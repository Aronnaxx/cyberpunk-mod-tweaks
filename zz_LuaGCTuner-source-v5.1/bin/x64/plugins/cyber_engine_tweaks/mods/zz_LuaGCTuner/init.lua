-- zz_LuaGCTuner v5.1 "menu-time cleanup"
-- v5.1: pause cleanups wait until the game has been paused for "pauseWaitS" seconds (default 2), so the
--       freeze doesn't land in the pause transition (audio fade into the pause mix). Native Settings
--       page has an Apply button that rebuilds the sliders right away (unit / ranges). "Clean up Lua memory
--       now" hotkey (bind it in CET overlay > Bindings). Choose which menus trigger a cleanup:
--       pause menu (Esc), map, inventory & character, journal & messages, other (stash, vendor,
--       photo mode, ...), CET overlay. Loading screens always clean up.
-- v5: (1) red on-screen warnings at 90 / 95 / 99 % of the hard cap. (2) menu cleanup threshold can be
--     set up to 90 % of the hard cap (and is clamped there). (3) reaching the hard cap during gameplay
--     shows a "memory full" warning and runs a full cleanup a moment later (big stutter, estimated in
--     the message); if the cap is below what Lua mods keep alive, falls back to background GC.
--     (4) hard cap 0-128 GB, shown and typed in MB or GB; 0 = no hard cap.
-- v4: finishes the cleanup in ONE pause (CET userdata with finalizers are freed on the following
--     cycle, so a second pass runs when the first leaves the heap well above the live set); skips
--     cleanups unless the heap grew >= 64 MB since the last one.
-- Stops CET's Lua garbage collector from running during gameplay and does the full cleanup
-- where the stall is invisible: game paused (map, inventory, pause menu, journal, photo mode),
-- CET overlay open, or no player (loading).
-- Configure in: CET overlay window "Lua GC Tuner", or game Settings > MODS > Lua GC Tuner.

local DEFAULTS = {
  enabled         = true,   -- false = vanilla Lua GC behaviour
  menuCollectMB   = 150,    -- in a pause/menu, clean up if Lua holds more than this (max 90 % of hard cap)
  hardCapMB       = 10240,  -- full cleanup during gameplay when reached; 0 = none (LuaJIT is GC64: no 2 GB limit)
  capUnit         = "GB",   -- how the hard cap is shown/entered: "GB" or "MB"
  pauseWaitS      = 2.0,    -- pause must last this long (seconds) before a menu cleanup runs
  trigPause       = true,   -- Esc menu (save / load / settings)
  trigMap         = true,   -- world map
  trigInventory   = true,   -- inventory, backpack, cyberware, crafting, perks, stats
  trigJournal     = true,   -- journal, messages, shards, codex
  trigOther       = true,   -- any other pause: stash, vendor, photo mode, fast travel, ...
  trigOverlay     = true,   -- CET overlay opened
  capWarnings     = true,   -- red on-screen warnings at 90 / 95 / 99 / 100 % of the hard cap
  logCleanups     = true,   -- print each cleanup to the CET console
}
local CHECK_EVERY_S = 0.5
local MIN_GROWTH_MB = 64      -- no cleanup unless the heap grew this much since the last one
local MAX_CAP_MB    = 128 * 1024
local MAX_WAIT_S    = 10
local MENU_MAX_FRAC = 0.90    -- menu threshold can't exceed this fraction of the hard cap
local WARN_LEVELS   = { 0.90, 0.95, 0.99 }
local WARN_RESET    = 0.85    -- warnings re-arm once the heap drops below this fraction
local CAP_DELAY_S   = 1.0     -- time between the "memory full" message and the cleanup, so it gets drawn
local SETTINGS_FILE = "settings.json"
local liveMB = nil            -- smallest post-cleanup heap seen = estimate of live data

local cfg = {}
for k, v in pairs(DEFAULTS) do cfg[k] = v end

local acc, capMode = 0, false
local lastStamp, frozenFor = nil, 0
local pausedFor = 0         -- how long the current pause has lasted
local menuKind = nil        -- "pause" | "map" | "inventory" | "journal" | nil (= other / none)
local MENU_KINDS = {
  { key = "trigPause",     label = "Pause menu (Esc: save / load / settings)" },
  { key = "trigMap",       label = "Map" },
  { key = "trigInventory", label = "Inventory & character (backpack, cyberware, crafting, perks)" },
  { key = "trigJournal",   label = "Journal & messages (quests, shards, codex)" },
  { key = "trigOther",     label = "Other pauses (stash, vendor, photo mode, fast travel, ...)" },
  { key = "trigOverlay",   label = "CET overlay" },
}
local KIND_KEY = { pause = "trigPause", map = "trigMap", inventory = "trigInventory", journal = "trigJournal" }

