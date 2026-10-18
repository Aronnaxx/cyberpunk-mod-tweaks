local Coverage = require('module/Coverage')
local StoryAlertGate = require('module/StoryAlertGate')
local PhoneAlerts = require('module/PhoneAlerts')
local DelamainRepairExemption = require('module/DelamainRepairExemption')
local Opt = require('module/VanguardOptions')

local Adapter = {}

local SYSTEM_CANDIDATES = {
    'CarDealer.System.PurchasableVehicleSystem',
    'VanguardAuto.System.PurchasableVehicleSystem',
    'VanguardAuto.System.VehicleDealerSystem',
    'VirtualCarDealer.System.PurchasableVehicleSystem',
}

local GARAGE_METHODS = {
    'GetOwnedVehiclesData',
    'GetGarageVehiclesData',
    'GetOwnedVehicles',
    'GetGarageVehicles',
    'GetVehiclesData',
}

local VALUE_FLATS = {
    '.dealerPrice',
    '.autofixer',
    '.price',
    '.purchasePrice',
}

local lastSystemName = ''
local cachedDealershipSystem = nil
local nextDealershipSystemLookup = 0.0
local DEALERSHIP_SYSTEM_LOOKUP_RETRY = 4.0
local repairJob = nil
local UNINSURED_REPAIR_MESSAGE = 'This vehicle is not covered under your insurance policy.'
local DAMAGE_UNCOVERED_MESSAGE = 'Damage detected. This vehicle is not covered under your insurance policy.'
local NO_DAMAGE_MESSAGE = 'No damage detected.'
local SUMMON_REPAIR_PASSES = { 0.10, 0.85, 1.75, 3.25, 5.50, 8.00, 12.00, 18.00 }
                                                                                
                                                                                
                                                                                     
local ENABLE_PASSIVE_VEHICLE_CHECKER = rawget(_G or {}, 'VANGUARD_ENABLE_PASSIVE_VEHICLE_CHECKER') == true
local PASSIVE_POLL_INTERVAL = 12.00
local GARAGE_SYNC_MIN_INTERVAL = 90.00
local VEHICLE_CACHE_LOG_INTERVAL = 15.0
local NATIVE_POLICY_CACHE_TTL = 2.00
local NATIVE_STATUS_CACHE_TTL = 2.00
local WINDOW_SEATS = {
    { cname = 'seat_front_left', enum = 0 },
    { cname = 'seat_front_right', enum = 1 },
    { cname = 'seat_back_left', enum = 2 },
    { cname = 'seat_back_right', enum = 3 },
}
local pendingSummonRepairs = {}
local recentSummonRepairs = {}
local summonObserverInstalled = false
local passivePollTimer = 0.0
local lastGarageSyncClock = 0.0
local lastGarageSnapshot = ''
local lastGarageCount = 0
local currentGarageVehicleIds = {}
local hasAuthoritativeGarageSnapshot = false
local lastVehicleCacheLogKey = ''
local lastVehicleCacheLogTime = 0.0
local cached = {
    id = '',
    recordId = '',
    name = '',
    entity = nil,
    position = nil,
    rotation = nil,
}
                                                                            
                                                             
local mountedRuntime = {
    key = '__UNINITIALIZED__',
    mounted = false,
    generation = 0,
}
local nativePolicyCache = {
    time = 0.0,
    selection = nil,
    deductible = nil,
    billing = nil,
    message = nil,
}
local nativeInsuredCache = {}
local nativeTotalLossCache = {}
local nativeDestroyedCache = {}
local registeredCoverageAliases = {}
local nativeDaysCache = {
    time = 0.0,
    value = 0,
}

local function clockNow()
    local now = 0.0
    pcall(function() now = tonumber(os.clock()) or 0.0 end)
    return now
end

local function cloneMap(source)
    local out = {}
    for key, value in pairs(source or {}) do
        out[key] = value
    end
    return out
end

local function clearNativeCaches()
    nativePolicyCache.time = 0.0
    nativePolicyCache.selection = nil
    nativePolicyCache.deductible = nil
    nativePolicyCache.billing = nil
    nativePolicyCache.message = nil
    nativeInsuredCache = {}
    nativeTotalLossCache = {}
    nativeDestroyedCache = {}
    registeredCoverageAliases = {}
    nativeDaysCache.time = 0.0
    nativeDaysCache.value = 0
end

local function safeString(value)
    return tostring(value or ''):gsub('[\r\n]+', ' '):gsub('|', '/'):gsub('%s+', ' ')
end

local function round(value)
    return math.max(0, math.floor((tonumber(value) or 0) + 0.5))
end

local function tdbidToString(value)
    local out = nil
    pcall(function()
        if TDBID and TDBID.ToStringDEBUG then
            out = TDBID.ToStringDEBUG(value)
        end
    end)
    if not out or out == '' then out = tostring(value or '') end
    return safeString(out)
end

local function nativeTdbidToVehicleKey(value)
    if value == nil then return '' end

    local validityKnown = false
    local valid = false
    pcall(function()
        if TDBID and TDBID.IsValid then
            validityKnown = true
            valid = TDBID.IsValid(value) == true
        end
    end)
    if validityKnown and not valid then return '' end

    local key = tdbidToString(value)
    local lowered = key:lower():gsub('%s+', '')
    if lowered == '' or lowered == 'nil' or lowered == '0'
        or lowered:find('invalid', 1, true)
        or lowered:find('tweakdbid(0', 1, true)
        or lowered:find('userdata', 1, true) then
        return ''
    end
    return key
end

local function normalizeVehicleId(value)
    local s = safeString(value):lower()
    s = s:gsub('^t"', ''):gsub('"$', '')
    s = s:gsub('^vehicle%.', '')
    s = s:gsub('^vehicles%.', '')
    s = s:gsub('^base%.vehicles%.', '')
    s = s:gsub('^record%.', '')
    s = s:gsub('[%[%]{}%(%)"]', '')
    s = s:gsub("'", '')
    s = s:gsub('%s+', '')
    s = s:gsub('_playervehicle$', '')
    return s
end

local function vehicleIdsEquivalent(a, b)
    local aRaw = safeString(a)
    local bRaw = safeString(b)
    if aRaw ~= '' and bRaw ~= '' and aRaw:lower() == bRaw:lower() then return true end

    local an = normalizeVehicleId(aRaw)
    local bn = normalizeVehicleId(bRaw)
    if an ~= '' and bn ~= '' and an == bn then return true end

    return false
end

local function rememberCurrentGarageVehicleIds(vehicles)
    currentGarageVehicleIds = {}
    for _, vehicle in ipairs(vehicles or {}) do
        local key = normalizeVehicleId(vehicle and vehicle.id or '')
        if key ~= '' and key ~= 'nil' then
            currentGarageVehicleIds[key] = true
        end
    end
end

local function isCurrentGarageVehicleId(vehicleId)
    local key = normalizeVehicleId(vehicleId)
    return key ~= '' and key ~= 'nil' and currentGarageVehicleIds[key] == true
end

local function objectKey(entity)
    if not entity then return 'nil' end

    local id = nil
    pcall(function()
        if entity.GetEntityID then id = safeString(entity:GetEntityID()) end
    end)
    if id and id ~= '' and id ~= 'nil' then return id end

    pcall(function()
        if entity.GetRecordID then id = tdbidToString(entity:GetRecordID()) end
    end)
    if id and id ~= '' and id ~= 'nil' then return id end

    return safeString(entity)
end

local function normalizeDisplayText(value)
    return safeString(value):lower():gsub('[^a-z0-9]+', '')
end

local function deliverNotificationNow(message, category)
    return PhoneAlerts.deliver(message, category)
end

local function notify(message, category)
    message = tostring(message or '')
    if message == '' then return false end
    category = tonumber(category) or 102
    if PhoneAlerts.isEnabled(category) == false then return true end
    print('[Vanguard Coverage] ' .. message)
    if StoryAlertGate.isSuppressed() then
        return StoryAlertGate.enqueue('coverage:' .. category .. ':' .. string.lower(message), message, category)
    end
    if deliverNotificationNow(message, category) then return true end
    return StoryAlertGate.enqueue('coverage:' .. category .. ':' .. string.lower(message), message, category)
end

function Adapter.notify(message, category)
    return notify(message, category)
end

function Adapter.deliverAlertNow(message, category)
    return deliverNotificationNow(message, category)
end

local function tryTweakValue(recordId)
    local key = tdbidToString(recordId)
    if not key or key == '' or key == 'nil' then return 0 end
    for _, flat in ipairs(VALUE_FLATS) do
        local ok, value = pcall(function() return TweakDB:GetFlat(key .. flat) end)
        if ok and tonumber(value) and tonumber(value) > 0 then return round(value) end
    end
    return 0
end

local function scriptableContainer()
    local ok, container = pcall(function() return Game.GetScriptableSystemsContainer() end)
    if ok then return container end
    return nil
end

local function playerObject()
    local ok, player = pcall(function() return Game.GetPlayer() end)
    if ok then return player end
    return nil
end

local function vehicleSystem()
    local ok, system = pcall(function() return Game.GetVehicleSystem() end)
    if ok then return system end
    return nil
end

local function getScriptableSystem(container, name)
    if not container or not name or name == '' then return nil end

                                                                               
                                                                                
                                                             
    local okCName, cname = pcall(function()
        if CName and CName.new then return CName.new(name) end
        return nil
    end)
    if okCName and cname then
        local okSystem, system = pcall(function() return container:Get(cname) end)
        if okSystem and system then return system end
    end

                                                                             
    local okSystem, system = pcall(function() return container:Get(name) end)
    if okSystem and system then return system end
    return nil
end

local function validatesCoverageBridge(system)
    if not system then return false end
    local okCount, count = pcall(function()
        return system:GetCoverageSelectedVehicleCount()
    end)
    if not okCount or tonumber(count) == nil then return false end

    local okActive, active = pcall(function()
        return system:HasVanguardCoverageActivePolicy()
    end)
    return okActive and type(active) == 'boolean'
end

function Adapter.findDealershipSystem()
    if cachedDealershipSystem then return cachedDealershipSystem end

    local now = 0.0
    pcall(function() now = tonumber(os.clock()) or 0.0 end)
    if now > 0.0 and now < nextDealershipSystemLookup then return nil end
    if now > 0.0 then nextDealershipSystemLookup = now + DEALERSHIP_SYSTEM_LOOKUP_RETRY end

    local container = scriptableContainer()
    if not container then return nil end

    for _, name in ipairs(SYSTEM_CANDIDATES) do
        local system = getScriptableSystem(container, name)
        if validatesCoverageBridge(system) then
            lastSystemName = name
            cachedDealershipSystem = system
            nextDealershipSystemLookup = 0.0
            print('[Vanguard Coverage] website policy bridge found: ' .. tostring(name))
            return system
        end
    end

    return nil
end

function Adapter.getLastSystemName()
    return lastSystemName
end

local function clearCachedMountedVehicle()
    cached.id = ''
    cached.recordId = ''
    cached.name = ''
    cached.entity = nil
    cached.position = nil
    cached.rotation = nil
end

function Adapter.clearNativeCoverageRuntimeAliases()
    local system = Adapter.findDealershipSystem()
    local cleared = false

    if system then
        pcall(function()
            if system.ClearVanguardCoverageRuntimeAliases then
                cleared = system:ClearVanguardCoverageRuntimeAliases() == true
            end
        end)
    end

    registeredCoverageAliases = {}
    return cleared
end

function Adapter.resetMountedVehicleRuntime(reason, clearAliases)
                                                                              
                                                                                 
                                                                                
                                                                            
    clearCachedMountedVehicle()
    clearNativeCaches()
    if clearAliases == true then Adapter.clearNativeCoverageRuntimeAliases() end
    return true
end

function Adapter.resetRuntimeCache()
                                                                                
                                                                                 
                                                                                    
    pcall(function() Adapter.clearNativeCoverageRuntimeAliases() end)
    pcall(function()
        local resetDelivery = rawget(_G or {}, 'VanguardAutoDeliveryResetRuntime')
        if type(resetDelivery) == 'function' then resetDelivery() end
    end)
    lastSystemName = ''
    cachedDealershipSystem = nil
    nextDealershipSystemLookup = 0.0
    lastGarageSyncClock = 0.0
    lastGarageSnapshot = ''
    lastGarageCount = 0
    currentGarageVehicleIds = {}
    hasAuthoritativeGarageSnapshot = false
                                                                          
                                                                              
    repairJob = nil
    pendingSummonRepairs = {}
    recentSummonRepairs = {}
    clearCachedMountedVehicle()
    mountedRuntime.key = '__UNINITIALIZED__'
    mountedRuntime.mounted = false
    mountedRuntime.generation = 0
    clearNativeCaches()
end

function Adapter.invalidateNativeCaches()
    clearNativeCaches()
end

