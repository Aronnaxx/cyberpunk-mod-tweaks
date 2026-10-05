import FleshAndChrome.*
import DigitalVixenCore.*

// timeskip meter bars - preview stamina & energy before napping ✧

@addField(TimeskipGameController)
private let m_facSystem: wref<FACSystem>;

@addField(TimeskipGameController)
private let m_facStaminaBar: ref<FACInventoryBar>;

@addField(TimeskipGameController)
private let m_facEnergyBar: ref<FACInventoryBar>;

@addField(TimeskipGameController)
private let m_facBarCluster: ref<inkHorizontalPanel>;

@addField(TimeskipGameController)
private let m_facInCar: Bool;

@wrapMethod(TimeskipGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();

  let gi: GameInstance = GetGameInstance();
  let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gi);
  if !IsDefined(container) { return result; }

  let facSystem: ref<FACSystem> = container.Get(n"FleshAndChrome.FACSystem") as FACSystem;
  if !IsDefined(facSystem) || !facSystem.IsEnabled() { return result; }
  if !facSystem.m_config.showBarsOnTimeskip { return result; }

  this.m_facSystem = facSystem;
  this.m_facInCar = facSystem.m_facSleepingInCar;   

  let player: ref<PlayerPuppet> = GetPlayer(gi) as PlayerPuppet;
  if !IsDefined(player) { return result; }

  let parentWidget: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  let container2: ref<inkCanvas> = parentWidget.GetWidget(n"container") as inkCanvas;
  if !IsDefined(container2) { return result; }

  let cluster: ref<inkHorizontalPanel> = new inkHorizontalPanel();
  cluster.SetName(n"FACTimeskipBars");
  cluster.SetAnchor(inkEAnchor.TopCenter);
  cluster.SetAnchorPoint(Vector2(0.5, 0.5));
  cluster.SetHAlign(inkEHorizontalAlign.Center);
  cluster.SetMargin(inkMargin(0.0, -100.0, 0.0, 0.0));
  cluster.Reparent(container2, 12);
  this.m_facBarCluster = cluster;

  let staminaBar: ref<FACInventoryBar> = new FACInventoryBar();
  staminaBar.Init(cluster, n"facTimeskipStamina", "STAMINA", 500.0);
  this.m_facStaminaBar = staminaBar;

  let energyBar: ref<FACInventoryBar> = new FACInventoryBar();
  energyBar.Init(cluster, n"facTimeskipEnergy", "ENERGY", 500.0);
  this.m_facEnergyBar = energyBar;

  let staminaPct: Float = facSystem.GetStaminaPercent(player) * 100.0;
  let energyPct: Float  = facSystem.GetEnergyPercent(player) * 100.0;
  staminaBar.SetValue(staminaPct, energyPct);
  energyBar.SetValue(energyPct, energyPct);

  this.FACUpdateBarPreview();

  return result;
}

@wrapMethod(TimeskipGameController)
private final func UpdateTargetTime(angle: Float) -> Void {
  wrappedMethod(angle);
  this.FACUpdateBarPreview();
}

@wrapMethod(TimeskipGameController)
private final func Apply() -> Void {
  if this.m_hoursToSkip > 0 {   
    DVPlayerState.MarkWaitWheelOpened(GetGameInstance());
  }
  wrappedMethod();
}

@wrapMethod(TimeskipGameController)
protected cb func OnUpdate(timeDelta: Float) -> Bool {
  wrappedMethod(timeDelta);
}

@wrapMethod(TimeskipGameController)
protected cb func OnCloseAfterCanceling(proxy: ref<inkAnimProxy>) -> Bool {
  
  if IsDefined(this.m_facSystem) && this.m_facInCar {
    this.m_facSystem.m_facSleepingInCar = false;
  }
  return wrappedMethod(proxy);
}

@addMethod(TimeskipGameController)
private final func FACUpdateBarPreview() -> Void {
  if !IsDefined(this.m_facSystem) { return; }

  let gi: GameInstance = GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gi) as PlayerPuppet;
  if !IsDefined(player) { return; }

  let hoursToSkip: Int32 = this.m_hoursToSkip;
  if hoursToSkip < 1 { hoursToSkip = 1; }

  let projected: array<Float> = this.m_facSystem.ProjectSleepResult(player, hoursToSkip);
  let energyPct: Float = projected[1];

  this.m_facStaminaBar.SetPreview(projected[0], energyPct);
  this.m_facEnergyBar.SetPreview(energyPct, energyPct);
}
