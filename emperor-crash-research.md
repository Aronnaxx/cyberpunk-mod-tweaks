# Police Emperor load crash: research (2026-10-04)

Crash (3x: 12:19, 15:23, 17:37, always while loading a save near [-1510..-1539, 1209..1473]):
`TweakDB::Val<DynArray<CName>>` <- `SimpleOccupantSlotSpawner::PrepareOccupantsConfig`, objects
`gamedataRandomPassengerEntry_Record` / `VehicleSeatSet` / `Vehicle`, entity
`base\vehicles\standard\v_standard3_chevalier_emperor_01__police_01.ent` (replaced by `ncpd_fleet.archive`).

Full grep of every "emperor" line in the police/traffic mods: `emperor-lines-all-mods.txt` (327 lines).

## Records that spawn THIS entity (police_01.ent, appearance chevalier_emperor__basic_police)

| Record | Defined by | File:line | Parent |
|---|---|---|---|
| `v_standard3_chevalier_emperor_police` | base game | - | - |
| `vcd_chevalier_emperor_ncpd` | Night City Fleet Expansion (25965) | `r6/tweaks/ash/NCPD Fleet/chevalier_emperor_ncpd.yaml:6-8` | `v_standard3_chevalier_emperor_police` |
| `leo_ncpd_chevalier_emperor_heat_3` | Law Enforcement Overhaul (via Factions Evolved LEO Reset) | `r6/tweaks/Law Enforcement Overhaul/prevention_vehicles.tweak:230` | `v_standard3_chevalier_emperor_police` |
| `leo_ncpd_chevalier_emperor_heat_4` | LEO | `prevention_vehicles.tweak:242` | **`vcd_chevalier_emperor_ncpd` (NCPD Fleet's record)** |
| `leo_ncpd_chevalier_emperor_heat_5` | LEO | `prevention_vehicles.tweak:247` | `leo_ncpd_chevalier_emperor_heat_4` |
| `ncpd_suv_chevalier_emperor_heat_4` | NCPD Prevention Police Enhancement 2.7 (REDmod, 9863) | `mods/NCPD Prevention Police Enhancement/tweaks/.../vehicles/prevention_vehicles.tweak:221` | `v_standard3_chevalier_emperor_police` |
| `ncpd_suv_chevalier_emperor_heat_2_City_Center` | NCPDPPE | same file `:105` | `v_standard3_chevalier_emperor_police` |

## Same record defined twice with different parents

`Vehicle.v_standard3_chevalier_emperor_police_prevention` (the police Emperor used by the game's prevention system):

- LEO `prevention_vehicles.tweak:1581`: `v_standard3_chevalier_emperor_police_prevention : leo_ncpd_chevalier_emperor_heat_3`
- NCPDPPE `prevention_vehicles.tweak:562`: `v_standard3_chevalier_emperor_police_prevention : ncpd_suv_chevalier_emperor_heat_4`

Both also replace the prevention spawn tables (`preventiondata.tweak`): LEO lines 85-3235, NCPDPPE lines 153-2051.
Whichever loads last wins, so the record's passenger setup depends on load order.
NCTO additionally filters this record out of traffic (`r6/scripts/NightCityTrafficOverhaul/NCTO.reds:439`).

## Passenger-related edits

- NCTO `r6/tweaks/NightCityTrafficOverhaul/NCPD.yaml:34-39`: `Vehicle.police__chevalier_emperor` ($base police Emperor, own `.ent`, `randomPassengers: [Passengers.policeEnforcerDriverEntry, ...FrontEntry, ...BackEntry]`); entries defined at lines 212-259 (TweakXL-created RandomPassengerEntry records).
- NCA 2.3 `r6/tweaks/NightCityAlive/vehicles/emperor.yml:1-7`: base `Vehicle.v_standard3_chevalier_emperor.randomPassengers` removes `Passengers.Corporat*Entry`, appends `Passengers.Premium*Entry` (defined in `NightCityAlive/passengers/cdpr-to-low.yml:306-332`). Deployed 17:52, after all three crashes.
- LEO / NCPDPPE police Emperors set `preventionPassengers` + min/max counts (LEO 3-4, NCPDPPE 4).

## Online (Nexus posts / bugs, web)

- No public report of this exact signature (SimpleOccupantSlotSpawner / RandomPassengerEntry).
- LEO (10135) posts: several "CTD on reload / load save" reports, one with Factions Evolved + fleet add-ons; bug "Possibly conflicting with Night City Alive causes CTD" (2 May 2026, open). Mod last updated 2024.
- NCTO (25552) description lists original LEO as incompatible (hard-coded spawns) and recommends LEO Reset (26045, installed). Troubleshooting: crash on load/entering an area = a vehicle in its lists that cannot spawn in traffic.
- NCPDPPE (9863) posts: "load a save and the game crashes" with this mod (x2).
- NCA (10395) 2.3 changelog: "Removed gang members spawning inside police cars", fixed a reload crash. Factions Evolved posts: NCTO author recommends NCA only with NCA passenger/vehicle spawning disabled.
