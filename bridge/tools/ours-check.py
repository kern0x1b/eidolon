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
source_bounds = any(owner.endswith('Source') and kind == 'var' and name == 'bounds' for owner, kind, name, _ in out)
source_rect = any(owner.endswith('Source') and kind == 'func' and name == 'rect' for owner, kind, name, _ in out)
print(f'{"ok  " if source_bounds else "FAIL"} Anchor.Source has bounds (TextModifiers.swift:168)')
print(f'{"ok  " if source_rect else "FAIL"} Anchor.Source has rect (TextModifiers.swift:168)')
if not (source_bounds and source_rect):
    failures.append('the Anchor.Source extension at TextModifiers.swift:168 produced neither bounds nor rect')

for line in failures:
    print(f'# {line}', file=sys.stderr)
print(f'# {5 + 2 - len(failures)} of {5 + 2} controls passed', file=sys.stderr)
sys.exit(1 if failures else 0)
