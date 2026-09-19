import json, sys, glob
graph = json.load(open(sys.argv[1]))
syms = {s['identifier']['precise']: s for s in graph['symbols']}
parent, members = {}, {}
for r in graph['relationships']:
    if r['kind'] == 'inheritsFrom':
        parent[r['source']] = r['target']
    elif r['kind'] == 'memberOf':
        members.setdefault(r['target'], []).append(r['source'])
def is_case(c, seen=0):
    while c in parent:
        c = parent[c]
        if c.endswith('6XCTest0A4CaseC') or c == 's:6XCTest0A4CaseC':
            return True
    return False
out, n = [], 0
for cid, s in sorted(syms.items(), key=lambda kv: kv[1]['names']['title']):
    if s['kind']['identifier'] != 'swift.class' or not is_case(cid):
        continue
    frags = ''.join(f['spelling'] for f in s.get('declarationFragments', []))
    cname = s['names']['title']
    for mid in sorted(members.get(cid, []), key=lambda m: syms[m]['names']['title'] if m in syms else ''):
        m = syms.get(mid)
        if not m or m['kind']['identifier'] != 'swift.method':
            continue
        t = m['names']['title']
        if not t.startswith('test') or not t.endswith('()'):
            continue
        d = ''.join(f['spelling'] for f in m.get('declarationFragments', []))
        name = t[:-2]
        if ' async' in d:
            out.append(f'// async test skipped: {cname}.{name}')
            continue
        out.append(f'_runTest({cname}.self, "{name}") {{ $0.{name} }}')
        n += 1
out.append('exit(_finishTests())')
open(sys.argv[2], 'w').write('import XCTest\nimport Foundation\n' + '\n'.join(out) + '\n')
print(f'{n} tests')
