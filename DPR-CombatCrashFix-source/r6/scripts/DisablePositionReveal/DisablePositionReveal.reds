module TracePositionOverhaul
import TracePositionOverhaul.Config.*

@addMethod(ScriptedPuppet)
public final static func CanTrace(ownerPuppet: ref<ScriptedPuppet>) -> Bool {
  return ScriptedPuppet.IsAlive(ownerPuppet) && !ScriptedPuppet.IsDefeated(ownerPuppet) && !ScriptedPuppet.IsUnconscious(ownerPuppet) && !StatusEffectSystem.ObjectHasStatusEffectWithTag(ownerPuppet, n"HackInterrupt");
}

@addMethod(NPCPuppet)
public final static func IsTraceSkipped(ownerPuppet: wref<ScriptedPuppet>, playerID: EntityID) -> Bool {
  //LogChannel(n"DEBUG", "IsTraceSkipped");
  let traceControl: ref<TraceControlConfig> = TraceControlConfig.GetSettings();
  if !traceControl.isEnabled {
    return false;
  };
  let result: Bool = true;
  let statusEffects: array<ref<StatusEffect>>;
  let npc: wref<NPCPuppet> = ownerPuppet as NPCPuppet;
  GameInstance.GetStatusEffectSystem(ownerPuppet.GetGame()).GetAppliedEffectsWithTag(ownerPuppet.GetEntityID(), n"ForceTrace", statusEffects);
  if ArraySize(statusEffects) > 0 {
    return false;
  };
  if !Equals(ownerPuppet.GetEntityID(), playerID) {
    GameInstance.GetStatusEffectSystem(ownerPuppet.GetGame()).GetAppliedEffectsWithTag(playerID, n"ForceTrace", statusEffects);
    if ArraySize(statusEffects) > 0 {
      return false;
    };
  };
  if traceControl.traceFromProxy && TakeOverControlSystem.IsPlayerRemoteControlling(ownerPuppet.GetGame()) {
    //NPCPuppet.SetIsTracing(npc, true);
    return false;
  };
  if traceControl.traceNetwork {
    let squadMembers: array<EntityID>;
    let squadMember: wref<NPCPuppet>;
    let i: Int32 = 0;
    AISquadHelper.GetSquadmatesID(ownerPuppet, squadMembers, false);
    while i < ArraySize(squadMembers) {
      squadMember = GameInstance.FindEntityByID(ownerPuppet.GetGame(), squadMembers[i]) as NPCPuppet;
      if squadMember.IsNetrunnerPuppet() && ScriptedPuppet.CanTrace(squadMember) {
        NPCPuppet.SetIsTracing(squadMember, true);
        //LogChannel(n"DEBUG", "NetrunnerCanTrace");
        result = false;
      };
      i+=1;
    };
  };
  if traceControl.traceNetrunners {
    if ownerPuppet.IsNetrunnerPuppet() {
      NPCPuppet.SetIsTracing(npc, true);
      return false;
    };
  };
  if traceControl.traceAbilities {
    let hasICE: ref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.HasICELevelBooster");
    let hasTracingICE: ref<GameplayAbility_Record> = TweakDBInterface.GetGameplayAbilityRecord(t"Ability.HasTracingICE");
    if (IsDefined(hasICE) && AIActionHelper.CheckAbility(ownerPuppet, hasICE)) || (IsDefined(hasTracingICE) && AIActionHelper.CheckAbility(ownerPuppet, hasTracingICE)) {
      NPCPuppet.SetIsTracing(npc, true);
      return false;
    };
  };
  if traceControl.traceRarity {
    let npcRarity: gamedataNPCRarity = ownerPuppet.GetNPCRarity();
    if Equals(npcRarity, gamedataNPCRarity.Boss) || Equals(npcRarity, gamedataNPCRarity.Elite) || Equals(npcRarity, gamedataNPCRarity.MaxTac) {
      NPCPuppet.SetIsTracing(npc, true);
      return false;
    };
  };
  if traceControl.traceMechanical && ownerPuppet.IsMechanical() {
    NPCPuppet.SetIsTracing(npc, true);
    return false;
  };
  return result;
}

