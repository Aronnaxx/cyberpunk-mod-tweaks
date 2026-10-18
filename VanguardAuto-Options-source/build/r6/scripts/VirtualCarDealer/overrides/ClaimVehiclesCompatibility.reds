import CarDealer.System.PurchasableVehicleSystem
import CarDealer.Dispatch.VanguardDispatchCoordinator

                                                                                       
                                                                                            
                                                                                                 
                                                                                               
@wrapMethod(VehicleComponent)
private final func StealVehicle(opt slotID: MountingSlotId) -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let vehicleID: TweakDBID;

  wrappedMethod(slotID);

  if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {
    vehicleID = vehicle.GetRecordID();
    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).MarkExternalVehicleClaimed(vehicleID);
  };
}

@wrapMethod(VehicleComponent)
protected cb func OnRemoteControlEvent(evt: ref<VehicleRemoteControlEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let vehicle: ref<VehicleObject> = this.GetVehicle();

  if IsDefined(vehicle) && IsDefined(evt) && evt.remoteControl && vehicle.IsPlayerVehicle() {
    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).MarkExternalVehicleClaimed(vehicle.GetRecordID());
  };

  return result;
}

@wrapMethod(DriveEvents)
public final func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let vehicle: ref<VehicleObject> = scriptInterface.owner as VehicleObject;

  wrappedMethod(stateContext, scriptInterface);

  if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {
    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).MarkExternalVehicleClaimed(vehicle.GetRecordID());
  };
  if IsDefined(vehicle) {
    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).ClaimSoldVehicleIfUnlocked(vehicle.GetRecordID());
  };
}
