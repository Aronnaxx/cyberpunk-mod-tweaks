
public class DPAE_IntegratedAmmoHUD {
  private let m_panel:        ref<inkHorizontalPanel>;
  private let m_icon:         ref<inkImage>;
  private let m_variantLabel: ref<inkText>;
  private let m_detailLabel:  ref<inkText>;

  public static func Create(parent: ref<inkCompoundWidget>, isE3HUD: Bool) -> ref<DPAE_IntegratedAmmoHUD> {
    let hud = new DPAE_IntegratedAmmoHUD();
    hud.Build(parent, isE3HUD);
    return hud;
  }

  private func Build(parent: ref<inkCompoundWidget>, isE3HUD: Bool) -> Void {
    let panel = new inkHorizontalPanel();
    panel.SetName(n"DPAEAmmoHUDInner");
    panel.SetFitToContent(true);

    if isE3HUD {
      panel.SetHAlign(inkEHorizontalAlign.Left);
      panel.SetMargin(new inkMargin(0.0, -24.0, 0.0, 24.0));
    } else {
      panel.SetHAlign(inkEHorizontalAlign.Right);
      panel.SetMargin(new inkMargin(0.0, 4.0, 50.0, 4.0));
    }

    panel.Reparent(parent);
    this.m_panel = panel;

    parent.ReorderChild(panel, 1);

    let icon = new inkImage();
    icon.SetName(n"DPAEVariantIcon");
    icon.SetSize(new Vector2(32.0, 32.0));
    icon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
    icon.SetTexturePart(n"ammo_rifle");
    icon.SetMargin(new inkMargin(0.0, 0.0, 8.0, 0.0));
    icon.Reparent(panel);
    this.m_icon = icon;

    let variantLabel = new inkText();
    variantLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    variantLabel.SetFontSize(32);
    variantLabel.SetStyle(r"base\\gameplay\\gui\\fullscreen\\fullscreen_main_colors.inkstyle");
    variantLabel.SetLetterCase(textLetterCase.UpperCase);
    variantLabel.SetMargin(new inkMargin(0.0, 0.0, 12.0, 0.0));
    variantLabel.BindProperty(n"tintColor", n"MainColors.White");
    variantLabel.SetText("");
    variantLabel.Reparent(panel);
    this.m_variantLabel = variantLabel;

    let detailLabel = new inkText();
    detailLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    detailLabel.SetFontSize(32);
    detailLabel.SetText("");
    detailLabel.Reparent(panel);
    this.m_detailLabel = detailLabel;
  }

  public func Show(caliberLabel: String, variantLabel: String, r: Float, g: Float, b: Float, iconName: CName) -> Void {
    if !IsDefined(this.m_panel) { return; }

    this.m_variantLabel.SetText(caliberLabel);
    this.m_detailLabel.SetText(variantLabel);
    this.m_detailLabel.SetTintColor(new HDRColor(r, g, b, 1.0));

    this.m_icon.SetTexturePart(iconName);
    this.m_icon.SetTintColor(new HDRColor(r, g, b, 1.0));

    this.m_panel.SetVisible(true);
  }

  public func Hide() -> Void {
    if !IsDefined(this.m_panel) { return; }
    this.m_panel.SetVisible(false);
  }
}

public class DPAE_IntegratedAmmoHUDTick extends DelayCallback {
  public let m_system: wref<DPAE_IntegratedAmmoHUDSystem>;

  public func Call() -> Void {
    let sys = this.m_system;
    if IsDefined(sys) {
      sys.Tick();
    }
  }
}

public class DPAE_IntegratedAmmoHUDSystem extends ScriptableSystem {
  private let m_hud: ref<DPAE_IntegratedAmmoHUD>;
  private let m_shownState:   Int32;
  private let m_shownAmmo:    TweakDBID;
  private let m_shownCaliber: TweakDBID;
  private let m_shownWeapon:  ItemID;

  private let m_tickID: DelayID;
  private let m_tickArmed: Bool;
  private let m_wasWeaponStowed: Bool = true;

  public func RegisterHUD(hud: ref<DPAE_IntegratedAmmoHUD>) -> Void {
    this.m_hud = hud;
    this.m_shownState = 0;
  }

  public func IsShowing(state: Int32, ammo: TweakDBID, caliber: TweakDBID, weapon: ItemID) -> Bool {
    return this.m_shownState == state && this.m_shownAmmo == ammo && this.m_shownCaliber == caliber && this.m_shownWeapon == weapon;
  }

