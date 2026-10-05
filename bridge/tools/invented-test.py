#!/usr/bin/env python3
"""invented-test.py: api-invented.py reports declarations the port invented, and only declarations.

Run: python3 bridge/tools/invented-test.py

Each case writes a digester dump of a module (the shape swift-api-digester prints) and a surface
file of the Apple side, runs the gate on them and compares what it prints with what it must print.
Every case has its control: the gate has to keep reporting a declaration that is invented, or a
case that passes by the gate saying nothing would pass too.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
GATE = os.path.join(HERE, '..', 'api-invented.py')


def decl(kind, name, decl_kind, children=()):
    return {'kind': kind, 'name': name, 'printedName': name, 'declKind': decl_kind, 'children': list(children)}


def reference(name, printed):
    # a use of a type in a signature: no declKind, no usr, a printed name qualified by its module
    return {'kind': 'TypeNameAlias', 'name': name, 'printedName': printed}


def dump(*members):
    return {'ABIRoot': {'kind': 'Root', 'name': 'SwiftUI', 'printedName': 'SwiftUI',
                        'children': [decl('TypeDecl', 'Widget', 'Struct', members)]}}


def run(module, surface):
    with tempfile.TemporaryDirectory() as folder:
        ours, apple = os.path.join(folder, 'ours.json'), os.path.join(folder, 'apple.tsv')
        json.dump(module, open(ours, 'w'))
        open(apple, 'w').write(surface)
        done = subprocess.run([sys.executable, GATE, ours], capture_output=True, text=True,
                              env=dict(os.environ, APPLE_26_SURFACE=apple))
        names = [line.split()[-1] for line in done.stdout.splitlines() if line.strip()]
        return done.returncode, names


def case(name, module, surface, want, control=False):
    code, names = run(module, surface)
    # a control asks only that the declaration is still reported; the others ask for exactly what is
    ok = code == 0 and (set(want) <= set(names) if control else sorted(names) == sorted(want))
    print(f'{"ok  " if ok else "FAIL"} {name}' + ('' if ok else f': exit {code}, reported {names}, wanted {want}'))
    return ok


def main():
    surface = '\tWidget\t\ttype\nWidget\tknown\t\tvar.var\n'
    good = []
    good.append(case('control: a member Apple does not declare is reported',
                     dump(decl('Var', 'invention', 'Var')), surface, ['invention'], control=True))
    good.append(case('control: a typealias Apple does not declare is reported',
                     dump(decl('TypeAlias', 'InventedAlias', 'TypeAlias')), surface, ['InventedAlias'], control=True))
    good.append(case('a use of Swift.Void in a signature is a reference, not a declaration',
                     dump(decl('Function', 'known(action:)', 'Func', [reference('Void', 'Swift.Void')])),
                     surface, []))
    good.append(case('a use of a nested alias in a signature is a reference, not a declaration',
                     dump(decl('Function', 'known(style:)', 'Func', [reference('Configuration', 'Self.Configuration')])),
                     surface, []))
    good.append(case('the module root is not a declaration of the module',
                     dump(), surface, []))
    # the surface is read from the source text, where a member named for a keyword is written in backticks;
    # the dump writes the same member without them
    keyword = 'Widget\t`default`\t\tvar.let\nWidget\t`repeat`\t\tvar.var\n'
    good.append(case('a member named for a keyword matches the one the surface writes in backticks',
                     dump(decl('Var', 'default', 'Var'), decl('Var', 'repeat', 'Var')), surface + keyword, []))
    good.append(case('control: a keyword-named member the surface lacks is still reported',
                     dump(decl('Var', 'default', 'Var')), surface, ['default'], control=True))
    print(f'\n{sum(good)}/{len(good)} cases')
    sys.exit(0 if all(good) else 1)


if __name__ == '__main__':
    main()