@addMethod(TakeOverControlSystem)
public final static func IsPlayerRemoteControlling(game: GameInstance) -> Bool {
  let player: wref<PlayerPuppet> = GetPlayer(game) as PlayerPuppet;
  if !player.IsPlayer() || player.IsReplacer() {
    return false;
  };
  if player.GetTakeOverControlSystem().IsDeviceControlled() {
    return true;
  };    
  let playerStateMachineBlackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine);
  let vehicleID: EntityID = playerStateMachineBlackboard.GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.EntityIDVehicleRemoteControlled);
  if EntityID.IsDefined(vehicleID) {
    let vehicle: wref<VehicleObject>;
    VehicleComponent.GetVehicleFromID(game, vehicleID, vehicle);
    return IsDefined(vehicle);
  };
  return false;
}

@wrapMethod(NPCPuppet)
public final static func RevealPlayerPositionIfNeeded(ownerPuppet: wref<ScriptedPuppet>, playerID: EntityID, opt isPrevention: Bool) -> Bool {
  if ScriptedPuppet.IsUnconscious(ownerPuppet) || ownerPuppet.IsDead() || ownerPuppet.GetCrowd() {
    return false;
  };
  if NPCPuppet.IsTraceSkipped(ownerPuppet, playerID) {
    return false;
  };
  return wrappedMethod(ownerPuppet, playerID, isPrevention);
}


///////////////////////////////////////////////////////////////////////////////////////////////
// Define tracing state and interrupt process when appropriate

@addField(NPCPuppet)
static let m_traceControl: ref<TraceControlConfig>;

@addField(NPCPuppet)
private let m_isTracing: Bool;

@wrapMethod(NPCPuppet)
protected cb func OnPostInitialize(evt: ref<entPostInitializeEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.m_traceControl = TraceControlConfig.GetSettings();
  return result;
}

@wrapMethod(NPCPuppet)
protected cb func OnPreUninitialize(evt: ref<entPreUninitializeEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.m_traceControl = null;
  return result;
}

@addMethod(NPCPuppet)
public func GetIsTracing() -> Bool {
  return this.m_isTracing;
}

@addMethod(NPCPuppet)
public static func SetIsTracing(obj: ref<GameObject>, newstate: Bool) -> Void {
  let npc: wref<NPCPuppet> = obj as NPCPuppet;
  let playerPuppet: wref<PlayerPuppet> = GetPlayer(npc.GetGame()) as PlayerPuppet;
  if !IsDefined(npc) || !IsDefined(playerPuppet) || playerPuppet.IsReplacer() {
    return;
  };
  if npc.m_traceControl.traceFromProxy && playerPuppet.GetTakeOverControlSystem().IsDeviceControlled() {
    return;
  };
  if playerPuppet.IsInCombat() {
    // Patch (DPR-CombatCrashFix): only clear the highlight on an NPC that was tracing. Calling it on every
    // NPC entering combat reached NPCs still attaching (Night City Allies' Jackie) whose scanning
    // controller isn't created yet -> null read in ScanningController::SetScannableThroughWalls.
    if npc.m_isTracing {
      npc.m_isTracing = false;
      npc.ForceVisionAppearanceNetrunner(npc, npc.GetEntityID(), n"EnemyNetrunner", false);
    };
    return;
  };
  npc.m_isTracing = newstate;
  if newstate {
    let playerCanTraceBack: Bool = GameInstance.GetStatsSystem(playerPuppet.GetGame()).GetStatValue(Cast<StatsObjectID>(playerPuppet.GetEntityID()), gamedataStatType.RevealNetrunnerWhenHacked) > 0.00;
    if npc.m_traceControl.reverseTrace && playerCanTraceBack {
      npc.ForceVisionAppearanceNetrunner(npc, npc.GetEntityID(), n"EnemyNetrunner", true);
    };
  }
  else {
    if playerPuppet.IsBeingRevealed() && npc.m_traceControl.traceInterrupt && !npc.IsSquadTracing() {
      StatusEffectHelper.ApplyStatusEffect(playerPuppet, t"BaseStatusEffect.RevealInterrupted");
      npc.ForceVisionAppearanceNetrunner(npc, npc.GetEntityID(), n"EnemyNetrunner", false);
    };
  };
}

@wrapMethod(NPCPuppet)
public final static func ChangeHighLevelState(obj: ref<GameObject>, newState: gamedataNPCHighLevelState) -> Void {
  wrappedMethod(obj, newState);
  if Equals(newState, gamedataNPCHighLevelState.Combat) {
    //LogChannel(n"DEBUG", "> ChangeHighLevelState (Combat)");
    NPCPuppet.SetIsTracing(obj, false);
  };
}

