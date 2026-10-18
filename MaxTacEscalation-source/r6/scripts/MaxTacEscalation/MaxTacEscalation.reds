module MaxTacEscalation

// MaxTac Escalation: when enough NCPD officers die near V in a short window, MaxTac is called in.
// Counts every officer death near V no matter who caused it (gang vs NCPD street fights count),
// MaxTac's own casualties excluded. Escalation = raise the heat stage to Heat_5 (the vanilla MaxTac stage).
// If V has a heat level, the response is raised to Heat_5 (MaxTac hunts V, as vanilla).
// If V has NO heat, V is never targeted: a MaxTac squad is spawned at the fight instead and engages
// whoever is shooting at NCPD (they are NCPD-affiliated, hostile to the gangs, neutral to V).

public class MTEConfig {
  public static func KillThreshold() -> Int32 = 10;          // officers down within the window
  public static func WindowSeconds() -> Float = 600.0;       // 10 min sim time
  public static func Radius() -> Float = 80.0;               // metres from V
  public static func CooldownSeconds() -> Float = 1200.0;    // after a call-in, ignore deaths for 20 min
  public static func TargetHeat() -> EPreventionHeatStage = EPreventionHeatStage.Heat_5;
  public static func SquadSize() -> Int32 = 4;
  public static func Debug() -> Bool = false;
}

public class MTESystem extends ScriptableSystem {
  private let m_deaths: array<Float>;
  private let m_cooldownUntil: Float;

  public static func Get(game: GameInstance) -> ref<MTESystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"MaxTacEscalation.MTESystem") as MTESystem;
  }

  private func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  }

  public func OnOfficerDown(npc: ref<NPCPuppet>) -> Void {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) { return; };
    let now: Float = this.Now();
    if now < this.m_cooldownUntil { return; };
    if Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) > MTEConfig.Radius() { return; };

    // drop stale entries, then add this one
    let cutoff: Float = now - MTEConfig.WindowSeconds();
    while ArraySize(this.m_deaths) > 0 && this.m_deaths[0] < cutoff {
      ArrayErase(this.m_deaths, 0);
    };
    ArrayPush(this.m_deaths, now);

    if MTEConfig.Debug() {
      LogChannel(n"DEBUG", "MaxTacEscalation: officer down " + ToString(ArraySize(this.m_deaths)) + "/" + ToString(MTEConfig.KillThreshold()));
    };
    if ArraySize(this.m_deaths) < MTEConfig.KillThreshold() { return; };

    let ps: ref<PreventionSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(ps) { return; };
    ArrayClear(this.m_deaths);
    this.m_cooldownUntil = now + MTEConfig.CooldownSeconds();
    let heat: Int32 = EnumInt(ps.GetHeatStage());
    if heat > 0 {
      if heat < EnumInt(MTEConfig.TargetHeat()) {
        ps.ChangeHeatStage(MTEConfig.TargetHeat(), "MaxTacEscalation");
        player.SetWarningMessage("Too many officers down. MaxTac has been called in.");
      };
    } else {
      this.SpawnSquad(npc.GetWorldPosition());
    };
  }

  private func SpawnSquad(center: Vector4) -> Void {
    let dyn: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(dyn) { return; };
    let pool: array<TweakDBID> = [
      t"Character.maxtac_rifle_wa_elite", t"Character.maxtac_rifle_ma_elite",
      t"Character.maxtac_shotgun_ma_elite", t"Character.maxtac_sniper_wa_elite"
    ];
    let i: Int32 = 0;
    while i < MTEConfig.SquadSize() {
      let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
      spec.recordID = pool[i % ArraySize(pool)];
      spec.position = center + new Vector4(Cast<Float>(i % 2) * 3.0 - 1.5, Cast<Float>(i / 2) * 3.0 - 1.5, 0.0, 0.0);
      spec.tags = [n"MaxTacEscalation"];
      dyn.CreateEntity(spec);
      i += 1;
    };
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let npc: ref<NPCPuppet> = this as NPCPuppet;
  if !IsDefined(npc) { return result; };
  if Equals(npc.GetNPCRarity(), gamedataNPCRarity.MaxTac) { return result; };
  let record: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(npc.GetRecordID());
  if !IsDefined(record) { return result; };
  let affiliation: ref<Affiliation_Record> = record.Affiliation();
  if !IsDefined(affiliation) { return result; };
  if !Equals(affiliation.Type(), gamedataAffiliation.NCPD) { return result; };
  let sys: ref<MTESystem> = MTESystem.Get(npc.GetGame());
  if IsDefined(sys) { sys.OnOfficerDown(npc); };
  return result;
}
