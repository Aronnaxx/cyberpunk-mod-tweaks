local Odometer = require('odometer')
local state = Odometer.new()
local elapsed, garageElapsed, importElapsed, mountedImportElapsed = 0, 30, 30, 1
local garageDirty, lastMountedKey, lastIntegrated = true, nil, nil
local session, owner = nil, nil
local owned = {}
local garageIDs = {}
local importQueue, importHead = {}, 1
local committedSnapshots = {}
local cachedNCGT, ncgtLookupCooldown = nil, 0

local GARAGE_IMPORT_BUDGET = 1
local GARAGE_REFRESH_INTERVAL = 30
local PARKED_IMPORT_INTERVAL = 30
local MOUNTED_IMPORT_INTERVAL = 4.0
local INTEGRATED_TICK_INTERVAL = 0.50
local STANDALONE_TICK_INTERVAL = 0.25
local NCGT_LOOKUP_INTERVAL = 2.0
local status = { mode='waiting', trackedVehicle=nil }

local function recordKey(id)
    return tostring(tonumber(id.hash)) .. ':' .. tostring(tonumber(id.length))
end
local function entityKey(entity)
    return 'entity:' .. tostring(entity:GetEntityID().hash)
end
local function reset()
    Odometer.reset(state)
    elapsed,garageElapsed,importElapsed,mountedImportElapsed=0,GARAGE_REFRESH_INTERVAL,PARKED_IMPORT_INTERVAL,MOUNTED_IMPORT_INTERVAL
    garageDirty,lastMountedKey,lastIntegrated=true,nil,nil
    session,owner=nil,nil
    owned={}
    garageIDs={}
    importQueue,importHead={},1
    committedSnapshots={}
    cachedNCGT,ncgtLookupCooldown=nil,0
    status.mode='waiting'; status.trackedVehicle=nil
end
local function ncgtModule()
    if type(cachedNCGT)=='table' and type(cachedNCGT.getOdometerSnapshot)=='function' then
        return cachedNCGT
    end
    if ncgtLookupCooldown>0 or type(GetMod)~='function' then return nil end
    ncgtLookupCooldown=NCGT_LOOKUP_INTERVAL
    local ok, mod=pcall(GetMod,'NightCityGT_LiveTuning')
    if ok and type(mod)=='table' and type(mod.getOdometerSnapshot)=='function' then
        cachedNCGT=mod
        return mod
    end
    cachedNCGT=nil
    return nil
end
local function importSnapshot(player,id,ncgt,entity)
    local key=recordKey(id)
    local ok,snapshot
    if type(ncgt.getVanguardOdometerSnapshot)=='function' then
        ok,snapshot=pcall(ncgt.getVanguardOdometerSnapshot,id)
    elseif entity and type(ncgt.getOdometerSnapshot)=='function' then
        ok,snapshot=pcall(ncgt.getOdometerSnapshot,entity,player:VanguardAutoGetOdometerMeters(id))
    end
    if not ok then cachedNCGT=nil; ncgtLookupCooldown=0; return false end
    local meters=Odometer.acceptSnapshot(snapshot,key,entity and entityKey(entity))
    if meters==nil then return false end
    local prior=committedSnapshots[key]
    if prior and prior.meters==meters and prior.scope==snapshot.scope then return true end
    if player:VanguardAutoStoreOdometerMeters(id,meters)~=true then return false end
    committedSnapshots[key]={meters=meters,scope=snapshot.scope}
    return true
end
local function importParkedSnapshots(player,ncgt,mountedKey)
    local processed=0
    while importHead<=#importQueue and processed<GARAGE_IMPORT_BUDGET do
        local id=importQueue[importHead]
        importHead=importHead+1
        processed=processed+1
        local key=recordKey(id)
        if owned[key] and key~=mountedKey then importSnapshot(player,id,ncgt,nil) end
    end
    if #importQueue>0 and importHead>#importQueue then
        importQueue,importHead={},1
        importElapsed=0
    end
