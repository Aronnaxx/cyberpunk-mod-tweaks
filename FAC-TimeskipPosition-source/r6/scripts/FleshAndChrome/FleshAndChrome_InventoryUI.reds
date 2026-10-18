import FleshAndChrome.*

// inventory bars with daily consumable counters (ﾉ◕ヮ◕)ﾉ*:・ﾟ✧

public class FACInventoryBar extends inkCanvas {

  private let m_fillWidth: Float;
  private let m_barHeight: Float;
  private let m_fillBar: ref<inkRectangle>;
  private let m_changeBar: ref<inkRectangle>;
  private let m_bg: ref<inkRectangle>;
  private let m_border: ref<inkRectangle>;
  private let m_label: ref<inkText>;
  private let m_valueText: ref<inkText>;
  private let m_currentPct: Float;
  private let m_counterRow: ref<inkHorizontalPanel>;

  public final func Init(parent: ref<inkCompoundWidget>, widgetName: CName, labelText: String, barWidth: Float) -> Void {
    this.m_fillWidth = barWidth - 22.0;
    this.m_barHeight = 8.0;
    this.m_currentPct = 100.0;
    this.CreateBar(parent, widgetName, labelText, barWidth);
  }

  private final func CreateBar(parent: ref<inkCompoundWidget>, widgetName: CName, labelText: String, canvasWidth: Float) -> Void {
    let canvas: ref<inkCanvas> = new inkCanvas();
    canvas.SetName(widgetName);
    canvas.SetChildOrder(inkEChildOrder.Backward);
    canvas.SetSize(Vector2(canvasWidth, 76.0));
    canvas.SetHAlign(inkEHorizontalAlign.Center);
    canvas.SetMargin(inkMargin(0.0, 0.0, 60.0, 0.0));
    canvas.Reparent(parent);

    let vertPanel: ref<inkVerticalPanel> = new inkVerticalPanel();
    vertPanel.SetName(n"vertPanel");
    vertPanel.SetMargin(inkMargin(10.0, 0.0, 0.0, 0.0));
    vertPanel.SetAnchor(inkEAnchor.TopLeft);
    vertPanel.SetVAlign(inkEVerticalAlign.Center);
    vertPanel.SetSize(Vector2(100.0, 32.0));
    vertPanel.Reparent(canvas);

    let labelPanel: ref<inkFlex> = new inkFlex();
    labelPanel.SetName(n"labelPanel");
    labelPanel.SetAnchor(inkEAnchor.Fill);
    labelPanel.SetSize(Vector2(canvasWidth - 20.0, 32.0));
    labelPanel.Reparent(vertPanel);

    let barLabel: ref<inkText> = new inkText();
    barLabel.SetName(n"barLabel");
    barLabel.SetMargin(inkMargin(2.0, 0.0, 0.0, 3.0));
    barLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    barLabel.SetLetterCase(textLetterCase.UpperCase);
    barLabel.SetFontSize(36);
    barLabel.SetText(labelText);
    barLabel.SetHAlign(inkEHorizontalAlign.Left);
    barLabel.SetVAlign(inkEVerticalAlign.Bottom);
    barLabel.Reparent(labelPanel);
    this.m_label = barLabel;

    let valueLabel: ref<inkText> = new inkText();
    valueLabel.SetName(n"valueLabel");
    valueLabel.SetAnchor(inkEAnchor.BottomRight);
    valueLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    valueLabel.SetLetterCase(textLetterCase.UpperCase);
    valueLabel.SetFontSize(36);
    valueLabel.SetText("100%");
    valueLabel.SetHAlign(inkEHorizontalAlign.Right);
    valueLabel.SetVAlign(inkEVerticalAlign.Bottom);
    valueLabel.SetMargin(inkMargin(0.0, 0.0, 10.0, 3.0));
    valueLabel.Reparent(labelPanel);
    this.m_valueText = valueLabel;

    let wrapper: ref<inkFlex> = new inkFlex();
    wrapper.SetName(n"wrapper");
    wrapper.SetAnchor(inkEAnchor.TopLeft);
    wrapper.SetHAlign(inkEHorizontalAlign.Left);
    wrapper.SetVAlign(inkEVerticalAlign.Top);
    wrapper.SetSize(Vector2(100.0, 15.0));
    wrapper.Reparent(vertPanel);

    let bg: ref<inkRectangle> = new inkRectangle();
    bg.SetName(n"bg");
    bg.SetHAlign(inkEHorizontalAlign.Left);
    bg.SetVAlign(inkEVerticalAlign.Center);
    bg.SetMargin(inkMargin(5.0, 0.0, 0.0, 0.0));
    bg.SetShear(Vector2(0.5, 0.0));
    bg.SetRenderTransformPivot(Vector2(1.0, 0.5));
    bg.SetSize(Vector2(canvasWidth - 20.0, 10.0));
    bg.Reparent(wrapper);
    this.m_bg = bg;

    let border: ref<inkRectangle> = new inkRectangle();
    border.SetName(n"border");
    border.SetMargin(inkMargin(5.0, 0.0, 0.0, 0.0));
    border.SetHAlign(inkEHorizontalAlign.Fill);
    border.SetVAlign(inkEVerticalAlign.Center);
    border.SetOpacity(0.15);
    border.SetShear(Vector2(0.5, 0.0));
    border.SetSize(Vector2(100.0, 12.0));
    border.Reparent(wrapper);
    this.m_border = border;

    let fillBar: ref<inkRectangle> = new inkRectangle();
    fillBar.SetName(n"fillBar");
    fillBar.SetAnchor(inkEAnchor.TopLeft);
    fillBar.SetHAlign(inkEHorizontalAlign.Left);
    fillBar.SetVAlign(inkEVerticalAlign.Center);
    fillBar.SetShear(Vector2(0.5, 0.0));
    fillBar.SetTranslation(8.0, 0.0);
    fillBar.SetRenderTransformPivot(Vector2(0.0, 0.5));
    fillBar.SetSize(Vector2(this.m_fillWidth, this.m_barHeight));
    fillBar.Reparent(wrapper);
    this.m_fillBar = fillBar;

    let changeBar: ref<inkRectangle> = new inkRectangle();
    changeBar.SetName(n"changeBar");
    changeBar.SetAnchor(inkEAnchor.TopLeft);
    changeBar.SetHAlign(inkEHorizontalAlign.Left);
    changeBar.SetVAlign(inkEVerticalAlign.Center);
    changeBar.SetShear(Vector2(0.5, 0.0));
    changeBar.SetTranslation(8.0, 0.0);
    changeBar.SetRenderTransformPivot(Vector2(0.0, 0.5));
    changeBar.SetSize(Vector2(0.5, this.m_barHeight));
    changeBar.Reparent(wrapper);
    this.m_changeBar = changeBar;

    let counterRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    counterRow.SetName(n"counterRow");
    counterRow.SetHAlign(inkEHorizontalAlign.Left);
    counterRow.SetMargin(inkMargin(8.0, 2.0, 0.0, 0.0));
    counterRow.SetSize(Vector2(canvasWidth - 20.0, 24.0));
    counterRow.Reparent(vertPanel);
    this.m_counterRow = counterRow;
  }

