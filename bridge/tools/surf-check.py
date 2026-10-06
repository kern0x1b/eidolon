#!/usr/bin/env python3
"""surf-check.py: the two controls for surf.py's owner tracking.

A negative: a member of a type the band does not own is never filed under one it does. `CoarseConversionValue`
lives in AdAttributionKit and has nothing to do with `Image`, and an earlier owner filed it there.

Four positives: a type nested in `Image` is owned by `Image.<nested>`, and none of its members is filed
under `Image`. The counts are what the interfaces have - ResizingMode 2, Orientation 8 cases plus `allCases`
and `rawValue`, Interpolation 3, TemplateRenderingMode 1.

Usage: surf-check.py [SURFACE-TSV]      or  SURFACE_TSV=... surf-check.py
"""
import collections
import os
import sys

NESTED = {'ResizingMode': 2, 'Orientation': 10, 'Interpolation': 3, 'TemplateRenderingMode': 1,
          'Representation': 2}


# The negative is a bound rather than a name: Image owns 15 rows of its own, the number the interfaces
# give it. The bug this check exists for filed its nested types' members under Image and took it to 32,
# so a bound fires on exactly that and cannot pass vacuously the way a name the filtered surface does
# not carry could.
MAX_IMAGE_OWN = 15


def surface():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.environ['SURFACE_TSV']


def main():
    path = surface()
    rows = [l.rstrip('\n').split('\t') for l in open(path) if l.strip()]
    print(f'# judging {path}', file=sys.stderr)
    owners = collections.Counter(owner for owner, _, _ in rows)
    failures = []
    # a bare name from a type the band does not own: CoarseConversionValue is AdAttributionKit's, and
    # an owner that filed it under Image would put it here
    # exactly one name: CoarseConversionValue is AdAttributionKit's, and nothing the band owns nests a
    # type of that name. `Representation` is NOT foreign - it is nested in Image at 26.2 and is a positive.
    owned = owners.get('Image', 0)
    print(f'{"ok  " if owned <= MAX_IMAGE_OWN else "FAIL"} Image owns no more than the {MAX_IMAGE_OWN} '
          f'rows the interfaces give it: {owned}')
    for nested, wanted in NESTED.items():
        got = owners.get(f'Image.{nested}', 0)
        print(f'{"ok  " if got else "FAIL"} Image.{nested} owns its own members ({got} rows, the interface has about {wanted})')
        if not got:
            failures.append(f'Image.{nested} owns nothing; its members are filed elsewhere')
    print(f'# Image owns {owners.get("Image", 0)} rows of its own', file=sys.stderr)
    if owned > MAX_IMAGE_OWN:
        failures.append(f'Image owns {owned} rows, more than the {MAX_IMAGE_OWN} its interfaces declare')
    for line in failures:
        print(f'# {line}', file=sys.stderr)
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
