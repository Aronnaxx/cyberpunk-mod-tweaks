------------------------------------------
-- Dedra's Car Seller CODE

local ui
do
  local ok, m = pcall(require, "modules/interactionUI")
  if ok and m then 
    ui = m 
  else
    ui = {
      init=function()end, 
      update=function()end,
      createChoice=function(label)return{label=label}end,
      createHub=function(title,choices)return{title=title,choices=choices}end,
      setupHub=function(_)end, 
      showHub=function()end, 
      hideHub=function()end,
      clearCallbacks=function()end, 
      registerChoiceCallback=function(_,_)end
    }
  end
end

-- Simple fallback UI system using game notifications
local simpleUI = {
  showing = false,
  currentChoices = {},
  currentCallbacks = {},
  title = "",
}

local function showSimpleUI(title, choices, callbacks)
  simpleUI.showing = true
  simpleUI.title = title
  simpleUI.currentChoices = choices or {}
  simpleUI.currentCallbacks = callbacks or {}
  
  local msg = title .. "\n\n"
  for i, choice in ipairs(choices) do
    msg = msg .. string.format("[%d] %s\n", i, choice)
  end
  msg = msg .. "\nUse CET console: CarSeller_choice(number)"
  
  alertMsg(msg, 10)
end

local function hideSimpleUI()
  simpleUI.showing = false
  simpleUI.currentChoices = {}
  simpleUI.currentCallbacks = {}
  simpleUI.title = ""
end

function CarSeller_choice(num)
  if not simpleUI.showing then
    return
  end
  
  local callback = simpleUI.currentCallbacks[num]
  if callback then
    callback()
  end
end

-- Debug functions to help troubleshoot
function CarSeller_debug_catalog()
end

function CarSeller_refresh_pools()
  currentCarIndices = { cheap = 1, high_end = 1, heavy_duty = 1, bikes = 1, savedspot = 1 }
  spawnCurrentCarSet()
  CarSeller_debug_catalog()
end

function CarSeller_next_set()
  nextCarSet()
end

function CarSeller_prev_set()
  previousCarSet()
end

function CarSeller_test_spawn()
  currentCarIndices = { cheap = 1, high_end = 1, heavy_duty = 1, bikes = 1, savedspot = 1 }
  spawnCurrentCarSet()
end

function CarSeller_start_monitoring()
  toggleSystem.active = true
  toggleSystem.currentIteration = 0
  playerVehicleState.monitoringActive = true
end

function CarSeller_stop_monitoring()
  toggleSystem.active = false
  toggleSystem.currentIteration = 0
  playerVehicleState.monitoringActive = false
end

function CarSeller_status()
end

function CarSeller_test_toggle()
end

function CarSeller_spam_test()
end

function CarSeller_toggle_map_marker()
  if shopMappinID or shopMappinID_2 then
    removeShopMapMarker()
    alertMsg("Map markers removed", 2)
  else
    createShopMapMarker()
    alertMsg("Map markers created", 2)
  end
end

----------------------------- Config -----------------------------
local ENTRANCE_POS = { x = -1677.94, y = 160.47, z = 7.82, w = 1, angle = 57.12 } -- Entrance location
local ENTRANCE_POS_2 = { x = 606.4076, y = -404.74185, z = 6.784172, w = 1, angle = 14.481052 } -- Second entrance location
local SELLER_POS = { x = 607.27515, y = -385.37085, z = 10.2202, w = 1 } -- Terminal location
local SHOP_EXIT_POS = { x = 605.2473, y = -398.05392, z = 10.171738, w = 1, angle = 7.2700634 } -- Shop exit location
local OPEN_RADIUS_M, CLOSE_RADIUS_M = 4.0, 5.5
local TAG = "CETSpawned_CarSeller"
local CATALOG_DIR = "cars" -- JSONs live here (relative to mod folder)

-- Spawn locations for each category (angles adjusted to face terminal)
local SPAWN_LOCATIONS = {
  high_end = { x = 629.29895, y = -386.8128, z = 10.362236, angle = 87.706894 },    -- Center - rotated 180°
  cheap = { x = 614.6627, y = -392.04672, z = 10.362236, angle = 24.17006 },       -- Front right - rotated 180°
  heavy_duty = { x = 642.7655, y = -388.8117, z = 10.362236, angle = 23.21959 },   -- Right back - rotated 180°
  bikes = { x = 618.135, y = -379.70465, z = 10.362236, angle = 184.769765 },      -- Front left - rotated 180°
  savedspot = { x = 635.70715, y = -374.21954, z = 10.362236, angle = 99.59365 }   -- New saved spot - rotated 180°
}

-- Map marker system
local shopMappinID = nil
local shopMappinID_2 = nil

local function _markerVariantName() 
  return "DropboxVariant" 
end

local function AddMapMarkerToDB(database, markerTdbPath)
  local list = TweakDB:GetFlat(database)
  if type(list) ~= "table" then list = {} end
  local tid = TweakDBID.new(markerTdbPath)
  for _,v in ipairs(list) do if v == tid then return end end
  table.insert(list, tid)
  TweakDB:SetFlat(database, list)
end

local function ensureJobsFilterHasVariant()
  local markerType = "Mappins.PointOfInterest_" .. _markerVariantName()
  AddMapMarkerToDB("WorldMap.JobsFilterGroup.mappins", markerType)
  AddMapMarkerToDB("WorldMap.AllServicePointsFilterGroup.mappins", markerType)
  AddMapMarkerToDB("WorldMap.DropPointFilterGroup.mappins", markerType)
  AddMapMarkerToDB("Mappins.DropPointDynamicMappin.possibleVariants", markerType)
  AddMapMarkerToDB("Mappins.DropPointStaticMappin.possibleVariants", markerType)
