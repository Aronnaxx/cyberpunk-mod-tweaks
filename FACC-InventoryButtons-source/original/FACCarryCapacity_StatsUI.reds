module FACCarryCapacity

// FACC Stats Panel - hub menu breakdown of what V is hauling ᕕ( ᐛ )ᕗ

import Codeware.UI.*
import FleshAndChrome.*

@addField(MenuHubGameController)
private let m_faccInfoPanel: wref<inkCanvas>;

@addField(MenuHubGameController)
private let m_faccPanelVisible: Bool;

@addField(MenuHubGameController)
private let m_faccDataPanel: wref<inkVerticalPanel>;

@wrapMethod(MenuHubLogicController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  this.FACC_AddMenuButton();
}

@addField(MenuHubLogicController)
private let m_faccMenuButton: wref<inkWidget>;

@addMethod(MenuHubLogicController)
private final func FACC_AddMenuButton() -> Void {
  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  if !IsDefined(root) { return; };

  let panel: ref<inkCompoundWidget> = root.GetWidgetByPathName(n"mainMenu/buttonsContainer/panel_inventory") as inkCompoundWidget;
  if !IsDefined(panel) { return; };

  let config: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();
  if !config.modON { return; };

  let buttonWidget: ref<inkWidget> = this.SpawnFromLocal(panel, n"menu_button");
  if !IsDefined(buttonWidget) { return; };
  buttonWidget.SetMargin(inkMargin(0.0, 510.0, 0.0, 0.0));

  let data: MenuData;
  data.identifier = 43;
  data.parentIdentifier = 3;
  data.label = GetLocalizedTextByKey(n"FACC.UI.menuButton");
  data.icon = n"ico_backpack";

  let controller: ref<MenuItemController> = buttonWidget.GetController() as MenuItemController;
  if IsDefined(controller) {
    controller.Init(data);
  };

  this.m_faccMenuButton = buttonWidget;
}

public class FACCClosePanelEvent extends Event {}

@wrapMethod(MenuItemController)
protected cb func OnMenuChangeRelease(e: ref<inkPointerEvent>) -> Bool {
  if this.m_menuData.identifier == 43 {
    if e.IsAction(n"click") {
      let uiEvt: ref<FACCTogglePanelEvent> = new FACCTogglePanelEvent();
      GameInstance.GetUISystem(GetGameInstance()).QueueEvent(uiEvt);
    };
    return true; 
  };
  
  if e.IsAction(n"click") {
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(new FACCClosePanelEvent());
  };
  return wrappedMethod(e);
}

public class FACCTogglePanelEvent extends Event {}

@wrapMethod(MenuHubGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();

  this.m_faccPanelVisible = false;

  let hubRoot: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  if IsDefined(hubRoot) {
    let panel: ref<inkCanvas> = FACCInfoPanelBuilder.Build(hubRoot);
    this.m_faccInfoPanel = panel;
    this.m_faccDataPanel = panel.GetWidget(n"DataPanel") as inkVerticalPanel;
  };

  return result;
}

@addMethod(MenuHubGameController)
protected cb func OnFACCClosePanelEvent(evt: ref<FACCClosePanelEvent>) -> Bool {
  if this.m_faccPanelVisible && IsDefined(this.m_faccInfoPanel) {
    this.m_faccPanelVisible = false;
    this.m_faccInfoPanel.SetVisible(false);
  };
  return true;
}

@addMethod(MenuHubGameController)
protected cb func OnFACCTogglePanelEvent(evt: ref<FACCTogglePanelEvent>) -> Bool {
  if !IsDefined(this.m_faccInfoPanel) { return false; };

  this.m_faccPanelVisible = !this.m_faccPanelVisible;

  if this.m_faccPanelVisible {
    this.FACCRefreshPanel();
    this.m_faccInfoPanel.SetVisible(true);
  } else {
    this.m_faccInfoPanel.SetVisible(false);
  };
  return true;
}

