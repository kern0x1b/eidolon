#!/usr/bin/env python3
"""classify-gaps.py: why a row of the 26.2 surface is a gap, as classes the rows themselves support.

The gaps list is one column, `Owner#name`, and every row in it is a name the 26.2 surface carries and
this tree declares nothing for. The rows are not one kind of thing, and a single "missing" count says
nothing about why: some name no lookup can ever satisfy, some is a member the compiler writes for a
conformance, some is machinery a header declares and no application writes, and some is a member of a
type this tree does not declare at all. The classes are therefore **ordered**, so that every row lands in
exactly one, and the count is a partition rather than a set of buckets that overlap.

    1 declaration-form  the row names no name at all - `init`, `subscript` - so declaring a name cannot close it
    2 witness           a member the compiler synthesises for a conformance: an associatedtype witness,
                        an Equatable/Hashable member, a protocol's collection member
    3 machinery         a name a header declares for the runtime's own use, underscore-prefixed
    4 nested            a member of a type nested in another, which the tree's owner is missing
    5 top-level         a member of a type the tree does not declare, and nothing else about it

Usage: classify-gaps.py gaps14.tsv [-o classified.tsv]
"""
import collections
import os
import sys

# A name the compiler writes out for a conformance rather than a declaration. `init` and `subscript` are
# not in this set: they are declaration forms, and they are the first class instead.
WITNESSES = {
    'Body', 'hash', 'hashValue', 'hashValue(into:)', 'Element', 'ArrayLiteralElement', 'RawValue',
    'Iterator', 'SubSequence', 'Substring', 'Index', 'Indices', 'startIndex', 'endIndex', 'index',
    'index(after:)', 'index(before:)', 'index(_:offsetBy:)', 'indices', 'all', 'rawValue', 'count',
    'first', 'last', 'isEmpty', 'description', 'debugDescription', 'CustomStringConvertible',
    'CustomDebugStringConvertible', 'Sendable', 'ExpressibleByStringLiteral', 'StringInterpolation',
    'StringLiteralType', 'UTF8View', 'UnicodeScalarView', 'StringView',
}
FORMS = {'init', 'subscript'}

CLASSES = ('declaration-form', 'witness', 'machinery', 'nested', 'top-level')


def classify(row):
    """the one class this row belongs to, in the order the classes are meant to be read"""
    owner, _, name = row.partition('#')
    if name in FORMS:
        return 'declaration-form'
    if name in WITNESSES:
        return 'witness'
    if name.startswith('_'):
        return 'machinery'
    if '.' in owner:
        return 'nested'
    return 'top-level'


def read(path):
    rows = []
    with open(path) as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip() or line.startswith('#'):
                continue
            if '#' not in line.rstrip('\n'):
                print(f'{path}: line {number} is not Owner#name: {line.rstrip()!r}', file=sys.stderr)
                sys.exit(1)
            rows.append(line.rstrip('\n'))
    return rows


def main():
    if len(sys.argv) not in (2, 4) or (len(sys.argv) == 4 and sys.argv[2] != '-o'):
        print(f'usage: {sys.argv[0]} gaps.tsv [-o classified.tsv]', file=sys.stderr)
        sys.exit(2)
    rows = read(sys.argv[1])
    buckets = collections.defaultdict(list)
    for row in rows:
        buckets[classify(row)].append(row)
    total = 0
    for name in CLASSES:
        bucket = buckets[name]
        total += len(bucket)
        print(f'{name:18} {len(bucket):4}')
        for example in bucket[:3]:
            print(f'    {example}')
    print(f'{"total":18} {total:4}   over {len(rows)} rows, in {len(CLASSES)} classes')
    if total != len(rows):
        print('# the classes do not cover every row', file=sys.stderr)
        sys.exit(1)
    if len(sys.argv) == 4:
        with open(sys.argv[3], 'w') as out:
            out.write(f'# every row of {os.path.basename(sys.argv[1])}, one class each, in the order the '
                      f'classes are meant to be read\n')
            out.write('# class\trow\n')
            for name in CLASSES:
                for row in buckets[name]:
                    out.write(f'{name}\t{row}\n')
        print(f'wrote {sys.argv[3]}')


if __name__ == '__main__':
    main()