end

local function createShopMapMarker()
  pcall(function()
    local mappinSystem = Game.GetMappinSystem()
    if not mappinSystem then return end
    
    -- First entrance marker
    if not shopMappinID then
      local md = MappinData.new()
      md.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
      md.variant = Enum.new('gamedataMappinVariant', 'Zzz01_CarForPurchaseVariant')
      md.visibleThroughWalls = true
      md.debugCaption = "Dedka's Dealership"
      
      local entrancePos = ToVector4(ENTRANCE_POS)
      shopMappinID = mappinSystem:RegisterMappin(md, entrancePos)
    end
    
    -- Second entrance marker
    if not shopMappinID_2 then
      local md2 = MappinData.new()
      md2.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
      md2.variant = Enum.new('gamedataMappinVariant', 'Zzz01_CarForPurchaseVariant')
      md2.visibleThroughWalls = true
      md2.debugCaption = "Dedka's Dealership"
      
      local entrancePos2 = ToVector4(ENTRANCE_POS_2)
      shopMappinID_2 = mappinSystem:RegisterMappin(md2, entrancePos2)
    end
  end)
end

local function removeShopMapMarker()
  pcall(function()
    local mappinSystem = Game.GetMappinSystem()
    if mappinSystem then
      if shopMappinID then
        mappinSystem:UnregisterMappin(shopMappinID)
        shopMappinID = nil
      end
      if shopMappinID_2 then
        mappinSystem:UnregisterMappin(shopMappinID_2)
        shopMappinID_2 = nil
      end
    end
  end)
end

----------------------------- Helpers -----------------------------
local function ToVector4(t) return Vector4.new(t.x, t.y, t.z, t.w or 1) end
local function ToEulerAngles(t) return EulerAngles.new(t.roll or 0, t.pitch or 0, t.yaw or 0) end
local function sqrDist(a, b)
  local ax, ay, az = a.x or 0, a.y or 0, a.z or 0
  local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
  local dx, dy, dz = ax - bx, ay - by, az - bz
  return dx*dx + dy*dy + dz*dz
end
local function isNear(pos, tgt, r) return sqrDist(pos, tgt) <= (r or 2)^2 end

local function alertMsg(txt, sec)
  if PreventionSystem and PreventionSystem.ShowMessage then
    PreventionSystem.ShowMessage(tostring(txt), sec or 4.0)
  else
    local MSG=SimpleScreenMessage.new()
    local BBS=Game.GetBlackboardSystem()
    local DEF=GetAllBlackboardDefs().UI_Notifications
    local UIN=BBS:Get(DEF)
    MSG.message=tostring(txt); MSG.isShown=true; MSG.duration=sec or 4.0
    UIN:SetVariant(DEF.OnscreenMessage, ToVariant(MSG), true)
  end
end
local function playFX()
  local p=Game.GetPlayer(); if not p then return end
  local t=WorldTransform.new()
  t:SetOrientation(p:GetWorldOrientation()); t:SetPosition(p:GetWorldPosition())
  local fx=gameFxResource.new({effect="base\\fx\\camera\\fast_travel_glitch\\fast_travel_glitch.effect"})
  Game.GetFxSystem():SpawnEffect(fx,t)
end
local function teleportPlayer(pos)
  local player = Game.GetPlayer()
  if not player then return end
  
  -- 
  local teleportFacility = Game.GetTeleportationFacility()
  if teleportFacility then
    teleportFacility:Teleport(player, ToVector4{x=pos.x, y=pos.y, z=pos.z, w=pos.w or 1}, ToEulerAngles{roll=0, pitch=0, yaw=pos.angle or 0})
  else
    -- 
    player:Teleport(ToVector4{x=pos.x, y=pos.y, z=pos.z, w=pos.w or 1}, ToEulerAngles{roll=0, pitch=0, yaw=pos.angle or 0})
  end
end
local function fmtMoney(n)
  local s=tostring(math.floor(n or 0)); local k
  repeat s,k=s:gsub("^(-?%d+)(%d%d%d)","%1,%2") until k==0
  return "₡"..s
end