@addMethod(MenuHubGameController)
private func FACCRefreshPanel() -> Void {
  if !IsDefined(this.m_faccDataPanel) { return; };

  let container = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
  if !IsDefined(container) { return; };
  let sys: ref<FACCarryCapacitySystem> = container.Get(n"FACCarryCapacity.FACCarryCapacitySystem") as FACCarryCapacitySystem;
  if !IsDefined(sys) { return; };

  let config: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();

  let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
  if !IsDefined(player) { return; };

  this.m_faccDataPanel.RemoveAllChildren();

  FACCInfoPanelBuilder.AddSectionHeader(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.headerCarryWeight"));

  let weight: Float = sys.GetCachedWeight();
  let gearCap: Float = sys.GetCachedGearCapacity();
  
  let totalCap: Float = sys.GetEffectiveCapacity();
  let weaponSlots: ref<FACCWeaponSlotResult> = sys.GetCachedWeaponSlots();
  
  let holsterSlots: ref<FACCHolsterSlots> = sys.GetEffectiveHolsters();
  let loadTier: Int32 = sys.GetCurrentLoadTier();

  let weightPct: Int32 = 0;
  if totalCap > 0.0 { weightPct = RoundF((weight / totalCap) * 100.0); };
  
  FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeight"),
    ToString(Cast<Int32>(weight)) + " / " + ToString(Cast<Int32>(totalCap)) + " (" + ToString(weightPct) + "%)",
    weightPct >= 90, weightPct >= 75 && weightPct < 90);

  if gearCap > 0.0 {
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowGearBonus"),
      "+" + ToString(RoundF(gearCap)) + GetLocalizedTextByKey(n"FACC.UI.carryCapacitySuffix"), false, false);
  };

  let overload: ref<FACCOverloadResult> = sys.GetCachedOverload();
  if !IsDefined(overload) { overload = new FACCOverloadResult(); };
  if overload.tolerance > 0.0 || overload.holsterBonus > 0 {
    let tolText: String = "+" + ToString(RoundF(overload.tolerance * 100.0)) + "%";
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowOverloadTolerance"), tolText, false, false);
  };

  let statusText: String = GetLocalizedTextByKey(n"FACC.UI.tierLight");
  if loadTier == 1 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierLoaded"); };
  if loadTier == 2 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierHeavy"); };
  if loadTier == 3 { statusText = GetLocalizedTextByKey(n"FACC.UI.tierOverburdened"); };
  FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowStatus"), statusText,
    loadTier >= 3, loadTier == 2);

  if IsDefined(weaponSlots) {
    let bodyPct: Int32 = 0;
    if weaponSlots.bodySlotsMax > 0.0 {
      bodyPct = RoundF((weaponSlots.bodySlotsUsed / weaponSlots.bodySlotsMax) * 100.0);
    };
    FACCInfoPanelBuilder.AddSectionHeader(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.headerEquipped"));
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowBodySlots"),
      FACCSlotText(weaponSlots.bodySlotsUsed) + GetLocalizedTextByKey(n"FACC.UI.slotsOf")
        + FACCSlotText(weaponSlots.bodySlotsMax) + GetLocalizedTextByKey(n"FACC.UI.slotsWord"),
      bodyPct > 100, bodyPct == 100);
    FACCAddWeaponRows(this.m_faccDataPanel, weaponSlots, true);

    FACCInfoPanelBuilder.AddSectionHeader(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.headerInventory"));
    FACCAddWeaponRows(this.m_faccDataPanel, weaponSlots, false);

    FACCInfoPanelBuilder.AddSectionHeader(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.headerWeaponSlots"));
    if weaponSlots.holstersTotal > 0 {
      
      FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowHolsters"),
        FACCHolsterBreakdown(holsterSlots, overload) + " ("
          + ToString(weaponSlots.holstersUsed) + GetLocalizedTextByKey(n"FACC.UI.holstersUsed") + ")",
        false, false);
    };
    if weaponSlots.backpackSlotsMax > 0.0 {
      FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowBackpackSlots"),
        FACCSlotText(weaponSlots.backpackSlotsUsed) + GetLocalizedTextByKey(n"FACC.UI.slotsOf")
          + FACCSlotText(weaponSlots.backpackSlotsMax), false, false);
    };
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowRoomFor"),
      FACCRoomForText(weaponSlots), false, false);
  };

  FACCInfoPanelBuilder.AddSectionHeader(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.headerStaminaDrain"));

  let weaponDrain: Float = sys.GetCachedWeaponDrain();
  if weaponDrain > 0.0 {
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeaponDrain"),
      FloatToStringPrec(weaponDrain, 2) + "/s", true, false);
  } else {
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowWeaponDrain"), GetLocalizedTextByKey(n"FACC.UI.none"), false, false);
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
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowTotalDrain"),
      FloatToStringPrec(totalDrain, 2) + GetLocalizedTextByKey(n"FACC.UI.drainSuffix"), totalDrain > 5.0, totalDrain > 2.0);
  } else {
    FACCInfoPanelBuilder.AddDataRow(this.m_faccDataPanel, GetLocalizedTextByKey(n"FACC.UI.rowTotalDrain"), GetLocalizedTextByKey(n"FACC.UI.none"), false, false);
  };

  FACCInfoPanelBuilder.Fit(this.m_faccInfoPanel, this.m_faccDataPanel);
}

