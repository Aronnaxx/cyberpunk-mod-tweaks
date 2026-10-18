-- Vanguard Auto Mod Settings bridge (CET side).
-- r6/scripts/VanguardAutoOptions mirrors each Mod Settings value into a quest fact
-- (value + 1; 0 = not published yet, in which case stock behaviour applies).
local Opt = {}

local TTL = 0.5
local cache = {}

local function clock()
    local ok, t = pcall(os.clock)
    if ok and tonumber(t) then return t end
    return 0
end

local function readFact(name)
    local now = clock()
    local hit = cache[name]
    if hit and (now - hit.at) < TTL then return hit.v end

    local v = 0
    pcall(function()
        local qs = Game.GetQuestsSystem()
        if qs then v = tonumber(qs:GetFactStr(name)) or 0 end
    end)
    cache[name] = { at = now, v = v }
    return v
end

local function boolFact(name, default)
    local v = readFact(name)
    if v == 0 then return default end
    return v == 2
end

function Opt.insuranceEnabled() return boolFact('vao_insurance', true) end
function Opt.waivePremiums() return boolFact('vao_waive_premiums', false) end
function Opt.waiveDeductibles() return boolFact('vao_waive_deductibles', false) end
function Opt.autoRepairOnSummon() return boolFact('vao_auto_repair', true) end
function Opt.permanentLoss() return boolFact('vao_permanent_loss', true) end

function Opt.summonRepairFeeMultiplier()
    local v = readFact('vao_summon_fee_pct')
    if v == 0 then return 1.0 end
    return math.max(0, v - 1) / 100.0
end

-- Wallet.remove stand-in for the three charge kinds. A waived charge succeeds without
-- taking any money; everything else is the stock Wallet.remove.
function Opt.remove(Wallet, amount, kind)
    if kind == 'premium' and Opt.waivePremiums() then return true, Wallet.balance() end
    if kind == 'deductible' and Opt.waiveDeductibles() then return true, Wallet.balance() end
    return Wallet.remove(amount)
end

return Opt
