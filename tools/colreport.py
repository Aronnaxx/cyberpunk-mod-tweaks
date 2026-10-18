import json, os, collections, re
SP = os.path.dirname(os.path.abspath(__file__))
OUT = r'C:\Users\wyant\Documents\cyberpunk-mod-patches'
members = json.load(open(os.path.join(SP, 'col_members.json'), encoding='utf-8'))
files = json.load(open(os.path.join(SP, 'col_clashes.json'), encoding='utf-8'))
arch = json.load(open(os.path.join(SP, 'col_archive_sha.json'), encoding='utf-8'))
reds = json.load(open(os.path.join(SP, 'col_reds.json'), encoding='utf-8'))

def short(m):
    return re.sub(r'[- ]\d{3,}.*$', '', m).strip() or m

flag = collections.defaultdict(list)   # mod -> reasons
# file overrides: my own patches and known compat patches are intended
INTENDED = re.compile(r'(?i)-v\d+\.\d+$|compat|fix \(lhud\)|weave - equipment-ex|factions evolved')
file_rows = []
for f in files:
    intended = any(INTENDED.search(m) for m in f['mods'])
    file_rows.append((f, intended))
    if not intended:
        for m in f['mods']:
            flag[m].append('ships the same %d file(s) as %s' % (len(f['files']), ', '.join(short(x) for x in f['mods'] if x != m)))
arch_rows = [a for a in arch if a['different']]
for a in arch_rows:
    w = a['order'][0]
    for m in a['order'][1:]:
        flag[m].append('%d texture/mesh file(s) overridden by %s (load order)' % (a['different'], short(w)))
    flag[w].append('overrides %d file(s) of %s' % (a['different'], ', '.join(short(x) for x in a['order'][1:])))
rep_rows = [r for r in reds if len(r['replace']) > 1]
for r in rep_rows:
    for m in r['replace']:
        flag[m].append('replaces %s, so does %s (only one can be active)' % (r['method'], ', '.join(short(x) for x in r['replace'] if x != m)))

safe = sorted(m for m in members if m not in flag)
review = sorted(m for m in members if m in flag)
json.dump({'safe': safe, 'review': {m: flag[m] for m in review}}, open(os.path.join(OUT, 'collection-safety.json'), 'w'), indent=1)

md = ['# WTNC / NCR collection mods: conflict check (2026-10-07)', '',
      'Collections (Nexus, latest published): Welcome to Night City 2.31a (rev 481), NCR Core 2.31a (rev 189), NCR - Extras (rev 129), NCR - Body Add-on (rev 112).',
      'Matched by Nexus mod ID against what Vortex has deployed now: %d of 1287 deployed mods are in at least one of these lists.' % len(members), '',
      'Checks: (1) loose files two mods both ship, (2) .archive assets two mods both ship, compared by content hash (identical copies are not a conflict), (3) redscript @replaceMethod on the same game function (only one survives).',
      'Not checked: TweakXL record edits, CET/Lua behaviour, ArchiveXL .xl patches, runtime interactions.', '',
      '**SAFE: %d mods.** No conflict found at these levels.' % len(safe), '',
      '**Review: %d mods.** Listed below with the reason.' % len(review), '']
md += ['## Review list', '']
for m in review:
    md.append('- **%s** [%s]' % (short(m), ', '.join(members[m])))
    for r in sorted(set(flag[m])):
        md.append('  - ' + r)
md += ['', '## Overlaps that are fine', '',
       '- %d asset groups overlap but the copies are byte-identical (e.g. the Really Want To Stay At Your House set, Romanced Enhanced, Immersive Shower vs Apartment Cats, Night City Interactions districts).' % sum(1 for a in arch if not a['different']),
       '- Intended file overrides (patches/compat files): ' + '; '.join(' <> '.join(short(x) for x in f['mods']) for f, i in file_rows if i), '',
       '## Safe list', '']
md += ['- %s [%s]' % (short(m), ', '.join(members[m])) for m in safe]
open(os.path.join(OUT, 'collection-safety.md'), 'w', encoding='utf-8').write('\n'.join(md))
print('safe', len(safe), 'review', len(review))
for m in review: print(' ', short(m), members[m], flag[m][:2])
