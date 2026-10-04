#!/usr/bin/env python3
"""ours.py: the members our module declares, per type, from eidolon/Sources/SwiftUI/*.swift.
One line per declaration: type, kind, name. A source-level stand-in for the digester dump,
used while the module is still building.

Two things it gets right that it did not before, and both cost a review:
  * an enum's `case` is a member in every reading — it is written under the enum's name, and Apple
    declares it as a `case` or a `static`, so it is recorded as all three;
  * a `typealias` is a declaration of the name it binds, and the thing it binds counts as declared
    too, so a type we only alias is not reported as one we lack."""
import re, glob, sys, os

KIND = r'(?:struct|class|enum|protocol|typealias|actor)'
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
files = sorted(glob.glob(os.path.join(root, 'eidolon/Sources/SwiftUI/*.swift')))

out = []
for path in files:
    lines = open(path).read().split('\n')
    depth = 0
    owner = None
    for line in lines:
        s = line.strip()
        if depth == 0:
            m = re.match(r'(?:public |internal |private |fileprivate |open |final |@frozen |indirect )*' + KIND + r'\s+(\w+)', s)
            if m:
                owner = m.group(1)
                out.append((owner, 'type', m.group(1), os.path.basename(path)))
                # a one-line type body — `enum X { case a, b }` — is all on this line, so its members are
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
                    owner = m.group(1).split('.')[-1]
                else:
                    owner = None
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
            elif re.search(r'\bsubscript\b', body):
                out.append((owner, 'subscript', 'subscript', os.path.basename(path)))
            elif re.search(KIND + r'\s+(\w+)', body):
                out.append((owner, 'type', re.search(KIND + r'\s+(\w+)', body).group(1), os.path.basename(path)))
            elif re.match(r'\s*typealias\s+(\w+)\s*=\s*(\w+)', body):
                # a type we alias is declared: the alias is the name, and what it binds is declared too
                alias, target = re.match(r'\s*typealias\s+(\w+)\s*=\s*(\w+)', body).groups()
                out.append((owner, 'type', alias, os.path.basename(path)))
                out.append(('', 'type', target, os.path.basename(path)))
        depth += line.count('{') - line.count('}')
        if depth == 0:
            owner = None
for owner, kind, name, path in out:
    print(f'{owner}\t{kind}\t{name}\t{path}')
