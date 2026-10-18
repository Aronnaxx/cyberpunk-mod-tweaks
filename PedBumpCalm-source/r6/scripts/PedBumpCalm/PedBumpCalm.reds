// PedBumpCalm v1.0 - crowds don't panic when a car bumps V while V is on foot.
// CrowdFleeProbe (2026-10-07) showed the "flee for no reason" waves start with a VehicleHit stim
// (radius 100 m) plus a Terror stim whose source is V while V is walking - the broadcast that fires
// when traffic hits the player. Every crowd NPC in range runs and SpreadFear chains it further.
// This swallows that VehicleHit for crowd NPCs, and V's Terror for 3 s after it. V running people
// over while driving, gunfire, explosions and everything else are untouched.

@wrapMethod(ReactionManagerComponent)
private func HandleCrowdReaction(stimEvent: ref<StimuliEvent>) -> Void {
  if IsDefined(stimEvent) && this.PBC_Swallow(stimEvent) {
    return;
  };
  wrappedMethod(stimEvent);
}

@addMethod(ReactionManagerComponent)
private func PBC_Swallow(stimEvent: ref<StimuliEvent>) -> Bool {
  let source: wref<GameObject> = stimEvent.sourceObject;
  if !IsDefined(source) || !source.IsPlayer() {
    return false;
  };
  let game: GameInstance = source.GetGame();
  if VehicleComponent.IsMountedToVehicle(game, source) {
    return false;
  };
  let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(game));
  let stimType: gamedataStimType = stimEvent.GetStimType();
  if Equals(stimType, gamedataStimType.VehicleHit) {
    PBCState.Get(game).lastBump = now;
    return true;
  };
  if Equals(stimType, gamedataStimType.Terror) {
    let last: Float = PBCState.Get(game).lastBump;
    return last > 0.0 && now - last >= 0.0 && now - last < 3.0;
  };
  return false;
}

public class PBCState extends ScriptableSystem {
  public let lastBump: Float;

  public static func Get(game: GameInstance) -> ref<PBCState> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"PBCState") as PBCState;
  }
}
