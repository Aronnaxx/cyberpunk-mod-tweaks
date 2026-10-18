module FACCarryCapacity

// Helper living in FACC's own module so the wardrobe buttons can raise FACC's panel events.
public static func FACCWBToggleCarry(gi: GameInstance) -> Void {
  GameInstance.GetUISystem(gi).QueueEvent(new FACCTogglePanelEvent());
}

public static func FACCWBCloseCarry(gi: GameInstance) -> Void {
  GameInstance.GetUISystem(gi).QueueEvent(new FACCClosePanelEvent());
}
