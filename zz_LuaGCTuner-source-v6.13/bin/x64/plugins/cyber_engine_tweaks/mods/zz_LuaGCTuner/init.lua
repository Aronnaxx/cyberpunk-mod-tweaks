-- zz_LuaGCTuner v6.7 "menu-time cleanup"
-- v6.13: LHUD bridge reads LHUD's own published state flags instead of re-deriving them (meter showed while LHUD hid the HUD).
-- v6.12: the MCM meter shows only in Mod Configuration Menu; other Esc pages (settings, save, load) hide it.
-- v6.11:  into the Resume list and "Mod Configuration Menu & other Esc pages" (own meter
--        position each); Limited HUD is always followed when installed (switch removed); LHUD status in the overlay;
--        "Only show above (% of cap)" removed (the meter shows whenever its screen is on).
-- v6.10: LHUD bridge gains "Show with scanner" (r6/scripts/LuaGCTunerLHUD).
-- v6.9: one default "Wait before cleanup" (main section) that each menu can override ("Own wait time");
--       meter: green marker at the gameplay-cleanup level, optional freeze estimate shown at all times.
-- v6.8: settings regrouped: one always-visible entry per screen (Esc menu, map, inventory, journal, other,
--       gameplay) with "Clean up here", wait, "Show meter", background opacity and Advanced options (look
--       overrides). Optional gameplay cleanup (off by default): at a % of the cap, warning first, skips combat /
--       driving. Background is an opacity slider per screen. LHUD link no longer gives up after 5 s.
-- v6.7: "Bottom center" and "Center" anchors; X / Y offsets can be negative (0 = centered for center anchors);
--       per-screen Background is a plain on / off switch;
--       removed the Esc-menu profiler ring chart (profiler.lua); meter no longer retries (and logs) a failed build every frame; layer lookup falls back to the layer list.
-- v6.6: Esc-menu ring chart of which mods allocate the most Lua memory and how fast (profiler.lua, fed by
--       RedProfiler captures: Off / Pause menu only / Sample gameplay after resume / Always); meter
--       "Only show above (% of cap)" threshold, per screen too.
-- v6.5: sharp meter text (sizes applied directly instead of SetScale); "Advanced options" holds the default
--       look plus a per-screen "Override settings" section with every look option (position, scale, width,
--       background, icon, percentage, cap mode, countdown, freeze estimate); meter screen check at 10 Hz.
-- v6.4: HUD meter follows Limited HUD (LHUD) via r6/scripts/LuaGCTunerLHUD (own section in LHUD's settings,
--       visibility + opacity polled at 4 Hz); "Follow LHUD" switch in the HUD meter section.
-- v6.3: meter layout per screen (inventory, map, journal, Esc menu, other, HUD): own anchor / X / Y / scale
--       behind "Own position (press Apply)", like Dark Future; global layout is the default. Freeze ETA next to
--       the countdown. Friendlier cleanup names in notices ("Esc menu", "map", ...).
-- v6.2: meter placed from the layer size (right/center anchors were ignored in the letterboxed menus);
--       new default in the top bar left of weight / money; meter.lua colors built in init (load fix).
-- v6.1: per-menu cleanup mode (Off / Default wait / Immediately / Custom wait) for the pause menu, map,
--       inventory & character, journal and other pauses. Hard cap and dynamic limits can not exceed the
--       installed RAM (read through SysMemInfo; 128 GB when the plugin is missing).
-- v6.0: native ink meter (meter.lua) in menus / optionally the HUD: icon, value / cap, %, filling bar with the
--       menu-threshold marker, static / dynamic mode, cleanup countdown; position, scale, width, background
--       and per-screen toggles (advanced options). Mod Configuration Menu re-reads the page after rebuilds.
--       Static hard cap controls are replaced / greyed out while the dynamic cap is on. Ctrl+click types values.
-- v5.4: countdown at the top of the screen while a menu cleanup is pending ("Lua cleanup in 7 s"), drawn
--       with CET ImGui (works with the overlay closed). Only drawn while a countdown is running.
-- v5.3: "Clean up now" key bindable in Native Settings / Mod Config Menu (Codeware Input/Key callback; the
--       CET hotkey still works). SysMemInfo.dll ships inside this mod (red4ext/plugins/SysMemInfo); the
--       dynamic hard cap section is hidden with an explanation when the plugin did not load.
-- v5.2: pause wait 0-180 s (default 10, typeable). Notices: result of every cleanup (shown when gameplay
--       resumes). Dynamic hard cap from free RAM / commit via the SysMemInfo RED4ext plugin
--       (cap = Lua heap + min(free RAM, free commit) - reserve, clamped), with a notice when it moves
--       by the chosen step. "Clean up now" button in Native Settings.
-- v5.1: pause cleanups wait until the game has been paused for "pauseWaitS" seconds (default 2), so the
--       freeze doesn't land in the pause transition (audio fade into the pause mix). Native Settings
--       page refreshes itself after unit / cap changes (v5.2: no separate Apply button). "Clean up Lua memory
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
  thresholdPercent = false, -- menu threshold as a % of the hard cap (follows the cap) instead of exact MB
  menuCollectPct  = 30,     -- menu threshold in % of the hard cap, 1-90
  hardCapMB       = 10240,  -- full cleanup during gameplay when reached; 0 = none (LuaJIT is GC64: no 2 GB limit)
  capUnit         = "GB",   -- how the hard cap is shown/entered: "GB" or "MB"
  pauseWaitS      = 10.0,   -- default wait before a menu cleanup (s); menus can override it (waitOwn<Kind>)
  cleanKey        = "IK_None", -- Native Settings key for "clean up now" (IK_None = not bound)
  warnLeadS       = 3.0,    -- seconds between the "expect a stutter" warning and the cleanup
  menuCountdown   = true,   -- show "Lua cleanup in N s" at the top of the screen in menus
  cleanupNotify   = true,   -- notice with the result of each cleanup (shown back in gameplay)
  dynamicCap      = false,  -- hard cap follows free system memory (needs the SysMemInfo plugin)
  dynReserveGB    = 8.0,    -- keep this much RAM / commit free for the game and Windows
  dynMinGB        = 2.0,    -- dynamic cap never goes below this
  dynMaxGB        = 64.0,   -- ... or above this
  dynNotifyGB     = 1.0,    -- notice when the dynamic cap moved at least this much (0 = never)
  -- per menu: clean up there or not, and how long the menu must be open first (0 = immediately)
  cleanPause      = true, waitOwnPause     = false, waitPause     = 10,   -- Esc menu (save / load / settings)
  cleanMap        = true, waitOwnMap       = false, waitMap       = 10,   -- world map
  cleanInventory  = true, waitOwnInventory = false, waitInventory = 10,   -- inventory, backpack, cyberware, ...
  cleanJournal    = true, waitOwnJournal   = false, waitJournal   = 10,   -- journal, messages, shards, codex
  cleanOther      = true, waitOwnOther     = false, waitOther     = 10,   -- stash, vendor, photo mode, fast travel, ...
  -- gameplay (no menu): off by default; at hudCleanPct % of the cap, warn, wait hudWarnS, clean up
  cleanHud        = false,
  hudCleanPct     = 75,
  hudWarnS        = 5,
  hudSkipCombat   = true,
  hudSkipDriving  = true,
  trigOverlay     = true,   -- CET overlay opened
  capWarnings     = true,   -- red on-screen warnings at 90 / 95 / 99 / 100 % of the hard cap
  logCleanups     = true,   -- print each cleanup to the CET console
}
local CHECK_EVERY_S = 0.5
local MIN_GROWTH_MB = 64      -- no cleanup unless the heap grew this much since the last one
local MAX_CAP_MB    = 128 * 1024
local MAX_WAIT_S    = 180
local DYN_EVERY_S   = 5
local DYN_STEP_MB   = 256      -- ignore smaller moves of the dynamic cap
local MENU_MAX_FRAC = 0.90    -- menu threshold can't exceed this fraction of the hard cap
local WARN_LEVELS   = { 0.90, 0.95, 0.99 }
local WARN_RESET    = 0.85    -- warnings re-arm once the heap drops below this fraction
local CAP_DELAY_S   = 1.0     -- time between the "memory full" message and the cleanup, so it gets drawn
local SETTINGS_FILE = "settings.json"
local liveMB = nil            -- smallest post-cleanup heap seen = estimate of live data
local dynCapMB = nil          -- current dynamic cap (nil = not computed / plugin missing)
local dynNotifiedMB = nil     -- dynamic cap value of the last notice
local dynAcc = DYN_EVERY_S
local sysMem = { ok = nil, availMB = 0, commitMB = 0, totalMB = 0 }
local notices = {}           -- queued on-screen notices, shown during gameplay
local noticeGap = 0
local lastPaused = true      -- result of the last pause check (notices wait for gameplay)
local countdown = nil        -- seconds until the pending menu cleanup (nil = none pending)
local countdownMB = 0        -- heap size the countdown was computed for
local armedReason = nil      -- menu cleanup runs next frame, after "Cleaning up" has been drawn once

