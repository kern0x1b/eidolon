#!/usr/bin/env python3
"""surf-diff.py: what a rewrite of the extractor lost, as sets, not as totals.

A row is a `(owner, leaf member name)` pair. The old extraction's owner column is wrong for every member
of a type nested in one - that is what the rewrite fixes - so a row that is in both files under a
different owner is a *move*, and it is paired by the leaf name **and** the line the interface declares it
on, because a bare name has several homes and only the line says which one moved.

The classes are sets, and they are checked against the sets they are supposed to partition:

    |O| - |N| == |O\\N| - |N\\O|
    O\\N == moved + attribute + other
    N\\O == gained

Usage: surf-diff.py [--allow-empty-new] OLD.tsv NEW.tsv

Both files must have three tab-separated columns per row: owner, kind, name. A file of any other shape is
a hard error naming the file, the expected three and the count found - a wrong-shaped file read as the
empty set would make every identity below hold at zero.
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


COLUMNS = 3


class ReadError(Exception):
    """a file that is not the shape the diff reads, named rather than read as nothing"""


def read(path, allow_empty=False):
    """A set of (owner, kind, leaf) keyed so a move is visible.

    A row is only read when the line has exactly three tab-separated columns, and a line that does not is
    a **hard error**: the sets partition what was read, so a file of the wrong shape read as the empty set
    makes |O| - |N| == |O\\N| - |N\\O| true whatever the file holds - 0 == 0 - and the classes below it
    partition an empty |O\\N| exactly. That is the silent green this refuses. The three artifacts in
    bridge/tools are three different shapes (see surftool/README.md), and pairing the wrong two must stop
    here rather than print a partition of nothing.
    """
    rows, bad = set(), []
    with open(path) as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            parts = line.rstrip('\n').split('\t')
            if len(parts) != COLUMNS:
                bad.append((number, len(parts)))
                continue
            rows.add((parts[0], parts[1], leaf(parts[2])))
    if bad:
        number, found = bad[0]
        raise ReadError(
            f'{path}: line {number} has {found} tab-separated column(s), the {COLUMNS} this diff reads are '
            f'owner/kind/name; {len(bad)} line(s) in all (first at line {number}). Refusing to read the file '
            f'as the empty set: the partition below would hold vacuously. Use the artifact that has three '
            f'columns (see bridge/tools/surftool/README.md for what each one is).')
    if not rows and not allow_empty:
        raise ReadError(f'{path}: no rows. A NEW file of no rows is a hard error, because |O| - |N| == '
                        f'|O\\N| - |N\\O| then holds at 0 == 0. Pass --allow-empty-new to mean it.')
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
    args = [a for a in sys.argv[1:] if a != '--allow-empty-new']
    if len(args) != 2:
        print(f'usage: {sys.argv[0]} [--allow-empty-new] OLD.tsv NEW.tsv   (three columns each: owner/kind/name)',
              file=sys.stderr)
        sys.exit(2)
    try:
        old, new = read(args[0]), read(args[1], allow_empty='--allow-empty-new' in sys.argv[1:])
    except ReadError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    if not old:
        print(f'{args[0]}: no rows either, so there is nothing to diff. Refusing.', file=sys.stderr)
        sys.exit(1)
    only_old, only_new = old - new, new - old
    table = index()
    # where each name sits in the NEW file, by (name, file, line) - the pairing that says "moved" is the
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
    print(f'|O| = {len(old)}   surface rows in OLD')
    print(f'|N| = {len(new)}   surface rows in NEW')
    print(f'|O\\N| = {len(only_old)}   |O\\N| rows: moved {len(moved)}  attribute {len(attribute)}  other {len(other)}')
    print(f'|N\\O| = {len(gained)}   |N\\O| rows: gained')
    for label, rows in (('moved', moved), ('attribute', attribute), ('other', other)):
        for owner, kind, name in sorted(rows)[:3]:
            homes = '; '.join(f'{h[1]}:{h[2]} in {h[0]}' for h in sorted(table.get(name, ()), key=lambda h: (str(h[1]), h[2]))[:2])
            print(f'  {label:10} {owner}#{name:22} {homes}')
    parts = (moved, attribute, other)
    union = moved | attribute | other
    disjoint = not (parts[0] & parts[1] or parts[0] & parts[2] or parts[1] & parts[2])
    ok = (len(old) - len(new) == len(only_old) - len(only_new)
          and union == only_old and disjoint and (moved | attribute | other) == only_old)
    print(f'identity over surface rows (not gap rows): |O|-|N| = {len(old) - len(new)}, '
          f'|O\\N| - |N\\O| = {len(only_old) - len(only_new)}, '
          f'classes: {len(moved)} + {len(attribute)} + {len(other)} = {len(moved | attribute | other)}')
    if not ok:
        print('# the classes do not add up', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
