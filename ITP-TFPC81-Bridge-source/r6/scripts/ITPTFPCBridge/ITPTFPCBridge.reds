// ITP <-> TFPC bridge (local patch for Ethan's setup - not for upload)
//
// Immersive Third Person (ITP) Best Of Both Worlds + True First Person Camera (TFPC) 8.1+.
//
// TFPC 8.1 keeps the game-built character-customization head on V and only toggles its
// components (the TppHead slot is never swapped). Its hide rules (sprint, crouch, pitch,
// weapon drawn...) and its camera/lean/weapon offsets are first-person features, so while
// ITP is in third person this bridge:
//   1. shows the head and lets TFPC switch the head/eyes appearances to &TPP,
//   2. parks TFPC's head logic in its non-hiding "vehicle mode" so nothing re-hides it,
//   3. switches TFPC off (modON) and disables its camera,
// then restores exactly the previous state when ITP returns to first person.
//
// Update safety:
//   - ITP is read only at runtime through Codeware reflection (field `tppActive`, falling back
//     to `IsPickupScanWanted()`), so ITP changes can never break script compilation.
//   - The TFPC half (ITPTFPCBridgeTfpc) is compiled only when the TrueFirstPerson module exists,
//     and uses only API present unchanged in both TFPC 8.0.3 and 8.1.3. Without TFPC an inert
//     stub with the same interface is compiled instead.
//   - ITP installed but unreadable -> the bridge logs, shows one warning and stands down.
//
// Logs go to r6/logs/redscript_rCURRENT.log with the prefix [ITP-TFPC Bridge].

@if(ModuleExists("TrueFirstPerson"))
import TrueFirstPerson.*

public class ITPTFPCBridgeTick extends DelayCallback {
  public let system: wref<ITPTFPCBridgeSystem>;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.OnTick();
    };
  }
}

public class ITPTFPCBridgeSystem extends ScriptableSystem {
  private let m_tfpc: ref<ITPTFPCBridgeTfpc>;
  private let m_lastTpp: Bool;
  private let m_standDown: Bool;
  private let m_warned: Bool;
  private let m_tickID: DelayID;
  private let m_ticking: Bool;

  public static func TickSeconds() -> Float = 0.1;

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_tfpc = new ITPTFPCBridgeTfpc();
    this.m_lastTpp = false;
    this.m_standDown = false;
    ITPTFPCBridgeLog(s"player attached; TFPC compiled in: \(ITPTFPCBridgeTfpc.CompiledIn())");
    this.ScheduleTick();
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    if IsDefined(this.m_tfpc) && this.m_tfpc.IsActive() {
      this.m_tfpc.Exit(this.GetGameInstance(), "player detach");
    };
    this.StopTick();
  }

  private func ScheduleTick() -> Void {
    let cb: ref<ITPTFPCBridgeTick> = new ITPTFPCBridgeTick();
    cb.system = this;
    this.m_tickID = GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, ITPTFPCBridgeSystem.TickSeconds(), false);
    this.m_ticking = true;
  }

  private func StopTick() -> Void {
    if this.m_ticking {
      GameInstance.GetDelaySystem(this.GetGameInstance()).CancelCallback(this.m_tickID);
      this.m_ticking = false;
    };
  }

  public func OnTick() -> Void {
    this.m_ticking = false;
    if !this.m_standDown && IsDefined(this.m_tfpc) {
      this.Step();
    };
    this.ScheduleTick();
  }

  private func Step() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let itp: Int32 = this.ReadItpTpp();
    if itp < 0 {
      // ITP not installed (-1) is fine; installed but unreadable (-2) means it changed.
      if itp == -2 {
        this.StandDown("ITP is installed but its third-person flag could not be read (ITP update?)");
      };
      return;
    };
    let tpp: Bool = itp == 1;

    if !this.m_tfpc.IsReady(gi) {
      if this.m_tfpc.IsActive() {
        this.m_tfpc.Exit(gi, "TFPC session ended");
      };
      this.m_lastTpp = tpp;
      return;
    };

    if NotEquals(tpp, this.m_lastTpp) {
      ITPTFPCBridgeLog(s"ITP perspective -> \(tpp ? "third" : "first") person");
    };
    this.m_lastTpp = tpp;

    if tpp {
      this.m_tfpc.TickThirdPerson(gi, this.IsMounted());
    } else {
      if this.m_tfpc.IsActive() {
        this.m_tfpc.Exit(gi, "returned to first person");
      };
    };
  }

  // Returns 1 = third person, 0 = first person, -1 = ITP not installed, -2 = ITP unreadable.
  private func ReadItpTpp() -> Int32 {
    let bridge: ref<ScriptableSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"TPPCameraVisibleRenderBridge");
    if !IsDefined(bridge) {
      return -1;
    };
    let cls: ref<ReflectionClass> = Reflection.GetClassOf(ToVariant(bridge), true);
    if !IsDefined(cls) {
      return -2;
    };
    let prop: ref<ReflectionProp> = cls.GetProperty(n"tppActive");
    if IsDefined(prop) {
      return FromVariant<Bool>(prop.GetValue(ToVariant(bridge))) ? 1 : 0;
    };
    let fn: ref<ReflectionMemberFunc> = cls.GetFunction(n"IsPickupScanWanted");
    if IsDefined(fn) {
      return FromVariant<Bool>(fn.Call(bridge)) ? 1 : 0;
    };
    return -2;
  }

  private func IsMounted() -> Bool {
    let player: ref<GameObject> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    return IsDefined(player) && VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), player);
  }

  private func StandDown(reason: String) -> Void {
    if this.m_tfpc.IsActive() {
      this.m_tfpc.Exit(this.GetGameInstance(), "standing down");
    };
    this.m_standDown = true;
    ITPTFPCBridgeLog(s"STANDING DOWN: \(reason)");
    if !this.m_warned {
      this.m_warned = true;
      let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
      if IsDefined(player) {
        player.SetWarningMessage("ITP/TFPC bridge disabled - see redscript log");
      };
    };
  }
}

