import json, os, struct, collections
SP = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(SP, 'colcheck2.py')).read().split("# vanilla hashes")[0])

def fnv(s):
    h = 0xcbf29ce484222325
    for b in s.encode():
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h

known = {}
for line in open(os.path.join(GAME, 'red4ext', 'plugins', 'Codeware', 'Data', 'KnownHashes.txt'), encoding='utf-8', errors='ignore'):
    p = line.strip().lower()
    if p: known[fnv(p)] = p
modarch = os.path.join(GAME, 'archive', 'pc', 'mod')
names = sorted(x for x in os.listdir(modarch) if x.lower().endswith('.archive'))
owner = collections.defaultdict(list)
for n in names:
    m = src.get(os.path.join('archive', 'pc', 'mod', n).lower(), '?')
    try:
        for h in archive_hashes(os.path.join(modarch, n)): owner[h].append((n, m))
    except Exception: pass
out = collections.defaultdict(list)
for h, lst in owner.items():
    mods = []
    for n, m in lst:
        if m not in mods: mods.append(m)
    if len(mods) < 2 or not any(m in members for m in mods): continue
    out[' > '.join(mods)].append(known.get(h, '#%016x' % h))
res = sorted(out.items(), key=lambda x: -len(x[1]))
json.dump(res, open(os.path.join(SP, 'col_archive_named.json'), 'w'), indent=1)
for k, v in res:
    named = [x for x in v if not x.startswith('#')]
    print(len(v), len(named), '|', ' > '.join(x[:42] for x in k.split(' > ')), '|', named[:3])
