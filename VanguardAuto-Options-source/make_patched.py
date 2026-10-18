"""Builds VanguardAuto-Options from the INSTALLED Vanguard Auto files.

Each patch is an exact-match anchor that must occur the expected number of times; if a
Vanguard Auto update moves any anchor the build fails instead of shipping a broken file.
Re-run after updating Vanguard Auto, then reinstall the zip through Vortex.

  python make_patched.py [game_dir] [out_zip]
"""
import re
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
GAME = Path(sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077")
OUT_ZIP = Path(sys.argv[2] if len(sys.argv) > 2 else HERE.parent / "VanguardAuto-Options-v1.3.zip")

SYS = "r6/scripts/VirtualCarDealer/core/CarDealer-System.reds"
CET = "bin/x64/plugins/cyber_engine_tweaks/mods/vanguard_coverage/"
CLM = "r6/scripts/VirtualCarDealer/overrides/ClaimVehiclesCompatibility.reds"
ODO = "bin/x64/plugins/cyber_engine_tweaks/mods/vanguard_auto_odometer/init.lua"
COV = CET + "module/Coverage.lua"
ADA = CET + "module/VanguardAdapter.lua"
DEL = CET + "module/DelamainRepairExemption.lua"


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def lua_guard(fn_signature, body):
    """Insert `body` as the first statement of a Coverage function."""
    return (fn_signature, fn_signature + "\n" + body, 1)


# (anchor, replacement, expected_count). Anchors are literal unless wrapped in re.compile.
PATCHES = {
    SYS: [
        (
            "import CarDealer.Calendar.VanguardAutoCalendar\n",
            "import CarDealer.Calendar.VanguardAutoCalendar\nimport VAO.Settings.VanguardAutoOptions\n",
            1,
        ),
        # Permanent-loss off: destroyed vehicles are no longer reported DESTROYED.
        (
            "  public func IsVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {\n    let i: Int32 = 0;\n",
            "  public func IsVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {\n    let i: Int32 = 0;\n\n"
            "    if !VanguardAutoOptions.PermanentLossEnabled() {\n      return false;\n    };\n",
            1,
        ),
        (
            "  public func MarkVanguardDestroyedVehicleWithoutSettlement(id: TweakDBID) -> Bool {\n    let canonicalID: TweakDBID;\n",
            "  public func MarkVanguardDestroyedVehicleWithoutSettlement(id: TweakDBID) -> Bool {\n    let canonicalID: TweakDBID;\n\n"
            "    if !VanguardAutoOptions.PermanentLossEnabled() {\n      return false;\n    };\n",
            1,
        ),
        (
            "  public func MarkVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {\n",
            "  public func MarkVanguardUninsuredVehicleDestroyed(id: TweakDBID) -> Bool {\n"
            "    if !VanguardAutoOptions.PermanentLossEnabled() && TDBID.IsValid(id) && !this.IsVanguardCoverageVehicleIneligible(id) && !this.IsVanguardCoverageTotalLossLocked(id) {\n"
            "      VanguardAutoOptions.ChargeRestoreFee(this.GetGameInstance(), this.GetVanguardCoverageVehicleValue(id));\n"
            "      return false;\n    };\n",
            1,
        ),
        # Re-acquired models: sold / settled / scrapped models stay on m_soldVehicles and are stripped from the
        # garage on every read, so a car taken by Midnight Acquisition (or any non-Vanguard unlock) vanishes
        # before the exit-vehicle claim hook can clear it. Claim the car the player is sitting in first.
        (
            "  public func DeactivateSoldVehicles() -> Void {\n",
            "  private func IsRecordUnlockedForPlayer(id: TweakDBID) -> Bool {\n"
            "    let unlocked: array<PlayerVehicle>;\n\n"
            "    if !IsDefined(this.m_vehicleSystem) || !TDBID.IsValid(id) {\n      return false;\n    };\n"
            "    this.m_vehicleSystem.GetPlayerUnlockedVehicles(unlocked);\n"
            "    for vehicle in unlocked {\n"
            "      if Equals(vehicle.recordID, id) {\n        return true;\n      };\n"
            "    };\n"
            "    return false;\n"
            "  }\n\n"
            "  // A model that is on the sold list but currently unlocked was re-acquired outside Vanguard (Midnight\n"
            "  // Acquisition, steal, ...). The live entity's IsPlayerVehicle() stays false for those, so test the unlock.\n"
            "  public func ClaimSoldVehicleIfUnlocked(id: TweakDBID) -> Void {\n"
            "    if TDBID.IsValid(id) && ArrayContains(this.m_soldVehicles, id) && this.IsRecordUnlockedForPlayer(id) {\n"
            "      this.MarkExternalVehicleClaimed(id);\n    };\n"
            "  }\n\n"
            "  private func ClaimMountedSoldVehicle() -> Void {\n"
            "    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;\n"
            "    let vehicle: ref<VehicleObject>;\n\n"
            "    if !IsDefined(player) {\n      return;\n    };\n"
            "    vehicle = GetMountedVehicle(player) as VehicleObject;\n"
            "    if !IsDefined(vehicle) || vehicle.GetVehiclePS().GetIsDestroyed() {\n      return;\n    };\n"
            "    this.ClaimSoldVehicleIfUnlocked(vehicle.GetRecordID());\n"
            "  }\n\n"
            "  public func DeactivateSoldVehicles() -> Void {\n",
            1,
        ),
        (
            "    for id in this.m_soldVehicles {\n      RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, id);\n    };\n",
            "    this.ClaimMountedSoldVehicle();\n\n"
            "    for id in this.m_soldVehicles {\n      RemoveVehicle(this.GetGameInstance(), this.m_vehicleSystem, id);\n    };\n",
            1,
        ),
        # Adjudication: the single funnel for every destruction outcome.
        (
            "public func AdjudicateVanguardCoverageDestroyedVehicleWithDiagnostics(id: TweakDBID, coveredAtIncident: Bool, evidenceFresh: Bool, playerDeliberateEvidence: Bool,",
            "public func AdjudicateVanguardCoverageDestroyedVehicleWithDiagnostics(id: TweakDBID, coveredAtIncidentIn: Bool, evidenceFresh: Bool, playerDeliberateEvidenceIn: Bool,",
            1,
        ),
        (
            "    let creditSuppressed: Bool = false;\n\n    this.m_coverageLastAdjudicationClaimCreated = false;\n",
            "    let creditSuppressed: Bool = false;\n"
            "    let coveredAtIncident: Bool = coveredAtIncidentIn && VanguardAutoOptions.TotalLossClaimsActive();\n"
            "    let playerDeliberateEvidence: Bool = playerDeliberateEvidenceIn && VanguardAutoOptions.FraudStrikesActive();\n\n"
            "    this.m_coverageLastAdjudicationClaimCreated = false;\n"
            "    if !VanguardAutoOptions.PermanentLossEnabled() && TDBID.IsValid(id) && !this.IsVanguardCoverageVehicleIneligible(id) && !this.IsVanguardCoverageTotalLossLocked(id) {\n"
            "      VanguardAutoOptions.ChargeRestoreFee(this.GetGameInstance(), this.GetVanguardCoverageVehicleValue(id));\n"
            "      return 3;\n    };\n",
            1,
        ),
    ],
    CLM: [
        # Exit hook: the live entity of a Midnight Acquisition car reports IsPlayerVehicle() == false, so also
        # un-sell the model when it is in the unlocked list.
        (
            "  wrappedMethod(stateContext, scriptInterface);\n\n  if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {\n"
            "    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).MarkExternalVehicleClaimed(vehicle.GetRecordID());\n  };\n}",
            "  wrappedMethod(stateContext, scriptInterface);\n\n  if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {\n"
            "    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).MarkExternalVehicleClaimed(vehicle.GetRecordID());\n  };\n"
            "  if IsDefined(vehicle) {\n"
            "    PurchasableVehicleSystem.GetInstance(vehicle.GetGame()).ClaimSoldVehicleIfUnlocked(vehicle.GetRecordID());\n  };\n}",
            1,
        ),
    ],
    ODO: [
        # VehicleObject:GetVelocity() does not exist in this game version, so every tick threw
        # "attempt to call method 'GetVelocity' (a nil value)" and the standalone odometer never counted a mile.
        # GetCurrentSpeed() (m/s, signed) is what other mods use on the mounted vehicle.
        (
            "    local velocity=vehicle:GetVelocity()\n"
            "    local speed=math.sqrt(velocity.x*velocity.x+velocity.y*velocity.y+velocity.z*velocity.z)\n",
            "    local speed=0\n"
            "    local okSpeed,rawSpeed=pcall(function() return vehicle:GetCurrentSpeed() end)\n"
            "    if okSpeed and type(rawSpeed)=='number' and rawSpeed==rawSpeed then speed=math.abs(rawSpeed) end\n",
            1,
        ),
    ],
    COV: [
        ("local Calendar = require('module/Calendar')\n",
         "local Calendar = require('module/Calendar')\nlocal Opt = require('module/VanguardOptions')\n", 1),
        ("Wallet.remove(due)", "Opt.remove(Wallet, due, 'premium')", 3),
        ("Wallet.remove(deductible)", "Opt.remove(Wallet, deductible, 'deductible')", 1),
        lua_guard("function Coverage.isInsured(vehicleId)", "    if not Opt.insuranceEnabled() then return false end"),
        lua_guard("function Coverage.runInstallAutoEnrollment(force, reason)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.' end"),
        lua_guard("function Coverage.refreshAutoEnrollmentBilling(force)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.' end"),
        lua_guard("function Coverage.handleDrivingAccident(vehicleId, atFault, amount, impactScore, targetType, alreadyPaid, coverageAuthorityConfirmed)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end"),
        lua_guard("function Coverage.repairVehicle(vehicleId, repairFn)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end"),
        lua_guard("function Coverage.confirmPolicy(selection, deductibleOption, billingMode)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end"),
        lua_guard("function Coverage.applyMidtermChange(selection, deductibleOption, billingMode)",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end"),
        lua_guard("function Coverage.payCurrentBill()",
                  "    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end"),
    ],
    ADA: [
        ("local DelamainRepairExemption = require('module/DelamainRepairExemption')\n",
         "local DelamainRepairExemption = require('module/DelamainRepairExemption')\nlocal Opt = require('module/VanguardOptions')\n", 1),
        # Auto-repair off (or insurance off): leave the damaged vehicle alone on summon. Placed after the
        # destroyed / locked checks so destruction routing is unchanged.
        (
            "                elseif Coverage.hasFreshBodyPending and Coverage.hasFreshBodyPending(vehicle.id) == true then\n",
            "                elseif not Opt.insuranceEnabled() or not Opt.autoRepairOnSummon() then\n"
            "                    print('[Vanguard Coverage] summon repair skipped by Mod Settings for ' .. tostring(vehicle.name or vehicle.id))\n"
            "                    table.remove(pendingSummonRepairs, i)\n"
            "                elseif Coverage.hasFreshBodyPending and Coverage.hasFreshBodyPending(vehicle.id) == true then\n",
            1,
        ),
    ],
    DEL: [
        ("local Exemption = {}\n", "local Opt = require('module/VanguardOptions')\nlocal Exemption = {}\n", 1),
        ("local function runWithoutNativeRepairCharge(callback)", "local function runWithoutNativeRepairCharge(callback, multiplier)", 1),
        ("TweakDB:SetFlat(REPAIR_COST_MULTIPLIER_FLAT, 0.0)", "TweakDB:SetFlat(REPAIR_COST_MULTIPLIER_FLAT, previous * (multiplier or 0.0))", 1),
        # Non-Delamain summons: scale the native repair fee by the Mod Settings percentage.
        (
            re.compile(r"(if not Exemption\.isDelamainVehicleId\(vehicleId\) then)(\s+)return wrapped\(vehicleType, vehicleId, spawnOnlyOnValidRoad\)"),
            lambda m: m.group(1) + m.group(2)
            + "local scale = Opt.summonRepairFeeMultiplier()" + m.group(2)
            + "if scale == 1.0 then return wrapped(vehicleType, vehicleId, spawnOnlyOnValidRoad) end" + m.group(2)
            + "return runWithoutNativeRepairCharge(function() return wrapped(vehicleType, vehicleId, spawnOnlyOnValidRoad) end, scale)",
            1,
        ),
        (
            re.compile(r"(if not Exemption\.isDelamainVehicleId\(vehicleId\) then)(\s+)return wrapped\(vehicleType\)"),
            lambda m: m.group(1) + m.group(2)
            + "local scale = Opt.summonRepairFeeMultiplier()" + m.group(2)
            + "if scale == 1.0 then return wrapped(vehicleType) end" + m.group(2)
            + "return runWithoutNativeRepairCharge(function() return wrapped(vehicleType) end, scale)",
            1,
        ),
    ],
}


def eol_at(text, pos):
    """Line ending used where the match ends (the Lua files mix LF and CRLF)."""
    nl = text.find("\n", pos)
    return "\r\n" if nl > 0 and text[nl - 1] == "\r" else "\n"


def literal_to_regex(anchor):
    parts = anchor.split("\n")
    return re.compile(r"\r?\n".join(re.escape(p) for p in parts))


def apply(path, patches):
    text = (GAME / path).read_bytes().decode("utf-8")
    for anchor, repl, expected in patches:
        if not isinstance(anchor, re.Pattern):
            anchor = literal_to_regex(anchor)
        matches = list(anchor.finditer(text))
        if len(matches) != expected:
            sys.exit(f"{path}: anchor {anchor.pattern[:70]!r} matched {len(matches)}x, expected {expected}")
        pieces, last = [], 0
        for m in matches:
            eol = eol_at(text, m.start())
            r = repl(m) if callable(repl) else repl
            pieces.append(text[last:m.start()])
            pieces.append(r.replace("\r\n", "\n").replace("\n", eol))
            last = m.end()
        pieces.append(text[last:])
        text = "".join(pieces)
    return text


def main():
    out = {}
    for path, patches in PATCHES.items():
        out[path] = apply(path, patches).encode("utf-8")
        print(f"patched {path}")

    # New files shipped as-is.
    for rel in ("r6/scripts/VanguardAutoOptions/VanguardAutoOptions.reds", CET + "module/VanguardOptions.lua"):
        out[rel] = (HERE / rel).read_bytes()

    for rel, data in out.items():
        dest = HERE / "build" / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)

    OUT_ZIP.unlink(missing_ok=True)
    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, data in out.items():
            z.writestr(rel, data)
    print(f"wrote {OUT_ZIP} ({len(out)} files)")


if __name__ == "__main__":
    main()