local function normalizeGarageItem(item, index)
    item = item or {}
    local recordId = item.vehicleID or item.vehicleId or item.recordId or item.tweakId or item.id
    local id = item.id or item.vehicleKey or item.key or recordId or ('garage_vehicle_' .. tostring(index))
    if recordId then id = tdbidToString(recordId) end

    local title = item.title or item.name or item.displayName or item.label or ('Vehicle ' .. tostring(index))
    title = safeString(title):gsub('%s+%-+%s+FINANCED$', '')

    local rawValue = tonumber(item.value or item.dealerPrice or item.purchasePrice or item.price or 0) or 0
    local tweakValue = recordId and tryTweakValue(recordId) or 0
    local sellValue = tonumber(item.sellValue or item.price or 0) or 0

    local value = tweakValue
    if value <= 0 then value = rawValue end
    if value <= 0 and sellValue > 0 then value = round(sellValue / 0.25) end
    if value <= 0 then value = 40000 end

    local status = tostring(item.status or item.ownership or ''):upper()
    local balanceRaw = item.financeBalance or item.remainingBalance or item.balanceDue or item.loanBalance
    local financeBalance = nil
    if balanceRaw ~= nil then
        financeBalance = tonumber(balanceRaw) or 0
    end
    local financed = item.financed == true or item.isFinanced == true or status == 'FINANCED' or title:upper():find('FINANCED', 1, true) ~= nil
    if financeBalance ~= nil and financeBalance <= 0 then
        financed = false
    end
    local contractIndex = tonumber(item.contractIndex or item.loanIndex or item.financeContractIndex) or 0
    if contractIndex <= 0 then
        local rawFinanceIndex = tonumber(item.financeIndex)
        if rawFinanceIndex ~= nil and rawFinanceIndex >= 0 then
            contractIndex = rawFinanceIndex + 1
        else
            contractIndex = index
        end
    end

    return {
        id = safeString(id),
        name = title,
        value = round(value),
        ineligible = Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = safeString(id), recordId = safeString(recordId), name = title }) == true,
        financed = financed,
        owned = item.owned ~= false,
        source = lastSystemName ~= '' and lastSystemName or 'Vanguard Garage',
        index = index,
        financeIndex = contractIndex,
        contractIndex = contractIndex,
        financeBalance = financeBalance,
        paymentFrequency = item.paymentFrequency or item.financePaymentFrequency or item.loanPaymentFrequency or item.paymentFrequencyCode or item.financePaymentFrequencyCode,
        financePaymentFrequency = item.financePaymentFrequency or item.paymentFrequency or item.loanPaymentFrequency or item.paymentFrequencyCode or item.financePaymentFrequencyCode,
        financeBillingMode = item.financeBillingMode or item.billingMode or item.insuranceBillingMode,
    }
end

function Adapter.scanGarage()
    local system = Adapter.findDealershipSystem()
    local vehicles = {}
    if not system then return vehicles, 'Vanguard dealership system not detected yet.', false end

    pcall(function()
        if system.UpdatePendingOrders then system:UpdatePendingOrders() end
    end)

    local data = nil
    for _, method in ipairs(GARAGE_METHODS) do
        local ok, result = pcall(function()
            if system[method] then return system[method](system) end
            return nil
        end)
        if ok and result then
            data = result
            break
        end
    end

    if not data then return vehicles, 'Garage system found, but no owned vehicle list method returned data.', false end

    local count = 0
    local okIter = pcall(function()
        for _, item in ipairs(data) do
            count = count + 1
            table.insert(vehicles, normalizeGarageItem(item, count))
        end
    end)

    if not okIter then return {}, 'Garage data could not be iterated.', false end
    return vehicles, 'Garage scanned: ' .. tostring(#vehicles) .. ' vehicles.', true
end

function Adapter.isVehicleRecordInstalled(vehicleId)
    local key = safeString(vehicleId)
    if key == '' or key == 'nil' or not TweakDB or not TweakDB.GetRecord then return nil end

    local ok, record = pcall(function() return TweakDB:GetRecord(key) end)
    if not ok then return nil end
    return record ~= nil
end

local function garageSnapshot(vehicles)
    local parts = {}
    for _, vehicle in ipairs(vehicles or {}) do
        parts[#parts + 1] = table.concat({
            safeString(vehicle.id),
            safeString(vehicle.name),
            tostring(tonumber(vehicle.value or 0) or 0),
            tostring(vehicle.financed == true),
            tostring(tonumber(vehicle.financeBalance or 0) or 0),
            tostring(vehicle.repossessed == true),
        }, '~')
    end
    table.sort(parts)
    return table.concat(parts, '|')
end

function Adapter.syncGarageToCoverage(force)
    local now = os.clock()
    local forceSync = force == true

                                                                              
                                                                              
    if not forceSync and lastGarageSyncClock > 0 and (now - lastGarageSyncClock) < GARAGE_SYNC_MIN_INTERVAL then
        return lastGarageCount, 'Garage sync throttled for performance.'
    end

    local vehicles, msg, authoritative = Adapter.scanGarage()
    local snapshot = garageSnapshot(vehicles)
    lastGarageSyncClock = now
    lastGarageCount = #vehicles

    if authoritative ~= true then
        return #vehicles, msg
    end

    rememberCurrentGarageVehicleIds(vehicles)

    if #vehicles <= 0 then
                                                                                 
                                                                               
        Coverage.syncVehicles({}, true, Adapter.isVehicleRecordInstalled)
        hasAuthoritativeGarageSnapshot = true
        lastGarageSnapshot = '__EMPTY__'
        return 0, msg
    end

    hasAuthoritativeGarageSnapshot = true

    if not forceSync and snapshot ~= '' and snapshot == lastGarageSnapshot then
        return #vehicles, 'Garage unchanged; coverage sync skipped.'
    end

    Coverage.syncVehicles(vehicles, true, Adapter.isVehicleRecordInstalled)
    lastGarageSnapshot = snapshot
    return #vehicles, msg
end

function Adapter.isNativeCoveragePolicyActive()
    local system = Adapter.findDealershipSystem()
    if not system then return nil, 'Vanguard website policy bridge unavailable.' end

    local ok, active = pcall(function()
        return system:HasVanguardCoverageActivePolicy()
    end)

    if not ok or type(active) ~= 'boolean' then
        return nil, 'Vanguard website active-policy state could not be read.'
    end
    return active == true, nil
end

function Adapter.readNativeCoveragePolicy(force)
    local now = clockNow()
    if force == true then
        clearNativeCaches()
    elseif nativePolicyCache.selection and now > 0.0 and (now - nativePolicyCache.time) < NATIVE_POLICY_CACHE_TTL then
        return cloneMap(nativePolicyCache.selection), nativePolicyCache.deductible, nativePolicyCache.billing, nativePolicyCache.message
    end

    local system = Adapter.findDealershipSystem()
    if not system then return nil, nil, nil, 'Vanguard website policy bridge unavailable.' end

    local okCount, count = pcall(function()
        return system:GetCoverageSelectedVehicleCount()
    end)
    if not okCount or tonumber(count) == nil then
        return nil, nil, nil, 'Vanguard website selected-vehicle count could not be read.'
    end

    local selection = {}
    count = math.max(0, math.floor(tonumber(count) or 0))
    for i = 0, count - 1 do
                                                                              
                                                                                
                                                                            
        local okId, nativeId = pcall(function()
            return system:GetVanguardCoverageSelectedVehicleIDAt(i)
        end)
        local key = ''
        if okId and nativeId then
            key = tdbidToString(nativeId)
        end

                                                                                
                                                                        
        if key == '' or key == 'nil' or key:find('userdata', 1, true) then
            local okKey, stringKey = pcall(function()
                return system:GetCoverageSelectedVehicleKeyAt(i)
            end)
            if okKey then key = safeString(stringKey) end
        end

        if key == '' or key == 'nil' or key:find('userdata', 1, true) then
            return nil, nil, nil, 'Vanguard website policy vehicle ID could not be converted at position ' .. tostring(i + 1) .. '.'
        end
        if key ~= ''
            and key ~= 'nil'
            and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(key))
            and (hasAuthoritativeGarageSnapshot ~= true or isCurrentGarageVehicleId(key)) then
            selection[key] = true
        end
    end

    local okDed, deductible = pcall(function()
        if system.GetVanguardCoverageDeductibleOption then return system:GetVanguardCoverageDeductibleOption() end
        return 3
    end)
    if not okDed then deductible = 3 end

    local okFreq, freq = pcall(function()
        if system.GetVanguardCoveragePaymentFrequency then return system:GetVanguardCoveragePaymentFrequency() end
        return 3
    end)
    if not okFreq then freq = 3 end

    local okTerm, termMonths = pcall(function()
        if system.GetVanguardCoverageTermMonths then return system:GetVanguardCoverageTermMonths() end
        return 6
    end)
    if not okTerm then termMonths = 6 end
    termMonths = tonumber(termMonths) or 6

    local billing = 'monthly'
    freq = tonumber(freq) or 3
    if freq == 0 then billing = termMonths >= 12 and 'pay_in_full_12' or 'pay_in_full'
    elseif freq == 1 then billing = termMonths >= 12 and 'weekly_12' or 'weekly'
    elseif freq == 2 then billing = termMonths >= 12 and 'biweekly_12' or 'biweekly'
    else billing = termMonths >= 12 and 'monthly_12' or 'monthly' end

    nativePolicyCache.time = clockNow()
    nativePolicyCache.selection = cloneMap(selection)
    nativePolicyCache.deductible = tonumber(deductible) or 3
    nativePolicyCache.billing = billing
    nativePolicyCache.message = 'Vanguard website policy read from ' .. tostring(lastSystemName) .. ': ' .. tostring(count) .. ' selected vehicle(s).'

    return cloneMap(selection), nativePolicyCache.deductible, nativePolicyCache.billing, nativePolicyCache.message
end

function Adapter.isNativeTotalLossLocked(vehicleId, force)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end

    local cacheKey = normalizeVehicleId(id)
    local now = clockNow()
    local cachedStatus = nativeTotalLossCache[cacheKey]
    if force ~= true and cachedStatus and now > 0.0 and (now - cachedStatus.time) < NATIVE_STATUS_CACHE_TTL then
        return cachedStatus.value == true
    end

    local system = Adapter.findDealershipSystem()
    if not system then return false end

    local ok, locked = pcall(function()
        if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then
            return false
        end
        if system.IsVanguardCoverageTotalLossLockedByKey then
            return system:IsVanguardCoverageTotalLossLockedByKey(id)
        end
        return false
    end)

    local value = ok and locked == true
    if cacheKey ~= '' and now > 0.0 then
        nativeTotalLossCache[cacheKey] = { time = now, value = value }
    end
    return value
end

function Adapter.isNativeUninsuredVehicleDestroyed(vehicleId, force)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end

    local cacheKey = normalizeVehicleId(id)
    local now = clockNow()
    local cachedStatus = nativeDestroyedCache[cacheKey]
    if force ~= true and cachedStatus and now > 0.0 and (now - cachedStatus.time) < NATIVE_STATUS_CACHE_TTL then
        return cachedStatus.value == true
    end

    local system = Adapter.findDealershipSystem()
    if not system then return false end

    local ok, destroyed = pcall(function()
        if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then
            return false
        end
        if system.IsVanguardUninsuredVehicleDestroyedByKey then
            return system:IsVanguardUninsuredVehicleDestroyedByKey(id)
        end
        return false
    end)

    local value = ok and destroyed == true
    if cacheKey ~= '' and now > 0.0 then
        nativeDestroyedCache[cacheKey] = { time = now, value = value }
    end
    return value
end

function Adapter.markNativeUninsuredVehicleDestroyed(vehicleId)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then return false end
                                                                                  
                                                                                    
    if Adapter.isNativeUninsuredVehicleDestroyed(id, true) then return true end

    local system = Adapter.findDealershipSystem()
    if not system then
        print('[Vanguard Coverage] uninsured destroyed-state mark skipped: native dealership system unavailable')
        return false
    end

    local ok, marked = pcall(function()
        if system.MarkVanguardUninsuredVehicleDestroyedByKey then
            return system:MarkVanguardUninsuredVehicleDestroyedByKey(id)
        end
        return false
    end)

    if not ok then
        print('[Vanguard Coverage] uninsured destroyed-state mark failed for ' .. tostring(id) .. ': ' .. tostring(marked))
        return false
    end

    if marked == true then
        clearNativeCaches()
        print('[Vanguard Coverage] native uninsured DESTROYED state recorded for ' .. tostring(id))
    end
    return marked == true
end

function Adapter.markNativeDestroyedWithoutSettlement(vehicleId)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end
    local system = Adapter.findDealershipSystem()
    if not system then return false end

    local ok, marked = pcall(function()
        if system.MarkVanguardDestroyedVehicleWithoutSettlementByKey then
            return system:MarkVanguardDestroyedVehicleWithoutSettlementByKey(id)
        end
        return false
    end)
    if ok and marked == true then clearNativeCaches() end
    return ok and marked == true
end

local function nativeFrequencyAndTermForBilling(billingMode)
    local mode = safeString(billingMode):lower()
    local termMonths = 6
    if mode:find('_12', 1, true) or mode:find('12', 1, true) or mode:find('annual', 1, true) or mode:find('year', 1, true) then
        termMonths = 12
    end

    local frequency = 3
    if mode:find('pay_in_full', 1, true) or mode == 'full' or mode == 'paid in full' then
        frequency = 0
    elseif mode:find('biweekly', 1, true) or mode:find('bi_weekly', 1, true) or mode:find('every_two_weeks', 1, true) then
        frequency = 2
    elseif mode:find('weekly', 1, true) then
        frequency = 1
    else
        frequency = 3
    end

    return frequency, termMonths
end

