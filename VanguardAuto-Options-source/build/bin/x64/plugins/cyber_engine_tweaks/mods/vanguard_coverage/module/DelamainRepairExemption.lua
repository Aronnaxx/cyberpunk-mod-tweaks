local Opt = require('module/VanguardOptions')
local Exemption = {}

local REPAIR_COST_MULTIPLIER_FLAT = 'Vehicle.summon_setup.repairCostMultiplier'
local DELAMAIN_RECORDS = {
    'Vehicle.v_delamain_taxi',
    'Vehicle.v_standard2_villefort_cortes_delamain',
    'Vehicle.v_standard2_villefort_cortes_delamain_taxi',
    'Vehicle.v_standard2_villefort_cortes_delamain_player',
}

local directOverrideInstalled = false
local activeOverrideInstalled = false
local knownRecordIds = nil

local function safeString(value)
    return tostring(value or ''):gsub('[\r\n]+', ' '):gsub('%s+', ' ')
end

local function recordIdString(value)
    local out = nil
    pcall(function()
        if TDBID and TDBID.ToStringDEBUG then
            out = TDBID.ToStringDEBUG(value)
        end
    end)
    if not out or out == '' then out = safeString(value) end
    return safeString(out)
end

local function buildKnownRecordIds()
    if knownRecordIds ~= nil then return knownRecordIds end

    knownRecordIds = {}
    if not TweakDBID or not TweakDBID.new then return knownRecordIds end

    for _, recordName in ipairs(DELAMAIN_RECORDS) do
        pcall(function()
            knownRecordIds[#knownRecordIds + 1] = TweakDBID.new(recordName)
        end)
    end
    return knownRecordIds
end

function Exemption.isDelamainVehicleId(value)
    if value == nil then return false end

    local key = recordIdString(value):lower()
    if key:find('delamain', 1, true) then return true end

    for _, knownId in ipairs(buildKnownRecordIds()) do
        local equal = false
        pcall(function() equal = value == knownId end)
        if equal then return true end
    end

    return false
end

local function runWithoutNativeRepairCharge(callback, multiplier)
    if not TweakDB or not TweakDB.GetFlat or not TweakDB.SetFlat then
        return callback()
    end

    local previous = nil
    local readOk = pcall(function()
        previous = TweakDB:GetFlat(REPAIR_COST_MULTIPLIER_FLAT)
    end)
    if not readOk or type(previous) ~= 'number' then
        return callback()
    end

    local disabled = pcall(function()
        TweakDB:SetFlat(REPAIR_COST_MULTIPLIER_FLAT, previous * (multiplier or 0.0))
    end)
    if not disabled then return callback() end

    local result = table.pack(pcall(callback))
    local restored, restoreError = pcall(function()
        TweakDB:SetFlat(REPAIR_COST_MULTIPLIER_FLAT, previous)
    end)
    if not restored then
        print('[Vanguard Coverage] failed to restore summon repair multiplier: ' .. safeString(restoreError))
    end

    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

local function activeVehicleRecordId(vehicleSystem, vehicleType)
    local recordId = nil
    pcall(function()
        local vehicle = vehicleSystem:GetActivePlayerVehicle(vehicleType)
        if vehicle then recordId = vehicle.recordID end
    end)
    return recordId
end

function Exemption.install()
    if directOverrideInstalled and activeOverrideInstalled then return true end
    if type(Override) ~= 'function' then return false end

    if not directOverrideInstalled then
        directOverrideInstalled = pcall(function()
            Override('VehicleSystem', 'SpawnPlayerVehicle', function(_, vehicleType, vehicleId, spawnOnlyOnValidRoad, wrapped)
                if not Exemption.isDelamainVehicleId(vehicleId) then
                    local scale = Opt.summonRepairFeeMultiplier()
                    if scale == 1.0 then return wrapped(vehicleType, vehicleId, spawnOnlyOnValidRoad) end
                    return runWithoutNativeRepairCharge(function() return wrapped(vehicleType, vehicleId, spawnOnlyOnValidRoad) end, scale)
                end

                print('[Vanguard Coverage] Delamain summon detected; native repair charge suppressed')
                return runWithoutNativeRepairCharge(function()
                    return wrapped(vehicleType, vehicleId, spawnOnlyOnValidRoad)
                end)
            end)
        end)
    end

    if not activeOverrideInstalled then
        activeOverrideInstalled = pcall(function()
            Override('VehicleSystem', 'SpawnActivePlayerVehicle', function(this, vehicleType, wrapped)
                local vehicleId = activeVehicleRecordId(this, vehicleType)
                if not Exemption.isDelamainVehicleId(vehicleId) then
                    local scale = Opt.summonRepairFeeMultiplier()
                    if scale == 1.0 then return wrapped(vehicleType) end
                    return runWithoutNativeRepairCharge(function() return wrapped(vehicleType) end, scale)
                end

                print('[Vanguard Coverage] active Delamain summon detected; native repair charge suppressed')
                return runWithoutNativeRepairCharge(function()
                    return wrapped(vehicleType)
                end)
            end)
        end)
    end

    if directOverrideInstalled and activeOverrideInstalled then
        print('[Vanguard Coverage] installed Delamain native summon repair-charge exemption')
    elseif directOverrideInstalled or activeOverrideInstalled then
        print('[Vanguard Coverage] partially installed Delamain native summon repair-charge exemption; missing hook will retry')
    else
        print('[Vanguard Coverage] failed to install Delamain native summon repair-charge exemption')
    end

    return directOverrideInstalled and activeOverrideInstalled
end

return Exemption
