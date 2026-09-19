#!/usr/bin/env python3
"""coverage.py: сколько публичной поверхности SwiftUI покрыто нашей реализацией.

Эталон — интерфейс SwiftUI из SDK (списки в ../bridge/apple-types.txt и apple-view-modifiers.txt),
наша сторона — исходники Sources/SwiftUI.

  coverage.py             счёт
  coverage.py --missing   чего нет
  coverage.py --ignored   что объявлено и игнорируется
  coverage.py --pending   заглушки: объявлены, пишут в журнал, ждут реализации
  coverage.py --check     проверка для сборки: счёт не упал, README сходится, у каждого
                          игнорируемого API есть строка причины в README
  coverage.py --update    записать текущий счёт в coverage-baseline.json и в README
"""
import json
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))


def apple_surface():
    types = {}
    for line in open(os.path.join(here, '..', 'bridge', 'apple-types.txt')):
        name, kind = line.rstrip('\n').split('\t')
        types[name] = kind
    mods = [l.strip() for l in open(os.path.join(here, '..', 'bridge', 'apple-view-modifiers.txt')) if l.strip()]
    return types, mods


def ios_surface():
    names = lambda f: {l.strip() for l in open(os.path.join(here, '..', 'bridge', f)) if l.strip()}
    return names('apple-types-ios.txt'), names('apple-view-modifiers-ios.txt')


SCORE = r'\*\*(\d+) типов\*\* и \*\*(\d+) модификаторов\*\*, из них \*\*(\d+) действуют\*\*, (\d+) заглушки \(пишут в журнал\), (\d+) объявлены'
IOS_SCORE = r'Из того, что Apple объявляет доступным на iOS: \*\*(\d+) из (\d+) типов\*\* и \*\*(\d+) из (\d+) модификаторов\*\*, из них \*\*(\d+) действуют\*\*, (\d+) заглушки, (\d+) игнорируются'
IOS_SCORE_TEXT = 'Из того, что Apple объявляет доступным на iOS: **{ios_types} из {ios_apple_types} типов** и **{ios_mods} из {ios_apple_mods} модификаторов**, из них **{ios_working} действуют**, {ios_pending} заглушки, {ios_ignored} игнорируются'
SCORE_TEXT = '**{types} типов** и **{mods} модификаторов**, из них **{working} действуют**, {pending} заглушки (пишут в журнал), {ignored} объявлены'


def stub_calls():
    """Every call that writes to the journal, with what coverage makes of it: a counted modifier name, a partial
    note that the README must name, or a call the counter cannot read at all."""
    counted, partial, unreadable = [], [], []
    for root, _, files in os.walk(os.path.join(here, 'Sources', 'SwiftUI')):
        for name in sorted(files):
            if not name.endswith('.swift'):
                continue
            text = open(os.path.join(root, name)).read()
            for m in re.finditer(r'(?<!func )\b(unimplemented|ignored)\((.*)', text):
                literal = re.match(r'[^,"]+,\s*"([^"]*)"', m.group(2))
                where = f'{name}:{text.count(chr(10), 0, m.start()) + 1}'
                if not literal or not re.fullmatch(r'\w*', literal.group(1)):
                    unreadable.append((where, m.group(0).strip()[:80]))
                elif literal.group(1):
                    counted.append((m.group(1), literal.group(1)))
            for m in re.finditer(r'_Unsupported\.(pendingNote|note)\("([^"]*)"', text):
                head = re.match(r'[\w.]+(\([^)\\]*\))?', m.group(2))
                partial.append((m.group(1), head.group(0) if head else m.group(2), f'{name}:{text.count(chr(10), 0, m.start()) + 1}'))
    return counted, partial, unreadable


def ours():
    types, mods, ignored, pending = set(), set(), {}, set()
    for root, _, files in os.walk(os.path.join(here, 'Sources', 'SwiftUI')):
        for name in sorted(files):
            if not name.endswith('.swift'):
                continue
            text = open(os.path.join(root, name)).read()
            for m in re.finditer(r'public (?:@\w+\s+)*(struct|class|enum|protocol)\s+([A-Za-z_]\w*)', text):
                types.add(m.group(2))
            for m in re.finditer(r'(?:public )?typealias\s+([A-Za-z_]\w*)', text):
                types.add(m.group(1))
            for m in re.finditer(r'associatedtype\s+([A-Za-z_]\w*)', text):
                types.add(m.group(1))
            for m in re.finditer(r'ignored\(self, "(\w+)", "([^"]*)"\)', text):
                ignored[m.group(1)] = m.group(2)
            for m in re.finditer(r'unimplemented\(self, "(\w+)"\)', text):
                pending.add(m.group(1))
            in_view = False
            for line in text.split('\n'):
                e = re.match(r'extension ([\w.]+)', line)
                if e:
                    in_view = e.group(1) == 'View'
                if re.match(r'(public |final |)(struct|class|enum|protocol) ', line):
                    in_view = False
                f = re.match(r'    public func (\w+)', line)
                if f and in_view:
                    mods.add(f.group(1))
    return types, mods, ignored, pending - set(ignored)


