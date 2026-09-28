#!/usr/bin/env python3
"""api-invented.py OURS26 INTERFACE: the public members our module has that Apple's 26.2 interface does not.

    api-invented.py ours.json

The typed diff in api-diff.py asks what Apple's declarations are missing here. This asks the other
question, which nothing else did: what does this module declare that Apple does not? A member invented
rather than reimplemented is a row the ledger counts as covered and the reader of the API never asked
for, so every such name is a line in the output.

The oracle is the union of the 26.2 interfaces of the modules this one re-exports (APPLE_26_SDK
overrides the root): the standard library, SwiftUI, SwiftUICore, Foundation, Combine, Observation,
CoreGraphics and UIKit. Judging a re-export against SwiftUI's interface alone called half the standard
library invented.
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
MODULES = ('Swift', 'SwiftUI', 'SwiftUICore', 'Foundation', 'CoreFoundation', 'Combine', 'Observation',
           'CoreGraphics', 'UIKit')


def interfaces():
    for module in MODULES:
        found = sorted(glob.glob(f'{SDK}/**/{module}.swiftmodule/*.swiftinterface', recursive=True))
        if not found:
            print(f'# no interface for {module} under {SDK}', file=sys.stderr)
            continue
        yield from found


SURFACE = os.environ.get('APPLE_26_SURFACE') or os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                             'apple-26-surface.tsv')

apple = set()
if os.path.exists(SURFACE):
    # The surface file is what bridge/surface-swiftui.sh writes: the same interfaces read by
    # swift-syntax's SwiftParser, which sees what the regular expressions below could not — an
    # associatedtype witness printed as a `var`, a nested `typealias` printed as a property, an enum
    # `case`, a `subscript`, a static in a constrained extension. Every such row was a name Apple
    # declares and this gate called invented.
    for line in open(SURFACE, errors='replace'):
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 2 and parts[1]:
            apple.add(parts[1].split('.')[-1].split('(')[0])
    print(f'# Apple surface from {SURFACE} ({len(apple)} names)', file=sys.stderr)
else:
    print(f'# no {SURFACE}: falling back to the regular-expression parse of the interfaces', file=sys.stderr)
    for path in interfaces():
        text = open(path, errors='replace').read()
        # Apple's text qualifies everything with its module; the member name is what has to match ours
        text = re.sub(r'\b(?:Swift|SwiftUI|SwiftUICore|Foundation|CoreFoundation|UIKit|QuartzCore|ObjectiveC|CoreGraphics|Darwin|Dispatch|Combine|Observation)\.(?=[A-Z])', '', text)
        apple |= set(re.findall(r'(?:func|var|let|init|subscript|typealias|case)\s+([A-Za-z_][\w]*)', text))
        apple |= set(re.findall(r'(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][\w]*)', text))
        apple |= set(re.findall(r'extension\s+(?:SwiftUI\.|SwiftUICore\.)?([A-Za-z_][\w]*)', text))
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
    if node.get('kind') in ('Import', 'Accessor', 'TypeNominal', 'AssociatedType'):
        return
    is_public = access_level(node) == 'public'
    if printed:
        base = re.sub(r'<[^<>]*>', '', printed).split('(')[0]
        if (public or is_public) and base and not base.startswith('_') and len(base) > 1:
            ours.append((path[-1] if path else '', base, node.get('declKind') or ''))
    is_type = node.get('kind') == 'TypeDecl' and node.get('name')
    nested = path + [node.get('name') or node.get('printedName') or ''] if is_type else path
    for child in node.get('children', []):
        walk(child, nested, public or (is_public and is_type))


walk(root, [], False)

invented = []
for owner, name, access in ours:
    if name in apple:
        continue
    invented.append((owner, name, access))

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