function Adapter.registerNativeCoverageAlias(liveVehicleId, policyVehicleId)
    local liveId = safeString(liveVehicleId)
    local policyId = safeString(policyVehicleId)
    if liveId == '' or liveId == 'nil' or policyId == '' or policyId == 'nil' then return false end

    local aliasKey = normalizeVehicleId(liveId)
    if aliasKey ~= '' and registeredCoverageAliases[aliasKey] == policyId then return true end

    local system = Adapter.findDealershipSystem()
    if not system then return false end

    local ok, registered = pcall(function()
        if system.RegisterVanguardCoverageRuntimeAliasByKey then
            return system:RegisterVanguardCoverageRuntimeAliasByKey(liveId, policyId)
        end
        return false
    end)

    if ok and registered == true then
        clearNativeCaches()
        if aliasKey ~= '' then registeredCoverageAliases[aliasKey] = policyId end
        return true
    end
    return false
end

function Adapter.isNativeVehicleInsured(vehicleId, force)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end

    local cacheKey = normalizeVehicleId(id)
    local now = clockNow()
    local cachedStatus = nativeInsuredCache[cacheKey]
    if force ~= true and cachedStatus and now > 0.0 and (now - cachedStatus.time) < NATIVE_STATUS_CACHE_TTL then
        return cachedStatus.value == true
    end

    local system = Adapter.findDealershipSystem()
    if not system then return false end

    local ok, insured = pcall(function()
        if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then
            return false
        end
        if system.IsVanguardCoverageVehicleInsuredByKey then
            return system:IsVanguardCoverageVehicleInsuredByKey(id)
        end
        return false
    end)

    local value = ok and insured == true
    if cacheKey ~= '' and now > 0.0 then
        nativeInsuredCache[cacheKey] = { time = now, value = value }
    end
    return value
end

function Adapter.getNativeCoverageAccountState()
    local system = Adapter.findDealershipSystem()
    if not system then
        return nil
    end

    local ok, state = pcall(function()
        if system.RefreshVanguardCoverageFraudAccountState then
            system:RefreshVanguardCoverageFraudAccountState()
        end
        return {
            recordExists = system.HasVanguardCoveragePolicyRecord and system:HasVanguardCoveragePolicyRecord() == true or false,
            termActive = system.IsVanguardCoveragePolicyTermActive and system:IsVanguardCoveragePolicyTermActive() == true or false,
            suspended = system.IsVanguardCoverageSuspended and system:IsVanguardCoverageSuspended() == true or false,
            terminated = system.IsVanguardCoveragePermanentlyTerminated and system:IsVanguardCoveragePermanentlyTerminated() == true or false,
            operational = system.IsVanguardCoverageOperational and system:IsVanguardCoverageOperational() == true or false,
            canModify = system.CanModifyVanguardCoveragePolicy and system:CanModifyVanguardCoveragePolicy() == true or false,
            strikes = system.GetVanguardCoverageFraudStrikeCount and tonumber(system:GetVanguardCoverageFraudStrikeCount()) or 0,
            suspensionExpiration = system.GetVanguardCoverageFraudSuspensionExpirationMinute and tonumber(system:GetVanguardCoverageFraudSuspensionExpirationMinute()) or 0,
        }
    end)

    if not ok or type(state) ~= 'table' then return nil end
    return state
end

function Adapter.canModifyNativeCoveragePolicy()
    local state = Adapter.getNativeCoverageAccountState()
    if not state then return false, 'UNAVAILABLE' end
    if state.terminated then return false, 'TERMINATED' end
    if state.suspended then return false, 'SUSPENDED' end
    return state.canModify == true, state.canModify == true and 'AVAILABLE' or 'RESTRICTED'
end

function Adapter.getNativeCoverageDaysRemaining(force)
    local now = clockNow()
    if force ~= true and nativeDaysCache.time > 0.0 and now > 0.0 and (now - nativeDaysCache.time) < NATIVE_POLICY_CACHE_TTL then
        return tonumber(nativeDaysCache.value) or 0
    end

    local system = Adapter.findDealershipSystem()
    if not system then return nil end

    local ok, days = pcall(function()
        return system:GetVanguardCoverageDaysRemaining()
    end)

    if not ok or tonumber(days) == nil then return nil end
    nativeDaysCache.time = clockNow()
    nativeDaysCache.value = tonumber(days) or 0
    return nativeDaysCache.value
end

function Adapter.ensureNativeCoverageVehicle(vehicleId, deductibleOption, billingMode, daysRemaining)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false, 'No vehicle id supplied for native policy restore.' end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then return false, 'Delamain cabs are ineligible for Vanguard Coverage.' end
    if Adapter.isNativeUninsuredVehicleDestroyed and Adapter.isNativeUninsuredVehicleDestroyed(id, true) then
        return false, 'Destroyed vehicles cannot be added to a Vanguard policy. Scrap the wreck from Garage.'
    end

    local system = Adapter.findDealershipSystem()
    if not system then return false, 'Vanguard dealership system not detected.' end

    local frequency, termMonths = nativeFrequencyAndTermForBilling(billingMode)
    local remaining = math.max(1, math.floor(tonumber(daysRemaining) or 1))
    local deductible = math.floor(tonumber(deductibleOption) or 3)

    local ok, restored = pcall(function()
        if system.RestoreVanguardCoverageVehicleByKey then
            return system:RestoreVanguardCoverageVehicleByKey(id, deductible, frequency, termMonths, remaining)
        end
        return false
    end)

    if not ok then return false, tostring(restored or 'native policy restore failed') end
    if restored == true then clearNativeCaches() end
    return restored == true, restored == true and 'Native policy restored for ' .. id .. '.' or 'Native policy restore was not accepted.'
end

function Adapter.createNativeTotalLossClaim(vehicleId)
    local id = safeString(vehicleId)
    if id == '' or id == 'nil' then return false end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then return false end

    local system = Adapter.findDealershipSystem()
    if not system then
        print('[Vanguard Coverage] total loss claim skipped: native dealership system unavailable')
        return false
    end

    local ok, created = pcall(function()
        if system.CreateVanguardCoverageTotalLossClaimByKey then
            return system:CreateVanguardCoverageTotalLossClaimByKey(id)
        end
        return false
    end)

    if not ok then
        print('[Vanguard Coverage] total loss claim failed for ' .. tostring(id) .. ': ' .. tostring(created))
        return false
    end

    local locked = created == true
    if not locked then
        pcall(function()
            if system.IsVanguardCoverageTotalLossLockedByKey then
                locked = system:IsVanguardCoverageTotalLossLockedByKey(id) == true
            end
        end)
    end

    if locked then
        clearNativeCaches()
        print(created == true
            and '[Vanguard Coverage] native total loss claim created for ' .. tostring(id)
            or '[Vanguard Coverage] existing native total loss claim retained for ' .. tostring(id))
    else
        local destroyedWithoutSettlement = false
        pcall(function()
            if system.IsVanguardUninsuredVehicleDestroyedByKey then
                destroyedWithoutSettlement = system:IsVanguardUninsuredVehicleDestroyedByKey(id) == true
            end
        end)
        if destroyedWithoutSettlement then
            clearNativeCaches()
            print('[Vanguard Coverage] total loss adjudication produced no retrievable settlement for ' .. tostring(id))
        end
    end
    return locked
end

local function getMountedVehicleObject()
    local player = playerObject()
    if not player then return nil end

    local vehicle = nil
    pcall(function()
        if Game and Game['GetMountedVehicle;GameObject'] then
            vehicle = Game['GetMountedVehicle;GameObject'](player)
        end
    end)
    if vehicle then return vehicle end

    pcall(function()
        if type(GetMountedVehicle) == 'function' then vehicle = GetMountedVehicle(player) end
    end)
    if vehicle then return vehicle end

    pcall(function()
        if Game.GetMountedVehicle then vehicle = Game.GetMountedVehicle(player) end
    end)
    if vehicle then return vehicle end

    pcall(function()
        if player.GetMountedVehicle then vehicle = player:GetMountedVehicle() end
    end)
    if vehicle then return vehicle end

    pcall(function()
        if player.GetVehicleObject then vehicle = player:GetVehicleObject() end
    end)

    return vehicle
end

local function currentVehicleRecordId(vehicle)
    if not vehicle then return '' end
    local id = ''
    pcall(function()
        if vehicle.GetRecordID then
            local record = vehicle:GetRecordID()
            id = tdbidToString(record)
            if (id == '' or id == 'nil' or id:find('userdata', 1, true)) and record and record.value then id = safeString(record.value) end
        end
    end)
    if id ~= '' and id ~= 'nil' then return id end

    pcall(function()
        if vehicle.GetTweakDBID then
            local record = vehicle:GetTweakDBID()
            id = tdbidToString(record)
            if (id == '' or id == 'nil' or id:find('userdata', 1, true)) and record and record.value then id = safeString(record.value) end
        end
    end)
    if id ~= '' and id ~= 'nil' then return id end

    pcall(function()
        if vehicle.GetEntityID then id = safeString(vehicle:GetEntityID()) end
    end)
    return id
end

local function currentVehicleDisplayName(vehicle)
    if not vehicle then return '' end
    local name = ''
    pcall(function()
        if vehicle.GetDisplayName then name = safeString(vehicle:GetDisplayName()) end
    end)
    if name ~= '' and name ~= 'nil' then return name end
    pcall(function()
        if vehicle.GetLocalizedName then name = safeString(vehicle:GetLocalizedName()) end
    end)
    return name
end

local function mountedEntityRuntimeKey(entity)
    if not entity then return '__UNMOUNTED__' end
    local ok, hash = pcall(function() return entity:GetEntityID().hash end)
    if ok and hash ~= nil and tostring(hash) ~= '0' and tostring(hash) ~= '0ULL' then
        return '__MOUNTED_ENTITY__|' .. tostring(hash)
    end

                                                                                  
                                                                              
                                                                             
                                                                              
                                                                               
                        
    local recordId = currentVehicleRecordId(entity)
    if recordId ~= '' and recordId ~= 'nil' and not recordId:find('userdata', 1, true) then
        return '__MOUNTED_RECORD__|' .. normalizeVehicleId(recordId)
    end

                                                                                
                                                                                 
                                                                                  
    local displayName = currentVehicleDisplayName(entity)
    if displayName ~= '' and displayName ~= 'nil' and not displayName:find('userdata', 1, true) then
        return '__MOUNTED_NAME__|' .. normalizeDisplayText(displayName)
    end

    return '__MOUNTED_PENDING__'
end

function Adapter.pollMountedVehicleTransition(force)
    local mounted = getMountedVehicleObject()
    local isMounted = mounted ~= nil

                                                                              
                                                                                 
                                                                              
                                                                                  
    local key = mountedEntityRuntimeKey(mounted)
    local changed = force == true or isMounted ~= mountedRuntime.mounted or key ~= mountedRuntime.key

    if not changed then
        return false, mounted, mountedRuntime.generation, isMounted and 'MOUNTED' or 'UNMOUNTED'
    end

    local previousKey = mountedRuntime.key
    mountedRuntime.key = key
    mountedRuntime.mounted = isMounted
    mountedRuntime.generation = mountedRuntime.generation + 1

                                                                           
                                                                               
                     
    Adapter.resetMountedVehicleRuntime('mount transition ' .. tostring(previousKey) .. ' -> ' .. tostring(key), false)
    return true, mounted, mountedRuntime.generation, isMounted and 'ENTERED' or 'EXITED'
end

function Adapter.getMountedVehicleRuntimeGeneration()
    return mountedRuntime.generation
end

local function worldSnapshot(entity)
    local pos = nil
    local rot = nil
    if entity then
        pcall(function()
            if entity.GetWorldPosition then pos = entity:GetWorldPosition() end
        end)
        pcall(function()
            if entity.GetWorldOrientation then
                rot = entity:GetWorldOrientation()
                if rot and rot.ToEulerAngles then rot = rot:ToEulerAngles() end
            end
        end)
    end

    if not pos then
        local player = playerObject()
        pcall(function()
            if player and player.GetWorldPosition then pos = player:GetWorldPosition() end
        end)
        pcall(function()
            if player and player.GetWorldOrientation then
                rot = player:GetWorldOrientation()
                if rot and rot.ToEulerAngles then rot = rot:ToEulerAngles() end
            end
        end)
    end

    return pos, rot
end

local function matchVehicleByRecord(recordId)
    recordId = safeString(recordId)
    if recordId == '' or recordId == 'nil' then return nil end

    local vehicles = Coverage.getVehiclesSorted()
    for _, vehicle in ipairs(vehicles) do
        local id = safeString(vehicle.id)
        if id ~= '' and vehicleIdsEquivalent(id, recordId) and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle)) then
            return vehicle
        end
    end

    return nil
end

local function matchVehicleByName(displayName)
    local wanted = normalizeDisplayText(displayName)
    if wanted == '' or wanted == 'nil' then return nil end

    local vehicles = Coverage.getVehiclesSorted()
    local exact = nil
    for _, vehicle in ipairs(vehicles) do
        local name = normalizeDisplayText(vehicle.name)
        if name ~= '' and name == wanted and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle)) then
            if exact then return nil end
            exact = vehicle
        end
    end

    return exact
end

