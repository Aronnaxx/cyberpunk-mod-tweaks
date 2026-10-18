module FACCarryCapacity

// FACC-HubButtonMove: adds a second copy of FACC Carry Capacity's hub button to the inventory
// screen, directly under Street Smarts (margin -168). The original button (margin 510) is left alone.
// Both use identifier 43, so FACC's own click handler toggles the same panel from either one.

@wrapMethod(MenuHubLogicController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();

  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  if !IsDefined(root) { return result; };
  let panel: ref<inkCompoundWidget> = root.GetWidgetByPathName(n"mainMenu/buttonsContainer/panel_inventory") as inkCompoundWidget;
  if !IsDefined(panel) { return result; };

  let config: ref<FACCarryCapacityConfig> = FACCarryCapacityConfig.Get();
  if !IsDefined(config) || !config.modON { return result; };

  let buttonWidget: ref<inkWidget> = this.SpawnFromLocal(panel, n"menu_button");
  if !IsDefined(buttonWidget) { return result; };
  buttonWidget.SetName(n"FACCHubButtonCopy");
  buttonWidget.SetMargin(inkMargin(0.0, -88.0, 0.0, 0.0));

  let data: MenuData;
  data.identifier = 43;
  data.parentIdentifier = 3;
  data.label = GetLocalizedTextByKey(n"FACC.UI.menuButton");
  data.icon = n"ico_backpack";

  let controller: ref<MenuItemController> = buttonWidget.GetController() as MenuItemController;
  if IsDefined(controller) {
    controller.Init(data);
  };
  return result;
}
