-- Native ink meter for Lua GC Tuner: icon + "LUA MEMORY" label, value / cap + percent, a filling bar with a
-- marker at the menu-cleanup threshold, the cap mode (static / dynamic) and the cleanup countdown with a
-- freeze estimate. Lives on an overlay layer above the menu (inkGameNotificationsLayer, fallback inkWatermarksLayer, then inkMenuLayer) while a chosen menu is open and, optionally, on inkHUDLayer during
-- gameplay. Every option has a default and can be overridden per screen ("Advanced options").
-- Text stays sharp: everything is built at its final size (no SetScale, which blurs ink text).

local M = {}

local FONT = "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"
local ICON_ATLAS = "base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas"
local ROOT_NAME = "LuaGCTunerMeter"
-- v6.14: menu meters no longer live on inkMenuLayer. A widget there shares the menu's virtual window, and every
-- SetText / SetMargin re-ran that window's layout, which re-placed the backpack tooltip each refresh (the
-- tooltip "flicker"). Menus now use an overlay layer with its own layout; inkMenuLayer is the last fallback.
-- Widgets are also only touched when a value really changes.
local MENU_LAYERS = { "inkGameNotificationsLayer", "inkWatermarksLayer", "inkMenuLayer" }
local UPDATE_EVERY_S = 0.2   -- text / bar refresh while visible
local CHECK_EVERY_S = 0.1    -- which screen / layer the meter belongs on

-- game types (HDRColor, ink classes) only exist once CET runs onInit, so colors are made in M.init
local function rgba(r, g, b, a) return HDRColor.new({ Red = r, Green = g, Blue = b, Alpha = a or 1 }) end
local COL = {}
local function makeColors()
  COL.red = rgba(1.1761, 0.3809, 0.3476)        -- game "panel red"
  COL.faintRed = rgba(0.2824, 0.1137, 0.1373)
  COL.mildRed = rgba(0.6824, 0.2314, 0.2118)
  COL.blue = rgba(0.3686, 0.9647, 1.0)           -- game "main blue"
  COL.yellow = rgba(1.1192, 0.8441, 0.2565)
  COL.bg = rgba(0.054902, 0.054902, 0.090196)    -- game dark panel background
  COL.green = rgba(0.3412, 1.0, 0.5216)          -- gameplay-cleanup marker
end

local ANCHORS = {
  { label = "Top right",    px = 1,   py = 0 },
  { label = "Top left",     px = 0,   py = 0 },
  { label = "Top center",   px = 0.5, py = 0 },
  { label = "Bottom right", px = 1,   py = 1 },
  { label = "Bottom left",  px = 0,   py = 1 },
  { label = "Bottom center", px = 0.5, py = 1 },   -- new anchors go last so saved choices keep their meaning
  { label = "Center",        px = 0.5, py = 0.5 },
}
M.ANCHORS = ANCHORS

-- in settings order; each one is an entry with its cleanup + meter options
-- look = this screen's own defaults (its Advanced options start on with these values)
local SCREENS = {
  { id = "Pause",     show = "meterPause",     label = "Esc menu (Resume / Save / Load list)",
    look = { Anchor = 3, X = -1340, Y = 360, Scale = 1.0, Width = 460, EtaAlways = true } },
  { id = "Mcm",       show = "meterMcm",       noClean = true,
    label = "Mod Configuration Menu",
    look = { Anchor = 3, X = -360, Y = 100, Scale = 1.25, Width = 610, EtaAlways = true } },
  { id = "Map",       show = "meterMap",       label = "Map" },
  { id = "Inventory", show = "meterInventory", label = "Inventory & character (backpack, cyberware, crafting, perks)" },
  { id = "Journal",   show = "meterJournal",   label = "Journal & messages (quests, shards, codex)" },
  { id = "Other",     show = "meterOther",     label = "Other pauses (stash, vendor, photo mode, fast travel, ...)" },
  { id = "Hud",       show = "meterGameplay",  label = "Gameplay (no menu open)" },
}
M.SCREENS = SCREENS
local KIND_SCREEN = { inventory = "Inventory", map = "Map", journal = "Journal", pause = "Pause" }