  public func RememberShown(state: Int32, ammo: TweakDBID, caliber: TweakDBID, weapon: ItemID) -> Void {
    this.m_shownState   = state;
    this.m_shownAmmo    = ammo;
    this.m_shownCaliber = caliber;
    this.m_shownWeapon  = weapon;
  }

  private func GetAmmoIconForWeapon(weaponID: ItemID) -> CName {
    let rec = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weaponID));
    if !IsDefined(rec) { return n"ammo_rifle"; }

    switch rec.ItemType().Type() {
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
        return n"ammo_handgun";
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
        return n"ammo_shotgun";
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_PrecisionRifle:
        return n"ammo_sniper";
      default:
        return n"ammo_rifle";
    }
  }

  public func UpdateDisplay(caliberLabel: String, variantLabel: String, r: Float, g: Float, b: Float, weaponID: ItemID) -> Void {
    if IsDefined(this.m_hud) {
      let iconName = this.GetAmmoIconForWeapon(weaponID);
      this.m_hud.Show(caliberLabel, variantLabel, r, g, b, iconName);
    }
  }

  public func HideDisplay() -> Void {
    if this.m_shownState == 0 { return; }
    this.m_shownState = 0;
    if IsDefined(this.m_hud) {
      this.m_hud.Hide();
    }
  }

  public func StartTicking() -> Void {
    if this.m_tickArmed { return; }
    this.m_tickArmed = true;
    this.ScheduleTick();
  }

  private func ScheduleTick() -> Void {
    let cb = new DPAE_IntegratedAmmoHUDTick();
    cb.m_system = this;
    this.m_tickID = GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.1, false);
  }

  public func Tick() -> Void {
    let p: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if IsDefined(p) {
      if p.DPAE_IsWeaponStowed() {
        this.m_wasWeaponStowed = true;
      } else {
        if this.m_wasWeaponStowed {
          p.DPAE_RefreshOnDraw();
        }
        this.m_wasWeaponStowed = false;
      }
      p.DPAE_RefreshAmmoHUD();
    }
    this.ScheduleTick();
  }

  private func OnDetach() -> Void {
    if this.m_tickArmed {
      GameInstance.GetDelaySystem(this.GetGameInstance()).CancelCallback(this.m_tickID);
      this.m_tickArmed = false;
    }
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let sys = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"DPAE_IntegratedAmmoHUDSystem") as DPAE_IntegratedAmmoHUDSystem;
  if IsDefined(sys) { sys.StartTicking(); }
  return result;
}

@wrapMethod(WeaponRosterGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  let root = this.GetRootCompoundWidget();
  let weaponOnFoot = root.GetWidget(n"weapon_on_foot") as inkCompoundWidget;
  if !IsDefined(weaponOnFoot) { return false; }

  let ammoCounter = weaponOnFoot.GetWidget(n"ammo_counter") as inkCompoundWidget;
  if !IsDefined(ammoCounter) { return false; }

  let weaponWrapper = ammoCounter.GetWidget(n"weapon_wrapper") as inkCompoundWidget;
  if !IsDefined(weaponWrapper) { return false; }

  let isE3HUD: Bool = false;
  let weaponHolder = weaponWrapper.GetWidget(n"weapon_holder") as inkCompoundWidget;
  if IsDefined(weaponHolder) && IsDefined(weaponHolder.GetWidget(n"decorator")) {
    isE3HUD = true;
  }

  if !isE3HUD {
    let ammoWrapper = weaponWrapper.GetWidget(n"ammo_wrapper") as inkCompoundWidget;
    if IsDefined(ammoWrapper) {
      ammoWrapper.SetHAlign(inkEHorizontalAlign.Right);
    }
  }

  ammoCounter.RemoveChildByName(n"DPAEAmmoHUDInner");

  let player = this.GetPlayerControlledObject() as PlayerPuppet;
  if !IsDefined(player) { return false; }

  let sys = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"DPAE_IntegratedAmmoHUDSystem") as DPAE_IntegratedAmmoHUDSystem;
  if IsDefined(sys) {
    let hud = DPAE_IntegratedAmmoHUD.Create(ammoCounter, isE3HUD);
    sys.RegisterHUD(hud);

    player.DPAE_RefreshAmmoHUD();
  }
}

@wrapMethod(WeaponRosterGameController)
protected cb func OnWeaponDataChanged(value: Variant) -> Bool {
  wrappedMethod(value);
  let player = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    player.DPAE_RefreshAmmoHUD();
  }
}