  public final func AddCounter(labelText: String) -> ref<inkText> {
    let pair: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    pair.SetName(StringToName("counter_" + labelText));
    pair.SetMargin(inkMargin(0.0, 0.0, 16.0, 0.0));
    pair.SetVAlign(inkEVerticalAlign.Center);
    pair.Reparent(this.m_counterRow);

    let label: ref<inkText> = new inkText();
    label.SetName(n"counterLabel");
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetFontSize(26);
    label.SetText(labelText);
    label.SetOpacity(0.5);
    label.SetVAlign(inkEVerticalAlign.Center);
    label.SetMargin(inkMargin(0.0, 0.0, 2.0, 0.0));
    label.Reparent(pair);

    let value: ref<inkText> = new inkText();
    value.SetName(n"counterValue");
    value.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    value.SetFontSize(26);
    value.SetText("x0");
    value.SetVAlign(inkEVerticalAlign.Center);
    value.Reparent(pair);

    return value;
  }

  public final func SetValue(pct: Float, energyPct: Float) -> Void {
    this.m_currentPct = ClampF(pct, 0.0, 100.0);
    let fraction: Float = this.m_currentPct / 100.0;

    let fillW: Float = MaxF(this.m_fillWidth * fraction, 0.5);
    this.m_fillBar.SetSize(Vector2(fillW, this.m_barHeight));
    this.m_changeBar.SetTranslation(8.0, 0.0);
    this.m_changeBar.SetSize(Vector2(0.5, this.m_barHeight));
    this.m_valueText.SetText(ToString(RoundF(this.m_currentPct)) + "%");

    let color: HDRColor = FACui.EnergyToColor(energyPct);
    this.m_fillBar.SetTintColor(color);
    this.m_label.SetTintColor(color);
    this.m_valueText.SetTintColor(color);
    this.m_border.SetTintColor(color);

    let bgColor: HDRColor;
    bgColor.Red = 0.12;
    bgColor.Green = 0.12;
    bgColor.Blue = 0.14;
    bgColor.Alpha = 1.0;
    this.m_bg.SetTintColor(bgColor);
    this.m_bg.SetOpacity(0.6);
  }