-- look options every screen can override
local LOOK = {
  { f = "Anchor",     d = 1,    kind = "anchor", label = "Position from" },
  { f = "X",          d = 1290, kind = "int",    label = "Offset X", lo = -3000, hi = 3000, step = 5 },
  { f = "Y",          d = 50,   kind = "int",    label = "Offset Y", lo = -2000, hi = 2000, step = 5 },
  { f = "Scale",      d = 0.8,  kind = "float",  label = "Scale", lo = 0.4, hi = 2.5, step = 0.05 },
  { f = "Width",      d = 460,  kind = "int",    label = "Bar width", lo = 200, hi = 1400, step = 10 },
  { f = "Icon",       d = true, kind = "bool",   label = "Show icon" },
  { f = "Percent",    d = true, kind = "bool",   label = "Show percentage" },
  { f = "Mode",       d = true, kind = "bool",   label = "Show cap mode" },
  { f = "Countdown",  d = true, kind = "bool",   label = "Show countdown" },
  { f = "Eta",        d = true, kind = "bool",   label = "Show freeze estimate" },
  { f = "EtaAlways",  d = false, kind = "bool",  label = "Freeze estimate even when no cleanup is due" },
}
M.LOOK = LOOK

M.DEFAULTS = {
  meterEnabled     = true,
  meterAdvanced    = false,   -- "Advanced options" in Native Settings
  meterPause       = true,
  meterMcm         = true,
  meterInventory   = true,
  meterMap         = true,
  meterJournal     = true,
  meterOther       = false,
  meterGameplay    = false,
}
for _, o in ipairs(LOOK) do M.DEFAULTS["meter" .. o.f] = o.d end
for _, sc in ipairs(SCREENS) do   -- per screen: override off unless the screen has its own look
  M.DEFAULTS["meterOwn" .. sc.id] = sc.look ~= nil
  M.DEFAULTS["meterBg" .. sc.id] = sc.id == "Map" and 0.85 or 0   -- background panel opacity (0 = none)
  for _, o in ipairs(LOOK) do
    local v = sc.look and sc.look[o.f]
    if v == nil then v = o.d end
    M.DEFAULTS["meter" .. o.f .. sc.id] = v
  end
end

local ctx            -- functions/state handed in by init.lua
local cfg
local w = nil        -- current widgets
local acc, checkAcc = 0, CHECK_EVERY_S
local wantLayer, wantScreen = nil, nil
local failedKey = nil   -- a build that failed is retried on the next screen check (10 Hz), not every frame

-- option value for a screen: its override when "Override" is on, else the default
local function opt(screen, f)
  if screen and cfg["meterOwn" .. screen] then return cfg["meter" .. f .. screen] end
  return cfg["meter" .. f]
end
M.opt = opt

local function text(parent, size, style, color, x, y)
  local t = inkText.new()
  t:SetFontFamily(FONT)
  pcall(function() t:SetFontStyle(style) end)
  t:SetFontSize(math.floor(size + 0.5))
  t:SetLetterCase(textLetterCase.UpperCase)
  t:SetTintColor(color)
  t:SetAnchor(inkEAnchor.TopLeft)
  t:SetMargin(inkMargin.new({ left = math.floor(x + 0.5), top = math.floor(y + 0.5), right = 0, bottom = 0 }))
  t:SetText("")
  t:Reparent(parent, -1)
  return t
end

local function rect(parent, x, y, width, height, color, opacity, shear)
  local r = inkRectangle.new()
  r:SetAnchor(inkEAnchor.TopLeft)
  r:SetMargin(inkMargin.new({ left = x, top = y, right = 0, bottom = 0 }))
  r:SetSize(width, height)
  r:SetTintColor(color)
  r:SetOpacity(opacity or 1)
  if shear then pcall(function() r:SetShear(Vector2.new({ X = 0.5, Y = 0 })) end) end
  r:Reparent(parent, -1)
  return r
