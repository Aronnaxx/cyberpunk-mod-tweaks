// Adds Street Smarts and Carry Capacity buttons to the EquipmentEx wardrobe screen (left column,
// under the outfit list). Clicks queue the same toggle events the inventory hub buttons use, so the
// hub's own panels open; nothing is duplicated.
// Hooks the vanilla parent inkPuppetPreviewGameController (EquipmentEx's WardrobeScreenController calls
// super.OnInitialize) and checks the runtime class: annotating WardrobeScreenController directly fails to
// resolve when this folder is compiled from r6\scripts (v1.1 broke script compilation that way).
import StreetSense.*
import FACCarryCapacity.*

public static func FACCWB_MakeButton(parent: ref<inkCompoundWidget>, name: CName, label: String, top: Float) -> ref<inkCanvas> {
  let btn: ref<inkCanvas> = new inkCanvas();
  btn.SetName(name);
  btn.SetAnchor(inkEAnchor.TopLeft);
  btn.SetMargin(inkMargin(65.0, top, 0.0, 0.0));
  btn.SetSize(400.0, 50.0);
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
  text.SetAnchor(inkEAnchor.Fill);
  text.SetVAlign(inkEVerticalAlign.Center);
  text.SetMargin(inkMargin(20.0, 0.0, 0.0, 0.0));
  text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  text.SetFontSize(30);
  text.SetLetterCase(textLetterCase.UpperCase);
  text.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  text.BindProperty(n"tintColor", n"MainColors.Blue");
  text.SetText(label);
  text.Reparent(btn);

  btn.Reparent(parent);
  return btn;
}

@addField(inkPuppetPreviewGameController)
private let m_faccwbSS: wref<inkWidget>;

@addField(inkPuppetPreviewGameController)
private let m_faccwbFACC: wref<inkWidget>;

@wrapMethod(inkPuppetPreviewGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  if !this.IsA(n"EquipmentEx.WardrobeScreenController") { return result; };
  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  if !IsDefined(root) { return result; };

  let ssCfg: ref<UNRConfig> = UNRConfig.Get();
  if IsDefined(ssCfg) && ssCfg.modON && ssCfg.showHubMenuButton {
    let b: ref<inkCanvas> = FACCWB_MakeButton(root, n"FACCWBStreetSmarts", SSLoc("SS.UI.streetSmartsBtn"), 590.0);
    b.RegisterToCallback(n"OnRelease", this, n"OnFACCWBStreetSmarts");
    this.m_faccwbSS = b;
  };

  let faccCfg: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();
  if IsDefined(faccCfg) && faccCfg.modON {
    let top: Float = IsDefined(this.m_faccwbSS) ? 650.0 : 590.0;
    let b2: ref<inkCanvas> = FACCWB_MakeButton(root, n"FACCWBCarry", GetLocalizedTextByKey(n"FACC.UI.menuButton"), top);
    b2.RegisterToCallback(n"OnRelease", this, n"OnFACCWBCarry");
    this.m_faccwbFACC = b2;
  };
  return result;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnFACCWBStreetSmarts(e: ref<inkPointerEvent>) -> Bool {
  if e.IsAction(n"click") {
    FACCWBCloseCarry(GetGameInstance());
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(new SSTogglePanelEvent());
  };
  return true;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnFACCWBCarry(e: ref<inkPointerEvent>) -> Bool {
  if e.IsAction(n"click") {
    GameInstance.GetUISystem(GetGameInstance()).QueueEvent(new SSClosePanelEvent());
    FACCWBToggleCarry(GetGameInstance());
  };
  return true;
}
