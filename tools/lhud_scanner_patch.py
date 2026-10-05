# Builds LHUD-ScannerOptions: adds "Show with scanner" to every Limited HUD module that lacks it
# (Action Buttons, Crouch Indicator, Weapon Roster, Hotkey Hints, Health bar, Stamina bar).
# Copies the originals to <out>/original and writes patched copies to <out>/r6/scripts/LHUD.
# Usage: lhud_scanner_patch.py <out dir>
import os, re, shutil, sys

LHUD = r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\r6\scripts\LHUD"
OUT = sys.argv[1]
CLASSES = ["ActionButtonsModuleConfig", "CrouchIndicatorModuleConfig", "WeaponRosterModuleConfig",
           "HintsModuleConfig", "PlayerHealthbarModuleConfig", "PlayerStaminabarModuleConfig"]
MODULES = ["actionButtons", "crouchIndicator", "weaponRoster", "hints", "playerHealthbar", "playerStamina"]

def read(rel):
    src = os.path.join(LHUD, rel)
    dst = os.path.join(OUT, "original", rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return open(src, encoding="utf-8", newline="").read()

def write(rel, s):
    dst = os.path.join(OUT, r"r6\scripts\LHUD", rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "w", encoding="utf-8", newline="").write(s)

# config.reds: a ShowWithScanner field after each class's ShowWithZoom field (same category / order)
cfg = read("config.reds")
for cls in CLASSES:
    start = cfg.index("public class " + cls + " {")
    end = cfg.index("\n}", start)
    body = cfg[start:end]
    assert "ShowWithScanner" not in body, cls
    m = re.search(r"((?:[ \t]*@runtimeProperty\([^\n]*\r?\n)+)([ \t]*)public let ShowWithZoom: Bool = \w+;\r?\n", body)
    assert m, cls
    props = m.group(1)
    props = re.sub(r'"Mod-LHUD-Show-Zoom"', '"Mod-LHUD-Show-Scanner"', props)
    props = re.sub(r'"Mod-LHUD-Show-Zoom-Desc"', '"Mod-LHUD-Show-Scanner-Desc"', props)
    assert "Show-Scanner" in props, (cls, props)
    nl = "\r\n" if "\r\n" in m.group(0) else "\n"
    block = nl + props + m.group(2) + "public let ShowWithScanner: Bool = false;" + nl
    body = body[:m.end()] + block + body[m.end():]
    cfg = cfg[:start] + body + cfg[end:]
write("config.reds", cfg)

# modules: showForScanner joins each OR-ed visibility expression
total = 0
for mod in MODULES:
    rel = os.path.join("modules", mod + ".reds")
    s = read(rel)
    pat = re.compile(r"^([ \t]*)let (isVisible|moddedVisibility): Bool = (showForGlobalHotkey[^;\n]*);(\r?)$", re.M)
    n = 0
    def rep(m):
        global n
        n += 1
        ind, var, expr, cr = m.groups()
        return (f"{ind}let showForScanner: Bool = this.lhud_isScannerActive && this.lhudConfig.ShowWithScanner;{cr}\n"
                f"{ind}let {var}: Bool = {expr} || showForScanner;{cr}")
    s, n = pat.subn(rep, s)
    assert n > 0, mod
    assert s.count("this.lhudConfig.ShowWithScanner") == n
    total += n
    print(f"{mod}: {n} visibility rule(s)")
    write(rel, s)
print("patched rules:", total)
