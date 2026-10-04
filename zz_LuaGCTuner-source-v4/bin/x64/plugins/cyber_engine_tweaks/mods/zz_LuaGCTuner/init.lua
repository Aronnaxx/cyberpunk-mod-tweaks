-- zz_LuaGCTuner v4.0 "menu-time cleanup"
-- v4: (1) finishes the cleanup in ONE pause: CET userdata with finalizers are only freed on the
--     following cycle, so a second pass runs right away when the first leaves the heap well above
--     the live set. (2) skips cleanups unless the heap grew >= 64 MB since the last one.
-- Stops CET's Lua garbage collector from running during gameplay and does the full cleanup
-- where the stall is invisible: game paused (map, inventory, pause menu, journal, photo mode),
-- CET overlay open, or no player (loading). A hard cap resumes normal background GC.
-- Configure in: CET overlay window "Lua GC Tuner", or game Settings > MODS > Lua GC Tuner.

local DEFAULTS = {
  enabled         = true,   -- false = vanilla Lua GC behaviour
  menuCollectMB   = 150,    -- in a pause/menu, clean up if Lua holds more than this
  hardCapMB       = 10240,  -- above this, background GC resumes even in gameplay (LuaJIT is GC64: no 2 GB limit)
  logCleanups     = true,   -- print each cleanup to the CET console
}
local CHECK_EVERY_S = 0.5
local MIN_GROWTH_MB = 64      -- v4: no cleanup unless the heap grew this much since the last one
local liveMB = nil           -- v4: smallest post-cleanup heap seen = estimate of live data
local SETTINGS_FILE = "settings.json"

local cfg = {}
for k, v in pairs(DEFAULTS) do cfg[k] = v end

local acc, capMode = 0, false
local lastStamp, frozenFor = nil, 0
local stats = { count = 0, lastReason = "-", lastBefore = 0, lastAfter = 0, lastMs = 0 }

local function heapMB() return collectgarbage("count") / 1024 end

local function save()
  local ok, err = pcall(function()
    local f = io.open(SETTINGS_FILE, "w")
    if f then f:write(json.encode(cfg)); f:close() end
  end)
  if not ok then print("[LuaGCTuner] could not save settings: " .. tostring(err)) end
end

local function load()
  pcall(function()
    local f = io.open(SETTINGS_FILE, "r")
    if not f then return end
    local data = json.decode(f:read("*a")); f:close()
    if type(data) == "table" then
      for k, v in pairs(data) do if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then cfg[k] = v end end
    end
  end)
end

local function applyMode()
  if cfg.enabled then
    collectgarbage("stop"); capMode = false
  else
    collectgarbage("restart")
  end
end

local function fullCollect(reason)
  local before, t0 = heapMB(), os.clock()
  collectgarbage("collect")
  local mid = heapMB()
  -- v4: finalizer-held objects are released on the next cycle; finish in this same pause
  if liveMB == nil or mid > liveMB * 1.3 + 32 then
    collectgarbage("collect")
  end
  if cfg.enabled and not capMode then collectgarbage("stop") end
  local after, ms = heapMB(), (os.clock() - t0) * 1000
  if liveMB == nil or after < liveMB then liveMB = after end
  stats.count = stats.count + 1
  stats.lastReason, stats.lastBefore, stats.lastAfter, stats.lastMs = reason, before, after, ms
  if cfg.logCleanups then
    print(string.format("[LuaGCTuner] %s: %.0f MB -> %.0f MB -> %.0f MB in %.0f ms (live ~%.0f MB)", reason, before, mid, after, ms, liveMB))
  end
end

local function isPaused(dt)
  local st = nil
  pcall(function() st = Game.GetTimeSystem():GetGameTimeStamp() end)
  if st ~= nil then
    if lastStamp ~= nil and st == lastStamp then frozenFor = frozenFor + dt else frozenFor = 0 end
    lastStamp = st
    if frozenFor >= 0.4 then return true end
  end
  local paused = false
  pcall(function() paused = Game.GetTimeSystem():IsPausedState() end)
  return paused
end

local function noPlayer()
  local p = nil
  pcall(function() p = Game.GetPlayer() end)
  return p == nil
end

