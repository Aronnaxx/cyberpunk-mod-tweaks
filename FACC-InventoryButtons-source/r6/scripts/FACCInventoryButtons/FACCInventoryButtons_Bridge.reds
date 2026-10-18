module FACCarryCapacity

// FACC-InventoryButtons bridge: lives in FACC's module so it can use FACC's panel builder, system and events.
// FACCIBPopulate is a copy of FACC's MenuHubGameController.FACCRefreshPanel body (private there), with the
// hub's panel fields turned into parameters. Original kept in FACC-InventoryButtons-source/original/.
// Redo the copy if a FACC update changes that panel.

import Codeware.UI.*
import FleshAndChrome.*

public class FACCIBBtnController extends MenuItemController {
  protected cb func OnInitialize() -> Bool {
    super.OnInitialize();
    let data: MenuData;
    data.label = GetLocalizedTextByKey(n"FACC.UI.menuButton");
    data.icon = n"ico_backpack";
    data.fullscreenName = n"inventory_screen";
    data.identifier = EnumInt(HubMenuItems.Inventory);
    data.parentIdentifier = EnumInt(HubMenuItems.None);
    this.Init(data);
  }
}

public static func FACCIBEnabled() -> Bool {
  let config: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();
  return IsDefined(config) && config.modON;
}

public static func FACCIBBuildPanel(parent: ref<inkCompoundWidget>) -> ref<inkCanvas> {
  return FACCInfoPanelBuilder.Build(parent);
}

