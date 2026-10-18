// FACC-InventoryButtons: a Carry Capacity button on the inventory screen next to Street Sense's own Street Smarts
// button, and both buttons on the EquipmentEx wardrobe screen (bottom left). Each button opens its own copy of
// the mod's info panel on that screen, like Street Sense does on the inventory screen.
// Wardrobe hooks wrap EquipmentEx's gameuiInventoryGameController.ShowWardrobeScreen/HideWardrobeScreen (as Street
// Sense's UNR_StatsUI_SubmenuHide.reds does). Annotating EquipmentEx.WardrobeScreenController itself does not
// resolve from r6\scripts (FACC-HubButtonMove v1.1 broke script compilation that way).

import StreetSense.*
import FACCarryCapacity.*

// Positions, in the UI's 4K units.
// Inventory: fixed position of the Carry Capacity button, independent of Street Sense's button setting.
// Default = one button row (~133, measured from Ethan's screenshot) below Street Smarts at Ethan's Street Sense
// setting (X 565 Y 1500, left column under Quick Access). Street Sense's own default (X 2525 Y 1350) is in the
// Related column, where v1.1's Y 1507 landed on top of STATS.
public static func FACCIB_InvX() -> Float = 565.0;
public static func FACCIB_InvY() -> Float = 1635.0;
// Wardrobe: left edge (outfit list column) and gap from the screen bottom to the lower button.
public static func FACCIB_WardLeft() -> Float = 130.0;
public static func FACCIB_WardBottom() -> Float = 170.0;
// Where the info panels open (inventory: same spot as Street Sense's; wardrobe: over the preview).
public static func FACCIB_InvPanelPos() -> inkMargin = inkMargin(800.0, 350.0, 0.0, 0.0);
public static func FACCIB_WardPanelPos() -> inkMargin = inkMargin(1000.0, 350.0, 0.0, 0.0);

public static func FACCIB_MakeButton(parent: ref<inkCompoundWidget>, name: CName, label: String, bottom: Float) -> ref<inkCanvas> {
  let btn: ref<inkCanvas> = new inkCanvas();
  btn.SetName(name);
  btn.SetAnchor(inkEAnchor.BottomLeft);
  btn.SetAnchorPoint(Vector2(0.0, 1.0));
  btn.SetMargin(inkMargin(FACCIB_WardLeft(), 0.0, 0.0, bottom));
  btn.SetSize(800.0, 100.0);
  btn.SetInteractive(true);

  let frame: ref<inkImage> = new inkImage();
  frame.SetName(n"frame");
  frame.SetAnchor(inkEAnchor.Fill);
  frame.SetNineSliceScale(true);
  frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
  frame.SetTexturePart(n"status_cell_fg");
  frame.SetStyle(r"base\\gameplay\\gui\\common\\components\\toggles_style.inkstyle");
  frame.BindProperty(n"tintColor", n"FilterButton.frameColor");
  frame.BindProperty(n"opacity", n"FilterButton.frameOpacity");
  frame.Reparent(btn);

  let text: ref<inkText> = new inkText();
  text.SetName(n"label");
  text.SetAnchor(inkEAnchor.CenterLeft);
  text.SetAnchorPoint(Vector2(0.0, 0.5));
  text.SetMargin(inkMargin(36.0, 0.0, 0.0, 0.0));
  text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  text.SetFontSize(42);
  text.SetLetterCase(textLetterCase.UpperCase);
  text.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  text.BindProperty(n"tintColor", n"MainColors.Blue");
  text.SetText(label);
  text.Reparent(btn);

  btn.Reparent(parent);
  return btn;
}

public static func FACCIB_SSButtonShown() -> Bool {
  let cfg: ref<UNRConfig> = UNRConfig.Get();
  return IsDefined(cfg) && cfg.modON && cfg.showInventoryButton;
}

public static func FACCIB_FillSSPanel(dataPanel: ref<inkVerticalPanel>) -> Void {
  if !IsDefined(dataPanel) { return; };
  let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
  if !IsDefined(player) { return; };
  dataPanel.RemoveAllChildren();
  player.UNR_UpdateClothingState();
  SSPopulateData(dataPanel, player, UNRConfig.Get());
}

// ---------- inventory screen ----------