local meter = require("meter")
for k, v in pairs(meter.DEFAULTS) do DEFAULTS[k] = v end

local cfg = {}
for k, v in pairs(DEFAULTS) do cfg[k] = v end

-- effective hard cap: dynamic when enabled and the plugin answers, else the configured one
local function capMB()
  if cfg.dynamicCap and dynCapMB then return dynCapMB end
  return cfg.hardCapMB
end

local acc, capMode = 0, false
local lastStamp, frozenFor = nil, 0
local pausedFor = 0         -- how long the current pause has lasted
local menuKind = nil        -- "pause" | "map" | "inventory" | "journal" | nil (= other / none)
local MENU_KINDS = {
  { id = "Pause",     label = "Pause menu (Esc: save / load / settings)" },
  { id = "Map",       label = "Map" },
  { id = "Inventory", label = "Inventory & character (backpack, cyberware, crafting, perks)" },
  { id = "Journal",   label = "Journal & messages (quests, shards, codex)" },
  { id = "Other",     label = "Other pauses (stash, vendor, photo mode, fast travel, ...)" },
}
local KIND_ID = { pause = "Pause", map = "Map", inventory = "Inventory", journal = "Journal" }
local OLD_TRIG = { Pause = "trigPause", Map = "trigMap", Inventory = "trigInventory", Journal = "trigJournal", Other = "trigOther" }

local function hubKind(name)
  name = string.lower(name or "")
  if name:find("map") then return "map" end
  if name:find("quest") or name:find("journal") or name:find("codex") or name:find("shard")
    or name:find("message") or name:find("phone") then return "journal" end
  return "inventory"
end

-- Limited HUD bridge (r6/scripts/LuaGCTunerLHUD, compiled only when LHUD is installed): asked 4x a second
-- Looked up again every 2 s until found (the system only exists once a game is loaded), never given up on.
local lhud = { at = -1, visible = true, opacity = 1, sys = nil, logged = nil, misses = 0, why = "" }
local ALWAYS = { visible = true, opacity = 1 }
local function lhudState()
  local now = os.clock()
  if now - lhud.at < (lhud.sys and 0.25 or 2.0) then return lhud.sys and lhud or ALWAYS end
  lhud.at = now
  if not lhud.sys then
    local ok = pcall(function()
      local c = Game.GetScriptableSystemsContainer()
      lhud.sys = c:Get("LuaGCTunerLHUDSystem") or c:Get(CName.new("LuaGCTunerLHUDSystem"))
    end)
    if not lhud.sys then
      if Game.GetPlayer() then lhud.misses = lhud.misses + 1 end
      if lhud.misses == 15 and lhud.logged ~= "missing" then   -- ~30 s in a loaded game without it
        lhud.logged = "missing"
        print("[LuaGCTuner] Limited HUD link not found (LHUD not installed, or r6/scripts/LuaGCTunerLHUD did not compile): HUD meter ignores LHUD")
      end
      return ALWAYS
    end
  end
  local ok = pcall(function() lhud.visible = lhud.sys:IsVisible(); lhud.opacity = lhud.sys:GetOpacity() end)
  if ok then pcall(function() lhud.why = lhud.sys:Describe() end) end
  if not ok then lhud.sys = nil; lhud.misses = 0; return ALWAYS end
  if lhud.logged ~= "ok" then
    lhud.logged = "ok"
    print(string.format("[LuaGCTuner] Limited HUD link connected (meter visible: %s, opacity %.2f)", tostring(lhud.visible), lhud.opacity))
  end
  return lhud
end

-- gameplay cleanup is held back during combat / driving when asked
local function gameplayBusy()
  local busy = false
  pcall(function()
    local p = Game.GetPlayer()
    if not p then return end
    if cfg.hudSkipCombat and p:IsInCombat() then busy = true end
    if cfg.hudSkipDriving and Game.GetMountedVehicle(p) ~= nil then busy = true end
  end)
  return busy
end

local KIND_NAME = { pause = "Esc menu", map = "map", inventory = "inventory", journal = "journal" }
local function kindName(kind) return KIND_NAME[kind] or "menu" end

local function setMenuKind(kind)
  if kind ~= menuKind then menuKind = kind; pausedFor = 0 end   -- new menu: restart the wait
end

-- Esc menu page: the pause scenario's current menu / sub-menu (helper in r6/scripts/LuaGCTunerLHUD/
-- LuaGCTunerMenu.reds). "list" = the Resume / Save / Load list, "mcm" = Mod Configuration Menu (drawn by
-- MCM inside the settings screen; its controller says so through McmUiIsActive), "other" = any other page.
local pauseScenario = nil
local settingsCtrl = nil
local pausePageName = ""
local function mcmActive()
  if not settingsCtrl then return false end
  local ok, on = pcall(function() return settingsCtrl:McmUiIsActive() end)
  if not ok then settingsCtrl = nil; return false end
  return on == true
end
local function pausePage()
  if menuKind ~= "pause" or not pauseScenario then pausePageName = ""; return "list" end
  local ok, page = pcall(function() return pauseScenario:LuaGCTuner_MenuPage() end)
  if not ok or type(page) ~= "string" then pausePageName = "?"; return "list" end
  local main, sub = page:match("^([^|]*)|(.*)$")
  if main and (main == "pause_menu" or main == "" or main == "None") and (sub == "" or sub == "None") then
    pausePageName = page
    return "list"
  end
  local kind = mcmActive() and "mcm" or "other"
  pausePageName = page .. " -> " .. kind
  return kind
end

