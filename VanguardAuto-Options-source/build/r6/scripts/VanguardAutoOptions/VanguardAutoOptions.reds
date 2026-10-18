module VAO.Settings

// Mod Settings menu for Vanguard Auto: Mod Settings > Vanguard Auto.
// Every default matches stock Vanguard Auto, so nothing changes until a toggle is flipped.
// Redscript readers call the static getters; the CET Lua side reads the quest facts that
// PublishFacts() mirrors (fact value = setting + 1, so 0 means "not published yet").

@if(ModuleExists("ModSettingsModule"))
public class VanguardAutoOptionsSettings {
  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Insurance")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "0")
  @runtimeProperty("ModSettings.displayName", "Vanguard insurance")
  @runtimeProperty("ModSettings.description", "Master switch. Off: insurance does nothing. No premiums, no deductibles, no claims or payouts, no fraud strikes, and vehicles are never treated as insured. A destroyed vehicle then follows the Vehicle Loss settings. Existing policies are kept and come back when you turn this on again. Default: On.")
  public let insuranceEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Insurance")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "1")
  @runtimeProperty("ModSettings.displayName", "Waive premiums")
  @runtimeProperty("ModSettings.description", "Coverage still works, but policy payments (new term, installments, mid-term changes) cost nothing. Default: Off.")
  @runtimeProperty("ModSettings.dependency", "insuranceEnabled")
  public let waivePremiums: Bool = false;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Insurance")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "2")
  @runtimeProperty("ModSettings.displayName", "Waive repair deductibles")
  @runtimeProperty("ModSettings.description", "Insured repair claims cost nothing. Default: Off.")
  @runtimeProperty("ModSettings.dependency", "insuranceEnabled")
  public let waiveDeductibles: Bool = false;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Insurance")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "3")
  @runtimeProperty("ModSettings.displayName", "Total-loss claims")
  @runtimeProperty("ModSettings.description", "On: a destroyed insured vehicle becomes a total-loss claim you settle. Off: no claim is filed, so Vehicle Loss settings decide what happens to it. Default: On.")
  @runtimeProperty("ModSettings.dependency", "insuranceEnabled")
  public let totalLossClaims: Bool = true;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Insurance")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.order", "4")
  @runtimeProperty("ModSettings.displayName", "Fraud strikes and suspension")
  @runtimeProperty("ModSettings.description", "On: deliberately destroying an insured vehicle earns a fraud strike and can suspend your coverage. Off: it is handled like any other loss. Default: On.")
  @runtimeProperty("ModSettings.dependency", "insuranceEnabled")
  public let fraudStrikes: Bool = true;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Vehicle Loss")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.order", "0")
  @runtimeProperty("ModSettings.displayName", "Permanent loss when destroyed")
  @runtimeProperty("ModSettings.description", "On: a destroyed vehicle is lost for good (scrapped, or settled through a claim). Off: it stays in your garage and you pay a restoration fee instead. Vehicles already marked DESTROYED become usable again while this is off. Default: On.")
  public let permanentLoss: Bool = true;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Vehicle Loss")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.order", "1")
  @runtimeProperty("ModSettings.displayName", "Restoration fee (% of vehicle value)")
  @runtimeProperty("ModSettings.description", "Only used when Permanent loss is Off. Taken from your eddies when a vehicle is destroyed (as much as you have, up to the fee). Default: 25.")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let restoreFeePercent: Int32 = 25;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Repairs")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "0")
  @runtimeProperty("ModSettings.displayName", "Auto-repair on summon")
  @runtimeProperty("ModSettings.description", "On: a damaged insured vehicle is repaired (claim and deductible) when you summon it. Off: it stays damaged until you file a repair claim with the repair key. Default: On.")
  public let autoRepairOnSummon: Bool = true;

  @runtimeProperty("ModSettings.mod", "Vanguard Auto")
  @runtimeProperty("ModSettings.category", "Repairs")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.order", "1")
  @runtimeProperty("ModSettings.displayName", "Summon repair fee (% of normal)")
  @runtimeProperty("ModSettings.description", "Scales the game's own repair fee for summoning a damaged vehicle. 0 = free, 100 = normal. Default: 100.")
  @runtimeProperty("ModSettings.step", "10")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "200")
  public let summonRepairFeePercent: Int32 = 100;

  public cb func OnModSettingsChange() -> Void {
    VanguardAutoOptions.PublishFacts(GetGameInstance());
  }
}

public abstract class VanguardAutoOptions {
  @if(ModuleExists("ModSettingsModule"))
  private static func FindVar(category: CName, name: CName) -> ref<ConfigVar> {
    let variables: array<ref<ConfigVar>> = ModSettings.GetVars(n"Vanguard Auto", category);
    let i: Int32 = 0;

    while i < ArraySize(variables) {
      if Equals(variables[i].GetName(), name) {
        return variables[i];
      };
      i += 1;
    };
    return null;
  }

  @if(!ModuleExists("ModSettingsModule"))
  private static func FindVar(category: CName, name: CName) -> ref<ConfigVar> {
    return null;
  }

  private static func GetBool(category: CName, name: CName, fallback: Bool) -> Bool {
    let option: ref<ModConfigVarBool> = VanguardAutoOptions.FindVar(category, name) as ModConfigVarBool;
    if IsDefined(option) {
      return option.GetValue();
    };
    return fallback;
  }

