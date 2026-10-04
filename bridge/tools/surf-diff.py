#!/usr/bin/env python3
"""surf-diff.py: what a rewrite of the extractor lost, keyed, not by totals.

A row is keyed by the leaf member name, so a member that moved from `Image` to `Image.ResizingMode` is
the same row with another owner, not a loss. Every row the old extraction has and the new one does not
lands in one of four classes, and the counts have to add up to the difference between the two files:

  a  moved       the same member name is in the new file under another owner — the nesting fix at work
  b  available   a static or a member of a `where` extension whose `@available` annotation is the only
                 thing that made the old extractor drop it
  c  attribute   a member of a block with more than one attribute line above it, and `pending` kept only
                 the last one
  d  other       everything else, with three example lines each so it can be read

Usage: surf-diff.py OLD.tsv NEW.tsv
"""
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from owners import walk, is_declaration

SDK26 = os.environ.get('APPLE_26_SDK') or os.path.expanduser(
    '~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk')
INTERFACES = []
for pattern in (f'{SDK26}/System/Library/Frameworks/*/Modules/*.swiftmodule/arm64e-apple-ios.swiftinterface',
                 f'{SDK26}/usr/lib/swift/*.swiftmodule/arm64e-apple-ios.swiftinterface'):
    import glob
    for path in sorted(glob.glob(pattern)):
        INTERFACES.append(path)


def read(path):
    out = []
    for line in open(path):
        parts = line.rstrip('\n').split('\t')
        if len(parts) == 3:
            out.append(tuple(parts))
    return out


_INDEX = None


def index():
    """one pass over every interface: leaf member name -> [(owner, file, line, text, attributes above)]

    The first version walked every interface again for every lost name, and 298 names over twenty
    interfaces is a job that does not finish. One pass, then a dict lookup per name.
    """
    global _INDEX
    if _INDEX is not None:
        return _INDEX
    _INDEX = collections.defaultdict(list)
    for path in INTERFACES:
        lines = open(path, errors='replace').read().split('\n')
        attrs = 0
        for number, line, owner in walk(lines):
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
                    _INDEX[m.group(1) if m.groups() else 'init'].append(
                        (owner, os.path.basename(path), number, stripped[:70], attrs))
                    break
            attrs = 0
    return _INDEX


def interface_lines(name):
    """the declarations of a member name, from the one pass"""
    return index().get(name, [])


def main():
    old, new = read(sys.argv[1]), read(sys.argv[2])
    new_leaves = {leaf(owner, text) for owner, _, text in new}
    new_by_leaf = collections.defaultdict(set)
    for owner, _, text in new:
        new_by_leaf[leaf(owner, text)].add(owner)
    classes = collections.defaultdict(list)
    for owner, kind, text in old:
        name = leaf(owner, text)
        if name in new_leaves:
            if owner not in new_by_leaf[name]:
                classes['a moved'].append((name, owner, sorted(new_by_leaf[name]), ''))
            continue
        hits = interface_lines(name)
        if not hits:
            classes['d other'].append((name, owner, '', '(no declaration of that name in the interfaces)'))
        elif any('@available' in h[3] and h[1] != owner for h in hits) or any(h[4] > 1 for h in hits):
            classes['b available' if any('@available' in h[3] and h[1] != owner for h in hits)
                     else 'c attribute'].append((name, owner, [f'{h[1]}:{h[2]}' for h in hits[:2]], hits[0][3]))
        else:
            classes['d other'].append((name, owner, [f'{h[1]}:{h[2]}' for h in hits[:2]], hits[0][3]))
    new_only = {leaf(o, x) for o, _, x in new} - {leaf(o, x) for o, _, x in old}
    total = 0
    for key in sorted(classes):
        rows = classes[key]
        total += len(rows)
        print(f'{key:12} {len(rows):5}')
        for row in rows[:3]:
            print(f'             {row[0]}  was under {row[1]}  now {row[2] or "-"}  {row[3][:50]}')
    print(f'{"rows only in NEW":12} {len(new_only):5}')
    print(f'{"TOTAL":12} {total:5}   (lost {len(old) - len(new)}, gained {len(new) - len(old)}, '
          f'which must be {len(new_only) - (len(new) - len(old))})')
    if total + (len(new) - len(old)) != len(new_only):
        print('# the classes do not add up to the difference between the files', file=sys.stderr)
        sys.exit(1)


DECL_NOISE = re.compile(r'^(?:@[\w.]+(?:\([^)]*\))?\s*)*(?:public |open |package |internal |private |final |indirect |'
                         r'@frozen|@inlinable|@usableFromInline|@_alwaysEmitIntoClient|nonisolated|MainActor|'
                         r'preconcurrency|static|mutating|_disfavoredOverload|_Concurrency\.\w+|\s)+')


def leaf(owner, text):
    """the member name a row names, whether the column holds a bare name or a whole declaration"""
    if not text.startswith(('@', 'public', 'open', 'package', 'nonisolated', 'self', 'internal',
                           'private', 'final', 'static', 'mutating', 'indirect', '_Concurrency')):
        return text.split('(')[0].split(':')[0].strip()
    stripped = text.strip()
    for pattern in (r'\bcase\s+(\w+)', r'\bfunc\s+(\w+)', r'\bvar\s+(\w+)', r'\blet\s+(\w+)',
                    r'\binit\b', r'\bsubscript\b',
                    r'\b(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)'):
        m = re.search(pattern, stripped)
        if m:
            return m.group(1) if m.groups() else ('init' if 'init' in pattern else 'subscript')
    return ''.join(DECL_NOISE.findall(stripped) and [] or []) or stripped.split('(')[0].split(':')[0].strip()


if __name__ == '__main__':
    main()