public static func FACCIBPopulate(panel: ref<inkCanvas>, dataPanel: ref<inkVerticalPanel>) -> Void {
  if !IsDefined(dataPanel) { return; };

  let container = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
  if !IsDefined(container) { return; };
  let sys: ref<FACCarryCapacitySystem> = container.Get(n"FACCarryCapacity.FACCarryCapacitySystem") as FACCarryCapacitySystem;
  if !IsDefined(sys) { return; };

  let config: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();

  let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
  if !IsDefined(player) { return; };

  dataPanel.RemoveAllChildren();

  FACCInfoPanelBuilder.AddSectionHeader(dataPanel, GetLocalizedTextByKey(n"FACC.UI.headerCarryWeight"));

  let weight: Float = sys.GetCachedWeight();
  let gearCap: Float = sys.GetCachedGearCapacity();
  
  let totalCap: Float = sys.GetEffectiveCapacity();
  let weaponSlots: ref<FACCWeaponSlotResult> = sys.GetCachedWeaponSlots();
  
  let holsterSlots: ref<FACCHolsterSlots> = sys.GetEffectiveHolsters();
  let loadTier: Int32 = sys.GetCurrentLoadTier();

  let weightPct: Int32 = 0;
  if totalCap > 0.0 { weightPct = RoundF((weight / totalCap) * 100.0); };
  
  FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeight"),
    ToString(Cast<Int32>(weight)) + " / " + ToString(Cast<Int32>(totalCap)) + " (" + ToString(weightPct) + "%)",
    weightPct >= 90, weightPct >= 75 && weightPct < 90);

  if gearCap > 0.0 {
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowGearBonus"),
      "+" + ToString(RoundF(gearCap)) + GetLocalizedTextByKey(n"FACC.UI.carryCapacitySuffix"), false, false);
  };

  let overload: ref<FACCOverloadResult> = sys.GetCachedOverload();
  if !IsDefined(overload) { overload = new FACCOverloadResult(); };
  if overload.tolerance > 0.0 || overload.holsterBonus > 0 {
    let tolText: String = "+" + ToString(RoundF(overload.tolerance * 100.0)) + "%";
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowOverloadTolerance"), tolText, false, false);
  };

  let statusText: String = GetLocalizedTextByKey(n"FACC.UI.tierLight");
  if loadTier == 1 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierLoaded"); };
  if loadTier == 2 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierHeavy"); };
  if loadTier == 3 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierOverburdened"); };
  FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowStatus"), statusText,
    loadTier >= 3, loadTier == 2);

  if IsDefined(weaponSlots) {
    let bodyPct: Int32 = 0;
    if weaponSlots.bodySlotsMax > 0.0 {
      bodyPct = RoundF((weaponSlots.bodySlotsUsed / weaponSlots.bodySlotsMax) * 100.0);
    };
    FACCInfoPanelBuilder.AddSectionHeader(dataPanel, GetLocalizedTextByKey(n"FACC.UI.headerEquipped"));
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowBodySlots"),
      FACCSlotText(weaponSlots.bodySlotsUsed) + GetLocalizedTextByKey(n"FACC.UI.slotsOf")
        + FACCSlotText(weaponSlots.bodySlotsMax) + GetLocalizedTextByKey(n"FACC.UI.slotsWord"),
      bodyPct > 100, bodyPct == 100);
    FACCAddWeaponRows(dataPanel, weaponSlots, true);

    FACCInfoPanelBuilder.AddSectionHeader(dataPanel, GetLocalizedTextByKey(n"FACC.UI.headerInventory"));
    FACCAddWeaponRows(dataPanel, weaponSlots, false);

    FACCInfoPanelBuilder.AddSectionHeader(dataPanel, GetLocalizedTextByKey(n"FACC.UI.headerWeaponSlots"));
    if weaponSlots.holstersTotal > 0 {
      
      FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowHolsters"),
        FACCHolsterBreakdown(holsterSlots, overload) + " ("
          + ToString(weaponSlots.holstersUsed) + GetLocalizedTextByKey(n"FACC.UI.holstersUsed") + ")",
        false, false);
    };
    if weaponSlots.backpackSlotsMax > 0.0 {
      FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowBackpackSlots"),
        FACCSlotText(weaponSlots.backpackSlotsUsed) + GetLocalizedTextByKey(n"FACC.UI.slotsOf")
          + FACCSlotText(weaponSlots.backpackSlotsMax), false, false);
    };
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowRoomFor"),
      FACCRoomForText(weaponSlots), false, false);
  };

  FACCInfoPanelBuilder.AddSectionHeader(dataPanel, GetLocalizedTextByKey(n"FACC.UI.headerStaminaDrain"));

  let weaponDrain: Float = sys.GetCachedWeaponDrain();
  if weaponDrain > 0.0 {
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeaponDrain"),
      FloatToStringPrec(weaponDrain, 2) + "/s", true, false);
  } else {
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeaponDrain"), GetLocalizedTextByKey(n"FACC.UI.none"), false, false);
  };

  let totalDrain: Float = weaponDrain;
  if totalCap > 0.0 {
    let facConfig: ref<FACConfig> = FACConfig.Get();
    
    let cywareReduction: Float = 0.0;
    let facSystem: ref<FACSystem> = container.Get(n"FleshAndChrome.FACSystem") as FACSystem;
    if IsDefined(facSystem) {
      cywareReduction = facSystem.GetCyberwareReductionFactor();
    } else {
      cywareReduction = FACCyberware.GetEnergyReductionFactor(player, facConfig);
    };
    let threshold: Float = totalCap + (totalCap * cywareReduction * 0.5);
    if weight > threshold {
      let excess: Float = weight - threshold;
      totalDrain += config.overweightDrainPerUnit * excess;
      let facDrainRate: Float = FACActivity.GetDrainRate(player, facConfig);
      if facDrainRate > 0.0 {
        let excessRatio: Float = excess / threshold;
        if excessRatio > 3.0 { excessRatio = 3.0; };
        totalDrain += facDrainRate * excessRatio;
      };
    };
  };
  if totalDrain > 0.0 {
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowTotalDrain"),
      FloatToStringPrec(totalDrain, 2) + GetLocalizedTextByKey(n"FACC.UI.drainSuffix"), totalDrain > 5.0, totalDrain > 2.0);
  } else {
    FACCInfoPanelBuilder.AddDataRow(dataPanel, GetLocalizedTextByKey(n"FACC.UI.rowTotalDrain"), GetLocalizedTextByKey(n"FACC.UI.none"), false, false);
  };

  FACCInfoPanelBuilder.Fit(panel, dataPanel);
}
