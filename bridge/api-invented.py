#!/usr/bin/env python3
"""api-invented.py OURS26 INTERFACE: the public members our module has that Apple's 26.2 interface does not.

    api-invented.py ours.json

The typed diff in api-diff.py asks what Apple's declarations are missing here. This asks the other
question, which nothing else did: what does this module declare that Apple does not? A member invented
rather than reimplemented is a row the ledger counts as covered and the reader of the API never asked
for, so every such name is a line in the output.

The oracle is the union of the 26.2 interfaces of every module SwiftUI reaches through its
`@_exported import` lines, written by `bridge/surface-swiftui.sh` and read from `apple-26-surface.tsv`.
Judging a re-export against SwiftUI's interface alone called half the standard library invented, and
reading the interfaces with regular expressions instead of a parser called 40 of Apple's own witnesses
invented; both are fixed, and a missing surface file is an error rather than a different answer.
"""
import glob
import json
import os
import re
import sys

SDK = os.environ.get('APPLE_26_SDK') or os.path.expanduser(
    '~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')

# The oracle is every module this one re-exports, not SwiftUI alone: a name like `MutableCollection`
# or `URL` is declared by the standard library, and judging it against SwiftUI's interface called it
# invented. The union of the seven is what the module's own surface is written against.
SURFACE = os.environ.get('APPLE_26_SURFACE') or os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                             'apple-26-surface.tsv')

if not os.path.exists(SURFACE):
    # Falling back is not an option: the hand parse below answers a different question and gives a
    # different number (241 rows against 205 on this tree), so a gate that quietly changed its own
    # oracle would be a gate nobody could trust. `bridge/surface-swiftui.sh` writes the file.
    print(f'# ERROR no Apple surface: {SURFACE} is missing', file=sys.stderr)
    print('# run bridge/surface-swiftui.sh first; the gate does not fall back to its own parse', file=sys.stderr)
    sys.exit(2)

# The surface file is what bridge/surface-swiftui.sh writes: the interfaces of every module SwiftUI
# reaches through its `@_exported import` lines, read by swift-syntax's SwiftParser. A parser sees what
# regular expressions cannot — an associatedtype witness printed as a `var`, a nested `typealias` printed
# as a property, an enum `case`, a `subscript`, a static in a constrained extension — and every such row
# used to be a name Apple declares and this gate called invented.
apple = set()
for line in open(SURFACE, errors='replace'):
    parts = line.rstrip('\n').split('\t')
    if len(parts) >= 2 and parts[1]:
        # the interface writes a member named for a keyword in backticks (`default`, `repeat`); the dump does not
        apple.add(parts[1].split('.')[-1].split('(')[0].strip('`'))
print(f'# Apple surface from {SURFACE} ({len(apple)} names)', file=sys.stderr)
apple |= {'==', 'hash', 'self', 'Type', 'init', 'some', 'get', 'set'}

root = json.load(open(sys.argv[1]))['ABIRoot']
ours = []


def access_level(node):
    """The digester lists an access level only when it is not the one the context already implies, so
    a member of a public type is public unless it says otherwise."""
    attributes = node.get('declAttributes')
    if isinstance(attributes, dict):
        return attributes.get('accessLevel') or 'public'
    if isinstance(attributes, list):
        for item in attributes:
            if not isinstance(item, str):
                continue
            if item.startswith('public'):
                return 'public'
            if item.startswith('private') or item.startswith('fileprivate'):
                return 'private'
    return 'public'


def walk(node, path, public):
    if not isinstance(node, dict):
        return
    printed = node.get('printedName')
    # A TypeNameAlias is a use of a typealias inside a signature (`Swift.Void`, `Self.Configuration`), printed
    # qualified, with no declaration kind and no usr: the declaration it names is judged where it is declared.
    if node.get('kind') in ('Import', 'Accessor', 'TypeNominal', 'TypeNameAlias', 'AssociatedType'):
        return
    # An @_spi declaration is visible only to a client that imports its group by name (`@_spi(Probe) import`), so it
    # is not part of the API an app is written against, and neither is anything inside it.
    if 'SPIAccessControl' in (node.get('declAttributes') or []):
        return
    # An override is the name of the declaration it overrides, which is judged where that one is declared (a method of
    # UIKit is Objective-C and is in no .swiftinterface, so judging the override would call UIKit's own name invented).
    if node.get('overriding'):
        return
    is_public = access_level(node) == 'public'
    if printed and node.get('kind') != 'Root':
        base = re.sub(r'<[^<>]*>', '', printed).split('(')[0]
        if (public or is_public) and base and not base.startswith('_') and len(base) > 1:
            ours.append((path[-1] if path else '', base, node.get('declKind') or ''))
    is_type = node.get('kind') == 'TypeDecl' and node.get('name')
    nested = path + [node.get('name') or node.get('printedName') or ''] if is_type else path
    for child in node.get('children', []):
        walk(child, nested, public or (is_public and is_type))


walk(root, [], False)

# the allow-list: a name this port carries that no interface of the modules the port declares
# against declares either, with the reason it is here. `#name` is the name under any type.
ALLOW = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'api-allow-list.txt')
allowed = {}
if os.path.exists(ALLOW):
    for line in open(ALLOW):
        line = line.rstrip('\n')
        # a comment is a `#` with a space after it: `#name` is the bare form for any type
        if not line.strip() or line.lstrip().startswith('# ') or line.lstrip().startswith('//'):
            continue
        name, _, reason = line.partition('\t')
        allowed[name.strip()] = reason.strip()
used = set()
print(f'# {len(allowed)} names on the allow-list', file=sys.stderr)


invented = []
for owner, name, access in ours:
    if name in apple:
        continue
    key = next((k for k in (f'{owner}#{name}', f'#{name}') if k in allowed), None)
    if key:
        used.add(key)
        continue
    invented.append((owner, name, access))

for key in sorted(set(allowed) - used):
    # to stderr, never to stdout: stdout is invented.txt, and a row that is not invented does not
    # belong in the count api-surface.sh prints
    print(f'allowed\t{key}\t{allowed[key]}', file=sys.stderr)
print(f'# {len(used)} of the {len(allowed)} allow-listed names were used', file=sys.stderr)

seen = set()
for owner, name, access in invented:
    key = (owner, name)
    if key in seen:
        continue
    seen.add(key)
    print(f'{owner:34} {access:10} {name}')
print(f'# {len(seen)} public names in ours that no 26.2 interface of the modules we re-export declares', file=sys.stderr)
# The oracle is SwiftUI's own interface, so the standard library and Foundation that this module
# re-exports are all "invented" by that measure. STRICT=1 makes a non-empty list fail; until the
# re-exports are whitelisted the list is reported and the check does not stop a build.
if os.environ.get('STRICT') == '1' and seen:
    sys.exit(1)
