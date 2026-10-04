#!/usr/bin/env python3
"""ours3.py: the 'ours' surface in the three columns surf-diff.py reads.

ours.py writes four: owner, kind, name, and the file the declaration is in. The path is what tells a
reader *where* a name came from and nothing else needs it, so this drops it; a row whose owner, kind and
name are equal to another's collapses, because the sets surf-diff partitions are of declarations and two
paths for one declaration are one row.

Usage: ours3.py [ours.tsv] > ours-3.tsv      (a file already at three columns is passed through)
"""
import sys

COLUMNS = 3
OURS = 4


def convert(path):
    rows, seen, dropped = set(), 0, 0
    with open(path) as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            parts = line.rstrip('\n').split('\t')
            if len(parts) == OURS:
                rows.add((parts[0], parts[1], parts[2]))
            elif len(parts) == COLUMNS:
                rows.add(tuple(parts))
            else:
                print(f'{path}: line {number} has {len(parts)} columns, the {OURS} ours.py writes or the '
                      f'{COLUMNS} surf-diff reads. Refusing.', file=sys.stderr)
                sys.exit(1)
    return rows


def main():
    if len(sys.argv) != 2:
        print(f'usage: {sys.argv[0]} ours.tsv > ours-3.tsv', file=sys.stderr)
        sys.exit(2)
    rows = convert(sys.argv[1])
    for row in sorted(rows):
        print('\t'.join(row))
    print(f'# {len(rows)} rows of three columns from {sys.argv[1]}', file=sys.stderr)


if __name__ == '__main__':
    main()