local function hubKind(name)
  name = string.lower(name or "")
  if name:find("map") then return "map" end
  if name:find("quest") or name:find("journal") or name:find("codex") or name:find("shard")
    or name:find("message") or name:find("phone") then return "journal" end
  return "inventory"
end

local function setMenuKind(kind)
  if kind ~= menuKind then menuKind = kind; pausedFor = 0 end   -- new menu: restart the wait
end

local function watchMenus()
  pcall(function()
    ObserveAfter("MenuScenario_PauseMenu", "OnEnterScenario", function() setMenuKind("pause") end)
    Observe("MenuScenario_PauseMenu", "OnLeaveScenario", function() setMenuKind(nil) end)
    ObserveAfter("MenuScenario_HubMenu", "OnEnterScenario", function() setMenuKind("inventory") end)
    ObserveAfter("MenuScenario_HubMenu", "OnOpenMenu", function(_, name)
      local n = ""
      pcall(function() n = name.value or Game.NameToString(name) end)
      setMenuKind(hubKind(n))
    end)
    Observe("MenuScenario_HubMenu", "OnLeaveScenario", function() setMenuKind(nil) end)
  end)
end
local warnedLevel = 0         -- highest warning shown since the heap was last below WARN_RESET
local capPending = nil        -- seconds left until a delayed cleanup (hard cap or hotkey)
local pendingReason = "hard cap"
local stats = { count = 0, lastReason = "-", lastBefore = 0, lastAfter = 0, lastMs = 0, msPerMB = 1.0 }

local function heapMB() return collectgarbage("count") / 1024 end

local function menuMaxMB()
  if cfg.hardCapMB <= 0 then return math.floor(MAX_CAP_MB * MENU_MAX_FRAC) end
  return math.max(50, math.floor(cfg.hardCapMB * MENU_MAX_FRAC))
end

local function clampCfg()
  cfg.hardCapMB = math.max(0, math.min(MAX_CAP_MB, math.floor(cfg.hardCapMB + 0.5)))
  cfg.menuCollectMB = math.max(50, math.min(menuMaxMB(), math.floor(cfg.menuCollectMB + 0.5)))
  if cfg.capUnit ~= "MB" then cfg.capUnit = "GB" end
  cfg.pauseWaitS = math.max(0, math.min(MAX_WAIT_S, cfg.pauseWaitS))
end

local function fmtMB(mb)
  if cfg.capUnit == "MB" then return string.format("%.0f MB", mb) end
  return string.format("%.2f GB", mb / 1024)
end

local function capText()
  if cfg.hardCapMB <= 0 then return "off" end
  return fmtMB(cfg.hardCapMB)
end

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
  clampCfg()
end

local function applyMode()
  if cfg.enabled then
    collectgarbage("stop"); capMode = false
  else
    collectgarbage("restart")
  end
end

-- the red message in the middle of the screen (same one the game uses for "can't do that")
local function popup(msg)
  print("[LuaGCTuner] " .. msg)
  if not cfg.capWarnings then return end
  pcall(function()
    local p = Game.GetPlayer()
    if p then p:SetWarningMessage(msg) end
  end)
end

local function stutterText(mb)
  local ms = mb * stats.msPerMB
  if ms >= 1000 then return string.format("~%.0f s", ms / 1000) end
  return string.format("~%.0f ms", ms)
end

local function fullCollect(reason)
  local before, t0 = heapMB(), os.clock()
  collectgarbage("collect")
  local mid = heapMB()
  -- finalizer-held objects are released on the next cycle; finish in this same pause
  if liveMB == nil or mid > liveMB * 1.3 + 32 then
    collectgarbage("collect")
  end
  if cfg.enabled and not capMode then collectgarbage("stop") end
  local after, ms = heapMB(), (os.clock() - t0) * 1000
  if liveMB == nil or after < liveMB then liveMB = after end
  stats.count = stats.count + 1
  stats.lastReason, stats.lastBefore, stats.lastAfter, stats.lastMs = reason, before, after, ms
  if before > 100 then stats.msPerMB = ms / before end
  if cfg.hardCapMB <= 0 or after < cfg.hardCapMB * WARN_RESET then warnedLevel = 0 end
  capPending = nil
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
local NS_TAB, NS_SUB = "/LuaGCTuner", "/LuaGCTuner/main"
local nsDirty = false   -- slider ranges changed; rebuilt once the settings page is closed
local nsApplyNow = false -- Apply pressed: rebuild on the next frame even though the page is open