end
local function tick(dt)
    ncgtLookupCooldown=math.max(0,ncgtLookupCooldown-dt)
    local player=Game.GetPlayer()
    if not player or Game.GetSystemRequestsHandler():IsPreGame() then reset(); return end
    local currentOwner=entityKey(player)
    local currentSession=player:VanguardAutoGetOdometerSession()
    if currentOwner~=owner or currentSession~=session then
        reset(); owner=currentOwner; session=currentSession
    end
    local ncgt=ncgtModule()
    local integrated=ncgt~=nil and type(ncgt.getOdometerSnapshot)=='function'
    status.mode=integrated and 'NCGT' or 'standalone'
    local vehicle=Game['GetMountedVehicle;GameObject'](player)
    local mountedRecord=vehicle and vehicle:GetRecordID() or nil
    local mountedKey=mountedRecord and recordKey(mountedRecord) or nil
    if integrated~=lastIntegrated then
        importQueue,importHead={},1
        committedSnapshots={}
        importElapsed=PARKED_IMPORT_INTERVAL
        mountedImportElapsed=MOUNTED_IMPORT_INTERVAL
        garageDirty=true
        lastIntegrated=integrated
    end
    if mountedKey~=lastMountedKey then
        garageDirty=true
        lastMountedKey=mountedKey
        mountedImportElapsed=MOUNTED_IMPORT_INTERVAL
    end
    if not integrated and not vehicle then
        Odometer.reset(state)
        status.trackedVehicle=nil
        return
    end
    garageElapsed=garageElapsed+dt
    importElapsed=importElapsed+dt
    mountedImportElapsed=mountedImportElapsed+dt
    local garageRefreshed=false
    if garageDirty or garageElapsed>=GARAGE_REFRESH_INTERVAL then
        garageRefreshed=true
        local nextGarageIDs=player:VanguardAutoGetOdometerGarageIDs()
        local nextOwned={}
        for _,id in ipairs(nextGarageIDs) do nextOwned[recordKey(id)]=true end
        local changed=false
        for key in pairs(nextOwned) do
            if not owned[key] then changed=true; break end
        end
        if not changed then
            for key in pairs(owned) do
                if not nextOwned[key] then changed=true; break end
            end
        end
        if changed then
            importQueue,importHead={},1
            importElapsed=PARKED_IMPORT_INTERVAL
        end
        garageElapsed=0
        garageDirty=false
        owned,garageIDs=nextOwned,nextGarageIDs
        for key in pairs(committedSnapshots) do
            if not owned[key] then committedSnapshots[key]=nil end
        end
    end
    if integrated and type(ncgt.getVanguardOdometerSnapshot)=='function' then
        if #importQueue==0 and importElapsed>=PARKED_IMPORT_INTERVAL then
            importQueue,importHead=garageIDs,1
            importElapsed=0
        end
        local mountedDue=vehicle~=nil and owned[mountedKey] == true
            and mountedImportElapsed>=MOUNTED_IMPORT_INTERVAL
        if not garageRefreshed and not mountedDue then
            importParkedSnapshots(player,ncgt,mountedKey)
        end
    end
    if not vehicle then Odometer.reset(state); status.trackedVehicle=nil; return end
    local id=mountedRecord
    local key=mountedKey
    if not owned[key] then Odometer.reset(state); status.trackedVehicle=nil; return end
    status.trackedVehicle=key
    if integrated then
        Odometer.reset(state)
        if mountedImportElapsed>=MOUNTED_IMPORT_INTERVAL then
            mountedImportElapsed=0
            if not importSnapshot(player,id,ncgt,vehicle) then status.mode='NCGT waiting for save authority' end
        end
        return
    end
    local defs=Game.GetAllBlackboardDefs()
    local menu=Game.GetBlackboardSystem():Get(defs.UI_System):GetBool(defs.UI_System.IsInMenu)
    local pos=vehicle:GetWorldPosition()
    local speed=0
    local okSpeed,rawSpeed=pcall(function() return vehicle:GetCurrentSpeed() end)
    if okSpeed and type(rawSpeed)=='number' and rawSpeed==rawSpeed then speed=math.abs(rawSpeed) end
    local distance=Odometer.sample(state,{
        eligible=not menu and vehicle:IsPlayerDriver(), dt=dt,
        player=currentOwner .. ':' .. tostring(currentSession), record=key, entity=entityKey(vehicle),
        authority='standalone', x=pos.x,y=pos.y,z=pos.z,speed=speed,
    })
    if distance>0 then
        local total=player:VanguardAutoGetOdometerMeters(id)
        if Odometer.validTotal(total) then player:VanguardAutoStoreOdometerMeters(id,math.min(1000000000,total+distance)) end
    end
end

registerForEvent('onInit',function()
    reset()
    if type(ObserveAfter)=='function' then
        for _,method in ipairs({'SellOwnedVehicle','Purchase','ClearSoldVehicleRecord','QueuePurchaseConfirmation'}) do
            pcall(ObserveAfter,'CarDealer.System.PurchasableVehicleSystem',method,function()
                garageDirty=true
            end)
        end
    end
end)
registerForEvent('onShutdown',reset)
registerForEvent('onUpdate',function(delta)
    delta=tonumber(delta)
    if not delta or delta~=delta or delta<=0 or delta>3 then reset(); return end
    elapsed=elapsed+delta
    local interval=lastIntegrated==true and INTEGRATED_TICK_INTERVAL or STANDALONE_TICK_INTERVAL
    if elapsed<interval then return end
    local dt=elapsed; elapsed=0
    local ok,err=pcall(tick,dt)
    if not ok then
        Odometer.reset(state)
        status.mode='waiting for vehicle API'
        if status.lastError~=tostring(err) then print('[Vanguard Odometer] ' .. tostring(err)) end
        status.lastError=tostring(err)
    else status.lastError=nil end
end)

return { getStatus=function() return {mode=status.mode,trackedVehicle=status.trackedVehicle,lastError=status.lastError} end }