----------------------------- Minimal JSON -----------------------------
local json = (_G and _G.json) or nil
if not json then
  local function _esc(s) return (s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')) end
  local function _encode(tbl)
    local parts = {}
    for k,v in pairs(tbl) do
      local key = '"'.._esc(tostring(k))..'":'
      local tv = type(v)
      local val = (tv=="number" or tv=="boolean") and tostring(v) or '"'.._esc(tostring(v))..'"'
      table.insert(parts, key..val)
    end
    return "{"..table.concat(parts, ",").."}"
  end
  local function _parse_val(v)
    v = v:match("^%s*(.-)%s*$")
    if v == "true" then return true end
    if v == "false" then return false end
    if v:match('^%-?%d+%.%d+$') or v:match('^%-?%d+$') then return tonumber(v) end
    local s = v:match('^"(.*)"$'); if s then return (s:gsub('\\"','"'):gsub('\\\\','\\')) end
    return v
  end
  
  -- Simple but more robust JSON decoder
  local function _decode(s)
    -- 
    if s and s:sub(1,3) == "\239\187\191" then s = s:sub(4) end
    
    -- 
    local trimmed = s:match("^%s*(.-)%s*$")
    if trimmed:sub(1,1) == "[" and trimmed:sub(-1) == "]" then
      -- 
      local array_content = trimmed:sub(2, -2) -- Remove [ and ]
      local cars_format = '{"cars":[' .. array_content .. ']}'
      return _decode(cars_format) -- 
    end
    
    -- 
    local clean = s:gsub("%s+", "")
    
    -- 
    if clean:match('"cars":%[') then
      return { cars = "ARRAY_DETECTED" } -- 
    end
    
    local t = {}
    
    -- 
    local category = clean:match('"category":"([^"]+)"')
    local name = clean:match('"name":"([^"]+)"')
    local spawnId = clean:match('"spawnId":"([^"]+)"')
    local grantId = clean:match('"grantId":"([^"]+)"')
    
    if category then t.category = category end
    if name then t.name = name end
    if spawnId then t.spawnId = spawnId end
    if grantId then t.grantId = grantId end
    
    -- Extract price object
    local price_obj = clean:match('"price":{([^}]+)}')
    if price_obj then
      t.price = {}
      local low = price_obj:match('"low":(%d+)')
      local high = price_obj:match('"high":(%d+)')
      if low then t.price.low = tonumber(low) end
      if high then t.price.high = tonumber(high) end
    end
    
    -- Extract discount object
    local discount_obj = clean:match('"discount":{([^}]+)}')
    if discount_obj then
      t.discount = {}
      local low = discount_obj:match('"low":(%d+)')
      local high = discount_obj:match('"high":(%d+)')
      local days_array = discount_obj:match('"days":%[([^%]]+)%]')
      
      if low then t.discount.low = tonumber(low) end
      if high then t.discount.high = tonumber(high) end
      if days_array then
        t.discount.days = {}
        for day in days_array:gmatch('(%d+)') do
          table.insert(t.discount.days, tonumber(day))
        end
      end
    end
    
    local keys = {}
    for k,_ in pairs(t or {}) do table.insert(keys, k) end
    return next(t) and t or {}
  end
  json = { encode = _encode, decode = _decode }
end

local function read_file(path)
  local f = io.open(path, "r"); if not f then return nil, "open-failed" end
  local s = f:read("*a"); f:close()
  if s and s:sub(1,3) == "\239\187\191" then s = s:sub(4) end
  return s
end

----------------------------- Catalog -----------------------------
local activeSpawns = {} -- 
local CATALOG = { cheap = {}, high_end = {}, heavy_duty = {}, bikes = {}, savedspot = {} }

-- 
local RA_CATALOGS = {} -- RA_CATALOGS["ra1"] = { cheap = {}, high_end = {}, ... }
local currentCarIndices = { cheap = 1, high_end = 1, heavy_duty = 1, bikes = 1, savedspot = 1 } -- Current car index in each category
local activeCarSet = { cheap = nil, high_end = nil, heavy_duty = nil, bikes = nil, savedspot = nil } -- Currently spawned cars

-- 
local generateCarSet, spawnCurrentCarSet, nextCarSet, previousCarSet

-- 
generateCarSet = function()
  -- This function prepares the car selection system
  -- 
end

-- 
local function getCurrentCarForCategory(cat)
  -- 
  local ra1Cars = RA_CATALOGS["ra1"] and RA_CATALOGS["ra1"][cat] or {}
  local ra2Cars = RA_CATALOGS["ra2"] and RA_CATALOGS["ra2"][cat] or {}
  local otherRACars = {}
  
  --
  for raName, raCatalog in pairs(RA_CATALOGS) do
    if raName ~= "ra1" and raName ~= "ra2" then
      local cars = raCatalog[cat] or {}
      for _, car in ipairs(cars) do
        otherRACars[#otherRACars + 1] = {car = car, raFile = raName}
      end
    end
  end
  
  local currentIndex = currentCarIndices[cat] or 1
  
  -- 
  local allUniqueCars = {}
  local seenSpawnIds = {}
  
  -- 
  for _, car in ipairs(ra1Cars) do
    if not seenSpawnIds[car.spawnId] then
      allUniqueCars[#allUniqueCars + 1] = {car = car, raFile = "ra1"}
      seenSpawnIds[car.spawnId] = true
    end
  end
  
  -- 
  for _, car in ipairs(ra2Cars) do
    if not seenSpawnIds[car.spawnId] then
      allUniqueCars[#allUniqueCars + 1] = {car = car, raFile = "ra2"}
      seenSpawnIds[car.spawnId] = true
    end
  end
  
  -- 
  for _, carData in ipairs(otherRACars) do
    if not seenSpawnIds[carData.car.spawnId] then
      allUniqueCars[#allUniqueCars + 1] = carData
      seenSpawnIds[carData.car.spawnId] = true
    end
  end
  
  local totalCars = #allUniqueCars
  
  if totalCars == 0 then
    -- 
    local mainCars = CATALOG[cat] or {}
    if #mainCars > 0 then
      local index = ((currentIndex - 1) % #mainCars) + 1
      return mainCars[index]
    end
    return nil
  end
  
  -- 
  local adjustedIndex = ((currentIndex - 1) % totalCars) + 1
  
  if allUniqueCars[adjustedIndex] then
    return allUniqueCars[adjustedIndex].car
  end
  
  return nil
end

spawnCurrentCarSet = function()
  
  -- 
  local des = Game.GetDynamicEntitySystem(); if des then
    if des.DespawnTagged then des:DespawnTagged(CName.new(TAG))
    elseif des.DeleteTagged then des:DeleteTagged(CName.new(TAG)) end
    for i=#activeSpawns,1,-1 do
      local id=activeSpawns[i]
      if id and des.DespawnEntity then pcall(function() des:DespawnEntity(id) end) end
      activeSpawns[i]=nil
    end
  end
  
  -- 
  activeCarSet = { cheap = nil, high_end = nil, heavy_duty = nil, bikes = nil, savedspot = nil }
  
  for cat, location in pairs(SPAWN_LOCATIONS) do
    local item = getCurrentCarForCategory(cat)
    
    if item then
      -- 
      local des = Game.GetDynamicEntitySystem(); if not des then return nil end
      local spec = NewObject("DynamicEntitySpec")
      spec.recordID = TweakDBID.new(item.spawnId)
      spec.position = Vector4.new(location.x, location.y, location.z, location.w or 1)
      
      -- 
      local radians = math.rad(location.angle or 0)
      spec.orientation = Quaternion.new(0, 0, math.sin(radians/2), math.cos(radians/2))
      
      spec.persistState=false; spec.persistSpawn=false; spec.spawnInView=true; spec.active=true
      spec.tags = { CName.new(TAG) }
      local id = des:CreateEntity(spec)
      if id then 
        activeSpawns[#activeSpawns+1] = id
        activeCarSet[cat] = {
          id = id,
          item = item,
          carIndex = currentCarIndices[cat]
        }
      end
    end
  end
end

nextCarSet = function()
  -- Increment car indices for all categories
  for cat, _ in pairs(currentCarIndices) do
    currentCarIndices[cat] = currentCarIndices[cat] + 1
  end
  
  spawnCurrentCarSet()
  
  local function alertMsg(txt, sec)
    if PreventionSystem and PreventionSystem.ShowMessage then
      PreventionSystem.ShowMessage(tostring(txt), sec or 4.0)
    else
      local MSG=SimpleScreenMessage.new()
      local BBS=Game.GetBlackboardSystem()
      local DEF=GetAllBlackboardDefs().UI_Notifications
      local UIN=BBS:Get(DEF)
      MSG.message=tostring(txt); MSG.isShown=true; MSG.duration=sec or 4.0
      UIN:SetVariant(DEF.OnscreenMessage, ToVariant(MSG), true)
    end
  end
  alertMsg("New inventory selection available - Premium models refreshed", 3)
end

previousCarSet = function()
  -- Decrement car indices for all categories
  for cat, _ in pairs(currentCarIndices) do
    currentCarIndices[cat] = math.max(1, currentCarIndices[cat] - 1)
  end
  
  spawnCurrentCarSet()
  
  local function alertMsg(txt, sec)
    if PreventionSystem and PreventionSystem.ShowMessage then
      PreventionSystem.ShowMessage(tostring(txt), sec or 4.0)
    else
      local MSG=SimpleScreenMessage.new()
      local BBS=Game.GetBlackboardSystem()
      local DEF=GetAllBlackboardDefs().UI_Notifications
      local UIN=BBS:Get(DEF)
      MSG.message=tostring(txt); MSG.isShown=true; MSG.duration=sec or 4.0
      UIN:SetVariant(DEF.OnscreenMessage, ToVariant(MSG), true)
    end
  end
  alertMsg("Previous inventory selection restored - Browse available models", 3)
end

local function normalize_cat(s)
  if type(s)~="string" then return nil end
  s = s:lower():gsub("%-","_"):gsub("%s+","")
  if s=="cheap" or s=="low" then return "cheap" end
  if s=="highend" or s=="high_end" or s=="premium" then return "high_end" end
  if s=="heavyduty" or s=="heavy_duty" or s=="truck" or s=="utility" then return "heavy_duty" end
  if s=="bikes" or s=="bike" or s=="motorcycle" or s=="motorcycles" then return "bikes" end
  if s=="savedspot" or s=="saved_spot" or s=="saved" or s=="special" then return "savedspot" end
  return nil
end
local function valid_price(t) return type(t)=="table" and tonumber(t.low) and tonumber(t.high) and t.low<=t.high end
local function push_item(cat, item) CATALOG[cat]=CATALOG[cat] or {}; CATALOG[cat][#CATALOG[cat]+1]=item end

local function _push_from_json(entry, source)
  
  local cat = normalize_cat(entry.category)
  if not cat then return false end
  
  if type(entry.spawnId)~="string" then 
    return false 
  end
  
  if not valid_price(entry.price) then 
    return false 
  end
  
  local item = {
    name    = entry.name or entry.spawnId,
    spawnId = entry.spawnId,
    grantId = entry.grantId or entry.spawnId,
    price   = { low = tonumber(entry.price.low), high = tonumber(entry.price.high) },
    discount= nil
  }
  if type(entry.discount)=="table" and valid_price(entry.discount) and type(entry.discount.days)=="table" then
    local days = {}
    for _,d in ipairs(entry.discount.days) do
      local di = tonumber(d); if di and di>=1 and di<=7 then days[#days+1]=di end
    end
    if #days>0 then item.discount = { days=days, low=tonumber(entry.discount.low), high=tonumber(entry.discount.high) } end
  end
  
  -- Add to main catalog
  push_item(cat, item)
  
  local raFileName = source:match("(ra%d+)%.json") or source:match("(ra%d+)")
  if raFileName then
    if not RA_CATALOGS[raFileName] then
      RA_CATALOGS[raFileName] = { cheap = {}, high_end = {}, heavy_duty = {}, bikes = {}, savedspot = {} }
    end
    RA_CATALOGS[raFileName][cat] = RA_CATALOGS[raFileName][cat] or {}
    RA_CATALOGS[raFileName][cat][#RA_CATALOGS[raFileName][cat] + 1] = item
  end
  
  return true
end

-- 
local function list_json_files(dir)
  local out = {}
  
  -- Try lfs first
  local ok, lfs = pcall(require, "lfs")
  if ok and lfs and lfs.dir then
    local attr_ok, mode = pcall(lfs.attributes, dir, "mode")
    if attr_ok and mode == "directory" then
      for f in lfs.dir(dir) do
        if f ~= "." and f ~= ".." then
          local lower_f = f:lower()
          -- Only accept .json files (standard extension)
          if lower_f:sub(-5) == ".json" then
            out[#out+1] = dir .. "/" .. f
          end
        end
      end
      return out
    end
  end
  
  -- CMD fallback - try multiple approaches
  local cmd1 = ('cmd /c dir /b "%s\\*.json" 2>nul'):format(dir:gsub("/", "\\"))
  local popenOk, pipe = pcall(io.popen, cmd1)
  if popenOk and pipe then
    for f in pipe:lines() do 
      out[#out+1] = dir .. "/" .. f
    end
    pipe:close()
  end
  
  if #out == 0 then
    -- Try absolute path
    local abs_path = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Cyberpunk 2077\\bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\Dedra's Car seller\\cars"
    local cmd2 = ('cmd /c dir /b "%s\\*.json" 2>nul'):format(abs_path)
    local popenOk2, pipe2 = pcall(io.popen, cmd2)
    if popenOk2 and pipe2 then
      for f in pipe2:lines() do 
        out[#out+1] = abs_path .. "\\" .. f
      end
      pipe2:close()
    end
  end
  
  if #out == 0 then
    -- Try direct file access for known files (ra1.json to ra10000.json)
    for i = 1, 10000 do
      local fname = "ra" .. i .. ".json"
      local fpath = dir .. "/" .. fname
      local f = io.open(fpath, "r")
      if f then
        f:close()
        out[#out+1] = fpath
      end
    end
  end
  
  return out
end



local function load_catalog_from_json_dir(dir)
  local files = list_json_files(dir)
  local loaded, errors = 0, 0
  for _,full in ipairs(files) do
    local blob, err = read_file(full)
    if not blob then
      errors = errors + 1
    else
      local ok, data = pcall(json.decode, blob)
      if not ok or type(data) ~= "table" then
        errors = errors + 1
      else
        if data.cars and type(data.cars)=="table" then
          local count = 0
          for i,entry in ipairs(data.cars) do
            if type(entry)=="table" and _push_from_json(entry, (full:match("([^/\\]+)$") or full).."["..i.."]") then count=count+1 else errors=errors+1 end
          end
          loaded = loaded + count
        elseif data.cars == "ARRAY_DETECTED" then
          -- For array format, we need to parse individual entries manually
          local array_content = blob:match("^%s*%[(.-)%]%s*$")
          if array_content then
            local entry_count = 0
            -- Split by },{ pattern to get individual entries
            local entries = {}
            local current_entry = ""
            local brace_count = 0
            local in_string = false
            local escape_next = false
            
            for i = 1, #array_content do
              local char = array_content:sub(i, i)
              current_entry = current_entry .. char
              
              if escape_next then
                escape_next = false
              elseif char == "\\" then
                escape_next = true
              elseif char == '"' and not escape_next then
                in_string = not in_string
              elseif not in_string then
                if char == "{" then
                  brace_count = brace_count + 1
                elseif char == "}" then
                  brace_count = brace_count - 1
                  if brace_count == 0 then
                    -- End of an entry
                    table.insert(entries, current_entry)
                    current_entry = ""
                    -- Skip comma and whitespace
                    while i + 1 <= #array_content and array_content:sub(i + 1, i + 1):match("[,%s]") do
                      i = i + 1
                    end
                  end
                end
              end
            end
            
            -- Split array into entries (print removed)
            for i, entry_str in ipairs(entries) do
              local ok_entry, entry_data = pcall(json.decode, entry_str)
              if ok_entry and type(entry_data) == "table" then
                if _push_from_json(entry_data, (full:match("([^/\\]+)$") or full).."["..i.."]") then 
                  entry_count = entry_count + 1 
                else 
                  errors = errors + 1 
                end
              else
                errors = errors + 1
              end
            end
            loaded = loaded + entry_count
          else
            errors = errors + 1
          end
        else
          if _push_from_json(data, (full:match("([^/\\]+)$") or full)) then loaded=loaded+1 else errors=errors+1 end
        end
      end
    end
  end
  -- Count total cars across all categories
  local totalCars = 0
  for cat, items in pairs(CATALOG) do
    totalCars = totalCars + #items
  end
  
  -- Single mod loaded message
  print("[CarSeller] Mod loaded: found " .. totalCars .. " cars")
  
  -- 
  generateCarSet()
end

----------------------------- Spawn / Despawn preview -----------------------------
local playerVehicleState = {
  wasInVehicle = false,
  currentVehicle = nil,
  lastCheckedVehicle = nil,
  monitoringActive = true,
  lastToggleTime = 0
}

-- New 10,000-iteration system
local toggleSystem = {
  active = false,
  currentIteration = 0,
  maxIterations = 10000
}

local function despawnAll()
  local des = Game.GetDynamicEntitySystem(); if not des then return end
  if des.DespawnTagged then des:DespawnTagged(CName.new(TAG))
  elseif des.DeleteTagged then des:DeleteTagged(CName.new(TAG)) end
  for i=#activeSpawns,1,-1 do
    local id=activeSpawns[i]
    if id and des.DespawnEntity then pcall(function() des:DespawnEntity(id) end) end
    activeSpawns[i]=nil
  end
end

local function executeToggleCommand()
  if toggleSystem.active then
    pcall(function()
      local v = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
      if v then 
        v:GetVehicleComponent():ToggleVehicleSystems(false,true,true)
      end
    end)
    toggleSystem.currentIteration = toggleSystem.currentIteration + 1
  end
end

local function isSpawnedVehicle(vehicle)
  -- Check if the vehicle is one of our spawned vehicles
  if not vehicle then return false end
  
  -- First check against our active car set
  for cat, carData in pairs(activeCarSet) do
    if carData and carData.id then
      -- Try to get the vehicle entity from the ID
      local des = Game.GetDynamicEntitySystem()
      if des then
        local spawnedVehicle = des:GetEntity(carData.id)
        if spawnedVehicle and spawnedVehicle == vehicle then
          return true
        end
      end
    end
  end
  
  -- Fallback: Check if vehicle has our tag
  local tags = vehicle:GetTags()
  if tags then
    for i = 0, tags.size - 1 do
      local tag = tags:Get(i)
      if tag and tostring(tag) == TAG then
        return true
      end
    end
  end
  
  return false
end

local function checkPlayerVehicleEntry()
  -- Execute toggle command if system is active
  if toggleSystem.active then
    executeToggleCommand()
  end
  
  local player = Game.GetPlayer()
  if not player then return end
  
  local currentVehicle = Game['GetMountedVehicle;GameObject'](player)
  local isInVehicle = currentVehicle ~= nil
  
  -- Track vehicle entry/exit for logging only
  if isInVehicle and not playerVehicleState.wasInVehicle then
    playerVehicleState.wasInVehicle = true
    playerVehicleState.currentVehicle = currentVehicle
  elseif not isInVehicle and playerVehicleState.wasInVehicle then
    playerVehicleState.wasInVehicle = false
    playerVehicleState.currentVehicle = nil
  end
  
  playerVehicleState.lastCheckedVehicle = currentVehicle
end



----------------------------- Money + Grant -----------------------------
local function getMoneySafe()
  local ok, amt = pcall(function()
    local ts = Game.GetTransactionSystem(); local p = Game.GetPlayer()
    if ts and p then return ts:GetItemQuantity(p, TweakDBID.new("Items.money")) end
  end)
  return ok and amt or nil
end
local function hasEnough(price)
  local amt = getMoneySafe()
  return (type(amt)=="number") and (amt >= price) or true
end
local function charge(price) Game.AddToInventory("Items.money", -math.abs(price)) end

local function addVehicle(veh)
  local VS = Game.GetVehicleSystem()
  local function say(t) alertMsg(t, 5.0) end
  if TweakDB:GetRecord(veh) then
    local man = TweakDB:GetRecord(veh):Manufacturer():EnumName()
    local nm  = Game.GetLocalizedTextByKey(TDB.GetLocKey(veh..".displayName"))
    if VS:IsVehiclePlayerUnlocked(veh) then
      say(man.." - "..nm.."\nALREADY IN THE GARAGE.")
    else
      VS:EnablePlayerVehicle(veh, true, false)
      say("ADDED TO THE GARAGE :\n"..man.."  -  "..nm)
    end
  else
    say("VEHICLE ID NOT VALID.")
  end
end

----------------------------- Pricing -----------------------------
local function pick_price_for(item)
  local low, high = item.price.low, item.price.high
  local t = os.date("*t") -- Sun=1 .. Sat=7
  if item.discount and type(item.discount.days)=="table" then
    for _,d in ipairs(item.discount.days) do
      if t.wday == d then low, high = item.discount.low, item.discount.high; break end
    end
  end
  if low > high then low, high = high, low end
  local price = math.random(math.floor(low), math.floor(high))
  local note = (item.discount and "Discount Day" or "Standard Day")
  return price, note
end

----------------------------- UI State & Hubs -----------------------------
local state = {
  showing=false, phase="root",
  currentCarSetIndex=0, -- Which set of 3 cars (0, 1, 2)
  atEntrance=false, -- Whether player is at entrance
  atEntrance2=false, -- Whether player is at second entrance
  atShopExit=false, -- Whether player is at shop exit
  usedEntrance=1 -- Track which entrance was used (1 or 2)
}
local function resetOffer() 
  -- Don't despawn cars here - they stay persistent
  state.currentCarSetIndex = currentPoolIndex
end
local function hideHub() 
  pcall(function() ui.hideHub(); ui.clearCallbacks() end)
  hideSimpleUI()
  state.showing=false 
end
local function showOfferHub() end -- forward declare

-- --- tiny scheduler ---
local __tasks = {}
local function later(delay, fn)
  __tasks[#__tasks+1] = {t = os.clock() + (delay or 0), fn = fn}
end
local function runDueTasks()
  local now = os.clock()
  local i = 1
  while i <= #__tasks do
    if __tasks[i].t <= now then
      local task = table.remove(__tasks, i)
      pcall(task.fn)
    else
      i = i + 1
    end
  end
end

local function showEntranceHub()
  state.showing=true
  state.atEntrance=true
  local choices = {"Visit Shop", "Ignore"}
  local callbacks = {
    function()
      hideHub()
      state.atEntrance=false
      state.usedEntrance=1 -- Track that entrance 1 was used
      state.phase="root"

      -- Step 1: initial teleport immediately
      Game.GetTeleportationFacility():Teleport(
        Game.GetPlayer(),
        ToVector4{x=595.40784, y=-394.04953, z=9.180862, w=1},
        ToEulerAngles{roll=0, pitch=0, yaw=10.703067}
      )

      -- 
      -- Single FX at start
      Game.GetFxSystem():SpawnEffect(
        gameFxResource.new({effect="base\\fx\\camera\\fast_travel_glitch\\fast_travel_glitch.effect"}),
        (function() local t=WorldTransform.new(); local p=Game.GetPlayer(); t:SetOrientation(p:GetWorldOrientation()); t:SetPosition(p:GetWorldPosition()); return t end)()
      )

      -- Mid-step teleport after brief delay
      later(0.40, function()
        Game.GetTeleportationFacility():Teleport(
          Game.GetPlayer(),
          ToVector4{x=597.40784, y=-395.54953, z=9.680862, w=1},
          ToEulerAngles{roll=0, pitch=0, yaw=11.703067}
        )
      end)

      -- Final step
      later(0.80, function()
        teleportPlayer({ x = 605.2473, y = -398.05392, z = 10.171738, w = 1, angle = 7.2700634 })

        -- Reset car indices and spawn first set
        currentCarIndices = { cheap = 1, high_end = 1, heavy_duty = 1, bikes = 1, savedspot = 1 }
        spawnCurrentCarSet()

        -- Start 10,000-iteration toggle system
        toggleSystem.active = true
        toggleSystem.currentIteration = 0
        playerVehicleState.monitoringActive = true

        alertMsg("Welcome to Dedka's Dealership!", 3)
      end)
    end,
    function() 
      hideHub()
      state.atEntrance=false
      state.phase="root"
    end
  }
  
  local ok = pcall(function()
    ui.clearCallbacks()
    local uiChoices = { 
      ui.createChoice("Visit Shop"), 
      ui.createChoice("Ignore")
    }
    ui.registerChoiceCallback(1, callbacks[1])
    ui.registerChoiceCallback(2, callbacks[2])
    local hub = ui.createHub("Dedka's Dealership", uiChoices)
    ui.setupHub(hub); ui.showHub()
  end)
  
  if not ok then
    showSimpleUI("Dedka's Dealership", choices, callbacks)
  end
end

local function showEntrance2Hub()
  state.showing=true
  state.atEntrance2=true
  local choices = {"Visit Shop", "Ignore"}
  local callbacks = {
    function()
      hideHub()
      state.atEntrance2=false
      state.usedEntrance=2 -- Track that entrance 2 was used
      state.phase="root"

      -- Step 1: initial teleport immediately
      Game.GetTeleportationFacility():Teleport(
        Game.GetPlayer(),
        ToVector4{x=595.40784, y=-394.04953, z=9.180862, w=1},
        ToEulerAngles{roll=0, pitch=0, yaw=10.703067}
      )

      -- Single FX at start
      Game.GetFxSystem():SpawnEffect(
        gameFxResource.new({effect="base\\fx\\camera\\fast_travel_glitch\\fast_travel_glitch.effect"}),
        (function() local t=WorldTransform.new(); local p=Game.GetPlayer(); t:SetOrientation(p:GetWorldOrientation()); t:SetPosition(p:GetWorldPosition()); return t end)()
      )

      -- Mid-step teleport after brief delay
      later(0.40, function()
        Game.GetTeleportationFacility():Teleport(
          Game.GetPlayer(),
          ToVector4{x=597.40784, y=-395.54953, z=9.680862, w=1},
          ToEulerAngles{roll=0, pitch=0, yaw=11.703067}
        )
      end)

      -- Final step
      later(0.80, function()
        teleportPlayer({ x = 605.2473, y = -398.05392, z = 10.171738, w = 1, angle = 7.2700634 })

        -- Reset car indices and spawn first set
        currentCarIndices = { cheap = 1, high_end = 1, heavy_duty = 1, bikes = 1, savedspot = 1 }
        spawnCurrentCarSet()

        -- Start 10,000-iteration toggle system
        toggleSystem.active = true
        toggleSystem.currentIteration = 0
        playerVehicleState.monitoringActive = true

        alertMsg("Welcome to Dedka's Dealership!", 3)
      end)
    end,
    function() 
      hideHub()
      state.atEntrance2=false
      state.phase="root"
    end
  }
  
  local ok = pcall(function()
    ui.clearCallbacks()
    local uiChoices = { 
      ui.createChoice("Visit Shop"), 
      ui.createChoice("Ignore")
    }
    ui.registerChoiceCallback(1, callbacks[1])
    ui.registerChoiceCallback(2, callbacks[2])
    local hub = ui.createHub("Dedka's Dealership", uiChoices)
    ui.setupHub(hub); ui.showHub()
  end)
  
  if not ok then
    showSimpleUI("Dedka's Dealership", choices, callbacks)
  end
end

local function showShopExitHub()
  state.showing=true
  state.atShopExit=true
  local choices = {"Visit", "Leave"}
  local callbacks = {
    function() 
      -- Visit does nothing
      hideHub()
      state.atShopExit=false
      state.phase="root"
    end,
    function() 
      hideHub()
      state.atShopExit=false
      
      -- Stop toggle system immediately
      toggleSystem.active = false
      toggleSystem.currentIteration = 0
      playerVehicleState.monitoringActive = false
      
      -- Teleport back to the entrance that was used
      playFX()
      if state.usedEntrance == 2 then
        teleportPlayer(ENTRANCE_POS_2)
      else
        teleportPlayer(ENTRANCE_POS)
      end
      
      state.phase="root"
      alertMsg("Thanks for visiting Dedka's Dealership!", 3)
    end
  }
  
  local ok = pcall(function()
    ui.clearCallbacks()
    local uiChoices = { 
      ui.createChoice("Visit"), 
      ui.createChoice("Leave")
    }
    ui.registerChoiceCallback(1, callbacks[1])
    ui.registerChoiceCallback(2, callbacks[2])
    local hub = ui.createHub("Shop Exit", uiChoices)
    ui.setupHub(hub); ui.showHub()
  end)
  
  if not ok then
    showSimpleUI("Shop Exit", choices, callbacks)
  end
end

local function showRootHub()
  state.showing=true
  local choices = {"Next Set", "Previous Set", "Buy Car", "Ignore"}
  local callbacks = {
    function() nextCarSet() end,
    function() previousCarSet() end,
    function() hideHub(); state.phase="buy"; showBuyHub() end,
    function() hideHub(); state.phase="root" end
  }
  
  local ok = pcall(function()
    ui.clearCallbacks()
    local uiChoices = { 
      ui.createChoice("Next Set"), 
      ui.createChoice("Previous Set"), 
      ui.createChoice("Buy Car"),
      ui.createChoice("Ignore") 
    }
    ui.registerChoiceCallback(1, callbacks[1])
    ui.registerChoiceCallback(2, callbacks[2])
    ui.registerChoiceCallback(3, callbacks[3])
    ui.registerChoiceCallback(4, callbacks[4])
    local hub = ui.createHub("Car Seller - RA Rotation System", uiChoices)
    ui.setupHub(hub); ui.showHub()
  end)
  
  if not ok then
    showSimpleUI("Car Seller - RA Rotation System", choices, callbacks)
  end
end

function showBuyHub()
  state.showing=true
  
  local choices = {}
  local callbacks = {}
  
  -- Add options for each category's current car with location info
  local locationNames = {
    cheap = "FRONT RIGHT",
    high_end = "CENTER", 
    heavy_duty = "RIGHT BACK",
    bikes = "FRONT LEFT",
    savedspot = "SPECIAL SPOT"
  }
  
  for cat, carData in pairs(activeCarSet) do
    if carData and carData.item then
      local item = carData.item
      local price, note = pick_price_for(item)
      local location = locationNames[cat] or "UNKNOWN"
      local choiceText = string.format("%s: %s - %s", location, item.name, fmtMoney(price))
      
      table.insert(choices, choiceText)
      table.insert(callbacks, function()
        if not hasEnough(price) then 
          alertMsg("Not enough eddies!", 4) 
          return 
        end
        
        charge(price)
        addVehicle(item.grantId or item.spawnId)
        alertMsg("Purchase successful! " .. item.name .. " added to garage.", 4)
        playFX()
        hideHub()
        state.phase = "root"
        showRootHub()
      end)
    end
  end
  
  table.insert(choices, "Back")
  table.insert(callbacks, function() hideHub(); state.phase="root"; showRootHub() end)
  
  local title = "Car Seller — RA Rotation Purchase"
  
  local ok = pcall(function()
    ui.clearCallbacks()
    local uiChoices = {}
    for i, choice in ipairs(choices) do
      uiChoices[i] = ui.createChoice(choice)
      ui.registerChoiceCallback(i, callbacks[i])
    end
    local hub = ui.createHub(title, uiChoices)
    ui.setupHub(hub); ui.showHub()
  end)
  
  if not ok then
    showSimpleUI(title, choices, callbacks)
  end
end



----------------------------- Lifecycle & Proximity -----------------------------
registerForEvent("onInit", function()
  math.randomseed(os.time())
  ui.init()
  
  -- Initialize map marker filter
  ensureJobsFilterHasVariant()
  
  -- Create entrance map marker
  createShopMapMarker()
  
  load_catalog_from_json_dir(CATALOG_DIR)
  
  -- Cars will only spawn when player visits shop from entrance
end)

registerForEvent("onDraw", function() if ui then pcall(ui.update) end end) -- [CET-Cleans] no per-frame closure

registerForEvent("onShutdown", function()
  despawnAll()
  removeShopMapMarker()
  ui.clearCallbacks()
end)

registerForEvent("onUpdate", function(_)
  runDueTasks()  -- make scheduled steps tick
  local p = Game.GetPlayer(); if not p then return end
  local pos = p:GetWorldPosition()

  -- Check for vehicle entry/exit and execute toggle commands
  checkPlayerVehicleEntry()
  
  -- Process any pending timers (for making vehicles immovable)
  for i = #activeSpawns, 1, -1 do
    local spawn = activeSpawns[i]
    if type(spawn) == "table" and spawn.type == "timer" and spawn.check then
      if spawn.check() then
        table.remove(activeSpawns, i)
      end
    end
  end

  local nearEntrance = isNear(pos, ENTRANCE_POS, OPEN_RADIUS_M)
  local farFromEntrance = not isNear(pos, ENTRANCE_POS, CLOSE_RADIUS_M)
  local nearEntrance2 = isNear(pos, ENTRANCE_POS_2, OPEN_RADIUS_M)
  local farFromEntrance2 = not isNear(pos, ENTRANCE_POS_2, CLOSE_RADIUS_M)
  local nearSeller = isNear(pos, SELLER_POS, OPEN_RADIUS_M)
  local farFromSeller = not isNear(pos, SELLER_POS, CLOSE_RADIUS_M)
  local nearShopExit = isNear(pos, SHOP_EXIT_POS, OPEN_RADIUS_M)
  local farFromShopExit = not isNear(pos, SHOP_EXIT_POS, CLOSE_RADIUS_M)
  
  -- Handle entrance interaction (highest priority)
  if nearEntrance and not state.showing and not state.atEntrance then
    showEntranceHub()
  elseif state.atEntrance and farFromEntrance then
    hideHub()
    state.atEntrance = false
  
  -- Handle second entrance interaction
  elseif nearEntrance2 and not state.showing and not state.atEntrance2 then
    showEntrance2Hub()
  elseif state.atEntrance2 and farFromEntrance2 then
    hideHub()
    state.atEntrance2 = false
  
  -- Handle shop exit interaction
  elseif nearShopExit and not state.showing and not state.atShopExit then
    showShopExitHub()
  elseif state.atShopExit and farFromShopExit then
    hideHub()
    state.atShopExit = false
  
  -- Handle main seller interaction (original logic)
  elseif state.phase=="root" and not state.showing and nearSeller and not state.atEntrance and not state.atEntrance2 and not state.atShopExit then
    showRootHub()
  -- Hide UI when walking away, but preserve state
  elseif state.showing and farFromSeller and not state.atEntrance and not state.atEntrance2 and not state.atShopExit then
    hideHub() -- Hide UI but don't reset state/phase
  -- Show UI again when returning, resuming where left off
  elseif not state.showing and nearSeller and state.phase ~= "root" and not state.atEntrance and not state.atEntrance2 and not state.atShopExit then
    -- Resume the appropriate menu based on current phase
    if state.phase == "buy" then
      showBuyHub()
    else
      showRootHub() -- Default back to root
    end
  end
end)
