import json, os, struct, collections
SP = os.path.dirname(os.path.abspath(__file__))
GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
members = json.load(open(os.path.join(SP, 'col_members.json'), encoding='utf-8'))
dep = json.load(open(os.path.join(GAME, 'vortex.deployment.json'), encoding='utf-8'))
src = {f['relPath'].lower(): f['source'] for f in dep['files']}

def entries(path):
    with open(path, 'rb') as fh:
        h = fh.read(40)
        if h[:4] != b'RDAR': return {}
        idx_pos, idx_size = struct.unpack_from('<QI', h, 8)
        fh.seek(idx_pos); idx = fh.read(idx_size)
    n = struct.unpack_from('<I', idx, 16)[0]
    out = {}
    for i in range(n):
        o = 28 + i * 56
        out[struct.unpack_from('<Q', idx, o)[0]] = idx[o + 36:o + 56]
    return out

def fnv(s):
    h = 0xcbf29ce484222325
    for b in s.encode(): h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h
known = {}
for line in open(os.path.join(GAME, 'red4ext', 'plugins', 'Codeware', 'Data', 'KnownHashes.txt'), encoding='utf-8', errors='ignore'):
    p = line.strip().lower()
    if p: known[fnv(p)] = p

vanilla = set()
for sub in ('content', 'ep1'):
    d = os.path.join(GAME, 'archive', 'pc', sub)
    for f in os.listdir(d):
        if f.endswith('.archive'): vanilla |= set(entries(os.path.join(d, f)))

modarch = os.path.join(GAME, 'archive', 'pc', 'mod')
names = sorted(x for x in os.listdir(modarch) if x.lower().endswith('.archive'))
owner = collections.defaultdict(list)
for n in names:
    m = src.get(os.path.join('archive', 'pc', 'mod', n).lower(), '?')
    try:
        for h, sha in entries(os.path.join(modarch, n)).items(): owner[h].append((m, sha))
    except Exception as e: print('fail', n, e)

groups = collections.defaultdict(lambda: {'identical': 0, 'different': 0, 'vanilla': 0, 'named': []})
for h, lst in owner.items():
    mods = []
    for m, _ in lst:
        if m not in mods: mods.append(m)
    if len(mods) < 2 or not any(m in members for m in mods): continue
    shas = {sha for _, sha in lst}
    g = groups[tuple(mods)]
    if len(shas) == 1: g['identical'] += 1
    else:
        g['different'] += 1
        if h in vanilla: g['vanilla'] += 1
        if len(g['named']) < 3: g['named'].append(known.get(h, '#%016x' % h))
rows = [{'order': list(k), 'cols': {m: members.get(m, []) for m in k}, **v} for k, v in groups.items()]
rows.sort(key=lambda r: -r['different'])
json.dump(rows, open(os.path.join(SP, 'col_archive_sha.json'), 'w'), indent=1)
print('groups', len(rows), 'with real differences', sum(1 for r in rows if r['different']))
for r in rows:
    if r['different']:
        print(r['different'], 'diff', r['identical'], 'same', r['vanilla'], 'van |', ' > '.join(x[:40] for x in r['order']), '|', r['named'][:2])