@wrapMethod(MenuHubGameController)
protected cb func OnUninitialize() -> Bool {
  this.m_faccPanelVisible = false;
  return wrappedMethod();
}

public abstract class FACCInfoPanelBuilder {

  public static func Build(hubRoot: ref<inkCompoundWidget>) -> ref<inkCanvas> {
    let panel: ref<inkCanvas> = new inkCanvas();
    panel.SetName(n"FACCInfoPanel");
    panel.SetSize(new Vector2(700.0, 700.0));
    panel.SetMargin(new inkMargin(1350.0, 350.0, 0.0, 0.0));
    panel.SetVisible(false);
    panel.Reparent(hubRoot);

    let bg: ref<inkImage> = new inkImage();
    bg.SetAnchor(inkEAnchor.TopLeft);
    bg.SetSize(new Vector2(700.0, 700.0));
    bg.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    bg.BindProperty(n"tintColor", n"MainColors.Fullscreen_PrimaryBackgroundDarkest");
    bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\tooltip\\tooltips_new.inkatlas");
    bg.SetTexturePart(n"generic_background");
    bg.SetName(n"Background");
    bg.Reparent(panel);

    let fg: ref<inkImage> = new inkImage();
    fg.SetAnchor(inkEAnchor.TopLeft);
    fg.SetSize(new Vector2(700.0, 700.0));
    fg.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    fg.BindProperty(n"tintColor", n"MainColors.ActiveRed");
    fg.SetAtlasResource(r"base\\gameplay\\gui\\common\\tooltip\\tooltips_new.inkatlas");
    fg.SetTexturePart(n"generic_background_fg");
    fg.SetName(n"Foreground");
    fg.Reparent(panel);

    let title: ref<inkText> = new inkText();
    title.SetAnchor(inkEAnchor.TopLeft);
    title.SetMargin(new inkMargin(30.0, 16.0, 0.0, 0.0));
    title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    title.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    title.BindProperty(n"tintColor", n"MainColors.ActiveRed");
    title.SetLetterCase(textLetterCase.UpperCase);
    title.SetFontSize(42);
    title.SetText(GetLocalizedTextByKey(n"FACC.UI.title"));
    title.Reparent(panel);

    let dataPanel: ref<inkVerticalPanel> = new inkVerticalPanel();
    dataPanel.SetName(n"DataPanel");
    dataPanel.SetMargin(new inkMargin(30.0, 70.0, 0.0, 0.0));
    dataPanel.SetFitToContent(true);
    dataPanel.Reparent(panel);

    return panel;
  }

  public static func Fit(panel: ref<inkCanvas>, dataPanel: ref<inkVerticalPanel>) -> Void {
    if !IsDefined(panel) || !IsDefined(dataPanel) { return; }
    let content: Float = 0.0;
    let i: Int32 = 0;
    while i < dataPanel.GetNumChildren() {
      let child: ref<inkWidget> = dataPanel.GetWidgetByIndex(i);
      if IsDefined(child as inkRectangle) {
        content += 22.0;      
      } else {
        if IsDefined(child as inkText) {
          content += 46.0;    
        } else {
          content += 40.0;    
        };
      };
      i += 1;
    }
    
    let height: Float = MaxF(700.0, content + 110.0);
    if height > 1500.0 { height = 1500.0; }
    let size: Vector2 = new Vector2(700.0, height);
    panel.SetSize(size);
    let bg: ref<inkImage> = panel.GetWidget(n"Background") as inkImage;
    if IsDefined(bg) { bg.SetSize(size); }
    let fg: ref<inkImage> = panel.GetWidget(n"Foreground") as inkImage;
    if IsDefined(fg) { fg.SetSize(size); }
  }