@addMethod(NPCPuppet)
protected cb func OnDamageReceived(evt: ref<gameDamageReceivedEvent>) -> Bool {
  if evt.hitEvent.attackData.HasFlag(hitFlag.WasKillingBlow) {
    //LogChannel(n"DEBUG", "> OnDamageReceived (KillingBlow)");
    NPCPuppet.SetIsTracing(this, false);
  };
  super.OnDamageReceived(evt);
}

@addMethod(NPCPuppet)
protected cb func OnDefeated(evt: ref<DefeatedEvent>) -> Bool {
  //LogChannel(n"DEBUG", "> NPC Defeated");
  NPCPuppet.SetIsTracing(this, false);
  super.OnDefeated(evt);
}

@wrapMethod(LocomotionTakedownEvents)
private final func DefeatTarget(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, activator: wref<GameObject>, target: wref<GameObject>, effectName: CName, effectTag: CName) -> Void {
  //LogChannel(n"DEBUG", "> DefeatTarget");
  let npcPuppet: wref<NPCPuppet> = target as NPCPuppet;
  if IsDefined(npcPuppet) {
    NPCPuppet.SetIsTracing(npcPuppet, false);
  };
  wrappedMethod(stateContext, scriptInterface, activator, target, effectName, effectTag);
}

@addMethod(NPCPuppet)
public func IsSquadTracing() -> Bool {
  let squadMembers: array<EntityID>;
  let squadMember: wref<NPCPuppet>;
  let i: Int32 = 0;
  AISquadHelper.GetSquadmatesID(this, squadMembers, true);
  //LogChannel(n"DEBUG", ">> IsSquadTracing: "+ToString(ArraySize(squadMembers)));
  while i < ArraySize(squadMembers) {
    squadMember = GameInstance.FindEntityByID(this.GetGame(), squadMembers[i]) as NPCPuppet;
    if IsDefined(squadMember) {
      if squadMember.GetIsTracing() {
        //LogChannel(n"DEBUG", ">> ("+ToString(i)+" is tracing)");
        return true;
      };
    };
    i += 1;
  };
  return false;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// Ping + Counter-A-Hack interaction

@addField(PingSquadEffector)
static let traceControl: ref<TraceControlConfig>;

@wrapMethod(PingSquadEffector)
protected func Initialize(record: TweakDBID, game: GameInstance, parentRecord: TweakDBID) -> Void {
  wrappedMethod(record, game, parentRecord);
  this.traceControl = TraceControlConfig.GetSettings();
}

@wrapMethod(PingSquadEffector)
protected func Uninitialize(game: GameInstance) -> Void {
  this.traceControl = null;
  wrappedMethod(game);
}

@wrapMethod(PingSquadEffector)
protected func ActionOn(owner: ref<GameObject>) -> Void {
  if (owner as ScriptedPuppet).IsNetrunnerPuppet() {
    if this.traceControl.isEnabled && this.traceControl.pingNetrunners && GameInstance.GetStatsSystem(owner.GetGame()).GetStatValue(Cast<StatsObjectID>(GetPlayer(owner.GetGame()).GetEntityID()), gamedataStatType.RevealNetrunnerWhenHacked) > 0.00 {
      GameObject.TagObject(owner);
    };
  };
  wrappedMethod(owner);
}


///////////////////////////////////////////////////////////////////////////////////////////////
// Can Netrunners Ping?

public class CanNetrunnersPing extends ScriptableSystem {

  private func OnDetach() -> Void {
    let traceControl: ref<TraceControlConfig> = TraceControlConfig.GetSettings();
    if traceControl.netrunnersCanPing {
      TweakDBManager.SetFlat(t"Ability.CanPingQuickHack_inline2.value", 1.0);
    } else {
      TweakDBManager.SetFlat(t"Ability.CanPingQuickHack_inline2.value", 0.0);
    };
    TweakDBManager.UpdateRecord(t"Ability.CanPingQuickHack_inline2");
  }

}


///////////////////////////////////////////////////////////////////////////////////////////////
// Housekeeping

@wrapMethod(ScriptedPuppet)
public final const func IsNetrunnerPuppet() -> Bool {
  let result: Bool = wrappedMethod();
  if !result {
    result = AIActionHelper.CheckAbility(this, TweakDBInterface.GetGameplayAbilityRecord(t"Ability.CanQuickhack"));
  };
  return result;
}