local function rememberVehicleEntity(vehicle, context)
    if not vehicle then return nil end

    local recordId = currentVehicleRecordId(vehicle)
    local displayName = currentVehicleDisplayName(vehicle)
    if (recordId == '' or recordId == 'nil') and (displayName == '' or displayName == 'nil') then return nil end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = recordId, name = displayName }) then
        return nil
    end

    local matched = nil
    if recordId ~= '' and recordId ~= 'nil' then
        matched = matchVehicleByRecord(recordId)
    end
    if not matched and displayName ~= '' and displayName ~= 'nil' then
        matched = matchVehicleByName(displayName)
    end

    local pos, rot = worldSnapshot(vehicle)

    cached.recordId = recordId
    cached.id = matched and matched.id or recordId
    cached.name = matched and matched.name or (displayName ~= '' and displayName or recordId)
    cached.entity = vehicle
    cached.position = pos
    cached.rotation = rot

    context = tostring(context or 'vehicle')
    local logKey = context .. '|' .. tostring(cached.id) .. '|' .. tostring(recordId) .. '|' .. tostring(displayName)
    local now = os.clock()
    if logKey ~= lastVehicleCacheLogKey or (now - lastVehicleCacheLogTime) >= VEHICLE_CACHE_LOG_INTERVAL then
        lastVehicleCacheLogKey = logKey
        lastVehicleCacheLogTime = now
        if matched then
            print('[Vanguard Coverage] ' .. context .. ' matched: ' .. tostring(matched.name or matched.id) .. ' | record=' .. tostring(recordId) .. ' | display=' .. tostring(displayName))
        else
            print('[Vanguard Coverage] ' .. context .. ' not matched to policy garage | record=' .. tostring(recordId) .. ' | display=' .. tostring(displayName))
        end
    end

    return matched
end

local function rememberMountedVehicle(vehicle)
    return rememberVehicleEntity(vehicle, 'mounted vehicle')
end

local function readMountedPlayerOwnership(mounted, system)
    local playerOwned = false
    local ownershipKnown = false

    if system then
        pcall(function()
            if system.IsVanguardMountedPlayerVehicleOwned then
                ownershipKnown = true
                playerOwned = system:IsVanguardMountedPlayerVehicleOwned() == true
            end
        end)
    end

    if not ownershipKnown then
        pcall(function()
            if mounted and mounted.IsPlayerVehicle then
                ownershipKnown = true
                playerOwned = mounted:IsPlayerVehicle() == true
            end
        end)
    end

    if not playerOwned and mounted then
        pcall(function()
            local ps = mounted:GetVehiclePS()
            if ps then
                ownershipKnown = true
                playerOwned = ps:GetIsPlayerVehicle() == true
            end
        end)
        if not playerOwned and type(GetMod) == 'function' then
            local ok, ncgt = pcall(GetMod, 'NightCityGT_LiveTuning')
            if ok and type(ncgt) == 'table' and type(ncgt.restoreExactReplacementOwnership) == 'function' then
                local restored, result = pcall(ncgt.restoreExactReplacementOwnership, mounted)
                if restored and result == true then playerOwned, ownershipKnown = true, true end
            end
        end
    end
    return playerOwned == true, ownershipKnown == true
end

function Adapter.isExactNCGTReplacement(entity)
    if entity == nil or type(GetMod) ~= 'function' then return false end
    local ok, ncgt = pcall(GetMod, 'NightCityGT_LiveTuning')
    if not ok or type(ncgt) ~= 'table' or type(ncgt.isExactReplacementEntity) ~= 'function' then return false end
    local checked, exact = pcall(ncgt.isExactReplacementEntity, entity)
    return checked and exact == true
end

function Adapter.getMountedVehicleOwnership()
    local mounted = getMountedVehicleObject()
    if not mounted then return nil, nil end

    local playerOwned, ownershipKnown = readMountedPlayerOwnership(mounted, Adapter.findDealershipSystem())
    if not ownershipKnown then return nil, mounted end
    return playerOwned == true, mounted
end

local function getNativeMountedVehicleIdentity(mounted)
    local liveKey = ''
    local policyKey = ''
    local nativeInsured = false
    local playerOwned = false
    local system = Adapter.findDealershipSystem()
    playerOwned = select(1, readMountedPlayerOwnership(mounted, system))

    if not playerOwned then
        return {
            playerOwned = false,
            liveKey = '',
            policyKey = '',
            nativeInsured = false,
        }
    end

    if system then
                                                                                
                                                                                  
                                         
        pcall(function()
            if system.GetVanguardMountedPlayerVehicleID then
                liveKey = nativeTdbidToVehicleKey(system:GetVanguardMountedPlayerVehicleID())
            end
        end)
        pcall(function()
            if system.GetVanguardMountedCoverageVehicleID then
                policyKey = nativeTdbidToVehicleKey(system:GetVanguardMountedCoverageVehicleID())
            end
        end)
        pcall(function()
            if (liveKey == '' or liveKey == 'nil' or liveKey:find('userdata', 1, true)) and system.GetVanguardMountedPlayerVehicleKey then
                liveKey = safeString(system:GetVanguardMountedPlayerVehicleKey())
            end
        end)
        pcall(function()
            if (policyKey == '' or policyKey == 'nil' or policyKey:find('userdata', 1, true)) and system.GetVanguardMountedCoverageVehicleKey then
                policyKey = safeString(system:GetVanguardMountedCoverageVehicleKey())
            end
        end)
        pcall(function()
            if system.IsVanguardMountedPlayerVehicleInsured then
                nativeInsured = system:IsVanguardMountedPlayerVehicleInsured() == true
            end
        end)
    end

    if liveKey == '' or liveKey == 'nil' then
        liveKey = currentVehicleRecordId(mounted)
    end

                                                                                  
                                                                                  
    if playerOwned and (policyKey == '' or policyKey == 'nil') and liveKey ~= '' and liveKey ~= 'nil' then
        local selection = nil
        pcall(function()
            selection = select(1, Adapter.readNativeCoveragePolicy(true))
        end)
        for key, selected in pairs(selection or {}) do
            if selected == true and vehicleIdsEquivalent(key, liveKey) then
                policyKey = safeString(key)
                nativeInsured = true
                break
            end
        end
    end

    if policyKey ~= '' and policyKey ~= 'nil' then
        nativeInsured = true
    end

    return {
        playerOwned = playerOwned == true,
        liveKey = liveKey,
        policyKey = policyKey,
        nativeInsured = nativeInsured == true,
    }
end

function Adapter.resolveNativePolicyVehicle(liveVehicleId, displayName)
    local liveKey = safeString(liveVehicleId)
    local wantedName = normalizeDisplayText(displayName)
    if liveKey == '' or liveKey == 'nil' then return nil, '', 'no_live_vehicle_key' end
    local active = Adapter.isNativeCoveragePolicyActive()
    if active == nil then return nil, '', 'native_policy_unavailable' end
    if active ~= true then return nil, '', 'native_policy_inactive' end

                                                                              
                                                                                
                                                                         
    local selection = nil
    pcall(function() selection = select(1, Adapter.readNativeCoveragePolicy(false)) end)
    if not selection then return nil, '', 'native_policy_unavailable' end

    local function copyPolicyVehicle(policyKey, vehicle)
        local out = {}
        for key, value in pairs(vehicle or {}) do out[key] = value end
        out.id = safeString(policyKey)
        if not out.name or out.name == '' or out.name == 'nil' then
            out.name = (displayName ~= '' and displayName) or out.id
        end
        out.owned = true
        out.source = 'Vanguard Website Policy'
        return out
    end

                                                            
    for policyKey, selected in pairs(selection or {}) do
        if selected == true and vehicleIdsEquivalent(policyKey, liveKey) then
            local row = Coverage.getVehicle(policyKey) or matchVehicleByRecord(policyKey)
            return copyPolicyVehicle(policyKey, row), safeString(policyKey), 'website_policy_record'
        end
    end

                                                                                 
                                                                              
                                                                                 
    if isCurrentGarageVehicleId(liveKey) then
        return nil, '', 'website_policy_owned_record_unselected'
    end

    if wantedName == '' or wantedName == 'nil' or #wantedName < 5 then
        return nil, '', 'website_policy_no_name'
    end

    local exactMatches = {}
    for policyKey, selected in pairs(selection or {}) do
        if selected == true then
            local row = Coverage.getVehicle(policyKey) or matchVehicleByRecord(policyKey)
            local candidateName = normalizeDisplayText(row and row.name or '')
            if candidateName ~= '' and candidateName == wantedName then
                exactMatches[#exactMatches + 1] = { key = safeString(policyKey), vehicle = row }
            end
        end
    end

                                                                               
                                                                                
                                                                             
    if #exactMatches == 1 then
        local match = exactMatches[1]
        return copyPolicyVehicle(match.key, match.vehicle), match.key, 'website_policy_exact_name'
    end
    if #exactMatches > 1 then return nil, '', 'website_policy_ambiguous_name' end

    return nil, '', 'website_policy_no_match'
end

local function resolveMountedPlayerVehicle()
    local mounted = getMountedVehicleObject()
    if not mounted then return nil, nil, nil end

    local identity = getNativeMountedVehicleIdentity(mounted)
    identity.displayName = currentVehicleDisplayName(mounted)
    if not identity.playerOwned then
        return nil, mounted, identity
    end

    local displayName = identity.displayName
    identity.displayName = displayName
    local vehicle = nil
    local matchReason = ''
    local nativePolicyReason = ''

                                                                              
                                                                                
                                                                              
    pcall(function()
        local resolved, policyKey, reason = Adapter.resolveNativePolicyVehicle(identity.liveKey, displayName)
        nativePolicyReason = tostring(reason or '')
        if resolved and policyKey and policyKey ~= '' and policyKey ~= 'nil' then
            vehicle = resolved
            identity.policyKey = policyKey
            identity.nativeInsured = true
            matchReason = tostring(reason or 'website_policy')
        end
    end)

                                                                               
                                                                                 
    if not vehicle and nativePolicyReason ~= 'website_policy_owned_record_unselected' and Coverage.resolveInsuredVehicle then
        pcall(function()
            local resolved, policyKey, reason = Coverage.resolveInsuredVehicle(identity.liveKey, displayName)
            if resolved and policyKey and policyKey ~= '' and policyKey ~= 'nil' then
                vehicle = resolved
                vehicle.id = policyKey
                identity.policyKey = policyKey
                matchReason = tostring(reason or 'active_policy')
            end
        end)
    end

                                                                     
    if not vehicle then
        local lookupKeys = {}
        if identity.policyKey ~= '' and identity.policyKey ~= 'nil' then table.insert(lookupKeys, identity.policyKey) end
        if identity.liveKey ~= '' and identity.liveKey ~= 'nil' and not vehicleIdsEquivalent(identity.liveKey, identity.policyKey) then
            table.insert(lookupKeys, identity.liveKey)
        end
        for _, key in ipairs(lookupKeys) do
            vehicle = Coverage.getVehicle(key) or matchVehicleByRecord(key)
            if vehicle then break end
        end
    end

                                                                                  
                                                                                   
    if not vehicle then
        local id = identity.liveKey
        if id ~= '' and id ~= 'nil' then
            vehicle = {
                id = id,
                name = (displayName ~= '' and displayName ~= 'nil') and displayName or id,
                owned = true,
                financed = false,
                source = 'Mounted Customer Vehicle',
            }
        end
    end

    if identity.policyKey ~= '' and identity.policyKey ~= 'nil' and identity.liveKey ~= '' and identity.liveKey ~= 'nil' then
        local aliased = Adapter.registerNativeCoverageAlias(identity.liveKey, identity.policyKey)
        identity.nativeInsured = aliased == true or Adapter.isNativeVehicleInsured(identity.liveKey, true) == true
    end
    identity.matchReason = matchReason

    if vehicle and Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle) then
        return nil, mounted, identity
    end

    if vehicle then
        local pos, rot = worldSnapshot(mounted)
        cached.recordId = identity.liveKey
        cached.id = vehicle.id
        cached.name = vehicle.name or displayName or vehicle.id
        cached.entity = mounted
        cached.position = pos
        cached.rotation = rot
    end

    return vehicle, mounted, identity
end

function Adapter.getMountedVehicleIdentity()
    local vehicle, mounted, identity = resolveMountedPlayerVehicle()
    return vehicle, mounted, identity
end

                                                                                 
                                                                                 
                                                                              
function Adapter.getCachedMountedCoverageVehicle(vehicleId)
    if mountedRuntime.mounted ~= true or not cached.entity then return nil, nil end

    local requested = safeString(vehicleId)
    if requested == '' or requested == 'nil' then requested = safeString(cached.id) end
    if requested == '' or requested == 'nil' then return nil, nil end

    if cached.id ~= '' and not vehicleIdsEquivalent(cached.id, requested) then
        return nil, nil
    end

    local coverageState = Coverage.getState and Coverage.getState() or nil
    local vehicle = coverageState and coverageState.vehicles and (coverageState.vehicles[requested] or coverageState.vehicles[cached.id]) or nil
    if not vehicle then return nil, nil end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle) then return nil, nil end

    return vehicle, cached.entity
end

function Adapter.cacheMountedVehicle()
    local vehicle, mounted = resolveMountedPlayerVehicle()
    if mounted then
        return vehicle ~= nil
    end
    return false
end

function Adapter.isPlayerMounted()
    local player = playerObject()
    local inside = false
    local checked = false
    pcall(function()
        local workspot = Game.GetWorkspotSystem and Game.GetWorkspotSystem()
        if workspot and workspot.IsActorInWorkspot then
            checked = true
            inside = workspot:IsActorInWorkspot(player) == true
        end
    end)
    if inside then return true end

    pcall(function()
        if player and player.IsPlayerInVehicle then
            checked = true
            inside = player:IsPlayerInVehicle() == true
        end
    end)
    if inside then return true end
    if checked then return false end

    return getMountedVehicleObject() ~= nil
