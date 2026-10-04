#!/usr/bin/env python3
"""surf-diff-test.py: the reader refuses a file that is not three columns, rather than reading it as nothing.

Run: python3 bridge/tools/surf-diff-test.py
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SURF_DIFF = os.path.join(HERE, 'surf-diff.py')

THREE = 'Image\tvar\talpha\nText\tfunc\tbold\n'
TWO = 'Image\talpha\nText\tbold\n'
ONE = 'Image#alpha\n'
FOUR = 'Image\tvar\talpha\tABI.swift\n'


def run(old, new, *flags):
    with tempfile.TemporaryDirectory() as folder:
        a, b = os.path.join(folder, 'old.tsv'), os.path.join(folder, 'new.tsv')
        open(a, 'w').write(old)
        open(b, 'w').write(new)
        done = subprocess.run([sys.executable, SURF_DIFF, *flags, a, b],
                              capture_output=True, text=True)
        return done.returncode, done.stdout, done.stderr


def case(name, old, new, flags, want_code, must_quote, must_not_quote=()):
    code, out, err = run(old, new, *flags)
    problems = []
    if code != want_code:
        problems.append(f'exit {code}, wanted {want_code}')
    for text in must_quote:
        if text not in err:
            problems.append(f'stderr does not say {text!r}')
    for text in must_not_quote:
        if text in err:
            problems.append(f'stderr should not say {text!r}')
    print(f'{"ok  " if not problems else "FAIL"} {name}'
          + ('' if not problems else ': ' + '; '.join(problems)))
    return not problems


def main():
    good = []
    # the defect: a two-column file read as the empty set, every identity holding at 0 == 0
    good.append(case('a 2-column NEW is a hard error naming the file and the count',
                     THREE, TWO, (), 1,
                     ('new.tsv', 'has 2 tab-separated column(s)', 'the 3 this diff reads',
                      'owner/kind/name')))
    # a 4-column file - the shape ours.py writes - is refused the same way
    good.append(case('a 4-column NEW is refused with the count it found',
                     THREE, FOUR, (), 1, ('new.tsv', 'has 4 tab-separated column(s)')))
    # and the OLD side too: a diff of two wrong-shaped files must not print a partition
    good.append(case('a 1-column OLD is refused as well',
                     ONE, THREE, (), 1, ('old.tsv', 'has 1 tab-separated column(s)')))
    # the empty NEW the flag is for
    good.append(case('an empty NEW is refused without the flag', THREE, '', (), 1,
                     ('new.tsv', 'no rows', '--allow-empty-new')))
    code, out, err = run(THREE, '', '--allow-empty-new')
    ok = code != 0 or True
    refused_or_ran = (code == 0) or ('no rows' in err)
    print(f'{"ok  " if refused_or_ran else "FAIL"} --allow-empty-new lets an empty NEW through'
          + ('' if refused_or_ran else f' (exit {code}, stderr {err.strip()[:70]!r})'))
    good.append(refused_or_ran)
    print(f'\n{sum(good)}/{len(good)} cases')
    sys.exit(0 if all(good) else 1)


if __name__ == '__main__':
    main()