-- Game Settings > MODS page (Native Settings UI), if installed
local function buildNativeSettings()
  local ns = GetMod("nativeSettings")
  if not ns then return end
  local tab = "/LuaGCTuner"
  if not ns.pathExists(tab) then ns.addTab(tab, "Lua GC Tuner") end
  local sub = tab .. "/main"
  ns.addSubcategory(sub, "Lua memory cleanup")
  ns.addSwitch(sub, "Enabled", "ON: no Lua cleanup during gameplay, clean up in menus instead. OFF: vanilla behaviour.",
    cfg.enabled, DEFAULTS.enabled, function(v) cfg.enabled = v; applyMode(); save() end)
  ns.addRangeInt(sub, "Menu cleanup threshold (MB)", "When paused or in a menu, clean up if Lua holds more than this.",
    50, 2000, 50, cfg.menuCollectMB, DEFAULTS.menuCollectMB, function(v) cfg.menuCollectMB = v; save() end)
  ns.addRangeInt(sub, "Hard cap (MB)", "Safety net: above this, normal background cleanup resumes during gameplay until the next menu.",
    512, 16384, 512, cfg.hardCapMB, DEFAULTS.hardCapMB, function(v) cfg.hardCapMB = v; save() end)
  ns.addSwitch(sub, "Log cleanups to console", "Print a line in the CET console for each cleanup.",
    cfg.logCleanups, DEFAULTS.logCleanups, function(v) cfg.logCleanups = v; save() end)
end

registerForEvent("onInit", function()
  load()
  applyMode()
  buildNativeSettings()
  print(string.format("[LuaGCTuner v4.0] %s; menu cleanup >%d MB, hard cap %d MB, heap %.0f MB",
    cfg.enabled and "background GC stopped" or "DISABLED (vanilla GC)", cfg.menuCollectMB, cfg.hardCapMB, heapMB()))
end)

local overlayOpen = false
registerForEvent("onOverlayOpen", function()
  overlayOpen = true
  if cfg.enabled and heapMB() > cfg.menuCollectMB then fullCollect("CET overlay") end
end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

-- CET overlay window
registerForEvent("onDraw", function()
  if not overlayOpen then return end
  if ImGui.Begin("Lua GC Tuner", ImGuiWindowFlags.AlwaysAutoResize) then
    ImGui.Text(string.format("Lua heap: %.0f MB   %s", heapMB(),
      not cfg.enabled and "(vanilla GC)" or (capMode and "(hard cap: background GC running)" or "(background GC parked)")))
    ImGui.Text(string.format("Cleanups: %d   last: %s, %.0f -> %.0f MB in %.0f ms",
      stats.count, stats.lastReason, stats.lastBefore, stats.lastAfter, stats.lastMs))
    ImGui.Separator()
    local changed
    local v, c = ImGui.Checkbox("Enabled", cfg.enabled)
    if c then cfg.enabled = v; applyMode(); changed = true end
    ImGui.PushItemWidth(220)
    local m, c2 = ImGui.SliderInt("Menu cleanup threshold (MB)", cfg.menuCollectMB, 50, 2000)
    if c2 then cfg.menuCollectMB = m; changed = true end
    local h, c3 = ImGui.SliderInt("Hard cap (MB)", cfg.hardCapMB, 512, 16384)
    if c3 then cfg.hardCapMB = h; changed = true end
    ImGui.PopItemWidth()
    local l, c4 = ImGui.Checkbox("Log cleanups to console", cfg.logCleanups)
    if c4 then cfg.logCleanups = l; changed = true end
    if ImGui.Button("Clean up now") then fullCollect("manual") end
    ImGui.SameLine()
    if ImGui.Button("Reset to defaults") then
      for k, dv in pairs(DEFAULTS) do cfg[k] = dv end; applyMode(); changed = true
    end
    if changed then save() end
  end
  ImGui.End()
end)

registerForEvent("onUpdate", function(dt)
  if not cfg.enabled then return end
  acc = acc + dt
  if acc < CHECK_EVERY_S then return end
  local step = acc
  acc = 0
  local mb = heapMB()
  local paused = isPaused(step)

  if mb > cfg.menuCollectMB and mb > stats.lastAfter + MIN_GROWTH_MB and (paused or noPlayer()) then
    capMode = false
    fullCollect(noPlayer() and "loading/no player" or "game paused")
    return
  end

  if mb > cfg.hardCapMB then
    if not capMode then
      capMode = true
      collectgarbage("restart")
      print(string.format("[LuaGCTuner] hard cap hit at %.0f MB - background GC resumed until next menu", mb))
    end
  elseif capMode and mb < cfg.hardCapMB * 0.5 then
    capMode = false
    collectgarbage("stop")
  elseif not capMode then
    collectgarbage("stop")   -- another mod's collectgarbage() can restart GC; keep it parked
  end
end)
