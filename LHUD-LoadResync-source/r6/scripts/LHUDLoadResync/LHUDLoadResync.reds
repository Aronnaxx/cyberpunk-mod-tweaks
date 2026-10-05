// LHUD Load Resync 1.0
//
// Limited HUD sets its "weapon out" state once, 1 s after the player spawns, from what is in the
// WeaponRight slot at that moment (LHUD core/listeners.reds PostLaunchCall). On this setup a weapon sits
// in that slot for a moment right after loading and is then removed without a holster, so the
// HasWeaponEquipped blackboard never changes and LHUD never hears that the weapon is gone: the weapon
// roster stays unfolded until the player draws and holsters once.
//
// This re-sends LHUD the real weapon state a few seconds after every load. Compiled only with LHUD.

@if(ModuleExists("LimitedHudCommon"))
import LimitedHudCommon.LHUDEventType

@if(ModuleExists("LimitedHudCommon"))
public class LHUDLoadResyncCallback extends DelayCallback {
  public let gi: GameInstance;

  public func Call() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.gi);
    if IsDefined(player) {
      player.QueueLHUDEvent(LHUDEventType.Weapon, player.HasAnyWeaponEquipped_LHUD());
    }
  }
}

@if(ModuleExists("LimitedHudCommon"))
public class LHUDLoadResyncSystem extends ScriptableSystem {
  private let m_attachedID: Uint32;

  private func OnAttach() -> Void {
    this.m_attachedID = GameInstance.GetPlayerSystem(this.GetGameInstance())
      .RegisterPlayerPuppetAttachedCallback(this, n"OnPlayerAttached");
  }

  private func OnDetach() -> Void {
    GameInstance.GetPlayerSystem(this.GetGameInstance()).UnregisterPlayerPuppetAttachedCallback(this.m_attachedID);
  }

  protected cb func OnPlayerAttached(playerPuppet: ref<GameObject>) -> Void {
    // LHUD's own check runs at 1 s; repeat after the load has settled
    this.Schedule(3.0);
    this.Schedule(8.0);
  }

  private func Schedule(delay: Float) -> Void {
    let cb: ref<LHUDLoadResyncCallback> = new LHUDLoadResyncCallback();
    cb.gi = this.GetGameInstance();
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delay, false);
  }
}
