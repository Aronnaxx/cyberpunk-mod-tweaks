// Lua GC Tuner - Esc menu page helper (always compiled; no other mod needed)
// The CET side asks the pause scenario which page is open: "<menu>|<sub-menu>", e.g. "pause_menu|" on the
// Resume / Save / Load list, something else on the settings page Mod Configuration Menu draws into.

@addMethod(MenuScenario_BaseMenu)
public func LuaGCTuner_MenuPage() -> String {
  return NameToString(this.m_currMenuName) + "|" + NameToString(this.m_currSubMenuName);
}