end

local function vectorLength(value)
    if not value then return 0 end
    local direct = nil
    pcall(function()
        if value.Length then direct = value:Length() end
    end)
    if tonumber(direct) then return math.abs(tonumber(direct) or 0) end
    local x, y, z = 0, 0, 0
    pcall(function() x = tonumber(value.x or value.X) or 0 end)
    pcall(function() y = tonumber(value.y or value.Y) or 0 end)
    pcall(function() z = tonumber(value.z or value.Z) or 0 end)
    return math.sqrt(x * x + y * y + z * z)
end

function Adapter.getMountedVehicleSpeed()
    local vehicle = getMountedVehicleObject()
    if not vehicle then return 0 end
    local speed = 0
    pcall(function()
        if vehicle.GetCurrentSpeed then speed = math.abs(tonumber(vehicle:GetCurrentSpeed()) or 0) end
    end)
    if speed > 0 then return speed end
    pcall(function()
        if vehicle.GetVelocity then speed = vectorLength(vehicle:GetVelocity()) end
    end)
    if speed > 0 then return speed end
    pcall(function()
        if vehicle.GetLinearVelocity then speed = vectorLength(vehicle:GetLinearVelocity()) end
    end)
    return speed or 0
end

function Adapter.isMountedVehicleMoving()
    return (tonumber(Adapter.getMountedVehicleSpeed()) or 0) > 0.75
end


local function callMethodNumber(target, names)
    if not target then return nil end
    for _, name in ipairs(names or {}) do
        local value = nil
        pcall(function()
            local method = target[name]
            if type(method) == 'function' then value = method(target) end
        end)
        if tonumber(value) then return tonumber(value) end
    end
    return nil
end

local function callMethodBool(target, names)
    if not target then return nil end
    for _, name in ipairs(names or {}) do
        local value = nil
        pcall(function()
            local method = target[name]
            if type(method) == 'function' then value = method(target) end
        end)
        if value == true then return true end
        if value == false then return false end
    end
    return nil
end

local function objectIsDestroyedOnly(entity)
    if not entity then return false end

                                                                                      
                                                                                    
                                  
    local destroyed = callMethodBool(entity, { 'IsDestroyed', 'IsDead', 'IsVehicleDestroyed', 'IsDestroyedState' })
    if destroyed == true then return true end

    local vc = nil
    pcall(function()
        if entity.GetVehicleComponent then vc = entity:GetVehicleComponent() end
    end)
    if vc then
        destroyed = callMethodBool(vc, { 'IsDestroyed', 'IsDead', 'IsVehicleDestroyed', 'IsDestroyedState' })
        if destroyed == true then return true end
    end

    local ps = nil
    pcall(function()
        if entity.GetVehiclePS then ps = entity:GetVehiclePS() end
    end)
    if ps then
        destroyed = callMethodBool(ps, { 'IsDestroyed', 'IsDead', 'IsVehicleDestroyed', 'IsDestroyedState' })
        if destroyed == true then return true end
    end

    local hp = callMethodNumber(entity, { 'GetHealth', 'GetCurrentHealth', 'GetCurrentHP', 'GetHitPoints', 'GetDurability', 'GetVehicleHealth' })
    local maxHp = callMethodNumber(entity, { 'GetMaxHealth', 'GetMaxHP', 'GetMaxHitPoints', 'GetMaxDurability', 'GetVehicleMaxHealth' })
    if hp and maxHp and maxHp > 0 and hp <= 0.01 then return true end

    if ps then
        hp = callMethodNumber(ps, { 'GetHealth', 'GetCurrentHealth', 'GetCurrentHP', 'GetHitPoints', 'GetDurability', 'GetVehicleHealth' })
        maxHp = callMethodNumber(ps, { 'GetMaxHealth', 'GetMaxHP', 'GetMaxHitPoints', 'GetMaxDurability', 'GetVehicleMaxHealth' })
        if hp and maxHp and maxHp > 0 and hp <= 0.01 then return true end
    end

    return false
end

local function objectLooksDamaged(entity)
    if not entity then return false end

                                                                  
    if objectIsDestroyedOnly(entity) then return false end

    local vc = nil
    pcall(function()
        if entity.GetVehicleComponent then vc = entity:GetVehicleComponent() end
    end)
    if vc then
        local damageLevel = nil
        pcall(function() damageLevel = tonumber(vc.damageLevel) end)
        if damageLevel and damageLevel > 0 then return true end
    end

    local flatTire = nil
    pcall(function()
        if entity.GetFlatTireIndex then flatTire = tonumber(entity:GetFlatTireIndex()) end
    end)
    if flatTire and flatTire >= 0 then return true end

    local hp = callMethodNumber(entity, { 'GetHealth', 'GetCurrentHealth', 'GetCurrentHP', 'GetHitPoints', 'GetDurability', 'GetVehicleHealth' })
    local maxHp = callMethodNumber(entity, { 'GetMaxHealth', 'GetMaxHP', 'GetMaxHitPoints', 'GetMaxDurability', 'GetVehicleMaxHealth' })
    if hp and maxHp and maxHp > 0 and hp < (maxHp * 0.985) then return true end

    local percent = callMethodNumber(entity, { 'GetHealthPercentage', 'GetDurabilityPercentage', 'GetVehicleHealthPercentage' })
    if percent and percent > 0 and percent < 98.5 then return true end

    local ps = nil
    pcall(function()
        if entity.GetVehiclePS then ps = entity:GetVehiclePS() end
    end)
    if ps then
        hp = callMethodNumber(ps, { 'GetHealth', 'GetCurrentHealth', 'GetCurrentHP', 'GetHitPoints', 'GetDurability', 'GetVehicleHealth' })
        maxHp = callMethodNumber(ps, { 'GetMaxHealth', 'GetMaxHP', 'GetMaxHitPoints', 'GetMaxDurability', 'GetVehicleMaxHealth' })
        if hp and maxHp and maxHp > 0 and hp < (maxHp * 0.985) then return true end
        percent = callMethodNumber(ps, { 'GetHealthPercentage', 'GetDurabilityPercentage', 'GetVehicleHealthPercentage' })
        if percent and percent > 0 and percent < 98.5 then return true end
    end

    return false
end

function Adapter.acceptNCGTStructuralRepair(entity, expectedRecordKey)
    if type(expectedRecordKey) ~= 'string' or expectedRecordKey == '' then return false, 'Repair record identity is required.' end
    if entity == nil or type(GetMod) ~= 'function' then return false, 'Repair entity unavailable.' end
    local ok, ncgt = pcall(GetMod, 'NightCityGT_LiveTuning')
    if not ok or type(ncgt) ~= 'table' or type(ncgt.isExactReplacementEntity) ~= 'function' then
        return false, 'NCGT repair identity service unavailable.'
    end
    local verified, exact = pcall(ncgt.isExactReplacementEntity, entity, expectedRecordKey)
    if not verified or exact ~= true then return false, 'Repair entity identity mismatch.' end
    local owned = false
    pcall(function()
        owned = entity:IsPlayerVehicle() == true or entity:GetVehiclePS():GetIsPlayerVehicle() == true
    end)
    if not owned then return false, 'Repair vehicle is not player-owned.' end
    local vehicle = matchVehicleByRecord(currentVehicleRecordId(entity))
    if not vehicle then return false, 'Repair vehicle is not registered with Vanguard.' end
    if Adapter.isNativeTotalLossLocked(vehicle.id, true)
        or Adapter.isNativeUninsuredVehicleDestroyed(vehicle.id, true)
        or objectIsDestroyedOnly(entity) then
        return false, 'Destroyed or total-loss vehicles cannot be restored through this bridge.'
    end
    if objectLooksDamaged(entity) then return false, 'The replacement has new physical damage.' end
    local accepted, message = Coverage.completeExternalStructuralRepair(vehicle.id)
    if accepted then Adapter.resetMountedVehicleRuntime('NCGT structural repair completed', false) end
    return accepted, message
end

function Adapter.objectIsDestroyedOnly(entity)
    return objectIsDestroyedOnly(entity)
end

function Adapter.isVehicleEntityIneligible(entity)
    if not entity or not Coverage.isVehicleIneligible then return false end
    return Coverage.isVehicleIneligible({ id = currentVehicleRecordId(entity), name = currentVehicleDisplayName(entity) }) == true
end

local function vehicleDamageDetected(entity, vehicleId)
    local id = safeString(vehicleId)
    if id ~= '' and id ~= 'nil' and Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then return false end
    if entity and Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = currentVehicleRecordId(entity), name = currentVehicleDisplayName(entity) }) then return false end

                                                                                    
    if entity and objectIsDestroyedOnly(entity) then return false end

    if id ~= '' and id ~= 'nil' and Adapter.isNativeTotalLossLocked(id) then return false end
    if id ~= '' and id ~= 'nil' and Adapter.isNativeUninsuredVehicleDestroyed(id) then return false end

    if entity and objectLooksDamaged(entity) then return true end

    if id ~= '' and id ~= 'nil' then
        local marked = false
        pcall(function()
            marked = Coverage.hasVehicleDamage and Coverage.hasVehicleDamage(id) == true
        end)
        if marked then return true end
    end

    return false
end

function Adapter.detectVehicleDamage(vehicleId)
                                                                                
                                                                                   
                                                                                  
                                                              
    local id = safeString(vehicleId)
    if id ~= '' and id ~= 'nil' and Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(id) then return false end
    if id ~= '' and id ~= 'nil' and Adapter.isNativeTotalLossLocked(id) then return false end
    if id ~= '' and id ~= 'nil' and Adapter.isNativeUninsuredVehicleDestroyed(id) then return false end

    local mounted = getMountedVehicleObject()
    if mounted and Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = currentVehicleRecordId(mounted), name = currentVehicleDisplayName(mounted) }) then return false end
    if objectIsDestroyedOnly(mounted) then return false end
    if vehicleDamageDetected(mounted, vehicleId) then return true end

    if objectIsDestroyedOnly(cached.entity) then return false end
    if vehicleDamageDetected(cached.entity, vehicleId) then return true end
    return false
end

function Adapter.vehicleDamageDetected(entity, vehicleId)
    return vehicleDamageDetected(entity, vehicleId)
end

local function resetAnimationInputs(entity)
    if not entity then return false end

    local touched = false
    pcall(function()
        if not AnimationControllerComponent or not AnimationControllerComponent.SetInputFloat then return end

        for _, partState in ipairs({
            'hood_destruction',
            'wheel_f_l_destruction',
            'wheel_f_r_destruction',
            'wheel_b_l_destruction',
            'wheel_b_r_destruction',
            'bumper_b_destruction',
            'bumper_f_destruction',
            'door_f_l_destruction',
            'door_f_r_destruction',
            'door_b_l_destruction',
            'door_b_r_destruction',
            'trunk_destruction',
            'bumper_b_destruction_side_2',
            'bumper_f_destruction_side_2',
            'head_light_destruction',
            'head_light_left_destruction',
            'head_light_right_destruction',
            'head_light_left_01_destruction',
            'head_light_left_02_destruction',
            'head_light_left_03_destruction',
            'head_light_left_04_destruction',
            'head_light_left_05_destruction',
            'head_light_right_01_destruction',
            'head_light_right_02_destruction',
            'head_light_right_03_destruction',
            'head_light_right_04_destruction',
            'front_light_destruction',
            'front_light_left_destruction',
            'front_light_right_destruction',
            'brake_light_destruction',
            'brake_light_left_destruction',
            'brake_light_right_destruction',
            'brake_light_left_01_destruction',
            'brake_light_left_02_destruction',
            'brake_light_right_01_destruction',
            'brake_light_right_02_destruction',
            'brake_light_trunk_01_destruction',
            'tail_light_destruction',
            'tail_light_left_destruction',
            'tail_light_right_destruction',
            'rear_light_destruction',
            'rear_light_left_destruction',
            'rear_light_right_destruction',
            'glass_destruction',
            'glass_front_destruction',
            'glass_rear_destruction',
            'glass_back_destruction',
            'glass_left_destruction',
            'glass_right_destruction',
            'window_destruction',
            'window_f_l_destruction',
            'window_f_r_destruction',
            'window_b_l_destruction',
            'window_b_r_destruction',
            'window_front_left_destruction',
            'window_front_right_destruction',
            'window_back_left_destruction',
            'window_back_right_destruction',
            'window_left_destruction',
            'window_right_destruction',
            'side_window_left_destruction',
            'side_window_right_destruction',
            'windshield_destruction',
            'windscreen_destruction',
            'windshield_front_destruction',
            'front_windshield_destruction',
            'front_windscreen_destruction',
            'windshield_rear_destruction',
            'rear_windshield_destruction',
            'rear_windscreen_destruction',
            'back_windshield_destruction',
            'back_windscreen_destruction',
            'rear_window_destruction',
            'back_window_destruction',
        }) do
            pcall(function()
                AnimationControllerComponent.SetInputFloat(entity, partState, 0.0)
                touched = true
            end)
        end
    end)

    return touched
end

local function callNoArgMethods(target, names)
    if not target then return false end
    local touched = false
    for _, name in ipairs(names or {}) do
        pcall(function()
            local method = target[name]
            if type(method) == 'function' then
                method(target)
                touched = true
            end
        end)
    end
    return touched
end

