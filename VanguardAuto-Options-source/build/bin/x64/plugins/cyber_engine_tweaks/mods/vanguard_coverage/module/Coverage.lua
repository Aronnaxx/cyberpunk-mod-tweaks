local Serializer = require('module/Serializer')
local Wallet = require('module/Wallet')
local Calendar = require('module/Calendar')
local Opt = require('module/VanguardOptions')

local Coverage = {}

                                                                               
                                                                             
                                                                           
local function getMarmurBridge()
    if type(GetMod) ~= 'function' then return nil end
    local ok, api = pcall(GetMod, 'marmurbank')
    if ok and type(api) == 'table' then return api end
    return nil
end

local function recordMarmurInsuranceSpend(amount, source)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return false end

    local api = getMarmurBridge()
    if not api or type(api.recordKnownAnalyticsSpend) ~= 'function' then
        return false
    end

    local posted, result = pcall(function()
        return api:recordKnownAnalyticsSpend('insurance', amount, source or 'vanguard_coverage', 'service')
    end)
    return posted == true and result == true
end

local MOD_DIR = '.'
local DATA_DIR = 'data'
local STATE_FILE = DATA_DIR .. '/coverage_state.lua'

Coverage.POLICY_NAME = 'Vanguard Comprehensive Policy'
Coverage.TERM_DAYS = 182
Coverage.TERM_DAYS_12 = 365
Coverage.MONTH_DAYS = 30
Coverage.DEFAULT_BILLING_MODE = 'monthly'
Coverage.PAY_IN_FULL_DISCOUNT = 0.0
Coverage.MECHANIC_REFERENCE_COST = 2500
Coverage.AT_FAULT_SURCHARGE_CAP = 0.25
Coverage.AT_FAULT_SURCHARGE_BY_SEVERITY = { [1] = 0.025, [2] = 0.05, [3] = 0.075 }
Coverage.GOOD_DRIVER_REWARD_RATE = 0.22
Coverage.GOOD_DRIVER_REWARD_VERSION = 2200
Coverage.GOOD_DRIVER_FULLPAY_REFUNDS = { [1] = Coverage.GOOD_DRIVER_REWARD_RATE }
Coverage.MULTI_VEHICLE_DISCOUNT_PER_EXTRA = 0.018
Coverage.MULTI_VEHICLE_DISCOUNT_CAP = 0.25
Coverage.GOOD_DRIVER_REVIEW_INTERVAL_DAYS = 7
Coverage.GOOD_DRIVER_WINDOW_DAYS = 7
Coverage.GOOD_DRIVER_REVIEWS = {
    { days = 7, level = 1, rate = Coverage.GOOD_DRIVER_REWARD_RATE, label = 'Good Driver Appreciation', maxAtFaultAccidents = 0, description = '7 days with no at-fault accidents. A 22% Good Driver reward applies to the current policy.' },
}

Coverage.DEDUCTIBLES = {
    [1] = {
        key = 'low_250',
        name = 'Low Deductible',
        short = 'LOW',
        amount = 250,
        termRate = 0.15,
        minTermPremium = 750,
        description = 'Highest term premium, lowest claim cost. Best value for large garages or frequent repair needs.',
    },
    [2] = {
        key = 'standard_750',
        name = 'Standard Deductible',
        short = 'STANDARD',
        amount = 750,
        termRate = 0.10,
        minTermPremium = 600,
        description = 'Balanced policy cost and repair-claim cost. Still far cheaper than the €$2,500 mechanic repair.',
    },
    [3] = {
        key = 'high_1500',
        name = 'High Deductible',
        short = 'HIGH',
        amount = 1500,
        termRate = 0.05,
        minTermPremium = 500,
        description = 'Lowest premium with the highest Vanguard deductible. It saves cash monthly, but costs more every time a claim is filed.',
    },
}


                                                                                  
                                                                            
Coverage.LENDER_COMPLIANCE_DAYS = 10
Coverage.LENDER_NOTICE_INTERVAL_DAYS = 4
Coverage.LENDER_NOTICE_MAX = 3
Coverage.LENDER_NOTICE_SCHEDULE = { 0, 4, 8 }
Coverage.FINANCED_MAX_DEDUCTIBLE_OPTION = 3
Coverage.FINANCED_MAX_DEDUCTIBLE_AMOUNT = Coverage.DEDUCTIBLES[Coverage.FINANCED_MAX_DEDUCTIBLE_OPTION].amount

                                                         
                                                                                  
                                                                             
                                                                       
                                                           
Coverage.MIGRATION_AUTO_ENROLL_FINANCED = true
Coverage.MIGRATION_AUTO_ENROLL_DEDUCTIBLE_OPTION = 3
Coverage.MIGRATION_DEFAULT_BILLING_MODE = Coverage.DEFAULT_BILLING_MODE



Coverage.POLICY_COVERAGES = {
    {
        key = 'bodily_injury_liability',
        section = 'For Others',
        name = 'Bodily Injury Liability',
        optionLabel = 'Included',
        weight = 0.14,
        description = 'Pays other-party injury costs when the policyholder is considered at fault.',
    },
    {
        key = 'property_damage_liability',
        section = 'For Others',
        name = 'Property Damage Liability',
        optionLabel = 'Included',
        weight = 0.16,
        description = 'Pays other-party vehicle or property damage when the policyholder causes the loss.',
    },
    {
        key = 'personal_injury_protection',
        section = 'For You',
        name = 'Personal Injury Protection',
        optionLabel = 'Included',
        weight = 0.08,
        description = 'Policy-side protection bundled into the Vanguard vehicle policy.',
    },
    {
        key = 'uninsured_motorist_protection',
        section = 'For You',
        name = 'Uninsured Motorist Protection',
        optionLabel = 'Included',
        weight = 0.04,
        description = 'Applies when damage is caused by an uninsured or unidentified driver.',
    },
    {
        key = 'accident_forgiveness',
        section = 'For You',
        name = 'Accident Forgiveness',
        optionLabel = 'Not Included',
        weight = 0.00,
        description = 'Not carried on the current Vanguard policy model.',
    },
}

Coverage.VEHICLE_COVERAGES = {
    {
        key = 'comprehensive_excluding_collision',
        name = 'Comprehensive Damage Protection',
        optionLabel = 'Deductible',
        weight = 0.28,
        usesDeductible = true,
        description = 'Pays for non-collision damage such as theft, vandalism, fire, or explosion.',
    },
    {
        key = 'collision_repair',
        name = 'Collision Repair Coverage',
        optionLabel = 'Deductible',
        weight = 0.26,
        usesDeductible = true,
        description = 'Pays for repair damage after crashes, impacts, and road chaos.',
    },
    {
        key = 'emergency_road_service',
        name = 'Emergency Road Service',
        optionLabel = 'Included',
        weight = 0.04,
        usesDeductible = false,
        description = 'Supports towing-style service hooks and vehicle recovery flavor.',
    },
    {
        key = 'rental_reimbursement',
        name = 'Rental Reimbursement',
        optionLabel = 'Not Carried',
        weight = 0.00,
        usesDeductible = false,
        description = 'Not carried on the current Vanguard policy model.',
    },
}

Coverage.BILLING = {
    pay_in_full = {
        key = 'pay_in_full',
        name = 'Paid In Full',
        short = 'FULL',
        installmentCount = 1,
        intervalDays = 0,
        termDays = Coverage.TERM_DAYS,
        termMonths = 6,
        description = 'Pay the full 182-day policy term up front. No recurring bill.',
    },
    pay_in_full_12 = {
        key = 'pay_in_full_12',
        name = 'Paid In Full',
        short = 'FULL',
        installmentCount = 1,
        intervalDays = 0,
        termDays = Coverage.TERM_DAYS_12,
        termMonths = 12,
        description = 'Pay the full 365-day policy term up front. No recurring bill.',
    },
    weekly = {
        key = 'weekly',
        name = 'Weekly Payments',
        short = 'WEEKLY',
        installmentCount = 26,
        intervalDays = 7,
        termDays = Coverage.TERM_DAYS,
        termMonths = 6,
        description = 'Split the 182-day term into 26 weekly payments. First payment is due at confirmation.',
    },
    biweekly = {
        key = 'biweekly',
        name = 'Biweekly Payments',
        short = 'BIWEEKLY',
        installmentCount = 13,
        intervalDays = 14,
        termDays = Coverage.TERM_DAYS,
        termMonths = 6,
        description = 'Split the 182-day term into 13 biweekly payments. First payment is due at confirmation.',
    },
    monthly = {
        key = 'monthly',
        name = 'Monthly Payments',
        short = 'MONTHLY',
        installmentCount = 6,
        intervalDays = 0,
        termDays = Coverage.TERM_DAYS,
        termMonths = 6,
        description = 'Split the 182-day term into 6 monthly payments. First payment is due at confirmation.',
    },
    weekly_12 = {
        key = 'weekly_12',
        name = 'Weekly Payments',
        short = 'WEEKLY',
        installmentCount = 52,
        intervalDays = 7,
        termDays = Coverage.TERM_DAYS_12,
        termMonths = 12,
        description = 'Split the 365-day term into 52 weekly payments. First payment is due at confirmation.',
    },
    biweekly_12 = {
        key = 'biweekly_12',
        name = 'Biweekly Payments',
        short = 'BIWEEKLY',
        installmentCount = 26,
        intervalDays = 14,
        termDays = Coverage.TERM_DAYS_12,
        termMonths = 12,
        description = 'Split the 365-day term into 26 biweekly payments. First payment is due at confirmation.',
    },
    monthly_12 = {
        key = 'monthly_12',
        name = 'Monthly Payments',
        short = 'MONTHLY',
        installmentCount = 12,
        intervalDays = 0,
        termDays = Coverage.TERM_DAYS_12,
        termMonths = 12,
        description = 'Split the 365-day term into 12 monthly payments. First payment is due at confirmation.',
    },
}

Coverage.BILLING_ALIASES = {
    full_12 = 'pay_in_full_12',
    pay_in_full_12 = 'pay_in_full_12',
    twelve_month_full = 'pay_in_full_12',
    twelve_month_pay_in_full = 'pay_in_full_12',
    twelve_month = 'monthly_12',
    twelve_month_plan = 'monthly_12',
    twelve_month_payments = 'monthly_12',
    twelve_months = 'monthly_12',
    twelve_month_monthly = 'monthly_12',
    twelve_month_biweekly = 'biweekly_12',
    twelve_month_weekly = 'weekly_12',
    six_month = 'monthly',
    six_month_plan = 'monthly',
    monthly_installments = 'monthly',
    twelve_month_weekly = 'weekly_12',
    twelve_month_biweekly = 'biweekly_12',
    twelve_month_monthly = 'monthly_12',
    weekly_12_month = 'weekly_12',
    biweekly_12_month = 'biweekly_12',
    monthly_12_month = 'monthly_12',
    month = 'monthly',
    bi_weekly = 'biweekly',
    every_two_weeks = 'biweekly',
}

                                                                                                  
Coverage.TIERS = Coverage.DEDUCTIBLES

local state = nil
local saveRequested = false
local collisionSaveRequested = false
local collisionSaveRequestedAt = 0.0
                                                                            
                                                                           
local COLLISION_SAVE_QUIET_SECONDS = 12.0

local function roundMoney(value)
    return math.max(0, math.floor((tonumber(value) or 0) + 0.5))
end

local function roundSignedMoney(value)
    local n = tonumber(value) or 0
    if n >= 0 then return math.floor(n + 0.5) end
    return -math.floor(math.abs(n) + 0.5)
end

local function ceilMoney(value)
    return math.max(0, math.ceil((tonumber(value) or 0) - 0.00001))
end

local function sanitize(value)
    return tostring(value or ''):gsub('[\r\n]+', ' '):gsub('|', '/'):gsub('%s+', ' ')
end

local function normalizeVehicleIdForMatch(value)
    local s = sanitize(value):lower()
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

local function vehicleIdsEquivalentForMatch(a, b)
    local aRaw = sanitize(a)
    local bRaw = sanitize(b)
    if aRaw ~= '' and bRaw ~= '' and aRaw:lower() == bRaw:lower() then return true end

    local an = normalizeVehicleIdForMatch(aRaw)
    local bn = normalizeVehicleIdForMatch(bRaw)
    if an ~= '' and bn ~= '' and an == bn then return true end

    return false
end

local function vehicleLooksIneligible(vehicle)
    local combined = ''
    if type(vehicle) == 'table' then
        combined = table.concat({
            sanitize(vehicle.id or ''),
            sanitize(vehicle.vehicleKey or ''),
            sanitize(vehicle.key or ''),
            sanitize(vehicle.recordId or ''),
            sanitize(vehicle.tweakId or ''),
            sanitize(vehicle.vehicleID or ''),
            sanitize(vehicle.name or ''),
            sanitize(vehicle.title or ''),
            sanitize(vehicle.label or ''),
            sanitize(vehicle.displayName or ''),
        }, ' ')
    else
        combined = sanitize(vehicle)
    end

    combined = combined:lower()
    return combined:find('delamain', 1, true) ~= nil
end

local function clearIneligibleVehicleState(s, id)
    if not s or id == '' or id == 'nil' then return false end
    local changed = false

    s.policy = s.policy or {}
    s.policy.selected = s.policy.selected or {}
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    s.marmur = s.marmur or {}
    s.marmur.violations = s.marmur.violations or {}
    s.marmur.defaulted = s.marmur.defaulted or {}
    s.marmur.repossessionRequested = s.marmur.repossessionRequested or {}

    if s.policy.selected[id] ~= nil then s.policy.selected[id] = nil; changed = true end
    if s.damage.vehicles[id] ~= nil then s.damage.vehicles[id] = nil; changed = true end
    if s.marmur.violations[id] ~= nil then s.marmur.violations[id] = nil; changed = true end
    if s.marmur.defaulted[id] ~= nil then s.marmur.defaulted[id] = nil; changed = true end
    if s.marmur.repossessionRequested[id] ~= nil then s.marmur.repossessionRequested[id] = nil; changed = true end

    return changed
end

local function scrubIneligibleVehicles(s)
    local changed = false
    for id, vehicle in pairs((s and s.vehicles) or {}) do
        local ineligible = vehicleLooksIneligible(vehicle) or vehicleLooksIneligible(id)
        local normalizedIneligible = ineligible == true
        if vehicle.ineligible ~= normalizedIneligible then changed = true end
        vehicle.ineligible = normalizedIneligible
        if ineligible and clearIneligibleVehicleState(s, id) then changed = true end
    end

    for id, selected in pairs((s and s.policy and s.policy.selected) or {}) do
        if selected == true and vehicleLooksIneligible(id) then
            s.policy.selected[id] = nil
            changed = true
        end
    end

    return changed
end

local function resolveVehicleKey(s, vehicleId)
    local id = sanitize(vehicleId or '')
    if id == '' or id == 'nil' then return id end
    if s and s.vehicles and s.vehicles[id] then return id end
    for key, _ in pairs((s and s.vehicles) or {}) do
        if vehicleIdsEquivalentForMatch(key, id) then return key end
    end
    return id
end

local function resolvePolicyKey(s, vehicleId)
    local id = resolveVehicleKey(s, vehicleId)
    if id == '' or id == 'nil' then return id end
    if s and s.policy and s.policy.selected and s.policy.selected[id] == true then return id end
    for key, selected in pairs((s and s.policy and s.policy.selected) or {}) do
        if selected == true and vehicleIdsEquivalentForMatch(key, id) then return key end
    end
    return id
end

local function normalizeVehicleNameForPolicyMatch(value)
    return sanitize(value or ''):lower():gsub('[^a-z0-9]+', '')
end

local function nowStamp()
    return Calendar.formatCurrent()
end

local function normalizeSavedCalendarStamps(value, visited)
    if type(value) ~= 'table' then return false end
    visited = visited or {}
    if visited[value] then return false end
    visited[value] = true

    local changed = false
    for key, child in pairs(value) do
        if type(child) == 'table' then
            if normalizeSavedCalendarStamps(child, visited) then changed = true end
        elseif type(child) == 'string' then
            local normalized = Calendar.normalizeStamp(child)
            local keyText = string.lower(tostring(key or ''))
            if normalized ~= child
                and (string.find(keyText, 'stamp', 1, true)
                    or string.find(keyText, 'createdat', 1, true)
                    or string.find(keyText, 'lastseen', 1, true)) then
                value[key] = normalized
                changed = true
            end
        end
    end
    return changed
end

local function mkdir(path)
    path = tostring(path or '')
    if path == '' or path == '.' then return end
    pcall(function() os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '" >nul 2>nul') end)
end