public func ITPTFPCBridgeLog(msg: String) -> Void {
  FTLog(s"[ITP-TFPC Bridge] \(msg)");
}

// ---------------------------------------------------------------------------------------------
// TFPC half - compiled only when True First Person Camera is installed.
// ---------------------------------------------------------------------------------------------

@if(ModuleExists("TrueFirstPerson"))
public class ITPTFPCBridgeTfpc {
  // 0 = idle (TFPC untouched), 1 = entering third person (showing head), 2 = TFPC suspended
  private let m_phase: Int32;
  private let m_enterTicks: Int32;
  private let m_modOnBefore: Bool;
  private let m_showHeadBefore: Bool;
  private let m_headHeldByUs: Bool;

  public static func CompiledIn() -> Bool = true;
  public static func EnterTimeoutTicks() -> Int32 = 15;

  public func IsActive() -> Bool {
    return this.m_phase != 0;
  }

  public func IsReady(gi: GameInstance) -> Bool {
    let tfpc: ref<IFPSystem> = IFPSystem.Get(gi);
    return IsDefined(tfpc) && tfpc.IsSessionActive() && IsDefined(tfpc.GetConfig()) && IsDefined(tfpc.GetHead());
  }

  public func TickThirdPerson(gi: GameInstance, mounted: Bool) -> Void {
    if this.m_phase == 0 {
      // Vehicles stay with TFPC's own vehicle logic; ITP switches to FPP for driving anyway.
      if !mounted {
        this.Enter(gi);
      };
    } else {
      if this.m_phase == 1 {
        this.ContinueEnter(gi);
      } else {
        this.Maintain(gi, mounted);
      };
    };
  }

  // FPP -> TPP: remember TFPC's state, stop its camera, and start showing the head.
  private func Enter(gi: GameInstance) -> Void {
    let tfpc: ref<IFPSystem> = IFPSystem.Get(gi);
    let config: ref<IFPConfig> = tfpc.GetConfig();
    let head: ref<IFPHead> = tfpc.GetHead();

    this.m_modOnBefore = config.modON;
    this.m_showHeadBefore = config.showHead;
    this.m_headHeldByUs = false;

    if this.m_modOnBefore {
      let camera: ref<IFPCamera> = tfpc.GetCamera();
      if IsDefined(camera) {
        camera.ResetCamera(true);
        camera.SetEnabled(false);
      };
      let lean: ref<IFPLean> = tfpc.GetLean();
      if IsDefined(lean) {
        lean.ResetLean();
      };
    };

    config.showHead = true;
    head.SetTempUnequipHidden(false);
    head.SetInEquipAnimation(false);
    // v1.1: always (re)apply. TFPC can believe the head is visible (IsHeadVisible) while its
    // components are actually off (seen in v1.0 logs), and ShowHead() is what re-applies them.
    head.ShowHead();

    this.m_phase = 1;
    this.m_enterTicks = 0;
    ITPTFPCBridgeLog(s"ENTER: modON=\(this.m_modOnBefore) showHead=\(this.m_showHeadBefore) headVisible=\(head.IsHeadVisible()) vehicleMode=\(head.IsVehicleMode())");
  }