local function vehicleHasSeat(entity, seat)
    if not entity or not seat then return false end

    local checked = false
    local hasSlot = false
    pcall(function()
        local fn = Game and Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName']
        if fn and CName and CName.new then
            checked = true
            hasSlot = fn(entity, CName.new(seat.cname)) == true
        end
    end)

    if checked then return hasSlot end
    return true
end

local function getGameInstanceForVehicle(entity)
    local game = nil
    pcall(function()
        if entity and entity.GetGame then game = entity:GetGame() end
    end)
    if game then return game end

    pcall(function()
        local player = playerObject()
        if player and player.GetGame then game = player:GetGame() end
    end)

    return game
end

local function newMountingSlot(slotName)
    local slot = nil
    pcall(function()
        slot = NewObject('gamemountingMountingSlotId')
        slot.id = slotName
    end)
    return slot
end

local function queueWindowEvent(persistentState, seat, open)
    if not persistentState or not seat then return false end

    local queued = false
    pcall(function()
        local event = nil
        if open == true then
            event = VehicleWindowOpen.new()
        else
            event = VehicleWindowClose.new()
        end
        event.slotID = seat.cname
        event.forceScene = false
        persistentState:QueuePSEvent(persistentState, event)
        queued = true
    end)

    return queued
end

local function toggleVehicleWindow(entity, game, seat, open)
    if not entity or not game or not seat then return false end

    local slot = newMountingSlot(seat.cname)
    if not slot then return false end

    local toggled = false
    pcall(function()
        VehicleComponent.ToggleVehicleWindow(game, entity, slot, open == true)
        toggled = true
    end)
    pcall(function()
        local source = 'Custom'
        if CName and CName.new then source = CName.new('Custom') end
        VehicleComponent.ToggleVehicleWindow(game, entity, slot, open == true, source)
        toggled = true
    end)

    return toggled
end

local function resetPersistentGlassDestruction(entity, component, persistentState)
    local touched = false
    local targets = {}

    local function addTarget(target)
        if target then table.insert(targets, target) end
    end

    addTarget(persistentState)
    addTarget(component)
    addTarget(entity)

    pcall(function()
        if component and component.GetPS then addTarget(component:GetPS()) end
    end)
    pcall(function()
        if entity and entity.GetDevicePS then addTarget(entity:GetDevicePS()) end
    end)
    pcall(function()
        if entity and entity.GetPersistentData then addTarget(entity:GetPersistentData()) end
    end)
    pcall(function()
        if entity and entity.GetPersistentDataPS then addTarget(entity:GetPersistentDataPS()) end
    end)
    pcall(function()
        if component and component.GetPersistentData then addTarget(component:GetPersistentData()) end
    end)
    pcall(function()
        if component and component.GetPersistentDataPS then addTarget(component:GetPersistentDataPS()) end
    end)

    for _, target in ipairs(targets) do
        pcall(function()
            if target and target.destruction then
                pcall(function() target.destruction.brokenGlass = 0; touched = true end)
                pcall(function() target.destruction.brokenLights = 0; touched = true end)
                pcall(function() target.destruction.windshieldShattered = false; touched = true end)
                pcall(function() target.destruction.windshieldPoints = {}; touched = true end)
                pcall(function()
                    if target.destruction.gridValues then
                        for index = 1, 30 do
                            target.destruction.gridValues[index] = 0.0
                        end
                        touched = true
                    end
                end)
            end
        end)
    end

    return touched
end

local function refreshVehicleWindowMeshes(entity, persistentState)
    if not entity and not persistentState then return false end

    local ps = persistentState
    pcall(function()
        if not ps and entity and entity.GetVehiclePS then ps = entity:GetVehiclePS() end
    end)

    local touched = false
    if ps then
        pcall(function() ps:OpenAllVehWindows(); touched = true end)
        pcall(function() ps:CloseAllVehWindows(); touched = true end)
    end

    local game = getGameInstanceForVehicle(entity)
    for _, seat in ipairs(WINDOW_SEATS) do
        if vehicleHasSeat(entity, seat) then
            touched = queueWindowEvent(ps, seat, true) or touched
            touched = queueWindowEvent(ps, seat, false) or touched
            touched = toggleVehicleWindow(entity, game, seat, true) or touched
            touched = toggleVehicleWindow(entity, game, seat, false) or touched
        end
    end

    if ps then
        pcall(function() ps:CloseAllVehWindows(); touched = true end)
        pcall(function() ps:ForcePersistentStateChanged(); touched = true end)
    end

    return touched
end

local function forceRepairEntity(entity)
    if not entity then return false end

    local component = nil
    local persistentState = nil
    local touched = false

    pcall(function()
        if entity.GetVehicleComponent then component = entity:GetVehicleComponent() end
    end)
    pcall(function()
        if entity.GetVehiclePS then persistentState = entity:GetVehiclePS() end
    end)

    if component then
        pcall(function()
            component.damageLevel = 0
            touched = true
        end)
        pcall(function() component.bumperFrontState = 0 end)
        pcall(function() component.bumperBackState = 0 end)
    end

    pcall(function()
        if entity.GetFlatTireIndex and tonumber(entity:GetFlatTireIndex()) and tonumber(entity:GetFlatTireIndex()) >= 0 then
            for _, index in ipairs({ 0, 1, 2, 3 }) do
                pcall(function() entity:ToggleBrokenTire(index, false) end)
            end
            touched = true
        end
    end)

    touched = resetPersistentGlassDestruction(entity, component, persistentState) or touched
    touched = resetAnimationInputs(entity) or touched
    touched = refreshVehicleWindowMeshes(entity, persistentState) or touched
    touched = callNoArgMethods(entity, {
        'ResetGlass',
        'RepairGlass',
        'RepairWindows',
        'RepairAllWindows',
        'ResetWindows',
        'ResetAllWindows',
        'ResetVehicleDestruction',
        'ResetDestruction',
        'ResetAllDestruction',
        'ClearVisualDamage',
        'ClearDamage',
    }) or touched

    pcall(function()
        if entity.DestructionResetGrid then
            entity:DestructionResetGrid()
            touched = true
        end
    end)
    pcall(function()
        if entity.DestructionResetGlass then
            entity:DestructionResetGlass()
            touched = true
        end
    end)

    if persistentState then
        pcall(function() persistentState:CloseAllVehDoors(true) end)
        pcall(function() persistentState:CloseAllVehWindows() end)
        touched = resetPersistentGlassDestruction(entity, component, persistentState) or touched
        touched = refreshVehicleWindowMeshes(entity, persistentState) or touched
        touched = callNoArgMethods(persistentState, {
            'RepairGlass',
            'RepairWindows',
            'RepairAllWindows',
            'ResetWindows',
            'ResetAllWindows',
            'RestoreAllVehWindows',
            'CloseAllVehWindows',
            'ResetVehicleDestruction',
            'ClearVisualDamage',
            'ClearDamage',
        }) or touched
        pcall(function() persistentState:ForcePersistentStateChanged() end)
    end

    touched = resetPersistentGlassDestruction(entity, component, persistentState) or touched
    touched = resetAnimationInputs(entity) or touched
    touched = refreshVehicleWindowMeshes(entity, persistentState) or touched

    if component then
        touched = callNoArgMethods(component, {
            'RepairGlass',
            'RepairWindows',
            'RepairAllWindows',
            'ResetWindows',
            'ResetAllWindows',
            'ResetVehicleDestruction',
            'ResetDestruction',
            'ResetAllDestruction',
            'ClearVisualDamage',
            'ClearDamage',
        }) or touched
        pcall(function() component:UpdateDamageEngineEffects() end)
        pcall(function()
            component:RepairVehicle()
            touched = true
        end)
        pcall(function() component:VehicleVisualDestructionSetup() end)
    end

    touched = resetPersistentGlassDestruction(entity, component, persistentState) or touched
    pcall(function()
        if entity.DestructionResetGlass then
            entity:DestructionResetGlass()
            touched = true
        end
    end)
    touched = resetAnimationInputs(entity) or touched
    touched = refreshVehicleWindowMeshes(entity, persistentState) or touched

    if persistentState then
        pcall(function() persistentState:CloseAllVehWindows() end)
        pcall(function() persistentState:ForcePersistentStateChanged() end)
    end

    return touched
end

function Adapter.repairCachedVehicleEntity(vehicleId)
    local requested = safeString(vehicleId)
    local entity = cached.entity

    if not entity then
        return false, 'Repair failed: no cached vehicle entity. Drive the insured vehicle once, exit, then press the repair key.'
    end

    if requested ~= '' and requested ~= 'nil' then
        local matched = nil
        pcall(function()
            matched = rememberMountedVehicle(entity)
        end)

        if not matched and cached.recordId and cached.recordId ~= '' then
            matched = matchVehicleByRecord(cached.recordId)
        end

        if not matched or not vehicleIdsEquivalent(matched.id, requested) then
            return false, 'Repair failed: cached vehicle no longer matches the active repair claim.'
        end
    end

    if forceRepairEntity(entity) then
        return true, 'Cached insured vehicle repaired.'
    end

    return false, 'Repair failed: cached vehicle did not expose repair components.'
end

function Adapter.repairMountedVehicleEntity(vehicleId)
    local requested = safeString(vehicleId)
    local entity = getMountedVehicleObject()

    if not entity then
        return false, 'Repair failed: no mounted vehicle entity.'
    end

    local matched = nil
    pcall(function()
        matched = rememberMountedVehicle(entity)
    end)

    if requested ~= '' and requested ~= 'nil' then
        if not matched then
            local recordId = currentVehicleRecordId(entity)
            if recordId ~= '' and recordId ~= 'nil' then
                matched = matchVehicleByRecord(recordId)
            end
        end

        if not matched or not vehicleIdsEquivalent(matched.id, requested) then
            return false, 'Repair failed: mounted vehicle does not match the active policy vehicle.'
        end
    end

    if forceRepairEntity(entity) then
        return true, 'Mounted insured vehicle repaired.'
    end

    return false, 'Repair failed: mounted vehicle did not expose repair components.'
end

local function resolveSummonedCoverageVehicle(entity)
    if not entity then return nil end

    local matched = nil
    pcall(function()
        matched = rememberVehicleEntity(entity, 'summoned vehicle')
    end)
    if matched then return matched end

    local recordId = currentVehicleRecordId(entity)
    if recordId ~= '' and recordId ~= 'nil' then
        matched = matchVehicleByRecord(recordId)
        if matched then return matched end
    end

    return nil
end

local function deliveryCreatedFreshBody(entity, vehicleId)
    local hook = rawget(_G or {}, 'VanguardAutoDeliveryIsFreshSpawnActive')
    if type(hook) ~= 'function' then return false end

    local active = false
    pcall(function() active = hook(vehicleId) == true end)
    if active then return true end

    local recordId = currentVehicleRecordId(entity)
    pcall(function() active = hook(recordId) == true end)
    return active == true
end

function Adapter.queueSummonedVehicleRepair(component)
    local entity = nil
    pcall(function()
        if component and component.GetVehicle then entity = component:GetVehicle() end
    end)
    if not entity then return false end

                                                                               
                                                                               
    if repairJob then
        local recordId = currentVehicleRecordId(entity)
        local matched = nil
        pcall(function() matched = resolveSummonedCoverageVehicle(entity) end)
        local sameRecord = vehicleIdsEquivalent(recordId, repairJob.recordId)
        local sameVehicle = matched and vehicleIdsEquivalent(matched.id, repairJob.vehicleId)
        if sameRecord or sameVehicle then
            repairJob.observedEntity = entity
            print('[Vanguard Coverage] captured verified fresh-body summon entity for ' .. tostring(repairJob.vehicleName or repairJob.vehicleId))
            return false
        end
    end

    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = currentVehicleRecordId(entity), name = currentVehicleDisplayName(entity) }) then
        print('[Vanguard Coverage] summoned Delamain cab ignored; vehicle is ineligible for coverage')
        return false
    end

    Adapter.syncGarageToCoverage()

    local vehicle = resolveSummonedCoverageVehicle(entity)
    if not vehicle then
        print('[Vanguard Coverage] summoned vehicle did not match a Vanguard garage vehicle; insurance repair skipped')
        return false
    end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle) then
        print('[Vanguard Coverage] summoned Delamain cab ignored; vehicle is ineligible for coverage')
        return false
    end

    if objectIsDestroyedOnly(entity) then
        if Coverage.isInsured(vehicle.id) == true then
            Adapter.createNativeTotalLossClaim(vehicle.id)
            print('[Vanguard Coverage] summon repair skipped: insured destroyed vehicle routed to total loss')
        else
            Adapter.markNativeUninsuredVehicleDestroyed(vehicle.id)
            print('[Vanguard Coverage] summon repair skipped: uninsured vehicle recorded as DESTROYED')
        end
        return false
    end

    if Adapter.isNativeTotalLossLocked(vehicle.id) then
        print('[Vanguard Coverage] summon repair skipped: pending or closed total loss claim exists for ' .. tostring(vehicle.name or vehicle.id))
        return false
    end
    if Adapter.isNativeUninsuredVehicleDestroyed(vehicle.id) then
        print('[Vanguard Coverage] summon repair skipped: vehicle is persistently DESTROYED and must be scrapped')
        return false
    end

    local key = 'summon:' .. objectKey(entity)
    local now = os.clock()
    if recentSummonRepairs[key] and (now - recentSummonRepairs[key]) < 1.25 then return false end
    recentSummonRepairs[key] = now

    table.insert(pendingSummonRepairs, {
        entity = entity,
        vehicleId = vehicle.id,
        vehicleName = vehicle.name,
        key = key,
        timer = 0.0,
        passIndex = 1,
        claimed = false,
        damageDetected = false,
        freshBodyPending = Coverage.hasFreshBodyPending and Coverage.hasFreshBodyPending(vehicle.id) == true,
        nativeFreshBody = deliveryCreatedFreshBody(entity, vehicle.id),
    })

    print('[Vanguard Coverage] queued summon damage check for ' .. tostring(vehicle.name or vehicle.id))
    return true