local function defaultStats()
    return {
        firstReviewDay = 0,
        repairClaimsLifetime = 0,
        accidentsLifetime = 0,
        atFaultAccidentsLifetime = 0,
        lastClaimDay = 0,
        lastIncidentDay = 0,
        events = {},
        goodDriver = {
            active = false,
            level = 0,
            rate = 0,
            label = 'Not Eligible Yet',
            message = 'Drive with low claim activity to unlock a premium discount.',
            daysObserved = 0,
            incidentScore = 0,
            incidentRate = 0,
            nextReviewDay = 0,
            atFaultAccidents = 0,
            repairClaims = 0,
            accidents = 0,
            rewardVersion = 0,
        },
        accidentSurcharge = {
            rate = 0,
            atFaultCount = 0,
            lastAppliedDay = 0,
            lastAmount = 0,
        },
        goodDriverFullPayRefundedLevel = 0,
        goodDriverFullPayRefundedVersion = 0,
    }
end

local function defaultMigration()
    return {
        financedAutoEnrollChecked = false,
        financedAutoEnrolled = false,
        financedAutoEnrollDay = 0,
        financedAutoEnrollVehicleCount = 0,
        financedAutoEnrollBillingMode = '',
        financedAutoEnrollBillingSource = '',
        financedAutoEnrollMessage = '',
        autoManaged = false,
        userAdjustedPolicy = false,
    }
end

local function defaultState()
    return {
        version = 11,
        policy = {
            active = false,
            policyName = Coverage.POLICY_NAME,
            deductibleOption = 3,
            billingMode = Coverage.DEFAULT_BILLING_MODE,
            selected = {},
            lastPremium = 0,
            lastTermPremium = 0,
            lastMonthlyPremium = 0,
            lastWeeklyPremium = 0,
            lastBiweeklyPremium = 0,
            lastInstallmentAmount = 0,
            lastPayInFullPremium = 0,
            lastDeductible = 1500,
            termMonths = 6,
            termDays = Coverage.TERM_DAYS,
            policyNumber = '',
            lastTotalValue = 0,
            lastPaidDay = 0,
            nextDueDay = 0,
            termStartDay = 0,
            termEndDay = 0,
            installmentsPaid = 0,
            installmentsRemaining = 0,
            paymentDue = 0,
            paymentFrequency = Coverage.DEFAULT_BILLING_MODE,
            paymentIntervalDays = 0,
            totalInstallments = 6,
            lapsed = false,
            pastDue = false,
        },
        vehicles = {},
        damage = {
            vehicles = {},
        },
        history = {},
        marmur = {
            notices = {},
            violations = {},
            defaulted = {},
            repossessionRequested = {},
            lastAuditDay = -1,
        },
        migration = defaultMigration(),
        stats = defaultStats(),
        ui = {
            lastSelectedVehicleId = '',
        },
    }
end

local function requestSave()
    saveRequested = true
end

local function coverageClockNow()
    local now = 0.0
                                                                                  
                                                                            
    pcall(function() now = tonumber(os.time()) or 0.0 end)
    return now
end

local function requestCollisionSave()
    collisionSaveRequested = true
    collisionSaveRequestedAt = coverageClockNow()
end

local function getCurrentDay()
    local ok, gameTime = pcall(function()
        return Game.GetTimeSystem():GetGameTime()
    end)
    if ok and gameTime then
        local okDay, day = pcall(function() return gameTime:Days() end)
        if okDay and tonumber(day) then return tonumber(day) end
    end
    return math.floor(os.time() / 86400)
end

local function addHistory(kind, message, amount, vehicleId)
    local s = state or defaultState()
    table.insert(s.history, 1, {
        stamp = nowStamp(),
        kind = sanitize(kind or 'EVENT'),
        message = sanitize(message or ''),
        amount = roundMoney(amount or 0),
        vehicleId = sanitize(vehicleId or ''),
    })
    while #s.history > 100 do table.remove(s.history) end
    requestSave()
end

local function addNotice(vehicleId, level, message)
    local s = state or defaultState()
    table.insert(s.marmur.notices, 1, {
        stamp = nowStamp(),
        vehicleId = sanitize(vehicleId or ''),
        level = tonumber(level) or 1,
        message = sanitize(message or ''),
    })
    while #s.marmur.notices > 60 do table.remove(s.marmur.notices) end
    requestSave()
end

local function postGoodDriverRewardPhone(mode, amount, percent, cleanDays, termMonths)
    pcall(function()
        local bridge = rawget(_G or {}, 'VanguardAutoPostGoodDriverRewardPhone')
        if bridge then
            bridge(tonumber(mode) or 0, roundMoney(amount or 0), tonumber(percent) or 22, tonumber(cleanDays) or 7, tonumber(termMonths) or 6)
        end
    end)
end


local function lenderRequirementDeductibleAmount()
    local option = Coverage.DEDUCTIBLES[Coverage.FINANCED_MAX_DEDUCTIBLE_OPTION]
    return option and option.amount or 1500
end

local function normalizeViolationRecord(raw, day)
    day = tonumber(day) or getCurrentDay()
    if type(raw) == 'table' then
        raw.startDay = tonumber(raw.startDay) or day
        raw.deadlineDay = tonumber(raw.deadlineDay) or (raw.startDay + Coverage.LENDER_COMPLIANCE_DAYS)
        raw.noticeCount = tonumber(raw.noticeCount) or 0
        raw.lastNoticeDay = tonumber(raw.lastNoticeDay) or -9999
        raw.defaultDay = tonumber(raw.defaultDay) or 0
        raw.lastCause = sanitize(raw.lastCause or '')
        return raw
    end

    local count = tonumber(raw) or 0
    return {
        startDay = day,
        deadlineDay = day + Coverage.LENDER_COMPLIANCE_DAYS,
        noticeCount = math.max(0, count),
        lastNoticeDay = count > 0 and day or -9999,
        defaultDay = 0,
        lastCause = '',
    }
end

local function postMarmurReminder(vehicle, record, cause, noticeNumber)
    local day = getCurrentDay()
    local daysRemaining = math.max(0, (tonumber(record.deadlineDay) or day) - day)
    noticeNumber = tonumber(noticeNumber) or tonumber(record.noticeCount) or 1
    local bridge = getMarmurBridge()
    if not bridge or type(bridge.PostVanguardCoverageReminder) ~= 'function' then return false end
    local ok, result = pcall(function()
        return bridge:PostVanguardCoverageReminder({
            vehicleId = vehicle.id,
            vehicleName = vehicle.name,
            contractIndex = tonumber(vehicle.contractIndex or vehicle.financeIndex or vehicle.index) or 0,
            daysRemaining = daysRemaining,
            noticeNumber = noticeNumber,
            requiredDeductible = lenderRequirementDeductibleAmount(),
            cause = cause,
        })
    end)
    return ok == true and result == true
end

local function postMarmurDefault(vehicle, record, cause)
    local bridge = getMarmurBridge()
    if not bridge or type(bridge.PostVanguardCoverageDefault) ~= 'function' then return false end
    local ok, result = pcall(function()
        return bridge:PostVanguardCoverageDefault({
            vehicleId = vehicle.id,
            vehicleName = vehicle.name,
            contractIndex = tonumber(vehicle.contractIndex or vehicle.financeIndex or vehicle.index) or 0,
            requiredDeductible = lenderRequirementDeductibleAmount(),
            cureDays = Coverage.LENDER_COMPLIANCE_DAYS,
            cause = cause,
        })
    end)
    return ok == true and result == true
end

local function deductibleMeetsFinancedRequirement(optionIndex)
    optionIndex = tonumber(optionIndex) or 0
    return Coverage.DEDUCTIBLES[optionIndex] ~= nil and optionIndex <= Coverage.FINANCED_MAX_DEDUCTIBLE_OPTION
end

local function financedViolationCause(s, vehicle, day)
    if vehicle.financed ~= true then return false, '' end
    local financeBalance = tonumber(vehicle.financeBalance)
    if financeBalance ~= nil and financeBalance <= 0 then return false, '' end

    local id = sanitize(vehicle.id)
    local selected = s.policy.selected[id] == true
    local invalidDeductible = not deductibleMeetsFinancedRequirement(s.policy.deductibleOption)
    local termEndDay = tonumber(s.policy.termEndDay) or 0
    local termMissing = termEndDay <= 0
    local termExpired = termEndDay > 0 and day > termEndDay
    local installmentPastDue = s.policy.billingMode ~= 'pay_in_full' and (tonumber(s.policy.nextDueDay) or 0) > 0 and day > (tonumber(s.policy.nextDueDay) or 0)
    local policyLapsed = s.policy.active ~= true or s.policy.lapsed == true or termMissing or termExpired or installmentPastDue

    if not selected then
        return true, 'financed vehicle is not insured under the Vanguard Comprehensive Policy'
    end
    if invalidDeductible then
        return true, 'deductible exceeds Marmur Bank lender requirements'
    end
    if policyLapsed then
        return true, 'insurance policy is past due or lapsed'
    end

    return false, ''
end

local function deductibleOptionData(option)
    local index = tonumber(option) or 3
    if index < 1 then index = 1 end
    if index > 3 then index = 3 end
    return Coverage.DEDUCTIBLES[index], index
end

local function financeFrequencyToBillingMode(value)
    if value == nil then return '' end

    if type(value) == 'number' then
        local n = math.floor(tonumber(value) or 0)
        if n == 1 then return 'weekly' end
        if n == 2 then return 'biweekly' end
        if n == 3 then return 'monthly' end
    end

    local key = tostring(value or ''):lower():gsub('%s+', ''):gsub('%-', ''):gsub('_', '')
    if key == '' or key == 'nil' then return '' end
    if key == '1' or key == 'weekly' or key == 'week' or key == 'every7days' or key == '7' then return 'weekly' end
    if key == '2' or key == 'biweekly' or key == 'biweek' or key == 'everytwoweeks' or key == 'every2weeks' or key == 'twoweeks' or key == '14' then return 'biweekly' end
    if key == '3' or key == 'monthly' or key == 'month' or key == 'every30days' or key == '30' then return 'monthly' end
    if key == 'payinfull' or key == 'full' then return 'pay_in_full' end
    return ''
end

local function billingData(mode)
    local numericMode = type(mode) == 'number' and financeFrequencyToBillingMode(mode) or ''
    mode = numericMode ~= '' and numericMode or tostring(mode or Coverage.DEFAULT_BILLING_MODE)
    local normalizedFinanceMode = financeFrequencyToBillingMode(mode)
    if normalizedFinanceMode ~= '' then mode = normalizedFinanceMode end
    mode = Coverage.BILLING_ALIASES[mode] or mode
    if Coverage.BILLING[mode] then return Coverage.BILLING[mode], mode end
    return Coverage.BILLING[Coverage.DEFAULT_BILLING_MODE], Coverage.DEFAULT_BILLING_MODE
end

local function termDaysForBillingKey(billingKey)
    local billing = Coverage.BILLING[billingKey or ''] or Coverage.BILLING[Coverage.DEFAULT_BILLING_MODE]
    return tonumber(billing.termDays) or Coverage.TERM_DAYS
end

local function termMonthsForBillingKey(billingKey)
    local billing = Coverage.BILLING[billingKey or ''] or Coverage.BILLING[Coverage.DEFAULT_BILLING_MODE]
    return tonumber(billing.termMonths) or 6
end

local function policyNumber()
    local s = state or defaultState()
    s.policy = s.policy or defaultState().policy
    if not s.policy.policyNumber or s.policy.policyNumber == '' then
        s.policy.policyNumber = 'VCP-' .. tostring(getCurrentDay()) .. '-' .. tostring(math.random(1000, 9999))
        requestSave()
    end
    return s.policy.policyNumber
end

local function getMarmurBillingModeForVehicle(vehicle)
    local mode = ''
    local source = ''
    pcall(function()
        local bridge = getMarmurBridge()
        if not bridge then return end

        local payload = {
            vehicleId = vehicle and vehicle.id or '',
            vehicleName = vehicle and vehicle.name or '',
            contractIndex = vehicle and (vehicle.financeIndex or vehicle.contractIndex or vehicle.index) or 0,
            financeIndex = vehicle and (vehicle.financeIndex or vehicle.contractIndex or vehicle.index) or 0,
        }

        local result = nil
        if bridge.GetVanguardAutoLoanBillingMode then
            result = bridge:GetVanguardAutoLoanBillingMode(payload)
        elseif bridge.GetVanguardLoanBillingMode then
            result = bridge:GetVanguardLoanBillingMode(payload)
        end

        if type(result) == 'table' then
            result = result.billingMode or result.mode or result.frequency or result.paymentFrequency
        end

        local normalized = financeFrequencyToBillingMode(result)
        if normalized ~= '' then
            mode = normalized
            source = 'marmur'
        end
    end)
    return mode, source
end

local function financeBillingModeForVehicle(vehicle)
    vehicle = vehicle or {}
    local directCandidateKeys = {
        'financeBillingMode',
        'billingMode',
        'insuranceBillingMode',
        'paymentFrequency',
        'financePaymentFrequency',
        'loanPaymentFrequency',
        'paymentFrequencyCode',
        'financePaymentFrequencyCode',
    }

    for _, key in ipairs(directCandidateKeys) do
        local mode = financeFrequencyToBillingMode(vehicle[key])
        if mode ~= '' and mode ~= 'pay_in_full' then
            return mode, 'vehicle'
        end
    end

    local marmurMode, marmurSource = getMarmurBillingModeForVehicle(vehicle)
    if marmurMode ~= '' and marmurMode ~= 'pay_in_full' then
        return marmurMode, marmurSource
    end

    return '', ''
end

local function chooseFinancedBillingMode(financedVehicles)
    local counts = {}
    local firstMode = ''
    local firstSource = ''

    for _, vehicle in ipairs(financedVehicles or {}) do
        local mode, source = financeBillingModeForVehicle(vehicle)
        if mode ~= '' and mode ~= 'pay_in_full' then
            counts[mode] = (counts[mode] or 0) + 1
            if firstMode == '' then
                firstMode = mode
                firstSource = source ~= '' and source or 'vehicle'
            end
        end
    end

    local bestMode = firstMode
    local bestCount = bestMode ~= '' and (counts[bestMode] or 0) or 0
    for mode, count in pairs(counts) do
        if count > bestCount then
            bestMode = mode
            bestCount = count
        end
    end

    if bestMode ~= '' then return bestMode, firstSource ~= '' and firstSource or 'vehicle' end
    return Coverage.MIGRATION_DEFAULT_BILLING_MODE, 'default'
end

local function installmentAmountFor(termPremium, billingKey)
    local billing = billingData(billingKey)
    local count = tonumber(billing.installmentCount) or 6
    if billing.key == 'pay_in_full' then
        return roundMoney(termPremium * (1.0 - Coverage.PAY_IN_FULL_DISCOUNT))
    end
    return count > 0 and ceilMoney(termPremium / count) or 0
end

local function nextInstallmentDueDay(startDay, billingKey, installmentsPaid)
    local billing, key = billingData(billingKey)
    if key == 'pay_in_full' then return 0 end

    local count = tonumber(billing.installmentCount) or 6
    local paid = tonumber(installmentsPaid) or 0
    if paid <= 0 then paid = 1 end
    if paid >= count then return 0 end

    local interval = tonumber(billing.intervalDays) or 0
    if interval > 0 then
        return (tonumber(startDay) or getCurrentDay()) + (interval * paid)
    end

                                                                                                
    return (tonumber(startDay) or getCurrentDay()) + math.ceil((termDaysForBillingKey(key) / count) * paid)
end

local function elapsedInstallmentsFor(startDay, billingKey, day)
    local billing, key = billingData(billingKey)
    if key == 'pay_in_full' then return 1 end

    local count = tonumber(billing.installmentCount) or 6
    local elapsed = math.max(0, (tonumber(day) or getCurrentDay()) - (tonumber(startDay) or getCurrentDay()))
    local paid = 1
    local interval = tonumber(billing.intervalDays) or 0
    if interval > 0 then
        paid = math.floor(elapsed / interval) + 1
    else
        paid = math.floor((elapsed / termDaysForBillingKey(key)) * count) + 1
    end
    if paid < 1 then paid = 1 end
    if paid > count then paid = count end
    return paid
end

local ensureState
local selectedCount

