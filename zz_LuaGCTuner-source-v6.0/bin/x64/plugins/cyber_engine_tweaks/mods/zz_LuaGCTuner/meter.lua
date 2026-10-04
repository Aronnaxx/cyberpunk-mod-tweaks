-- Native ink meter for Lua GC Tuner: icon + "LUA MEMORY" label, value / cap + percent, a filling bar with a
-- marker at the menu-cleanup threshold, the cap mode (static / dynamic) and the cleanup countdown.
-- Lives on inkMenuLayer while a chosen menu is open (inventory, character, map, journal, Esc menu) and,
-- optionally, on inkHUDLayer during gameplay. Built from plain ink widgets; nothing runs while it is hidden.

local M = {}

local FONT = "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"
local ICON_ATLAS = "base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas"
local ROOT_NAME = "LuaGCTunerMeter"
local UPDATE_EVERY_S = 0.2

local function rgba(r, g, b, a) return HDRColor.new({ Red = r, Green = g, Blue = b, Alpha = a or 1 }) end
local COL = {
  red = rgba(1.1761, 0.3809, 0.3476),        -- game "panel red"
  faintRed = rgba(0.2824, 0.1137, 0.1373),
  mildRed = rgba(0.6824, 0.2314, 0.2118),
  blue = rgba(0.3686, 0.9647, 1.0),           -- game "main blue"
  yellow = rgba(1.1192, 0.8441, 0.2565),
  bg = rgba(0.054902, 0.054902, 0.090196),    -- game dark panel background
}

-- anchor presets: inkEAnchor name, anchor point, and which margins the X / Y offsets go into
local ANCHORS = {
  { label = "Top right",    anchor = "TopRight",    px = 1,   py = 0, mx = "right", my = "top" },
  { label = "Top left",     anchor = "TopLeft",     px = 0,   py = 0, mx = "left",  my = "top" },
  { label = "Top center",   anchor = "TopCenter",   px = 0.5, py = 0, mx = "left",  my = "top" },
  { label = "Bottom right", anchor = "BottomRight", px = 1,   py = 1, mx = "right", my = "bottom" },
  { label = "Bottom left",  anchor = "BottomLeft",  px = 0,   py = 1, mx = "left",  my = "bottom" },
}
M.ANCHORS = ANCHORS

M.DEFAULTS = {
  meterEnabled     = true,
  meterAdvanced    = false,   -- "Show advanced options" in Native Settings
  meterPause       = true,    -- Esc menu
  meterInventory   = true,    -- inventory, backpack, character / cyberware, crafting, perks
  meterMap         = true,
  meterJournal     = true,
  meterOther       = false,   -- other pauses (stash, vendor, photo mode, ...)
  meterGameplay    = false,   -- HUD during gameplay
  meterAnchor      = 1,       -- index into ANCHORS
  meterX           = 150,     -- offset from the anchor edge, in 4K virtual units
  meterY           = 185,
  meterScale       = 1.0,
  meterWidth       = 460,     -- bar width
  meterBackground  = 2,       -- 1 = off, 2 = map only, 3 = always
  meterBgOpacity   = 0.85,
  meterIcon        = true,
  meterPercent     = true,
  meterMode        = true,
  meterCountdown   = true,
}

local ctx            -- functions/state handed in by init.lua
local cfg
local w = nil        -- current widgets: { root, layer, ... }
local acc = 0

local function text(parent, size, style, color, x, y)
  local t = inkText.new()
  t:SetFontFamily(FONT)
  pcall(function() t:SetFontStyle(style) end)
  t:SetFontSize(size)
  t:SetLetterCase(textLetterCase.UpperCase)
  t:SetTintColor(color)
  t:SetAnchor(inkEAnchor.TopLeft)
  t:SetMargin(inkMargin.new({ left = x, top = y, right = 0, bottom = 0 }))
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

local function layout()
  local pad, icon = 18, cfg.meterIcon and 52 or 0
  local x0 = pad + (icon > 0 and icon + 16 or 0)
  local barW = cfg.meterWidth
  local width = x0 + barW + pad
  local height = (cfg.meterMode or cfg.meterCountdown) and 132 or 96
  return pad, icon, x0, barW, width, height
end