  public final func SetPreview(newPct: Float, energyPct: Float) -> Void {
    let cur: Float = this.m_currentPct / 100.0;
    let nw: Float = ClampF(newPct, 0.0, 100.0) / 100.0;
    let color: HDRColor = FACui.EnergyToColor(energyPct);

    this.m_valueText.SetText(ToString(RoundF(ClampF(newPct, 0.0, 100.0))) + "%");

    if nw > cur + 0.005 {
      
      this.m_fillBar.SetSize(Vector2(MaxF(this.m_fillWidth * cur, 0.5), this.m_barHeight));
      this.m_changeBar.SetTranslation(8.0 + (this.m_fillWidth * cur), 0.0);
      this.m_changeBar.SetSize(Vector2(MaxF(this.m_fillWidth * (nw - cur), 0.5), this.m_barHeight));
      let cyan: HDRColor;
      cyan.Red = 0.20;
      cyan.Green = 0.85;
      cyan.Blue = 1.00;
      cyan.Alpha = 1.0;
      this.m_changeBar.SetTintColor(cyan);
      this.m_valueText.SetTintColor(cyan);
    } else if cur > nw + 0.005 {
      
      this.m_fillBar.SetSize(Vector2(MaxF(this.m_fillWidth * nw, 0.5), this.m_barHeight));
      this.m_changeBar.SetTranslation(8.0 + (this.m_fillWidth * nw), 0.0);
      this.m_changeBar.SetSize(Vector2(MaxF(this.m_fillWidth * (cur - nw), 0.5), this.m_barHeight));
      let orange: HDRColor;
      orange.Red = 1.00;
      orange.Green = 0.55;
      orange.Blue = 0.05;
      orange.Alpha = 1.0;
      this.m_changeBar.SetTintColor(orange);
      this.m_valueText.SetTintColor(orange);
    } else {
      this.m_fillBar.SetSize(Vector2(MaxF(this.m_fillWidth * cur, 0.5), this.m_barHeight));
      this.m_changeBar.SetSize(Vector2(0.5, this.m_barHeight));
      this.m_valueText.SetTintColor(color);
    }

    this.m_fillBar.SetTintColor(color);
    this.m_label.SetTintColor(color);
    this.m_border.SetTintColor(color);
  }
}

@addField(BackpackMainGameController)
private let m_facSystem: wref<FACSystem>;

@addField(BackpackMainGameController)
private let m_facEnergyBar: ref<FACInventoryBar>;

@addField(BackpackMainGameController)
private let m_facStaminaBar: ref<FACInventoryBar>;

@addField(BackpackMainGameController)
private let m_facBarCluster: ref<inkHorizontalPanel>;

@addField(BackpackMainGameController)
private let m_facFadeProxy: ref<inkAnimProxy>;

@addField(BackpackMainGameController)
private let m_facFadeDef: ref<inkAnimDef>;

@addField(BackpackMainGameController)
private let m_facMealCounter: ref<inkText>;

@addField(BackpackMainGameController)
private let m_facDrinkCounter: ref<inkText>;

@addField(BackpackMainGameController)
private let m_facSnackCounter: ref<inkText>;

