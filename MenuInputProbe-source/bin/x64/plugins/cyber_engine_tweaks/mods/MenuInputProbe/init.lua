-- MenuInputProbe v1.1 (temporary diagnostic, remove when done)
-- Logs, with timestamps, while the game runs:
--   * every switch of the game's input mode (keyboard/mouse vs controller), from PlayerPuppet
--   * every backpack hover-in / hover-out event and the item it was for
--   * v1.1: while the backpack is open, how often the tooltip / refresh machinery fires, summarised once per
--     second ("calls/s: ..."), so a tooltip that keeps being rebuilt under a still cursor shows which call repeats
-- Output: MenuInputProbe.log in this folder and the CET console. Capped at 1500 lines per launch.

local MAX_LINES = 1500
local t, lines, lastMode = 0, 0, nil
local backpackOpen, counts, nextFlush = false, {}, 0

local function log(msg)
  if lines >= MAX_LINES then return end
  lines = lines + 1
  local line = string.format("[MenuInputProbe %8.3fs] %s", t, msg)
  print(line)
  local f = io.open("MenuInputProbe.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. line .. "\n"); f:close() end
  if lines == MAX_LINES then print("[MenuInputProbe] line cap reached") end
end

local function itemName(evt)
  local ok, name = pcall(function()
    local it = evt.uiInventoryItem
    if it then return TDBID.ToStringDEBUG(it:GetID().id) end
    return "?"
  end)
  return ok and name or "?"
end

local function mode()
  local ok, m = pcall(function()
    local p = Game.GetPlayer()
    if not p then return nil end
    if p:PlayerLastUsedPad() then return "CONTROLLER" end
    if p:PlayerLastUsedKBM() then return "KEYBOARD/MOUSE" end
    return "unknown"
  end)
  return ok and m or nil
end

local function count(name)
  if backpackOpen then counts[name] = (counts[name] or 0) + 1 end
end

local function watch(class, method)
  local ok = pcall(function() Observe(class, method, function() count(class .. "." .. method) end) end)
  if not ok then log("could not observe " .. class .. "." .. method) end
end

registerForEvent("onInit", function()
  log("---- launch (v1.1) ----")
  Observe("BackpackMainGameController", "OnInitialize", function() backpackOpen = true; counts = {}; log("backpack opened") end)
  Observe("BackpackMainGameController", "OnUninitialize", function() backpackOpen = false; log("backpack closed") end)
  Observe("BackpackMainGameController", "OnItemDisplayHoverOver", function(_, evt) log("hover IN   " .. itemName(evt)) end)
  Observe("BackpackMainGameController", "OnItemDisplayHoverOut", function(_, evt) log("hover OUT  " .. itemName(evt)) end)
  -- tooltip lifecycle
  watch("gameuiTooltipsManager", "ShowTooltip")
  watch("gameuiTooltipsManager", "ShowTooltips")
  watch("gameuiTooltipsManager", "ShowTooltipAtWidget")
  watch("gameuiTooltipsManager", "HideTooltips")
  watch("ItemTooltipCommonController", "SetData")
  watch("ItemTooltipCommonController", "UpdateLayout")
  watch("ItemTooltipCommonController", "UpdateDetailsModule")
  watch("ItemTooltipCommonController", "NEW_UpdateHeaderModule")
  watch("ItemTooltipCommonController", "NEW_UpdateBottomModule")
  -- backpack / grid refreshes
  watch("BackpackMainGameController", "RefreshUI")
  watch("BackpackMainGameController", "NewShowItemHints")
  watch("BackpackMainGameController", "OnItemDisplayClick")
  watch("InventoryItemDisplayController", "RefreshUI")
  watch("InventoryItemDisplayController", "NewRefreshUI")
  watch("InventoryItemDisplayController", "NewUpdateEquipped")
  watch("ButtonHints", "AddButtonHint")
  watch("ButtonHints", "RemoveButtonHint")
end)

registerForEvent("onUpdate", function(dt)
  t = t + dt
  local m = mode()
  if m and m ~= lastMode then
    log("input mode: " .. tostring(lastMode or "-") .. " -> " .. m)
    lastMode = m
  end
  if backpackOpen and t >= nextFlush then
    nextFlush = t + 1.0
    local parts = {}
    for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
    table.sort(parts)
    if #parts > 0 then log("calls/s: " .. table.concat(parts, " ")) end
    counts = {}
  end
end)
