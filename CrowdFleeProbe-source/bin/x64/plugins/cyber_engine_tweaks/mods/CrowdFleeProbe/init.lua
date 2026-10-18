-- CrowdFleeProbe v1.4 (temporary diagnostic, remove when done)
-- Logs who starts crowd fear: every stim that reaches a crowd NPC's HandleCrowdReaction and every
-- fear area (CreateFearArea, phase 2 = cower, 3 = flee) is grouped by stim type + source object.
-- For each group: how many NPCs got it, the source (class, record, appearance, player / vehicle /
-- driver), its distance to V, the stim radius, and V's state (on foot / driving / passenger, combat,
-- weapon out). Same group is repeated at most every 5 s with the running count.
-- Hotkey "Mark: crowd just ran" writes a marker line so the log can be matched to what you saw.
-- Output: CrowdFleeProbe.log in this folder + CET console.

local t, flushT = 0, 0
local errCount, seen = 0, {}
local pending, lastLogged = {}, {}

local function log(msg)
  local line = string.format("[CFP %8.1fs] %s", t, msg)
  print(line)
  -- CET owns CrowdFleeProbe.log (per-mod logger), so write through it; io.open on it stays empty.
  spdlog.info(line)
end

local function try(fn, dflt)
  local ok, r = pcall(fn)
  if ok and r ~= nil then return r end
  return dflt
end

local function idStr(tdbid)
  return try(function() return TDBID.ToStringDEBUG(tdbid) end, "?")
end

local function nameStr(cn)
  return try(function() return Game.NameToString(cn) end, "?")
end

local function dist(a, b)
  return try(function() return Vector4.Distance(a, b) end, -1)
end