@addField(gameuiInventoryGameController)
private let m_faccibBtn: wref<inkWidget>;

@addField(gameuiInventoryGameController)
private let m_faccibPanel: wref<inkCanvas>;

@addField(gameuiInventoryGameController)
private let m_faccibData: wref<inkVerticalPanel>;

@addField(gameuiInventoryGameController)
private let m_faccibVisible: Bool;

@wrapMethod(gameuiInventoryGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  if !FACCIBEnabled() { return result; };

  this.m_faccibVisible = false;

  let wrapper: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"default_wrapper") as inkCompoundWidget;
  let btnList: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"default_wrapper/menuLinks/btnsContainer") as inkCompoundWidget;
  if IsDefined(wrapper) && IsDefined(btnList) {
    let btn: ref<inkWidget> = this.SpawnFromLocal(btnList, n"HyperlinkButton:FACCarryCapacity.FACCIBBtnController");
    if IsDefined(btn) {
      btn.Reparent(wrapper);
      btn.SetMargin(inkMargin(FACCIB_InvX(), FACCIB_InvY(), 0.0, 0.0));
      btn.RegisterToCallback(n"OnClick", this, n"OnFACCIBBtnClick");
      this.m_faccibBtn = btn;
    };
  };

  let invRoot: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  if IsDefined(invRoot) {
    let panel: ref<inkCanvas> = FACCIBBuildPanel(invRoot);
    panel.SetMargin(FACCIB_InvPanelPos());
    panel.SetVisible(false);
    this.m_faccibPanel = panel;
    this.m_faccibData = panel.GetWidget(n"DataPanel") as inkVerticalPanel;
  };

  return result;
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.m_faccibBtn) {
    this.m_faccibBtn.UnregisterFromCallback(n"OnClick", this, n"OnFACCIBBtnClick");
  };
  return wrappedMethod();
}

@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBBtnClick(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") {
    this.m_faccibVisible = !this.m_faccibVisible;
    if this.m_faccibVisible {
      // one info panel at a time: close Street Sense's
      this.m_ssInventoryPanelVisible = false;
      if IsDefined(this.m_ssInventoryPanel) { this.m_ssInventoryPanel.SetVisible(false); };
      FACCIBPopulate(this.m_faccibPanel, this.m_faccibData);
    };
    if IsDefined(this.m_faccibPanel) { this.m_faccibPanel.SetVisible(this.m_faccibVisible); };
  };
  return true;
}

// Street Smarts button: close the Carry Capacity panel. A second listener for Street Sense's event (callbacks
// are matched by event type) - wrapping its OnSSBtnToggleEvent fails because StreetSense compiles after this folder.
@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBSSToggle(evt: ref<SSBtnToggleEvent>) -> Bool {
  this.m_faccibVisible = false;
  if IsDefined(this.m_faccibPanel) { this.m_faccibPanel.SetVisible(false); };
  return false;
}

