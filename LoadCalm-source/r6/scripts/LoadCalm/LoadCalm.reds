module LoadCalm

// Crowd Load Calm: for a few seconds after a save load or a long-distance teleport (fast travel, metro),
// pedestrians ignore crowd panic stimuli. Spawn-time noise - traffic clipping into pedestrians while the area
// streams in, panic restored from the save - otherwise sends whole streets running the moment V arrives
// (Street Sense's fear propagation spreads one scared pedestrian to everyone within ~70 m).
// Never suppressed: panic while V has a non-fist weapon out or is in combat.

public class LoadCalmSystem extends ScriptableSystem {
  private let m_calmUntil: Float;
  private let m_lastPos: Vector4;
  private let m_hasPos: Bool;
  private let m_tickArmed: Bool;

  public static func GraceSeconds() -> Float = 12.0;
  // Fast travel and metro jumps are hundreds of metres to kilometres; even modded cars stay far below this per second.
  public static func TeleportDistance() -> Float = 400.0;

  public static func Get(game: GameInstance) -> ref<LoadCalmSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"LoadCalm.LoadCalmSystem") as LoadCalmSystem;
  }

  private func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  }

  public func StartCalm() -> Void {
    this.m_calmUntil = this.Now() + LoadCalmSystem.GraceSeconds();
  }

  public func IsCalm() -> Bool {
    return this.Now() < this.m_calmUntil;
  }

  public func StartWatching() -> Void {
    this.m_hasPos = false;
    if this.m_tickArmed { return; };
    this.m_tickArmed = true;
    this.Schedule();
  }

  private func Schedule() -> Void {
    let cb: ref<LoadCalmTick> = new LoadCalmTick();
    cb.m_system = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 1.0, false);
  }

  public func Tick() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      let pos: Vector4 = player.GetWorldPosition();
      if this.m_hasPos && Vector4.Distance(pos, this.m_lastPos) > LoadCalmSystem.TeleportDistance() {
        this.StartCalm();
      };
      this.m_lastPos = pos;
      this.m_hasPos = true;
    };
    this.Schedule();
  }
}

public class LoadCalmTick extends DelayCallback {
  public let m_system: wref<LoadCalmSystem>;

  public func Call() -> Void {
    if IsDefined(this.m_system) {
      this.m_system.Tick();
    };
  }
}

public static func LoadCalm_PlayerIsThreatening(game: GameInstance) -> Bool {
  let player: ref<PlayerPuppet> = GetPlayer(game);
  if !IsDefined(player) { return false; };
  let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(player);
  if IsDefined(weapon) && !WeaponObject.IsFists(weapon.GetItemID()) { return true; };
  let psm: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).GetLocalInstanced(player.GetEntityID(), GetAllBlackboardDefs().PlayerStateMachine);
  return IsDefined(psm) && psm.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat) == EnumInt(gamePSMCombat.InCombat);
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let sys: ref<LoadCalmSystem> = LoadCalmSystem.Get(this.GetGame());
  if IsDefined(sys) {
    sys.StartCalm();
    sys.StartWatching();
  };
  return result;
}

@wrapMethod(ReactionManagerComponent)
private func HandleCrowdReaction(stimEvent: ref<StimuliEvent>) -> Void {
  let owner: ref<GameObject> = this.GetOwner();
  if IsDefined(owner) {
    let sys: ref<LoadCalmSystem> = LoadCalmSystem.Get(owner.GetGame());
    if IsDefined(sys) && sys.IsCalm() && !LoadCalm_PlayerIsThreatening(owner.GetGame()) {
      return;
    };
  };
  wrappedMethod(stimEvent);
}
