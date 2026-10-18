// Flesh & Chrome <-> Dark Future bridge
// F&C owns energy, stamina and carry weight. Dark Future's Energy need mirrors F&C's energy pool,
// and Dark Future thirst raises F&C stamina costs through FACExternal.
// Energy changes other mods make to Dark Future (Hack The Corps, Jacked In, TheImmersiveWay...)
// are passed on to F&C. Dark Future's own drain, sleep and caffeine are left to F&C.
module FACDarkFutureBridge

import FleshAndChrome.*
import FleshAndChrome.External.*
@if(ModuleExists("DarkFuture.Needs"))
import DarkFuture.Needs.*

public static func FACDFTickInterval() -> Float = 1.0
// Smaller differences are Dark Future's passive drain (~0.3 per 5 game minutes).
public static func FACDFForwardThreshold() -> Float = 1.0
// After a time skip Dark Future applies its sleep result late; ignore changes for this long.
public static func FACDFSkipQuietSeconds() -> Float = 15.0

public class FACDFBridgeCallback extends DelayCallback {
  public let m_system: wref<FACDFBridgeSystem>;

  public func Call() -> Void {
    if IsDefined(this.m_system) {
      this.m_system.OnTick();
    }
  }
}

public class FACDFBridgeSystem extends ScriptableSystem {
  private let m_callback: ref<FACDFBridgeCallback>;
  private let m_delayID: DelayID;
  private let m_active: Bool;
  private let m_thirstFactor: Float = 1.0;
  private let m_hasLast: Bool;
  private let m_lastValue: Float;
  private let m_lastStacks: Uint32;
  private let m_lastGameTime: Float;
  private let m_quietUntil: Float;

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let player: ref<PlayerPuppet> = request.owner as PlayerPuppet;
    if !IsDefined(player) || player.IsReplacer() { return; }
    this.m_active = true;
    this.m_thirstFactor = 1.0;
    this.m_hasLast = false;
    this.ScheduleNextTick();
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    this.m_active = false;
    let delaySys: ref<DelaySystem> = GameInstance.GetDelaySystem(this.GetGameInstance());
    if IsDefined(delaySys) { delaySys.CancelCallback(this.m_delayID); }
  }

  public func OnTick() -> Void {
    if !this.m_active { return; }
    this.Sync();
    this.ScheduleNextTick();
  }

  private func ScheduleNextTick() -> Void {
    let game: GameInstance = this.GetGameInstance();
    if !GameInstance.IsValid(game) { return; }
    let delaySys: ref<DelaySystem> = GameInstance.GetDelaySystem(game);
    if !IsDefined(delaySys) { return; }
    delaySys.CancelCallback(this.m_delayID);
    if !IsDefined(this.m_callback) {
      this.m_callback = new FACDFBridgeCallback();
      this.m_callback.m_system = this;
    }
    this.m_delayID = delaySys.DelayCallback(this.m_callback, FACDFTickInterval(), false);
  }

  private func GetFAC() -> ref<FACSystem> {
    return GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"FleshAndChrome.FACSystem") as FACSystem;
  }

  private func SetThirstFactor(factor: Float) -> Void {
    if factor == this.m_thirstFactor { return; }
    FACExternal.SetStaminaCostFactor(this.GetGameInstance(), n"DarkFuture.Thirst", factor);
    this.m_thirstFactor = factor;
  }

  // Dark Future writes these vanilla flats for thirst/smoking; F&C runs its own stamina costs.
  private func ZeroVanillaStaminaCost(flat: TweakDBID) -> Void {
    if FromVariant<Float>(TweakDBInterface.GetFlat(flat)) != 0.0 {
      TweakDBManager.SetFlat(flat, 0.0);
    }
  }

  @if(ModuleExists("DarkFuture.Needs"))
  private func Sync() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) { return; }

    let fac: ref<FACSystem> = this.GetFAC();
    if !IsDefined(fac) || !fac.IsEnabled() {
      this.SetThirstFactor(1.0);
      return;
    }
    let ps: ref<PlayerPuppetPS> = player.GetPS() as PlayerPuppetPS;
    if !IsDefined(ps) || !ps.m_facInitialized { return; }

    let realNow: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    let gameNow: Float = GameInstance.GetTimeSystem(gi).GetGameTimeStamp();
    if this.m_hasLast && gameNow - this.m_lastGameTime > 300.0 {
      this.m_quietUntil = realNow + FACDFSkipQuietSeconds();
    }
    this.m_lastGameTime = gameNow;

    // Energy: Dark Future shows F&C's pool.
    let energy: ref<DFEnergySystem> = DFEnergySystem.GetInstance(gi);
    if IsDefined(energy) {
      let current: Float = energy.GetNeedValue();
      let maxValue: Float = energy.GetNeedMax();
      let stacks: Uint32 = energy.GetEnergizedStacks();
      if current >= 0.0 && maxValue > 0.0 {
        if this.m_hasLast && realNow >= this.m_quietUntil && stacks == this.m_lastStacks {
          let external: Float = current - this.m_lastValue;
          if AbsF(external) >= FACDFForwardThreshold() {
            let maxEnergy: Float = fac.GetMaxEnergy(player);
            if external > 0.0 {
              fac.ApplyEnergyRestore(player, maxEnergy * external / 100.0);
            } else {
              fac.ApplyEnergyCost(player, maxEnergy * -external / 100.0);
            }
          }
        }
        let target: Float = ClampF(fac.GetEnergyPercent(player) * 100.0, 0.0, maxValue);
        if AbsF(target - current) >= 0.25 {
          let props: DFChangeNeedValueProps;
          props.doNotUpdateUIIfNoChange = true;
          energy.ChangeNeedValue(target - current, props);
        }
        this.m_lastValue = energy.GetNeedValue();
        this.m_lastStacks = stacks;
        this.m_hasLast = true;
      }
    }

    // Thirst: higher F&C stamina costs instead of Dark Future's vanilla sprint/jump costs.
    let factor: Float = 1.0;
    let hydration: ref<DFHydrationSystem> = DFHydrationSystem.Get();
    if IsDefined(hydration) {
      let stage: Int32 = hydration.GetNeedStage();
      if stage >= 4 { factor = 1.35; }
      else if stage == 3 { factor = 1.2; }
      else if stage == 2 { factor = 1.1; }
    }
    this.SetThirstFactor(factor);
    this.ZeroVanillaStaminaCost(t"player.staminaCosts.sprint");
    this.ZeroVanillaStaminaCost(t"player.staminaCosts.jump");
  }

  @if(!ModuleExists("DarkFuture.Needs"))
  private func Sync() -> Void {}
}