  // Wait until the head is really visible, switch it to TPP appearances, then park TFPC.
  private func ContinueEnter(gi: GameInstance) -> Void {
    let tfpc: ref<IFPSystem> = IFPSystem.Get(gi);
    let config: ref<IFPConfig> = tfpc.GetConfig();
    let head: ref<IFPHead> = tfpc.GetHead();
    this.m_enterTicks += 1;

    let shown: Bool = head.IsHeadCurrentlyVisible();
    if !shown && this.m_enterTicks < ITPTFPCBridgeTfpc.EnterTimeoutTicks() {
      // ShowHead() applies after ~0.25 s and each call restarts that wait, so re-ask only every
      // 4th tick (a TFPC rule such as sprint or weapon may have hidden it again meanwhile).
      if this.m_enterTicks % 4 == 0 {
        head.ShowHead();
      };
      return;
    };
    if !shown {
      ITPTFPCBridgeLog(s"WARNING: head components still off after \(this.m_enterTicks) ticks (believed visible: \(head.IsHeadVisible()))");
    };

    head.ActivateTPPAppearances();

    if !head.IsVehicleMode() {
      let hideOnEntry: Bool = config.hideHeadOnVehicleEntry;
      config.hideHeadOnVehicleEntry = false;
      head.SetVehicleMode(true, false);
      config.hideHeadOnVehicleEntry = hideOnEntry;
      this.m_headHeldByUs = head.IsVehicleMode();
    };

    if this.m_modOnBefore {
      config.modON = false;
    };
    this.m_phase = 2;
    ITPTFPCBridgeLog(s"SUSPENDED after \(this.m_enterTicks) ticks: headShown=\(shown) tppAppearances=\(head.IsTPPActive()) held=\(this.m_headHeldByUs)");
  }

  // While suspended: if TFPC let go of the head (e.g. its vehicle-unmount path), take it again.
  private func Maintain(gi: GameInstance, mounted: Bool) -> Void {
    let tfpc: ref<IFPSystem> = IFPSystem.Get(gi);
    let config: ref<IFPConfig> = tfpc.GetConfig();
    let head: ref<IFPHead> = tfpc.GetHead();

    if this.m_modOnBefore && config.modON {
      ITPTFPCBridgeLog("TFPC was switched back on while in third person - suspending it again");
      config.modON = false;
    };
    if !head.IsVehicleMode() && !mounted {
      ITPTFPCBridgeLog("TFPC released the head while in third person - re-entering");
      this.m_headHeldByUs = false;
      config.showHead = true;
      if !head.IsHeadVisible() {
        head.ShowHead();
      };
      this.m_phase = 1;
      this.m_enterTicks = 0;
    };
  }

  // TPP -> FPP: hand everything back exactly as it was.
  public func Exit(gi: GameInstance, reason: String) -> Void {
    let tfpc: ref<IFPSystem> = IFPSystem.Get(gi);
    if !IsDefined(tfpc) || !IsDefined(tfpc.GetConfig()) {
      this.m_phase = 0;
      this.m_headHeldByUs = false;
      return;
    };
    let config: ref<IFPConfig> = tfpc.GetConfig();
    let head: ref<IFPHead> = tfpc.GetHead();

    config.modON = this.m_modOnBefore;
    config.showHead = this.m_showHeadBefore;

    if IsDefined(head) {
      let player: ref<GameObject> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
      let mounted: Bool = IsDefined(player) && VehicleComponent.IsMountedToVehicle(gi, player);
      if this.m_headHeldByUs && head.IsVehicleMode() && !mounted {
        head.SetTempUnequipHidden(false);
        head.SetInEquipAnimation(false);
        head.SetVehicleMode(false, false);
      };
      if head.IsTPPActive() {
        head.DeactivateTPPAppearances();
      };
      head.EvaluateVisibility();
    };

    if this.m_modOnBefore {
      let camera: ref<IFPCamera> = tfpc.GetCamera();
      if IsDefined(camera) {
        camera.SetEnabled(true);
      };
    };

    ITPTFPCBridgeLog(s"EXIT (\(reason)): modON=\(config.modON) showHead=\(config.showHead) headVisible=\(IsDefined(head) && head.IsHeadVisible())");
    this.m_phase = 0;
    this.m_headHeldByUs = false;
  }
}

// Without TFPC: an inert stub with the same interface, so the bridge simply idles.
@if(!ModuleExists("TrueFirstPerson"))
public class ITPTFPCBridgeTfpc {
  public static func CompiledIn() -> Bool = false;
  public func IsActive() -> Bool = false;
  public func IsReady(gi: GameInstance) -> Bool = false;
  public func TickThirdPerson(gi: GameInstance, mounted: Bool) -> Void {}
  public func Exit(gi: GameInstance, reason: String) -> Void {}
}
