-- WeaponSlotProbe (temporary diagnostic, remove when done)
-- For the first 20 s after each load, logs every change of: the item in V's right hand
-- (AttachmentSlots.WeaponRight), GameObject.GetActiveWeapon, the HUD "armed" blackboard flag and the
-- UpperBody state. Output: WeaponSlotProbe.log in this folder and the CET console.

local WINDOW_S = 20
local t, active, last = 0, false, {}

local function log(msg)
  local line = string.format("[WeaponSlotProbe +%5.2fs] %s", t, msg)
  print(line)
  local f = io.open("WeaponSlotProbe.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. line .. "\n"); f:close() end
end

local function snapshot()
  local s = {}
  pcall(function()
    local p = Game.GetPlayer()
    if not p then return end
    local d = GetAllBlackboardDefs()
    local bs = Game.GetBlackboardSystem()
    local it = Game.GetTransactionSystem():GetItemInSlot(p, TweakDBID.new("AttachmentSlots.WeaponRight"))
    s.hand = it and TDBID.ToStringDEBUG(it:GetItemID().id) or "nothing"
    local w = GameObject.GetActiveWeapon(p)
    s.active = w and TDBID.ToStringDEBUG(w:GetItemID().id) or "none"
    s.armed = tostring(bs:Get(d.UI_EquipmentData):GetBool(d.UI_EquipmentData.HasWeaponEquipped))
    s.upper = tostring(bs:GetLocalInstanced(p:GetEntityID(), d.PlayerStateMachine):GetInt(d.PlayerStateMachine.UpperBody))
  end)
  return s
end

registerForEvent("onInit", function()
  Observe("PlayerPuppet", "OnGameAttached", function()
    t, active, last = 0, true, {}
    log("player attached (load) - watching")
  end)
end)

registerForEvent("onUpdate", function(dt)
  if not active then return end
  t = t + dt
  local s = snapshot()
  for _, k in ipairs({ "hand", "active", "armed", "upper" }) do
    if s[k] ~= nil and s[k] ~= last[k] then
      log(k .. ": " .. tostring(last[k] or "-") .. " -> " .. s[k])
      last[k] = s[k]
    end
  end
  if t >= WINDOW_S then active = false; log("done") end
end)
