"""Back up everything a clean reinstall would lose, without copying what Vortex can redeploy.

Collects from the game folder:
  game/                 files that are NOT in vortex.deployment.json (mod-created settings, databases, saves of mods...)
  game-edited-mod-files/ files that ARE deployed but were edited in place (hardlink broken, or mtime changed since Vortex deployed it)
Also copies UserSettings.json (+ appdata), the game saves, and the deployment manifest.
Vortex's own state.v2 must be copied separately with Vortex closed (see the runbook).

Usage: python settings_backup.py <backup dir> [--dry-run]
"""
import json, os, shutil, sys

GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
STAGING = os.path.join(os.environ['APPDATA'], 'Vortex', 'cyberpunk2077', 'mods')
APPDATA = os.path.join(os.environ['LOCALAPPDATA'], 'CD Projekt Red', 'Cyberpunk 2077')
SAVES = os.path.join(os.environ['USERPROFILE'], 'Saved Games', 'CD Projekt Red', 'Cyberpunk 2077')
ROOTS = [r'bin\x64\plugins', 'r6', 'red4ext', r'archive\pc\mod', 'mods', r'engine\config']
SKIP_PREFIX = [os.path.normcase(p) for p in (r'r6\cache', r'bin\x64\plugins\AdvancedCrashReporter\reports')]
SKIP_EXT = ('.log',)
# Inside r6\cache (otherwise skipped): the player's key bindings, rewritten in place by the game / Input Loader.
KEEP = [os.path.normcase(p) for p in (r'r6\cache\inputUserMappings.xml',)]


def main(dest, dry):
    man = json.load(open(os.path.join(GAME, 'vortex.deployment.json')))
    managed = {os.path.normcase(f['relPath']): f['source'] for f in man['files']}
    deploy_time = {os.path.normcase(f['relPath']): f['time'] for f in man['files']}
    stats = {'unmanaged': 0, 'edited': 0, 'bytes': 0}
    edited_list = []

    def put(src, kind, rel):
        out = os.path.join(dest, kind, rel)
        stats[{'game': 'unmanaged', 'game-edited-mod-files': 'edited'}[kind]] += 1
        stats['bytes'] += os.path.getsize(src)
        if not dry:
            os.makedirs(os.path.dirname(out), exist_ok=True)
            shutil.copy2(src, out)

    for root in ROOTS:
        for dp, _, files in os.walk(os.path.join(GAME, root)):
            for f in files:
                src = os.path.join(dp, f)
                rel = os.path.relpath(src, GAME)
                n = os.path.normcase(rel)
                if f.lower().endswith(SKIP_EXT) or (any(n.startswith(p) for p in SKIP_PREFIX) and n not in KEEP):
                    continue
                if n in managed:
                    # In-place writes keep the hardlink (staging changes too), so also compare the mtime
                    # against the time Vortex recorded at deploy.
                    stg = os.path.join(STAGING, managed[n], rel)
                    try:
                        same = os.path.samefile(src, stg)
                    except OSError:
                        same = True  # staging copy missing: nothing to compare, leave to Vortex
                    if not same or abs(os.stat(src).st_mtime * 1000 - deploy_time[n]) > 3000:
                        edited_list.append(rel)
                        put(src, 'game-edited-mod-files', rel)
                else:
                    put(src, 'game', rel)

    extra = [('appdata-game-settings', APPDATA), ('saves', SAVES)]
    for name, src in extra:
        if os.path.isdir(src):
            for dp, _, files in os.walk(src):
                for f in files:
                    p = os.path.join(dp, f)
                    stats['bytes'] += os.path.getsize(p)
                    if not dry:
                        out = os.path.join(dest, name, os.path.relpath(p, src))
                        os.makedirs(os.path.dirname(out), exist_ok=True)
                        shutil.copy2(p, out)
    if not dry:
        shutil.copy2(os.path.join(GAME, 'vortex.deployment.json'), dest)
        with open(os.path.join(dest, 'backup-manifest.txt'), 'w', encoding='utf8') as m:
            m.write(f"unmanaged files copied to game\\: {stats['unmanaged']}\n")
            m.write(f"edited-in-place mod files copied to game-edited-mod-files\\: {stats['edited']}\n")
            m.write('\n'.join(edited_list) + '\n')
    print(f"{'would copy' if dry else 'copied'}: unmanaged={stats['unmanaged']} edited-in-place={stats['edited']} "
          f"total {stats['bytes'] / 1e6:.0f} MB (incl. appdata + saves)")
    for r in edited_list:
        print('  edited:', r)


if __name__ == '__main__':
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    main(a[0], '--dry-run' in sys.argv)
