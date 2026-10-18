"""Copy mod settings/data files from the pre-clean-install backup back into the game folder.

Only files that do NOT exist in the game folder are copied, so files deployed by Vortex (hardlinks into
staging) are never overwritten. Vanilla config/caches restored by Steam and logs are skipped.
Second pass: files in game-edited-mod-files/ (deployed files the user edited in place, e.g. MySettings' user.ini)
are written over the freshly deployed copy IN PLACE (open + truncate keeps the hardlink, so Vortex sees no change).
Usage: python restore_settings.py [backup dir name] [--dry-run]   (default: clean-install-backup-2026-10-09)
"""
import os, shutil, sys

GAME = r'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077'
_args = [a for a in sys.argv[1:] if not a.startswith('--')]
ROOT = os.path.join(os.environ['USERPROFILE'], 'Documents', 'cyberpunk-mod-patches',
                    _args[0] if _args else 'clean-install-backup-2026-10-09')
BACKUP = os.path.join(ROOT, 'game')
EDITED = os.path.join(ROOT, 'game-edited-mod-files')
SKIP_PREFIXES = [os.path.normcase(p) for p in (
    r'r6\config', r'r6\cache', r'r6\logs', r'engine\config',
    r'bin\x64\plugins\AdvancedCrashReporter\reports',
)]
SKIP_EXT = ('.log',)


def main(dry):
    copied = skipped_exists = skipped_rule = 0
    for dp, _, files in os.walk(BACKUP):
        for f in files:
            src = os.path.join(dp, f)
            rel = os.path.relpath(src, BACKUP)
            if any(os.path.normcase(rel).startswith(p) for p in SKIP_PREFIXES) or f.lower().endswith(SKIP_EXT):
                skipped_rule += 1
                continue
            dst = os.path.join(GAME, rel)
            if os.path.exists(dst):
                skipped_exists += 1
                continue
            if not dry:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
            copied += 1
    print(f"{'would copy' if dry else 'copied'}={copied} already-present={skipped_exists} skipped-by-rule={skipped_rule}")
    changed = missing = 0
    for dp, _, files in os.walk(EDITED):
        for f in files:
            src = os.path.join(dp, f)
            rel = os.path.relpath(src, EDITED)
            dst = os.path.join(GAME, rel)
            if not os.path.exists(dst):
                missing += 1  # the owning mod is not installed
                print('  mod not installed, skipped:', rel)
                continue
            if open(src, 'rb').read() != open(dst, 'rb').read():
                changed += 1
                if not dry:
                    with open(src, 'rb') as a, open(dst, 'r+b') as b:
                        b.write(a.read()); b.truncate()
    print(f"edited mod files: {'would overwrite' if dry else 'overwrote'}={changed} mod-missing={missing}")


if __name__ == '__main__':
    main('--dry-run' in sys.argv)