end

local function updateSummonRepairJobs(delta)
    delta = tonumber(delta) or 0

    for i = #pendingSummonRepairs, 1, -1 do
        local job = pendingSummonRepairs[i]
        job.timer = (tonumber(job.timer) or 0) + delta

        local due = SUMMON_REPAIR_PASSES[job.passIndex]
        if not due then
            table.remove(pendingSummonRepairs, i)
        elseif job.timer >= due then
            if job.claimed ~= true then
                local vehicle = Coverage.getVehicle(job.vehicleId)
                if not vehicle then
                    print('[Vanguard Coverage] summon repair skipped: vehicle record disappeared')
                    table.remove(pendingSummonRepairs, i)
                elseif objectIsDestroyedOnly(job.entity) then
                    if Coverage.isInsured(vehicle.id) == true then
                        Adapter.createNativeTotalLossClaim(vehicle.id)
                        print('[Vanguard Coverage] summon repair stopped: insured destroyed vehicle handed to total loss')
                    else
                        Adapter.markNativeUninsuredVehicleDestroyed(vehicle.id)
                        print('[Vanguard Coverage] summon repair stopped: uninsured vehicle recorded as DESTROYED')
                    end
                    table.remove(pendingSummonRepairs, i)
                elseif Adapter.isNativeTotalLossLocked(vehicle.id) then
                    print('[Vanguard Coverage] summon repair stopped: total loss lock exists for ' .. tostring(vehicle.name or vehicle.id))
                    table.remove(pendingSummonRepairs, i)
                elseif Adapter.isNativeUninsuredVehicleDestroyed(vehicle.id) then
                    print('[Vanguard Coverage] summon repair stopped: persistent DESTROYED state exists for ' .. tostring(vehicle.name or vehicle.id))
                    table.remove(pendingSummonRepairs, i)
                elseif not Opt.insuranceEnabled() or not Opt.autoRepairOnSummon() then
                    print('[Vanguard Coverage] summon repair skipped by Mod Settings for ' .. tostring(vehicle.name or vehicle.id))
                    table.remove(pendingSummonRepairs, i)
                elseif Coverage.hasFreshBodyPending and Coverage.hasFreshBodyPending(vehicle.id) == true then
                    if Coverage.isInsured(vehicle.id) ~= true then
                        print('[Vanguard Coverage] fresh-body refresh deferred: policy is not active for ' .. tostring(vehicle.name or vehicle.id))
                        table.remove(pendingSummonRepairs, i)
                    elseif job.nativeFreshBody == true then
                        forceRepairEntity(job.entity)
                        pcall(function()
                            Coverage.clearFreshBodyPending(vehicle.id)
                            Coverage.saveNow()
                        end)
                        print('[Vanguard Coverage] native Delivery spawn satisfied pending fresh-body refresh for ' .. tostring(vehicle.name or vehicle.id))
                        table.remove(pendingSummonRepairs, i)
                    else
                                                                                
                                                                                 
                                                                                 
                        forceRepairEntity(job.entity)
                        local queued, reason = Adapter.queueFreshBodyReplacement(job.entity, job.vehicleId, job.vehicleName)
                        if queued then
                            print('[Vanguard Coverage] early native drive-up replacement queued for ' .. tostring(vehicle.name or vehicle.id))
                        else
                            print('[Vanguard Coverage] early fresh-body replacement deferred; marker retained: ' .. tostring(reason or 'native refresh unavailable'))
                        end
                        table.remove(pendingSummonRepairs, i)
                    end
                elseif vehicleDamageDetected(job.entity, vehicle.id) ~= true then
                    if job.passIndex < #SUMMON_REPAIR_PASSES then
                        job.passIndex = job.passIndex + 1
                        print('[Vanguard Coverage] summon repair waiting for damage state on ' .. tostring(job.vehicleName or job.vehicleId))
                    else
                                                                                  
                                                                                 
                                                              
                        print('[Vanguard Coverage] summoned vehicle has no detected damage: ' .. tostring(job.vehicleName or job.vehicleId))
                        table.remove(pendingSummonRepairs, i)
                    end
                elseif Coverage.isInsured(vehicle.id) ~= true then
                    notify(DAMAGE_UNCOVERED_MESSAGE)
                    print('[Vanguard Coverage] summoned damaged vehicle is uninsured: ' .. tostring(vehicle.name or vehicle.id))
                    table.remove(pendingSummonRepairs, i)
                else
                    pcall(function()
                        Coverage.markVehicleDamage(vehicle.id, 'insured summon repair claim')
                    end)

                    local ok, msg = Coverage.repairVehicle(vehicle.id, function()
                        return forceRepairEntity(job.entity)
                    end)
                    notify(msg or (ok and 'Repair claim approved.' or 'Repair claim denied.'))

                    if ok then
                        if job.nativeFreshBody == true then
                            pcall(function()
                                Coverage.clearFreshBodyPending(vehicle.id)
                                Coverage.saveNow()
                            end)
                            print('[Vanguard Coverage] native Delivery spawn completed the insured body refresh for ' .. tostring(vehicle.name or vehicle.id))
                            table.remove(pendingSummonRepairs, i)
                        else
                            local queued, reason = Adapter.queueFreshBodyReplacement(job.entity, job.vehicleId, job.vehicleName)
                            if queued then
                                print('[Vanguard Coverage] insured clean drive-up replacement queued for ' .. tostring(vehicle.name or vehicle.id))
                            else
                                print('[Vanguard Coverage] insured fresh-body replacement deferred; marker retained: ' .. tostring(reason or 'native refresh unavailable'))
                            end
                            table.remove(pendingSummonRepairs, i)
                        end
                    else
                        table.remove(pendingSummonRepairs, i)
                    end
                end
            else
                table.remove(pendingSummonRepairs, i)
            end
        end
    end
end

function Adapter.installSummonRepairObserver()
    DelamainRepairExemption.install()
    if summonObserverInstalled then return true end

    local installed = false
    if type(ObserveAfter) == 'function' then
        local ok = pcall(function()
            ObserveAfter('VehicleComponent', 'OnSummonStartedEvent', function(self, _)
                local ran, err = pcall(function() Adapter.queueSummonedVehicleRepair(self) end)
                if not ran then print('[Vanguard Coverage] insured summon repair observer error: ' .. tostring(err)) end
            end)
        end)
        installed = installed or ok
    end

    if not installed and type(Observe) == 'function' then
        local ok = pcall(function()
            Observe('VehicleComponent', 'OnSummonStartedEvent', function(self, _)
                local ran, err = pcall(function() Adapter.queueSummonedVehicleRepair(self) end)
                if not ran then print('[Vanguard Coverage] insured summon repair observer error: ' .. tostring(err)) end
            end)
        end)
        installed = installed or ok
    end

    summonObserverInstalled = installed == true
    if summonObserverInstalled then
        print('[Vanguard Coverage] installed insured VehicleComponent.OnSummonStartedEvent repair observer')
    else
        print('[Vanguard Coverage] failed to install insured summon repair observer')
    end

    return summonObserverInstalled
end

function Adapter.hasCachedVehicleEntity(vehicleId)
    if not cached.entity then return false end
    if Coverage.isVehicleIneligible and Coverage.isVehicleIneligible({ id = cached.recordId ~= '' and cached.recordId or cached.id, name = cached.name }) then return false end

    local requested = safeString(vehicleId)
    if requested == '' or requested == 'nil' then return true end

    if cached.id and vehicleIdsEquivalent(cached.id, requested) then return true end

    if cached.recordId and cached.recordId ~= '' then
        local matched = matchVehicleByRecord(cached.recordId)
        if matched and vehicleIdsEquivalent(matched.id, requested) then return true end
    end

    return false
end

                                        
function Adapter.isPlayerInVehicle()
    return Adapter.isPlayerMounted()
end

function Adapter.resolveMountedCoverageVehicle()
    local vehicle, mounted, identity = resolveMountedPlayerVehicle()
    if not vehicle then return nil, mounted end

    if Coverage.isInsured(vehicle.id) == true or (identity and identity.nativeInsured == true) then
        return vehicle, mounted
    end

    return nil, mounted
end

function Adapter.resolveCurrentCoverageVehicle()
    Adapter.syncGarageToCoverage()

    local mountedVehicle, mountedEntity = resolveMountedPlayerVehicle()
    if mountedVehicle then return mountedVehicle, mountedEntity end

    if cached.id and cached.id ~= '' then
        local cachedVehicle = Coverage.getVehicle(cached.id)
        if cachedVehicle and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(cachedVehicle)) then return cachedVehicle, cached.entity end
    end

    if cached.recordId and cached.recordId ~= '' then
        local matched = matchVehicleByRecord(cached.recordId)
        if matched then return matched, cached.entity end
    end

    local s = Coverage.getState()
    if s.ui and s.ui.lastSelectedVehicleId and s.ui.lastSelectedVehicleId ~= '' then
        local selected = Coverage.getVehicle(s.ui.lastSelectedVehicleId)
        if selected and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(selected)) then return selected, nil end
    end

    local vehicles = Coverage.getVehiclesSorted()
    for _, vehicle in ipairs(vehicles) do
        if not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle)) and Coverage.isInsured(vehicle.id) then return vehicle, nil end
    end

    for _, vehicle in ipairs(vehicles) do
        if not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle)) then return vehicle, nil end
    end
    return nil, nil
end

function Adapter.resolveRepairClaimVehicle(vehicleId)
    Adapter.syncGarageToCoverage()

    local requested = safeString(vehicleId)
    if requested ~= '' and requested ~= 'nil' then
        local vehicle = Coverage.getVehicle(requested)
        if vehicle and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(vehicle)) then return vehicle end
    end

    if cached.id and cached.id ~= '' then
        local cachedVehicle = Coverage.getVehicle(cached.id)
        if cachedVehicle and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(cachedVehicle)) then return cachedVehicle end
    end

    if cached.recordId and cached.recordId ~= '' then
        local matched = matchVehicleByRecord(cached.recordId)
        if matched then return matched end
    end

    local s = Coverage.getState()
    if s.ui and s.ui.lastSelectedVehicleId and s.ui.lastSelectedVehicleId ~= '' then
        local selected = Coverage.getVehicle(s.ui.lastSelectedVehicleId)
        if selected and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(selected)) then return selected end
    end

    return nil
end


function Adapter.resolveHotkeyVehicle()
    Adapter.syncGarageToCoverage()

    local mountedVehicle, mountedEntity, mountedIdentity = resolveMountedPlayerVehicle()
    if mountedEntity then
                                                                             
                                                                               
        return mountedVehicle, mountedEntity, mountedIdentity
    end

    if cached.id and cached.id ~= '' then
        local cachedVehicle = Coverage.getVehicle(cached.id)
        if cachedVehicle and not (Coverage.isVehicleIneligible and Coverage.isVehicleIneligible(cachedVehicle)) then return cachedVehicle, cached.entity end
    end

    if cached.recordId and cached.recordId ~= '' then
        local matched = matchVehicleByRecord(cached.recordId)
        if matched then return matched, cached.entity end
    end

    return nil, nil, nil
end

function Adapter.getRepairCandidate()
    local vehicle = Adapter.resolveRepairClaimVehicle()
    if not vehicle then return nil end

    local totalLossLocked = Adapter.isNativeTotalLossLocked(vehicle.id) == true
    local uninsuredDestroyed = Adapter.isNativeUninsuredVehicleDestroyed(vehicle.id) == true
    return {
        id = vehicle.id,
        name = vehicle.name,
        insured = Coverage.isInsured(vehicle.id),
        deductible = Coverage.recalculate().deductibleAmount,
        mustExitVehicle = false,
        damaged = (not totalLossLocked) and (not uninsuredDestroyed) and (Coverage.hasVehicleDamage and Coverage.hasVehicleDamage(vehicle.id) or false),
        totalLossLocked = totalLossLocked,
        uninsuredDestroyed = uninsuredDestroyed,
    }
end

function Adapter.markRepairCandidateDamaged(reason)
    local vehicle, entity = Adapter.resolveCurrentCoverageVehicle()
    if not vehicle then vehicle = Adapter.resolveRepairClaimVehicle() end
    if not vehicle then return false, 'Vehicle damage detected, but no Vanguard garage vehicle matched.' end

    if objectIsDestroyedOnly(entity) then
        if Coverage.isInsured(vehicle.id) == true then
            Adapter.createNativeTotalLossClaim(vehicle.id)
            return false, 'Insured vehicle has been destroyed and was routed to total loss.'
        end
        Adapter.markNativeUninsuredVehicleDestroyed(vehicle.id)
        return false, 'Uninsured vehicle is DESTROYED and must be scrapped from Garage.'
    end

    if Adapter.isNativeUninsuredVehicleDestroyed(vehicle.id) then
        return false, 'Uninsured vehicle is DESTROYED and must be scrapped from Garage.'
    end

    if Adapter.isNativeTotalLossLocked(vehicle.id) then
        return false, 'Vehicle has a total loss claim and is not eligible for repair handling.'
    end

    return Coverage.markVehicleDamage(vehicle.id, reason or 'vehicle damage detected')
