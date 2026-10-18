# MapFilterFix v1.0

TweakXL-only patch for Garage Core (Nexus 30297). Moves the "Garages" world-map filter from
`CustomFilter` (shared with the Custom tab and Custom Map Markers) to `Courier`, which no vanilla
Custom-list entry uses.

Known leftover: Immersive Odometer and Fuel's gas pins use `CPO_PingGoHereVariant`, the same
variant as Custom Map Markers, so those two checkboxes can still show each other's pins. Fixing that
needs a change to VehicleMileage's `RegisterGasMappins`; redscript annotations could not resolve
`VMRuntimeSystem` from an external patch (UNRESOLVED_REF), so it is not included.