def counts():
    apple_types, apple_mods = apple_surface()
    our_types, our_mods, ignored, pending = ours()
    covered_types = sorted(t for t in apple_types if t in our_types)
    covered_mods = sorted(m for m in apple_mods if m in our_mods)
    working = [m for m in covered_mods if m not in ignored and m not in pending]
    stubs = [m for m in covered_mods if m in pending]
    return {
        'apple_types': len(apple_types), 'types': len(covered_types),
        'apple_mods': len(apple_mods), 'mods': len(covered_mods),
        'working': len(working), 'pending': len(stubs), 'ignored': len(covered_mods) - len(working) - len(stubs),
        **ios_counts(our_types, covered_mods, working, stubs),
    }, apple_types, apple_mods, our_types, our_mods, ignored, stubs


def ios_counts(our_types, covered_mods, working, stubs):
    ios_types, ios_mods = ios_surface()
    mods = [m for m in covered_mods if m in ios_mods]
    work = [m for m in working if m in ios_mods]
    pend = [m for m in stubs if m in ios_mods]
    return {
        'ios_apple_types': len(ios_types), 'ios_types': len([t for t in ios_types if t in our_types]),
        'ios_apple_mods': len(ios_mods), 'ios_mods': len(mods),
        'ios_working': len(work), 'ios_pending': len(pend), 'ios_ignored': len(mods) - len(work) - len(pend),
    }


def main():
    numbers, apple_types, apple_mods, our_types, our_mods, ignored, stubs = counts()
    baseline_path = os.path.join(here, 'coverage-baseline.json')
    readme_path = os.path.join(here, 'README.md')

    if '--update' in sys.argv:
        json.dump(numbers, open(baseline_path, 'w'), indent=2)
        readme = open(readme_path).read()
        readme = re.sub(SCORE, SCORE_TEXT.format(**numbers), readme)
        readme = re.sub(IOS_SCORE, IOS_SCORE_TEXT.format(**numbers), readme)
        open(readme_path, 'w').write(readme)
        print('записано:', numbers)
        return 0

    if '--check' in sys.argv:
        problems = []
        if os.path.exists(baseline_path):
            baseline = json.load(open(baseline_path))
            for key in ('types', 'mods', 'working'):
                if numbers[key] < baseline[key]:
                    problems.append(f'{key}: было {baseline[key]}, стало {numbers[key]} — покрытие упало')
        readme = open(readme_path).read()
        ios_stated = re.search(IOS_SCORE, readme)
        if not ios_stated:
            problems.append('README не содержит строки со счётом для iOS')
        else:
            said = tuple(int(g) for g in ios_stated.groups())
            actual = tuple(numbers[k] for k in ('ios_types', 'ios_apple_types', 'ios_mods', 'ios_apple_mods', 'ios_working', 'ios_pending', 'ios_ignored'))
            if said != actual:
                problems.append(f'README для iOS говорит {said}, на деле {actual} — обновите README (coverage.py --update)')
        stated = re.search(SCORE, readme)
        if not stated:
            problems.append('README не содержит строки со счётом')
        else:
            said = tuple(int(g) for g in stated.groups())
            actual = (numbers['types'], numbers['mods'], numbers['working'], numbers['pending'], numbers['ignored'])
            if said != actual:
                problems.append(f'README говорит {said}, на деле {actual} — обновите README (coverage.py --update)')
        for name in sorted(ignored):
            if f'`{name}`' not in readme:
                problems.append(f'игнорируемый API {name} не описан в README')
        counted, partial, unreadable = stub_calls()
        for where, call in unreadable:
            problems.append(f'{where}: {call} — счётчик не может прочесть имя (нужна строка из одного идентификатора)')
        for kind, name, where in partial:
            if f'`{name}' not in readme:
                problems.append(f'{where}: частичный {"unimplemented" if kind == "pendingNote" else "ignored"} «{name}» не назван в README')
        if problems:
            print('coverage: проверка не прошла')
            for problem in problems:
                print(' -', problem)
            return 1
        print(f"coverage: типы {numbers['types']}/{numbers['apple_types']}, модификаторы {numbers['mods']}/{numbers['apple_mods']} "
              f"(действуют {numbers['working']}, заглушки {numbers['pending']}, игнорируются {numbers['ignored']}) — README сходится")
        return 0

    print(f"типы:         {numbers['types']} из {numbers['apple_types']}")
    print(f"модификаторы: {numbers['mods']} из {numbers['apple_mods']} (действуют {numbers['working']}, заглушки {numbers['pending']}, объявлены и игнорируются {numbers['ignored']})")
    if '--pending' in sys.argv:
        print('  ' + ', '.join(stubs))
    if '--ignored' in sys.argv:
        for name in sorted(ignored):
            print(f'  {name}: {ignored[name]}')
    if '--missing' in sys.argv:
        print('\nне покрыто (типы):')
        print(' ', ', '.join(t for t in apple_types if t not in our_types))
        print('\nне покрыто (модификаторы):')
        print(' ', ', '.join(m for m in apple_mods if m not in our_mods))
    return 0


sys.exit(main())