  public static func AddSectionHeader(dataPanel: ref<inkVerticalPanel>, text: String) -> Void {
    let separator: ref<inkRectangle> = new inkRectangle();
    separator.SetSize(new Vector2(640.0, 2.0));
    separator.SetMargin(new inkMargin(0.0, 14.0, 0.0, 6.0));
    separator.SetTintColor(new HDRColor(0.8, 0.2, 0.2, 0.4));
    separator.Reparent(dataPanel);

    let header: ref<inkText> = new inkText();
    header.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    header.SetFontStyle(n"Bold");
    header.SetFontSize(32);
    header.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    header.BindProperty(n"tintColor", n"MainColors.ActiveRed");
    header.SetLetterCase(textLetterCase.UpperCase);
    header.SetText(text);
    header.SetMargin(new inkMargin(0.0, 2.0, 0.0, 6.0));
    header.Reparent(dataPanel);
  }

  public static func AddLabel(parent: ref<inkCompoundWidget>, text: String, width: Float, fontSize: Int32, isHeader: Bool) -> Void {
    let label: ref<inkText> = new inkText();
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    if isHeader {
      label.SetFontStyle(n"Semi-Bold");
    } else {
      label.SetFontStyle(n"Regular");
    };
    label.SetFontSize(fontSize);
    label.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    label.BindProperty(n"tintColor", n"MainColors.ActiveRed");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetText(text);
    label.SetSize(new Vector2(width, 42.0));
    label.SetHAlign(inkEHorizontalAlign.Left);
    label.Reparent(parent);
  }

  public static func AddDataRow(dataPanel: ref<inkVerticalPanel>, label: String, value: String, isCritical: Bool, isWarning: Bool) -> Void {
    let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    row.SetMargin(new inkMargin(0.0, 0.0, 0.0, 4.0));
    row.Reparent(dataPanel);

    let labelContainer: ref<inkCanvas> = new inkCanvas();
    labelContainer.SetSize(new Vector2(300.0, 36.0));
    labelContainer.Reparent(row);

    let labelText: ref<inkText> = new inkText();
    labelText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    labelText.SetFontStyle(n"Semi-Bold");
    labelText.SetFontSize(30);
    labelText.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    labelText.BindProperty(n"tintColor", n"MainColors.ActiveRed");
    labelText.SetLetterCase(textLetterCase.UpperCase);
    labelText.SetText(label);
    labelText.Reparent(labelContainer);

    let valueText: ref<inkText> = new inkText();
    valueText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    valueText.SetFontStyle(n"Regular");
    valueText.SetFontSize(30);
    valueText.SetLetterCase(textLetterCase.UpperCase);
    valueText.SetText(value);
    valueText.SetMargin(new inkMargin(20.0, 0.0, 0.0, 0.0));

    if isCritical {
      valueText.SetTintColor(new HDRColor(1.0, 0.2, 0.2, 1.0));
    } else {
      if isWarning {
        valueText.SetTintColor(new HDRColor(1.0, 0.7, 0.2, 1.0));
      } else {
        valueText.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
        valueText.BindProperty(n"tintColor", n"MainColors.ActiveRed");
      };
    };

    valueText.Reparent(row);
  }
}

public static func FACCSlotText(v: Float) -> String {
  let whole: Int32 = Cast<Int32>(v);
  if AbsF(v - Cast<Float>(whole)) < 0.01 { return ToString(whole); }
  return FloatToStringPrec(v, 1);
}

public static func FACCPlacementText(entry: ref<FACCWeaponEntry>) -> String {
  if Equals(entry.placement, FACCWeaponPlacement.Holstered) { return GetLocalizedTextByKey(n"FACC.UI.placeHolstered"); }
  if Equals(entry.placement, FACCWeaponPlacement.Backpack) { return GetLocalizedTextByKey(n"FACC.UI.placeStowed"); }
  if Equals(entry.placement, FACCWeaponPlacement.Body) { return GetLocalizedTextByKey(n"FACC.UI.placeOnBody"); }
  return GetLocalizedTextByKey(n"FACC.UI.placeLoose");
}

