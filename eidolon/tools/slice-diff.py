#!/usr/bin/env python3
"""slice-diff.py: what Apple's SDK 26.2 interface declares for a slice of types that our module does not.

    slice-diff.py ours.json TYPE [TYPE...]

Apple's side is parsed out of the 26.2 .swiftinterface (the only written-down shape of a 17+
declaration; the corpus carries names only). Ours is the digester dump of the module this worktree
builds, the same way bridge/api-diff.py reads it. A declaration counts as missing when our dump has
nothing of that name under that type; Apple's declaration is printed with it, so the shape to write
is right there.
"""
import json
import os
import re
import sys

KEEP = re.compile(r'^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |static |mutating |nonisolated |final )*(?:func|var|let|init|subscript|typealias|associatedtype|case)\b')
SKIP = re.compile(r'^\s*(?:get|set|_read|_modify|return|\{|\}|#if|#endif|@_Concurrency|@_transparent|@usableFromInline)')
SDK = os.path.expanduser('~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
MODULES = SDK + '/System/Library/Frameworks'
SWIFTUI = MODULES + '/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface'
CORE = MODULES + '/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface'


def interface_blocks(path):
    lines = open(path, errors='replace').read().split('\n')
    i = 0
    while i < len(lines):
        if not lines[i] or lines[i][0] in ' \t}':
            i += 1
            continue
        start = i
        while i < len(lines) and (lines[i].startswith('@') or not lines[i]):
            i += 1
        head = ' '.join(l.strip() for l in lines[start:i + 1])
        body, depth = [], 0
        while i < len(lines):
            body.append(lines[i])
            depth += lines[i].count('{') - lines[i].count('}')
            i += 1
            if depth <= 0:
                break
        yield head, body


def apple(types):
    """[(owner, member name, declaration text)] for the types asked for."""
    out = []
    for path in (SWIFTUI, CORE):
        for head, body in interface_blocks(path):
            m = re.search(r'(?:struct|class|enum|protocol|extension)\s+([A-Za-z_][\w.]*)', head)
            if not m or m.group(1).split('.')[-1] not in types:
                continue
            owner = m.group(1).split('.')[-1]
            avail = re.search(r'@available\(iOS ([\d.]+)', head)
            for line in body:
                if not KEEP.match(line) or SKIP.match(line):
                    continue
                decl = line.strip()
                if decl.startswith('nonisolated public static func _') or decl.startswith('public static func _'):
                    continue
                out.append((owner, decl, avail.group(1) if avail else ''))
    return out


def ours_of(path):
    root = json.load(open(path))['ABIRoot']
    found = set()

    def walk(node, path):
        if not isinstance(node, dict):
            return
        printed = node.get('printedName')
        if printed:
            base = re.sub(r'<[^<>]*>', '', printed).split('(')[0]
            found.add((tuple(path), base))
        nested = path + [node.get('name') or node.get('printedName') or ''] if node.get('kind') == 'TypeDecl' else path
        for child in node.get('children', []):
            walk(child, nested)

    walk(root, [])
    return found


ours = ours_of(sys.argv[1])
types = set(sys.argv[2:])
missing = 0
total = 0
for owner, decl, avail in apple(types):
    total += 1
    # the *name* of a declaration, which is not the last dotted component for a property: in
    # `public static let never: PageTabViewStyle.IndexDisplayMode` the name is `never` and the
    # type is the last component, so taking that made every property of a nested type look missing.
    m = re.search(r'(?:func|var|let|init|subscript|case)\s+([A-Za-z_][\w]*)', decl)
    name = m.group(1) if m else re.search(r'typealias\s+(\w+)', decl).group(1) if 'typealias' in decl else None
    if name in ('Self', 'get', 'set'):
        name = None
    if name is None or name.startswith('_'):
        continue
    # a member of a nested type lives under a path that ends with the owner, so compare suffixes:
    # `PageTabViewStyle.IndexDisplayMode.never` is a member of `PageTabViewStyle` as much as one of
    # the nested type, and the corpus names only the outer one.
    if any(n == name and any(part == owner for part in o) for o, n in ours if o):
        continue
    missing += 1
    print(f'{owner:28} {avail:6} {decl}')
print(f'# {total} declarations of {len(types)} types, {missing} with no declaration of that name in ours', file=sys.stderr)