local function build(layerName)
  local ok, err = pcall(function()
    local vw = Game.GetInkSystem():GetLayer(layerName):GetVirtualWindow()
    pcall(function() vw:RemoveChildByName(ROOT_NAME) end)
    local a = ANCHORS[cfg.meterAnchor] or ANCHORS[1]
    local pad, icon, x0, barW, width, height = layout()

    local root = inkCanvas.new()
    root:SetName(CName.new(ROOT_NAME))
    root:SetAnchor(inkEAnchor[a.anchor])
    root:SetAnchorPoint(Vector2.new({ X = a.px, Y = a.py }))
    root:SetSize(width, height)
    local m = { left = 0, top = 0, right = 0, bottom = 0 }
    m[a.mx] = cfg.meterX
    m[a.my] = cfg.meterY
    root:SetMargin(inkMargin.new(m))
    root:SetScale(Vector2.new({ X = cfg.meterScale, Y = cfg.meterScale }))
    root:SetRenderTransformPivot(Vector2.new({ X = a.px, Y = a.py }))

    local new = { root = root, layer = layerName, barW = barW }
    new.bg = rect(root, 0, 0, width, height, COL.bg, cfg.meterBgOpacity)
    new.bgEdge = rect(root, 0, 0, 4, height, COL.red, 0.9)
    if icon > 0 then
      local img = inkImage.new()
      img:SetAtlasResource(ResRef.FromName(ICON_ATLAS))
      img:SetTexturePart("wait")
      img:SetAnchor(inkEAnchor.TopLeft)
      img:SetMargin(inkMargin.new({ left = pad, top = pad + 4, right = 0, bottom = 0 }))
      img:SetSize(icon, icon)
      img:SetTintColor(COL.red)
      img:Reparent(root, -1)
      new.icon = img
    end
    new.label = text(root, 30, "Medium", COL.red, x0, pad - 4)
    new.label:SetText("Lua memory")
    new.value = text(root, 30, "Semi-Bold", COL.blue, x0 + 190, pad - 4)
    new.barBg = rect(root, x0, pad + 44, barW, 12, COL.faintRed, 0.6, true)
    new.fill = rect(root, x0, pad + 46, 1, 8, COL.red, 1, true)
    new.mark = rect(root, x0, pad + 38, 3, 24, COL.blue, 0.9)
    new.mode = text(root, 24, "Medium", COL.mildRed, x0, pad + 70)
    new.count = text(root, 24, "Semi-Bold", COL.yellow, x0 + barW * 0.45, pad + 70)

    root:Reparent(vw, -1)
    w = new
  end)
  if not ok then
    print("[LuaGCTuner] meter: could not build (" .. tostring(err) .. ")")
    w = nil
  end
  return ok
end

local function destroy()
  if not w then return end
  pcall(function()
    local vw = Game.GetInkSystem():GetLayer(w.layer):GetVirtualWindow()
    vw:RemoveChild(w.root)
  end)
  w = nil
end

local function wantedLayer()
  if not cfg.meterEnabled or not cfg.enabled then return nil end
  local s = ctx.state()
  if s.loading then return nil end
  if s.paused then
    local k = s.menuKind
    local on = (k == "pause" and cfg.meterPause) or (k == "inventory" and cfg.meterInventory)
      or (k == "map" and cfg.meterMap) or (k == "journal" and cfg.meterJournal) or (k == nil and cfg.meterOther)
    return on and "inkMenuLayer" or nil
  end
  return cfg.meterGameplay and "inkHUDLayer" or nil
end

local function refresh()
  if not w then return end
  local s = ctx.state()
  local mb, cap = ctx.heapMB(), ctx.capMB()
  local frac = cap > 0 and math.min(1, mb / cap) or 0
  local value = ctx.fmtMB(mb) .. (cap > 0 and (" / " .. ctx.fmtMB(cap)) or "")
  if cfg.meterPercent and cap > 0 then value = value .. string.format("   %d%%", math.floor(frac * 100 + 0.5)) end
  w.value:SetText(value)
  w.fill:SetSize(math.max(1, w.barW * frac), 8)
  w.fill:SetTintColor(frac >= 0.9 and COL.yellow or COL.red)
  local thr = cap > 0 and math.min(1, ctx.menuThresholdMB() / cap) or 0
  w.mark:SetVisible(cap > 0)
  w.mark:SetMargin(inkMargin.new({ left = w.barBg:GetMargin().left + w.barW * thr, top = w.mark:GetMargin().top, right = 0, bottom = 0 }))
  w.mode:SetVisible(cfg.meterMode)
  w.mode:SetText(cap <= 0 and "No hard cap" or (s.dynamic and "Dynamic cap" or "Static cap"))
  local cd = s.countdown
  w.count:SetVisible(cfg.meterCountdown and cd ~= nil)
  if cd then
    w.count:SetText(cd > 0.25 and string.format("Cleanup in %d s", math.ceil(cd)) or "Cleaning up...")
  end
  local bgOn = cfg.meterBackground == 3 or (cfg.meterBackground == 2 and s.menuKind == "map")
  w.bg:SetVisible(bgOn)
  w.bgEdge:SetVisible(bgOn)
end

function M.init(context)
  ctx = context
  cfg = context.cfg
end

-- true when the native meter is showing the countdown (so the simple box can stay hidden)
function M.showsCountdown()
  return w ~= nil and cfg.meterCountdown and w.layer == "inkMenuLayer"
end

function M.rebuild() destroy() end   -- settings changed: the next update builds it again

function M.update(dt)
  local want = wantedLayer()
  if want ~= (w and w.layer or nil) then
    destroy()
    if want and build(want) then acc = UPDATE_EVERY_S end
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
