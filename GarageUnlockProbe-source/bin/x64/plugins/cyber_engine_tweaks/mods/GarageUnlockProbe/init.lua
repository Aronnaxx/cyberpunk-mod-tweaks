-- GarageUnlockProbe v1.0 (temporary diagnostic, remove when done)
-- Finds what removes a vehicle from the player's garage (unlocked list) after Midnight Acquisition etc.
--  * hooks VehicleSystem.EnablePlayerVehicle / EnablePlayerVehicleID / DisablePlayerVehicle and logs every call
--    with enable=false (and the Lua call stack, which names the mod's file) plus enable=true for correlation
--  * once a second compares V's unlocked list with the previous one and logs every vehicle added / removed
-- Output: GarageUnlockProbe.log in this folder + CET console. Lines start with [GUP].

local t, acc = 0, 0
local prev, havePrev = {}, false

local function log(msg)
  local line = string.format("[GUP %8.1fs] %s", t, msg)
  print(line)
  spdlog.info(line)
end

local function try(fn, dflt)
  local ok, r = pcall(fn)
  if ok and r ~= nil then return r end
  return dflt
end

local function idStr(v)
  if type(v) == "string" then return v end
  return try(function() return TDBID.ToStringDEBUG(v) end, tostring(v))
end

-- Lua frames above the hook = the code that made the call (CET runs the observer inside the caller's call).
local function callers()
  local out = {}
  for level = 3, 14 do
    local info = try(function() return debug.getinfo(level, "Sl") end, nil)
    if not info then break end
    local src = tostring(info.short_src or info.source or "?"):gsub("\\", "/")
    local mod = src:match("mods/([^/]+)/") or src
    out[#out + 1] = string.format("%s:%s", mod, tostring(info.currentline))
  end
  if #out == 0 then return "(no Lua frames: called from redscript/native)" end
  return table.concat(out, " < ")
end

local function mountedRecord()
  return try(function()
    local p = Game.GetPlayer()
    if not p then return "no player" end
    local v = Game.GetMountedVehicle(p)
    if not v then return "on foot" end
    return "in " .. idStr(v:GetRecordID())
  end, "?")
end

local function snapshot()
  local set, list = {}, try(function() return Game.GetVehicleSystem():GetPlayerUnlockedVehicles() end, nil)
  if not list then return nil end
  for _, v in ipairs(list) do set[idStr(v.recordID)] = true end
  return set
end

local function hook(name, argsFn)
  local ok = pcall(function()
    Observe("VehicleSystem", name, function(self, ...)
      local a, b = argsFn(...)
      log(string.format("%s(%s) [%s] by %s", name, a, mountedRecord(), callers()))
    end)
  end)
  if not ok then log("could not hook VehicleSystem." .. name) end
end

registerForEvent("onInit", function()
  hook("EnablePlayerVehicle", function(id, enable, persistent)
    return string.format("%s, enable=%s, despawn/persist=%s", idStr(id), tostring(enable), tostring(persistent))
  end)
  hook("EnablePlayerVehicleID", function(id, enable, persistent)
    return string.format("%s, enable=%s, despawn/persist=%s", idStr(id), tostring(enable), tostring(persistent))
  end)
  hook("DisablePlayerVehicle", function(id)
    return idStr(id)
  end)
  log("probe loaded; hooks installed")
end)

registerForEvent("onUpdate", function(dt)
  t = t + dt
  acc = acc + dt
  if acc < 1.0 then return end
  acc = 0
  local now = snapshot()
  if not now then return end
  if havePrev then
    for id in pairs(now) do
      if not prev[id] then log("UNLOCKED   " .. id .. " [" .. mountedRecord() .. "]") end
    end
    for id in pairs(prev) do
      if not now[id] then log("REMOVED    " .. id .. " [" .. mountedRecord() .. "]") end
    end
  else
    local n = 0
    for _ in pairs(now) do n = n + 1 end
    log(string.format("start: %d unlocked vehicles", n))
  end
  prev, havePrev = now, true
end)
