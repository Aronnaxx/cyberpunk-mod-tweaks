"""Builds SmasherEncounters.reds (Adam Smasher Encounters 2.4, Nexus 26824) with the CET-Cleans
Live Settings & Housekeeping fixes applied directly in the source.

Why direct edits: this redscript version cannot attach @addMethod/@wrapMethod/@replaceMethod to
classes defined in another mod's scripts (addMethod crashes the compiler with
"constant pool error: definition not found"; wrap/replace report UNRESOLVED_METHOD).

usage: python make_patched.py <original SmasherEncounters.reds> <output .reds>
"""
import sys

src = open(sys.argv[1], encoding="utf-8", newline="").read()
NL = "\r\n" if "\r\n" in src else "\n"

def rep(old, new):
    global src
    old, new = old.replace("\n", NL), new.replace("\n", NL)
    n = src.count(old)
    assert n == 1, f"anchor found {n}x: {old[:70]!r}"
    src = src.replace(old, new)

HEADER = """// [CET-Cleans] Adam Smasher Encounters 2.4 + Live Settings & Housekeeping fixes (v2.0, local only - do not upload)
//  1. Settings apply live: settings object registered with ModSettings.RegisterListenerToClass().
//  2. Danger-meter animation timer drops from ~60/s to 2/s while the bar is not moving.
//  3. "Mod Enabled" off mid-session ends the encounter, stops timers, hides the meter, stops danger points.
// All edits are marked [CET-Cleans]. Original file kept in Documents\\CET-Cleans\\SmasherEncounters_LiveSettings-source-v2.0.

"""
src = HEADER.replace("\n", NL) + src

# A. fields
rep("""    let settings: ref<SmasherEncountersSettings>;
""", """    let settings: ref<SmasherEncountersSettings>;
    // [CET-Cleans] live settings / master switch state
    let sep_settingsRegistered: Bool;
    let sep_lastEnabled: Bool;
    let sep_enabledKnown: Bool;
""")

# B. register settings object during init
rep("""    private func InitializeSystem() -> Void {
        ModSettings.RegisterListenerToModifications(this);
        if !IsDefined(this.settings) {
            this.settings = new SmasherEncountersSettings();
        };
""", """    private func InitializeSystem() -> Void {
        ModSettings.RegisterListenerToModifications(this);
        if !IsDefined(this.settings) {
            this.settings = new SmasherEncountersSettings();
        };
        this.SEP_EnsureSettingsRegistered(); // [CET-Cleans]
""")

# C. new methods after IsModEnabled
rep("""    public func IsModEnabled() -> Bool {
        if IsDefined(this.settings) { return this.settings.ModEnabled; };
        return true;
    };
""", """    public func IsModEnabled() -> Bool {
        if IsDefined(this.settings) { return this.settings.ModEnabled; };
        return true;
    };

    // [CET-Cleans] register the settings object so menu changes apply without a reload
    public func SEP_EnsureSettingsRegistered() -> Void {
        if !IsDefined(this.settings) {
            this.settings = new SmasherEncountersSettings();
            this.sep_settingsRegistered = false;
        };
        if !this.sep_settingsRegistered {
            ModSettings.RegisterListenerToClass(this.settings);
            this.sep_settingsRegistered = true;
        };
        if !this.sep_enabledKnown {
            this.sep_lastEnabled = this.IsModEnabled();
            this.sep_enabledKnown = true;
        };
    }

    // [CET-Cleans] master switch: react to "Mod Enabled" changing mid-session
    public func SEP_ApplyEnabledState() -> Void {
        let enabled = this.IsModEnabled();
        if !this.sep_enabledKnown {
            this.sep_lastEnabled = enabled;
            this.sep_enabledKnown = true;
            return;
        };
        if Equals(enabled, this.sep_lastEnabled) {
            return;
        };
        this.sep_lastEnabled = enabled;
        if !enabled {
            FTLog("[SmasherEncounters LiveSettings] Mod disabled in settings: ending encounter and stopping timers.");
            if this.isSmasherEventInProgress {
                this.CleanupSmasherEvent(true, "Mod disabled in settings");
            };
            if IsDefined(this.lastEncounterSecondsDaemon) {
                this.lastEncounterSecondsDaemon.Stop();
            };
            if IsDefined(this.periodicSpawnCheckDaemon) {
                this.periodicSpawnCheckDaemon.Stop();
                this.periodicSpawnCheckDaemon = null;
            };
            if IsDefined(this.playerSecondsAwayDaemon) {
                this.playerSecondsAwayDaemon.Stop();
            };
        } else {
            FTLog("[SmasherEncounters LiveSettings] Mod re-enabled in settings: restarting.");
            this.InitializeSystem();
        };
    }
""")

