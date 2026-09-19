#!/usr/bin/env python3
"""ios-surface.py: from the SwiftUI interface in fw/, write the parts of apple-types.txt and
apple-view-modifiers.txt that an iOS app can actually use (drops declarations marked
@available(iOS, unavailable) in every overload)."""
import re, glob, os

here = os.path.dirname(os.path.abspath(__file__))
src = open(glob.glob(os.path.join(here, 'fw/SwiftUI.framework/Modules/SwiftUI.swiftmodule/*.swiftinterface'))[0]).read()
decl = re.compile(r'((?:@[^\n]*\n\s*)*)(?:public |open )?(?:final )?(?:@frozen )?(?:indirect )?(struct|class|enum|protocol|typealias|actor)\s+(\w+)')

def unavailable(attrs):
    return re.search(r'@available\(iOS,\s*unavailable', attrs) is not None

types = set(open(os.path.join(here, 'apple-types.txt')).read().split())
usable = set()
for m in decl.finditer(src):
    if m.group(3) in types and not unavailable(m.group(1)):
        usable.add(m.group(3))
open(os.path.join(here, 'apple-types-ios.txt'), 'w').write('\n'.join(sorted(usable)) + '\n')

mods = set(open(os.path.join(here, 'apple-view-modifiers.txt')).read().split())
usable_mods = set()
lines = src.split('\n')
depth = 0
in_view = False
view_depth = 0
attrs = []
for line in lines:
    stripped = line.strip()
    if depth == 0 and re.match(r'(?:@\S+\s+)*extension SwiftUI\.View\b', stripped):
        in_view = True
    f = re.search(r'\bfunc (\w+)', stripped)
    if f:
        if in_view and depth == 1 and f.group(1) in mods:
            own = stripped[:f.start()]
            if not any(re.search(r'@available\(iOS,\s*unavailable', a) for a in attrs + [own]):
                usable_mods.add(f.group(1))
        attrs = []
    elif stripped.startswith('@'):
        attrs.append(stripped)
    elif stripped and not stripped.startswith('#'):
        attrs = []
    depth += line.count('{') - line.count('}')
    if depth == 0:
        in_view = False
open(os.path.join(here, 'apple-view-modifiers-ios.txt'), 'w').write('\n'.join(sorted(usable_mods)) + '\n')
print(f'types: {len(types)} -> {len(usable)} usable on iOS; modifiers: {len(mods)} -> {len(usable_mods)} usable on iOS')
