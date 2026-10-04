local PURCHASE_FACT = "yaiba_penthouse"
local MARKER_TDBID = "FastTravelPoints.yaibaPenthouse"
local MARKER_BASE = "FastTravelPoints.bls_nth_dataterm_01"
local MARKER_DISPLAY_NAME = "LocKey#48329170583926"
local MARKER_DISTRICT = "Districts.Watson"

local ENABLE_MARKER = true
local MARKER_SETTLE_FRAMES = 30

local markerPending = false
local markerCountdown = 0
local markerDone = false

local bathtub = require("bathtub")
local lampShades = require("lampShades")
local candleLights = require("candleLights")

local function log(msg)
    print("[yaiba_purchase_marker] " .. tostring(msg))
end

local function getFactValue(name)
    if Game and type(Game.GetFact) == "function" then
        local ok, value = pcall(Game.GetFact, name)
        if ok and value ~= nil then
            return value
        end
    end
    return 0
end

local function markerExists()
    local id = TweakDBID.new(MARKER_TDBID)
    return TweakDB:GetRecord(id) ~= nil
end

local function setFlat(field, value)
    local ok, err = pcall(function() TweakDB:SetFlat(field, value) end)
    if not ok then
        log("SetFlat failed for " .. field .. ": " .. tostring(err))
    end
end

local function createMarker()
    local baseId = TweakDBID.new(MARKER_BASE)

    if TweakDB:GetRecord(baseId) == nil then
        log("Base record does not exist: " .. MARKER_BASE)
        return
    end

    local ok, err = pcall(function() TweakDB:CloneRecord(MARKER_TDBID, baseId) end)
    if not ok then
        log("CloneRecord failed for " .. MARKER_TDBID .. ": " .. tostring(err))
        return
    end

    setFlat(MARKER_TDBID .. ".displayName", MARKER_DISPLAY_NAME)
    setFlat(MARKER_TDBID .. ".district", TweakDBID.new(MARKER_DISTRICT))
    setFlat(MARKER_TDBID .. ".showInWorld", 1)
    setFlat(MARKER_TDBID .. ".showOnWorldMap", 1)
    setFlat(MARKER_TDBID .. ".SubwayStation", 0)

    log("Created marker record " .. MARKER_TDBID)
end

local function syncVisibility(visible)
    local v = visible and 1 or 0
    setFlat(MARKER_TDBID .. ".showInWorld", v)
    setFlat(MARKER_TDBID .. ".showOnWorldMap", v)
    log("Set marker visibility to " .. tostring(visible))
end

local function processMarker()
    local purchased = getFactValue(PURCHASE_FACT) == 1

    if not markerExists() then
        if not purchased then
            log("Fact not set and no record; nothing to do")
            return
        end
        createMarker()
        return
    end

    syncVisibility(purchased)
end

registerForEvent("onInit", function()
    bathtub.init()
    lampShades.init()
    candleLights.init()

    Observe('PlayerPuppet', 'OnGameAttached', function()
        bathtub.onSessionStart()
        lampShades.onSessionStart()
        candleLights.onSessionStart()

        markerPending = true
        markerCountdown = MARKER_SETTLE_FRAMES
        markerDone = false
    end)
end)

local cleanFarAcc = 0 -- [CET-Cleans]
registerForEvent("onUpdate", function(dt)
    local player = GetPlayer()
    local ppos = player and player:GetWorldPosition() or nil
    -- [CET-Cleans] penthouse props update every frame within 150 m, twice a second elsewhere
    local far = ppos and ((ppos.x + 1160.27) ^ 2 + (ppos.y - 1579.75) ^ 2 + (ppos.z - 75.74) ^ 2) > 22500
    cleanFarAcc = cleanFarAcc + (dt or 0)
    if not far or cleanFarAcc >= 0.5 then
        cleanFarAcc = 0
        bathtub.update(player, ppos)
        lampShades.update(player)
        candleLights.update()
    end

    if ENABLE_MARKER and markerPending and not markerDone then
        if markerCountdown > 0 then
            markerCountdown = markerCountdown - 1
        else
            markerPending = false
            markerDone = true
            local ok, err = pcall(processMarker)
            if not ok then
                log("processMarker error: " .. tostring(err))
            end
        end
    end
end)