local function migratePolicy(s)
    s.version = tonumber(s.version) or 1
    s.policy = s.policy or defaultState().policy
    s.policy.selected = s.policy.selected or {}

                                                                                                    
                                                              
    if not s.policy.deductibleOption then
        local oldTier = tonumber(s.policy.tier) or 1
        local map = { [1] = 3, [2] = 2, [3] = 1 }
        s.policy.deductibleOption = map[oldTier] or 3
    end

    if not s.policy.billingMode then
        if tostring(s.policy.billing or '') == 'pay_in_full' then
            s.policy.billingMode = 'pay_in_full'
        else
            s.policy.billingMode = Coverage.DEFAULT_BILLING_MODE
        end
    end

    local _, optionIndex = deductibleOptionData(s.policy.deductibleOption)
    local _, billingMode = billingData(s.policy.billingMode)
    s.policy.deductibleOption = optionIndex
    s.policy.billingMode = billingMode
    s.policy.policyName = Coverage.POLICY_NAME
    s.policy.termMonths = tonumber(s.policy.termMonths) or termMonthsForBillingKey(billingMode)
    s.policy.termDays = tonumber(s.policy.termDays) or termDaysForBillingKey(billingMode)
    s.policy.policyNumber = tostring(s.policy.policyNumber or '')
    s.policy.lastPremium = roundMoney(s.policy.lastPremium or 0)
    s.policy.lastTermPremium = roundMoney(s.policy.lastTermPremium or s.policy.lastPremium or 0)
    s.policy.lastMonthlyPremium = roundMoney(s.policy.lastMonthlyPremium or 0)
    s.policy.lastWeeklyPremium = roundMoney(s.policy.lastWeeklyPremium or 0)
    s.policy.lastBiweeklyPremium = roundMoney(s.policy.lastBiweeklyPremium or 0)
    s.policy.lastInstallmentAmount = roundMoney(s.policy.lastInstallmentAmount or 0)
    s.policy.lastPayInFullPremium = roundMoney(s.policy.lastPayInFullPremium or 0)
    s.policy.lastDeductible = roundMoney(s.policy.lastDeductible or Coverage.DEDUCTIBLES[optionIndex].amount)
    s.policy.lastTotalValue = roundMoney(s.policy.lastTotalValue or 0)
    s.policy.lastPaidDay = tonumber(s.policy.lastPaidDay) or 0
    s.policy.nextDueDay = tonumber(s.policy.nextDueDay) or 0
    s.policy.termStartDay = tonumber(s.policy.termStartDay) or 0
    s.policy.termEndDay = tonumber(s.policy.termEndDay) or 0
    s.policy.installmentsPaid = tonumber(s.policy.installmentsPaid) or 0
    s.policy.installmentsRemaining = tonumber(s.policy.installmentsRemaining) or 0
    s.policy.paymentDue = roundMoney(s.policy.paymentDue or 0)
    s.policy.paymentFrequency = tostring(s.policy.paymentFrequency or billingMode)
    s.policy.paymentIntervalDays = tonumber(s.policy.paymentIntervalDays) or ((Coverage.BILLING[billingMode] and Coverage.BILLING[billingMode].intervalDays) or 0)
    s.policy.totalInstallments = tonumber(s.policy.totalInstallments) or ((Coverage.BILLING[billingMode] and Coverage.BILLING[billingMode].installmentCount) or 6)
    s.policy.lapsed = s.policy.lapsed == true
    s.policy.pastDue = s.policy.pastDue == true
    return s
end


local function ensureStats(s)
    s.stats = s.stats or defaultStats()
    local defaults = defaultStats()
    for key, value in pairs(defaults) do
        if s.stats[key] == nil then s.stats[key] = value end
    end
    s.stats.events = s.stats.events or {}
    s.stats.goodDriver = s.stats.goodDriver or defaults.goodDriver
    for key, value in pairs(defaults.goodDriver) do
        if s.stats.goodDriver[key] == nil then s.stats.goodDriver[key] = value end
    end
    s.stats.accidentSurcharge = s.stats.accidentSurcharge or defaults.accidentSurcharge
    for key, value in pairs(defaults.accidentSurcharge) do
        if s.stats.accidentSurcharge[key] == nil then s.stats.accidentSurcharge[key] = value end
    end
    s.stats.goodDriverFullPayRefundedLevel = tonumber(s.stats.goodDriverFullPayRefundedLevel) or 0
    s.stats.goodDriverFullPayRefundedVersion = tonumber(s.stats.goodDriverFullPayRefundedVersion) or 0
    return s.stats
end


local function accidentSurchargeRate(stats)
    stats = stats or defaultStats()
    stats.accidentSurcharge = stats.accidentSurcharge or defaultStats().accidentSurcharge
    local rate = tonumber(stats.accidentSurcharge.rate) or 0
    if rate < 0 then rate = 0 end
    if rate > Coverage.AT_FAULT_SURCHARGE_CAP then rate = Coverage.AT_FAULT_SURCHARGE_CAP end
    return rate
end

local function addAtFaultSurcharge(s, severity, amount)
    s = s or ensureState()
    local stats = ensureStats(s)
    local level = tonumber(severity) or 1
    if level < 1 then level = 1 end
    if level > 3 then level = 3 end
    local increase = Coverage.AT_FAULT_SURCHARGE_BY_SEVERITY[level] or Coverage.AT_FAULT_SURCHARGE_BY_SEVERITY[1] or 0.025
    stats.accidentSurcharge = stats.accidentSurcharge or defaultStats().accidentSurcharge
    local previous = accidentSurchargeRate(stats)
    local updated = previous + increase
    if updated > Coverage.AT_FAULT_SURCHARGE_CAP then updated = Coverage.AT_FAULT_SURCHARGE_CAP end
    stats.accidentSurcharge.rate = updated
    stats.accidentSurcharge.atFaultCount = (tonumber(stats.accidentSurcharge.atFaultCount) or 0) + 1
    stats.accidentSurcharge.lastAppliedDay = getCurrentDay()
    stats.accidentSurcharge.lastAmount = roundMoney(amount or 0)
    requestSave()
    return updated - previous, updated
end

local function goodDriverFullPayRefundRate(level)
    local refundRate = Coverage.GOOD_DRIVER_FULLPAY_REFUNDS[tonumber(level) or 0] or 0
    if refundRate < 0 then refundRate = 0 end
    if refundRate > Coverage.GOOD_DRIVER_REWARD_RATE then refundRate = Coverage.GOOD_DRIVER_REWARD_RATE end
    return refundRate
end

local function pruneIncidentEvents(stats)
    stats = stats or defaultStats()
    stats.events = stats.events or {}
    local day = getCurrentDay()
    local keepAfter = day - math.max(Coverage.GOOD_DRIVER_WINDOW_DAYS, 180)
    local kept = {}
    for _, event in ipairs(stats.events or {}) do
        local eventDay = tonumber(event.day) or day
        if eventDay >= keepAfter then table.insert(kept, event) end
    end
    stats.events = kept
end

local function incidentStats(stats, insuredCount)
    stats = stats or defaultStats()
    pruneIncidentEvents(stats)
    local day = getCurrentDay()
    local first = tonumber(stats.firstReviewDay) or 0
    if first <= 0 then first = day end
    local cutoff = math.max(day - Coverage.GOOD_DRIVER_WINDOW_DAYS, first)
    local score = 0
    local repairs = 0
    local accidents = 0
    local atFault = 0
    for _, event in ipairs(stats.events or {}) do
        local eventDay = tonumber(event.day) or day
        if eventDay >= cutoff then
            score = score + (tonumber(event.score) or 0)
            if event.kind == 'repair_claim' then repairs = repairs + 1 end
            if event.kind == 'accident' then accidents = accidents + 1 end
            if event.atFault == true then atFault = atFault + 1 end
        end
    end
    local count = math.max(1, tonumber(insuredCount) or 1)
    return {
        day = day,
        daysObserved = math.max(0, day - first),
        incidentScore = score,
        incidentRate = score / count,
        repairClaims = repairs,
        accidents = accidents,
        atFaultAccidents = atFault,
    }
end

local function updateGoodDriverStatus(insuredCount)
    local s = ensureState()
    local stats = ensureStats(s)
    if (tonumber(stats.firstReviewDay) or 0) <= 0 then
        stats.firstReviewDay = getCurrentDay()
    end

    local recent = incidentStats(stats, insuredCount)
    local best = nil
    for _, review in ipairs(Coverage.GOOD_DRIVER_REVIEWS or {}) do
        local minDays = tonumber(review.days) or 0
        local maxAtFault = tonumber(review.maxAtFaultAccidents)
        if maxAtFault == nil then maxAtFault = 0 end
        if recent.daysObserved >= minDays and recent.atFaultAccidents <= maxAtFault then
            if not best or (tonumber(review.level) or 0) > (tonumber(best.level) or 0) then
                best = review
            end
        end
    end

    local previousLevel = tonumber(stats.goodDriver.level) or 0
    if best then
        stats.goodDriver.active = true
        stats.goodDriver.level = tonumber(best.level) or 1
        stats.goodDriver.rate = tonumber(best.rate) or 0
        stats.goodDriver.label = tostring(best.label or 'Good Driver')
        stats.goodDriver.message = tostring(best.description or 'Good driver discount applied.')
    else
        stats.goodDriver.active = false
        stats.goodDriver.level = 0
        stats.goodDriver.rate = 0
        stats.goodDriver.label = 'Not Eligible Yet'
        stats.goodDriver.message = 'Avoid at-fault accidents for 7 days to unlock the 22% Good Driver reward.'
    end

    stats.goodDriver.daysObserved = recent.daysObserved
    stats.goodDriver.incidentScore = recent.incidentScore
    stats.goodDriver.incidentRate = recent.incidentRate
    stats.goodDriver.repairClaims = recent.repairClaims
    stats.goodDriver.accidents = recent.accidents
    stats.goodDriver.atFaultAccidents = recent.atFaultAccidents

    local nextDay = 0
    for _, review in ipairs(Coverage.GOOD_DRIVER_REVIEWS or {}) do
        if recent.daysObserved < (tonumber(review.days) or 0) then
            nextDay = (tonumber(stats.firstReviewDay) or recent.day) + (tonumber(review.days) or 0)
            break
        end
    end
    stats.goodDriver.nextReviewDay = nextDay

    local currentLevel = tonumber(stats.goodDriver.level) or 0
    local rewardVersion = tonumber(Coverage.GOOD_DRIVER_REWARD_VERSION) or 2200
    local rewardVersionChanged = currentLevel > 0 and (tonumber(stats.goodDriver.rewardVersion) or 0) ~= rewardVersion
    if previousLevel ~= currentLevel or rewardVersionChanged then
        if currentLevel > 0 then
            local percent = math.floor((stats.goodDriver.rate or 0) * 100 + 0.5)
            addHistory('GOOD_DRIVER', stats.goodDriver.label .. ' reward applied: ' .. tostring(percent) .. '% off qualifying premium after 7 days with no at-fault accidents.', 0, '')
            stats.goodDriver.rewardVersion = rewardVersion

            local billingMode = tostring((s.policy and s.policy.billingMode) or '')
            if s.policy and s.policy.active == true and (billingMode == 'pay_in_full' or billingMode == 'pay_in_full_12') then
                local alreadyRefunded = currentLevel <= (tonumber(stats.goodDriverFullPayRefundedLevel) or 0) and (tonumber(stats.goodDriverFullPayRefundedVersion) or 0) == rewardVersion
                if not alreadyRefunded then
                    local base = roundMoney(s.policy.lastPayInFullPremium or s.policy.lastTermPremium or 0)
                    local refund = roundMoney(base * goodDriverFullPayRefundRate(currentLevel))
                    if refund > 0 and Wallet.add(refund) then
                        stats.goodDriverFullPayRefundedLevel = currentLevel
                        stats.goodDriverFullPayRefundedVersion = rewardVersion
                        addHistory('GOOD_DRIVER_REFUND', stats.goodDriver.label .. ' paid-in-full reward credit issued: ' .. Coverage.formatMoney(refund) .. '.', refund, '')
                        postGoodDriverRewardPhone(1, refund, percent, recent.daysObserved, tonumber(s.policy.termMonths) or 6)
                    end
                end
            elseif s.policy and s.policy.active == true then
                postGoodDriverRewardPhone(2, 0, percent, recent.daysObserved, tonumber(s.policy.termMonths) or 6)
            end
        elseif previousLevel > 0 then
            addHistory('GOOD_DRIVER', 'Good Driver discount removed due to at-fault accident activity or review requirements.', 0, '')
            stats.goodDriver.rewardVersion = 0
        end
    end

    requestSave()
    return stats.goodDriver
end

local function recordIncident(kind, vehicleId, score, atFault, amount)
    local s = ensureState()
    local stats = ensureStats(s)
    local day = getCurrentDay()
    if atFault == true then
        stats.firstReviewDay = day + 1
    elseif (tonumber(stats.firstReviewDay) or 0) <= 0 then
        stats.firstReviewDay = day
    end
    local event = {
        day = day,
        stamp = nowStamp(),
        kind = sanitize(kind or 'incident'),
        vehicleId = sanitize(vehicleId or ''),
        score = tonumber(score) or 1,
        atFault = atFault == true,
        amount = roundMoney(amount or 0),
    }
    table.insert(stats.events, 1, event)
    while #stats.events > 80 do table.remove(stats.events) end
    stats.lastIncidentDay = day
    if kind == 'repair_claim' then
        stats.repairClaimsLifetime = (tonumber(stats.repairClaimsLifetime) or 0) + 1
        stats.lastClaimDay = day
    elseif kind == 'accident' then
        stats.accidentsLifetime = (tonumber(stats.accidentsLifetime) or 0) + 1
        if atFault == true then stats.atFaultAccidentsLifetime = (tonumber(stats.atFaultAccidentsLifetime) or 0) + 1 end
    end
    updateGoodDriverStatus(selectedCount())
    requestSave()
end

function ensureState()
    if state then return state end
    mkdir(MOD_DIR)
    mkdir(DATA_DIR)
    state = Serializer.load(STATE_FILE, defaultState()) or defaultState()
    state = migratePolicy(state)
    state.vehicles = state.vehicles or {}
    state.damage = state.damage or { vehicles = {} }
    state.damage.vehicles = state.damage.vehicles or {}
    state.history = state.history or {}
    state.marmur = state.marmur or defaultState().marmur
    state.marmur.notices = state.marmur.notices or {}
    state.marmur.violations = state.marmur.violations or {}
    state.marmur.defaulted = state.marmur.defaulted or {}
    state.marmur.repossessionRequested = state.marmur.repossessionRequested or {}
    ensureStats(state)
    state.ui = state.ui or { lastSelectedVehicleId = '' }
    state.migration = state.migration or defaultMigration()
    local migrationDefaults = defaultMigration()
    for key, value in pairs(migrationDefaults) do
        if state.migration[key] == nil then state.migration[key] = value end
    end
    if normalizeSavedCalendarStamps(state) then requestSave() end
    if scrubIneligibleVehicles(state) then requestSave() end
    state.version = 12
    return state
end

function selectedCount()
    local s = ensureState()
    local count = 0
    for id, selected in pairs(s.policy.selected or {}) do
        local vehicle = s.vehicles[id]
        if selected == true and not vehicleLooksIneligible(vehicle or id) then count = count + 1 end
    end
    return count
end

local function getVehicleName(vehicle)
    return sanitize(vehicle.name or vehicle.title or vehicle.label or vehicle.displayName or 'Unknown Vehicle')
end

local function getVehicleId(vehicle)
    local raw = vehicle.id or vehicle.vehicleKey or vehicle.key or vehicle.recordId or vehicle.tweakId or vehicle.vehicleID
    if raw == nil or tostring(raw) == '' or tostring(raw) == 'nil' then
        raw = (vehicle.name or vehicle.title or 'vehicle') .. '_' .. tostring(vehicle.index or '')
    end
    return sanitize(raw)
end

local function normalizeVehicle(vehicle)
    vehicle = vehicle or {}
    local id = getVehicleId(vehicle)
    local value = tonumber(vehicle.value or vehicle.price or vehicle.dealerPrice or vehicle.purchasePrice or vehicle.sellValue) or 0
    local financeBalance = nil
    if value <= 0 then value = 40000 end
    if vehicle.financeBalance ~= nil or vehicle.remainingBalance ~= nil or vehicle.balanceDue ~= nil or vehicle.loanBalance ~= nil then
        financeBalance = tonumber(vehicle.financeBalance or vehicle.remainingBalance or vehicle.balanceDue or vehicle.loanBalance) or 0
    end

    return {
        id = id,
        name = getVehicleName(vehicle),
        value = roundMoney(value),
        ineligible = vehicleLooksIneligible(vehicle) or vehicleLooksIneligible(id),
        financed = vehicle.financed == true or vehicle.isFinanced == true or tostring(vehicle.status or ''):upper() == 'FINANCED',
        owned = vehicle.owned ~= false,
        source = sanitize(vehicle.source or 'Vanguard Garage'),
        index = tonumber(vehicle.index or vehicle.garageIndex or 0) or 0,
        contractIndex = tonumber(vehicle.contractIndex or vehicle.financeIndex or vehicle.loanIndex or vehicle.index or 0) or 0,
        financeIndex = tonumber(vehicle.contractIndex or vehicle.financeIndex or vehicle.loanIndex or vehicle.index or 0) or 0,
        financeBalance = financeBalance,
        paymentFrequency = vehicle.paymentFrequency or vehicle.financePaymentFrequency or vehicle.loanPaymentFrequency or vehicle.paymentFrequencyCode or vehicle.financePaymentFrequencyCode,
        financePaymentFrequency = vehicle.financePaymentFrequency or vehicle.paymentFrequency or vehicle.loanPaymentFrequency or vehicle.paymentFrequencyCode or vehicle.financePaymentFrequencyCode,
        financeBillingMode = financeFrequencyToBillingMode(vehicle.financeBillingMode or vehicle.billingMode or vehicle.insuranceBillingMode or vehicle.paymentFrequency or vehicle.financePaymentFrequency or vehicle.loanPaymentFrequency or vehicle.paymentFrequencyCode or vehicle.financePaymentFrequencyCode),
        lastSeen = nowStamp(),
    }
