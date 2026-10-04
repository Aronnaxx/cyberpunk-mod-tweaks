return function(G)
  local M = { looted = {}, moveAt = {}, busy = {} }

  local SEARCH = 60.0
  local WALK = 20.0
  local GRAB = 3.5
  local MOVE_COOLDOWN = 6.0
  local BUSY = 8.0

  function M.busyFor(rec)
    local until_ = M.busy[rec]
    if not until_ then return false end
    if until_ < os.clock() then
      M.busy[rec] = nil
      return false
    end
    return true
  end

  local function tdbid(s) return TweakDBID.new(s) end

  local REG_CAP = 500
  local reg, regN = {}, 0

  local function track(component)
    pcall(function()
      local owner = component:GetOwner()
      if not owner or not IsDefined(owner) or not owner:IsA("gameLootContainerBase") then return end
      local id = owner:GetEntityID()
      local k = tostring(id.hash)
      if k == "1ULL" or k == "1" or reg[k] then return end
      if regN >= REG_CAP then reg, regN = {}, 0 end
      reg[k] = id
      regN = regN + 1
    end)
  end

  function M.install()
    ObserveAfter("GameplayRoleComponent", "OnGameAttach", track)
    ObserveAfter("GameplayRoleComponent", "ShowRoleMappins", track)
  end

  local function containers(player, out, seen)
    local ppos = player:GetWorldPosition()
    for k, id in pairs(reg) do
      local ent = Game.FindEntityByID(id)
      if not ent or not IsDefined(ent) then
        reg[k] = nil
        regN = regN - 1
      else
        pcall(function()
          if Vector4.Distance(ppos, ent:GetWorldPosition()) > SEARCH then return end
          local key = G.companion.entKey(ent)
          if seen[key] or M.looted[key] then return end
          seen[key] = true
          local count = 0
          pcall(function()
            local _, list = Game.GetTransactionSystem():GetItemList(ent)
            count = #(list or {})
          end)
          if count == 0 then return end
          out[#out + 1] = { ent = ent, key = key, kind = "container", count = count }
        end)
      end
    end
  end

  local function corpses(player)
    local out = {}
    local ok, err = pcall(function()
      local q = Game["TSQ_ALL;"]()
      q.maxDistance = SEARCH
      q.includeSecondaryTargets = false
      q.ignoreInstigator = true
      local found, list = Game.GetTargetingSystem():GetTargetParts(player, q)
      local seen = {}
      containers(player, out, seen)
      if not found then return end
      for _, part in ipairs(list) do
        pcall(function()
          local ent = part:GetComponent(part):GetEntity()
          if not IsDefined(ent) or ent:IsPlayer() then return end
          local key = G.companion.entKey(ent)
          if seen[key] or M.looted[key] then return end
          seen[key] = true
          local kind
          if ent:IsNPC() then
            if not G.companion.isDown(ent) then return end
            if Game.GetStatusEffectSystem():HasStatusEffect(ent:GetEntityID(), tdbid(G.TDB .. "CompanionSE")) then return end
            kind = "corpse"
          elseif ent:IsA("gameLootContainerBase") then
            kind = "container"
          elseif ent:IsA("gameLootObject") then
            kind = "drop"
          else
            return
          end
          local count = 0
          pcall(function()
            local _, list = Game.GetTransactionSystem():GetItemList(ent)
            count = #(list or {})
          end)
          if count == 0 then return end
          out[#out + 1] = { ent = ent, key = key, kind = kind, count = count }
        end)
      end
    end)
    if not ok then G.log("loot: search failed " .. tostring(err)) end
    return out
  end

  local function androidsIdle()
    local rows = {}
    G.companion.eachActive(function(rec, ent, model)
      if model.chassis ~= "Android" or G.companion.isDown(ent) then return end
      if G.hacks.held[rec] and not G.companion.faceHeld[rec] then return end
      if G.dronecam and G.dronecam.active == rec then return end
      if G.chauffeur and G.chauffeur.crew and G.chauffeur.crew[rec] then return end
      if G.orders and G.orders.moving[rec] then return end
      rows[#rows + 1] = { rec = rec, ent = ent }
    end)
    return rows
  end

  local function grab(player, corpse)
    local before, after = 0, 0
    pcall(function()
      local _, list = Game.GetTransactionSystem():GetItemList(corpse.ent)
      before = #(list or {})
    end)
    local ok, skipped = false, 0
    pcall(function()
      local ts = Game.GetTransactionSystem()
      local _, list = ts:GetItemList(corpse.ent)
      for _, item in ipairs(list or {}) do
        local moved = false
        pcall(function()
          if item:HasTag(CName.new("Quest")) or item:HasTag(CName.new("QuestItem")) then return end
          ts:TransferItem(corpse.ent, player, item:GetID(), item:GetQuantity() or 1)
          moved = true
        end)
        if not moved then skipped = skipped + 1 end
      end
      ok = true
    end)
    pcall(function()
      local _, list = Game.GetTransactionSystem():GetItemList(corpse.ent)
      after = #(list or {})
    end)
    M.looted[corpse.key] = true
    if not ok then G.log(string.format("loot: %s %s transfer failed", corpse.kind, corpse.key)) end
    return before - after
  end

  -- [CET-Cleans] skip rescans while standing still after a scan that found nothing
  local lastScanPos, lastScanAt, lastScanEmpty = nil, 0, false
  local IDLE_RESCAN = 15.0
  local MOVE_RESCAN = 3.0

  function M.tick()
    if not G.settings.androidLoot then return end
    local player = Game.GetPlayer()
    if not player then return end
    local inCombat = false
    pcall(function() inCombat = player:IsInCombat() end)
    if inCombat then return end
    local androids = androidsIdle()
    if #androids == 0 then return end
    local now = os.clock()
    local ppos = player:GetWorldPosition()
    if lastScanEmpty and lastScanPos and now - lastScanAt < IDLE_RESCAN
      and Vector4.Distance(ppos, lastScanPos) < MOVE_RESCAN then
      return
    end
    local bodies = corpses(player)
    lastScanPos, lastScanAt, lastScanEmpty = ppos, now, (#bodies == 0)
    if #bodies == 0 then return end
    local grabbed = 0
    for _, row in ipairs(androids) do
      local from = row.ent:GetWorldPosition()
      local best, bestDist
      for _, corpse in ipairs(bodies) do
        if not M.looted[corpse.key] then
          local d = Vector4.Distance(from, corpse.ent:GetWorldPosition())
          if not bestDist or d < bestDist then best, bestDist = corpse, d end
        end
      end
      if best then
        if bestDist <= GRAB then
          grabbed = grabbed + grab(player, best)
        elseif bestDist <= WALK and (M.moveAt[row.rec] or 0) + MOVE_COOLDOWN < now then
          M.moveAt[row.rec] = now
          M.busy[row.rec] = now + BUSY
          if G.companion.faceHeld[row.rec] then
            G.companion.faceHeld[row.rec] = nil
            pcall(G.hacks.clearHold, row.rec, row.ent)
          end
          local p = best.ent:GetWorldPosition()
          G.orders.moveCmd(row.ent, p.x, p.y, p.z, moveMovementType.Walk)
        end
      end
    end
    if grabbed > 0 then G.notify(string.format(G.STR.loot_grabbed, grabbed)) end
  end

  return M
end