// Hide/restore with the item chooser, like Street Sense's button.
@wrapMethod(gameuiInventoryGameController)
protected cb func OnItemChooserItemChanged(e: ref<ItemChooserItemChanged>) -> Bool {
  this.FACCIBShowInventoryWidgets(false);
  return wrappedMethod(e);
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnBack(userData: ref<IScriptable>) -> Bool {
  this.FACCIBShowInventoryWidgets(true);
  return wrappedMethod(userData);
}

@addMethod(gameuiInventoryGameController)
private func FACCIBShowInventoryWidgets(show: Bool) -> Void {
  if IsDefined(this.m_faccibBtn) { this.m_faccibBtn.SetVisible(show); };
  if IsDefined(this.m_faccibPanel) { this.m_faccibPanel.SetVisible(show && this.m_faccibVisible); };
}

// ---------- EquipmentEx wardrobe screen ----------

@addField(gameuiInventoryGameController)
private let m_faccibWardSSPanel: wref<inkCanvas>;

@addField(gameuiInventoryGameController)
private let m_faccibWardSSData: wref<inkVerticalPanel>;

@addField(gameuiInventoryGameController)
private let m_faccibWardCarryPanel: wref<inkCanvas>;

@addField(gameuiInventoryGameController)
private let m_faccibWardCarryData: wref<inkVerticalPanel>;

@if(ModuleExists("EquipmentEx"))
@wrapMethod(gameuiInventoryGameController)
protected func ShowWardrobeScreen() -> Bool {
  this.FACCIBShowInventoryWidgets(false);
  let shown: Bool = wrappedMethod();
  if shown {
    this.FACCIBAddWardrobeButtons();
  } else {
    this.FACCIBShowInventoryWidgets(true);
  };
  return shown;
}

@if(ModuleExists("EquipmentEx"))
@wrapMethod(gameuiInventoryGameController)
protected func HideWardrobeScreen() -> Bool {
  let hidden: Bool = wrappedMethod();
  if hidden {
    this.FACCIBShowInventoryWidgets(true);
  };
  return hidden;
}

// Buttons and panels are children of the wardrobe widget, so they go away with it.
@addMethod(gameuiInventoryGameController)
private func FACCIBAddWardrobeButtons() -> Void {
  let wardrobe: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wardrobe") as inkCompoundWidget;
  if !IsDefined(wardrobe) { return; };

  let bottom: Float = FACCIB_WardBottom();

  if FACCIBEnabled() {
    let carryBtn: ref<inkCanvas> = FACCIB_MakeButton(wardrobe, n"FACCIBWardCarry", GetLocalizedTextByKey(n"FACC.UI.menuButton"), bottom);
    carryBtn.RegisterToCallback(n"OnRelease", this, n"OnFACCIBWardCarryClick");
    carryBtn.RegisterToCallback(n"OnHoverOver", this, n"OnFACCIBWardHoverOver");
    carryBtn.RegisterToCallback(n"OnHoverOut", this, n"OnFACCIBWardHoverOut");
    let carryPanel: ref<inkCanvas> = FACCIBBuildPanel(wardrobe);
    carryPanel.SetMargin(FACCIB_WardPanelPos());
    carryPanel.SetVisible(false);
    this.m_faccibWardCarryPanel = carryPanel;
    this.m_faccibWardCarryData = carryPanel.GetWidget(n"DataPanel") as inkVerticalPanel;
    bottom += 120.0;
  };

  if FACCIB_SSButtonShown() {
    let ssBtn: ref<inkCanvas> = FACCIB_MakeButton(wardrobe, n"FACCIBWardStreetSmarts", SSLoc("SS.UI.streetSmartsBtn"), bottom);
    ssBtn.RegisterToCallback(n"OnRelease", this, n"OnFACCIBWardSSClick");
    ssBtn.RegisterToCallback(n"OnHoverOver", this, n"OnFACCIBWardHoverOver");
    ssBtn.RegisterToCallback(n"OnHoverOut", this, n"OnFACCIBWardHoverOut");
    let ssPanel: ref<inkCanvas> = SSInfoPanelBuilder.Build(wardrobe);
    ssPanel.SetMargin(FACCIB_WardPanelPos());
    ssPanel.SetVisible(false);
    this.m_faccibWardSSPanel = ssPanel;
    this.m_faccibWardSSData = ssPanel.GetWidget(n"DataPanel") as inkVerticalPanel;
  };
}

@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBWardCarryClick(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") && IsDefined(this.m_faccibWardCarryPanel) {
    let show: Bool = !this.m_faccibWardCarryPanel.IsVisible();
    if IsDefined(this.m_faccibWardSSPanel) { this.m_faccibWardSSPanel.SetVisible(false); };
    if show { FACCIBPopulate(this.m_faccibWardCarryPanel, this.m_faccibWardCarryData); };
    this.m_faccibWardCarryPanel.SetVisible(show);
  };
  return true;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBWardSSClick(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") && IsDefined(this.m_faccibWardSSPanel) {
    let show: Bool = !this.m_faccibWardSSPanel.IsVisible();
    if IsDefined(this.m_faccibWardCarryPanel) { this.m_faccibWardCarryPanel.SetVisible(false); };
    if show { FACCIB_FillSSPanel(this.m_faccibWardSSData); };
    this.m_faccibWardSSPanel.SetVisible(show);
  };
  return true;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBWardHoverOver(evt: ref<inkPointerEvent>) -> Bool {
  evt.GetCurrentTarget().SetState(n"Hover");
  return true;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnFACCIBWardHoverOut(evt: ref<inkPointerEvent>) -> Bool {
  evt.GetCurrentTarget().SetState(n"Default");
  return true;
}