# D. settings change: ensure registration + schedule re-apply after ModSettings writes values
rep("""    public cb func OnModSettingsChange() -> Void {
        this.InitializePersistentState();
""", """    public cb func OnModSettingsChange() -> Void {
        this.SEP_EnsureSettingsRegistered(); // [CET-Cleans]
        this.InitializePersistentState();
""")
rep("""        SmasherHUDSystem.GetInstance(this.GetGameInstance()).OnSettingsChanged();
    };

    private func InitializePersistentState() -> Void {""", """        SmasherHUDSystem.GetInstance(this.GetGameInstance()).OnSettingsChanged();
        // [CET-Cleans] re-apply 0.1 s later, after Mod Settings has written the new values
        let sepCb = new SEP_ApplySmasherSettingsCallback();
        sepCb.gi = this.GetGameInstance();
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(sepCb, 0.1, false);
    };

    private func InitializePersistentState() -> Void {""")

# E. no danger points while disabled
rep("""    func AddSpawnPoints(points: Float) -> Float {
""", """    func AddSpawnPoints(points: Float) -> Float {
        if !this.IsModEnabled() { return 0.0; } // [CET-Cleans]
""")

# F. hide meter while disabled
rep("""        if !IsDefined(smasherSys) || !IsDefined(smasherSys.settings) {
            this.UpdateDanger(0.0, false);
            return;
        };

        if smasherSys.IsSmasherEventInProgress()""", """        if !IsDefined(smasherSys) || !IsDefined(smasherSys.settings) {
            this.UpdateDanger(0.0, false);
            return;
        };

        if !smasherSys.IsModEnabled() { // [CET-Cleans]
            this.UpdateDanger(0.0, false);
            return;
        };

        if smasherSys.IsSmasherEventInProgress()""")

# G. meter: settled check
rep("""    public func SetProgress(progress: Float) -> Void {
        this.m_targetProgress = ClampF(progress, 0.0, 1.0);
    }
""", """    public func SetProgress(progress: Float) -> Void {
        this.m_targetProgress = ClampF(progress, 0.0, 1.0);
    }

    // [CET-Cleans]
    public func SEP_IsSettled() -> Bool {
        return AbsF(this.m_targetProgress - this.m_currentProgress) <= 0.001;
    }
""")

# H. HUD: animating check
rep("""    public func UpdateSmooth() -> Void {
        if IsDefined(this.m_dangerMeter) {
            this.m_dangerMeter.Update();
        }
    }
""", """    public func UpdateSmooth() -> Void {
        if IsDefined(this.m_dangerMeter) {
            this.m_dangerMeter.Update();
        }
    }

    // [CET-Cleans]
    public func SEP_IsMeterAnimating() -> Bool {
        if !IsDefined(this.m_dangerMeter) {
            return false;
        };
        return !this.m_dangerMeter.SEP_IsSettled();
    }
""")

# I. adaptive animation timer
rep("""    func Call() -> Void {
        let hud = SmasherHUDSystem.GetInstance(this.gi);
        if IsDefined(hud) {
            hud.UpdateSmooth();
        };
        this.Repeat();
    };""", """    func Call() -> Void {
        let hud = SmasherHUDSystem.GetInstance(this.gi);
        if IsDefined(hud) && hud.SEP_IsMeterAnimating() {
            hud.UpdateSmooth();
            this.delay = 0.0166; // [CET-Cleans] animating: ~60 updates per second
        } else {
            this.delay = 0.5;    // [CET-Cleans] idle: check twice a second
        };
        this.Repeat();
    };""")

# J. delayed re-apply callback
src += NL.join(["", "",
"// [CET-Cleans] delayed re-apply (runs after Mod Settings has written the new values)",
"public class SEP_ApplySmasherSettingsCallback extends DelayCallback {",
"    public let gi: GameInstance;",
"",
"    public func Call() -> Void {",
"        let sys = GameInstance.GetSmasherEncountersSystem(this.gi);",
"        if IsDefined(sys) {",
"            sys.SEP_ApplyEnabledState();",
"        };",
"        let hud = SmasherHUDSystem.GetInstance(this.gi);",
"        if IsDefined(hud) {",
"            hud.OnSettingsChanged();",
"            hud.RefreshDangerMeter();",
"        };",
"    }",
"}", ""])

open(sys.argv[2], "w", encoding="utf-8", newline="").write(src)
print("ok:", sys.argv[2])
