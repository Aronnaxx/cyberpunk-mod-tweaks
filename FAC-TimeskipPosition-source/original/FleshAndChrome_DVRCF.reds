// RCF provider: builds the FAC config panel + binds every setting. (｡◕‿◕｡)
module FleshAndChrome

import RedscriptConfigFramework.*
import Codeware.Localization.*

public class FAC_DVRCFProvider extends DVRCF_Provider {
  private let m_gi: GameInstance;
  private let m_cfg: wref<FACConfig>;

  public func Init(gi: GameInstance, cfg: ref<FACConfig>) -> Void {
    this.m_gi = gi;
    this.m_cfg = cfg;
  }

  private func Loc(key: String) -> String {
    let sys: ref<LocalizationSystem> = LocalizationSystem.GetInstance(this.m_gi);
    if !IsDefined(sys) { return key; }
    return sys.GetText(key);
  }

  public func OnSave() -> Void {
    let sys: ref<FACSystem> = GameInstance.GetScriptableSystemsContainer(this.m_gi).Get(n"FleshAndChrome.FACSystem") as FACSystem;
    if IsDefined(sys) {
      sys.OnConfigChanged();
    }
  }

  public func BuildSchema() -> ref<DVRCF_Schema> {
    let b: ref<DVRCF_SchemaBuilder> = DVRCF_SchemaBuilder.New("FLESH AND CHROME");
    b.Tab(this.Loc("FAC.tab.Main"));
    b.Section(this.Loc("FAC.sec.Main_General"));
    b.Toggle("modON", this.Loc("FAC.modON.Name"));
    b.Tip(this.Loc("FAC.modON.Desc"));
    b.Toggle("disableCombatHealthRegen", this.Loc("FAC.disableCombatHealthRegen.Name"));
    b.Tip(this.Loc("FAC.disableCombatHealthRegen.Desc"));
    b.Section(this.Loc("FAC.sec.Main_Debug"));
    b.Toggle("debugON", this.Loc("FAC.debugON.Name"));
    b.Tip(this.Loc("FAC.debugON.Desc"));
    b.Tab(this.Loc("FAC.tab.Pools"));
    b.Section(this.Loc("FAC.sec.Pools_CorePools"));
    b.Slider("baseStamina", this.Loc("FAC.baseStamina.Name"), 1000.0, 10000.0, 100.0, false);
    b.Tip(this.Loc("FAC.baseStamina.Desc"));
    b.Slider("bodyStaminaBonus", this.Loc("FAC.bodyStaminaBonus.Name"), 0.0, 5000.0, 100.0, false);
    b.Tip(this.Loc("FAC.bodyStaminaBonus.Desc"));
    b.Slider("baseEnergy", this.Loc("FAC.baseEnergy.Name"), 1000.0, 10000.0, 100.0, false);
    b.Tip(this.Loc("FAC.baseEnergy.Desc"));
    b.Slider("bodyEnergyBonus", this.Loc("FAC.bodyEnergyBonus.Name"), 0.0, 5000.0, 100.0, false);
    b.Tip(this.Loc("FAC.bodyEnergyBonus.Desc"));
    b.Section(this.Loc("FAC.sec.Pools_ReflexScaling"));
    b.Slider("reflexCooldownReduction", this.Loc("FAC.reflexCooldownReduction.Name"), 0.0, 80.0, 5.0, false);
    b.Tip(this.Loc("FAC.reflexCooldownReduction.Desc"));
    b.Slider("reflexCostReduction", this.Loc("FAC.reflexCostReduction.Name"), 0.0, 80.0, 5.0, false);
    b.Tip(this.Loc("FAC.reflexCostReduction.Desc"));
    b.Section(this.Loc("FAC.sec.Pools_Regeneration"));
    b.Slider("staminaRegenRate", this.Loc("FAC.staminaRegenRate.Name"), 0.1, 50.0, 0.1, false);
    b.Tip(this.Loc("FAC.staminaRegenRate.Desc"));
    b.Slider("regenDelayCooldownMinutes", this.Loc("FAC.regenDelayCooldownMinutes.Name"), 0.0, 30.0, 1.0, true);
    b.Tip(this.Loc("FAC.regenDelayCooldownMinutes.Desc"));
    b.Slider("energyCostPerStamina", this.Loc("FAC.energyCostPerStamina.Name"), 0.05, 1.0, 0.01, false);
    b.Tip(this.Loc("FAC.energyCostPerStamina.Desc"));
    b.Tab(this.Loc("FAC.tab.Movement"));
    b.Section(this.Loc("FAC.sec.Movement_DrainRates"));
    b.Slider("jogDrainRate", this.Loc("FAC.jogDrainRate.Name"), 0.01, 5.0, 0.01, false);
    b.Tip(this.Loc("FAC.jogDrainRate.Desc"));
    b.Slider("combatDrainRate", this.Loc("FAC.combatDrainRate.Name"), 0.01, 5.0, 0.01, false);
    b.Tip(this.Loc("FAC.combatDrainRate.Desc"));
    b.Slider("sprintDrainRate", this.Loc("FAC.sprintDrainRate.Name"), 1.0, 100.0, 0.5, false);
    b.Tip(this.Loc("FAC.sprintDrainRate.Desc"));
    b.Slider("crouchMoveDrainRate", this.Loc("FAC.crouchMoveDrainRate.Name"), 0.01, 5.0, 0.01, false);
    b.Tip(this.Loc("FAC.crouchMoveDrainRate.Desc"));
    b.Section(this.Loc("FAC.sec.Movement_InstantCosts"));
    b.Slider("jumpCost", this.Loc("FAC.jumpCost.Name"), 0.0, 500.0, 5.0, false);
    b.Tip(this.Loc("FAC.jumpCost.Desc"));
    b.Slider("dodgeCost", this.Loc("FAC.dodgeCost.Name"), 0.0, 500.0, 5.0, false);
    b.Tip(this.Loc("FAC.dodgeCost.Desc"));
    b.Slider("slideCost", this.Loc("FAC.slideCost.Name"), 0.0, 500.0, 5.0, false);
    b.Tip(this.Loc("FAC.slideCost.Desc"));
    b.Slider("meleeCost", this.Loc("FAC.meleeCost.Name"), 0.0, 500.0, 5.0, false);
    b.Tip(this.Loc("FAC.meleeCost.Desc"));
    b.Tab(this.Loc("FAC.tab.Consumables"));
    b.Section(this.Loc("FAC.sec.Consumables_General"));
    b.Group(this.Loc("FAC.grp.mealEnergyRestorePercent"));
    b.Slider("mealEnergyRestorePercent", this.Loc("FAC.mealEnergyRestorePercent.Name"), 1.0, 30.0, 1.0, true);
    b.Tip(this.Loc("FAC.mealEnergyRestorePercent.Desc"));
    b.Slider("mealDrinkBonusPercent", this.Loc("FAC.mealDrinkBonusPercent.Name"), 0.0, 15.0, 1.0, true);
    b.Tip(this.Loc("FAC.mealDrinkBonusPercent.Desc"));
    b.Slider("maxMealsPerDay", this.Loc("FAC.maxMealsPerDay.Name"), 1.0, 4.0, 1.0, true);
    b.Tip(this.Loc("FAC.maxMealsPerDay.Desc"));
    b.Slider("mealDrinkWindowMinutes", this.Loc("FAC.mealDrinkWindowMinutes.Name"), 1.0, 60.0, 1.0, true);
    b.Tip(this.Loc("FAC.mealDrinkWindowMinutes.Desc"));
    b.Group(this.Loc("FAC.grp.snackStaminaRestorePercent"));
    b.Slider("snackStaminaRestorePercent", this.Loc("FAC.snackStaminaRestorePercent.Name"), 1.0, 20.0, 1.0, true);
    b.Tip(this.Loc("FAC.snackStaminaRestorePercent.Desc"));
    b.Slider("maxSnacksPerDay", this.Loc("FAC.maxSnacksPerDay.Name"), 1.0, 8.0, 1.0, true);
    b.Tip(this.Loc("FAC.maxSnacksPerDay.Desc"));
    b.Slider("maxDrinksPerDay", this.Loc("FAC.maxDrinksPerDay.Name"), 1.0, 10.0, 1.0, true);
    b.Tip(this.Loc("FAC.maxDrinksPerDay.Desc"));
    b.Slider("drinkStaminaRefreshPercent", this.Loc("FAC.drinkStaminaRefreshPercent.Name"), 0.0, 15.0, 1.0, true);
    b.Tip(this.Loc("FAC.drinkStaminaRefreshPercent.Desc"));
    b.Slider("drinkEnergyRefreshPercent", this.Loc("FAC.drinkEnergyRefreshPercent.Name"), 0.0, 10.0, 1.0, true);
    b.Tip(this.Loc("FAC.drinkEnergyRefreshPercent.Desc"));
    b.Group(this.Loc("FAC.grp.mrWhiteyStaminaPercent"));
    b.Slider("mrWhiteyStaminaPercent", this.Loc("FAC.mrWhiteyStaminaPercent.Name"), 5.0, 50.0, 1.0, true);
    b.Tip(this.Loc("FAC.mrWhiteyStaminaPercent.Desc"));
    b.Slider("mrWhiteyEnergyDrainPercent", this.Loc("FAC.mrWhiteyEnergyDrainPercent.Name"), 5.0, 50.0, 1.0, true);
    b.Tip(this.Loc("FAC.mrWhiteyEnergyDrainPercent.Desc"));
    b.Group(this.Loc("FAC.grp.alcohol"));
    b.Slider("alcoholExtraSleepHoursPerDrink", this.Loc("FAC.alcoholExtraSleepHoursPerDrink.Name"), 0.0, 4.0, 1.0, true);
    b.Tip(this.Loc("FAC.alcoholExtraSleepHoursPerDrink.Desc"));
    b.Slider("alcoholMaxExtraSleepHours", this.Loc("FAC.alcoholMaxExtraSleepHours.Name"), 0.0, 12.0, 1.0, true);
    b.Tip(this.Loc("FAC.alcoholMaxExtraSleepHours.Desc"));
    b.Slider("alcoholSoberBaseHours", this.Loc("FAC.alcoholSoberBaseHours.Name"), 1.0, 24.0, 1.0, true);
    b.Tip(this.Loc("FAC.alcoholSoberBaseHours.Desc"));
    b.Slider("alcoholSoberHoursPerExtraDrink", this.Loc("FAC.alcoholSoberHoursPerExtraDrink.Name"), 0.0, 4.0, 1.0, true);
    b.Tip(this.Loc("FAC.alcoholSoberHoursPerExtraDrink.Desc"));
    b.Group(this.Loc("FAC.grp.smokingCooldownReductionPercent"));
    b.Slider("smokingCooldownReductionPercent", this.Loc("FAC.smokingCooldownReductionPercent.Name"), 25.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.smokingCooldownReductionPercent.Desc"));
    b.Slider("smokingRegenPenaltyPercent", this.Loc("FAC.smokingRegenPenaltyPercent.Name"), 10.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.smokingRegenPenaltyPercent.Desc"));
    b.Slider("smokingPenaltyDurationMinutes", this.Loc("FAC.smokingPenaltyDurationMinutes.Name"), 5.0, 60.0, 5.0, true);
    b.Tip(this.Loc("FAC.smokingPenaltyDurationMinutes.Desc"));
    b.Tab(this.Loc("FAC.tab.Combat"));
    b.Section(this.Loc("FAC.sec.Combat_Cyberware"));
    b.Slider("energyReductionPerImplant", this.Loc("FAC.energyReductionPerImplant.Name"), 0.0, 10.0, 1.0, true);
    b.Tip(this.Loc("FAC.energyReductionPerImplant.Desc"));
    b.Slider("maxCywareEnergyReduction", this.Loc("FAC.maxCywareEnergyReduction.Name"), 0.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.maxCywareEnergyReduction.Desc"));
    b.Group(this.Loc("FAC.grp.synLungsMaxStaminaBonusPercent"));
    b.Slider("synLungsMaxStaminaBonusPercent", this.Loc("FAC.synLungsMaxStaminaBonusPercent.Name"), 0.0, 15.0, 1.0, true);
    b.Tip(this.Loc("FAC.synLungsMaxStaminaBonusPercent.Desc"));
    b.Slider("synLungsRegenBonusPercent", this.Loc("FAC.synLungsRegenBonusPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.synLungsRegenBonusPercent.Desc"));
    b.Slider("synLungsDelayReductionPercent", this.Loc("FAC.synLungsDelayReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.synLungsDelayReductionPercent.Desc"));
    b.Slider("synLungsSmokingReductionPercent", this.Loc("FAC.synLungsSmokingReductionPercent.Name"), 0.0, 75.0, 5.0, true);
    b.Tip(this.Loc("FAC.synLungsSmokingReductionPercent.Desc"));
    b.Slider("adrenalineMeleeRestorePercent", this.Loc("FAC.adrenalineMeleeRestorePercent.Name"), 0.0, 15.0, 1.0, true);
    b.Tip(this.Loc("FAC.adrenalineMeleeRestorePercent.Desc"));
    b.Slider("denseMarrowMeleeCostPercent", this.Loc("FAC.denseMarrowMeleeCostPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.denseMarrowMeleeCostPercent.Desc"));
    b.Slider("kineticFramePlateauPercent", this.Loc("FAC.kineticFramePlateauPercent.Name"), 0.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.kineticFramePlateauPercent.Desc"));
    b.Slider("kineticFrameFloorFraction", this.Loc("FAC.kineticFrameFloorFraction.Name"), 0.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.kineticFrameFloorFraction.Desc"));
    b.Slider("isometricMinPercent", this.Loc("FAC.isometricMinPercent.Name"), 5.0, 30.0, 1.0, true);
    b.Tip(this.Loc("FAC.isometricMinPercent.Desc"));
    b.Slider("isometricMaxPercent", this.Loc("FAC.isometricMaxPercent.Name"), 5.0, 30.0, 1.0, true);
    b.Tip(this.Loc("FAC.isometricMaxPercent.Desc"));
    b.Slider("ubMinPercent", this.Loc("FAC.ubMinPercent.Name"), 5.0, 40.0, 1.0, true);
    b.Tip(this.Loc("FAC.ubMinPercent.Desc"));
    b.Slider("ubMaxPercent", this.Loc("FAC.ubMaxPercent.Name"), 5.0, 40.0, 1.0, true);
    b.Tip(this.Loc("FAC.ubMaxPercent.Desc"));
    b.Slider("berserkStaminaReductionPercent", this.Loc("FAC.berserkStaminaReductionPercent.Name"), 0.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.berserkStaminaReductionPercent.Desc"));
    b.Slider("apogeeKillRestorePercent", this.Loc("FAC.apogeeKillRestorePercent.Name"), 0.0, 50.0, 1.0, true);
    b.Tip(this.Loc("FAC.apogeeKillRestorePercent.Desc"));
    b.Section(this.Loc("FAC.sec.Combat_WeaponHandling"));
    b.Toggle("disableRecoilRecovery", this.Loc("FAC.disableRecoilRecovery.Name"));
    b.Tip(this.Loc("FAC.disableRecoilRecovery.Desc"));
    b.Slider("swayThresholdPercent", this.Loc("FAC.swayThresholdPercent.Name"), 1.0, 25.0, 1.0, true);
    b.Tip(this.Loc("FAC.swayThresholdPercent.Desc"));
    b.Slider("weaponPenaltySeverity", this.Loc("FAC.weaponPenaltySeverity.Name"), 0.5, 20.0, 0.5, false);
    b.Tip(this.Loc("FAC.weaponPenaltySeverity.Desc"));
    b.Slider("meleeThresholdPercent", this.Loc("FAC.meleeThresholdPercent.Name"), 1.0, 25.0, 1.0, true);
    b.Tip(this.Loc("FAC.meleeThresholdPercent.Desc"));
    b.Slider("meleeDamageMinPercent", this.Loc("FAC.meleeDamageMinPercent.Name"), 0.0, 50.0, 1.0, true);
    b.Tip(this.Loc("FAC.meleeDamageMinPercent.Desc"));
    b.Tab(this.Loc("FAC.tab.Perks"));
    b.Section(this.Loc("FAC.sec.Perks_CostReductions"));
    b.Group(this.Loc("FAC.grp.perkDashReductionPercent"));   
    b.Slider("perkDashReductionPercent", this.Loc("FAC.perkDashReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkDashReductionPercent.Desc"));
    b.Slider("perkAirDashReductionPercent", this.Loc("FAC.perkAirDashReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkAirDashReductionPercent.Desc"));
    b.Slider("perkLeadStealReductionPercent", this.Loc("FAC.perkLeadStealReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkLeadStealReductionPercent.Desc"));
    b.Slider("perkBladerunnerReductionPercent", this.Loc("FAC.perkBladerunnerReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkBladerunnerReductionPercent.Desc"));
    b.Slider("perkWreckingBallReductionPercent", this.Loc("FAC.perkWreckingBallReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkWreckingBallReductionPercent.Desc"));
    b.Slider("perkQuakeReductionPercent", this.Loc("FAC.perkQuakeReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkQuakeReductionPercent.Desc"));
    b.Slider("perkDeadEyeReductionPercent", this.Loc("FAC.perkDeadEyeReductionPercent.Name"), 0.0, 50.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkDeadEyeReductionPercent.Desc"));
    b.Slider("perkShinobiReductionPercent", this.Loc("FAC.perkShinobiReductionPercent.Name"), 20.0, 60.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkShinobiReductionPercent.Desc"));
    b.Section(this.Loc("FAC.sec.Perks_Restores"));
    b.Group(this.Loc("FAC.grp.perkMeanStreakRestore"));   
    b.Slider("perkMeanStreakRestore", this.Loc("FAC.perkMeanStreakRestore.Name"), 0.0, 1000.0, 25.0, true);
    b.Tip(this.Loc("FAC.perkMeanStreakRestore.Desc"));
    b.Slider("perkCreepingDeathRestore", this.Loc("FAC.perkCreepingDeathRestore.Name"), 0.0, 1000.0, 25.0, true);
    b.Tip(this.Loc("FAC.perkCreepingDeathRestore.Desc"));
    b.Slider("perkSharpshooterRegenPercent", this.Loc("FAC.perkSharpshooterRegenPercent.Name"), 0.0, 15.0, 1.0, true);
    b.Tip(this.Loc("FAC.perkSharpshooterRegenPercent.Desc"));
    b.Slider("perkCaliforniaReaperRestore", this.Loc("FAC.perkCaliforniaReaperRestore.Name"), 0.0, 1000.0, 25.0, true);
    b.Tip(this.Loc("FAC.perkCaliforniaReaperRestore.Desc"));
    b.Slider("perkAftershockRestore", this.Loc("FAC.perkAftershockRestore.Name"), 0.0, 300.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkAftershockRestore.Desc"));
    b.Slider("perkSlaughterhouseRestore", this.Loc("FAC.perkSlaughterhouseRestore.Name"), 0.0, 300.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkSlaughterhouseRestore.Desc"));
    b.Slider("perkKineticAbsorptionRestore", this.Loc("FAC.perkKineticAbsorptionRestore.Name"), 25.0, 75.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkKineticAbsorptionRestore.Desc"));
    b.Slider("perkTailWindRestore", this.Loc("FAC.perkTailWindRestore.Name"), 0.0, 300.0, 5.0, true);
    b.Tip(this.Loc("FAC.perkTailWindRestore.Desc"));
    b.Section(this.Loc("FAC.sec.Perks_ModeTuning"));
    b.Slider("deadEyeFullStaminaPercent", this.Loc("FAC.deadEyeFullStaminaPercent.Name"), 70.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.deadEyeFullStaminaPercent.Desc"));
    b.Slider("focusCooldownMinSeconds", this.Loc("FAC.focusCooldownMinSeconds.Name"), 0.0, 30.0, 1.0, true);
    b.Tip(this.Loc("FAC.focusCooldownMinSeconds.Desc"));
    b.Slider("focusCooldownMaxSeconds", this.Loc("FAC.focusCooldownMaxSeconds.Name"), 10.0, 120.0, 5.0, true);
    b.Tip(this.Loc("FAC.focusCooldownMaxSeconds.Desc"));
    b.Slider("dontStopThresholdPercent", this.Loc("FAC.dontStopThresholdPercent.Name"), 10.0, 50.0, 1.0, true);
    b.Tip(this.Loc("FAC.dontStopThresholdPercent.Desc"));
    b.Tab(this.Loc("FAC.tab.Rest"));
    b.Section(this.Loc("FAC.sec.Rest_Fatigue"));
    b.Slider("fatigueMultiplierCap", this.Loc("FAC.fatigueMultiplierCap.Name"), 1.0, 10.0, 0.5, false);
    b.Tip(this.Loc("FAC.fatigueMultiplierCap.Desc"));
    b.Toggle("pauseFatigueInWorkspot", this.Loc("FAC.pauseFatigueInWorkspot.Name"));
    b.Tip(this.Loc("FAC.pauseFatigueInWorkspot.Desc"));
    b.Section(this.Loc("FAC.sec.Rest_Sleep"));
    b.Slider("minSleepHoursForFullReset", this.Loc("FAC.minSleepHoursForFullReset.Name"), 3.0, 12.0, 1.0, true);
    b.Tip(this.Loc("FAC.minSleepHoursForFullReset.Desc"));
    b.Slider("timeSkipThresholdMinutes", this.Loc("FAC.timeSkipThresholdMinutes.Name"), 5.0, 120.0, 5.0, true);
    b.Tip(this.Loc("FAC.timeSkipThresholdMinutes.Desc"));
    b.Toggle("enableCarSleep", this.Loc("FAC.enableCarSleep.Name"));
    b.Tip(this.Loc("FAC.enableCarSleep.Desc"));
    b.Toggle("carSleepOwnedOnly", this.Loc("FAC.carSleepOwnedOnly.Name"));
    b.Tip(this.Loc("FAC.carSleepOwnedOnly.Desc"));
    b.Slider("carSleepEfficiency", this.Loc("FAC.carSleepEfficiency.Name"), 10.0, 100.0, 5.0, true);
    b.Tip(this.Loc("FAC.carSleepEfficiency.Desc"));
    b.Toggle("showBarsOnTimeskip", this.Loc("FAC.showBarsOnTimeskip.Name"));
    b.Tip(this.Loc("FAC.showBarsOnTimeskip.Desc"));
    b.Tab(this.Loc("FAC.tab.HUD"));
    b.Section(this.Loc("FAC.sec.HUD_InventoryDisplay"));
    b.Toggle("showBarOnConsumables", this.Loc("FAC.showBarOnConsumables.Name"));
    b.Tip(this.Loc("FAC.showBarOnConsumables.Desc"));
    b.Toggle("showBarOnFood", this.Loc("FAC.showBarOnFood.Name"));
    b.Tip(this.Loc("FAC.showBarOnFood.Desc"));
    b.Toggle("showBarOnAllItems", this.Loc("FAC.showBarOnAllItems.Name"));
    b.Tip(this.Loc("FAC.showBarOnAllItems.Desc"));
    b.Toggle("showBarOnWeaponWheel", this.Loc("FAC.showBarOnWeaponWheel.Name"));
    b.Tip(this.Loc("FAC.showBarOnWeaponWheel.Desc"));
    b.Slider("barOffsetX", this.Loc("FAC.barOffsetX.Name"), -2500.0, 2500.0, 10.0, false);
    b.Tip(this.Loc("FAC.barOffsetX.Desc"));
    b.Slider("barOffsetY", this.Loc("FAC.barOffsetY.Name"), 50.0, 2500.0, 10.0, false);
    b.Tip(this.Loc("FAC.barOffsetY.Desc"));
    b.Slider("wheelBarOffsetX", this.Loc("FAC.wheelBarOffsetX.Name"), -2500.0, 2500.0, 10.0, false);
    b.Tip(this.Loc("FAC.wheelBarOffsetX.Desc"));
    b.Slider("wheelBarOffsetY", this.Loc("FAC.wheelBarOffsetY.Name"), 50.0, 2500.0, 10.0, false);
    b.Tip(this.Loc("FAC.wheelBarOffsetY.Desc"));
    b.Section(this.Loc("FAC.sec.HUD_StaminaBar"));
    b.Slider("staminaDrainColorThreshold", this.Loc("FAC.staminaDrainColorThreshold.Name"), 0.0, 20.0, 0.1, false);
    b.Tip(this.Loc("FAC.staminaDrainColorThreshold.Desc"));
    b.Section(this.Loc("FAC.sec.HUD_VisionEffects"));
    b.Slider("breathingThresholdPercent", this.Loc("FAC.breathingThresholdPercent.Name"), 1.0, 25.0, 1.0, true);
    b.Tip(this.Loc("FAC.breathingThresholdPercent.Desc"));
    b.Slider("breathingMaxAmplitude", this.Loc("FAC.breathingMaxAmplitude.Name"), 0.5, 20.0, 0.5, false);
    b.Tip(this.Loc("FAC.breathingMaxAmplitude.Desc"));
    b.Toggle("tfpBreathingEnabled", this.Loc("FAC.tfpBreathingEnabled.Name"));
    b.Tip(this.Loc("FAC.tfpBreathingEnabled.Desc"));
    b.Slider("tfpBreathingMaxIntensity", this.Loc("FAC.tfpBreathingMaxIntensity.Name"), 0.0, 2.0, 0.1, false);
    b.Tip(this.Loc("FAC.tfpBreathingMaxIntensity.Desc"));
    b.Toggle("visionBlurEnabled", this.Loc("FAC.visionBlurEnabled.Name"));
    b.Tip(this.Loc("FAC.visionBlurEnabled.Desc"));
    b.Slider("tunnelVisionThresholdPercent", this.Loc("FAC.tunnelVisionThresholdPercent.Name"), 5.0, 40.0, 1.0, true);
    b.Tip(this.Loc("FAC.tunnelVisionThresholdPercent.Desc"));
    b.Slider("visionFlashThresholdPercent", this.Loc("FAC.visionFlashThresholdPercent.Name"), 1.0, 20.0, 1.0, true);
    b.Tip(this.Loc("FAC.visionFlashThresholdPercent.Desc"));
    return b.Build();
  }

  public func GetBool(key: String) -> Bool {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return false; }
    if Equals(key, "modON") { return c.modON; }
    if Equals(key, "disableCombatHealthRegen") { return c.disableCombatHealthRegen; }
    if Equals(key, "disableRecoilRecovery") { return c.disableRecoilRecovery; }
    if Equals(key, "tfpBreathingEnabled") { return c.tfpBreathingEnabled; }
    if Equals(key, "pauseFatigueInWorkspot") { return c.pauseFatigueInWorkspot; }
    if Equals(key, "enableCarSleep") { return c.enableCarSleep; }
    if Equals(key, "carSleepOwnedOnly") { return c.carSleepOwnedOnly; }
    if Equals(key, "showBarsOnTimeskip") { return c.showBarsOnTimeskip; }
    if Equals(key, "showBarOnConsumables") { return c.showBarOnConsumables; }
    if Equals(key, "showBarOnFood") { return c.showBarOnFood; }
    if Equals(key, "showBarOnAllItems") { return c.showBarOnAllItems; }
    if Equals(key, "showBarOnWeaponWheel") { return c.showBarOnWeaponWheel; }
    if Equals(key, "visionBlurEnabled") { return c.visionBlurEnabled; }
    if Equals(key, "debugON") { return c.debugON; }
    return false;
  }

  public func SetBool(key: String, value: Bool) -> Void {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return; }
    if Equals(key, "modON") { c.modON = value; return; }
    if Equals(key, "disableCombatHealthRegen") { c.disableCombatHealthRegen = value; return; }
    if Equals(key, "disableRecoilRecovery") { c.disableRecoilRecovery = value; return; }
    if Equals(key, "tfpBreathingEnabled") { c.tfpBreathingEnabled = value; return; }
    if Equals(key, "pauseFatigueInWorkspot") { c.pauseFatigueInWorkspot = value; return; }
    if Equals(key, "enableCarSleep") { c.enableCarSleep = value; return; }
    if Equals(key, "carSleepOwnedOnly") { c.carSleepOwnedOnly = value; return; }
    if Equals(key, "showBarsOnTimeskip") { c.showBarsOnTimeskip = value; return; }
    if Equals(key, "showBarOnConsumables") { c.showBarOnConsumables = value; return; }
    if Equals(key, "showBarOnFood") { c.showBarOnFood = value; return; }
    if Equals(key, "showBarOnAllItems") { c.showBarOnAllItems = value; return; }
    if Equals(key, "showBarOnWeaponWheel") { c.showBarOnWeaponWheel = value; return; }
    if Equals(key, "visionBlurEnabled") { c.visionBlurEnabled = value; return; }
    if Equals(key, "debugON") { c.debugON = value; return; }
  }

  public func GetFloat(key: String) -> Float {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return 0.0; }
    if Equals(key, "baseStamina") { return c.baseStamina; }
    if Equals(key, "bodyStaminaBonus") { return c.bodyStaminaBonus; }
    if Equals(key, "baseEnergy") { return c.baseEnergy; }
    if Equals(key, "bodyEnergyBonus") { return c.bodyEnergyBonus; }
    if Equals(key, "reflexCooldownReduction") { return c.reflexCooldownReduction; }
    if Equals(key, "reflexCostReduction") { return c.reflexCostReduction; }
    if Equals(key, "jogDrainRate") { return c.jogDrainRate; }
    if Equals(key, "combatDrainRate") { return c.combatDrainRate; }
    if Equals(key, "sprintDrainRate") { return c.sprintDrainRate; }
    if Equals(key, "crouchMoveDrainRate") { return c.crouchMoveDrainRate; }
    if Equals(key, "jumpCost") { return c.jumpCost; }
    if Equals(key, "dodgeCost") { return c.dodgeCost; }
    if Equals(key, "slideCost") { return c.slideCost; }
    if Equals(key, "meleeCost") { return c.meleeCost; }
    if Equals(key, "staminaRegenRate") { return c.staminaRegenRate; }
    if Equals(key, "energyCostPerStamina") { return c.energyCostPerStamina; }
    if Equals(key, "weaponPenaltySeverity") { return c.weaponPenaltySeverity; }
    if Equals(key, "breathingMaxAmplitude") { return c.breathingMaxAmplitude; }
    if Equals(key, "tfpBreathingMaxIntensity") { return c.tfpBreathingMaxIntensity; }
    if Equals(key, "fatigueMultiplierCap") { return c.fatigueMultiplierCap; }
    if Equals(key, "barOffsetX") { return c.barOffsetX; }
    if Equals(key, "barOffsetY") { return c.barOffsetY; }
    if Equals(key, "wheelBarOffsetX") { return c.wheelBarOffsetX; }
    if Equals(key, "wheelBarOffsetY") { return c.wheelBarOffsetY; }
    if Equals(key, "staminaDrainColorThreshold") { return c.staminaDrainColorThreshold; }
    return 0.0;
  }

  public func SetFloat(key: String, value: Float) -> Void {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return; }
    if Equals(key, "baseStamina") { c.baseStamina = value; return; }
    if Equals(key, "bodyStaminaBonus") { c.bodyStaminaBonus = value; return; }
    if Equals(key, "baseEnergy") { c.baseEnergy = value; return; }
    if Equals(key, "bodyEnergyBonus") { c.bodyEnergyBonus = value; return; }
    if Equals(key, "reflexCooldownReduction") { c.reflexCooldownReduction = value; return; }
    if Equals(key, "reflexCostReduction") { c.reflexCostReduction = value; return; }
    if Equals(key, "jogDrainRate") { c.jogDrainRate = value; return; }
    if Equals(key, "combatDrainRate") { c.combatDrainRate = value; return; }
    if Equals(key, "sprintDrainRate") { c.sprintDrainRate = value; return; }
    if Equals(key, "crouchMoveDrainRate") { c.crouchMoveDrainRate = value; return; }
    if Equals(key, "jumpCost") { c.jumpCost = value; return; }
    if Equals(key, "dodgeCost") { c.dodgeCost = value; return; }
    if Equals(key, "slideCost") { c.slideCost = value; return; }
    if Equals(key, "meleeCost") { c.meleeCost = value; return; }
    if Equals(key, "staminaRegenRate") { c.staminaRegenRate = value; return; }
    if Equals(key, "energyCostPerStamina") { c.energyCostPerStamina = value; return; }
    if Equals(key, "weaponPenaltySeverity") { c.weaponPenaltySeverity = value; return; }
    if Equals(key, "breathingMaxAmplitude") { c.breathingMaxAmplitude = value; return; }
    if Equals(key, "tfpBreathingMaxIntensity") { c.tfpBreathingMaxIntensity = value; return; }
    if Equals(key, "fatigueMultiplierCap") { c.fatigueMultiplierCap = value; return; }
    if Equals(key, "barOffsetX") { c.barOffsetX = value; return; }
    if Equals(key, "barOffsetY") { c.barOffsetY = value; return; }
    if Equals(key, "wheelBarOffsetX") { c.wheelBarOffsetX = value; return; }
    if Equals(key, "wheelBarOffsetY") { c.wheelBarOffsetY = value; return; }
    if Equals(key, "staminaDrainColorThreshold") { c.staminaDrainColorThreshold = value; return; }
  }

  public func GetInt(key: String) -> Int32 {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return 0; }
    if Equals(key, "regenDelayCooldownMinutes") { return c.regenDelayCooldownMinutes; }
    if Equals(key, "mealEnergyRestorePercent") { return c.mealEnergyRestorePercent; }
    if Equals(key, "mealDrinkBonusPercent") { return c.mealDrinkBonusPercent; }
    if Equals(key, "maxMealsPerDay") { return c.maxMealsPerDay; }
    if Equals(key, "mealDrinkWindowMinutes") { return c.mealDrinkWindowMinutes; }
    if Equals(key, "snackStaminaRestorePercent") { return c.snackStaminaRestorePercent; }
    if Equals(key, "maxSnacksPerDay") { return c.maxSnacksPerDay; }
    if Equals(key, "maxDrinksPerDay") { return c.maxDrinksPerDay; }
    if Equals(key, "drinkStaminaRefreshPercent") { return c.drinkStaminaRefreshPercent; }
    if Equals(key, "drinkEnergyRefreshPercent") { return c.drinkEnergyRefreshPercent; }
    if Equals(key, "mrWhiteyStaminaPercent") { return c.mrWhiteyStaminaPercent; }
    if Equals(key, "mrWhiteyEnergyDrainPercent") { return c.mrWhiteyEnergyDrainPercent; }
    if Equals(key, "alcoholExtraSleepHoursPerDrink") { return c.alcoholExtraSleepHoursPerDrink; }
    if Equals(key, "alcoholMaxExtraSleepHours") { return c.alcoholMaxExtraSleepHours; }
    if Equals(key, "alcoholSoberBaseHours") { return c.alcoholSoberBaseHours; }
    if Equals(key, "alcoholSoberHoursPerExtraDrink") { return c.alcoholSoberHoursPerExtraDrink; }
    if Equals(key, "smokingCooldownReductionPercent") { return c.smokingCooldownReductionPercent; }
    if Equals(key, "smokingRegenPenaltyPercent") { return c.smokingRegenPenaltyPercent; }
    if Equals(key, "smokingPenaltyDurationMinutes") { return c.smokingPenaltyDurationMinutes; }
    if Equals(key, "energyReductionPerImplant") { return c.energyReductionPerImplant; }
    if Equals(key, "maxCywareEnergyReduction") { return c.maxCywareEnergyReduction; }
    if Equals(key, "synLungsMaxStaminaBonusPercent") { return c.synLungsMaxStaminaBonusPercent; }
    if Equals(key, "synLungsRegenBonusPercent") { return c.synLungsRegenBonusPercent; }
    if Equals(key, "synLungsDelayReductionPercent") { return c.synLungsDelayReductionPercent; }
    if Equals(key, "synLungsSmokingReductionPercent") { return c.synLungsSmokingReductionPercent; }
    if Equals(key, "adrenalineMeleeRestorePercent") { return c.adrenalineMeleeRestorePercent; }
    if Equals(key, "denseMarrowMeleeCostPercent") { return c.denseMarrowMeleeCostPercent; }
    if Equals(key, "kineticFramePlateauPercent") { return c.kineticFramePlateauPercent; }
    if Equals(key, "kineticFrameFloorFraction") { return c.kineticFrameFloorFraction; }
    if Equals(key, "isometricMinPercent") { return c.isometricMinPercent; }
    if Equals(key, "isometricMaxPercent") { return c.isometricMaxPercent; }
    if Equals(key, "ubMinPercent") { return c.ubMinPercent; }
    if Equals(key, "ubMaxPercent") { return c.ubMaxPercent; }
    if Equals(key, "berserkStaminaReductionPercent") { return c.berserkStaminaReductionPercent; }
    if Equals(key, "apogeeKillRestorePercent") { return c.apogeeKillRestorePercent; }
    if Equals(key, "perkDashReductionPercent") { return c.perkDashReductionPercent; }
    if Equals(key, "perkAirDashReductionPercent") { return c.perkAirDashReductionPercent; }
    if Equals(key, "perkLeadStealReductionPercent") { return c.perkLeadStealReductionPercent; }
    if Equals(key, "perkBladerunnerReductionPercent") { return c.perkBladerunnerReductionPercent; }
    if Equals(key, "perkWreckingBallReductionPercent") { return c.perkWreckingBallReductionPercent; }
    if Equals(key, "perkQuakeReductionPercent") { return c.perkQuakeReductionPercent; }
    if Equals(key, "perkDeadEyeReductionPercent") { return c.perkDeadEyeReductionPercent; }
    if Equals(key, "perkShinobiReductionPercent") { return c.perkShinobiReductionPercent; }
    if Equals(key, "perkMeanStreakRestore") { return c.perkMeanStreakRestore; }
    if Equals(key, "perkCreepingDeathRestore") { return c.perkCreepingDeathRestore; }
    if Equals(key, "perkSharpshooterRegenPercent") { return c.perkSharpshooterRegenPercent; }
    if Equals(key, "perkCaliforniaReaperRestore") { return c.perkCaliforniaReaperRestore; }
    if Equals(key, "perkAftershockRestore") { return c.perkAftershockRestore; }
    if Equals(key, "perkSlaughterhouseRestore") { return c.perkSlaughterhouseRestore; }
    if Equals(key, "perkKineticAbsorptionRestore") { return c.perkKineticAbsorptionRestore; }
    if Equals(key, "perkTailWindRestore") { return c.perkTailWindRestore; }
    if Equals(key, "deadEyeFullStaminaPercent") { return c.deadEyeFullStaminaPercent; }
    if Equals(key, "focusCooldownMinSeconds") { return c.focusCooldownMinSeconds; }
    if Equals(key, "focusCooldownMaxSeconds") { return c.focusCooldownMaxSeconds; }
    if Equals(key, "dontStopThresholdPercent") { return c.dontStopThresholdPercent; }
    if Equals(key, "swayThresholdPercent") { return c.swayThresholdPercent; }
    if Equals(key, "breathingThresholdPercent") { return c.breathingThresholdPercent; }
    if Equals(key, "meleeThresholdPercent") { return c.meleeThresholdPercent; }
    if Equals(key, "meleeDamageMinPercent") { return c.meleeDamageMinPercent; }
    if Equals(key, "minSleepHoursForFullReset") { return c.minSleepHoursForFullReset; }
    if Equals(key, "timeSkipThresholdMinutes") { return c.timeSkipThresholdMinutes; }
    if Equals(key, "carSleepEfficiency") { return c.carSleepEfficiency; }
    if Equals(key, "tunnelVisionThresholdPercent") { return c.tunnelVisionThresholdPercent; }
    if Equals(key, "visionFlashThresholdPercent") { return c.visionFlashThresholdPercent; }
    return 0;
  }

  public func SetInt(key: String, value: Int32) -> Void {
    let c: wref<FACConfig> = this.m_cfg;
    if !IsDefined(c) { return; }
    if Equals(key, "regenDelayCooldownMinutes") { c.regenDelayCooldownMinutes = value; return; }
    if Equals(key, "mealEnergyRestorePercent") { c.mealEnergyRestorePercent = value; return; }
    if Equals(key, "mealDrinkBonusPercent") { c.mealDrinkBonusPercent = value; return; }
    if Equals(key, "maxMealsPerDay") { c.maxMealsPerDay = value; return; }
    if Equals(key, "mealDrinkWindowMinutes") { c.mealDrinkWindowMinutes = value; return; }
    if Equals(key, "snackStaminaRestorePercent") { c.snackStaminaRestorePercent = value; return; }
    if Equals(key, "maxSnacksPerDay") { c.maxSnacksPerDay = value; return; }
    if Equals(key, "maxDrinksPerDay") { c.maxDrinksPerDay = value; return; }
    if Equals(key, "drinkStaminaRefreshPercent") { c.drinkStaminaRefreshPercent = value; return; }
    if Equals(key, "drinkEnergyRefreshPercent") { c.drinkEnergyRefreshPercent = value; return; }
    if Equals(key, "mrWhiteyStaminaPercent") { c.mrWhiteyStaminaPercent = value; return; }
    if Equals(key, "mrWhiteyEnergyDrainPercent") { c.mrWhiteyEnergyDrainPercent = value; return; }
    if Equals(key, "alcoholExtraSleepHoursPerDrink") { c.alcoholExtraSleepHoursPerDrink = value; return; }
    if Equals(key, "alcoholMaxExtraSleepHours") { c.alcoholMaxExtraSleepHours = value; return; }
    if Equals(key, "alcoholSoberBaseHours") { c.alcoholSoberBaseHours = value; return; }
    if Equals(key, "alcoholSoberHoursPerExtraDrink") { c.alcoholSoberHoursPerExtraDrink = value; return; }
    if Equals(key, "smokingCooldownReductionPercent") { c.smokingCooldownReductionPercent = value; return; }
    if Equals(key, "smokingRegenPenaltyPercent") { c.smokingRegenPenaltyPercent = value; return; }
    if Equals(key, "smokingPenaltyDurationMinutes") { c.smokingPenaltyDurationMinutes = value; return; }
    if Equals(key, "energyReductionPerImplant") { c.energyReductionPerImplant = value; return; }
    if Equals(key, "maxCywareEnergyReduction") { c.maxCywareEnergyReduction = value; return; }
    if Equals(key, "synLungsMaxStaminaBonusPercent") { c.synLungsMaxStaminaBonusPercent = value; return; }
    if Equals(key, "synLungsRegenBonusPercent") { c.synLungsRegenBonusPercent = value; return; }
    if Equals(key, "synLungsDelayReductionPercent") { c.synLungsDelayReductionPercent = value; return; }
    if Equals(key, "synLungsSmokingReductionPercent") { c.synLungsSmokingReductionPercent = value; return; }
    if Equals(key, "adrenalineMeleeRestorePercent") { c.adrenalineMeleeRestorePercent = value; return; }
    if Equals(key, "denseMarrowMeleeCostPercent") { c.denseMarrowMeleeCostPercent = value; return; }
    if Equals(key, "kineticFramePlateauPercent") { c.kineticFramePlateauPercent = value; return; }
    if Equals(key, "kineticFrameFloorFraction") { c.kineticFrameFloorFraction = value; return; }
    if Equals(key, "isometricMinPercent") { c.isometricMinPercent = value; return; }
    if Equals(key, "isometricMaxPercent") { c.isometricMaxPercent = value; return; }
    if Equals(key, "ubMinPercent") { c.ubMinPercent = value; return; }
    if Equals(key, "ubMaxPercent") { c.ubMaxPercent = value; return; }
    if Equals(key, "berserkStaminaReductionPercent") { c.berserkStaminaReductionPercent = value; return; }
    if Equals(key, "apogeeKillRestorePercent") { c.apogeeKillRestorePercent = value; return; }
    if Equals(key, "perkDashReductionPercent") { c.perkDashReductionPercent = value; return; }
    if Equals(key, "perkAirDashReductionPercent") { c.perkAirDashReductionPercent = value; return; }
    if Equals(key, "perkLeadStealReductionPercent") { c.perkLeadStealReductionPercent = value; return; }
    if Equals(key, "perkBladerunnerReductionPercent") { c.perkBladerunnerReductionPercent = value; return; }
    if Equals(key, "perkWreckingBallReductionPercent") { c.perkWreckingBallReductionPercent = value; return; }
    if Equals(key, "perkQuakeReductionPercent") { c.perkQuakeReductionPercent = value; return; }
    if Equals(key, "perkDeadEyeReductionPercent") { c.perkDeadEyeReductionPercent = value; return; }
    if Equals(key, "perkShinobiReductionPercent") { c.perkShinobiReductionPercent = value; return; }
    if Equals(key, "perkMeanStreakRestore") { c.perkMeanStreakRestore = value; return; }
    if Equals(key, "perkCreepingDeathRestore") { c.perkCreepingDeathRestore = value; return; }
    if Equals(key, "perkSharpshooterRegenPercent") { c.perkSharpshooterRegenPercent = value; return; }
    if Equals(key, "perkCaliforniaReaperRestore") { c.perkCaliforniaReaperRestore = value; return; }
    if Equals(key, "perkAftershockRestore") { c.perkAftershockRestore = value; return; }
    if Equals(key, "perkSlaughterhouseRestore") { c.perkSlaughterhouseRestore = value; return; }
    if Equals(key, "perkKineticAbsorptionRestore") { c.perkKineticAbsorptionRestore = value; return; }
    if Equals(key, "perkTailWindRestore") { c.perkTailWindRestore = value; return; }
    if Equals(key, "deadEyeFullStaminaPercent") { c.deadEyeFullStaminaPercent = value; return; }
    if Equals(key, "focusCooldownMinSeconds") { c.focusCooldownMinSeconds = value; return; }
    if Equals(key, "focusCooldownMaxSeconds") { c.focusCooldownMaxSeconds = value; return; }
    if Equals(key, "dontStopThresholdPercent") { c.dontStopThresholdPercent = value; return; }
    if Equals(key, "swayThresholdPercent") { c.swayThresholdPercent = value; return; }
    if Equals(key, "breathingThresholdPercent") { c.breathingThresholdPercent = value; return; }
    if Equals(key, "meleeThresholdPercent") { c.meleeThresholdPercent = value; return; }
    if Equals(key, "meleeDamageMinPercent") { c.meleeDamageMinPercent = value; return; }
    if Equals(key, "minSleepHoursForFullReset") { c.minSleepHoursForFullReset = value; return; }
    if Equals(key, "timeSkipThresholdMinutes") { c.timeSkipThresholdMinutes = value; return; }
    if Equals(key, "carSleepEfficiency") { c.carSleepEfficiency = value; return; }
    if Equals(key, "tunnelVisionThresholdPercent") { c.tunnelVisionThresholdPercent = value; return; }
    if Equals(key, "visionFlashThresholdPercent") { c.visionFlashThresholdPercent = value; return; }
  }

}
