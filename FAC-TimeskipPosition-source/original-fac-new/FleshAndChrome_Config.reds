module FleshAndChrome

import RedscriptConfigFramework.*
import Codeware.Localization.*

// Flesh and Chrome - Config (✿◠‿◠)

public class FACConfig extends ScriptableSystem {

  public static func Get() -> ref<FACConfig> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"FleshAndChrome.FACConfig") as FACConfig;
  }

  private let m_provider: ref<FAC_DVRCFProvider>;

  private func OnAttach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    this.m_provider = new FAC_DVRCFProvider();
    this.m_provider.Init(gi, this);
    DVRCF_Store.RestoreInto(gi, "FleshAndChrome", this.m_provider, this.m_provider.BuildSchema());
    this.HealPoisonedRestoreSeeds(gi);
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  private func HealPoisonedRestoreSeeds(gi: GameInstance) -> Void {
    if this.perkKineticAbsorptionRestore != 0 { return; }
    this.perkMeanStreakRestore = 200;
    this.perkCreepingDeathRestore = 150;
    this.perkCaliforniaReaperRestore = 250;
    this.perkAftershockRestore = 30;
    this.perkSlaughterhouseRestore = 25;
    this.perkKineticAbsorptionRestore = 50;
    this.perkTailWindRestore = 25;
    DVRCF_Store.PersistFrom(gi, "FleshAndChrome", this.m_provider, this.m_provider.BuildSchema());
    RedLogger.LogInfo("FleshAndChrome", "Healed poisoned restore-slider seeds (type-flag fix) - defaults rewritten to the settings store.");
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    if IsDefined(this.m_provider) {
      let gi: GameInstance = this.GetGameInstance();
      let title: String = "Flesh and Chrome";
      let desc: String = "A stamina and energy survival layer: moving, fighting, and cyberware tire you out; eat, drink, smoke, and sleep to recover.";
      let sys: ref<LocalizationSystem> = LocalizationSystem.GetInstance(gi);
      if IsDefined(sys) {
        title = sys.GetText("FAC.Mod.Name");
        desc = sys.GetText("FAC.Mod.Desc");
      }
      DVRCF.Register(gi, "FleshAndChrome", title, desc, this.m_provider);
    }
    
    let facSys: ref<FACSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance())
      .Get(n"FleshAndChrome.FACSystem") as FACSystem;
    if IsDefined(facSys) { facSys.QueueTooltipRefresh(); }
  }

  public let modON: Bool = true;
  public let showOptions: Bool = false;

  public let disableCombatHealthRegen: Bool = true;

  public let baseStamina: Float = 5000.0;
  public let bodyStaminaBonus: Float = 2000.0;
  public let baseEnergy: Float = 5000.0;
  public let bodyEnergyBonus: Float = 2000.0;

  public let reflexCooldownReduction: Float = 40.0;
  public let reflexCostReduction: Float = 40.0;

  public let jogDrainRate: Float = 0.17;
  public let combatDrainRate: Float = 0.69;
  public let sprintDrainRate: Float = 16.67;
  public let crouchMoveDrainRate: Float = 0.35;

  public let jumpCost: Float = 100.0;
  public let dodgeCost: Float = 120.0;
  public let slideCost: Float = 150.0;
  public let meleeCost: Float = 200.0;

  public let staminaRegenRate: Float = 2.78;
  public let regenDelayCooldownMinutes: Int32 = 10;
  public let energyCostPerStamina: Float = 0.25;

  public let mealEnergyRestorePercent: Int32 = 10;
  public let mealDrinkBonusPercent: Int32 = 5;
  public let maxMealsPerDay: Int32 = 2;
  public let mealDrinkWindowMinutes: Int32 = 10;
  public let snackStaminaRestorePercent: Int32 = 7;
  public let maxSnacksPerDay: Int32 = 4;
  public let maxDrinksPerDay: Int32 = 6;
  public let drinkStaminaRefreshPercent: Int32 = 5;
  public let drinkEnergyRefreshPercent: Int32 = 1;
  public let mrWhiteyStaminaPercent: Int32 = 20;
  public let mrWhiteyEnergyDrainPercent: Int32 = 20;
  
  public let alcoholExtraSleepHoursPerDrink: Int32 = 1;
  public let alcoholMaxExtraSleepHours: Int32 = 6;
  
  public let alcoholSoberBaseHours: Int32 = 6;
  public let alcoholSoberHoursPerExtraDrink: Int32 = 1;
  public let smokingCooldownReductionPercent: Int32 = 75;
  public let smokingRegenPenaltyPercent: Int32 = 30;
  public let smokingPenaltyDurationMinutes: Int32 = 30;

  public let energyReductionPerImplant: Int32 = 3;
  public let maxCywareEnergyReduction: Int32 = 100;

  public let synLungsMaxStaminaBonusPercent: Int32 = 12;     
  public let synLungsRegenBonusPercent: Int32 = 40;          
  public let synLungsDelayReductionPercent: Int32 = 40;      
  public let synLungsSmokingReductionPercent: Int32 = 50;    
  public let adrenalineMeleeRestorePercent: Int32 = 7;       
  public let denseMarrowMeleeCostPercent: Int32 = 20;        
  public let kineticFramePlateauPercent: Int32 = 75;         
  public let kineticFrameFloorFraction: Int32 = 25;          
  public let isometricMinPercent: Int32 = 13;                
  public let isometricMaxPercent: Int32 = 20;                
  public let ubMinPercent: Int32 = 15;                       
  public let ubMaxPercent: Int32 = 30;                       
  public let berserkStaminaReductionPercent: Int32 = 100;    
  public let apogeeKillRestorePercent: Int32 = 22;           

  public let perkDashReductionPercent: Int32 = 20;           
  public let perkAirDashReductionPercent: Int32 = 10;        
  public let perkLeadStealReductionPercent: Int32 = 15;      
  public let perkBladerunnerReductionPercent: Int32 = 15;    
  public let perkWreckingBallReductionPercent: Int32 = 15;   
  public let perkQuakeReductionPercent: Int32 = 15;          
  public let perkDeadEyeReductionPercent: Int32 = 25;        
  public let perkShinobiReductionPercent: Int32 = 40;        

  public let perkMeanStreakRestore: Int32 = 200;             
  public let perkCreepingDeathRestore: Int32 = 150;          
  public let perkSharpshooterRegenPercent: Int32 = 7;        
  public let perkCaliforniaReaperRestore: Int32 = 250;       
  public let perkAftershockRestore: Int32 = 30;              
  public let perkSlaughterhouseRestore: Int32 = 25;          
  public let perkKineticAbsorptionRestore: Int32 = 50;       
  public let perkTailWindRestore: Int32 = 25;                

  public let deadEyeFullStaminaPercent: Int32 = 85;          
  public let focusCooldownMinSeconds: Int32 = 5;             
  public let focusCooldownMaxSeconds: Int32 = 45;            
  public let dontStopThresholdPercent: Int32 = 33;           

  public let disableRecoilRecovery: Bool = true;
  public let swayThresholdPercent: Int32 = 10;
  public let weaponPenaltySeverity: Float = 1.0;
  public let breathingThresholdPercent: Int32 = 10;
  public let breathingMaxAmplitude: Float = 3.0;
  public let tfpBreathingEnabled: Bool = true;
  public let tfpBreathingMaxIntensity: Float = 1.0;
  public let meleeThresholdPercent: Int32 = 10;
  public let meleeDamageMinPercent: Int32 = 5;

  public let fatigueMultiplierCap: Float = 3.0;

  public let pauseFatigueInWorkspot: Bool = true;

  public let minSleepHoursForFullReset: Int32 = 6;
  public let timeSkipThresholdMinutes: Int32 = 30;
  public let enableCarSleep: Bool = true;
  public let carSleepOwnedOnly: Bool = false;
  public let carSleepEfficiency: Int32 = 50;
  public let showBarsOnTimeskip: Bool = true;

  public let showBarOnConsumables: Bool = true;
  public let showBarOnFood: Bool = true;
  public let showBarOnAllItems: Bool = true;
  public let showBarOnWeaponWheel: Bool = true;
  public let barOffsetX: Float = 0.0;
  public let barOffsetY: Float = 240.0;
  public let wheelBarOffsetX: Float = 0.0;
  public let wheelBarOffsetY: Float = 240.0;

  public let staminaDrainColorThreshold: Float = 0.0;

  public let visionBlurEnabled: Bool = true;
  public let tunnelVisionThresholdPercent: Int32 = 20;
  public let visionFlashThresholdPercent: Int32 = 5;

  public let debugON: Bool = false;
}

public static func ShowDebugLogsFAC() -> Bool = false
