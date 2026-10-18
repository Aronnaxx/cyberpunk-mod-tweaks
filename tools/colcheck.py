import json, os, sys, collections, re
SP = os.path.dirname(os.path.abspath(__file__))
GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
STAGE = r'C:\Users\wyant\AppData\Roaming\Vortex\cyberpunk2077\mods'

COLS = {'iszwwe': 'WTNC', 'rcuccp': 'NCR Core', 'srpv39': 'NCR Extras', 'vfy7w1': 'NCR Body'}
colmods = collections.defaultdict(set)   # modId -> set of collection names
catof, nameof = {}, {}
for slug, cname in COLS.items():
    d = json.load(open(os.path.join(SP, f'col_{slug}.json'), encoding='utf-8'))
    for mf in d['data']['collectionRevision']['modFiles']:
        f = mf['file']
        if not f: continue
        colmods[f['modId']].add(cname)
        catof[f['modId']] = (f.get('mod') or {}).get('category')
        nameof[f['modId']] = (f.get('mod') or {}).get('name')

st = json.load(open(os.path.join(SP, 'mods_now.json'), encoding='utf-8'))
modid = {}
for k, v in st.items():
    p = k.split('###')
    if len(p) == 6 and p[4] == 'attributes' and p[5] == 'modId':
        try: modid[p[3]] = int(json.loads(v))
        except Exception: pass

dep = json.load(open(os.path.join(GAME, 'vortex.deployment.json'), encoding='utf-8'))
deployed = collections.defaultdict(list)
winner = {}
for f in dep['files']:
    deployed[f['source']].append(f['relPath'].lower())
    winner[f['relPath'].lower()] = f['source']

# installed+deployed mods that belong to WTNC/NCR
inset = {m: colmods[modid[m]] for m in deployed if m in modid and modid[m] in colmods}
print('deployed mods:', len(deployed), ' in WTNC/NCR lists:', len(inset))
cnt = collections.Counter()
for m, cs in inset.items():
    for c in cs: cnt[c] += 1
print('by collection:', dict(cnt))
print('in both WTNC and some NCR:', sum(1 for cs in inset.values() if 'WTNC' in cs and len(cs) > 1))
catc = collections.Counter(catof.get(modid[m]) for m in inset)
print('categories:', catc.most_common())

# file overlap: walk staging folder of every deployed mod (all mods, so we also see clashes with non-collection mods)
owners = collections.defaultdict(set)
for m in deployed:
    root = os.path.join(STAGE, m)
    for dp, dn, fn in os.walk(root):
        for x in fn:
            rel = os.path.relpath(os.path.join(dp, x), root).lower()
            if rel.startswith('fomod') or x.lower() in ('__folder_managed_by_vortex',) or rel.endswith(('.txt', '.md', '.png', '.jpg', '.pdf', '.url')) or '\\' not in rel:
                continue
            owners[rel].add(m)
clash = {p: ms for p, ms in owners.items() if len(ms) > 1}
pairs = collections.defaultdict(list)
for p, ms in clash.items():
    if not any(m in inset for m in ms): continue
    pairs[tuple(sorted(ms))].append(p)
out = []
for ms, ps in sorted(pairs.items(), key=lambda x: -len(x[1])):
    out.append({'mods': list(ms), 'collections': {m: sorted(inset.get(m, [])) for m in ms},
                'files': sorted(ps), 'winner': {p: winner.get(p) for p in ps[:5]}})
json.dump(out, open(os.path.join(SP, 'col_clashes.json'), 'w'), indent=1)
json.dump({m: sorted(c) for m, c in inset.items()}, open(os.path.join(SP, 'col_members.json'), 'w'), indent=1)
print('clash groups touching collection mods:', len(out))
for o in out[:60]:
    print(len(o['files']), '|', ' <> '.join(o['mods']), '|', o['files'][0])
