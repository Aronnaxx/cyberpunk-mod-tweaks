-- WeaponSlotProbe v1.2 (temporary diagnostic, remove when done)
-- Logs every change of: the item in V's right hand (AttachmentSlots.WeaponRight), GameObject.GetActiveWeapon
-- (what Street Sense's crowd fear reads), the HUD "armed" blackboard flag, the weapon record the HUD's weapon
-- roster displays (UI_ActiveWeaponData), and the UpperBody state. v1.1 watches the whole session, not only
-- 20 s after a load, and also marks loads and fast travels. Output: WeaponSlotProbe.log here + CET console.

local t, last = 0, {}

local function log(msg)
  local line = string.format("[WeaponSlotProbe %8.2fs] %s", t, msg)
  print(line)
  local f = io.open("WeaponSlotProbe.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. line .. "\n"); f:close() end
end

local function idStr(tdbid)
  if not tdbid then return "none" end
  local ok, s = pcall(function() return TDBID.ToStringDEBUG(tdbid) end)
  return ok and s or "?"
end

local function snapshot()
  local s = {}
  pcall(function()
    local p = Game.GetPlayer()
    if not p then return end
    local d = GetAllBlackboardDefs()
    local bs = Game.GetBlackboardSystem()
    local it = Game.GetTransactionSystem():GetItemInSlot(p, TweakDBID.new("AttachmentSlots.WeaponRight"))
    s.hand = it and idStr(it:GetItemID().id) or "nothing"
    local w = GameObject.GetActiveWeapon(p)
    s.active = w and idStr(w:GetItemID().id) or "none"
    s.armed = tostring(bs:Get(d.UI_EquipmentData):GetBool(d.UI_EquipmentData.HasWeaponEquipped))
    local v = bs:Get(d.UI_ActiveWeaponData):GetVariant(d.UI_ActiveWeaponData.WeaponRecordID)
    s.hudWeapon = v and idStr(FromVariant(v)) or "none"
    s.upper = tostring(bs:GetLocalInstanced(p:GetEntityID(), d.PlayerStateMachine):GetInt(d.PlayerStateMachine.UpperBody))
  end)
  return s
end

registerForEvent("onInit", function()
  log("---- launch (v1.2, continuous + LHUD) ----")
  Observe("PlayerPuppet", "OnGameAttached", function() last = {}; log("player attached (load)") end)
  Observe("FastTravelSystem", "OnLoadingScreenFinished", function() log("fast travel loading screen finished") end)
  -- v1.2: Limited HUD's own state. Every LHUD event (type number: 1 global hotkey, 4 combat, 6 stealth,
  -- 7 scanner, 9 weapon, 10 zoom, 18 danger zone) and the weapon panel's flags whenever its visibility changes.
  Observe("PlayerPuppet", "QueueLHUDEvent", function(_, typ, active)
    log("LHUD event type=" .. tostring(typ) .. " active=" .. tostring(active))
  end)
  local lastVis = nil
  ObserveAfter("WeaponRosterGameController", "DetermineCurrentVisibility", function(self)
    local ok, line = pcall(function()
      return string.format("visible=%s global=%s combat=%s stealth=%s weapon=%s zoom=%s danger=%s scanner=%s braindance=%s",
        tostring(self.lhud_isVisibleNow), tostring(self.lhud_isGlobalFlagToggled), tostring(self.lhud_isCombatActive),
        tostring(self.lhud_isStealthActive), tostring(self.lhud_isWeaponUnsheathed), tostring(self.lhud_isZoomActive),
        tostring(self.lhud_isInDangerZone), tostring(self.lhud_isScannerActive), tostring(self.lhud_isBraindanceActive))
    end)
    line = ok and line or ("flags unreadable: " .. tostring(line))
    if line ~= lastVis then lastVis = line; log("weapon panel: " .. line) end
  end)
end)

registerForEvent("onUpdate", function(dt)
  t = t + dt
  local s = snapshot()
  for _, k in ipairs({ "hand", "active", "armed", "hudWeapon", "upper" }) do
    if s[k] ~= nil and s[k] ~= last[k] then
      log(k .. ": " .. tostring(last[k] or "-") .. " -> " .. s[k])
      last[k] = s[k]
    end
  end
end)
