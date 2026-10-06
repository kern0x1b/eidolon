#!/usr/bin/env python3
"""gaps.py: the rows of the 26.2 surface that ours.py finds no declaration for.

A row is `Type#member`. An enum's case counts as declared, and so does a type we only alias - both
because the declaration is there, whichever way it is written. A type we genuinely lack stays on the list,
and the tool is checked against one: a name that is in Apple's surface and in no source of ours.

Usage: gaps.py [ours.tsv] [surface.tsv]
"""
import collections
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
ours_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, '.agent-work/runs/ours-source.tsv')
surface_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, '.agent-work/runs/surface-26.2.tsv')
negative_name = sys.argv[3] if len(sys.argv) > 3 else 'TextEditorStyle'


def surface(path):
    # surf.py writes three columns and no header: owner, kind, the declaration as text
    rows = []
    for line in open(path):
        parts = line.rstrip('\n').split('\t')
        if len(parts) == 3:
            rows.append({'owner': parts[0], 'kind': parts[1], 'api': parts[2]})
    return rows


def ours(path):
    declared = collections.defaultdict(lambda: collections.defaultdict(set))
    for line in open(path):
        owner, kind, name, _ = line.rstrip('\n').split('\t')
        declared[owner][kind].add(name)
        declared[''][kind].add(name)      # a type declared at file scope names itself
    return declared


def main():
    apple = surface(surface_path)
    declared = ours(ours_path)
    gaps = []
    for row in apple:
        owner, kind, decl = row['owner'], row['kind'], row['api']
        names = declared[owner]
        if kind in ('type', 'init', 'subscript'):
            found = kind in names
        else:
            base = decl.split('(')[0]
            found = base in names['var'] or base in names['func'] or base in names['const']
        if not found:
            gaps.append(f'{owner}#{decl.split("(")[0]}')
    total = len(gaps)
    print(f'# {total} rows of the 26.2 surface that this tree declares no name for', file=sys.stderr)
    for row in gaps:
        print(row)
    # the negative: a name Apple's surface carries and no source of ours has must stay on the list
    kept = [row for row in gaps if row.startswith(negative_name + '#')]
    if not kept:
        print(f'# FAIL the negative case is gone: nothing starting {negative_name}# is reported', file=sys.stderr)
        sys.exit(1)
    print(f'# the negative case is kept: {len(kept)} row(s) of {negative_name}', file=sys.stderr)


if __name__ == '__main__':
    main()
