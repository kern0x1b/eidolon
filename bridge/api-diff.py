#!/usr/bin/env python3
"""api-diff.py: the typed API surface of Eidolon against Apple's SwiftUI, from two swift-api-digester dumps.

    api-diff.py apple.json ours.json [--conformances] [--variants] [--type NAME]

Apple's dump is taken from the SDK's SwiftUI interface for iOS 16.4 (so what is unavailable on iOS is not in it);
ours is taken from the module this repository builds. A declaration of Apple's counts as missing when no declaration
with the same USR exists in ours; it is then told apart as
  absent   nothing of that name on that type in ours,
  variant  a declaration of that name exists there but with another signature (an overload, a constraint, an attribute).
Names starting with an underscore and implicit (compiler-made) declarations are left out.
"""
import collections
import json
import os
import re
import sys


def walk(node, path, out):
    """Every node with a USR, with the names of the types it is nested in."""
    if not isinstance(node, dict):
        return
    if node.get('usr') and node.get('declKind'):
        out.append((tuple(path), node))
    nested = path + [node.get('name') or node.get('printedName') or ''] if node.get('kind') == 'TypeDecl' else path
    for child in node.get('children', []):
        walk(child, nested, out)


def load(file):
    root = json.load(open(file))['ABIRoot']
    found = []
    walk(root, [], found)
    return found


def split_name(printed):
    """'init(_:text:onCommit:)' -> ('init', ['_', 'text', 'onCommit'])"""
    match = re.match(r'^([^(]+)\((.*)\)$', printed)
    if not match:
        return None, []
    labels = [l for l in match.group(2).split(':') if l != ''] if match.group(2) else []
    return match.group(1), labels


def covered_by_defaults(ours_shapes, owner, printed):
    """A call written the way Apple's declaration reads compiles against one of ours whose extra parameters have
    defaults: the labels of Apple's are a subsequence of ours, in order, and every other label of ours has a default."""
    base, wanted = split_name(printed)
    if not base:
        return False
    for shape in ours_shapes.get((owner, base), []):
        index = 0
        extras_default = True
        for label, has_default in shape:
            if index < len(wanted) and label == wanted[index]:
                index += 1
            elif not has_default:
                extras_default = False
        if index == len(wanted) and extras_default:
            return True
    return False


def signature(node):
    parts = [c.get('printedName', '') for c in node.get('children', []) if c.get('kind', '').startswith('Type')]
    return ' -> '.join(parts[1:]) if len(parts) > 1 else ''


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    flags = [a for a in sys.argv[1:] if a.startswith('--')]
    only = None
    if '--type' in flags:
        only = sys.argv[sys.argv.index('--type') + 1]
        args = [a for a in args if a != only]
    apple = load(args[0])
    ours = load(args[1])
    ours_usr = {n.get('usr') for _, n in ours if n.get('usr')}
    ours_names = collections.defaultdict(set)
    ours_shapes = collections.defaultdict(list)
    for path, node in ours:
        ours_names[(path[-1] if path else '', node.get('printedName', ''))].add(node.get('usr'))
        base, labels = split_name(node.get('printedName', ''))
        params = [c for c in node.get('children', []) if c.get('kind', '').startswith('Type')][1:]
        if base and len(params) == len(labels):
            ours_shapes[(path[-1] if path else '', base)].append([(label, bool(p.get('hasDefaultArg'))) for label, p in zip(labels, params)])

    not_applicable = {}
    listed = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'not-applicable.txt')
    if os.path.exists(listed):
        for line in open(listed):
            if line.strip() and not line.startswith('#'):
                name, _, reason = line.rstrip('\n').partition('\t')
                not_applicable[name] = reason

    missing = collections.defaultdict(list)
    for path, node in apple:
        usr = node.get('usr')
        if not usr or usr in ours_usr or node.get('implicit'):
            continue
        printed = node.get('printedName', '')
        if printed.startswith('_') or re.match(r'^(init\(_:\)|)$', printed) and False:
            continue
        if any(p.startswith('_') for p in path):
            continue
        owner = path[-1] if path else ''
        if only and owner != only:
            continue
        kind = node.get('declKind') or node.get('kind')
        if kind in ('Accessor',):
            continue
        if kind in ('Func', 'Constructor') and covered_by_defaults(ours_shapes, owner, printed):
            continue
        state = 'variant' if ours_names.get((owner, printed)) else 'absent'
        member = f'{owner}#{printed.split("(")[0]}'
        if state == 'absent' and (owner in not_applicable or member in not_applicable):
            state = 'not-applicable'
        missing[owner].append((state, kind, printed, signature(node)))

    total = collections.Counter()
    for owner, items in sorted(missing.items(), key=lambda kv: -len(kv[1])):
        for state, kind, printed, sig in sorted(items):
            total[state] += 1
            if '--variants' in flags or state == 'absent' or (state == 'not-applicable' and '--not-applicable' in flags):
                print(f'{owner}\t{state}\t{kind}\t{printed}\t{sig}')
    print(f'# absent {total["absent"]}, variant {total["variant"]}, not applicable {total["not-applicable"]} (bridge/not-applicable.txt, with reasons)', file=sys.stderr)
    used = set()
    for owner, items in missing.items():
        for state, kind, printed, sig in items:
            if state == 'not-applicable':
                used.add(owner if owner in not_applicable else f'{owner}#{printed.split("(")[0]}')
    unused = sorted(set(not_applicable) - used)
    if unused:
        print('# not-applicable.txt names types with nothing absent (remove them): ' + ', '.join(unused), file=sys.stderr)

    if '--conformances' in flags:
        ours_conf = collections.defaultdict(set)
        for path, node in ours:
            if node.get('declKind') in ('Struct', 'Class', 'Enum', 'Protocol'):
                ours_conf[node.get('printedName')].update(c.get('printedName') for c in node.get('conformances', []))
        for path, node in apple:
            if node.get('declKind') in ('Struct', 'Class', 'Enum'):
                name = node.get('printedName')
                gap = sorted({c.get('printedName') for c in node.get('conformances', [])} - ours_conf.get(name, set()) - {n for n in ()})
                gap = [g for g in gap if not g.startswith('_') and g not in ('Copyable', 'Escapable', 'Sendable', 'BitwiseCopyable')]
                if gap and (not only or name == only):
                    print(f'CONFORMANCE\t{name}\t{", ".join(gap)}')


if __name__ == '__main__':
    main()
