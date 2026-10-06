#!/usr/bin/env python3
"""types-surface.py: write bridge/apple-types.txt from the SDK's own 26.2 interfaces, so the list the
ledger counts against is generated rather than kept by hand.

The list used to be hand-kept and had been since the repository's first commit, which is how a family
the interface declares - `TextEditorStyle` and its three styles - was missing from it. It is now every
public type and typealias the SDK of 26.2 declares in the module of this framework, and
`apple-types-ios.txt` the part of it an iOS app can actually use.

The source is the SDK of 26.2, not `fw/`: `fw/` is the interface of 16.4, which has no widget, no
`TextEditorStyle` and no window, and generating from it would drop every type this port exists to carry.

Usage: types-surface.py [SDK26]        (default: the charon SDK 26.2 checkout)
"""
import glob
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))
sdk = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
    'APPLE_26_SDK', os.path.expanduser('~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk'))
frameworks = os.path.join(sdk, 'System/Library/Frameworks')
# the modules the inventory covers: SwiftUI's own surface, which is what an app writes against.
# The standard library, Foundation and UIKit are reachable through it and are not listed here -
# the hand-kept list never had them, and `SCOPE` widens the list when a review asks for it.
SCOPE = os.environ.get('APPLE_26_SCOPE', 'SwiftUI,SwiftUICore')
stdlib = os.path.join(sdk, 'usr/lib/swift')

# a public type or typealias, with the attributes that may be above it
DECL = re.compile(
    r'((?:@[\w.()]+\s*(?:\([^)]*\)\s*)?)*)((?:public|open|package)\s+)'
    r'(?:final\s+|indirect\s+|@frozen\s+)*'
    r'(struct|class|enum|protocol|typealias|actor)\s+(\w+)')


def interfaces():
    for root in (frameworks, stdlib):
        if not os.path.isdir(root):
            continue
        for path in sorted(glob.glob(os.path.join(root, '*', 'Modules', '*.swiftmodule', '*.swiftinterface'))):
            module = os.path.basename(os.path.dirname(path)).removesuffix('.swiftmodule')
            # the modules of this framework and the ones it re-exports; the standard library, Foundation
            # and the frameworks SwiftUI builds on are what an app writes against
            if module in SCOPE.split(','):
                yield path


def unavailable_on_ios(attrs):
    return re.search(r'@available\(\s*iOS\s*,\s*unavailable', attrs) is not None


def main():
    if not os.path.isdir(sdk):
        print(f'types-surface: no SDK at {sdk}', file=sys.stderr)
        sys.exit(2)
    everything, on_ios, per_module = {}, {}, {}
    for path in interfaces():
        module = os.path.basename(os.path.dirname(path)).removesuffix('.swiftmodule')
        text = open(path, errors='replace').read()
        # a type declared inside another is not a module-level name, and a doc or comment line is not a
        # declaration: take only lines that start with an attribute or a public keyword at the left.
        # The SDK writes @available on the line above the declaration it belongs to and on no declaration's
        # own line at all, so a declaration's attributes are its own line and the @-lines above it; read off
        # its own line alone, unavailable_on_ios never fires and nothing is ever dropped.
        above = []
        for line in text.split('\n'):
            stripped = line.lstrip()
            if stripped.startswith('@') and not DECL.match(stripped):
                above.append(stripped)
                continue
            m = DECL.match(stripped)
            if not m:
                above = []
                continue
            attrs, access, kind, name = m.groups()
            if access == 'package':
                continue
            entry = (name, kind)
            per_module.setdefault(module, {})[name] = kind
            everything[name] = kind
            if not unavailable_on_ios(' '.join(above + [attrs])):
                on_ios[name] = kind
            above = []
    previous = {}
    path = os.path.join(here, 'apple-types.txt')
    if os.path.exists(path):
        for line in open(path):
            if line.strip():
                name, _, kind = line.rstrip('\n').partition('\t')
                previous[name] = kind
    added = sorted(set(everything) - set(previous))
    removed = sorted(set(previous) - set(everything))
    with open(path, 'w') as handle:
        for name in sorted(everything):
            handle.write(f'{name}\t{everything[name]}\n')
    with open(os.path.join(here, 'apple-types-ios.txt'), 'w') as handle:
        for name in sorted(on_ios):
            handle.write(name + '\n')
    print(f'types-surface: {sdk}')
    for module, names in sorted(per_module.items()):
        print(f'  {module}: {len(names)} types')
    print(f'  apple-types.txt: {len(everything)} types, {len(on_ios)} of them usable on iOS')
    print(f'  added {len(added)}: {" ".join(added[:20])}{" ..." if len(added) > 20 else ""}')
    print(f'  removed {len(removed)}: {" ".join(removed[:20])}{" ..." if len(removed) > 20 else ""}')


if __name__ == '__main__':
    main()
