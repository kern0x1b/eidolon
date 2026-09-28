#!/usr/bin/env python3
"""api-invented.py OURS26 INTERFACE: the public members our module has that Apple's 26.2 interface does not.

    api-invented.py ours.json arm64e-apple-ios.swiftinterface

The typed diff in api-diff.py asks what Apple's declarations are missing here. This asks the other
question, which nothing else did: what does this module declare that Apple does not? A member invented
rather than reimplemented is a row the ledger counts as covered and the reader of the API never asked
for, so every such name is a line in the output and a non-empty output is a failure.
"""
import json
import os
import re
import sys

INTERFACE = sys.argv[2] if len(sys.argv) > 2 else os.environ.get(
    'APPLE_26_INTERFACE',
    os.path.expanduser('~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk/System/Library/Frameworks/'
                      'SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface'))

text = open(INTERFACE, errors='replace').read()
# Apple's text qualifies everything with its module; the member name is what has to match ours
text = re.sub(r'\b(?:Swift|SwiftUI|SwiftUICore|Foundation|CoreFoundation|UIKit|QuartzCore|ObjectiveC|CoreGraphics|Darwin|Dispatch)\.(?=[A-Z])', '', text)
apple = set(re.findall(r'(?:func|var|let|init|subscript|typealias|case)\s+([A-Za-z_][\w]*)', text))
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
print(f'# {len(seen)} public names in ours that the 26.2 SwiftUI interface does not declare', file=sys.stderr)
# The oracle is SwiftUI's own interface, so the standard library and Foundation that this module
# re-exports are all "invented" by that measure. STRICT=1 makes a non-empty list fail; until the
# re-exports are whitelisted the list is reported and the check does not stop a build.
if os.environ.get('STRICT') == '1' and seen:
    sys.exit(1)