local function buildNativeSettings()
  local ns = GetMod("nativeSettings")
  if not ns then return end
  if not ns.pathExists(NS_TAB) then ns.addTab(NS_TAB, "Lua GC Tuner") end
  local NS_MENUS = NS_TAB .. "/menus"
  -- remove the last subcategory first so Native Settings' key list never has holes
  if ns.pathExists(NS_MENUS) then ns.removeSubcategory(NS_MENUS) end
  if ns.pathExists(NS_SUB) then ns.removeSubcategory(NS_SUB) end
  ns.addSubcategory(NS_SUB, "Lua memory cleanup")
  ns.addSwitch(NS_SUB, "Enabled", "ON: no Lua cleanup during gameplay, clean up in menus instead. OFF: vanilla behaviour.",
    cfg.enabled, DEFAULTS.enabled, function(v) cfg.enabled = v; applyMode(); save() end)
  ns.addRangeInt(NS_SUB, "Menu cleanup threshold (MB)",
    string.format("When paused or in a menu, clean up if Lua holds more than this. Max is 90%% of the hard cap (%d MB).", menuMaxMB()),
    50, menuMaxMB(), 10, cfg.menuCollectMB, math.min(DEFAULTS.menuCollectMB, menuMaxMB()),
    function(v) cfg.menuCollectMB = v; clampCfg(); save() end)
  local units = { "GB", "MB" }
  ns.addSelectorString(NS_SUB, "Hard cap unit", "Show and enter the hard cap in gigabytes or megabytes. Press Apply to switch the slider.",
    units, cfg.capUnit == "MB" and 2 or 1, 1,
    function(i) cfg.capUnit = units[i]; save(); nsDirty = true end)
  local capDesc = "At this size Lua memory is cleaned up during gameplay (large stutter, with a warning first). 0 = no hard cap. Exact values can be typed in the CET overlay window."
  if cfg.capUnit == "MB" then
    ns.addRangeInt(NS_SUB, "Hard cap (MB)", capDesc, 0, MAX_CAP_MB, 16, cfg.hardCapMB, DEFAULTS.hardCapMB,
      function(v) cfg.hardCapMB = v; clampCfg(); save(); nsDirty = true end)
  else
    ns.addRangeFloat(NS_SUB, "Hard cap (GB)", capDesc, 0, 128, 0.05, "%.2f", cfg.hardCapMB / 1024, DEFAULTS.hardCapMB / 1024,
      function(v) cfg.hardCapMB = v * 1024; clampCfg(); save(); nsDirty = true end)
  end
  ns.addRangeFloat(NS_SUB, "Pause wait before cleanup (s)",
    "How long the game must stay paused before the cleanup freeze runs. Keeps it out of the pause transition (audio fade). 0 = immediately.",
    0, MAX_WAIT_S, 0.25, "%.2f", cfg.pauseWaitS, DEFAULTS.pauseWaitS,
    function(v) cfg.pauseWaitS = v; clampCfg(); save() end)
  ns.addSwitch(NS_SUB, "Memory warnings", "Red on-screen warnings at 90, 95, 99 and 100% of the hard cap.",
    cfg.capWarnings, DEFAULTS.capWarnings, function(v) cfg.capWarnings = v; save() end)
  ns.addSwitch(NS_SUB, "Log cleanups to console", "Print a line in the CET console for each cleanup.",
    cfg.logCleanups, DEFAULTS.logCleanups, function(v) cfg.logCleanups = v; save() end)
  ns.addSubcategory(NS_MENUS, "Clean up in these menus")
  for _, k in ipairs(MENU_KINDS) do
    ns.addSwitch(NS_MENUS, k.label, "Run the cleanup (after the pause wait) when this menu is open. Loading screens always clean up.",
      cfg[k.key], DEFAULTS[k.key], function(v) cfg[k.key] = v; save() end)
  end
  ns.addButton(NS_SUB, "Apply", "Refresh this page: switches the hard cap slider to the chosen unit and updates the menu threshold range (max 90% of the hard cap).",
    "Apply", 45, function() nsApplyNow = true end)
end

