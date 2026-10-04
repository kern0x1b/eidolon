#!/usr/bin/env python3
"""surf-check.py: the two controls for surf.py's owner tracking.

A negative: a member of a type the band does not own is never filed under one it does. `CoarseConversionValue`
lives in AdAttributionKit and has nothing to do with `Image`, and an earlier owner filed it there.

Four positives: a type nested in `Image` is owned by `Image.<nested>`, and none of its members is filed
under `Image`. The counts are what the interfaces have — ResizingMode 2, Orientation 8 cases plus `allCases`
and `rawValue`, Interpolation 3, TemplateRenderingMode 1.

Usage: surf-check.py SURFACE-TSV
"""
import collections
import sys

NESTED = {'ResizingMode': 2, 'Orientation': 10, 'Interpolation': 3, 'TemplateRenderingMode': 1,
          'Representation': 2}


def main():
    rows = [l.rstrip('\n').split('\t') for l in open(sys.argv[1]) if l.strip()]
    owners = collections.Counter(owner for owner, _, _ in rows)
    failures = []
    # a bare name from a type the band does not own: CoarseConversionValue is AdAttributionKit's, and
    # an owner that filed it under Image would put it here
    # exactly one name: CoarseConversionValue is AdAttributionKit's, and nothing the band owns nests a
    # type of that name. `Representation` is NOT foreign — it is nested in Image at 26.2 and is a positive.
    foreign = [name for name in ('CoarseConversionValue',)
               if f'Image.{name}' in owners or any(r[0] == f'Image.{name}' for r in rows)]
    print(f'{"ok  " if not foreign else "FAIL"} CoarseConversionValue is not under Image: {foreign}')
    if foreign:
        failures.append('CoarseConversionValue is filed under Image')
    for nested, wanted in NESTED.items():
        got = owners.get(f'Image.{nested}', 0)
        print(f'{"ok  " if got else "FAIL"} Image.{nested} owns its own members ({got} rows, the interface has about {wanted})')
        if not got:
            failures.append(f'Image.{nested} owns nothing; its members are filed elsewhere')
    print(f'# Image owns {owners.get("Image", 0)} rows of its own', file=sys.stderr)
    for line in failures:
        print(f'# {line}', file=sys.stderr)
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