@wrapMethod(BackpackMainGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();

  this.m_facSystem = GameInstance.GetScriptableSystemsContainer(GetGameInstance())
    .Get(n"FleshAndChrome.FACSystem") as FACSystem;

  if IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() {
    let parentWidget: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    this.FACCreateBarCluster(parentWidget);
    this.FACRefreshBars();
  }

  return result;
}

@wrapMethod(BackpackMainGameController)
protected cb func OnItemDisplayHoverOver(evt: ref<ItemDisplayHoverOverEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);

  if IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() && IsDefined(evt.uiInventoryItem) {
    let itemData: wref<gameItemData> = evt.uiInventoryItem.GetItemData();

    if IsDefined(itemData) && itemData.HasTag(n"Consumable") {
      let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
      if IsDefined(player) {
        let energyDelta: Float = this.m_facSystem.GetItemEnergyDelta(player, itemData);
        let staminaDelta: Float = this.m_facSystem.GetItemStaminaDelta(player, itemData);
        let energyPct: Float = this.m_facSystem.GetEnergyPercent(player);

        if AbsF(energyDelta) > 0.01 {
          let curEnergy: Float = energyPct * 100.0;
          let previewEnergyPct: Float = ClampF((curEnergy + energyDelta) / 100.0, 0.0, 1.0);
          this.m_facEnergyBar.SetPreview(curEnergy + energyDelta, previewEnergyPct);
        }

        if AbsF(staminaDelta) > 0.01 {
          let curStamina: Float = this.m_facSystem.GetStaminaPercent(player) * 100.0;
          this.m_facStaminaBar.SetPreview(curStamina + staminaDelta, energyPct);
        }
      }
    }
  }

  return result;
}

@wrapMethod(BackpackMainGameController)
protected cb func OnItemDisplayHoverOut(evt: ref<ItemDisplayHoverOutEvent>) -> Bool {
  if IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() {
    this.FACRefreshBars();
  }

  return wrappedMethod(evt);
}

@wrapMethod(BackpackMainGameController)
protected cb func OnItemFilterClick(evt: ref<inkPointerEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);

  if IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() {
    if evt.IsAction(n"click") {
      this.FACUpdateBarVisibility(true);
    }
  }

  return result;
}

@wrapMethod(BackpackMainGameController)
protected cb func OnFilterButtonSpawned(widget: ref<inkWidget>, callbackData: ref<BackpackFilterButtonSpawnedCallbackData>) -> Bool {
  let result: Bool = wrappedMethod(widget, callbackData);

  if IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() {
    this.FACUpdateBarVisibility(false);
  }

  return result;
}

@addMethod(BackpackMainGameController)
private final func FACCreateBarCluster(parent: ref<inkCompoundWidget>) -> Void {
  let config: ref<FACConfig> = FACConfig.Get();
  this.m_facBarCluster = new inkHorizontalPanel();
  this.m_facBarCluster.SetOpacity(0.0);
  this.m_facBarCluster.SetName(n"FACBarCluster");
  this.m_facBarCluster.SetAnchor(inkEAnchor.TopCenter);
  this.m_facBarCluster.SetAnchorPoint(Vector2(0.5, 0.5));
  this.m_facBarCluster.SetTranslation(Vector2(config.barOffsetX, config.barOffsetY));
  this.m_facBarCluster.SetHAlign(inkEHorizontalAlign.Center);
  this.m_facBarCluster.SetVAlign(inkEVerticalAlign.Center);
  this.m_facBarCluster.Reparent(parent, 12);

  this.m_facStaminaBar = new FACInventoryBar();
  this.m_facStaminaBar.Init(this.m_facBarCluster, n"facStaminaBar", "Stamina", 400.0);
  this.m_facSnackCounter = this.m_facStaminaBar.AddCounter("Snacks");

  this.m_facEnergyBar = new FACInventoryBar();
  this.m_facEnergyBar.Init(this.m_facBarCluster, n"facEnergyBar", "Energy", 400.0);
  this.m_facMealCounter = this.m_facEnergyBar.AddCounter("Meals");
  this.m_facDrinkCounter = this.m_facEnergyBar.AddCounter("Drinks");
}

