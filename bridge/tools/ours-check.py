#!/usr/bin/env python3
"""ours-check.py: the two controls the brace tokenizer in ours.py has to pass.

1. An `Anchor.Source` extension — TextModifiers.swift:168 — must produce `bounds` and `rect`, which a
   walk at the wrong depth attributes to nothing.
2. A brace inside a string, a raw string, a line comment and a block comment must not move the depth; a
   real brace must.

Usage: ours-check.py
"""
import importlib.util
import io
import contextlib
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('oursmod', os.path.join(here, 'ours.py'))
ours = importlib.util.module_from_spec(spec)
# ours.py walks the tree on import; its output is the other check and is wanted here too
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(ours)

failures = []


def check(what, got, want):
    if got != want:
        failures.append(f'{what}: got {got}, want {want}')
    print(f'{"ok  " if got == want else "FAIL"} {what}: {got}')


# control 2, the tokenizer itself
check('a string carrying a brace', ours.braces('    let s = "a { b"', False, False, 0)[0], 0)
check('a raw string carrying a brace', ours.braces('    let s = #"a { b"#', False, False, 0)[0], 0)
check('a brace in a line comment', ours.braces('    // a { b', False, False, 0)[0], 0)
check('a brace in a block comment', ours.braces('    /* a { b */', False, False, 0)[0], 0)
check('a real brace', ours.braces('    struct X {', False, False, 0)[0], 1)

# control 1, the walk itself: TextModifiers.swift:168 declares bounds and rect on Anchor.Source
out = ours.out
# the owner is the whole extended name: `Anchor.Source`, not `Source` and not `Anchor`
def owned_by(owner, kind, name):
    return any(o == 'Anchor.Source' and k == kind and n == name for o, k, n, _ in out)

source_bounds = owned_by('Anchor.Source', 'var', 'bounds')
source_rect = owned_by('Anchor.Source', 'func', 'rect')
stray = [o for o, k, n, _ in out if n in ('bounds', 'rect') and o != 'Anchor.Source' and o.endswith('Source')]
print(f'{"ok  " if source_bounds else "FAIL"} Anchor.Source has bounds (TextModifiers.swift:168)')
print(f'{"ok  " if source_rect else "FAIL"} Anchor.Source has rect (TextModifiers.swift:168)')
print(f'{"ok  " if not stray else "FAIL"} and no other owner claims them: {stray}')
if not (source_bounds and source_rect):
    failures.append('the Anchor.Source extension at TextModifiers.swift:168 produced neither bounds nor rect')
if stray:
    failures.append(f'bounds or rect is filed under {stray}, not under Anchor.Source')

for line in failures:
    print(f'# {line}', file=sys.stderr)
print(f'# {7 - len(failures)} of 7 controls passed', file=sys.stderr)
sys.exit(1 if failures else 0)
