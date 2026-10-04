#!/usr/bin/env python3
"""trace.py: for a fully qualified name, which file, line and enclosing type declares it.

The row list a gap tool prints is a bare member name, and a bare name is not a place: `stretch` is
`Image.ResizingMode.stretch` and is declared as `case tile` / `case stretch` **inside** `Image` in
SwiftUICore, with no prefix on the line at all. So the name is looked up whole, the enclosing type is
composed from the nesting — every `struct`, `enum` and `class` pushes, every `extension X` sets the base
to `X` — and the file, the line and that enclosing type come out.

Usage: trace.py NAMES-FILE [--out table.tsv]      (names are `Image.ResizingMode.stretch`)
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from owners import walk

SDK26 = os.environ.get('APPLE_26_SDK') or os.path.expanduser(
    '~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
MODULES = ('Swift', 'SwiftUI', 'SwiftUICore', 'Foundation', 'CoreGraphics', 'UIKit', 'Combine',
           'Observation', 'CoreTransferable', 'DeveloperToolsSupport')
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
INTERFACES = []
for pattern, label in (
        (f'{SDK26}/System/Library/Frameworks/*/Modules/*.swiftmodule/arm64e-apple-ios.swiftinterface', '26.2 arm64e'),
        (f'{SDK26}/System/Library/Frameworks/*/Modules/*.swiftmodule/arm64-apple-ios.swiftinterface', '26.2 arm64'),
        (f'{SDK26}/usr/lib/swift/*.swiftmodule/arm64e-apple-ios.swiftinterface', '26.2 arm64e stdlib'),
        (os.path.join(ROOT, 'bridge/fw/SwiftUI.framework/Modules/SwiftUI.swiftmodule/*.swiftinterface'), '16.4')):
    for path in sorted(glob.glob(pattern)):
        INTERFACES.append((path, label))

DECL = re.compile(r'^(?:@[\w.()]+\s*(?:\([^)]*\)\s*)?)*(?:public|open|package)\s+'
                  r'(?:final\s+|indirect\s+|@frozen\s+|@usableFromInline\s+)*'
                  r'(struct|class|enum|protocol|actor|typealias|extension)\s+([\w.]+)')
MEMBER = re.compile(r'\b(?:static\s+|case\s+)?(?:let|var|func|case)\s+([\w_]+)')


def qualified(name):
    """the module prefix, if the interface wrote one, dropped: the name a caller writes has no module"""
    if '.' in name:
        head, _, tail = name.rpartition('.')
        first = head.split('.', 1)[0]
        if first in MODULES:
            return head.split('.', 1)[1] if '.' in head else tail
    return name


def find(name, path, label):
    """the file, line and enclosing type that declare a fully qualified name.

    The line is examined **before** the stack is popped, and an entry is popped only when the braces
    have closed it: `case stretch` stands at depth two inside `extension SwiftUICore.Image` and inside
    `ResizingMode`, and the owner is `Image.ResizingMode`. Popping first — the first version did —
    collapsed it to `Image` and then to nothing, and five public members read as absent.
    """
    want = qualified(name)
    member = want.rsplit('.', 1)[-1]
    enclosing = want.rsplit('.', 1)[0] if '.' in want else ''
    lines = open(path, errors='replace').read().split('\n')
    hits = []
    for number, line, owner in walk(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('//') or owner is None:
            continue
        found = MEMBER.search(stripped)
        if not found or found.group(1) != member:
            continue
        if enclosing and not owner.endswith(enclosing):
            continue
        hits.append((owner, number, label, ''))
    return hits



# the enclosing type is part of the check: a line number on its own proves nothing, and three of the
# five were "found" under a type that has nothing to do with them
CONTROLS = [
    ('Image.ResizingMode.stretch', 'Image.ResizingMode'),
    ('Image.Orientation.up', 'Image.Orientation'),
    ('Image.TemplateRenderingMode.original', 'Image.TemplateRenderingMode'),
    ('Image.Interpolation.high', 'Image.Interpolation'),
    ('View.symbolRenderingMode', 'View'),
]


def main():
    if sys.argv[1] == '--check':
        failures = 0
        for control, owner_wanted in CONTROLS:
            hits = [h for path, label in INTERFACES for h in (find(control, path, label) or [])]
            owners = [h[0] for h in hits]
            if owner_wanted in owners:
                for owner, number, label, availability in hits:
                    mark = 'ok  ' if owner == owner_wanted else '    '
                    print(f'{mark} {control}  {label} {number}  in {owner}')
                if len(owners) > 1:
                    print(f'     ({len(owners)} declarations of that name; the control wants {owner_wanted})')
            else:
                print(f'FAIL {control}  no declaration in {owner_wanted}; found in {owners or "nothing"}')
                failures += 1
        print(f'# {len(CONTROLS) - failures} of {len(CONTROLS)} controls passed', file=sys.stderr)
        sys.exit(1 if failures else 0)
    names = [l.strip() for l in open(sys.argv[1]) if l.strip() and not l.startswith('#')]
    rows = []
    for name in names:
        hits = [(p, l, h) for p, label in INTERFACES for h in (find(name, p, label) or []) for l in [label]]
        if hits:
            owner, number, label, availability = hits[0][2]
            rows.append((name, owner, label, number, availability))
        else:
            rows.append((name, '(not found)', '', '', ''))
    if len(sys.argv) > 2 and sys.argv[2] == '--out':
        with open(sys.argv[3], 'w') as handle:
            handle.write('name\textended-type\tinterface\tline\tavailability\n')
            for row in rows:
                handle.write('\t'.join(str(c) for c in row) + '\n')
    else:
        for row in rows:
            print('\t'.join(str(c) for c in row))


if __name__ == '__main__':
    main()