@addMethod(BackpackMainGameController)
private final func FACRefreshBars() -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
  if !IsDefined(player) || !IsDefined(this.m_facSystem) { return; }

  let energyPct: Float = this.m_facSystem.GetEnergyPercent(player);
  let staminaPct: Float = this.m_facSystem.GetStaminaPercent(player);

  this.m_facEnergyBar.SetValue(energyPct * 100.0, energyPct);
  this.m_facStaminaBar.SetValue(staminaPct * 100.0, energyPct);

  let mealsLeft: Int32 = this.m_facSystem.GetMealsRemaining(player);
  let drinksLeft: Int32 = this.m_facSystem.GetDrinksRemaining(player);
  let snacksLeft: Int32 = this.m_facSystem.GetSnacksRemaining(player);

  this.m_facMealCounter.SetText("x" + ToString(mealsLeft));
  this.m_facMealCounter.SetOpacity(mealsLeft > 0 ? 1.0 : 0.3);

  this.m_facDrinkCounter.SetText("x" + ToString(drinksLeft));
  this.m_facDrinkCounter.SetOpacity(drinksLeft > 0 ? 1.0 : 0.3);

  this.m_facSnackCounter.SetText("x" + ToString(snacksLeft));
  this.m_facSnackCounter.SetOpacity(snacksLeft > 0 ? 1.0 : 0.3);
}

@addMethod(BackpackMainGameController)
private final func FACUpdateBarVisibility(animate: Bool) -> Void {
  let config: ref<FACConfig> = FACConfig.Get();
  let filterInt: Int32 = EnumInt(this.m_activeFilter.GetFilterType());
  let show: Bool = false;
  if config.showBarOnConsumables && filterInt == 3 { show = true; }
  if config.showBarOnAllItems && filterInt == 14 { show = true; }
  if config.showBarOnFood && filterInt == 24 { show = true; }

  if animate {
    this.FACBarFade(show ? 1.0 : 0.0);
  } else {
    this.m_facBarCluster.SetOpacity(show ? 1.0 : 0.0);
  }
}

@addMethod(BackpackMainGameController)
private final func FACBarFade(targetOpacity: Float) -> Void {
  if IsDefined(this.m_facFadeProxy) { this.m_facFadeProxy.Stop(); }

  this.m_facFadeDef = new inkAnimDef();
  let interp: ref<inkAnimTransparency> = new inkAnimTransparency();
  interp.SetStartTransparency(this.m_facBarCluster.GetOpacity());
  interp.SetEndTransparency(targetOpacity);
  interp.SetDuration(0.075);
  this.m_facFadeDef.AddInterpolator(interp);
  this.m_facFadeProxy = this.m_facBarCluster.PlayAnimation(this.m_facFadeDef);

  if targetOpacity > 0.5 {
    this.FACRefreshBars();
  }
}

@addField(RadialWheelController)
private let m_facSystem: wref<FACSystem>;

@addField(RadialWheelController)
private let m_facEnergyBar: ref<FACInventoryBar>;

@addField(RadialWheelController)
private let m_facStaminaBar: ref<FACInventoryBar>;

@addField(RadialWheelController)
private let m_facBarCluster: ref<inkHorizontalPanel>;

@addField(RadialWheelController)
private let m_facMealCounter: ref<inkText>;

@addField(RadialWheelController)
private let m_facDrinkCounter: ref<inkText>;

@addField(RadialWheelController)
private let m_facSnackCounter: ref<inkText>;

@wrapMethod(RadialWheelController)
protected cb func OnLateInit(evt: ref<LateInit>) -> Bool {
  let result: Bool = wrappedMethod(evt);

  this.m_facSystem = GameInstance.GetScriptableSystemsContainer(GetGameInstance())
    .Get(n"FleshAndChrome.FACSystem") as FACSystem;

  this.FACApplyWheelSettings();
  this.FACRefreshWheelBars();

  return result;
}

@wrapMethod(RadialWheelController)
protected cb func OnOpenWheelRequest(evt: ref<QuickSlotButtonHoldStartEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);

  this.FACApplyWheelSettings();
  this.FACRefreshWheelBars();
  return result;
}