local function rebuildNativeSettingsWhenClosed()
  if not nsDirty and not nsApplyNow then return end
  local ns = GetMod("nativeSettings")
  if not ns then nsDirty, nsApplyNow = false, false; return end
  -- open page: only rebuild when Apply was pressed (a frame later, never inside a widget callback)
  if ns.currentTab == NS_TAB:sub(2) and not nsApplyNow then return end
  nsDirty, nsApplyNow = false, false
  pcall(buildNativeSettings)
end

registerForEvent("onInit", function()
  load()
  applyMode()
  watchMenus()
  buildNativeSettings()
  print(string.format("[LuaGCTuner v5.1] %s; menu cleanup >%d MB after %.2f s paused, hard cap %s, heap %.0f MB",
    cfg.enabled and "background GC stopped" or "DISABLED (vanilla GC)", cfg.menuCollectMB, cfg.pauseWaitS, capText(), heapMB()))
end)

registerHotkey("lgc_clean_now", "Clean up Lua memory now", function()
  if capPending then return end
  local mb = heapMB()
  if mb <= (liveMB or 0) + 16 then
    popup(string.format("Lua memory is already clean (%s).", fmtMB(mb)))
    return
  end
  popup(string.format("Cleaning up Lua memory (%s): expect a stutter (%s).", fmtMB(mb), stutterText(mb)))
  pendingReason = "hotkey"
  capPending = CAP_DELAY_S
end)

local overlayOpen = false
registerForEvent("onOverlayOpen", function()
  overlayOpen = true
  if cfg.enabled and cfg.trigOverlay and heapMB() > cfg.menuCollectMB then fullCollect("CET overlay") end
end)
registerForEvent("onOverlayClose", function() overlayOpen = false; nsDirty = true end)

-- CET overlay window
registerForEvent("onDraw", function()
  if not overlayOpen then return end
  if ImGui.Begin("Lua GC Tuner", ImGuiWindowFlags.AlwaysAutoResize) then
    local mb = heapMB()
    local pct = cfg.hardCapMB > 0 and string.format(" (%.0f%% of cap)", mb / cfg.hardCapMB * 100) or ""
    ImGui.Text(string.format("Lua heap: %s%s   %s", fmtMB(mb), pct,
      not cfg.enabled and "(vanilla GC)" or (capMode and "(background GC running)" or "(background GC parked)")))
    ImGui.Text(string.format("Cleanups: %d   last: %s, %.0f -> %.0f MB in %.0f ms   live ~%.0f MB",
      stats.count, stats.lastReason, stats.lastBefore, stats.lastAfter, stats.lastMs, liveMB or 0))
    ImGui.Separator()
    local changed
    local v, c = ImGui.Checkbox("Enabled", cfg.enabled)
    if c then cfg.enabled = v; applyMode(); changed = true end

    ImGui.PushItemWidth(220)
    local m, c2 = ImGui.SliderInt("Menu cleanup threshold (MB)", cfg.menuCollectMB, 50, menuMaxMB())
    if c2 then cfg.menuCollectMB = m; changed = true end
    ImGui.SameLine(); ImGui.TextDisabled(string.format("max %d (90%% of cap)", menuMaxMB()))

    ImGui.Text("Hard cap unit:"); ImGui.SameLine()
    if ImGui.RadioButton("GB", cfg.capUnit == "GB") then cfg.capUnit = "GB"; changed = true end
    ImGui.SameLine()
    if ImGui.RadioButton("MB", cfg.capUnit == "MB") then cfg.capUnit = "MB"; changed = true end

    if cfg.capUnit == "MB" then
      local h, c3 = ImGui.SliderInt("Hard cap (MB)", cfg.hardCapMB, 0, MAX_CAP_MB)
      if c3 then cfg.hardCapMB = h; changed = true end
      local t, c4 = ImGui.InputInt("Type MB + Enter##capmb", cfg.hardCapMB, 0, 0, ImGuiInputTextFlags.EnterReturnsTrue)
      if c4 then cfg.hardCapMB = t; changed = true end
    else
      local h, c3 = ImGui.SliderFloat("Hard cap (GB)", cfg.hardCapMB / 1024, 0, 128, "%.2f")
      if c3 then cfg.hardCapMB = h * 1024; changed = true end
      local t, c4 = ImGui.InputFloat("Type GB + Enter##capgb", cfg.hardCapMB / 1024, 0, 0, "%.3f", ImGuiInputTextFlags.EnterReturnsTrue)
      if c4 then cfg.hardCapMB = t * 1024; changed = true end
    end
    ImGui.PopItemWidth()
    ImGui.TextDisabled("0 = no hard cap. Range 0-128 GB (0-131072 MB).")

    ImGui.PushItemWidth(220)
    local pw, cw = ImGui.SliderFloat("Pause wait before cleanup (s)", cfg.pauseWaitS, 0, MAX_WAIT_S, "%.2f")
    if cw then cfg.pauseWaitS = pw; changed = true end
    ImGui.PopItemWidth()
    ImGui.Text("Clean up in these menus:")
    for _, k in ipairs(MENU_KINDS) do
      local tv, tc = ImGui.Checkbox(k.label, cfg[k.key])
      if tc then cfg[k.key] = tv; changed = true end
    end
    ImGui.TextDisabled("Current menu: " .. (menuKind or "none / other"))
    local w, c5 = ImGui.Checkbox("Memory warnings (90/95/99/100% of cap)", cfg.capWarnings)
    if c5 then cfg.capWarnings = w; changed = true end
    local l, c6 = ImGui.Checkbox("Log cleanups to console", cfg.logCleanups)
    if c6 then cfg.logCleanups = l; changed = true end
    if ImGui.Button("Clean up now") then fullCollect("manual") end
    ImGui.SameLine()
    if ImGui.Button("Test warning") then popup("Lua GC Tuner: test warning") end
    ImGui.SameLine()
    if ImGui.Button("Reset to defaults") then
      for k, dv in pairs(DEFAULTS) do cfg[k] = dv end; applyMode(); changed = true
    end
    if changed then clampCfg(); save() end
  end
  ImGui.End()
end)