  private static func GetInt(category: CName, name: CName, fallback: Int32) -> Int32 {
    let option: ref<ModConfigVarInt32> = VanguardAutoOptions.FindVar(category, name) as ModConfigVarInt32;
    if IsDefined(option) {
      return option.GetValue();
    };
    return fallback;
  }

  public static func InsuranceEnabled() -> Bool {
    return VanguardAutoOptions.GetBool(n"Insurance", n"insuranceEnabled", true);
  }

  public static func WaivePremiums() -> Bool {
    return VanguardAutoOptions.GetBool(n"Insurance", n"waivePremiums", false);
  }

  public static func WaiveDeductibles() -> Bool {
    return VanguardAutoOptions.GetBool(n"Insurance", n"waiveDeductibles", false);
  }

  // Claims are only filed while insurance itself is on.
  public static func TotalLossClaimsActive() -> Bool {
    return VanguardAutoOptions.InsuranceEnabled() && VanguardAutoOptions.GetBool(n"Insurance", n"totalLossClaims", true);
  }

  public static func FraudStrikesActive() -> Bool {
    return VanguardAutoOptions.InsuranceEnabled() && VanguardAutoOptions.GetBool(n"Insurance", n"fraudStrikes", true);
  }

  public static func PermanentLossEnabled() -> Bool {
    return VanguardAutoOptions.GetBool(n"Vehicle Loss", n"permanentLoss", true);
  }

  public static func RestoreFeePercent() -> Int32 {
    return Clamp(VanguardAutoOptions.GetInt(n"Vehicle Loss", n"restoreFeePercent", 25), 0, 100);
  }

  public static func AutoRepairOnSummon() -> Bool {
    return VanguardAutoOptions.GetBool(n"Repairs", n"autoRepairOnSummon", true);
  }

  public static func SummonRepairFeePercent() -> Int32 {
    return Clamp(VanguardAutoOptions.GetInt(n"Repairs", n"summonRepairFeePercent", 100), 0, 200);
  }

  private static func PublishBool(game: GameInstance, fact: CName, value: Bool) -> Void {
    let encoded: Int32 = 1;
    if value {
      encoded = 2;
    };
    SetFactValue(game, fact, encoded);
  }

  // The CET Lua side cannot read Mod Settings directly, so every setting is mirrored into a
  // quest fact (value + 1). Called on game attach and on every Mod Settings change.
  public static func PublishFacts(game: GameInstance) -> Void {
    if !GameInstance.IsValid(game) {
      return;
    };
    VanguardAutoOptions.PublishBool(game, n"vao_insurance", VanguardAutoOptions.InsuranceEnabled());
    VanguardAutoOptions.PublishBool(game, n"vao_waive_premiums", VanguardAutoOptions.WaivePremiums());
    VanguardAutoOptions.PublishBool(game, n"vao_waive_deductibles", VanguardAutoOptions.WaiveDeductibles());
    VanguardAutoOptions.PublishBool(game, n"vao_auto_repair", VanguardAutoOptions.AutoRepairOnSummon());
    VanguardAutoOptions.PublishBool(game, n"vao_permanent_loss", VanguardAutoOptions.PermanentLossEnabled());
    SetFactValue(game, n"vao_summon_fee_pct", VanguardAutoOptions.SummonRepairFeePercent() + 1);
  }

  @if(ModuleExists("ModSettingsModule"))
  public static func Attach(player: ref<PlayerPuppet>) -> ref<IScriptable> {
    let holder: ref<VanguardAutoOptionsSettings> = new VanguardAutoOptionsSettings();
    ModSettings.RegisterListenerToModifications(holder);
    VanguardAutoOptions.PublishFacts(player.GetGame());
    return holder;
  }

  @if(!ModuleExists("ModSettingsModule"))
  public static func Attach(player: ref<PlayerPuppet>) -> ref<IScriptable> {
    return null;
  }

  // Restoration fee for a destroyed vehicle while Permanent loss is off. Takes what the
  // player can afford, up to the fee. At most one charge per 10 s of game time, because a
  // single wreck is reported by several paths (health listener, summon check, adjudication).
  public static func ChargeRestoreFee(game: GameInstance, vehicleValue: Int32) -> Int32 {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(game);
    let now: Int32 = Cast<Int32>(EngineTime.ToFloat(GameInstance.GetSimTime(game)));
    let last: Int32 = GetFact(game, n"vao_fee_time");
    let fee: Int32 = vehicleValue * VanguardAutoOptions.RestoreFeePercent() / 100;
    let balance: Int32;
    let paid: Int32;
    let msg: SimpleScreenMessage;
    let blackboard: ref<IBlackboard>;

    if !IsDefined(player) || !IsDefined(ts) || fee <= 0 {
      return 0;
    };
    if last > 0 && now >= last - 1 && now - (last - 1) < 10 {
      return 0;
    };
    SetFactValue(game, n"vao_fee_time", now + 1);

    balance = ts.GetItemQuantity(player, MarketSystem.Money());
    paid = Min(fee, balance);
    if paid > 0 {
      ts.RemoveItem(player, MarketSystem.Money(), paid);
    };

    msg.isShown = true;
    msg.duration = 6.0;
    msg.message = s"Vanguard Auto: vehicle restored. Restoration fee charged: \(paid) eddies.";
    blackboard = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().UI_Notifications);
    blackboard.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
    return paid;
  }
}

@addField(PlayerPuppet)
public let vaoOptionsHolder: ref<IScriptable>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let ret: Bool = wrappedMethod();
  this.vaoOptionsHolder = VanguardAutoOptions.Attach(this);
  return ret;
}