public static func FACCHolsterBreakdown(holsterSlots: ref<FACCHolsterSlots>, overload: ref<FACCOverloadResult>) -> String {
  if !IsDefined(holsterSlots) { return ""; }
  let parts: String = "";
  if holsterSlots.ranged > 0 {
    parts += ToString(holsterSlots.ranged) + " " + GetLocalizedTextByKey(n"FACC.UI.holsterPistol");
  }
  if holsterSlots.rangedLarge > 0 {
    if StrLen(parts) > 0 { parts += ", "; };
    parts += ToString(holsterSlots.rangedLarge) + " " + GetLocalizedTextByKey(n"FACC.UI.holsterLong");
  }
  if holsterSlots.melee > 0 {
    if StrLen(parts) > 0 { parts += ", "; };
    parts += ToString(holsterSlots.melee) + " " + GetLocalizedTextByKey(n"FACC.UI.holsterKnife");
  }
  if holsterSlots.meleeLarge > 0 {
    if StrLen(parts) > 0 { parts += ", "; };
    parts += ToString(holsterSlots.meleeLarge) + " " + GetLocalizedTextByKey(n"FACC.UI.holsterBlade");
  }
  
  if IsDefined(overload) && overload.holsterBonus > 0 {
    parts += " (+" + ToString(overload.holsterBonus) + " " + GetLocalizedTextByKey(n"FACC.UI.holsterImplantSuffix") + ")";
  }
  return parts;
}

public static func FACCCarriesWeight(entry: ref<FACCWeaponEntry>) -> Bool {
  if Equals(entry.placement, FACCWeaponPlacement.Backpack) { return true; }
  return Equals(entry.placement, FACCWeaponPlacement.Body) && !entry.equipped;
}

public static func FACCAddWeaponRows(panel: ref<inkVerticalPanel>, weaponSlots: ref<FACCWeaponSlotResult>, equipped: Bool) -> Void {
  let shown: Int32 = 0;
  let i: Int32 = 0;
  while i < ArraySize(weaponSlots.entries) {
    let entry: ref<FACCWeaponEntry> = weaponSlots.entries[i];
    if Equals(entry.equipped, equipped) {
      let name: String = UIItemsHelper.GetItemName(ItemID.GetTDBID(entry.itemID), null);
      let cost: String = GetLocalizedTextByKey(n"FACC.UI.noDrain");
      if entry.drain > 0.0 {
        cost = "-" + FloatToStringPrec(entry.drain, 1) + GetLocalizedTextByKey(n"FACC.UI.drainSuffix");
      } else {
        
        if FACCCarriesWeight(entry) && entry.weight > 0.0 {
          cost = "+" + FloatToStringPrec(entry.weight, 1) + GetLocalizedTextByKey(n"FACC.UI.weightSuffix");
        };
      };
      FACCInfoPanelBuilder.AddDataRow(panel, "  " + name,
        FACCPlacementText(entry) + "   " + cost,
        entry.drain > 0.0, false);
      shown += 1;
    };
    i += 1;
  }
  if shown == 0 {
    FACCInfoPanelBuilder.AddDataRow(panel, "", GetLocalizedTextByKey(n"FACC.UI.noWeapons"), false, false);
  }
}

public static func FACCRoomForText(weaponSlots: ref<FACCWeaponSlotResult>) -> String {
  let spareHolsters: Int32 = weaponSlots.holstersTotal - weaponSlots.holstersUsed;
  let free: Float = (weaponSlots.backpackSlotsMax - weaponSlots.backpackSlotsUsed)
                  + (weaponSlots.bodySlotsMax - weaponSlots.bodySlotsUsed);
  if spareHolsters > 0 {
    let h: String = ToString(spareHolsters) + " " + GetLocalizedTextByKey(n"FACC.UI.roomHolster");
    if spareHolsters > 1 { h += GetLocalizedTextByKey(n"FACC.UI.pluralSuffix"); };
    if free < FACCSlotSizeSmall() { return h; }
    return h + ", " + FACCBagRoomText(free);
  }
  if free < FACCSlotSizeSmall() { return GetLocalizedTextByKey(n"FACC.UI.roomNothing"); }
  return FACCBagRoomText(free);
}

public static func FACCBagRoomText(free: Float) -> String {
  let large: Int32 = Cast<Int32>(free / FACCSlotSizeLarge());
  let remainder: Float = free - (Cast<Float>(large) * FACCSlotSizeLarge());
  let text: String = "";
  if large > 0 {
    text = ToString(large) + " " + GetLocalizedTextByKey(n"FACC.UI.roomLarge");
    if large > 1 { text += GetLocalizedTextByKey(n"FACC.UI.pluralSuffix"); };
  };
  if remainder >= FACCSlotSizeSmall() - 0.01 {
    if StrLen(text) > 0 { text += ", "; };
    text += "1 " + GetLocalizedTextByKey(n"FACC.UI.roomSmall");
  };
  return text;
}