local function watchMenus()
  pcall(function()
    ObserveAfter("MenuScenario_PauseMenu", "OnEnterScenario", function(self) pauseScenario = self; setMenuKind("pause") end)
    Observe("MenuScenario_PauseMenu", "OnLeaveScenario", function() pauseScenario = nil; setMenuKind(nil) end)
  end)
  pcall(function()   -- settings screen controller: MCM draws inside it (Mod Configuration Menu installed or not)
    ObserveAfter("SettingsMainGameController", "OnInitialize", function(self) settingsCtrl = self end)
    Observe("SettingsMainGameController", "OnUninitialize", function() settingsCtrl = nil end)
  end)
  pcall(function()
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
  if capMB() <= 0 then return math.floor(MAX_CAP_MB * MENU_MAX_FRAC) end
  return math.max(50, math.floor(capMB() * MENU_MAX_FRAC))
end

-- does the open menu clean up, and after how long (kind = nil -> "Other")
local function menuCleans(kind) return cfg["clean" .. (KIND_ID[kind] or "Other")] end
local function menuWait(kind)
  local id = KIND_ID[kind] or "Other"
  if cfg["waitOwn" .. id] then return cfg["wait" .. id] end
  return cfg.pauseWaitS
end

-- largest allowed cap: installed RAM when SysMemInfo can tell, else 128 GB
local function maxCapMB()
  if sysMem.ok and sysMem.totalMB > 0 then return math.floor(sysMem.totalMB) end
  return MAX_CAP_MB
end
local function maxCapGB() return math.floor(maxCapMB() / 1024 * 4) / 4 end

-- effective menu-cleanup threshold: % of the current cap, or the exact MB value limited to 90 % of the cap
local function menuThresholdMB()
  if cfg.thresholdPercent and capMB() > 0 then
    return math.max(50, math.floor(capMB() * cfg.menuCollectPct / 100))
  end
  return math.min(cfg.menuCollectMB, menuMaxMB())
end

local function clampCfg()
  cfg.hardCapMB = math.max(0, math.min(maxCapMB(), math.floor(cfg.hardCapMB + 0.5)))
  cfg.menuCollectMB = math.max(50, math.min(MAX_CAP_MB, math.floor(cfg.menuCollectMB + 0.5)))
  cfg.menuCollectPct = math.max(1, math.min(90, math.floor(cfg.menuCollectPct + 0.5)))
  if cfg.capUnit ~= "MB" then cfg.capUnit = "GB" end
  cfg.pauseWaitS = math.max(0, math.min(MAX_WAIT_S, cfg.pauseWaitS))
  cfg.warnLeadS = math.max(0.5, math.min(15, cfg.warnLeadS))
  cfg.dynReserveGB = math.max(0, math.min(64, cfg.dynReserveGB))
  cfg.dynMinGB = math.max(0.25, math.min(maxCapGB(), cfg.dynMinGB))
  cfg.dynMaxGB = math.max(cfg.dynMinGB, math.min(maxCapGB(), cfg.dynMaxGB))
  for _, k in ipairs(MENU_KINDS) do
    cfg["wait" .. k.id] = math.max(0, math.min(MAX_WAIT_S, cfg["wait" .. k.id]))
  end
  cfg.hudCleanPct = math.max(10, math.min(99, math.floor(cfg.hudCleanPct + 0.5)))
  cfg.hudWarnS = math.max(0.5, math.min(30, cfg.hudWarnS))
  for _, sc in ipairs(meter.SCREENS) do
    cfg["meterBg" .. sc.id] = math.max(0, math.min(1, cfg["meterBg" .. sc.id]))
  end
  cfg.dynNotifyGB = math.max(0, math.min(64, cfg.dynNotifyGB))
  local function clampLook(suffix)
    for _, o in ipairs(meter.LOOK) do
      local k = "meter" .. o.f .. suffix
      if o.kind == "anchor" then cfg[k] = math.max(1, math.min(#meter.ANCHORS, math.floor(cfg[k])))
      elseif o.kind == "int" or o.kind == "float" then cfg[k] = math.max(o.lo, math.min(o.hi, cfg[k])) end
    end
  end
  clampLook("")
  for _, sc in ipairs(meter.SCREENS) do clampLook(sc.id) end
end

local function fmtMB(mb)
  if cfg.capUnit == "MB" then return string.format("%.0f MB", mb) end
  return string.format("%.2f GB", mb / 1024)
end

local function capText()
  if capMB() <= 0 then return "off" end
  return fmtMB(capMB()) .. ((cfg.dynamicCap and dynCapMB) and " (dynamic)" or "")
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
      for _, sc in ipairs(meter.SCREENS) do   -- per-screen values that were never saved start from the saved defaults
        for _, o in ipairs(meter.LOOK) do
          if data["meter" .. o.f .. sc.id] == nil and data["meter" .. o.f] ~= nil then
            cfg["meter" .. o.f .. sc.id] = data["meter" .. o.f]
          end
        end
      end
      if data.meterOwnMcm == nil and data.meterOwnPause ~= nil then
        -- v6.11: the Esc menu meter becomes two screens. The MCM / settings pages keep the old Esc menu
        -- meter; the Resume list starts from its new default (just above Resume).
        local P = { "meterOwn", "meterBg", "meter" }
        for _, pre in ipairs(P) do
          local k = pre .. "Pause"
          if data[k] ~= nil then cfg[pre .. "Mcm"] = cfg[k] end
        end
        for _, o in ipairs(meter.LOOK) do
          cfg["meter" .. o.f .. "Mcm"] = cfg["meter" .. o.f .. "Pause"]
          cfg["meter" .. o.f .. "Pause"] = DEFAULTS["meter" .. o.f .. "Pause"]
        end
        cfg.meterOwnPause = true
      end
      if data.meterX == 150 and data.meterY == 185 and data.meterScale == 1.0 then   -- v6.0/6.1 meter defaults
        cfg.meterX, cfg.meterY, cfg.meterScale = meter.DEFAULTS.meterX, meter.DEFAULTS.meterY, meter.DEFAULTS.meterScale
      end
      for _, k in ipairs(MENU_KINDS) do   -- v6.1-6.7 per-menu modes (off / default / immediately / custom) -> on + wait
        local id, mode = k.id, data["mode" .. k.id]
        if data[OLD_TRIG[id]] == false and mode == nil then mode = 1 end   -- v5 / v6.0 on/off switches
        if data["clean" .. id] == nil and mode ~= nil then
          cfg["clean" .. id] = mode ~= 1
          if mode == 3 then cfg["wait" .. id] = 0 end
          cfg["waitOwn" .. id] = mode == 3 or mode == 4
        elseif data["waitOwn" .. id] == nil and tonumber(data["wait" .. id]) then   -- v6.8: own only if it differed
          cfg["waitOwn" .. id] = math.abs(tonumber(data["wait" .. id]) - (tonumber(data.pauseWaitS) or 10)) > 0.01
        end
      end
      for _, sc in ipairs(meter.SCREENS) do   -- v6.0-6.7 Background (off / map only / always) + opacity -> one opacity
        if data["meterBg" .. sc.id] == nil and (data.meterBackground ~= nil or data.meterBgOpacity ~= nil) then
          local own = data["meterOwn" .. sc.id] == true
          local mode = (own and data["meterBackground" .. sc.id]) or data.meterBackground or 2
          local op = (own and data["meterBgOpacity" .. sc.id]) or data.meterBgOpacity or 0.85
          cfg["meterBg" .. sc.id] = (mode == 3 or (mode == 2 and sc.id == "Map")) and op or 0
        end
      end
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
local function showNow(msg)
  pcall(function()
    local p = Game.GetPlayer()
    if p then p:SetWarningMessage(msg) end
  end)
end

-- memory warnings: shown right away
local function popup(msg)
  print("[LuaGCTuner] " .. msg)
  if not cfg.capWarnings then return end
  showNow(msg)
end

-- informational notices (cleanup results, dynamic cap moves): queued, shown during gameplay
local function notice(msg)
  print("[LuaGCTuner] " .. msg)
  table.insert(notices, msg)
  if #notices > 4 then table.remove(notices, 1) end
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
  if capMB() <= 0 or after < capMB() * WARN_RESET then warnedLevel = 0 end
  capPending = nil
  if cfg.cleanupNotify then
    notice(string.format("Lua cleanup (%s): %s -> %s in %s.", reason, fmtMB(before), fmtMB(after),
      ms >= 1000 and string.format("%.1f s", ms / 1000) or string.format("%.0f ms", ms)))
  end
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

-- SysMemInfo plugin (RED4ext): free RAM and free commit in MB
local function readSysMem()
  if (sysMem.fails or 0) >= 3 then return false end   -- missing: stop calling it (avoids error spam)
  local ok = pcall(function()
    sysMem.availMB = Game.SysMem_AvailPhysMB()
    sysMem.commitMB = Game.SysMem_AvailCommitMB()
    sysMem.totalMB = Game.SysMem_TotalPhysMB()
  end)
  sysMem.ok = (ok and type(sysMem.availMB) == "number" and type(sysMem.totalMB) == "number"
    and sysMem.totalMB > 0) and true or false
  if sysMem.ok then sysMem.fails = 0 else sysMem.fails = (sysMem.fails or 0) + 1 end
  return sysMem.ok
end

local function updateDynamicCap()
  if not cfg.dynamicCap then dynCapMB = nil; dynNotifiedMB = nil; return end
  if not readSysMem() then dynCapMB = nil; return end
  local commit = (type(sysMem.commitMB) == "number" and sysMem.commitMB > 0) and sysMem.commitMB or sysMem.availMB
  local free = math.min(sysMem.availMB, commit)
  local target = heapMB() + free - cfg.dynReserveGB * 1024
  target = math.max(cfg.dynMinGB * 1024, math.min(cfg.dynMaxGB * 1024, target))
  target = math.floor(target / 64 + 0.5) * 64
  if dynCapMB == nil or math.abs(target - dynCapMB) >= DYN_STEP_MB then dynCapMB = target end
  if cfg.dynNotifyGB > 0 then
    if dynNotifiedMB == nil then
      dynNotifiedMB = dynCapMB
      notice(string.format("Dynamic Lua limit set to %s.", fmtMB(dynCapMB)))
    elseif math.abs(dynCapMB - dynNotifiedMB) >= cfg.dynNotifyGB * 1024 then
      notice(string.format("Dynamic Lua limit %s to %s.", dynCapMB > dynNotifiedMB and "increased" or "decreased",
        fmtMB(dynCapMB)))
      dynNotifiedMB = dynCapMB
    end
  end
end

-- Game Settings > MODS page (Native Settings UI), if installed
local NS_TAB, NS_SUB = "/LuaGCTuner", "/LuaGCTuner/main"
local nsDirty = false   -- slider ranges changed; rebuilt once the settings page is closed
local mcmReloadPending = false
local nsRefreshIn = nil   -- unit / cap applied: refresh the open page after this many seconds (debounced)

-- one Native Settings widget for a look option (suffix "" = default, else a screen id)
local function addLookOption(ns, path, o, suffix, set)
  local k = "meter" .. o.f .. suffix
  if o.kind == "anchor" then
    local anchors = {}
    for i, a in ipairs(meter.ANCHORS) do anchors[i] = a.label end
    ns.addSelectorString(path, o.label, "Where the offsets are measured from. Center anchors start centered: negative X / Y moves left / up, positive right / down. Corner anchors measure inward from that corner.", anchors, cfg[k], DEFAULTS[k], set(k))
  elseif o.kind == "int" then
    ns.addRangeInt(path, o.label, (o.f == "X" or o.f == "Y") and "4K screen units from the anchor; with a center anchor 0 is centered and negative goes left / up. Kept on screen." or "4K screen units.", o.lo, o.hi, o.step, cfg[k], DEFAULTS[k], set(k))
  elseif o.kind == "float" then
    ns.addRangeFloat(path, o.label, "", o.lo, o.hi, o.step, "%.2f", cfg[k], DEFAULTS[k], set(k))
  else
    ns.addSwitch(path, o.label, "", cfg[k], DEFAULTS[k], set(k))
  end
end

-- "Menu meter": master switch + the default look every screen inherits
local function buildMeterSettings(ns)
  local P = NS_TAB .. "/meter"
  local function set(key) return function(v) cfg[key] = v; clampCfg(); save(); meter.rebuild() end end
  ns.addSubcategory(P, "Meter (Lua memory bar)")
  ns.addSwitch(P, "Show meter", "Master switch for the native Lua memory bar. Pick the screens in their own sections below.",
    cfg.meterEnabled, DEFAULTS.meterEnabled, set("meterEnabled"))
  ns.addSwitch(P, "Default look (press Apply)", "Position, size and contents every screen uses unless its Advanced options override them.",
    cfg.meterAdvanced, DEFAULTS.meterAdvanced, function(v) cfg.meterAdvanced = v; save(); nsRefreshIn = 0.3 end)
  if not cfg.meterAdvanced then return end
  for _, o in ipairs(meter.LOOK) do addLookOption(ns, P, o, "", set) end
end

-- one always-visible entry per screen: cleanup there + meter there
local function buildScreenSettings(ns)
  local function setMeter(key) return function(v) cfg[key] = v; clampCfg(); save(); meter.rebuild() end end
  local function setPlain(key) return function(v) cfg[key] = v; clampCfg(); save() end end
  for _, sc in ipairs(meter.SCREENS) do
    local SP = NS_TAB .. "/screen" .. sc.id
    ns.addSubcategory(SP, sc.label)
    if sc.noClean then
      -- cleanup here follows the Esc menu entry above
    elseif sc.id == "Hud" then
      ns.addSwitch(SP, "Clean up during gameplay", "Clean up before the hard cap, during gameplay: a warning, then a stutter after the delay below. Off: only menus, loading screens and the hard cap clean up.",
        cfg.cleanHud, DEFAULTS.cleanHud, setPlain("cleanHud"))
      ns.addRangeInt(SP, "Clean up at (% of cap)", "Lua memory level (share of the hard cap) that starts a gameplay cleanup.",
        10, 99, 1, cfg.hudCleanPct, DEFAULTS.hudCleanPct, setPlain("hudCleanPct"))
      ns.addRangeFloat(SP, "Warning before cleanup (s)", "How long the warning is on screen before the stutter.",
        0.5, 30, 0.5, "%.1f", cfg.hudWarnS, DEFAULTS.hudWarnS, setPlain("hudWarnS"))
      ns.addSwitch(SP, "Not during combat", "Hold the gameplay cleanup back while in combat.",
        cfg.hudSkipCombat, DEFAULTS.hudSkipCombat, setPlain("hudSkipCombat"))
      ns.addSwitch(SP, "Not while driving", "Hold the gameplay cleanup back while in a vehicle.",
        cfg.hudSkipDriving, DEFAULTS.hudSkipDriving, setPlain("hudSkipDriving"))
    else
      ns.addSwitch(SP, "Clean up here", "Clean up Lua memory while this menu is open (when over the menu threshold).",
        cfg["clean" .. sc.id], DEFAULTS["clean" .. sc.id], setPlain("clean" .. sc.id))
      ns.addSwitch(SP, "Own wait time (press Apply)", "Use its own wait here instead of the default 'Wait before cleanup' in the main section.",
        cfg["waitOwn" .. sc.id], false, function(v) cfg["waitOwn" .. sc.id] = v; save(); nsRefreshIn = 0.3 end)
      if cfg["waitOwn" .. sc.id] then
        ns.addRangeFloat(SP, "Wait before cleanup (s)", "How long this menu must be open before the cleanup freeze runs. 0 = immediately.",
          0, MAX_WAIT_S, 1, "%.0f", cfg["wait" .. sc.id], DEFAULTS["wait" .. sc.id], setPlain("wait" .. sc.id))
      end
    end
    ns.addSwitch(SP, "Show meter", sc.id == "Hud"
        and "Show the Lua memory bar during gameplay. With Limited HUD installed it follows LHUD (Mod Settings -> LHUD -> 'Lua GC Tuner meter')."
        or "Show the Lua memory bar here.", cfg[sc.show], DEFAULTS[sc.show], setMeter(sc.show))
    ns.addRangeFloat(SP, "Background opacity", "Dark panel behind the meter here. 0 = none.",
      0, 1, 0.05, "%.2f", cfg["meterBg" .. sc.id], DEFAULTS["meterBg" .. sc.id], setMeter("meterBg" .. sc.id))
    ns.addSwitch(SP, "Advanced options (press Apply)", "Give the meter its own look here; anything not changed comes from the default look.",
      cfg["meterOwn" .. sc.id], DEFAULTS["meterOwn" .. sc.id], function(v) cfg["meterOwn" .. sc.id] = v; save(); meter.rebuild(); nsRefreshIn = 0.3 end)
    if cfg["meterOwn" .. sc.id] then
      for _, o in ipairs(meter.LOOK) do addLookOption(ns, SP, o, sc.id, setMeter) end
    end
  end
end

local function buildNativeSettings()
  local ns = GetMod("nativeSettings")
  if not ns then return end
  if not ns.pathExists(NS_TAB) then ns.addTab(NS_TAB, "Lua GC Tuner") end
  local NS_MENUS = NS_TAB .. "/menus"   -- v6.7 and older only
  -- remove the last subcategory first so Native Settings' key list never has holes
  for i = #meter.SCREENS, 1, -1 do
    for _, prefix in ipairs({ "/screen", "/meter" }) do
      local SP = NS_TAB .. prefix .. meter.SCREENS[i].id
      if ns.pathExists(SP) then ns.removeSubcategory(SP) end
    end
  end
  if ns.pathExists(NS_TAB .. "/meter") then ns.removeSubcategory(NS_TAB .. "/meter") end
  if ns.pathExists(NS_TAB .. "/dynamic") then ns.removeSubcategory(NS_TAB .. "/dynamic") end
  if ns.pathExists(NS_MENUS) then ns.removeSubcategory(NS_MENUS) end
  if ns.pathExists(NS_SUB) then ns.removeSubcategory(NS_SUB) end
  ns.addSubcategory(NS_SUB, "Lua memory cleanup")
  ns.addSwitch(NS_SUB, "Enabled", "ON: no Lua cleanup during gameplay, clean up in menus instead. OFF: vanilla behaviour.",
    cfg.enabled, DEFAULTS.enabled, function(v) cfg.enabled = v; applyMode(); save() end)
  ns.addSelectorString(NS_SUB, "Menu cleanup threshold as", "Percent of the hard cap (moves with the cap, dynamic or fixed) or an exact size.",
    { "Percent of cap", "Exact MB" }, cfg.thresholdPercent and 1 or 2, DEFAULTS.thresholdPercent and 1 or 2,
    function(i) cfg.thresholdPercent = (i == 1); save(); nsRefreshIn = 0.3 end)
  if cfg.thresholdPercent then
    ns.addRangeInt(NS_SUB, "Menu cleanup threshold (% of cap)",
      "When paused or in a menu, clean up if Lua holds more than this share of the hard cap (1-90 %).",
      1, 90, 1, cfg.menuCollectPct, DEFAULTS.menuCollectPct, function(v) cfg.menuCollectPct = v; clampCfg(); save() end)
  else
    ns.addRangeInt(NS_SUB, "Menu cleanup threshold (MB)",
      "When paused or in a menu, clean up if Lua holds more than this. Limited to 90% of the hard cap when that is lower.",
      50, MAX_CAP_MB, 10, cfg.menuCollectMB, DEFAULTS.menuCollectMB, function(v) cfg.menuCollectMB = v; clampCfg(); save() end)
  end
  local dynOn = cfg.dynamicCap and readSysMem()
  if dynOn then
    ns.addButton(NS_SUB, "Hard cap: dynamic", "The dynamic hard cap is on, so the fixed cap is not used. Turn it off under 'Dynamic hard cap' to set a fixed cap.",
      "Dynamic", 45, function() popup("Hard cap is dynamic: " .. capText() .. ".") end)
  else
  local units = { "GB", "MB" }
  ns.addSelectorString(NS_SUB, "Hard cap unit", "Show and enter the hard cap in gigabytes or megabytes. The slider switches after you apply.",
    units, cfg.capUnit == "MB" and 2 or 1, 1,
    function(i) cfg.capUnit = units[i]; save(); nsRefreshIn = 0.5 end)
  local capDesc = "At this size Lua memory is cleaned up during gameplay (large stutter, with a warning first). 0 = no hard cap. Can't exceed your installed RAM."
  if cfg.capUnit == "MB" then
    -- same widget type in both units: MCM matches settings by type and refuses a type switch
    ns.addRangeFloat(NS_SUB, "Hard cap (MB)", capDesc, 0, maxCapMB(), 16, "%.0f", cfg.hardCapMB, DEFAULTS.hardCapMB,
      function(v) cfg.hardCapMB = v; clampCfg(); save(); nsRefreshIn = 0.5 end)
  else
    ns.addRangeFloat(NS_SUB, "Hard cap (GB)", capDesc, 0, maxCapGB(), 0.05, "%.2f", cfg.hardCapMB / 1024, DEFAULTS.hardCapMB / 1024,
      function(v) cfg.hardCapMB = v * 1024; clampCfg(); save(); nsRefreshIn = 0.5 end)
  end
  end
  ns.addRangeFloat(NS_SUB, "Wait before cleanup (s)",
    "Default for every menu: how long it must be open before the cleanup freeze runs (keeps it out of the menu transition / audio fade). 0 = immediately. Menus can override it below.",
    0, MAX_WAIT_S, 1, "%.0f", cfg.pauseWaitS, DEFAULTS.pauseWaitS, function(v) cfg.pauseWaitS = v; clampCfg(); save() end)
  ns.addRangeFloat(NS_SUB, "Warning lead time (s)", "How long the 'expect a stutter' warning is on screen before a hard-cap or hotkey cleanup freezes the game.",
    0.5, 15, 0.5, "%.1f", cfg.warnLeadS, DEFAULTS.warnLeadS, function(v) cfg.warnLeadS = v; clampCfg(); save() end)
  ns.addSwitch(NS_SUB, "Menu countdown", "While paused in a menu that will clean up, show 'Lua cleanup in N s' at the top of the screen.",
    cfg.menuCountdown, DEFAULTS.menuCountdown, function(v) cfg.menuCountdown = v; save() end)
  ns.addSwitch(NS_SUB, "Cleanup notices", "After a cleanup, show its result (before -> after, time) when you are back in gameplay.",
    cfg.cleanupNotify, DEFAULTS.cleanupNotify, function(v) cfg.cleanupNotify = v; save() end)
  ns.addButton(NS_SUB, "Clean up now", "Clean up Lua memory right now (stutter).",
    "Clean up", 45, function() pendingReason = "manual"; capPending = 0.1 end)
  if ns.addKeyBinding then ns.addKeyBinding(NS_SUB, "Clean up now key", "Press during gameplay to clean up Lua memory (warning first, then the stutter). Same as the CET hotkey.",
    cfg.cleanKey, DEFAULTS.cleanKey, false, function(key) cfg.cleanKey = key or "IK_None"; save() end) end
  ns.addSwitch(NS_SUB, "Memory warnings", "Red on-screen warnings at 90, 95, 99 and 100% of the hard cap.",
    cfg.capWarnings, DEFAULTS.capWarnings, function(v) cfg.capWarnings = v; save() end)
  ns.addSwitch(NS_SUB, "Log cleanups to console", "Print a line in the CET console for each cleanup.",
    cfg.logCleanups, DEFAULTS.logCleanups, function(v) cfg.logCleanups = v; save() end)
  ns.addSwitch(NS_SUB, "Clean up when the CET overlay opens", "Clean up when the CET overlay opens (if over the menu threshold).",
    cfg.trigOverlay, DEFAULTS.trigOverlay, function(v) cfg.trigOverlay = v; save() end)
  local NS_DYN = NS_TAB .. "/dynamic"
  local plugin = readSysMem()
  if not plugin then
    -- MCM hides empty subcategories, so explain with a button
    ns.addSubcategory(NS_DYN, "Dynamic hard cap")
    ns.addButton(NS_DYN, "Dynamic hard cap: unavailable",
      "red4ext/plugins/SysMemInfo/SysMemInfo.dll did not load, so free system memory can't be read. Reinstall Lua GC Tuner (the DLL ships with it). The fixed hard cap is used.",
      "Why?", 45, function() popup("Dynamic hard cap needs red4ext/plugins/SysMemInfo/SysMemInfo.dll (ships with Lua GC Tuner). Reinstall the mod.") end)
    buildMeterSettings(ns)
    buildScreenSettings(ns)
    return
  end
  ns.addSubcategory(NS_DYN, "Dynamic hard cap (follows free system memory)")
  ns.addSwitch(NS_DYN, "Dynamic hard cap", plugin
      and string.format("Hard cap = Lua memory + free RAM/commit - reserve, checked every %d s. Now: %.1f GB RAM / %.1f GB commit free.",
        DYN_EVERY_S, sysMem.availMB / 1024, sysMem.commitMB / 1024)
      or "Needs the SysMemInfo RED4ext plugin (not found). The fixed hard cap is used.",
    cfg.dynamicCap, DEFAULTS.dynamicCap, function(v) cfg.dynamicCap = v; dynAcc = DYN_EVERY_S; save(); nsRefreshIn = 0.3 end)
  if cfg.dynamicCap then
  ns.addRangeFloat(NS_DYN, "Reserve (GB)", "Memory kept free for the game and Windows.", 0, 64, 0.5, "%.1f",
    cfg.dynReserveGB, DEFAULTS.dynReserveGB, function(v) cfg.dynReserveGB = v; clampCfg(); save() end)
  ns.addRangeFloat(NS_DYN, "Minimum cap (GB)", "The dynamic cap never goes below this.", 0.25, maxCapGB(), 0.25, "%.2f",
    cfg.dynMinGB, DEFAULTS.dynMinGB, function(v) cfg.dynMinGB = v; clampCfg(); save() end)
  ns.addRangeFloat(NS_DYN, "Maximum cap (GB)", "The dynamic cap never goes above this (at most your installed RAM).", 0.25, maxCapGB(), 0.25, "%.2f",
    cfg.dynMaxGB, DEFAULTS.dynMaxGB, function(v) cfg.dynMaxGB = v; clampCfg(); save() end)
  ns.addRangeFloat(NS_DYN, "Notify when it moves by (GB)", "Show a notice when the dynamic cap changed at least this much. 0 = never.",
    0, 64, 0.5, "%.1f", cfg.dynNotifyGB, DEFAULTS.dynNotifyGB, function(v) cfg.dynNotifyGB = v; clampCfg(); save() end)
  end
  buildMeterSettings(ns)
  buildScreenSettings(ns)
end

-- Rebuild the settings page when slider ranges changed. Hard cap unit / value changes refresh the open
-- page on their own, 0.5 s after the last change (MCM applies a batch of callbacks at once; plain Native
-- Settings fires on every slider step, so wait for the drag to stop). Never inside a widget callback.
local function rebuildNativeSettings(dt)
  local now = false
  if nsRefreshIn then
    nsRefreshIn = nsRefreshIn - dt
    if nsRefreshIn > 0 then return end
    nsRefreshIn, now = nil, true
  end
  if not nsDirty and not now then return end
  local ns = GetMod("nativeSettings")
  if not ns then nsDirty = false; return end
  if ns.currentTab == NS_TAB:sub(2) and not now then return end   -- other changes wait for the page to close
  nsDirty = false
  pcall(buildNativeSettings)
  mcmReloadPending = true
end

-- Mod Configuration Menu caches each mod's settings; after a rebuild ask it to re-read ours so the open
-- page shows the new sliders. Pending (unapplied) changes block the reload, so retry until they're gone.
local MCM_KEY = "cet:LuaGCTuner"
local function pumpMcmReload()
  if not mcmReloadPending then return end
  local api = GetMod("ModConfigurationMenuAPI")
  if type(api) ~= "table" or type(api.reloadMod) ~= "function" then mcmReloadPending = false; return end
  local okD, diag = pcall(api.getDiagnostics)
  if not okD or type(diag) ~= "table" or diag.activeModKey ~= MCM_KEY then
    mcmReloadPending = false   -- our page isn't open: MCM re-reads it when it opens
    return
  end
  local okH, drafts = pcall(api.hasDrafts, MCM_KEY)
  if okH and drafts then return end
  local ok, _, err = pcall(api.reloadMod, MCM_KEY)
  if ok and err == nil then mcmReloadPending = false end
end

local watchCleanKey   -- defined below, next to the CET hotkey
registerForEvent("onInit", function()
  readSysMem()   -- before load(): the installed RAM limits the caps
  load()
  applyMode()
  watchMenus()
  meter.init({
    cfg = cfg, heapMB = heapMB, capMB = capMB, fmtMB = fmtMB,
    menuThresholdMB = menuThresholdMB,
    freezeText = function(mb) return (stutterText(mb):gsub("^~", "")) end,
    hudVisible = function() return lhudState().visible end,
    hudOpacity = function() return lhudState().opacity end,
    state = function()
      return { paused = lastPaused, menuKind = menuKind, pausePage = lastPaused and pausePage() or "list", loading = noPlayer(), countdown = countdown,
        dynamic = cfg.dynamicCap and dynCapMB ~= nil }
    end,
  })
  readSysMem()   -- probe the SysMemInfo plugin once
  if not watchCleanKey() then print("[LuaGCTuner] Codeware not found: the Native Settings key is inactive (CET hotkey still works).") end
  buildNativeSettings()
  print(string.format("[LuaGCTuner v6.13] %s; menu cleanup >%d MB, gameplay cleanup %s, hard cap %s, heap %.0f MB",
    cfg.enabled and "background GC stopped" or "DISABLED (vanilla GC)", menuThresholdMB(),
    cfg.cleanHud and (cfg.hudCleanPct .. "% of cap") or "off", capText(), heapMB()))
end)

local function requestCleanNow()
  if capPending or not cfg.enabled then return end
  local mb = heapMB()
  if mb <= (liveMB or 0) + 16 then
    popup(string.format("Lua memory is already clean (%s).", fmtMB(mb)))
    return
  end
  popup(string.format("Cleaning up Lua memory (%s): expect a stutter (%s).", fmtMB(mb), stutterText(mb)))
  pendingReason = "hotkey"
  capPending = cfg.warnLeadS
end

registerHotkey("lgc_clean_now", "Clean up Lua memory now", requestCleanNow)

-- Native Settings / Mod Config Menu key: Codeware's Input/Key callback (event driven, no polling).
-- Only presses during gameplay count, so binding the key in the settings page doesn't trigger it.
local keyListener = nil
watchCleanKey = function()
  local hasCodeware = pcall(function() return Codeware.Version() end)
  if not hasCodeware then return false end
  local ok = pcall(function()
    keyListener = NewProxy({
      OnKeyInput = {
        args = { "handle:KeyInputEvent" },
        callback = function(event)
          if cfg.cleanKey == "IK_None" or lastPaused then return end
          if event:GetKey().value ~= cfg.cleanKey then return end
          if event:GetAction().value ~= "IACT_Press" then return end
          requestCleanNow()
        end,
      },
    })
    Game.GetCallbackSystem():RegisterCallback("Input/Key", keyListener:Target(), keyListener:Function("OnKeyInput"), true)
  end)
  return ok
end

local overlayOpen = false
registerForEvent("onOverlayOpen", function()
  overlayOpen = true
  if cfg.enabled and cfg.trigOverlay and heapMB() > menuThresholdMB() then fullCollect("CET overlay") end
end)
registerForEvent("onOverlayClose", function() overlayOpen = false; nsDirty = true end)

-- CET overlay window
-- grey out a block of ImGui controls (BeginDisabled when CET's ImGui has it, else just dimmed)
local function greyBegin(on)
  if not on then return nil end
  if ImGui.BeginDisabled then ImGui.BeginDisabled(true); return "disabled" end
  ImGui.PushStyleVar(ImGuiStyleVar.Alpha, 0.4); return "alpha"
end
local function greyEnd(t)
  if t == "disabled" then ImGui.EndDisabled() elseif t == "alpha" then ImGui.PopStyleVar(1) end
end

local function drawCountdown()
  local w = 1920
  pcall(function() w = GetDisplayResolution() end)
  ImGui.SetNextWindowPos(w / 2, 60, ImGuiCond.Always, 0.5, 0)
  ImGui.SetNextWindowBgAlpha(0.75)
  local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
    + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoSavedSettings
    + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoNav
  if ImGui.Begin("##LuaGCTunerCountdown", flags) then
    local left = math.max(0, countdown)
    if left > 0.25 then
      ImGui.Text(string.format("Lua memory cleanup in %d s  (%s, %s freeze)", math.ceil(left), fmtMB(countdownMB),
        stutterText(countdownMB)))
    else
      ImGui.Text(string.format("Cleaning up Lua memory (%s)...", fmtMB(countdownMB)))
    end
  end
  ImGui.End()
end

registerForEvent("onDraw", function()
  if countdown and cfg.menuCountdown and lastPaused and not meter.showsCountdown() then drawCountdown() end
  if not overlayOpen then return end
  if ImGui.Begin("Lua GC Tuner", ImGuiWindowFlags.AlwaysAutoResize) then
    local mb = heapMB()
    local pct = capMB() > 0 and string.format(" (%.0f%% of %s cap)", mb / capMB() * 100, capText()) or ""
    ImGui.Text(string.format("Lua heap: %s%s   %s", fmtMB(mb), pct,
      not cfg.enabled and "(vanilla GC)" or (capMode and "(background GC running)" or "(background GC parked)")))
    ImGui.Text(string.format("Cleanups: %d   last: %s, %.0f -> %.0f MB in %.0f ms   live ~%.0f MB",
      stats.count, stats.lastReason, stats.lastBefore, stats.lastAfter, stats.lastMs, liveMB or 0))
    ImGui.TextDisabled("Tip: Ctrl+click any slider to type an exact value.")
    ImGui.Separator()
    local changed, meterChanged
    local function slider(label, value, lo, hi, fmt)
      local v, c = ImGui.SliderFloat(label, value, lo, hi, fmt)
      return c and math.max(lo, math.min(hi, v)) or nil
    end
    local v, c = ImGui.Checkbox("Enabled", cfg.enabled)
    if c then cfg.enabled = v; applyMode(); changed = true end

    ImGui.PushItemWidth(240)
    ImGui.Text("Menu threshold as:"); ImGui.SameLine()
    if ImGui.RadioButton("% of cap", cfg.thresholdPercent) then cfg.thresholdPercent = true; changed = true end
    ImGui.SameLine()
    if ImGui.RadioButton("Exact MB", not cfg.thresholdPercent) then cfg.thresholdPercent = false; changed = true end
    if cfg.thresholdPercent then
      local m = slider("Menu cleanup threshold (% of cap)", cfg.menuCollectPct, 1, 90, "%.0f %%")
      if m then cfg.menuCollectPct = m; changed = true end
    else
      local m = slider("Menu cleanup threshold (MB)", cfg.menuCollectMB, 50, MAX_CAP_MB, "%.0f")
      if m then cfg.menuCollectMB = m; changed = true end
    end
    ImGui.SameLine(); ImGui.TextDisabled("= " .. fmtMB(menuThresholdMB()) .. " now")

    local dynOn = cfg.dynamicCap and sysMem.ok
    local grey = greyBegin(dynOn)
    ImGui.Text("Hard cap unit:"); ImGui.SameLine()
    if ImGui.RadioButton("GB", cfg.capUnit == "GB") and not dynOn then cfg.capUnit = "GB"; changed = true end
    ImGui.SameLine()
    if ImGui.RadioButton("MB", cfg.capUnit == "MB") and not dynOn then cfg.capUnit = "MB"; changed = true end
    if cfg.capUnit == "MB" then
      local h = slider("Hard cap (MB)", cfg.hardCapMB, 0, maxCapMB(), "%.0f")
      if h and not dynOn then cfg.hardCapMB = h; changed = true end
    else
      local h = slider("Hard cap (GB)", cfg.hardCapMB / 1024, 0, maxCapGB(), "%.2f")
      if h and not dynOn then cfg.hardCapMB = h * 1024; changed = true end
    end
    greyEnd(grey)
    ImGui.TextDisabled(dynOn and ("Fixed cap not used: dynamic cap is on (" .. capText() .. ").")
      or string.format("0 = no hard cap. Max %s (installed RAM).", fmtMB(maxCapMB())))

    local pw = slider("Wait before cleanup (s, default)", cfg.pauseWaitS, 0, MAX_WAIT_S, "%.0f")
    if pw then cfg.pauseWaitS = pw; changed = true end
    ImGui.PopItemWidth()
    local ov, oc = ImGui.Checkbox("Clean up when the CET overlay opens", cfg.trigOverlay)
    if oc then cfg.trigOverlay = ov; changed = true end
    ImGui.TextDisabled("Current menu: " .. (menuKind or "none / other")
      .. (menuKind == "pause" and (" (page: " .. (pausePageName ~= "" and pausePageName or "-") .. ")") or ""))
    ImGui.Separator()
    if not sysMem.ok then
      ImGui.TextDisabled("Dynamic hard cap unavailable: SysMemInfo.dll did not load (reinstall Lua GC Tuner).")
    else
      local dv, dc = ImGui.Checkbox("Dynamic hard cap (follows free system memory)", cfg.dynamicCap)
      if dc then cfg.dynamicCap = dv; dynAcc = DYN_EVERY_S; changed = true end
      ImGui.TextDisabled(string.format("Free: %.1f GB RAM, %.1f GB commit of %.0f GB RAM. Dynamic cap: %s",
        sysMem.availMB / 1024, sysMem.commitMB / 1024, sysMem.totalMB / 1024, dynCapMB and fmtMB(dynCapMB) or "-"))
      local g2 = greyBegin(not cfg.dynamicCap)
      ImGui.PushItemWidth(240)
      local r1 = slider("Reserve (GB)", cfg.dynReserveGB, 0, 64, "%.1f")
      if r1 and cfg.dynamicCap then cfg.dynReserveGB = r1; changed = true end
      local r2 = slider("Minimum cap (GB)", cfg.dynMinGB, 0.25, maxCapGB(), "%.2f")
      if r2 and cfg.dynamicCap then cfg.dynMinGB = r2; changed = true end
      local r3 = slider("Maximum cap (GB)", cfg.dynMaxGB, 0.25, maxCapGB(), "%.2f")
      if r3 and cfg.dynamicCap then cfg.dynMaxGB = r3; changed = true end
      local r4 = slider("Notify when it moves by (GB)", cfg.dynNotifyGB, 0, 64, "%.1f")
      if r4 and cfg.dynamicCap then cfg.dynNotifyGB = r4; changed = true end
      ImGui.PopItemWidth()
      greyEnd(g2)
    end
    ImGui.Separator()
    ImGui.PushItemWidth(240)
    local wl = slider("Warning lead time (s)", cfg.warnLeadS, 0.5, 15, "%.1f")
    if wl then cfg.warnLeadS = wl; changed = true end
    ImGui.PopItemWidth()
    local mc, mcc = ImGui.Checkbox("Menu countdown", cfg.menuCountdown)
    if mcc then cfg.menuCountdown = mc; changed = true end
    local cn, cnc = ImGui.Checkbox("Cleanup notices (shown back in gameplay)", cfg.cleanupNotify)
    if cnc then cfg.cleanupNotify = cn; changed = true end
    ImGui.TextDisabled("Clean-now key: Settings > Mods > Lua GC Tuner, or CET overlay > Bindings.")
    local w, c5 = ImGui.Checkbox("Memory warnings (90/95/99/100% of cap)", cfg.capWarnings)
    if c5 then cfg.capWarnings = w; changed = true end
    local l, c6 = ImGui.Checkbox("Log cleanups to console", cfg.logCleanups)
    if c6 then cfg.logCleanups = l; changed = true end

    if ImGui.CollapsingHeader("Meter and screens") then
      local function check(key, label, isMeter)
        local cv, cc = ImGui.Checkbox(label, cfg[key])
        if cc then cfg[key] = cv; changed = true; if isMeter ~= false then meterChanged = true end end
      end
      local anchorLabels = {}
      for i, a in ipairs(meter.ANCHORS) do anchorLabels[i] = a.label end
      local function lookControls(suffix)
        for _, o in ipairs(meter.LOOK) do
          local k = "meter" .. o.f .. suffix
          local id = o.label .. "##" .. k
          if o.kind == "anchor" then
            local i, c2 = ImGui.Combo(id, cfg[k] - 1, anchorLabels, #anchorLabels)
            if c2 then cfg[k] = i + 1; changed = true; meterChanged = true end
          elseif o.kind == "int" or o.kind == "float" then
            local nv = slider(id, cfg[k], o.lo, o.hi, o.kind == "int" and "%.0f" or "%.2f")
            if nv then cfg[k] = nv; changed = true; meterChanged = true end
          else
            check(k, id)
          end
        end
      end
      ImGui.PushItemWidth(240)
      check("meterEnabled", "Show meter (master switch)")
      if ImGui.TreeNode("Default look##deflook") then lookControls(""); ImGui.TreePop() end
      for _, sc in ipairs(meter.SCREENS) do
        if ImGui.TreeNode(sc.label .. "##scr" .. sc.id) then
          if sc.noClean then
            ImGui.TextDisabled("Cleanup here follows the Esc menu entry.")
          elseif sc.id == "Hud" then
            check("cleanHud", "Clean up during gameplay##hudclean", false)
            local p = slider("Clean up at (% of cap)##hudpct", cfg.hudCleanPct, 10, 99, "%.0f %%")
            if p then cfg.hudCleanPct = p; changed = true end
            local ws = slider("Warning before cleanup (s)##hudwarn", cfg.hudWarnS, 0.5, 30, "%.1f")
            if ws then cfg.hudWarnS = ws; changed = true end
            check("hudSkipCombat", "Not during combat##hudcombat", false)
            check("hudSkipDriving", "Not while driving##huddrive", false)
          else
            check("clean" .. sc.id, "Clean up here##clean" .. sc.id, false)
            check("waitOwn" .. sc.id, "Own wait time##waitown" .. sc.id, false)
            if cfg["waitOwn" .. sc.id] then
              local wv = slider("Wait before cleanup (s)##wait" .. sc.id, cfg["wait" .. sc.id], 0, MAX_WAIT_S, "%.0f")
              if wv then cfg["wait" .. sc.id] = wv; changed = true end
            end
          end
          check(sc.show, "Show meter##show" .. sc.id)
          if sc.id == "Hud" then
            if lhud.sys then
              ImGui.TextDisabled(string.format("Limited HUD: linked, meter %s, opacity %.2f. Active: %s",
                lhud.visible and "shown" or "hidden", lhud.opacity, lhud.why ~= "" and lhud.why or "none"))
            else
              ImGui.TextDisabled("Limited HUD: not linked (not installed, or no game loaded): meter always shown")
            end
          end
          local bv = slider("Background opacity##bg" .. sc.id, cfg["meterBg" .. sc.id], 0, 1, "%.2f")
          if bv then cfg["meterBg" .. sc.id] = bv; changed = true; meterChanged = true end
          check("meterOwn" .. sc.id, "Advanced options##own" .. sc.id)
          if cfg["meterOwn" .. sc.id] then lookControls(sc.id) end
          ImGui.TreePop()
        end
      end
      ImGui.PopItemWidth()
    end

    if ImGui.Button("Clean up now") then fullCollect("manual") end
    ImGui.SameLine()
    if ImGui.Button("Test warning") then popup("Lua GC Tuner: test warning") end
    ImGui.SameLine()
    if ImGui.Button("Reset to defaults") then
      for k, dv in pairs(DEFAULTS) do cfg[k] = dv end; applyMode(); changed = true; meterChanged = true
    end
    if changed then clampCfg(); save() end
    if meterChanged then meter.rebuild() end
  end
  ImGui.End()
end)

registerForEvent("onUpdate", function(dt)
  rebuildNativeSettings(dt)
  pumpMcmReload()
  meter.update(dt)
  if not cfg.enabled then return end

  dynAcc = dynAcc + dt
  if dynAcc >= DYN_EVERY_S then dynAcc = 0; updateDynamicCap() end

  -- queued notices go out one at a time, only during gameplay (the HUD is hidden in menus)
  noticeGap = noticeGap - dt
  if #notices > 0 and noticeGap <= 0 and not lastPaused and not noPlayer() then
    showNow(table.remove(notices, 1))
    noticeGap = 3
  end

  if armedReason then
    local reason = armedReason
    armedReason, countdown = nil, nil
    if lastPaused then
      if capMode then capMode = false end
      fullCollect(reason)
      return
    end
  end

  -- forced hard-cap cleanup, a moment after its warning was shown
  if capPending then
    capPending = capPending - dt
    countdown, countdownMB = math.max(0, capPending), heapMB()   -- the meter shows it too
    if capPending <= 0 then
      countdown = nil
      local reason = pendingReason
      fullCollect(reason)
      if reason == "hard cap" and capMB() > 0 and heapMB() >= capMB() * MENU_MAX_FRAC then
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
  if countdown then countdown = menuWait(menuKind) - pausedFor - acc end
  if acc < CHECK_EVERY_S then return end
  local step = acc
  acc = 0
  local mb = heapMB()
  local paused = isPaused(step)
  if paused then pausedFor = pausedFor + step else pausedFor = 0 end
  lastPaused = paused
  local cap = capMB()
  local frac = cap > 0 and mb / cap or 0
  local menuMB = menuThresholdMB()

  local loading = noPlayer()
  local menuOn = paused and not loading and menuCleans(menuKind)
  local wait = menuWait(menuKind)
  local menuOk = loading or (menuOn and pausedFor >= wait)
  local due = mb > menuMB and mb > stats.lastAfter + MIN_GROWTH_MB
  if due and menuOn then
    countdown, countdownMB = wait - pausedFor, mb
  else
    countdown = nil
  end
  if due and menuOk and menuOn and cfg.menuCountdown then
    countdown = 0
    armedReason = kindName(menuKind)
    return
  end
  if due and menuOk then
    countdown = nil
    if capMode then capMode = false end
    fullCollect(loading and "loading screen" or kindName(menuKind))
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

  -- optional gameplay cleanup, below the hard cap: warning, short wait, then the cleanup
  if cfg.cleanHud and frac * 100 >= cfg.hudCleanPct and frac < 1.0 and mb > stats.lastAfter + MIN_GROWTH_MB
    and not gameplayBusy() then
    popup(string.format("Lua memory at %d%% of the cap (%s): cleaning up in %d s, expect a stutter (%s).",
      math.floor(frac * 100 + 0.5), fmtMB(mb), math.ceil(cfg.hudWarnS), stutterText(mb)))
    pendingReason = "gameplay"
    capPending = cfg.hudWarnS
    return
  end

  if frac >= 1.0 then
    popup(string.format("Lua memory FULL (%s of %s). Cleaning up now: expect a large stutter (%s).",
      fmtMB(mb), capText(), stutterText(mb)))
    warnedLevel = 1.0
    pendingReason = "hard cap"
    capPending = cfg.warnLeadS
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

registerForEvent("onShutdown", function() meter.shutdown() end)
