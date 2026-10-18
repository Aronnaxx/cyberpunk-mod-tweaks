import json, os, struct, collections, re
SP = os.path.dirname(os.path.abspath(__file__))
GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
members = json.load(open(os.path.join(SP, 'col_members.json'), encoding='utf-8'))
dep = json.load(open(os.path.join(GAME, 'vortex.deployment.json'), encoding='utf-8'))
src = {f['relPath'].lower(): f['source'] for f in dep['files']}

def archive_hashes(path):
    with open(path, 'rb') as fh:
        h = fh.read(40)
        if h[:4] != b'RDAR': return set()
        idx_pos, idx_size = struct.unpack_from('<QI', h, 8)
        fh.seek(idx_pos)
        idx = fh.read(idx_size)
    n = struct.unpack_from('<I', idx, 16)[0]
    base = 28
    return {struct.unpack_from('<Q', idx, base + i * 56)[0] for i in range(n)}

# vanilla hashes, to tell "replaces a game file" from "adds a new file"
vanilla = set()
for f in os.listdir(os.path.join(GAME, 'archive', 'pc', 'content')) + [('ep1\\' + x) for x in os.listdir(os.path.join(GAME, 'archive', 'pc', 'ep1'))]:
    p = os.path.join(GAME, 'archive', 'pc', 'content' if not f.startswith('ep1\\') else '', f) if not f.startswith('ep1\\') else os.path.join(GAME, 'archive', 'pc', f)
    if p.endswith('.archive'):
        try: vanilla |= archive_hashes(p)
        except Exception as e: print('vanilla fail', p, e)
print('vanilla hashes', len(vanilla))

modarch = os.path.join(GAME, 'archive', 'pc', 'mod')
names = sorted(x for x in os.listdir(modarch) if x.lower().endswith('.archive'))
load_order = {n: i for i, n in enumerate(names)}  # game loads mod archives in this order; first one wins a hash
owner = collections.defaultdict(list)
for n in names:
    m = src.get(('archive\\pc\\mod\\' + n).lower(), '?')
    try: hs = archive_hashes(os.path.join(modarch, n))
    except Exception as e: print('fail', n, e); continue
    for h in hs: owner[h].append((n, m))

pairs = collections.Counter(); pair_van = collections.Counter()
for h, lst in owner.items():
    mods = sorted({m for _, m in lst})
    if len(mods) < 2: continue
    if not any(m in members for m in mods): continue
    win = lst[0]  # first in load order
    for m in mods:
        if m == win[1]: continue
        k = (win[1], m)
        pairs[k] += 1
        if h in vanilla: pair_van[k] += 1
rows = []
for (w, l), c in pairs.most_common():
    rows.append({'winner': w, 'loser': l, 'shared': c, 'vanilla_replaced': pair_van[(w, l)],
                 'winner_cols': members.get(w, []), 'loser_cols': members.get(l, [])})
json.dump(rows, open(os.path.join(SP, 'col_archive_clash.json'), 'w'), indent=1)
print('archive overlap pairs:', len(rows))
for r in rows[:80]:
    print(r['shared'], r['vanilla_replaced'], '|', r['winner'][:55], '[', ','.join(r['winner_cols']), '] beats', r['loser'][:55], '[', ','.join(r['loser_cols']), ']')