registerForEvent("onUpdate", function(dt)
  rebuildNativeSettingsWhenClosed()
  if not cfg.enabled then return end

  -- forced hard-cap cleanup, a moment after its warning was shown
  if capPending then
    capPending = capPending - dt
    if capPending <= 0 then
      local reason = pendingReason
      fullCollect(reason)
      if reason == "hard cap" and cfg.hardCapMB > 0 and heapMB() >= cfg.hardCapMB * MENU_MAX_FRAC then
        -- the cap is at or below what Lua mods keep alive: repeated full cleanups would stutter forever
        capMode = true
        collectgarbage("restart")
        popup(string.format("Lua hard cap (%s) is too low: mods keep ~%s alive. Raise it. Using background cleanup for now.",
          capText(), fmtMB(heapMB())))
      end
    end
    return
  end

  acc = acc + dt
  if acc < CHECK_EVERY_S then return end
  local step = acc
  acc = 0
  local mb = heapMB()
  local paused = isPaused(step)
  if paused then pausedFor = pausedFor + step else pausedFor = 0 end
  local cap = cfg.hardCapMB
  local frac = cap > 0 and mb / cap or 0
  local menuMB = math.min(cfg.menuCollectMB, menuMaxMB())

  local loading = noPlayer()
  local menuOk = loading or (paused and pausedFor >= cfg.pauseWaitS and cfg[KIND_KEY[menuKind] or "trigOther"])
  if mb > menuMB and mb > stats.lastAfter + MIN_GROWTH_MB and menuOk then
    if capMode then capMode = false end
    fullCollect(loading and "loading/no player" or ("paused: " .. (menuKind or "other")))
    return
  end

  if cap <= 0 then
    if capMode then capMode = false; collectgarbage("stop") end
    collectgarbage("stop")   -- another mod's collectgarbage() can restart GC; keep it parked
    return
  end

  if capMode then
    -- background GC running because the cap is below the live set; park it again once it's well clear
    if mb < cap * 0.5 then capMode = false; collectgarbage("stop") end
    return
  end
  collectgarbage("stop")

  if frac < WARN_RESET then warnedLevel = 0 end
  if paused or noPlayer() then return end   -- menu cleanup handles it there

  if frac >= 1.0 then
    popup(string.format("Lua memory FULL (%s of %s). Cleaning up now: expect a large stutter (%s).",
      fmtMB(mb), capText(), stutterText(mb)))
    warnedLevel = 1.0
    pendingReason = "hard cap"
    capPending = CAP_DELAY_S
    return
  end

  for i = #WARN_LEVELS, 1, -1 do
    local lvl = WARN_LEVELS[i]
    if frac >= lvl then
      if warnedLevel < lvl then
        warnedLevel = lvl
        local tail = lvl >= 0.99
          and string.format(" At 100%% it cleans up with a large stutter (%s). Pause now to avoid it.", stutterText(cap))
          or " Open a menu or pause to clean it up."
        popup(string.format("Lua memory %d%% full (%s of %s).%s", math.floor(lvl * 100 + 0.5), fmtMB(mb), capText(), tail))
      end
      break
    end
  end
end)