end

-- the ink layer by name; falls back to scanning the layer list (by class) when GetLayer has nothing
local function findLayer(layerName)
  local sys = Game.GetInkSystem()
  if not sys then return nil end
  local ok, layer = pcall(function() return sys:GetLayer(layerName) end)
  if ok and layer then return layer end
  local found = nil
  pcall(function()
    for _, l in ipairs(sys:GetLayers()) do
      if l and l:GetClassName().value == layerName then found = l; break end
    end
  end)
  return found
end

local lastErr = nil
local function build(layerName, screen)
  local ok, err = pcall(function()
    local layer, actual = nil, layerName
    if layerName == "menu" then
      local list = {}
      if type(cfg.meterMenuLayer) == "string" and cfg.meterMenuLayer ~= "" and cfg.meterMenuLayer ~= "auto" then
        list[1] = cfg.meterMenuLayer
      end
      for _, n in ipairs(MENU_LAYERS) do list[#list + 1] = n end
      for _, n in ipairs(list) do
        local l = findLayer(n)
        local hasWindow = l and pcall(function() return l:GetVirtualWindow() end)
        if l and hasWindow and l:GetVirtualWindow() then layer, actual = l, n; break end
      end
    else
      layer = findLayer(layerName)
    end
    if not layer then error("layer " .. layerName .. " not available", 0) end
    local vw = layer:GetVirtualWindow()
    if not vw then error("layer " .. layerName .. " has no window", 0) end
    pcall(function() vw:RemoveChildByName(ROOT_NAME) end)

    -- Offsets / sizes are 4K units; the layer may be any size (menus are a letterboxed 16:9 window), so
    -- convert with its height and place from the top-left (right / center anchors are not honoured there).
    local W, H = 3840, 2160
    pcall(function()
      local size = vw:GetSize()
      if size and size.X and size.X > 0 and size.Y > 0 then W, H = size.X, size.Y end
    end)
    local s = opt(screen, "Scale") * (H / 2160)   -- applied to every size below, never with SetScale
    local hasIcon = opt(screen, "Icon")
    local secondRow = opt(screen, "Mode") or opt(screen, "Countdown")
    local pad, icon = 18 * s, hasIcon and 52 * s or 0
    local x0 = pad + (icon > 0 and icon + 16 * s or 0)
    local barW = opt(screen, "Width") * s
    local width = x0 + barW + pad
    local height = (secondRow and 132 or 96) * s

    local a = ANCHORS[opt(screen, "Anchor")] or ANCHORS[1]
    local offX, offY = opt(screen, "X") * (H / 2160), opt(screen, "Y") * (H / 2160)
    local x = a.px == 1 and (W - offX - width) or (a.px == 0.5 and (W - width) / 2 + offX) or offX
    local y = a.py == 1 and (H - offY - height) or (a.py == 0.5 and (H - height) / 2 + offY) or offY
    -- centered anchors: 0 = centered, negative = left / up, positive = right / down; always kept on screen
    x = math.max(0, math.min(W - width, x))
    y = math.max(0, math.min(H - height, y))

    local root = inkCanvas.new()
    root:SetName(CName.new(ROOT_NAME))
    root:SetAnchor(inkEAnchor.TopLeft)
    root:SetSize(width, height)
    root:SetMargin(inkMargin.new({ left = math.floor(x + 0.5), top = math.floor(y + 0.5), right = 0, bottom = 0 }))

    local new = { root = root, layer = actual, screen = screen, key = layerName .. ":" .. tostring(screen),
      barW = barW, s = s, x0 = x0, pad = pad, cache = {} }
    new.bg = rect(root, 0, 0, width, height, COL.bg, cfg["meterBg" .. screen] or 0)
    new.bgEdge = rect(root, 0, 0, 4 * s, height, COL.red, 0.9)
    if icon > 0 then
      local img = inkImage.new()
      img:SetAtlasResource(ResRef.FromName(ICON_ATLAS))
      img:SetTexturePart("wait")
      img:SetAnchor(inkEAnchor.TopLeft)
      img:SetMargin(inkMargin.new({ left = pad, top = pad + 4 * s, right = 0, bottom = 0 }))
      img:SetSize(icon, icon)
      img:SetTintColor(COL.red)
      img:Reparent(root, -1)
      new.icon = img
    end
    new.label = text(root, 30 * s, "Medium", COL.red, x0, pad - 4 * s)
    new.label:SetText("Lua memory")
    new.value = text(root, 30 * s, "Semi-Bold", COL.blue, x0 + 190 * s, pad - 4 * s)
    new.barBg = rect(root, x0, pad + 44 * s, barW, 12 * s, COL.faintRed, 0.6, true)
    new.fill = rect(root, x0, pad + 46 * s, 1, 8 * s, COL.red, 1, true)
    new.markTop = pad + 38 * s
    new.mark = rect(root, x0, new.markTop, 3 * s, 24 * s, COL.blue, 0.9)          -- menu cleanup threshold
    new.hudMark = rect(root, x0, new.markTop, 3 * s, 24 * s, COL.green, 0.9)      -- gameplay cleanup threshold
    new.mode = text(root, 24 * s, "Medium", COL.mildRed, x0, pad + 70 * s)
    new.count = text(root, 24 * s, "Semi-Bold", COL.yellow, x0 + barW * 0.36, pad + 70 * s)

    root:Reparent(vw, -1)
    w = new
  end)
  if not ok then
    if tostring(err) ~= lastErr then   -- log each distinct failure once, not every frame
      lastErr = tostring(err)
      print("[LuaGCTuner] meter: could not build (" .. lastErr .. "); retrying quietly")
    end
    w = nil
  else
    lastErr = nil
  end
  return ok
end

local function destroy()
  if not w then return end
  pcall(function()
    findLayer(w.layer):GetVirtualWindow():RemoveChild(w.root)
  end)
  w = nil
end

-- returns layer, screen id (nil = hidden)
local function wanted()
  if not cfg.meterEnabled or not cfg.enabled then return nil end
  local s = ctx.state()
  if s.loading then return nil end
  if s.paused then
    local screen = KIND_SCREEN[s.menuKind] or "Other"
    if screen == "Pause" and s.pausePage == "mcm" then screen = "Mcm" end   -- Mod Configuration Menu
    if screen == "Pause" and s.pausePage == "other" then return nil end    -- settings / save / load pages: hidden
    if not cfg[screen == "Other" and "meterOther" or ("meter" .. screen)] then return nil end
    return "menu", screen   -- resolved to a real layer in build(): cfg.meterMenuLayer, then MENU_LAYERS
  end
  if cfg.meterGameplay and ctx.hudVisible() then return "inkHUDLayer", "Hud" end
  return nil
end

-- change-only setters: each widget property is written only when its value differs from the last write
-- (every ink write invalidates layout, and the meter refreshes 5 times a second)
local function changed(key, value)
  if w.cache[key] == value then return false end
  w.cache[key] = value
  return true
end
local function setText(widget, key, s) if changed(key .. ".text", s) then widget:SetText(s) end end
local function setVisible(widget, key, v) if changed(key .. ".vis", v) then widget:SetVisible(v) end end
local function setOpacity(widget, key, o)
  o = math.floor(o * 100 + 0.5) / 100
  if changed(key .. ".op", o) then widget:SetOpacity(o) end
end
local function setLeft(widget, key, left, top)
  left = math.floor(left + 0.5)
  if changed(key .. ".left", left) then
    widget:SetMargin(inkMargin.new({ left = left, top = top, right = 0, bottom = 0 }))
  end
end

local function refresh()
  if not w then return end
  local sc = w.screen
  local st = ctx.state()
  local mb, cap = ctx.heapMB(), ctx.capMB()
  local frac = cap > 0 and math.min(1, mb / cap) or 0
  local value = ctx.fmtMB(mb) .. (cap > 0 and (" / " .. ctx.fmtMB(cap)) or "")
  if opt(sc, "Percent") and cap > 0 then value = value .. string.format("   %d%%", math.floor(frac * 100 + 0.5)) end
  setText(w.value, "value", value)
  local fillW = math.floor(math.max(1, w.barW * frac) + 0.5)
  if changed("fill.w", fillW) then w.fill:SetSize(fillW, 8 * w.s) end
  local hot = frac >= 0.9
  if changed("fill.hot", hot) then w.fill:SetTintColor(hot and COL.yellow or COL.red) end
  local thr = cap > 0 and math.min(1, ctx.menuThresholdMB() / cap) or 0
  setVisible(w.mark, "mark", cap > 0)
  setLeft(w.mark, "mark", w.x0 + w.barW * thr, w.markTop)
  local hudOn = cfg.cleanHud and cap > 0
  setVisible(w.hudMark, "hudMark", hudOn == true)
  if hudOn then
    setLeft(w.hudMark, "hudMark", w.x0 + w.barW * math.min(1, cfg.hudCleanPct / 100), w.markTop)
  end
  setVisible(w.mode, "mode", opt(sc, "Mode") == true)
  setText(w.mode, "mode", cap <= 0 and "No hard cap" or (st.dynamic and "Dynamic cap" or "Static cap"))
  local cd = st.countdown
  local always = opt(sc, "EtaAlways")
  setVisible(w.count, "count", (opt(sc, "Countdown") and cd ~= nil) or (cd == nil and always) or false)
  if cd == nil and always then
    setText(w.count, "count", "~" .. ctx.freezeText(mb) .. " freeze if cleaned now")
  end
  if cd then
    local eta = opt(sc, "Eta")
    setText(w.count, "count", cd > 0.25
      and string.format("Cleanup in %d s%s", math.ceil(cd), eta and (", ~" .. ctx.freezeText(mb) .. " freeze") or "")
      or ("Cleaning up" .. (eta and (" ~" .. ctx.freezeText(mb)) or "") .. "..."))
  end
  if w.layer == "inkHUDLayer" then setOpacity(w.root, "root", ctx.hudOpacity()) end
  local bgOpacity = cfg["meterBg" .. sc] or 0
  setVisible(w.bg, "bg", bgOpacity > 0)
  setOpacity(w.bg, "bg", bgOpacity)
  setVisible(w.bgEdge, "bgEdge", bgOpacity > 0)
end

function M.init(context)
  ctx = context
  cfg = context.cfg
  makeColors()
end

-- true when the native meter is showing the countdown (so the simple box can stay hidden)
function M.showsCountdown()
  return w ~= nil and w.screen ~= "Hud" and opt(w.screen, "Countdown")
end

function M.rebuild() destroy(); checkAcc = CHECK_EVERY_S end   -- settings changed: rebuilt on the next update

function M.update(dt)
  checkAcc = checkAcc + dt
  if checkAcc >= CHECK_EVERY_S then
    checkAcc = 0
    wantLayer, wantScreen = wanted()
    failedKey = nil
  end
  local key = wantLayer and (wantLayer .. ":" .. tostring(wantScreen)) or nil
  if key ~= (w and w.key or nil) then
    destroy()
    if wantLayer and key ~= failedKey then
      if build(wantLayer, wantScreen) then acc = UPDATE_EVERY_S else failedKey = key end
    end
  end
  if not w then return end
  acc = acc + dt
  if acc < UPDATE_EVERY_S then return end
  acc = 0
  local ok = pcall(refresh)
  if not ok then destroy() end
end

function M.shutdown() destroy() end

return M