end

local function forceInsured(vehicleId, reason)
                                                                                                                   
    if reason then
        addHistory('LENDER_NOTE', sanitize(reason), 0, sanitize(vehicleId or ''))
    else
        requestSave()
    end
end

function Coverage.init()
    ensureState()
    Coverage.recalculate()
    Coverage.saveNow()
end

function Coverage.getState()
    return ensureState()
end

function Coverage.isVehicleIneligible(vehicleOrId)
    if type(vehicleOrId) == 'table' then
        return vehicleLooksIneligible(vehicleOrId)
    end

    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleOrId or '')
    local vehicle = s.vehicles[id]
    return vehicleLooksIneligible(vehicle or id)
end

function Coverage.getDeductibles()
    return Coverage.DEDUCTIBLES
end

function Coverage.getDeductibleOption(option)
    local data = deductibleOptionData(option)
    return data
end

function Coverage.getBillingOptions()
    return Coverage.BILLING
end

function Coverage.roundMoney(value)
    return roundMoney(value)
end

function Coverage.formatMoney(value)
    local n = tostring(roundMoney(value))
    local formatted = n:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '€$' .. formatted
end


function Coverage.formatSignedMoney(value)
    local n = tonumber(value) or 0
    if n > 0 then return '+' .. Coverage.formatMoney(n) end
    if n < 0 then return '-' .. Coverage.formatMoney(math.abs(n)) end
    return Coverage.formatMoney(0)
end

function Coverage.getCurrentDay()
    return getCurrentDay()
end

function Coverage.getTermStatus()
    local s = ensureState()
    local day = getCurrentDay()
    local startDay = tonumber(s.policy.termStartDay) or 0
    local endDay = tonumber(s.policy.termEndDay) or 0
    local activeTerm = s.policy.active == true and startDay > 0 and endDay > day and s.policy.lapsed ~= true
    local daysRemaining = activeTerm and math.max(0, endDay - day) or 0
    local daysElapsed = activeTerm and math.max(0, day - startDay) or 0

    return {
        currentDay = day,
        termStartDay = startDay,
        termEndDay = endDay,
        termDays = tonumber(s.policy.termDays) or Coverage.TERM_DAYS,
        termMonths = tonumber(s.policy.termMonths) or 6,
        activeTerm = activeTerm,
        daysRemaining = daysRemaining,
        daysElapsed = daysElapsed,
        percentRemaining = (tonumber(s.policy.termDays) or Coverage.TERM_DAYS) > 0 and (daysRemaining / (tonumber(s.policy.termDays) or Coverage.TERM_DAYS)) or 0,
    }
end

function Coverage.getCoverageDaysRemaining()
    return Coverage.getTermStatus().daysRemaining
end

                                                     
function Coverage.getDaysRemaining()
    return Coverage.getCoverageDaysRemaining()
end

function Coverage.getTermInfo()
    return Coverage.getTermStatus()
end

function Coverage.getPolicyNumber()
    local s = ensureState()
    return s.policy.policyNumber or ''
end

local function policyHasActiveTerm()
    return Coverage.getTermStatus().activeTerm == true
end

local function buildBreakdown(termPremium, totalValue, count, vehicleRows, option)
    local policyRows = {}
    local vehicleBreakdown = {}
    local weightedRows = {}

    for _, row in ipairs(Coverage.POLICY_COVERAGES or {}) do
        local item = {
            key = row.key,
            section = row.section or 'Policy',
            name = row.name,
            optionLabel = row.optionLabel or 'Included',
            description = row.description or '',
            amount = 0,
        }
        table.insert(policyRows, item)
        if (tonumber(row.weight) or 0) > 0 then
            table.insert(weightedRows, { ref = item, weight = tonumber(row.weight) or 0 })
        end
    end

    local denom = totalValue > 0 and totalValue or math.max(1, count)
    for _, vehicle in ipairs(vehicleRows or {}) do
        local share = totalValue > 0 and ((tonumber(vehicle.value) or 0) / denom) or (1.0 / math.max(1, count))
        local vehicleItem = {
            id = vehicle.id,
            name = vehicle.name,
            value = tonumber(vehicle.value) or 0,
            financed = vehicle.financed == true,
            vehicleTotal = 0,
            rows = {},
        }

        for _, row in ipairs(Coverage.VEHICLE_COVERAGES or {}) do
            local optionLabel = row.optionLabel or 'Included'
            if row.usesDeductible == true then
                optionLabel = Coverage.formatMoney(option.amount) .. ' Ded.'
            end

            local item = {
                key = row.key,
                name = row.name,
                optionLabel = optionLabel,
                description = row.description or '',
                amount = 0,
                deductibleAmount = row.usesDeductible == true and option.amount or 0,
            }
            table.insert(vehicleItem.rows, item)
            if (tonumber(row.weight) or 0) > 0 then
                table.insert(weightedRows, { ref = item, vehicleRef = vehicleItem, weight = (tonumber(row.weight) or 0) * share })
            end
        end

        table.insert(vehicleBreakdown, vehicleItem)
    end

    local assigned = 0
    for i, item in ipairs(weightedRows) do
        local amount = 0
        if i == #weightedRows then
            amount = math.max(0, roundMoney(termPremium - assigned))
        else
            amount = roundMoney(termPremium * (tonumber(item.weight) or 0))
        end
        item.ref.amount = amount
        assigned = assigned + amount
    end

    local policyTotal = 0
    for _, row in ipairs(policyRows) do
        policyTotal = policyTotal + roundMoney(row.amount or 0)
    end

    local vehicleTotal = 0
    local vehiclePremiums = {}
    for _, vehicle in ipairs(vehicleBreakdown) do
        local vt = 0
        for _, row in ipairs(vehicle.rows or {}) do
            vt = vt + roundMoney(row.amount or 0)
        end
        vehicle.vehicleTotal = vt
        vehiclePremiums[vehicle.id] = vt
        vehicleTotal = vehicleTotal + vt
    end

    return {
        policyRows = policyRows,
        vehicleRows = vehicleBreakdown,
        policyCoverageTotal = policyTotal,
        vehicleCoverageTotal = vehicleTotal,
        lineItemTotal = policyTotal + vehicleTotal,
        vehiclePremiums = vehiclePremiums,
    }
end

function Coverage.getPolicyName()
    return Coverage.POLICY_NAME
end

function Coverage.upsertVehicle(vehicle, deferRecalculate)
    local s = ensureState()
    local normalized = normalizeVehicle(vehicle)
    local existing = s.vehicles[normalized.id] or {}

    normalized.insuranceLocked = false
    normalized.createdAt = existing.createdAt or nowStamp()
    normalized.ineligible = normalized.ineligible == true
    if existing and existing.id then
        normalized.financeIndex = tonumber(normalized.financeIndex or existing.financeIndex or existing.contractIndex or 0) or 0
        normalized.contractIndex = tonumber(normalized.contractIndex or existing.contractIndex or existing.financeIndex or 0) or 0
    end
    s.vehicles[normalized.id] = normalized

    if normalized.ineligible then
        clearIneligibleVehicleState(s, normalized.id)
    end

    if normalized.financed == true and normalized.ineligible ~= true and existing.financed ~= true then
        addHistory('LENDER_MONITOR', normalized.name .. ' is financed. The policyholder may leave it uninsured, but Marmur Bank will audit compliance and allow 10 days to cure.', 0, normalized.id)
    else
        requestSave()
    end

    if deferRecalculate ~= true then
        Coverage.recalculate()
    end
    return normalized
end

local function snapshotContainsVehicle(seen, vehicleId)
    for seenId, present in pairs(seen or {}) do
        if present == true and vehicleIdsEquivalentForMatch(seenId, vehicleId) then return true end
    end
    return false
end

