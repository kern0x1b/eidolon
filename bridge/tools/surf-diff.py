#!/usr/bin/env python3
"""surf-diff.py: what a rewrite of the extractor lost, as sets, not as totals.

A row is a `(owner, leaf member name)` pair. The old extraction's owner column is wrong for every member
of a type nested in one — that is what the rewrite fixes — so a row that is in both files under a
different owner is a *move*, and it is paired by the leaf name **and** the line the interface declares it
on, because a bare name has several homes and only the line says which one moved.

The classes are sets, and they are checked against the sets they are supposed to partition:

    |O| - |N| == |O\\N| - |N\\O|
    O\\N == moved + attribute + other
    N\\O == gained

Usage: surf-diff.py OLD.tsv NEW.tsv
"""
import collections
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from owners import walk

SDK26 = os.environ.get('APPLE_26_SDK') or os.path.expanduser(
    '~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
INTERFACES = []
for pattern in (f'{SDK26}/System/Library/Frameworks/*/Modules/*.swiftmodule/arm64e-apple-ios.swiftinterface',
                 f'{SDK26}/usr/lib/swift/*.swiftmodule/arm64e-apple-ios.swiftinterface'):
    for path in sorted(glob.glob(pattern)):
        INTERFACES.append(path)

NOISE = re.compile(r'^(?:@[\w.]+(?:\([^)]*\))?\s*|@\w+)*\s*'
                   r'(?:public |open |package |internal |private |fileprivate |final |indirect |mutating |static |'
                   r'nonisolated |@frozen\s*|@inlinable\s*|@usableFromInline\s*|@_alwaysEmitIntoClient\s*|'
                   r'@MainActor\s*|@preconcurrency\s*|_Concurrency\.\w+\s*|_disfavoredOverload\s*|'
                   r'@backDeployed\s*|convenience\s*|required\s*|mutating\s*|override\s*)*')


def leaf(text):
    """the member name a row names, whether the column holds a bare name or a whole declaration"""
    stripped = NOISE.sub('', text.strip(), count=1).strip()
    for pattern in (r'\bcase\s+(\w+)', r'\bfunc\s+(\w+)', r'\bvar\s+(\w+)', r'\blet\s+(\w+)',
                    r'\binit\b', r'\bsubscript\b',
                    r'\b(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)'):
        m = re.search(pattern, stripped)
        if m:
            return m.group(1) if m.groups() else ('init' if 'init' in pattern else 'subscript')
    return stripped.split('(')[0].split(':')[0].split('{')[0].strip()


def read(path):
    """a set of (owner, kind, leaf) and the leaf-name multiset, both keyed so a move is visible"""
    rows = set()
    for line in open(path):
        parts = line.rstrip('\n').split('\t')
        if len(parts) == 3:
            rows.add((parts[0], parts[1], leaf(parts[2])))
    return rows


_INDEX = None


def index():
    """one pass over every interface: leaf name -> {(owner, file, line, text, attributes above it)}"""
    global _INDEX
    if _INDEX is not None:
        return _INDEX
    _INDEX = collections.defaultdict(set)
    for path in INTERFACES:
        attrs = 0
        for number, line, owner in walk(open(path, errors='replace').read().split('\n')):
            stripped = line.strip()
            if not stripped or stripped.startswith('//'):
                continue
            if stripped.startswith('@'):
                attrs += 1
                continue
            for pattern in (r'\b(?:case|func|var|let|subscript)\s+(\w+)',
                            r'\b(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)',
                            r'\binit\b'):
                m = re.search(pattern, stripped)
                if m:
                    _INDEX[m.group(1) if m.groups() else 'init'].add(
                        (owner, os.path.basename(path), number, stripped[:70], attrs))
                    break
            attrs = 0
    return _INDEX


def main():
    old, new = read(sys.argv[1]), read(sys.argv[2])
    only_old, only_new = old - new, new - old
    table = index()
    # where each name sits in the NEW file, by (name, file, line) — the pairing that says "moved" is the
    # same declaration at another owner, not merely the same name
    new_leaves_by_line = collections.defaultdict(set)
    for owner, kind, name in new:
        for home_owner, file, number, _, _ in table.get(name, ()):
            new_leaves_by_line[(name, file, number)].add(owner)
    # one pass, and the three classes partition |O\N| exactly
    moved, attribute, other = set(), set(), set()
    for row in only_old:
        owner, kind, name = row
        homes = table.get(name, set())
        if any('@available' in text and at > 1 for _, _, _, text, at in homes):
            attribute.add(row)                       # (c) a block with more than one attribute above it
        elif any('@available' in text for _, _, _, text, _ in homes):
            other.add(row)                           # an @available the old extractor dropped
        elif not homes:
            other.add(row)                           # no declaration of that name in the interfaces
        elif any(new_leaves_by_line.get((name, h[1], h[2]), set()) - {owner} for h in homes):
            moved.add(row)                           # (a) the same declaration, at another owner
        else:
            other.add(row)                           # the same name, but not the same declaration
    gained = only_new
    print(f'|O| = {len(old)}')
    print(f'|N| = {len(new)}')
    print(f'|O\\N| = {len(only_old)}   moved {len(moved)}  attribute {len(attribute)}  other {len(other)}')
    print(f'|N\\O| = {len(gained)}   gained')
    for label, rows in (('moved', moved), ('attribute', attribute), ('other', other)):
        for owner, kind, name in sorted(rows)[:3]:
            homes = '; '.join(f'{h[1]}:{h[2]} in {h[0]}' for h in sorted(table.get(name, ()), key=lambda h: (str(h[1]), h[2]))[:2])
            print(f'  {label:10} {owner}#{name:22} {homes}')
    parts = (moved, attribute, other)
    union = moved | attribute | other
    disjoint = not (parts[0] & parts[1] or parts[0] & parts[2] or parts[1] & parts[2])
    ok = (len(old) - len(new) == len(only_old) - len(only_new)
          and union == only_old and disjoint and (moved | attribute | other) == only_old)
    print(f'identity: |O|-|N| = {len(old) - len(new)}, '
          f'|O\\N| - |N\\O| = {len(only_old) - len(only_new)}, '
          f'classes: {len(moved)} + {len(attribute)} + {len(other)} = {len(moved | attribute | other)}')
    if not ok:
        print('# the classes do not add up', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
