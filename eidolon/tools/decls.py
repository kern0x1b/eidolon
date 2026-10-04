#!/usr/bin/env python3
"""decls.py: the declarations of the given types in Apple's SDK 26.2 interface, one per line.

    decls.py TYPE [TYPE...]
    decls.py --view TEXT

The 26.2 interface is the only written-down shape of a 17+ declaration (the corpus carries names,
not types). Attribute lines, bodies and accessor noise are dropped so a type's whole API fits on
a screen.
"""
import os
import re
import sys

SDK = os.path.expanduser('~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
MODULES = SDK + '/System/Library/Frameworks'
SWIFTUI = MODULES + '/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface'
CORE = MODULES + '/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface'
KEEP = re.compile(r'^\s*(public |@_?availability|@MainActor|@Sendable|@preconcurrency|@ViewBuilder|@frozen|@inlinable|static |mutating |nonisolated )*(func|var|let|init|subscript|typealias|associatedtype|case)\b')
SKIP = re.compile(r'^\s*(get|set|_read|_modify|return|\{|\}|#if|#endif|@_Concurrency|@_transparent|@usableFromInline|@_opaqueReturnTypeOf)')


def blocks(path):
    lines = open(path, errors='replace').read().split('\n')
    i = 0
    while i < len(lines):
        if not lines[i] or lines[i][0] in ' \t}':
            i += 1
            continue
        start = i
        while i < len(lines) and (lines[i].startswith('@') or not lines[i]):
            i += 1
        head = lines[start:i + 1] if i < len(lines) else []
        body, depth = [], 0
        while i < len(lines):
            body.append(lines[i])
            depth += lines[i].count('{') - lines[i].count('}')
            i += 1
            if depth <= 0:
                break
        yield ' '.join(l.strip() for l in head), body


ALL = []
for path in (SWIFTUI, CORE):
    module = 'SwiftUI' if path == SWIFTUI else 'Core'
    for head, body in blocks(path):
        ALL.append((head, body, module))

args = sys.argv[1:]
if args and args[0] == '--view':
    needle = args[1]
    for head, body, module in ALL:
        if not re.search(r'extension (SwiftUI\.)?(View|some SwiftUI\.View)\b', head):
            continue
        for line in body:
            if needle in line and KEEP.match(line) and not SKIP.match(line):
                print(line.strip())
    sys.exit(0)
if args and args[0] == '--grep':
    needle = args[1]
    for head, body, module in ALL:
        if any(needle in l for l in body) or needle in head:
            print(f'--- {head[:150]}')
            for line in body:
                if KEEP.match(line) and not SKIP.match(line):
                    print('   ', line.strip())
    sys.exit(0)

names = set(args)
seen = set()
for head, body, module in ALL:
    m = re.search(r'(?:struct|class|enum|protocol|extension)\s+([A-Za-z_][\w.]*)', head)
    if not m or m.group(1).split('.')[-1] not in names:
        continue
    key = (m.group(1), head[:60])
    if key in seen:
        continue
    seen.add(key)
    print(f'--- [{module}] {head[:200]}')
    for line in body:
        if KEEP.match(line) and not SKIP.match(line):
            print('   ', line.strip())