local function removeVehicleRowsFromList(rows, vehicleId)
    local kept = {}
    local removed = 0
    for _, row in ipairs(rows or {}) do
        local rowVehicleId = type(row) == 'table' and sanitize(row.vehicleId or row.vehicleID or '') or ''
        if rowVehicleId ~= '' and vehicleIdsEquivalentForMatch(rowVehicleId, vehicleId) then
            removed = removed + 1
        else
            kept[#kept + 1] = row
        end
    end
    return kept, removed
end

local function removeVehicleKeyedRows(rows, vehicleId)
    local removed = 0
    for key, _ in pairs(rows or {}) do
        if vehicleIdsEquivalentForMatch(key, vehicleId) then
            rows[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

local function purgeVehicleState(s, vehicleId)
    local id = sanitize(vehicleId or '')
    if id == '' or id == 'nil' then return false end

    local changed = false
    s.policy = s.policy or {}
    s.policy.selected = s.policy.selected or {}
    s.vehicles = s.vehicles or {}
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    s.marmur = s.marmur or {}
    s.marmur.notices = s.marmur.notices or {}
    s.marmur.violations = s.marmur.violations or {}
    s.marmur.defaulted = s.marmur.defaulted or {}
    s.marmur.repossessionRequested = s.marmur.repossessionRequested or {}
    s.stats = s.stats or defaultStats()
    s.stats.events = s.stats.events or {}
    s.ui = s.ui or { lastSelectedVehicleId = '' }

    if removeVehicleKeyedRows(s.vehicles, id) > 0 then changed = true end
    if removeVehicleKeyedRows(s.policy.selected, id) > 0 then changed = true end
    if removeVehicleKeyedRows(s.damage.vehicles, id) > 0 then changed = true end
    if removeVehicleKeyedRows(s.marmur.violations, id) > 0 then changed = true end
    if removeVehicleKeyedRows(s.marmur.defaulted, id) > 0 then changed = true end
    if removeVehicleKeyedRows(s.marmur.repossessionRequested, id) > 0 then changed = true end

    local removed = 0
    s.history, removed = removeVehicleRowsFromList(s.history, id)
    if removed > 0 then changed = true end
    s.marmur.notices, removed = removeVehicleRowsFromList(s.marmur.notices, id)
    if removed > 0 then changed = true end
    s.stats.events, removed = removeVehicleRowsFromList(s.stats.events, id)
    if removed > 0 then changed = true end

    if vehicleIdsEquivalentForMatch(s.ui.lastSelectedVehicleId or '', id) then
        s.ui.lastSelectedVehicleId = ''
        changed = true
    end

    return changed
end

function Coverage.unregisterVehicle(vehicleId)
    local s = ensureState()
    local changed = purgeVehicleState(s, vehicleId)
    if changed then
        Coverage.recalculate()
        Coverage.auditMarmur(true)
        Coverage.saveNow()
    end
    return changed
end

function Coverage.syncVehicles(vehicles, authoritative, isInstalledRecord)
    local s = ensureState()
    local count = 0
    local removed = 0
    local seen = {}

    for _, vehicle in ipairs(vehicles or {}) do
                                                                               
                                                                             
                                                                             
        local normalized = Coverage.upsertVehicle(vehicle, true)
        if normalized and normalized.id then seen[normalized.id] = true end
        count = count + 1
    end

                                                                                
                                                                                  
                                                                              
    if authoritative == true then
        local stale = {}
        local function queueIfUninstalled(id)
            if snapshotContainsVehicle(seen, id) or type(isInstalledRecord) ~= 'function' then return end
            local ok, installed = pcall(isInstalledRecord, id)
            if ok and installed == false then stale[id] = true end
        end

        for id, _ in pairs(s.vehicles or {}) do
            queueIfUninstalled(id)
        end
        for id, selected in pairs((s.policy and s.policy.selected) or {}) do
            if selected == true then queueIfUninstalled(id) end
        end

        for id, _ in pairs(stale) do
            if purgeVehicleState(s, id) then removed = removed + 1 end
        end
    end

    Coverage.recalculate()
    if count > 0 then
        Coverage.runInstallAutoEnrollment(false, 'garage_sync')
    end
    if removed > 0 then requestSave() end
    return count, removed
end


local function markMigrationChecked(s, message)
    s.migration = s.migration or defaultMigration()
    s.migration.financedAutoEnrollChecked = true
    s.migration.financedAutoEnrollDay = getCurrentDay()
    s.migration.financedAutoEnrollMessage = sanitize(message or '')
    requestSave()
end

local function setPolicyScheduleAfterMigration(s, q, billingKey, day)
    local billing = Coverage.BILLING[billingKey] or Coverage.BILLING[Coverage.DEFAULT_BILLING_MODE]
    s.policy.paymentFrequency = billingKey
    s.policy.paymentIntervalDays = tonumber(billing.intervalDays) or 0
    s.policy.totalInstallments = tonumber(billing.installmentCount) or 6

    if billingKey == 'pay_in_full' then
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.installmentsPaid = 1
        s.policy.installmentsRemaining = 0
        return
    end

                                                                                   
                                                                                 
                                                 
    local count = tonumber(billing.installmentCount) or 6
    s.policy.installmentsPaid = 1
    s.policy.installmentsRemaining = math.max(0, count - 1)
    s.policy.paymentDue = roundMoney(q.installmentAmount or 0)
    s.policy.nextDueDay = nextInstallmentDueDay(day, billingKey, s.policy.installmentsPaid)
end

function Coverage.refreshAutoEnrollmentBilling(force)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.' end
    local s = ensureState()
    s.migration = s.migration or defaultMigration()

    if s.migration.autoManaged ~= true or s.migration.userAdjustedPolicy == true then
        return false, 'Policy is customer-managed; migration billing match skipped.'
    end

    local financed = {}
    for _, vehicle in ipairs(Coverage.getVehiclesSorted()) do
        if vehicle.financed == true and vehicle.ineligible ~= true then table.insert(financed, vehicle) end
    end
    if #financed <= 0 then return false, 'No financed vehicles available for billing match.' end

    local billingKey, source = chooseFinancedBillingMode(financed)
    if billingKey == '' then billingKey = Coverage.DEFAULT_BILLING_MODE end
    if source == 'default' and force ~= true then
        return false, 'Marmur billing mode not available yet; keeping current insurance billing mode.'
    end

    local old = tostring(s.policy.billingMode or '')
    s.migration.financedAutoEnrollBillingSource = source
    s.migration.financedAutoEnrollBillingMode = billingKey

    if old ~= billingKey then
        s.policy.billingMode = billingKey
        local q = Coverage.recalculate()
        local day = tonumber(s.policy.termStartDay) or getCurrentDay()
        setPolicyScheduleAfterMigration(s, q, billingKey, day)
        addHistory('MIGRATION_BILLING_MATCH', 'Insurance billing now matches your financed-vehicle payment schedule: ' .. Coverage.BILLING[billingKey].name .. '.', 0, '')
        Coverage.saveNow()
        return true, 'Migration billing matched: ' .. Coverage.BILLING[billingKey].name .. '.'
    end

    requestSave()
    return false, 'Migration billing already matched: ' .. Coverage.BILLING[billingKey].name .. '.'
end

function Coverage.runInstallAutoEnrollment(force, reason)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.' end
    local s = ensureState()
    s.migration = s.migration or defaultMigration()

    local vehicles = Coverage.getVehiclesSorted()

    if s.migration.financedAutoEnrollChecked == true and force ~= true then
        local retryFinancedFirstScan = false
        if s.migration.financedAutoEnrolled ~= true and s.migration.userAdjustedPolicy ~= true and selectedCount() <= 0 and s.policy.active ~= true then
            for _, vehicle in ipairs(vehicles or {}) do
                if vehicle.financed == true and vehicle.ineligible ~= true then retryFinancedFirstScan = true break end
            end
        end
        if retryFinancedFirstScan ~= true then
            return Coverage.refreshAutoEnrollmentBilling(false)
        end
    end

    if #vehicles <= 0 then
        return false, 'No Vanguard garage vehicles detected yet; migration auto-enrollment waiting for a garage scan.'
    end

    local financed = {}
    for _, vehicle in ipairs(vehicles) do
        if vehicle.financed == true and vehicle.ineligible ~= true then table.insert(financed, vehicle) end
    end

    if #financed <= 0 then
        local msg = 'No financed vehicles detected during first Coverage scan. Insurance remains available as an optional customer-managed policy.'
        markMigrationChecked(s, msg)
        Coverage.saveNow()
        return false, msg
    end

    local hasExistingPolicy = selectedCount() > 0 or s.policy.active == true or (tonumber(s.policy.termStartDay) or 0) > 0 or s.migration.userAdjustedPolicy == true
    if hasExistingPolicy and force ~= true then
        local msg = 'Existing Coverage policy data detected. Migration did not override policy selections.'
        markMigrationChecked(s, msg)
        Coverage.saveNow()
        return false, msg
    end

    local billingKey, billingSource = chooseFinancedBillingMode(financed)
    if billingKey == '' or billingKey == 'pay_in_full' then billingKey = Coverage.DEFAULT_BILLING_MODE end
    local optionIndex = Coverage.MIGRATION_AUTO_ENROLL_DEDUCTIBLE_OPTION
    local option = Coverage.DEDUCTIBLES[optionIndex] or Coverage.DEDUCTIBLES[3]

    s.policy.selected = {}
    for _, vehicle in ipairs(financed) do
        s.policy.selected[vehicle.id] = true
    end

    local day = getCurrentDay()
    local q = Coverage.quote(s.policy.selected, optionIndex, billingKey)
    s.policy.policyName = Coverage.POLICY_NAME
    s.policy.policyNumber = tostring(s.policy.policyNumber or '')
    s.policy.deductibleOption = optionIndex
    s.policy.billingMode = billingKey
    s.policy.active = true
    s.policy.termStartDay = day
    s.policy.termDays = q.termDays
    s.policy.termMonths = q.termMonths
    policyNumber()
    s.policy.termEndDay = day + q.termDays
    s.policy.lastPaidDay = day
    s.policy.lapsed = false
    s.policy.pastDue = false

    q = Coverage.recalculate()
    setPolicyScheduleAfterMigration(s, q, billingKey, day)

    s.migration.financedAutoEnrollChecked = true
    s.migration.financedAutoEnrolled = true
    s.migration.financedAutoEnrollDay = day
    s.migration.financedAutoEnrollVehicleCount = #financed
    s.migration.financedAutoEnrollBillingMode = billingKey
    s.migration.financedAutoEnrollBillingSource = billingSource
    s.migration.autoManaged = true
    s.migration.userAdjustedPolicy = false

    local msg = 'Coverage activated for ' .. tostring(#financed) .. ' financed vehicle(s) under ' .. Coverage.POLICY_NAME .. ', with a ' .. Coverage.formatMoney(option.amount) .. ' deductible and ' .. Coverage.BILLING[billingKey].name .. ' billing.'
    s.migration.financedAutoEnrollMessage = msg
    addHistory('MIGRATION_AUTO_ENROLL', msg, 0, '')
    Coverage.auditMarmur(true)
    Coverage.saveNow()
    return true, msg
end

function Coverage.getMigrationStatus()
    local s = ensureState()
    s.migration = s.migration or defaultMigration()
    return s.migration
end

function Coverage.getVehiclesSorted()
    local s = ensureState()
    local out = {}
    for _, vehicle in pairs(s.vehicles or {}) do table.insert(out, vehicle) end
    table.sort(out, function(a, b)
        if (a.financed and not b.financed) then return true end
        if (b.financed and not a.financed) then return false end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

function Coverage.getVehicle(vehicleId)
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId)
    return s.vehicles[id]
end

                                                                              
                                                                             
                                                                                
                                                                   
function Coverage.resolveInsuredVehicle(vehicleId, displayName)
    local s = ensureState()
    local id = sanitize(vehicleId or '')
    local directKey = resolvePolicyKey(s, id)

    if directKey ~= '' and directKey ~= 'nil' and Coverage.isInsured(directKey) == true then
        local vehicle = s.vehicles[directKey] or { id = directKey, name = directKey, owned = true }
        return vehicle, directKey, 'record_id'
    end

                                                                             
                                                                               
    local ownedRecord = s.vehicles[id]
    if ownedRecord and ownedRecord.owned ~= false then
        return nil, nil, 'owned_record_unselected'
    end

    local wanted = normalizeVehicleNameForPolicyMatch(displayName)
    if wanted == '' or wanted == 'nil' or #wanted < 5 then return nil, nil, 'no_identity_match' end

    local exact = nil
    for key, selected in pairs((s.policy and s.policy.selected) or {}) do
        if selected == true and Coverage.isInsured(key) == true then
            local vehicle = s.vehicles[key]
            local candidate = normalizeVehicleNameForPolicyMatch(vehicle and (vehicle.name or vehicle.title or vehicle.displayName) or '')
            if candidate ~= '' and candidate == wanted then
                exact = { vehicle = vehicle or { id = key, name = displayName, owned = true }, key = key }
                break
            end
        end
    end

    if exact then return exact.vehicle, exact.key, 'exact_name' end
    return nil, nil, 'no_policy_match'
end

function Coverage.setVehicleFinanced(vehicleId, financed, vehicleData)
    local s = ensureState()
    local id = sanitize(vehicleId)
    if vehicleData then
        local normalized = Coverage.upsertVehicle(vehicleData)
        id = normalized.id
    elseif id ~= '' and not s.vehicles[id] then
        s.vehicles[id] = normalizeVehicle({ id = id, name = id, financed = financed == true })
    end

    if id == '' or not s.vehicles[id] then return false, 'Vehicle not found.' end
    if s.vehicles[id].ineligible == true then
        clearIneligibleVehicleState(s, id)
        return false, 'Vehicle is ineligible for Vanguard Coverage.'
    end

    s.vehicles[id].financed = financed == true
    s.vehicles[id].insuranceLocked = false

    if financed == true then
        addHistory('LENDER_MONITOR', s.vehicles[id].name .. ' is now financed. Insurance is customer-controlled, but Marmur Bank requires coverage within 10 days if it is uninsured.', 0, id)
    else
        addHistory('PAYOFF', s.vehicles[id].name .. ' is now owned. Marmur no longer audits insurance on this vehicle.', 0, id)
        s.marmur.violations[id] = nil
        s.marmur.defaulted[id] = nil
        s.marmur.repossessionRequested[id] = nil
    end

    Coverage.recalculate()
    return true, 'Vehicle financing status updated.'
end

function Coverage.setVehiclePaidOff(vehicleId)
    return Coverage.setVehicleFinanced(vehicleId, false, nil)
end

local function nativeCoverageAccountState()
    local getter = VanguardCoverageNativeAccountState
    if type(getter) ~= 'function' then return nil end
    local ok, state = pcall(getter)
    if not ok or type(state) ~= 'table' then return nil end
    return state
end

local function nativeCoverageModificationAllowed()
    local state = nativeCoverageAccountState()
    if not state then return nil, 'UNAVAILABLE' end
    if state.terminated == true then return false, 'TERMINATED' end
    if state.suspended == true then return false, 'SUSPENDED' end
    return state.canModify == true, state.canModify == true and 'AVAILABLE' or 'RESTRICTED'
end

                                                                                 
                                                                              
                                                                               
function Coverage.getMirroredPolicyVehicleKey(vehicleId)
    local s = ensureState()
    local id = resolvePolicyKey(s, vehicleId)
    if id == '' or id == 'nil' then return '' end
    if not s.vehicles[id] then return '' end
    if not s.policy or not s.policy.selected or s.policy.selected[id] ~= true then return '' end
    return id
end

function Coverage.isInsured(vehicleId)
    if not Opt.insuranceEnabled() then return false end
    local s = ensureState()
    local id = resolvePolicyKey(s, vehicleId)
    local vehicle = s.vehicles[id]
    if vehicleLooksIneligible(vehicle or id) then return false end
    local nativeCheck = VanguardCoverageNativeIsVehicleInsured
    if type(nativeCheck) == 'function' then
        local ok, nativeInsured = pcall(nativeCheck, id)
        if ok then return nativeInsured == true end
        return false
    end
    if s.policy.active ~= true then return false end
    if s.policy.selected[id] ~= true then return false end
    if s.policy.lapsed == true then return false end
    local day = getCurrentDay()
    local endDay = tonumber(s.policy.termEndDay) or 0
    if endDay <= 0 then return false end
    if day > endDay then return false end
    return true
end

function Coverage.getInsuranceStatus(vehicleId)
    if Coverage.isVehicleIneligible(vehicleId) then return 'INELIGIBLE' end
    return Coverage.isInsured(vehicleId) and 'INSURED' or 'UNINSURED'
end

function Coverage.getGarageBadge(vehicleId)
    local status = Coverage.getInsuranceStatus(vehicleId)
    local tone = 'red'
    if status == 'INSURED' then
        tone = 'green'
    elseif status == 'INELIGIBLE' then
        tone = 'blue'
    end
    return {
        label = status,
        tone = tone,
    }
end

function Coverage.cloneSelection()
    local s = ensureState()
    local out = {}
    for id, selected in pairs(s.policy.selected or {}) do
        if selected == true and not Coverage.isVehicleIneligible(id) then out[id] = true end
    end
    return out
end

local function markUserPolicyAdjusted()
    local s = ensureState()
    s.migration = s.migration or defaultMigration()
    s.migration.userAdjustedPolicy = true
    s.migration.autoManaged = false
    requestSave()
end

function Coverage.setDeductibleOption(option)
    local allowed, state = nativeCoverageModificationAllowed()
    if allowed == false then return false, 'Policy changes are unavailable while the Vanguard account is ' .. string.lower(state) .. '.' end
    local s = ensureState()
    local data, index = deductibleOptionData(option)
    s.policy.deductibleOption = index
    markUserPolicyAdjusted()
    addHistory('DEDUCTIBLE_CHANGE', 'Deductible changed to ' .. Coverage.formatMoney(data.amount) .. ' per claim.', 0, '')
    Coverage.recalculate()
    return true, data.name
end

function Coverage.setBillingMode(mode)
    local allowed, state = nativeCoverageModificationAllowed()
    if allowed == false then return false, 'Policy changes are unavailable while the Vanguard account is ' .. string.lower(state) .. '.' end
    local s = ensureState()
    local data, key = billingData(mode)
    s.policy.billingMode = key
    markUserPolicyAdjusted()
    addHistory('BILLING_CHANGE', 'Billing changed to ' .. data.name .. '.', 0, '')
    Coverage.recalculate()
    return true, data.name
end

                                                                                            
function Coverage.setTier(level)
    local map = { [1] = 3, [2] = 2, [3] = 1 }
    return Coverage.setDeductibleOption(map[tonumber(level) or 1] or 3)
end

function Coverage.getTiers()
    return Coverage.DEDUCTIBLES
end


function Coverage.getPolicyBreakdown(selection, deductibleOption, billingMode)
    return Coverage.quote(selection, deductibleOption, billingMode).breakdown
end

function Coverage.selectVehicle(vehicleId, selected)
    local allowed, state = nativeCoverageModificationAllowed()
    if allowed == false then return false, 'Vehicle coverage changes are unavailable while the Vanguard account is ' .. string.lower(state) .. '.' end
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId)
    local vehicle = s.vehicles[id]
    if not vehicle then return false, 'Vehicle not found.' end
    if vehicle.ineligible == true then
        clearIneligibleVehicleState(s, id)
        return false, 'Delamain cabs are ineligible for Vanguard Coverage.'
    end

    s.policy.selected[id] = selected == true
    markUserPolicyAdjusted()
    if selected == true then
        s.policy.active = true
        addHistory('INSURE', vehicle.name .. ' marked INSURED.', 0, id)
    else
        addHistory('UNINSURE', vehicle.name .. ' marked UNINSURED.', 0, id)
    end

    if selectedCount() == 0 then s.policy.active = false end
    Coverage.recalculate()
    Coverage.auditMarmur(true)
    return true, selected and 'Vehicle insured.' or 'Vehicle uninsured.'
end

function Coverage.quote(selection, deductibleOption, billingMode)
    local s = ensureState()
    selection = selection or s.policy.selected or {}

    local option, optionIndex = deductibleOptionData(deductibleOption or s.policy.deductibleOption)
    local billing, billingKey = billingData(billingMode or s.policy.billingMode)
    local termDays = tonumber(billing.termDays) or Coverage.TERM_DAYS

    local totalValue = 0
    local count = 0
    local financedCount = 0
    local vehicleRows = {}

    for id, selected in pairs(selection or {}) do
        local vehicle = s.vehicles[id]
        if selected == true and vehicle and vehicle.ineligible ~= true then
            local value = roundMoney(vehicle.value or 0)
            totalValue = totalValue + value
            count = count + 1
            if vehicle.financed then financedCount = financedCount + 1 end
            table.insert(vehicleRows, {
                id = id,
                name = vehicle.name,
                value = value,
                financed = vehicle.financed == true,
                vehiclePremium = 0,
            })
        end
    end

    table.sort(vehicleRows, function(a, b) return tostring(a.name) < tostring(b.name) end)

    local rawTermPremium = 0
    local multiVehicleDiscountRate = 0
    local multiVehicleDiscountAmount = 0
    local preGoodDriverPremium = 0
    local goodDriver = updateGoodDriverStatus(count)
    local stats = ensureStats(s)
    local accidentSurchargeRateValue = accidentSurchargeRate(stats)
    local accidentSurchargeAmount = 0
    local goodDriverDiscountAmount = 0
    local baseTermPremium = 0

    if count > 0 then
        rawTermPremium = roundMoney(totalValue * option.termRate)
        if rawTermPremium < option.minTermPremium then rawTermPremium = option.minTermPremium end

        if count > 1 then
            multiVehicleDiscountRate = math.min(Coverage.MULTI_VEHICLE_DISCOUNT_CAP, (count - 1) * Coverage.MULTI_VEHICLE_DISCOUNT_PER_EXTRA)
        end
        multiVehicleDiscountAmount = roundMoney(rawTermPremium * multiVehicleDiscountRate)
        preGoodDriverPremium = math.max(option.minTermPremium, rawTermPremium - multiVehicleDiscountAmount)
        goodDriverDiscountAmount = roundMoney(preGoodDriverPremium * (tonumber(goodDriver.rate) or 0))
        baseTermPremium = math.max(option.minTermPremium, preGoodDriverPremium - goodDriverDiscountAmount)
        accidentSurchargeAmount = roundMoney(baseTermPremium * accidentSurchargeRateValue)
        baseTermPremium = baseTermPremium + accidentSurchargeAmount
                                                                                                 
                                                                                                            
    end

    local breakdown = buildBreakdown(baseTermPremium, totalValue, count, vehicleRows, option)
    for _, vehicle in ipairs(vehicleRows) do
        vehicle.vehiclePremium = breakdown.vehiclePremiums[vehicle.id] or 0
    end

    local payInFullPremium = count > 0 and roundMoney(baseTermPremium * (1.0 - Coverage.PAY_IN_FULL_DISCOUNT)) or 0
    local termMonths = tonumber(billing.termMonths) or 6
    local weeklyDenominator = termMonths >= 12 and 52.0 or 26.0
    local biweeklyDenominator = termMonths >= 12 and 26.0 or 13.0
    local monthlyDenominator = termMonths >= 12 and 12.0 or 6.0
    local weeklyInstallment = count > 0 and ceilMoney(baseTermPremium / weeklyDenominator) or 0
    local biweeklyInstallment = count > 0 and ceilMoney(baseTermPremium / biweeklyDenominator) or 0
    local monthlyInstallment = count > 0 and ceilMoney(baseTermPremium / monthlyDenominator) or 0
    local installmentCount = tonumber(billing.installmentCount) or 6
    local selectedInstallment = count > 0 and installmentAmountFor(baseTermPremium, billingKey) or 0
    local dueNow = selectedInstallment
    local termStatus = Coverage.getTermStatus()
    local quoteDaysRemaining = termStatus.activeTerm and termStatus.daysRemaining or (count > 0 and termDays or 0)

    return {
        policyName = Coverage.POLICY_NAME,
        deductibleOption = optionIndex,
        deductibleName = option.name,
        deductibleShort = option.short,
        deductibleAmount = option.amount,
        deductibleDescription = option.description,
        billingMode = billingKey,
        billingName = billing.name,
        billingShort = billing.short,
        count = count,
        financedCount = financedCount,
        totalValue = totalValue,
        rawTermPremium = rawTermPremium,
        multiVehicleDiscountRate = multiVehicleDiscountRate,
        multiVehicleDiscountAmount = multiVehicleDiscountAmount,
        preGoodDriverPremium = preGoodDriverPremium,
        goodDriverDiscountRate = tonumber(goodDriver.rate) or 0,
        goodDriverDiscountAmount = goodDriverDiscountAmount,
        goodDriverLabel = tostring(goodDriver.label or 'Not Eligible Yet'),
        goodDriverMessage = tostring(goodDriver.message or ''),
        goodDriverDaysObserved = tonumber(goodDriver.daysObserved) or 0,
        goodDriverIncidentScore = tonumber(goodDriver.incidentScore) or 0,
        goodDriverIncidentRate = tonumber(goodDriver.incidentRate) or 0,
        goodDriverRepairClaims = tonumber(goodDriver.repairClaims) or 0,
        goodDriverAccidents = tonumber(goodDriver.accidents) or 0,
        goodDriverNextReviewDay = tonumber(goodDriver.nextReviewDay) or 0,
        accidentSurchargeRate = accidentSurchargeRateValue,
        accidentSurchargeAmount = accidentSurchargeAmount,
        accidentSurchargeAtFaultCount = tonumber(stats.accidentSurcharge.atFaultCount) or 0,
        termPremium = baseTermPremium,
        payInFullPremium = payInFullPremium,
        monthlyPremium = monthlyInstallment,
        monthlyInstallment = monthlyInstallment,
        weeklyInstallment = weeklyInstallment,
        biweeklyInstallment = biweeklyInstallment,
        installmentAmount = selectedInstallment,
        selectedInstallment = selectedInstallment,
        installmentCount = installmentCount,
        installmentsPerTerm = installmentCount,
        paymentIntervalDays = tonumber(billing.intervalDays) or 0,
        paymentFrequency = billing.name,
        dueNow = dueNow,
        termDays = termDays,
        coverageDaysRemaining = quoteDaysRemaining,
        termMonths = termMonths,
        policyNumber = s.policy.policyNumber or '',
        termStartDay = termStatus.termStartDay,
        termEndDay = termStatus.termEndDay,
        currentDay = termStatus.currentDay,
        discountRate = Coverage.PAY_IN_FULL_DISCOUNT,
        effectiveRate = option.termRate,
        outsideMechanicCost = Coverage.MECHANIC_REFERENCE_COST,
        claimSavingsVsMechanic = math.max(0, Coverage.MECHANIC_REFERENCE_COST - option.amount),
        allVehiclesMechanicRepairCost = count * Coverage.MECHANIC_REFERENCE_COST,
        allVehiclesVanguardRepairCost = count * option.amount,
        allVehiclesRepairSavings = math.max(0, (count * Coverage.MECHANIC_REFERENCE_COST) - (count * option.amount)),
        vehicles = vehicleRows,
        breakdown = breakdown,
        policyCoverages = breakdown.policyRows,
        vehicleCoverages = breakdown.vehicleRows,
        policyCoverageTotal = breakdown.policyCoverageTotal,
        vehicleCoverageTotal = breakdown.vehicleCoverageTotal,
        breakdownTotal = breakdown.lineItemTotal,
    }
end

function Coverage.recalculate()
    local s = ensureState()
    local q = Coverage.quote()
    local freezePaidInFull = s.policy.active == true and (tostring(s.policy.billingMode or '') == 'pay_in_full' or tostring(s.policy.billingMode or '') == 'pay_in_full_12') and policyHasActiveTerm() and (tonumber(q.accidentSurchargeRate) or 0) > 0 and s.policy.acceptPendingSurchargePremium ~= true and (tonumber(s.policy.lastTermPremium) or 0) > 0
    s.policy.lastPremium = q.dueNow
    if freezePaidInFull then
        s.policy.pendingAccidentSurchargePremium = math.max(0, roundMoney((q.termPremium or 0) - (tonumber(s.policy.lastTermPremium) or 0)))
    else
        s.policy.lastTermPremium = q.termPremium
        s.policy.lastPayInFullPremium = q.payInFullPremium
        s.policy.pendingAccidentSurchargePremium = 0
    end
    s.policy.lastMonthlyPremium = q.monthlyInstallment
    s.policy.lastWeeklyPremium = q.weeklyInstallment
    s.policy.lastBiweeklyPremium = q.biweeklyInstallment
    s.policy.lastInstallmentAmount = q.installmentAmount
    s.policy.lastDeductible = q.deductibleAmount
    s.policy.termDays = q.termDays
    s.policy.termMonths = q.termMonths
    s.policy.lastTotalValue = q.totalValue
    s.policy.lastGoodDriverDiscountRate = q.goodDriverDiscountRate
    s.policy.lastGoodDriverDiscountAmount = q.goodDriverDiscountAmount
    s.policy.lastMultiVehicleDiscountAmount = q.multiVehicleDiscountAmount
    s.policy.active = q.count > 0
    requestSave()
    return q
end

function Coverage.applySelection(selection, deductibleOption, billingMode)
    local s = ensureState()
    selection = selection or {}

    s.policy.selected = {}
    for id, wanted in pairs(selection) do
        if wanted == true then
            local resolvedId = resolveVehicleKey(s, id)
            if resolvedId ~= '' and resolvedId ~= 'nil' and s.vehicles[resolvedId] and s.vehicles[resolvedId].ineligible ~= true then
                s.policy.selected[resolvedId] = true
            end
        end
    end

    local _, optionIndex = deductibleOptionData(deductibleOption or s.policy.deductibleOption)
    local _, billingKey = billingData(billingMode or s.policy.billingMode)
    s.policy.deductibleOption = optionIndex
    s.policy.billingMode = billingKey
    s.policy.termDays = termDaysForBillingKey(billingKey)
    s.policy.termMonths = termMonthsForBillingKey(billingKey)
    if selectedCount() > 0 then policyNumber() end
    s.policy.active = selectedCount() > 0
    markUserPolicyAdjusted()

    addHistory('POLICY_UPDATE', 'Insurance selections confirmed: ' .. tostring(selectedCount()) .. ' vehicle(s), ' .. Coverage.formatMoney(Coverage.DEDUCTIBLES[optionIndex].amount) .. ' deductible, ' .. Coverage.BILLING[billingKey].name .. '.', 0, '')
    Coverage.recalculate()
    Coverage.auditMarmur(true)
    return true, 'Insurance updated.'
end


function Coverage.calculateEndorsement(selection, deductibleOption, billingMode)
    local s = ensureState()
    local current = Coverage.quote(s.policy.selected, s.policy.deductibleOption, s.policy.billingMode)
    local pending = Coverage.quote(selection, deductibleOption, billingMode)
    local termStatus = Coverage.getTermStatus()
    local daysRemaining = termStatus.activeTerm and termStatus.daysRemaining or Coverage.TERM_DAYS
    local currentTermDays = tonumber(s.policy.termDays) or tonumber(current.termDays) or Coverage.TERM_DAYS
    local pendingTermDays = tonumber(pending.termDays) or currentTermDays
    local currentPremiumForEndorsement = current.termPremium or 0
    if policyHasActiveTerm() and (tonumber(s.policy.lastTermPremium) or 0) > 0 then
        currentPremiumForEndorsement = tonumber(s.policy.lastTermPremium) or currentPremiumForEndorsement
    end

    if currentTermDays <= 0 then currentTermDays = Coverage.TERM_DAYS end
    if pendingTermDays <= 0 then pendingTermDays = currentTermDays end

                                                                             
                                                                               
                                                        
    local currentDaily = currentPremiumForEndorsement / currentTermDays
    local pendingDaily = (pending.termPremium or 0) / pendingTermDays
    local dailyDelta = pendingDaily - currentDaily
    local proratedRaw = dailyDelta * daysRemaining
    local termPremiumDelta = roundSignedMoney((pending.termPremium or 0) - currentPremiumForEndorsement)
    local proratedDifference = roundMoney(math.abs(proratedRaw))
    local dueNow = 0
    if proratedRaw > 0 then
        if billingKey == 'pay_in_full' or billingKey == 'pay_in_full_12' then
            dueNow = roundMoney(proratedRaw)
        else
            dueNow = installmentAmountFor(roundMoney(proratedRaw), billingKey)
        end
    end
    local credit = proratedRaw < 0 and roundMoney(math.abs(proratedRaw)) or 0
    local factor = currentTermDays > 0 and (daysRemaining / currentTermDays) or 0

    return {
        activeTerm = termStatus.activeTerm,
        currentDay = termStatus.currentDay,
        termDays = pending.termDays or Coverage.TERM_DAYS,
        daysRemaining = daysRemaining,
        currentTermPremium = currentPremiumForEndorsement,
        pendingTermPremium = pending.termPremium,
        termPremiumDelta = termPremiumDelta,
        proratedFactor = factor,
        proratedDifference = proratedDifference,
        dueNow = dueNow,
        credit = credit,
        currentQuote = current,
        pendingQuote = pending,
    }
end

function Coverage.quoteAdjustment(selection, deductibleOption, billingMode)
    return Coverage.calculateEndorsement(selection, deductibleOption, billingMode)
end

function Coverage.applyMidtermChange(selection, deductibleOption, billingMode)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end
    local s = ensureState()
    local endorsement = Coverage.calculateEndorsement(selection, deductibleOption, billingMode)
    local due = roundMoney(endorsement.dueNow or 0)

    if due > 0 then
		local walletBefore = Wallet.balance()
        local ok, balance = Opt.remove(Wallet, due, 'premium')
        if not ok then
            addHistory('ENDORSEMENT_FAILED', 'Mid-term policy update failed. Balance too low for prorated difference.', due, '')
            return false, 'Insufficient funds. Prorated difference due now: ' .. Coverage.formatMoney(due) .. '.', due
        end
		recordMarmurInsuranceSpend(math.max(0, walletBefore - (tonumber(balance) or Wallet.balance())), 'vanguard_coverage_endorsement')
        addHistory('ENDORSEMENT_PAYMENT', 'Prorated insurance difference paid for mid-term policy update. Remaining term: ' .. tostring(endorsement.daysRemaining) .. ' day(s).', due, '')
    elseif (endorsement.credit or 0) > 0 then
        local credit = roundMoney(endorsement.credit)
        local refunded = Wallet.add(credit)
        if refunded then
            addHistory('ENDORSEMENT_REFUND', 'Prorated insurance refund paid for mid-term policy update. Remaining term: ' .. tostring(endorsement.daysRemaining) .. ' day(s).', credit, '')
        else
            addHistory('ENDORSEMENT_REFUND_FAILED', 'Mid-term policy update created a prorated refund, but the wallet refund could not be applied.', credit, '')
        end
    else
        addHistory('ENDORSEMENT_UPDATE', 'Mid-term policy update confirmed with no prorated amount due.', 0, '')
    end

    Coverage.applySelection(selection, deductibleOption, billingMode)

    s.policy.acceptPendingSurchargePremium = true
    local q = Coverage.recalculate()
    s.policy.acceptPendingSurchargePremium = false
    s.policy.pendingAccidentSurchargePremium = 0
    local _, billingKey = billingData(s.policy.billingMode)
    s.policy.billingMode = billingKey
    s.policy.lapsed = false
    s.policy.pastDue = false

    if billingKey == 'pay_in_full' then
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.installmentsPaid = 1
        s.policy.installmentsRemaining = 0
    else
        local billing = Coverage.BILLING[billingKey]
        local count = tonumber(billing.installmentCount) or 6
        local paid = elapsedInstallmentsFor(s.policy.termStartDay, billingKey, getCurrentDay())
        s.policy.installmentsPaid = paid
        s.policy.installmentsRemaining = math.max(0, count - paid)
        s.policy.paymentDue = q.installmentAmount
        s.policy.nextDueDay = nextInstallmentDueDay(s.policy.termStartDay, billingKey, paid)
    end

    Coverage.saveNow()
    if due > 0 then
        return true, 'Policy updated. Prorated difference paid: ' .. Coverage.formatMoney(due) .. '.', due
    elseif (endorsement.credit or 0) > 0 then
        return true, 'Policy updated. Prorated refund issued: ' .. Coverage.formatMoney(endorsement.credit) .. '.', 0
    end
    return true, 'Policy updated. No prorated amount due.', 0
end

function Coverage.startNewTerm()
    local s = ensureState()
    local q = Coverage.recalculate()
    if q.count <= 0 then
        s.policy.active = false
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.termStartDay = 0
        s.policy.termEndDay = 0
        s.policy.installmentsPaid = 0
        s.policy.installmentsRemaining = 0
        s.policy.lapsed = false
        s.policy.pastDue = false
        addHistory('POLICY_INACTIVE', 'No vehicles selected. Insurance policy is inactive.', 0, '')
        Coverage.saveNow()
        return true, 'No vehicles selected. Policy saved as inactive.', 0
    end

    local due = q.dueNow
	local walletBefore = Wallet.balance()
    local ok, balance = Opt.remove(Wallet, due, 'premium')
    if not ok then
        addHistory('PAYMENT_FAILED', 'Policy activation failed. Balance too low.', due, '')
        return false, 'Insufficient funds. Due now: ' .. Coverage.formatMoney(due) .. '.', due
    end
	recordMarmurInsuranceSpend(math.max(0, walletBefore - (tonumber(balance) or Wallet.balance())), 'vanguard_coverage_new_term')

    local day = getCurrentDay()
    ensureStats(s)
    s.stats.firstReviewDay = day
    s.stats.goodDriverFullPayRefundedLevel = 0
    s.stats.goodDriverFullPayRefundedVersion = 0
    if s.stats.goodDriver then s.stats.goodDriver.rewardVersion = 0 end
    s.policy.active = true
    s.policy.termStartDay = day
    s.policy.termDays = q.termDays
    s.policy.termMonths = q.termMonths
    policyNumber()
    s.policy.termEndDay = day + q.termDays
    s.policy.lastPaidDay = day
    s.policy.lapsed = false
    s.policy.pastDue = false

    if q.billingMode == 'pay_in_full' or q.billingMode == 'pay_in_full_12' then
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.installmentsPaid = 1
        s.policy.installmentsRemaining = 0
        addHistory('PAYMENT', tostring(q.termDays) .. '-day insurance term paid in full. Deductible: ' .. Coverage.formatMoney(q.deductibleAmount) .. '.', due, '')
        Coverage.saveNow()
        return true, 'Policy active for ' .. tostring(q.termDays) .. ' days. Paid in full: ' .. Coverage.formatMoney(due) .. '. Remaining balance: ' .. Coverage.formatMoney(balance) .. '.', due
    end

    local billing = Coverage.BILLING[q.billingMode] or Coverage.BILLING.monthly
    local count = tonumber(billing.installmentCount) or 6
    s.policy.installmentsPaid = 1
    s.policy.installmentsRemaining = math.max(0, count - 1)
    s.policy.paymentDue = q.installmentAmount
    s.policy.nextDueDay = nextInstallmentDueDay(day, q.billingMode, s.policy.installmentsPaid)
    addHistory('PAYMENT', 'First ' .. billing.name .. ' insurance payment paid. Deductible: ' .. Coverage.formatMoney(q.deductibleAmount) .. '.', due, '')
    Coverage.saveNow()
    return true, 'Policy active for ' .. tostring(q.termDays) .. ' days. First ' .. billing.name .. ' payment paid: ' .. Coverage.formatMoney(due) .. '. Remaining balance: ' .. Coverage.formatMoney(balance) .. '.', due
end


function Coverage.importNativePolicy(selection, deductibleOption, billingMode, daysRemaining)
    local s = ensureState()
    selection = selection or {}
    local importedDaysRemaining = math.floor(tonumber(daysRemaining) or 0)

                                                                                  
                                                                                  
                                                                                 
                                                                               
    for id, selected in pairs(selection) do
        if selected == true then
            local key = sanitize(id or '')
            local resolved = resolveVehicleKey(s, key)
            if resolved == '' or resolved == 'nil' then resolved = key end
            if resolved ~= '' and resolved ~= 'nil' and not s.vehicles[resolved] then
                s.vehicles[resolved] = normalizeVehicle({
                    id = resolved,
                    name = resolved,
                    owned = true,
                    financed = false,
                    source = 'Vanguard Website Policy',
                })
            end
        end
    end

    Coverage.applySelection(selection, deductibleOption, billingMode)
    local q = Coverage.recalculate()
    local day = getCurrentDay()

    if q.count <= 0 then
        s.policy.active = false
        s.policy.termStartDay = 0
        s.policy.termEndDay = 0
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.installmentsPaid = 0
        s.policy.installmentsRemaining = 0
        s.policy.lapsed = false
        s.policy.pastDue = false
        addHistory('WEBSITE_IMPORT', 'Your insurance policy is inactive. No vehicles are currently insured.', 0, '')
        Coverage.auditMarmur(true)
        if not Coverage.saveNow() then
            return false, 'Your coverage changes could not be saved. Please try again.', 0
        end
        return true, 'Your insurance policy is inactive. No vehicles are currently insured.', 0
    end

    if importedDaysRemaining > 0 then
        local remaining = math.max(1, math.min(tonumber(q.termDays) or Coverage.TERM_DAYS, importedDaysRemaining))
        s.policy.termDays = q.termDays
        s.policy.termMonths = q.termMonths
        policyNumber()
        s.policy.termStartDay = day + remaining - q.termDays
        s.policy.termEndDay = day + remaining
        s.policy.lastPaidDay = day
    elseif not policyHasActiveTerm() then
        s.policy.termStartDay = day
        s.policy.termDays = q.termDays
        s.policy.termMonths = q.termMonths
        policyNumber()
        s.policy.termEndDay = day + q.termDays
        s.policy.lastPaidDay = day
        s.policy.installmentsPaid = 1
    else
        s.policy.lastPaidDay = day
    end

    s.policy.active = true
    s.policy.lapsed = false
    s.policy.pastDue = false

    local billing = Coverage.BILLING[q.billingMode] or Coverage.BILLING.monthly
    if q.billingMode == 'pay_in_full' then
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
        s.policy.installmentsPaid = 1
        s.policy.installmentsRemaining = 0
    else
        local count = tonumber(billing.installmentCount) or 6
        local paid = elapsedInstallmentsFor(s.policy.termStartDay, q.billingMode, day)
        if paid < 1 then paid = 1 end
        s.policy.installmentsPaid = paid
        s.policy.installmentsRemaining = math.max(0, count - paid)
        s.policy.paymentDue = q.installmentAmount
        s.policy.nextDueDay = nextInstallmentDueDay(s.policy.termStartDay, q.billingMode, paid)
    end

    addHistory('WEBSITE_IMPORT', 'Coverage updated: ' .. tostring(q.count) .. ' vehicle(s), ' .. Coverage.formatMoney(q.deductibleAmount) .. ' deductible, ' .. q.billingName .. '.', 0, '')
    Coverage.auditMarmur(true)
    if not Coverage.saveNow() then
        return false, 'Your coverage changes could not be saved. Please try again.', 0
    end
    return true, 'Your coverage has been updated.', 0
end

function Coverage.confirmPolicy(selection, deductibleOption, billingMode)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end
    local allowed, state = nativeCoverageModificationAllowed()
    if allowed == false then return false, 'Coverage cannot be purchased or modified while the Vanguard account is ' .. string.lower(state) .. '.', 0 end
    local s = ensureState()
    local preview = Coverage.quote(selection, deductibleOption, billingMode)
    if preview.count <= 0 then
        Coverage.applySelection(selection, deductibleOption, billingMode)
        local ok, msg, due = Coverage.startNewTerm()
        Coverage.auditMarmur(true)
        return ok, msg, due
    end

    if policyHasActiveTerm() then
        local endorsement = Coverage.calculateEndorsement(selection, deductibleOption, billingMode)
        if Wallet.balance() < (endorsement.dueNow or 0) then
            addHistory('PAYMENT_FAILED', 'Policy update blocked. Balance too low for prorated difference.', endorsement.dueNow or 0, '')
            return false, 'Insufficient funds. Prorated difference due now: ' .. Coverage.formatMoney(endorsement.dueNow or 0) .. '.', endorsement.dueNow or 0
        end
        local ok, msg, due = Coverage.applyMidtermChange(selection, deductibleOption, billingMode)
        Coverage.auditMarmur(true)
        return ok, msg, due
    end

    local balance = Wallet.balance()
    if balance < preview.dueNow then
        addHistory('PAYMENT_FAILED', 'Policy confirmation blocked. Balance too low.', preview.dueNow, '')
        return false, 'Insufficient funds. Due now: ' .. Coverage.formatMoney(preview.dueNow) .. '.', preview.dueNow
    end

    Coverage.applySelection(selection, deductibleOption, billingMode)
    local ok, msg, due = Coverage.startNewTerm()
    Coverage.auditMarmur(true)
    return ok, msg, due
end

function Coverage.payCurrentBill()
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end
    local s = ensureState()
    local account = nativeCoverageAccountState()
    if account and account.terminated == true then
        return false, 'No payment was collected because Vanguard coverage eligibility is permanently terminated.', 0
    end
    local q = Coverage.recalculate()
    if q.count <= 0 then return false, 'No insured vehicles on the policy.', 0 end

    local day = getCurrentDay()
    if s.policy.billingMode == 'pay_in_full' then
        if (tonumber(s.policy.termEndDay) or 0) > day then
            return true, 'Policy is paid in full through day ' .. tostring(s.policy.termEndDay) .. ' (' .. tostring(Coverage.getCoverageDaysRemaining()) .. ' day(s) remaining).', 0
        end
        if account and account.suspended == true then return false, 'A new policy term cannot begin while coverage is suspended.', 0 end
        return Coverage.startNewTerm()
    end

    if (tonumber(s.policy.termEndDay) or 0) <= 0 or (tonumber(s.policy.installmentsPaid) or 0) <= 0 then
        if account and account.suspended == true then return false, 'A new policy term cannot begin while coverage is suspended.', 0 end
        return Coverage.startNewTerm()
    end

    if (tonumber(s.policy.installmentsRemaining) or 0) <= 0 then
        if (tonumber(s.policy.termEndDay) or 0) > day then
            return true, 'All installments are paid for this 182-day policy term.', 0
        end
        if account and account.suspended == true then return false, 'A new policy term cannot begin while coverage is suspended.', 0 end
        return Coverage.startNewTerm()
    end

    local billing, billingKey = billingData(s.policy.billingMode)
    local count = tonumber(billing.installmentCount) or 6
    local due = q.installmentAmount
	local walletBefore = Wallet.balance()
    local ok, balance = Opt.remove(Wallet, due, 'premium')
    if not ok then
        addHistory('PAYMENT_FAILED', billing.name .. ' insurance payment failed. Balance too low.', due, '')
        return false, 'Insufficient funds for insurance payment. Needed ' .. Coverage.formatMoney(due) .. '.', due
    end
	recordMarmurInsuranceSpend(math.max(0, walletBefore - (tonumber(balance) or Wallet.balance())), 'vanguard_coverage_bill')

    s.policy.installmentsPaid = (tonumber(s.policy.installmentsPaid) or 0) + 1
    s.policy.installmentsRemaining = math.max(0, count - (tonumber(s.policy.installmentsPaid) or 0))
    s.policy.lastPaidDay = day
    s.policy.lapsed = false
    s.policy.pastDue = false

    if s.policy.installmentsRemaining > 0 then
        s.policy.paymentDue = q.installmentAmount
        s.policy.nextDueDay = nextInstallmentDueDay(s.policy.termStartDay or day, billingKey, s.policy.installmentsPaid)
    else
        s.policy.paymentDue = 0
        s.policy.nextDueDay = 0
    end

    for id, vehicle in pairs(s.vehicles or {}) do
        if vehicle.financed == true then
            local stillViolation = financedViolationCause(s, vehicle, day)
            if not stillViolation then s.marmur.violations[id] = nil end
        end
    end

    addHistory('PAYMENT', 'Insurance payment paid (' .. tostring(s.policy.installmentsPaid) .. '/' .. tostring(count) .. ') on ' .. billing.name .. '.', due, '')
    Coverage.auditMarmur(true)
    Coverage.saveNow()
    return true, 'Insurance payment accepted. Remaining balance: ' .. Coverage.formatMoney(balance) .. '.', due
end

                                
function Coverage.payMonthlyPremium()
    return Coverage.payCurrentBill()
end


function Coverage.markVehicleDamage(vehicleId, reason, deferPersistence)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    if id == '' or id == 'nil' then return false, 'Vehicle not recognized.' end
    local vehicle = s.vehicles[id]
    if not vehicle then return false, 'Vehicle not recognized by Vanguard Coverage.' end
    if vehicle.ineligible == true then
        clearIneligibleVehicleState(s, id)
        return false, 'Delamain cabs are ineligible for Vanguard Coverage.'
    end
    local existing = s.damage.vehicles[id] or {}
    s.damage.vehicles[id] = {
        damaged = true,
        day = getCurrentDay(),
        stamp = nowStamp(),
        reason = sanitize(reason or 'vehicle damage detected'),
                                                                             
                                                                             
                                                                 
        freshBodyPending = existing.freshBodyPending == true,
        freshBodyReason = existing.freshBodyReason,
    }
    if deferPersistence == true then
        requestCollisionSave()
    else
        requestSave()
    end
    return true, 'Vehicle damage recorded.'
end

function Coverage.completeExternalStructuralRepair(vehicleId)
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = s.vehicles and s.vehicles[id]
    if not vehicle or vehicle.ineligible == true then return false, 'Vehicle not eligible for repair synchronization.' end
    local rows = s.damage and s.damage.vehicles
    if rows and rows[id] ~= nil then
        rows[id] = nil
        requestSave()
    end
    return true, 'External structural repair synchronized.'
end

function Coverage.clearVehicleDamage(vehicleId)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    if id ~= '' then
        local row = s.damage.vehicles[id]
        if row and row.freshBodyPending == true then
            row.damaged = false
            row.reason = nil
        else
            s.damage.vehicles[id] = nil
        end
    end
    requestSave()
    return true, 'Vehicle damage cleared.'
end

function Coverage.hasVehicleDamage(vehicleId)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = s.vehicles[id]
    if vehicle and vehicle.ineligible == true then return false end
    local row = s.damage.vehicles[id]
    return row ~= nil and row.damaged == true
end

function Coverage.markFreshBodyPending(vehicleId, reason)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    if id == '' or id == 'nil' then return false, 'Vehicle not recognized.' end
    local vehicle = s.vehicles[id]
    if not vehicle then return false, 'Vehicle not recognized by Vanguard Coverage.' end
    if vehicle.ineligible == true then
        clearIneligibleVehicleState(s, id)
        return false, 'Delamain cabs are ineligible for Vanguard Coverage.'
    end

    local row = s.damage.vehicles[id] or {}
    row.freshBodyPending = true
    row.freshBodyDay = getCurrentDay()
    row.freshBodyStamp = nowStamp()
    row.freshBodyReason = sanitize(reason or 'structural repair requires native body refresh')
    s.damage.vehicles[id] = row
    requestSave()
    return true, 'Fresh body refresh queued.'
end

function Coverage.clearFreshBodyPending(vehicleId)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    local row = id ~= '' and s.damage.vehicles[id] or nil
    if row then
        row.freshBodyPending = nil
        row.freshBodyDay = nil
        row.freshBodyStamp = nil
        row.freshBodyReason = nil
        if row.damaged ~= true then s.damage.vehicles[id] = nil end
    end
    requestSave()
    return true, 'Fresh body refresh cleared.'
end

function Coverage.hasFreshBodyPending(vehicleId)
    local s = ensureState()
    s.damage = s.damage or { vehicles = {} }
    s.damage.vehicles = s.damage.vehicles or {}
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = s.vehicles[id]
    if vehicle and vehicle.ineligible == true then return false end
    local row = s.damage.vehicles[id]
    return row ~= nil and row.freshBodyPending == true
end

local function clampNumber(value, minValue, maxValue)
    local n = tonumber(value) or 0
    if n < minValue then return minValue end
    if n > maxValue then return maxValue end
    return n
end

local function normalizeClaimTarget(targetType)
    local raw = tostring(targetType or ''):lower()
    if raw == '2' or raw == '3' or raw == 'bodily_injury' or raw == 'pedestrian' or raw == 'civilian' then
        return 'bodily_injury'
    end
    return 'property_damage'
end

local function impactFromScore(impactScore, claimTarget)
    local score = tonumber(impactScore) or 0
    if score <= 0 then return nil end
    local impact = score / 100
    if claimTarget == 'bodily_injury' then
        return clampNumber(impact, 4.0, 32.0)
    end
    return clampNumber(impact, 1.25, 12.0)
end

local function severityFromImpact(impact, claimTarget, payout)
    local force = tonumber(impact) or 0
    if force > 0 then
        if claimTarget == 'bodily_injury' then
            if force >= 22.0 then return 3 end
            if force >= 12.0 then return 2 end
            return 1
        end
        if force >= 7.0 then return 3 end
        if force >= 3.5 then return 2 end
        return 1
    end

    local paid = roundMoney(payout or 0)
    if paid >= 60000 then return 3 end
    if paid >= 15000 then return 2 end
    return 1
end

local function calculateDynamicAccidentPayout(vehicle, atFault, impactScore, claimTarget)
    local impact = impactFromScore(impactScore, claimTarget)
    if not impact then return 0, nil end

    local value = roundMoney((vehicle and vehicle.value) or 0)
    if value <= 0 then value = 40000 end

    if claimTarget == 'bodily_injury' then
        local normalized = clampNumber((impact - 4.0) / 28.0, 0.0, 1.0)
        local severity = 0.45 + normalized * 3.75 + normalized * normalized * 4.0
        local raw = (3500 + value * 0.006) * severity + normalized * 90000
        return math.min(250000, math.max(1500, roundMoney(raw))), impact
    end

    local normalized = clampNumber((impact - 1.25) / 10.75, 0.0, 1.0)
    local severity = 0.35 + normalized * 2.85 + normalized * normalized * 2.4
    local raw = (2500 + value * 0.018) * severity + normalized * value * 0.035
    if atFault == true then
        return math.min(180000, math.max(750, roundMoney(raw))), impact
    end

                                                                             
                                                                              
                                                                   
    local fairSettlementFloor = math.max(2500, roundMoney(value * 0.025))
    return math.min(180000, math.max(fairSettlementFloor, roundMoney(raw))), impact
end

local function collisionTermPremium(s)
    local option = deductibleOptionData(s.policy.deductibleOption)
    local totalValue = 0
    local count = 0
    for id, selected in pairs(s.policy.selected or {}) do
        local vehicle = s.vehicles[id]
        if selected == true and vehicle and vehicle.ineligible ~= true then
            totalValue = totalValue + roundMoney(vehicle.value or 0)
            count = count + 1
        end
    end
    if count == 0 then return 0 end

    local rawPremium = math.max(option.minTermPremium, roundMoney(totalValue * option.termRate))
    local multiVehicleRate = math.min(Coverage.MULTI_VEHICLE_DISCOUNT_CAP, (count - 1) * Coverage.MULTI_VEHICLE_DISCOUNT_PER_EXTRA)
    local preGoodDriverPremium = math.max(option.minTermPremium, rawPremium - roundMoney(rawPremium * multiVehicleRate))
    local goodDriverRate = tonumber(s.stats and s.stats.goodDriver and s.stats.goodDriver.rate) or 0
    local basePremium = math.max(option.minTermPremium, preGoodDriverPremium - roundMoney(preGoodDriverPremium * goodDriverRate))
    return basePremium + roundMoney(basePremium * accidentSurchargeRate(s.stats))
end

function Coverage.handleDrivingAccident(vehicleId, atFault, amount, impactScore, targetType, alreadyPaid, coverageAuthorityConfirmed)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = s.vehicles[id]
    if not vehicle then return false, 'Vehicle impact detected, but Vanguard could not match it to a garage vehicle.', 0 end
    if vehicle.ineligible == true then return false, 'Delamain cabs are ineligible for Vanguard Coverage.', 0 end

                                                                                  
                                                                                
                                                                                    
    local normalSaveWasPending = saveRequested == true
    local function finishCollision(ok, message, paidAmount)
        saveRequested = normalSaveWasPending
        requestCollisionSave()
        return ok, message, paidAmount
    end

    local claimTarget = normalizeClaimTarget(targetType)
    local damageReason = claimTarget == 'bodily_injury' and 'civilian pedestrian impact detected' or (atFault == true and 'at-fault collision detected' or 'vehicle hit by traffic')
    Coverage.markVehicleDamage(id, damageReason, true)

    local payout, impact = calculateDynamicAccidentPayout(vehicle, atFault == true, impactScore, claimTarget)
    local redscriptPaidAmount = roundMoney(amount or 0)
    if alreadyPaid == true and redscriptPaidAmount > 0 then
                                                                              
        payout = redscriptPaidAmount
    elseif payout <= 0 then
        payout = redscriptPaidAmount
    end
    if payout <= 0 then
        local value = roundMoney(vehicle.value or 0)
        if claimTarget == 'bodily_injury' then
            payout = math.min(250000, math.max(5000, roundMoney(value * 0.012)))
        else
            payout = atFault == true and math.min(180000, math.max(2500, roundMoney(value * 0.006))) or math.min(180000, math.max(2500, roundMoney(value * 0.025)))
        end
    end

    local severity = severityFromImpact(impact, claimTarget, payout)

    if coverageAuthorityConfirmed ~= true and not Coverage.isInsured(id) then
        local denied = claimTarget == 'bodily_injury'
            and vehicle.name .. ' was involved in a civilian injury claim, but no Vanguard Coverage payout was available because the vehicle is not covered.'
            or vehicle.name .. ' was damaged, but no Vanguard Coverage payout was available because the vehicle is not covered.'
        addHistory('ACCIDENT_UNINSURED', denied, payout, id)
        return finishCollision(false, 'Damage detected. ' .. vehicle.name .. ' is not covered under your insurance policy.', 0)
    end

    if atFault == true then
        local previousPremium = collisionTermPremium(s)
        local increase, newRate = addAtFaultSurcharge(s, severity, payout)
        local incidentScore = severity + (claimTarget == 'bodily_injury' and 2 or 1)
        local claimDescription = claimTarget == 'bodily_injury' and 'bodily injury' or 'property damage'
        local liabilityHistory = 'At-fault collision detected. Vanguard has paid ' .. Coverage.formatMoney(payout) .. ' to settle the third-party ' .. claimDescription .. ' claim.'
        recordIncident('accident', id, incidentScore, true, payout)
        addHistory('LIABILITY_PAYOUT', liabilityHistory, payout, id)
        if (increase or 0) > 0 then
            addHistory('RATE_SURCHARGE', 'At-fault surcharge added: +' .. tostring(math.floor((increase or 0) * 1000 + 0.5) / 10) .. '%. Current surcharge: ' .. tostring(math.floor((newRate or 0) * 1000 + 0.5) / 10) .. '%.', 0, id)
        end

        if tostring(s.policy.billingMode or '') ~= 'pay_in_full' and tostring(s.policy.billingMode or '') ~= 'pay_in_full_12' then
                                                                                    
                                                                                      
                                                                             
            s.policy.pendingCollisionRerate = true
            s.policy.pendingCollisionRerateVehicleId = id
        else
            addHistory('RATE_ADJUSTMENT_PENDING', 'Paid-in-full policy surcharge will be collected the next time the policy is changed or renewed.', 0, id)
        end

        local currentPremium = collisionTermPremium(s)
        local increasePercent = previousPremium > 0
            and math.max(0, (currentPremium - previousPremium) * 100 / previousPremium)
            or math.max(0, increase * 100 / (1 + newRate - increase))
        local premiumMessage = 'Your policy premium is unchanged.'
        if increasePercent > 0 then
            local percentage = string.format('%.2f', increasePercent):gsub('0+$', ''):gsub('%.$', '')
            if increasePercent < 0.01 then percentage = 'less than 0.01' end
            premiumMessage = 'Your policy premium has increased by ' .. percentage .. '% based on the settlement amount.'
            local billingMode = tostring(s.policy.billingMode or '')
            if billingMode == 'pay_in_full' or billingMode == 'pay_in_full_12' then
                premiumMessage = premiumMessage .. ' This adjustment applies when your policy is changed or renewed.'
            end
        elseif newRate >= Coverage.AT_FAULT_SURCHARGE_CAP then
            premiumMessage = 'Your policy premium is unchanged; the maximum at-fault surcharge has already been applied.'
        end
        return finishCollision(true, liabilityHistory .. ' ' .. premiumMessage, payout)
    end

    local balance = Wallet.balance()
    if alreadyPaid ~= true then
        local paid
        paid, balance = Wallet.add(payout)
        if not paid then
            addHistory('SETTLEMENT_FAILED', vehicle.name .. ' was hit by traffic, but the settlement transfer failed before it reached the account wallet.', payout, id)
            return finishCollision(false, 'Third-party insurer settlement approved, but the wallet transfer failed. No eddies were added.', 0)
        end
    end

    recordIncident('accident', id, severity, false, payout)
    addHistory('SETTLEMENT_PAYOUT', vehicle.name .. ' was hit by traffic. Settlement transferred to account.', payout, id)
    return finishCollision(true, 'Third-party insurer settlement transferred for vehicle damage: ' .. Coverage.formatMoney(payout) .. '. Wallet balance: ' .. Coverage.formatMoney(balance or 0) .. '.', payout)
end

function Coverage.repairVehicle(vehicleId, repairFn)
    if not Opt.insuranceEnabled() then return false, 'Vanguard insurance is disabled in Mod Settings.', 0 end
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId)
    local vehicle = s.vehicles[id]
    if not vehicle then return false, 'Vehicle not recognized by Vanguard Insurance.', 0 end
    if vehicle.ineligible == true then
        clearIneligibleVehicleState(s, id)
        return false, 'Delamain cabs are ineligible for Vanguard Coverage.', 0
    end
    if not Coverage.isInsured(id) then
        addHistory('REPAIR_DENIED', vehicle.name .. ' is UNINSURED. Repair claim rejected.', 0, id)
        return false, 'Damage detected. This vehicle is not covered under your insurance policy.', 0
    end

    if not Coverage.hasVehicleDamage(id) then
        addHistory('REPAIR_NO_DAMAGE', vehicle.name .. ' repair claim skipped: no damage detected.', 0, id)
        requestSave()
        return false, 'No damage detected.', 0
    end

    local q = Coverage.recalculate()
    local deductible = roundMoney(q.deductibleAmount)
    local balance = Wallet.balance()
    if balance < deductible then
        addHistory('REPAIR_FAILED', vehicle.name .. ' repair claim failed due to insufficient deductible funds.', deductible, id)
        return false, 'Insufficient funds for deductible: ' .. Coverage.formatMoney(deductible) .. '.', deductible
    end

    local paid = false
	local deductibleSpent = 0
    if deductible > 0 then
		local walletBefore = Wallet.balance()
        local ok, walletAfter = Opt.remove(Wallet, deductible, 'deductible')
        if not ok then
            return false, 'Could not collect deductible.', deductible
        end
		deductibleSpent = math.max(0, walletBefore - (tonumber(walletAfter) or Wallet.balance()))
        paid = true
    end

    local repaired = true
    local repairMessage = 'Repair hook completed.'
    if repairFn then
        local ok, result, msg = pcall(repairFn, vehicle)
        repaired = ok and result == true
        repairMessage = sanitize(msg or (ok and 'Repair hook returned.' or tostring(result)))
    end

    if not repaired then
        if paid then Wallet.add(deductible) end
        addHistory('REPAIR_FAILED', vehicle.name .. ' repair claim failed: ' .. repairMessage, deductible, id)
        return false, 'Repair failed; deductible refunded. ' .. repairMessage, deductible
    end

    if paid then recordMarmurInsuranceSpend(deductibleSpent, 'vanguard_coverage_repair') end
                                                                            
                                                                             
                                                                            
    Coverage.markFreshBodyPending(id, 'insured repair completed')
    Coverage.clearVehicleDamage(id)
    addHistory('REPAIR_CLAIM', vehicle.name .. ' repaired through Vanguard Coverage. Deductible: ' .. Coverage.formatMoney(deductible) .. '.', deductible, id)
    recordIncident('repair_claim', id, 1, false, deductible)
    requestSave()
                                                                               
                                                                   
    Coverage.saveNow()
    return true, 'Damage detected. Vehicle covered. Deductible collected: ' .. Coverage.formatMoney(deductible) .. '.', deductible
end

function Coverage.enforceFinancedMinimums(reason)
                                                                                             
                                                                                       
    return Coverage.runInstallAutoEnrollment(false, reason or 'compatibility_enforce_financed_minimums')
end

function Coverage.getFinancedCoverageRequirement()
    return {
        policyName = Coverage.POLICY_NAME,
        graceDays = Coverage.LENDER_COMPLIANCE_DAYS,
        noticeIntervalDays = Coverage.LENDER_NOTICE_INTERVAL_DAYS,
        noticeMax = Coverage.LENDER_NOTICE_MAX,
        maxDeductibleOption = Coverage.FINANCED_MAX_DEDUCTIBLE_OPTION,
        maxDeductibleAmount = lenderRequirementDeductibleAmount(),
        migrationAutoEnrollFinanced = Coverage.MIGRATION_AUTO_ENROLL_FINANCED,
        migrationDefaultDeductibleOption = Coverage.MIGRATION_AUTO_ENROLL_DEDUCTIBLE_OPTION,
        migrationDefaultDeductibleAmount = (Coverage.DEDUCTIBLES[Coverage.MIGRATION_AUTO_ENROLL_DEDUCTIBLE_OPTION] and Coverage.DEDUCTIBLES[Coverage.MIGRATION_AUTO_ENROLL_DEDUCTIBLE_OPTION].amount) or lenderRequirementDeductibleAmount(),
    }
end

function Coverage.getMarmurComplianceRows()
    local s = ensureState()
    local day = getCurrentDay()
    local rows = {}
    for id, vehicle in pairs(s.vehicles or {}) do
        if vehicle.financed == true and vehicle.ineligible ~= true then
            local violation, cause = financedViolationCause(s, vehicle, day)
            local rec = s.marmur.violations[id]
            if rec then rec = normalizeViolationRecord(rec, day) end
            table.insert(rows, {
                id = id,
                name = vehicle.name,
                insured = Coverage.isInsured(id),
                violation = violation,
                cause = cause,
                noticeCount = rec and (tonumber(rec.noticeCount) or 0) or 0,
                startDay = rec and (tonumber(rec.startDay) or 0) or 0,
                deadlineDay = rec and (tonumber(rec.deadlineDay) or 0) or 0,
                daysRemaining = rec and math.max(0, (tonumber(rec.deadlineDay) or day) - day) or Coverage.LENDER_COMPLIANCE_DAYS,
                defaulted = s.marmur.defaulted[id] == true,
                repossessionRequested = s.marmur.repossessionRequested[id] == true,
            })
        end
    end
    table.sort(rows, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return rows
end

function Coverage.auditMarmur(force)
    local s = ensureState()
    local day = getCurrentDay()
    if force ~= true and s.marmur.lastAuditDay == day then return false, 'Already audited today.' end
    s.marmur.lastAuditDay = day

    local q = Coverage.recalculate()
    local termExpired = (tonumber(s.policy.termEndDay) or 0) > 0 and day > (tonumber(s.policy.termEndDay) or 0)
    local installmentPastDue = s.policy.billingMode ~= 'pay_in_full' and (tonumber(s.policy.nextDueDay) or 0) > 0 and day > (tonumber(s.policy.nextDueDay) or 0)
    local premiumPastDue = termExpired or installmentPastDue

    s.policy.pastDue = premiumPastDue == true
    if premiumPastDue and q.financedCount > 0 then
        s.policy.lapsed = true
    end

    local noticesPosted = 0
    local defaultsOpened = 0
    local resolved = 0
    local bridgePending = false

    for id, vehicle in pairs(s.vehicles or {}) do
        if vehicle.financed == true and vehicle.ineligible ~= true then
            local isViolation, cause = financedViolationCause(s, vehicle, day)

            if isViolation then
                local rec = normalizeViolationRecord(s.marmur.violations[id], day)
                rec.lastCause = cause
                s.marmur.violations[id] = rec

                local daysOpen = math.max(0, day - (tonumber(rec.startDay) or day))
                local daysRemaining = math.max(0, (tonumber(rec.deadlineDay) or day) - day)
                local shouldNotice = false

                if (tonumber(rec.noticeCount) or 0) < Coverage.LENDER_NOTICE_MAX then
                    if (tonumber(rec.noticeCount) or 0) <= 0 then
                        shouldNotice = true
                    elseif day - (tonumber(rec.lastNoticeDay) or -9999) >= Coverage.LENDER_NOTICE_INTERVAL_DAYS then
                        shouldNotice = true
                    elseif day >= (tonumber(rec.deadlineDay) or day) and (tonumber(rec.lastNoticeDay) or -9999) ~= day then
                                                                                                       
                                                                                                      
                        shouldNotice = true
                    end
                end

                if shouldNotice then
                    local nextNoticeCount = math.min(Coverage.LENDER_NOTICE_MAX, (tonumber(rec.noticeCount) or 0) + 1)
                    if postMarmurReminder(vehicle, rec, cause, nextNoticeCount) then
                        rec.noticeCount = nextNoticeCount
                        rec.lastNoticeDay = day
                        local msg = 'Notice ' .. tostring(rec.noticeCount) .. '/3: ' .. vehicle.name .. ' is financed and must be insured under ' .. Coverage.POLICY_NAME .. ' with a deductible no higher than ' .. Coverage.formatMoney(lenderRequirementDeductibleAmount()) .. '. ' .. tostring(daysRemaining) .. ' day(s) remain before default review. Cause: ' .. cause .. '.'
                        addNotice(id, rec.noticeCount, msg)
                        addHistory('MARMUR_NOTICE', msg, 0, id)
                        noticesPosted = noticesPosted + 1
                    else
                        bridgePending = true
                    end
                end

                if day >= (tonumber(rec.deadlineDay) or day) and (tonumber(rec.noticeCount) or 0) >= Coverage.LENDER_NOTICE_MAX and s.marmur.defaulted[id] ~= true then
                    if postMarmurDefault(vehicle, rec, cause) then
                        s.marmur.defaulted[id] = true
                        s.marmur.repossessionRequested[id] = true
                        rec.defaultDay = day
                        local msg = 'Default review opened: ' .. vehicle.name .. ' remained out of lender-compliant insurance for ' .. tostring(Coverage.LENDER_COMPLIANCE_DAYS) .. ' day(s). Marmur repossession request submitted.'
                        addNotice(id, Coverage.LENDER_NOTICE_MAX, msg)
                        addHistory('MARMUR_DEFAULT', msg, 0, id)
                        defaultsOpened = defaultsOpened + 1
                    else
                        bridgePending = true
                    end
                end
            else
                if s.marmur.violations[id] ~= nil then
                    resolved = resolved + 1
                    addHistory('MARMUR_RESOLVED', vehicle.name .. ' is back in lender-compliant insurance. Cure window closed.', 0, id)
                end
                s.marmur.violations[id] = nil
                if s.marmur.defaulted[id] ~= true then
                    s.marmur.repossessionRequested[id] = nil
                end
            end
        else
            s.marmur.violations[id] = nil
            if s.marmur.defaulted[id] ~= true then s.marmur.repossessionRequested[id] = nil end
        end
    end

    if bridgePending then s.marmur.lastAuditDay = day - 1 end
    requestSave()
    local msg = 'Marmur audit complete.'
    if noticesPosted > 0 then msg = msg .. ' Notices posted: ' .. tostring(noticesPosted) .. '.' end
    if resolved > 0 then msg = msg .. ' Resolved: ' .. tostring(resolved) .. '.' end
    if defaultsOpened > 0 then msg = msg .. ' Defaults opened: ' .. tostring(defaultsOpened) .. '.' end
    return true, msg
end

function Coverage.refundRepairClaim(vehicleId, amount, reason)
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = id ~= '' and Coverage.getVehicle(id) or nil
    local refund = roundMoney(amount or Coverage.recalculate().deductibleAmount or 0)
    if refund > 0 then Wallet.add(refund) end
    addHistory('REPAIR_REFUND', (vehicle and vehicle.name or 'Vehicle') .. ' repair claim refunded: ' .. sanitize(reason or 'repair dispatch failed') .. '.', refund, id)
    requestSave()
    return true, 'Repair deductible refunded: ' .. Coverage.formatMoney(refund) .. '.'
end

function Coverage.recordAccident(vehicleId, atFault, severity)
    local s = ensureState()
    local id = resolveVehicleKey(s, vehicleId or '')
    local vehicle = id ~= '' and Coverage.getVehicle(id) or nil
    local severityScore = tonumber(severity) or 1
    if severityScore < 1 then severityScore = 1 end
    if severityScore > 3 then severityScore = 3 end
    local score = severityScore + (atFault == true and 1 or 0)
    if atFault == true then
        local stateRef = ensureState()
        addAtFaultSurcharge(stateRef, severityScore, 0)
        addHistory('RATE_SURCHARGE', (vehicle and vehicle.name or 'Vehicle') .. ' manual at-fault accident surcharge recorded.', 0, id)
    end
    recordIncident('accident', id, score, atFault == true, 0)
    addHistory('ACCIDENT', (vehicle and vehicle.name or 'Vehicle') .. ' accident recorded for Good Driver review.', 0, id)
    Coverage.recalculate()
    Coverage.saveNow()
    return true, 'Accident recorded. Good Driver status will update with the next quote.'
end

function Coverage.getGoodDriverStatus()
    local status = updateGoodDriverStatus(selectedCount())
    return status
end

function Coverage.getIncidentEvents(limit)
    local s = ensureState()
    ensureStats(s)
    local out = {}
    limit = limit or 12
    for i = 1, math.min(limit, #(s.stats.events or {})) do table.insert(out, s.stats.events[i]) end
    return out
end

function Coverage.getHistory(limit)
    local s = ensureState()
    local out = {}
    limit = limit or 20
    for i = 1, math.min(limit, #s.history) do table.insert(out, s.history[i]) end
    return out
end

function Coverage.getMarmurNotices(limit)
    local s = ensureState()
    local out = {}
    limit = limit or 12
    for i = 1, math.min(limit, #s.marmur.notices) do table.insert(out, s.marmur.notices[i]) end
    return out
end

local function applyPendingCollisionRerate()
    local s = ensureState()
    if not s.policy or s.policy.pendingCollisionRerate ~= true then return false end

    local vehicleId = tostring(s.policy.pendingCollisionRerateVehicleId or '')
    s.policy.pendingCollisionRerate = false
    s.policy.pendingCollisionRerateVehicleId = ''

    local billingMode = tostring(s.policy.billingMode or '')
    if billingMode == 'pay_in_full' or billingMode == 'pay_in_full_12' then
        return false
    end

    s.policy.acceptPendingSurchargePremium = true
    local q = Coverage.recalculate()
    s.policy.acceptPendingSurchargePremium = false
    s.policy.paymentDue = q.installmentAmount
    addHistory('RATE_ADJUSTMENT', 'Installment policy re-rated after at-fault collision activity. New payment: ' .. Coverage.formatMoney(q.installmentAmount) .. '.', q.installmentAmount, vehicleId)
    return true
end

function Coverage.saveNow()
    ensureState()
    applyPendingCollisionRerate()

                                                                              
                                                                                    
    local ok = Serializer.save(STATE_FILE, state)
    if not ok then
        mkdir(DATA_DIR)
        ok = Serializer.save(STATE_FILE, state)
    end
    if ok then
        saveRequested = false
        collisionSaveRequested = false
        collisionSaveRequestedAt = 0.0
    else
                                                                              
        saveRequested = true
    end
    return ok
end

function Coverage.flushSave(force)
    if saveRequested then return Coverage.saveNow() end

    if collisionSaveRequested then
        local now = coverageClockNow()
        local quietFor = (now > 0.0 and collisionSaveRequestedAt > 0.0) and (now - collisionSaveRequestedAt) or COLLISION_SAVE_QUIET_SECONDS
        if force == true or quietFor >= COLLISION_SAVE_QUIET_SECONDS then
            return Coverage.saveNow()
        end
    end

    return true
end

return Coverage
