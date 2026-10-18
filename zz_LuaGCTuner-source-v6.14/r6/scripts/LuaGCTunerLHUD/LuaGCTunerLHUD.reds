// Lua GC Tuner - Limited HUD (LHUD) bridge
//
// Gives the Lua GC Tuner's gameplay (HUD) meter its own section in LHUD's settings (Mod Settings -> LHUD ->
// "Lua GC Tuner meter") with the same toggles as LHUD's own modules, and lets the CET side ask whether the
// meter should be visible right now:
//   local sys = Game.GetScriptableSystemsContainer():Get("LuaGCTunerLHUDSystem")
//   if sys then show = sys:IsVisible(); opacity = sys:GetOpacity() end
//
// LHUD keeps no central visibility decision (every HUD controller decides for itself from LHUDEvents), but it
// publishes each condition flag on AllBlackboardDefinitions (r6\scripts\LHUD\core\common.reds); this applies
// LHUD's rule to those same flags. Everything is compiled only when LHUD is installed.
// No module line: global names, so CET can reach the system by its plain class name.

@if(ModuleExists("LimitedHudCommon"))
import LimitedHudCommon.LhudCooldownTracker

@if(ModuleExists("LimitedHudCommon"))
public class LuaGCTunerLHUDConfig {
  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Is-Enabled")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Is-Enabled-Desc")
  public let IsEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Global-Key")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Global-Key-Desc")
  public let BindToGlobalHotkey: Bool = true;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Combat")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Combat-Desc")
  public let ShowInCombat: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Out-Combat")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Out-Combat-Desc")
  public let ShowOutOfCombat: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Stealth")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Stealth-Desc")
  public let ShowInStealth: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Vehicle")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Vehicle-Desc")
  public let ShowInVehicle: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-AutoPilot")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-AutoPilot-Desc")
  public let ShowWithAutoDrive: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-AutoPilot-Del")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-AutoPilot-Del-Desc")
  public let ShowWithAutoDriveDelamain: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Weapon")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Weapon-Desc")
  public let ShowWithWeapon: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Zoom")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Zoom-Desc")
  public let ShowWithZoom: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Area")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Area-Desc")
  public let ShowInDangerArea: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Mod-LHUD-Show-Cooldown")
  @runtimeProperty("ModSettings.description", "Mod-LHUD-Show-Cooldown-Desc")
  public let ShowAtCooldown: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Show with scanner")
  @runtimeProperty("ModSettings.description", "Show the meter while the scanner is open.")
  public let ShowWithScanner: Bool = false;

  @runtimeProperty("ModSettings.mod", "LHUD")
  @runtimeProperty("ModSettings.category", "Lua GC Tuner meter")
  @runtimeProperty("ModSettings.category.order", "98")
  @runtimeProperty("ModSettings.displayName", "Addons-LHUD-Opacity")
  @runtimeProperty("ModSettings.description", "Addons-LHUD-Opacity-Desc")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let Opacity: Float = 1.0;
}

// LHUD's visibility rule for one module, recomputed from the blackboards LHUD listens to.
// why (optional) receives the switched-on conditions that are true right now, for the overlay.
@if(ModuleExists("LimitedHudCommon"))
public func LuaGCTunerLHUD_Decide(gi: GameInstance, c: ref<LuaGCTunerLHUDConfig>, why: script_ref<String>) -> Bool {
  if !IsDefined(c) || !c.IsEnabled { Deref(why) = "LHUD module off (always shown)"; return true; }
  // LHUD's own state: the flags its listeners publish on AllBlackboardDefinitions (LHUD core/common.reds),
  // the same ones every LHUD module reads, so the meter can never disagree with the rest of the HUD.
  let d: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
  if d.lhud_isBraindanceActive { Deref(why) = "braindance (hidden)"; return false; }   // LHUD always hides in braindances
  let global: Bool = d.lhud_isGlobalFlagToggled;
  let combat: Bool = d.lhud_isCombatActive;
  let outOfCombat: Bool = d.lhud_isOutOfCombatActive;
  let stealth: Bool = d.lhud_isStealthActive;
  let inVehicle: Bool = d.lhud_isInVehicle;
  let autoDrive: Bool = d.lhud_inAutoDrive;
  let autoDel: Bool = d.lhud_inAutoDriveDelamain;
  let weapon: Bool = d.lhud_isWeaponUnsheathed;
  let zoom: Bool = d.lhud_isZoomActive;
  let danger: Bool = d.lhud_isInDangerZone;
  let scanner: Bool = d.lhud_isScannerActive;
  let tracker: ref<LhudCooldownTracker> = LhudCooldownTracker.Get(gi);
  let cooldown: Bool = IsDefined(tracker) && tracker.IsNotEmpty();

  let s: String = "";
  if global && c.BindToGlobalHotkey { s += "hotkey "; }
  if combat && c.ShowInCombat { s += "combat "; }
  if outOfCombat && c.ShowOutOfCombat { s += "out-of-combat "; }
  if stealth && c.ShowInStealth { s += "stealth "; }
  if inVehicle && c.ShowInVehicle { s += "vehicle "; }
  if autoDrive && c.ShowWithAutoDrive { s += "autodrive "; }
  if autoDel && c.ShowWithAutoDriveDelamain { s += "delamain "; }
  if weapon && c.ShowWithWeapon { s += "weapon "; }
  if zoom && c.ShowWithZoom { s += "zoom "; }
  if danger && c.ShowInDangerArea { s += "danger-area "; }
  if cooldown && c.ShowAtCooldown { s += "cooldown "; }
  if scanner && c.ShowWithScanner { s += "scanner "; }
  Deref(why) = s;
  return NotEquals(s, "");
}

@if(ModuleExists("LimitedHudCommon"))
public class LuaGCTunerLHUDSystem extends ScriptableSystem {
  private let config: ref<LuaGCTunerLHUDConfig>;

  private func OnAttach() -> Void {
    this.config = new LuaGCTunerLHUDConfig();
  }

  // the config is re-read on every call so Mod Settings changes apply right away (a handful of fields)
  public func IsVisible() -> Bool {
    this.config = new LuaGCTunerLHUDConfig();
    let why: String;
    return LuaGCTunerLHUD_Decide(this.GetGameInstance(), this.config, why);
  }

  // switched-on LHUD conditions that are true right now (CET overlay status line)
  public func Describe() -> String {
    let why: String;
    LuaGCTunerLHUD_Decide(this.GetGameInstance(), new LuaGCTunerLHUDConfig(), why);
    return why;
  }

  public func GetOpacity() -> Float {
    return IsDefined(this.config) ? this.config.Opacity : 1.0;
  }
}