@wrapMethod(RadialWheelController)
protected cb func OnUninitialize() -> Bool {
  this.m_facSystem = null;
  this.m_facEnergyBar = null;
  this.m_facStaminaBar = null;
  this.m_facBarCluster = null;
  this.m_facMealCounter = null;
  this.m_facDrinkCounter = null;
  this.m_facSnackCounter = null;
  return wrappedMethod();
}

// FAC-TimeskipPosition patch: re-read the weapon wheel settings every time the wheel opens
// (stock FAC only read them once at LateInit, so menu changes needed a save reload).
@addMethod(RadialWheelController)
private final func FACApplyWheelSettings() -> Void {
  let config: ref<FACConfig> = FACConfig.Get();
  let show: Bool = IsDefined(this.m_facSystem) && this.m_facSystem.IsEnabled() && config.showBarOnWeaponWheel;
  if show && !IsDefined(this.m_facBarCluster) {
    this.FACCreateWheelBars(this.GetRootCompoundWidget(), config);
  }
  if IsDefined(this.m_facBarCluster) {
    this.m_facBarCluster.SetVisible(show);
    this.m_facBarCluster.SetTranslation(Vector2(config.wheelBarOffsetX, config.wheelBarOffsetY));
  }
}

@addMethod(RadialWheelController)
private final func FACCreateWheelBars(parent: ref<inkCompoundWidget>, config: ref<FACConfig>) -> Void {
  this.m_facBarCluster = new inkHorizontalPanel();
  this.m_facBarCluster.SetName(n"FACWheelBarCluster");
  this.m_facBarCluster.SetAnchor(inkEAnchor.TopCenter);
  this.m_facBarCluster.SetAnchorPoint(Vector2(0.5, 0.5));
  this.m_facBarCluster.SetTranslation(Vector2(config.wheelBarOffsetX, config.wheelBarOffsetY));
  this.m_facBarCluster.SetHAlign(inkEHorizontalAlign.Center);
  this.m_facBarCluster.SetVAlign(inkEVerticalAlign.Center);
  this.m_facBarCluster.Reparent(parent);

  this.m_facStaminaBar = new FACInventoryBar();
  this.m_facStaminaBar.Init(this.m_facBarCluster, n"facWheelStaminaBar", "Stamina", 400.0);
  this.m_facSnackCounter = this.m_facStaminaBar.AddCounter("Snacks");

  this.m_facEnergyBar = new FACInventoryBar();
  this.m_facEnergyBar.Init(this.m_facBarCluster, n"facWheelEnergyBar", "Energy", 400.0);
  this.m_facMealCounter = this.m_facEnergyBar.AddCounter("Meals");
  this.m_facDrinkCounter = this.m_facEnergyBar.AddCounter("Drinks");
}

@addMethod(RadialWheelController)
private final func FACRefreshWheelBars() -> Void {
  let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
  if !IsDefined(player) || !IsDefined(this.m_facSystem) { return; }
  if !IsDefined(this.m_facEnergyBar) || !IsDefined(this.m_facStaminaBar) { return; }

  let energyPct: Float = this.m_facSystem.GetEnergyPercent(player);
  let staminaPct: Float = this.m_facSystem.GetStaminaPercent(player);

  this.m_facEnergyBar.SetValue(energyPct * 100.0, energyPct);
  this.m_facStaminaBar.SetValue(staminaPct * 100.0, energyPct);

  let mealsLeft: Int32 = this.m_facSystem.GetMealsRemaining(player);
  let drinksLeft: Int32 = this.m_facSystem.GetDrinksRemaining(player);
  let snacksLeft: Int32 = this.m_facSystem.GetSnacksRemaining(player);

  this.m_facMealCounter.SetText("x" + ToString(mealsLeft));
  this.m_facMealCounter.SetOpacity(mealsLeft > 0 ? 1.0 : 0.3);

  this.m_facDrinkCounter.SetText("x" + ToString(drinksLeft));
  this.m_facDrinkCounter.SetOpacity(drinksLeft > 0 ? 1.0 : 0.3);

  this.m_facSnackCounter.SetText("x" + ToString(snacksLeft));
  this.m_facSnackCounter.SetOpacity(snacksLeft > 0 ? 1.0 : 0.3);
}