local function vState()
  return try(function()
    local p = Game.GetPlayer()
    local s = {}
    local veh = Game.GetMountedVehicle(p)
    if veh then
      local driver = try(function() return veh:IsPlayerDriver() end, false)
      s[#s + 1] = (driver and "driving " or "passenger in ") .. idStr(veh:GetRecordID())
    else
      s[#s + 1] = "on foot"
    end
    if try(function() return p:IsInCombat() end, false) then s[#s + 1] = "COMBAT" end
    local w = GameObject.GetActiveWeapon(p)
    if w then s[#s + 1] = "weapon " .. idStr(w:GetItemID().id) end
    return table.concat(s, ", ")
  end, "?")
end

local function describeSource(obj)
  if not obj then return "nil source", "nil" end
  return try(function()
    local p = Game.GetPlayer()
    local parts = { nameStr(obj:GetClassName()) }
    if obj:IsPlayer() then parts[#parts + 1] = "PLAYER" end
    local rec = try(function() return idStr(obj:GetRecordID()) end, nil)
    if rec then parts[#parts + 1] = rec end
    local app = try(function() return nameStr(obj:GetCurrentAppearanceName()) end, nil)
    if app and app ~= "None" then parts[#parts + 1] = "app=" .. app end
    if obj:IsVehicle() then
      if try(function() return obj:IsPlayerDriver() end, false) then parts[#parts + 1] = "V driving" end
      if try(function() return obj:IsPlayerMounted() end, false) then parts[#parts + 1] = "V inside" end
    end
    if try(function() return obj:IsDead() end, false) then parts[#parts + 1] = "dead" end
    local d = dist(obj:GetWorldPosition(), p:GetWorldPosition())
    parts[#parts + 1] = string.format("%.0fm from V", d)
    return table.concat(parts, " ")
  end, "unreadable source"), try(function() return tostring(obj:GetEntityID().hash) end, "?")
end

local function note(kind, this, stimEvent, phase)
  local stim = try(function() return tostring(stimEvent:GetStimType()) end, "?")
  stim = stim:gsub("gamedataStimType%.", "")
  local src, srcKey = describeSource(try(function() return stimEvent.sourceObject end, nil))
  local key = kind .. "|" .. stim .. "|" .. srcKey .. "|" .. tostring(phase or "")
  local e = pending[key]
  if not e then
    e = { kind = kind, stim = stim, src = src, phase = phase, n = 0, total = 0,
          radius = try(function() return stimEvent.radius end, -1),
          npcDist = 0 }
    pending[key] = e
  end
  e.n = e.n + 1
  local owner = try(function() return this:GetOwner() end, nil)
  if owner then
    local d = dist(owner:GetWorldPosition(), Game.GetPlayer():GetWorldPosition())
    if d > e.npcDist then e.npcDist = d end
  end
end

local function flush()
  for key, e in pairs(pending) do
    local L = lastLogged[key]
    local total = (L and L.total or 0) + e.n
    if not L or t - L.t >= 5 then
      log(string.format("%s stim=%s%s npcs=%d (total %d) radius=%.0f farthestNPC=%.0fm | SOURCE: %s | V: %s",
        e.kind, e.stim, e.phase and (" phase=" .. e.phase) or "", e.n + (L and L.unlogged or 0), total,
        e.radius or -1, e.npcDist, e.src, vState()))
      lastLogged[key] = { t = t, total = total, unlogged = 0 }
    else
      L.total = total
      L.unlogged = (L.unlogged or 0) + e.n
    end
  end
  pending = {}
end

local function guarded(kind, fn, ...)
  if not seen[kind] then seen[kind] = true; log("hook alive: first " .. kind .. " event seen") end
  local ok, err = pcall(fn, ...)
  if not ok and errCount < 5 then errCount = errCount + 1; log("ERROR in " .. kind .. ": " .. tostring(err)) end
end

-- v1.4: who turns hostile on V while V is not in combat, and through which game function.
local hostSeen = {}
local function noteHostile(path, owner, target)
  if not owner or not target then return end
  if not try(function() return target:IsPlayer() end, false) then return end
  local p = Game.GetPlayer()
  if try(function() return p:IsInCombat() end, false) then return end
  local id = try(function() return tostring(owner:GetEntityID().hash) end, "?")
  local k = path .. id
  if hostSeen[k] and t - hostSeen[k] < 10 then return end
  hostSeen[k] = t
  local att = try(function()
    return tostring(owner:GetAttitudeAgent():GetAttitudeTowards(p:GetAttitudeAgent()))
  end, "?")
  local grp = try(function() return nameStr(owner:GetAttitudeAgent():GetAttitudeGroup()) end, "?")
  log("HOSTILE via " .. path .. ": " .. tostring((describeSource(owner))) .. " entity=" .. id ..
      " attitudeNow=" .. att .. " group=" .. grp .. " | V: " .. vState())
end

registerForEvent("onInit", function()
  log("---- launch (v1.4) ----")
  Observe("AIActionHelper", "TryChangingAttitudeToHostile", function(owner, target)
    guarded("hostile", noteHostile, "TryChangingAttitudeToHostile", owner, target)
  end)
  Observe("GameObject", "ChangeAttitudeToHostile", function(owner, target)
    guarded("hostile", noteHostile, "ChangeAttitudeToHostile", owner, target)
  end)
  Observe("AIActionHelper", "TryStartCombatWithTarget", function(owner, target)
    guarded("hostile", noteHostile, "TryStartCombatWithTarget", owner, target)
  end)
  Observe("TargetTrackingExtension", "InjectThreat", function(puppet, threat)
    guarded("hostile", noteHostile, "InjectThreat", puppet, threat)
  end)
  Observe("PlayerPuppet", "OnCombatStateChanged", function(this, newState)
    log("V combat state -> " .. tostring(newState) .. " | V: " .. vState())
  end)
  Observe("PlayerPuppet", "OnGameAttached", function() log("player attached (load)") end)
  Observe("ReactionManagerComponent", "HandleCrowdReaction", function(this, stimEvent)
    guarded("crowdStim", note, "crowdStim", this, stimEvent, nil)
  end)
  Observe("ReactionManagerComponent", "CreateFearArea", function(this, stimEvent, fearPhase)
    if fearPhase and fearPhase >= 2 then guarded("FEAR", note, "FEAR", this, stimEvent, fearPhase) end
  end)
end)

local function doMark()
  log("hotkey: mark pressed")
  guarded("flush", flush)
  log("======== MARK: Ethan saw the crowd run ======== V: " .. vState())
end

-- v1.2: "Identify what I'm looking at" - record, class, appearance, entity template, position, persistence.
local function doIdentify()
  log("hotkey: identify pressed")
  local p = Game.GetPlayer()
  local obj = try(function() return Game.GetTargetingSystem():GetLookAtObject(p, false, false) end, nil)
  if not obj then log("IDENTIFY: nothing under the crosshair"); return end
  local desc = describeSource(obj)
  local tpl = try(function() return tostring(obj:GetTemplatePath().hash) end, "?")
  local pos = try(function()
    local v = obj:GetWorldPosition()
    return string.format("%.1f %.1f %.1f", v.x, v.y, v.z)
  end, "?")
  local ent = try(function() return EntityID.ToDebugString(obj:GetEntityID()) end, "?")
  log("IDENTIFY: " .. tostring(desc) .. " | entity=" .. ent .. " templateHash=" .. tpl .. " pos=" .. pos .. " | V: " .. vState())
end

registerHotkey("CrowdFleeProbe_mark", "Mark: crowd just ran", function() guarded("mark", doMark) end)
registerHotkey("CrowdFleeProbe_identify", "Identify what I'm looking at", function() guarded("identify", doIdentify) end)
-- Console fallback (CET console): CFP.mark()  /  CFP.identify()
CFP = { mark = function() guarded("mark", doMark) end, identify = function() guarded("identify", doIdentify) end }

registerForEvent("onUpdate", function(dt)
  t = t + dt
  if t - flushT >= 1 then flushT = t; guarded("flush", flush) end
end)
