import json, os, re, collections
SP = os.path.dirname(os.path.abspath(__file__))
GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
members = json.load(open(os.path.join(SP, 'col_members.json'), encoding='utf-8'))
dep = json.load(open(os.path.join(GAME, 'vortex.deployment.json'), encoding='utf-8'))
src = {f['relPath'].lower(): f['source'] for f in dep['files']}
log = open(os.path.join(GAME, 'r6', 'logs', 'redscript_rCURRENT.log'), encoding='utf-8', errors='ignore').read()

def mod_of(path):
    p = path.lower()
    i = p.find('cyberpunk 2077\\')
    rel = p[i + len('cyberpunk 2077\\'):] if i >= 0 else p
    return src.get(rel, '(unmanaged) ' + rel)

# every @replaceMethod / @wrapMethod in deployed scripts -> (class, method) -> mods
ann = collections.defaultdict(list)
rx = re.compile(r'@(replaceMethod|wrapMethod)\((\w+)\)\s*(?:@\w+(?:\([^)]*\))?\s*)*[^\n]*?func\s+(\w+)')
for root in [os.path.join(GAME, 'r6', 'scripts'), os.path.join(GAME, 'red4ext', 'plugins')]:
    for dp, dn, fn in os.walk(root):
        for x in fn:
            if not x.endswith('.reds'): continue
            p = os.path.join(dp, x)
            t = open(p, encoding='utf-8', errors='ignore').read()
            t = re.sub(r'//[^\n]*', '', t)
            for kind, cls, meth in rx.findall(t):
                ann[(cls, meth)].append((kind, mod_of(p)))
rows = []
for (cls, meth), lst in ann.items():
    reps = sorted({m for k, m in lst if k == 'replaceMethod'})
    wraps = sorted({m for k, m in lst if k == 'wrapMethod'})
    allm = set(reps) | set(wraps)
    if len(reps) >= 2 or (reps and wraps):
        if not any(m in members for m in allm): continue
        rows.append({'method': f'{cls}.{meth}', 'replace': reps, 'wrap': wraps,
                     'cols': {m: members.get(m, []) for m in allm}})
rows.sort(key=lambda r: (-len(r['replace']), r['method']))
json.dump(rows, open(os.path.join(SP, 'col_reds.json'), 'w'), indent=1)
print('methods with a replace clash touching collection mods:', len(rows))
for r in rows:
    tag = 'REPLACE x%d' % len(r['replace']) if len(r['replace']) > 1 else 'replace+wrap'
    print(tag, '|', r['method'], '| R:', [m[:40] for m in r['replace']], '| W:', [m[:30] for m in r['wrap']][:4])