end

local function makeGarageVehicleId(recordId)
    local ok, garageId = pcall(function() return NewObject('vehicleGarageVehicleID') end)
    if not ok or not garageId then return nil end
    local assigned = pcall(function() garageId.recordID = TweakDBID.new(recordId) end)
    if not assigned then return nil end
    return garageId
end

function Adapter.despawnTotalLossVehicle(vehicleId)
    local requested = safeString(vehicleId)
    local recordId = requested
    local cachedMatchesRequested = false

    if cached.recordId and cached.recordId ~= '' and cached.recordId ~= 'nil' then
        if requested ~= '' and requested ~= 'nil' and (vehicleIdsEquivalent(cached.id, requested) or vehicleIdsEquivalent(cached.recordId, requested)) then
            cachedMatchesRequested = true
            recordId = cached.recordId
        end
    end

    if recordId == '' or recordId == 'nil' then
        return false, 'Total loss despawn skipped: vehicle record ID is missing.'
    end

    local system = vehicleSystem()
    if not system then
        return false, 'Total loss despawn skipped: vehicle system is unavailable.'
    end

    local garageId = makeGarageVehicleId(recordId)
    if not garageId then
        return false, 'Total loss despawn skipped: could not prepare vehicle garage ID.'
    end

    pcall(function() system:ToggleSummonMode() end)
    local despawnOk = pcall(function() system:DespawnPlayerVehicle(garageId) end)
    pcall(function() system:ToggleSummonMode() end)
    if not despawnOk then
        return false, 'Total loss despawn skipped: exact vehicle despawn call failed.'
    end

    if cachedMatchesRequested then
        pcall(function()
            if cached.entity and cached.entity.Dispose then cached.entity:Dispose() end
        end)
        cached.entity = nil
        cached.position = nil
        cached.rotation = nil
    end
    clearNativeCaches()
    print('[Vanguard Coverage] total loss vehicle despawn requested for ' .. tostring(recordId))
    return true, 'Total loss vehicle despawn requested.'
end

local function replacementEntityMatches(entity, job)
    if not entity or not job then return false end
    local key = objectKey(entity)
    if job.oldEntityKey and job.oldEntityKey ~= '' and key == job.oldEntityKey then return false end

    local foundId = currentVehicleRecordId(entity)
    if vehicleIdsEquivalent(foundId, job.recordId) then return true end

    local matched = nil
    pcall(function() matched = resolveSummonedCoverageVehicle(entity) end)
    return matched ~= nil and vehicleIdsEquivalent(matched.id, job.vehicleId)
end

local function findSummonedVehicleEntity(job)
    if job and replacementEntityMatches(job.observedEntity, job) then
        return job.observedEntity
    end

    local entity = nil
    pcall(function()
        local defs = Game.GetAllBlackboardDefs()
        local summonDef = defs.VehicleSummonData
        local bb = Game.GetBlackboardSystem():Get(summonDef)
        local entityId = bb:GetEntityID(summonDef.SummonedVehicleEntityID)
        entity = Game.FindEntityByID(entityId)
    end)

    if replacementEntityMatches(entity, job) then return entity end
    return nil
end

local function spawnTypeForRecord(recordId)
    local vehicleType = ''
    pcall(function() vehicleType = safeString(TweakDB:GetFlat(safeString(recordId) .. '.type')) end)
    local lowered = vehicleType:lower()
    if lowered:find('bike', 1, true) or lowered:find('motorcycle', 1, true) then return 'Bike' end
    return 'Car'
end

local function spawnOnlyOnValidRoadForRecord(recordId)
    local system = vehicleSystem()
    if not system then return true end

    local list = nil
    pcall(function() list = system:GetPlayerUnlockedVehicles() end)
    if list then
        pcall(function()
            for _, row in ipairs(list) do
                local rowId = row and row.recordID and tdbidToString(row.recordID) or ''
                if vehicleIdsEquivalent(rowId, recordId) and row.spawnOnlyOnValidRoad ~= nil then
                    list = row.spawnOnlyOnValidRoad == true
                    return
                end
            end
        end)
        if type(list) == 'boolean' then return list end
    end

                                                                                
                                                                          
    return true
end

local function repairSpawnEligibility(job)
    if not job or not job.vehicleId then return nil end
    local dealership = Adapter.findDealershipSystem()
    if not dealership then return nil end

    local ok, blocked = pcall(function()
        local totaled = dealership.IsVanguardCoverageTotalLossLockedByKey
            and dealership:IsVanguardCoverageTotalLossLockedByKey(job.vehicleId) == true
        local destroyed = dealership.IsVanguardUninsuredVehicleDestroyedByKey
            and dealership:IsVanguardUninsuredVehicleDestroyedByKey(job.vehicleId) == true
        return totaled or destroyed
    end)
    if not ok then return nil end
    return blocked ~= true
end

function Adapter.queueFreshBodyReplacement(entity, vehicleId, vehicleName)
    if repairJob then return false, 'another native body refresh is active' end
    if not entity then return false, 'summoned vehicle entity is unavailable' end

    local mounted = false
    pcall(function()
        if entity.IsPlayerMounted then mounted = entity:IsPlayerMounted() == true end
    end)
    if mounted then return false, 'V is already mounted' end

    Adapter.syncGarageToCoverage(true)
    local vehicle = Coverage.getVehicle(vehicleId)
    if not vehicle then return false, 'policy vehicle disappeared' end
    if Coverage.isInsured(vehicle.id) ~= true then return false, 'vehicle is not currently insured' end
    if Adapter.isNativeTotalLossLocked(vehicle.id) then return false, 'total loss lock is active' end

    local matched = resolveSummonedCoverageVehicle(entity)
    if not matched or not vehicleIdsEquivalent(matched.id, vehicle.id) then
        return false, 'summoned entity no longer matches the policy vehicle'
    end

                                                                            
                                                                                
                                             
    local liveRecordId = currentVehicleRecordId(entity)
    local recordId = ''
    if isCurrentGarageVehicleId(liveRecordId) then
        recordId = liveRecordId
    elseif isCurrentGarageVehicleId(vehicle.id) then
        recordId = safeString(vehicle.id)
    else
        return false, 'no exact current-save Garage record is available'
    end

    local position, rotation = worldSnapshot(entity)

    local system = vehicleSystem()
    if not system then return false, 'vehicle system is unavailable' end
    local garageId = makeGarageVehicleId(recordId)
    if not garageId then return false, 'vehicle garage ID could not be prepared' end

    local oldEntityKey = objectKey(entity)
    repairJob = {
        recordId = recordId,
        vehicleId = vehicle.id,
        vehicleName = vehicleName or vehicle.name,
        garageId = garageId,
        position = position,
        rotation = rotation,
        oldEntityKey = oldEntityKey,
        observedEntity = nil,
        spawnType = spawnTypeForRecord(recordId),
        spawnOnlyOnValidRoad = spawnOnlyOnValidRoadForRecord(recordId),
        timer = 0.0,
        phase = 'waiting_for_clear',
    }

                                                                               
                                                                                 
                                                     
    pcall(function() system:ToggleSummonMode() end)
    pcall(function() system:DespawnPlayerVehicle(garageId) end)
    pcall(function() system:ToggleSummonMode() end)
    pcall(function()
        if entity.Dispose then entity:Dispose() end
    end)

    cached.entity = nil
    cached.position = position
    cached.rotation = rotation
    print('[Vanguard Coverage] retired damaged body for exact Garage record ' .. tostring(recordId))
    return true, 'silent fresh-body replacement queued'
end

function Adapter.queueFullVehicleRespawnRepair(vehicleId)
    local vehicle = Adapter.resolveRepairClaimVehicle(vehicleId)
    if not vehicle then return false, 'No matching Vanguard repair vehicle resolved.' end
    return Adapter.queueFreshBodyReplacement(cached.entity, vehicle.id, vehicle.name)
end

function Adapter.repairCurrentVehicle(vehicle)
    if type(VanguardCoverageExternalFullRepair) == 'function' then
        local ok, result, msg = pcall(VanguardCoverageExternalFullRepair, vehicle)
        if ok and result == true then return true, msg or 'External full repair hook completed.' end
        return false, msg or 'External full repair hook failed.'
    end

    if type(vehicle) == 'table' and vehicle.id then
        return Adapter.repairCachedVehicleEntity(vehicle.id)
    end

    return Adapter.repairCachedVehicleEntity(nil)
end

local function spawnReplacement(job)
    local system = vehicleSystem()
    if not system then return false end
    if repairSpawnEligibility(job) == false then return false end

    local spawned = false
    pcall(function()
        if job.garageId then system:DespawnPlayerVehicle(job.garageId) end
    end)

                                                                            
                                                                            
                                                                             
    pcall(function()
        local player = playerObject()
        local manager = player and player.GetQuickSlotsManager and player:GetQuickSlotsManager() or nil
        if manager and manager.SummonVehicle then
            manager:SummonVehicle(
                true,
                job.spawnType or 'Car',
                TweakDBID.new(job.recordId),
                job.spawnOnlyOnValidRoad ~= false
            )
            spawned = true
        end
    end)

    if spawned then return true end

    if repairSpawnEligibility(job) ~= true then return false end

                                                                             
                                                                             
    pcall(function()
        local result = system:SpawnPlayerVehicle(
            job.spawnType or 'Car',
            TweakDBID.new(job.recordId),
            job.spawnOnlyOnValidRoad ~= false
        )
        spawned = result ~= false
    end)
    return spawned
end

local function settleReplacement(job)
    local entity = findSummonedVehicleEntity(job)
    if entity then
        forceRepairEntity(entity)

                                                                               
                                                                             
        local settledPosition, settledRotation = worldSnapshot(entity)

        cached.recordId = job.recordId
        cached.id = job.vehicleId
        cached.name = job.vehicleName
        cached.entity = entity
        cached.position = settledPosition
        cached.rotation = settledRotation
        pcall(function()
            if Coverage.clearFreshBodyPending then Coverage.clearFreshBodyPending(job.vehicleId) end
            if Coverage.saveNow then Coverage.saveNow() end
        end)
        print('[Vanguard Coverage] verified clean native drive-up replacement for ' .. tostring(job.vehicleName or job.vehicleId))
        return true
    end

    return false
end

function Adapter.hasActiveWork()
    return repairJob ~= nil or #pendingSummonRepairs > 0
end

function Adapter.needsUpdate()
    return ENABLE_PASSIVE_VEHICLE_CHECKER == true or Adapter.hasActiveWork() == true
end

function Adapter.update(delta)
    delta = tonumber(delta) or 0

    if ENABLE_PASSIVE_VEHICLE_CHECKER then
        passivePollTimer = passivePollTimer + delta
        if passivePollTimer >= PASSIVE_POLL_INTERVAL then
            passivePollTimer = 0.0
            Adapter.cacheMountedVehicle()

                                                                                    
                                                                                  
                                                                               
            pcall(function()
                local mounted = getMountedVehicleObject()
                local watchedEntity = mounted or cached.entity
                if watchedEntity and cached.id and cached.id ~= '' then
                    local watchedIneligible = Coverage.isVehicleIneligible and (Coverage.isVehicleIneligible(cached.id) or Coverage.isVehicleIneligible({ id = currentVehicleRecordId(watchedEntity), name = currentVehicleDisplayName(watchedEntity) }))
                    if watchedIneligible then
                        return
                    elseif objectIsDestroyedOnly(watchedEntity) then
                        if Coverage.isInsured(cached.id) == true then
                            Adapter.createNativeTotalLossClaim(cached.id)
                        else
                            Adapter.markNativeUninsuredVehicleDestroyed(cached.id)
                        end
                    elseif mounted and Adapter.isNativeTotalLossLocked(cached.id) ~= true and Adapter.isNativeUninsuredVehicleDestroyed(cached.id) ~= true and objectLooksDamaged(mounted) then
                        Coverage.markVehicleDamage(cached.id, 'live vehicle damage detected')
                    end
                end
            end)
        end
    end

    updateSummonRepairJobs(delta)

    if not repairJob then return end
    repairJob.timer = (tonumber(repairJob.timer) or 0) + delta

    if repairJob.phase == 'waiting_for_clear' then
        if repairJob.timer >= 0.92 then
            if spawnReplacement(repairJob) then
                repairJob.phase = 'waiting_for_spawn'
                repairJob.timer = 0.0
            else
                                                                         
                                                                                  
                print('[Vanguard Coverage] native fresh-body spawn call failed; marker retained for a later summon')
                repairJob = nil
            end
        end
        return
    end

    if repairJob.phase == 'waiting_for_spawn' then
        if settleReplacement(repairJob) then
            repairJob = nil
            return
        end

        if repairJob.timer >= 8.0 then
            print('[Vanguard Coverage] fresh-body entity could not be verified; marker retained for a later summon')
            repairJob = nil
        end
    end
end

function Adapter.registerVehicle(vehicle)
    return Coverage.upsertVehicle(vehicle)
end

function Adapter.onVehiclePurchased(vehicle)
    local v = Coverage.upsertVehicle(vehicle)
    if v.financed then
        Coverage.setVehicleFinanced(v.id, true)
    end
    return v
end

function Adapter.onVehiclePaidOff(vehicleId)
    return Coverage.setVehiclePaidOff(vehicleId)
end

return Adapter
