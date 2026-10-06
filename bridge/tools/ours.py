#!/usr/bin/env python3
"""ours.py: the members our module declares, per type, from eidolon/Sources/SwiftUI/*.swift.
One line per declaration: type, kind, name. A source-level stand-in for the digester dump,
used while the module is still building.

Two things it gets right that it did not before, and both cost a review:
  * an enum's `case` is a member in every reading - it is written under the enum's name, and Apple
    declares it as a `case` or a `static`, so it is recorded as all three;
  * a `typealias` is a declaration of the name it binds, and the thing it binds counts as declared
    too, so a type we only alias is not reported as one we lack."""
import re, glob, sys, os

KIND = r'(?:struct|class|enum|protocol|typealias|actor)'
# the modules a name may be written with, and which the owner keeps no part of
MODULES = {'Swift', 'SwiftUI', 'SwiftUICore', 'Foundation', 'UIKit', 'Combine'}

def braces(line, in_block, in_multiline, hashes):
    # The braces a line really opens and closes.
    #
    # Counting them with `count('{')` is wrong the moment a string or a comment carries one, and from that
    # line on the walk sits at the wrong depth and attributes nothing after it. So the line is read as
    # Swift: a line comment, a block comment, a plain string, a multi-line one and a raw one with any
    # number of hashes carry no brace, and a block comment or a multi-line literal carries its state on.

    # Returns (opened, closed, in_block, in_multiline, hashes).
    opened = closed = 0
    i, n = 0, len(line)
    while i < n:
        if in_block:
            if line.startswith('*/', i):
                in_block = False
                i += 2
            else:
                i += 1
            continue
        if in_multiline:
            closing = ('#' * hashes + '"""') if hashes else '"""'
            if line.startswith(closing, i):
                in_multiline = False
                i += len(closing)
                continue
            i += 1
            continue
        if line.startswith('//', i):
            break
        if line.startswith('/*', i):
            in_block = True
            i += 2
            continue
        if line[i] == '#':
            run = 0
            while i + run < n and line[i + run] == '#':
                run += 1
            if i + run < n and line[i + run] == '"':
                hashes = run
                i += run + 1
                if line.startswith('"""', i):
                    in_multiline = True
                    i += 3
                    continue
                closing = '#' * hashes + '"'
                end = line.find(closing, i)
                i = n if end < 0 else end + len(closing)
                continue
            i += run
            continue
        if line[i] == '"':
            if line.startswith('"""', i):
                in_multiline = True
                i += 3
                continue
            i += 1
            while i < n:
                if line[i] == chr(92):
                    i += 2
                    continue
                if line[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if line[i] == '{':
            opened += 1
        elif line[i] == '}':
            closed += 1
        i += 1
    return opened, closed, in_block, in_multiline, hashes

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
files = sorted(glob.glob(os.path.join(root, 'eidolon/Sources/SwiftUI/*.swift')))

out = []
for path in files:
    lines = open(path).read().split('\n')
    depth = 0
    owner = None
    in_block = False
    in_multiline = False
    hashes = 0
    for line in lines:
        s = line.strip()
        if depth == 0:
            m = re.match(r'(?:public |internal |private |fileprivate |open |final |@frozen |indirect )*' + KIND + r'\s+(\w+)', s)
            if m:
                owner = m.group(1)
                out.append((owner, 'type', m.group(1), os.path.basename(path)))
                # a one-line type body - `enum X { case a, b }` - is all on this line, so its members are
                # read here and not at depth one, which it never reaches
                if '{' in s and '}' in s[s.index('{') + 1:]:
                    inline = s[s.index('{') + 1:s.rindex('}')]
                    for names in re.findall(r'\bcase ([\w,` ]+)$', inline.strip()):
                        for name in [n.strip().strip('`') for n in names.split(',') if n.strip()]:
                            out.append((owner, 'const', name, os.path.basename(path)))
                            out.append((owner, 'var', name, os.path.basename(path)))
                            out.append((owner, 'func', name, os.path.basename(path)))
                    for name in re.findall(r'\bstatic (?:let|var|func)\s+(\w+)', inline):
                        out.append((owner, 'var', name, os.path.basename(path)))
                    alias = re.search(KIND + r'\s+(\w+)\s*=\s*(\w+)', inline)
                    if alias:
                        out.append((owner, 'type', alias.group(2), os.path.basename(path)))
            else:
                m = re.match(r'extension\s+([\w.]+)', s)
                if m:
                    # the whole extended name without its module, so a member of `Anchor.Source` is
                    # recorded under `Anchor.Source` and not under `Source`
                    extended = m.group(1)
                    owner = extended.split('.', 1)[1] if extended.split('.', 1)[0] in MODULES else extended
                else:
                    owner = None
        elif re.match(r'extension\s+[\w.]+', s):
            # An `extension` line opens a new section wherever it stands, and the walk reaches it at
            # whatever depth the file has drifted to - TextModifiers.swift:168 is one. The owner is the
            # whole extended name without its module, so a member of `Anchor.Source` is recorded under
            # `Anchor.Source` and not under `Source`, which is what a name that belongs to neither the
            # type nor its nested type would look like.
            extended = re.match(r'extension\s+([\w.]+)', s).group(1)
            owner = extended.split('.', 1)[1] if extended.split('.', 1)[0] in MODULES else extended
        elif owner and s and not s.startswith('//') and s not in ('{', '}', 'get', 'set', 'get set', 'willSet', 'didSet'):
            body = s[:s.index('{')] if '{' in s else s
            if re.search(r'\bfunc (\w+)', body):
                out.append((owner, 'func', re.search(r'\bfunc (\w+)', body).group(1), os.path.basename(path)))
            elif re.search(r'\binit\b', body):
                out.append((owner, 'init', 'init', os.path.basename(path)))
            elif re.search(r'\bvar (\w+)', body):
                out.append((owner, 'var', re.search(r'\bvar (\w+)', body).group(1), os.path.basename(path)))
            elif re.search(r'\blet (\w+)', body):
                out.append((owner, 'var', re.search(r'\blet (\w+)', body).group(1), os.path.basename(path)))
            elif re.search(r'\bcase (\w+)', body):
                # Apple's declares a case as a `case` or as a `static`, so it counts as either, and a
                # case list on one line is every name in it, not only the first
                for case in re.findall(r'\bcase ([\w, ]+)$', body.strip()):
                    for name in [part.strip() for part in case.split(',') if part.strip()]:
                        out.append((owner, 'const', name, os.path.basename(path)))
                        out.append((owner, 'var', name, os.path.basename(path)))
                        out.append((owner, 'func', name, os.path.basename(path)))
            elif re.search(r'\bextension\s+([\w.]+)\s*:\s*(\w+)', s):
                # a conformance declares what the compiler synthesises from it, and no line of ours
                # shows those members: Hashable is hash(into:) and hashValue, Equatable is ==
                conformed, protocols = re.search(r'\bextension\s+([\w.]+)\s*:\s*([\w, ]+)', s).groups()
                # the whole extended name without its module: a member of `Anchor.Source` belongs to
                # `Anchor.Source`, not to `Source` and not to `Anchor`
                owner = conformed.split('.', 1)[1] if conformed.split('.', 1)[0] in MODULES else conformed
                if 'Hashable' in protocols:
                    out.append((owner, 'func', 'hash', os.path.basename(path)))
                    out.append((owner, 'var', 'hashValue', os.path.basename(path)))
                if 'Equatable' in protocols:
                    out.append((owner, 'func', '==', os.path.basename(path)))
            elif re.search(r'\bsubscript\b', body):
                out.append((owner, 'subscript', 'subscript', os.path.basename(path)))
            elif re.search(KIND + r'\s+(\w+)', body):
                out.append((owner, 'type', re.search(KIND + r'\s+(\w+)', body).group(1), os.path.basename(path)))
            elif re.match(r'\s*typealias\s+(\w+)\s*=\s*(\w+)', body):
                # a type we alias is declared: the alias is the name, and what it binds is declared too
                alias, target = re.match(r'\s*typealias\s+(\w+)\s*=\s*(\w+)', body).groups()
                out.append((owner, 'type', alias, os.path.basename(path)))
                out.append(('', 'type', target, os.path.basename(path)))
        opened, closed, in_block, in_multiline, hashes = braces(s, in_block, in_multiline, hashes)
        depth += opened - closed
        if depth == 0:
            owner = None
for owner, kind, name, path in out:
    print(f'{owner}\t{kind}\t{name}\t{path}')
