// Night City Traffic Overhaul 2.40 - passenger fix
// matchRandomPassengersSlots() read desiredPassengers[i] for every passenger slot of the vehicle, but the
// lists only hold 3 entries: vehicles with 4+ slots got empty IDs in randomPassengers. Never read past the end.
module NightCityTrafficOverhaul

@if(ModuleExists("NightCityTrafficOverhaul.Settings"))
@replaceGlobal()
public func matchRandomPassengersSlots(basePassengers: array<TweakDBID>, desiredPassengers: array<TweakDBID>) -> array<TweakDBID> {
    let newPassengers: array<TweakDBID>;
    let available = ArraySize(desiredPassengers);
    if available < 1 {
        return basePassengers;
    }
    let slots = ArraySize(basePassengers);
    if slots < 1 { slots = 1; }
    if slots > available { slots = available; }
    let i = 0;
    while i < slots {
        ArrayPush(newPassengers, desiredPassengers[i]);
        i += 1;
    }
    return newPassengers;
}