@wrapMethod(WeaponRosterGameController)
protected cb func OnMountingEvent(evt: ref<MountingEvent>) -> Bool {
  wrappedMethod(evt);
  let player = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    player.DPAE_RefreshAmmoHUD();
  }
}

@wrapMethod(WeaponRosterGameController)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
  wrappedMethod(evt);
  let player = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) {
    player.DPAE_RefreshAmmoHUD();
  }
}

@wrapMethod(WeaponRosterGameController)
private final func Fold() -> Void {
  wrappedMethod();
  this.DPAE_SyncWrapperAnimation(true);
}

@wrapMethod(WeaponRosterGameController)
private final func Unfold() -> Void {
  wrappedMethod();
  this.DPAE_SyncWrapperAnimation(false);
}

@addMethod(WeaponRosterGameController)
private func DPAE_SyncWrapperAnimation(isFold: Bool) -> Void {
  let root = this.GetRootCompoundWidget();
  if !IsDefined(root) { return; }

  let weaponOnFoot = root.GetWidget(n"weapon_on_foot") as inkCompoundWidget;
  if !IsDefined(weaponOnFoot) { return; }

  let ammoCounter = weaponOnFoot.GetWidget(n"ammo_counter") as inkCompoundWidget;
  if !IsDefined(ammoCounter) { return; }

  let weaponWrapper = ammoCounter.GetWidget(n"weapon_wrapper") as inkCompoundWidget;
  if !IsDefined(weaponWrapper) { return; }

  let weaponHolder = weaponWrapper.GetWidget(n"weapon_holder") as inkCompoundWidget;

  if IsDefined(weaponHolder) && IsDefined(weaponHolder.GetWidget(n"decorator")) {
    return;
  }

  let ammoWrapper = weaponWrapper.GetWidget(n"ammo_wrapper");

  if IsDefined(weaponHolder) {
    let animDef = new inkAnimDef();
    let alpha = new inkAnimTransparency();
    let trans = new inkAnimTranslation();

    alpha.SetDuration(0.0718);
    alpha.SetMode(inkanimInterpolationMode.EasyInOut);
    alpha.SetType(inkanimInterpolationType.Exponential);

    trans.SetDuration(0.25);
    trans.SetMode(inkanimInterpolationMode.EasyInOut);
    trans.SetType(inkanimInterpolationType.Exponential);

    if isFold {
      alpha.SetStartTransparency(1.0); alpha.SetEndTransparency(0.0); alpha.SetStartDelay(0.099);
      trans.SetStartTranslation(new Vector2(0.0, 0.0)); trans.SetEndTranslation(new Vector2(500.0, 0.0)); trans.SetStartDelay(0.0);
    } else {
      alpha.SetStartTransparency(0.0); alpha.SetEndTransparency(1.0); alpha.SetStartDelay(0.199);
      trans.SetStartTranslation(new Vector2(500.0, 0.0)); trans.SetEndTranslation(new Vector2(0.0, 0.0)); trans.SetStartDelay(0.156);
    }

    animDef.AddInterpolator(alpha);
    animDef.AddInterpolator(trans);
    weaponHolder.PlayAnimation(animDef);
  }

  if IsDefined(ammoWrapper) {
    let animDef = new inkAnimDef();
    let alpha = new inkAnimTransparency();
    let trans = new inkAnimTranslation();

    alpha.SetDuration(0.0718);
    alpha.SetMode(inkanimInterpolationMode.EasyInOut);
    alpha.SetType(inkanimInterpolationType.Exponential);

    trans.SetDuration(0.25);
    trans.SetMode(inkanimInterpolationMode.EasyInOut);
    trans.SetType(inkanimInterpolationType.Exponential);

    if isFold {
      alpha.SetStartTransparency(1.0); alpha.SetEndTransparency(0.0); alpha.SetStartDelay(0.100);
      trans.SetStartTranslation(new Vector2(0.0, 0.0)); trans.SetEndTranslation(new Vector2(245.0, 0.0)); trans.SetStartDelay(0.0);
    } else {
      alpha.SetStartTransparency(0.0); alpha.SetEndTransparency(1.0); alpha.SetStartDelay(0.199);
      trans.SetStartTranslation(new Vector2(245.0, 0.0)); trans.SetEndTranslation(new Vector2(0.0, 0.0)); trans.SetStartDelay(0.157);
    }

    animDef.AddInterpolator(alpha);
    animDef.AddInterpolator(trans);
    ammoWrapper.PlayAnimation(animDef);
  }
}
