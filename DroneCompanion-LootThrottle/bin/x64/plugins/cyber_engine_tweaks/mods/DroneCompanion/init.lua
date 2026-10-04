local Cron = require("libs/Cron")
local GameSession = require("libs/GameSession")
local GameUI = require("libs/GameUI")

local G = {
  Cron = Cron,
  GameSession = GameSession,
  GameUI = GameUI,
  TDB = "DroneCompanion.",
  INSTANCES = 3,
}

G.CHASSIS = {
  { key = "Octant", pts = 2, name = "Octant", fly = true, dmg = 1.6, hp = 2.0,
    factions = {
      { key = "Militech",   name = "Militech",    base = "Character.militech_base_drone_octant" },
      { key = "Arasaka",    name = "Arasaka",     base = "Character.arasaka_base_drone_octant", weapon = "smart" },
      { key = "KangTao",    name = "Kang Tao",    base = "Character.kangtao_base_drone_octant" },
      { key = "TraumaTeam", name = "Trauma Team", base = "Character.trauma_team_base_drone_octant" },
      { key = "NCPD",       name = "NCPD",        base = "Character.prevention_unit_octant_drone" },
      { key = "BorderPatrol", name = "Border Patrol", base = "Character.max_border_drone_octant",
        appearance = "zetatech_octant_basic_border_patrol_01" },
    } },

  { key = "Wyvern", template = "dronecompanion\\characters\\dc_wyvern.ent", pts = 3, name = "Wyvern", fly = true, dmg = 1.3, hp = 3.0, weapon = "smart",
    factions = {
      { key = "Militech",   name = "Militech",   base = "Character.militech_base_drone_wyvern",
        appearance = "militech_wyvern__basic_militech_01" },
      { key = "Arasaka",    name = "Arasaka",    base = "Character.arasaka_base_drone_wyvern",
        appearance = "militech_wyvern__basic_arasaka_01" },
      { key = "KangTao",    name = "Kang Tao",   base = "Character.kangtao_base_drone_wyvern",
        appearance = "militech_wyvern__basic_militech_01" },
      { key = "NCPD",       name = "NCPD",       base = "Character.ncpd_base_drone_wyvern",
        appearance = "militech_wyvern__basic_militech_01" },
      { key = "Maelstrom",  name = "Maelstrom",  base = "Character.maelstrom_base_drone_wyvern",
        appearance = "militech_wyvern__basic_arasaka_01" },
      { key = "Wraiths",    name = "Wraiths",    base = "Character.wraiths_base_drone_wyvern",
        appearance = "militech_wyvern__basic_arasaka_01" },
      { key = "Aldecaldos", name = "Aldecaldos", base = "Character.aldecaldos_base_drone_wyvern",
        appearance = "militech_wyvern__basic_militech_01" },
      { key = "Barghest",   name = "Barghest",   base = "Character.kurtz_base_drone_wyvern",
        appearance = "militech_wyvern__basic_ep1_01" },
    } },
  { key = "Griffin", template = "dronecompanion\\characters\\dc_griffin.ent", pts = 2, name = "Griffin", fly = true, dmg = 1.3, hp = 2.0,
    factions = {
      { key = "Militech",  name = "Militech",  base = "Character.militech_base_drone_griffin",
        appearance = "militech_griffin__basic_griffin_arasaka_01" },
      { key = "KangTao",   name = "Kang Tao",  base = "Character.kangtao_base_drone_griffin",
        appearance = "militech_griffin__basic_griffin_kangtao_01" },
      { key = "Maelstrom", name = "Maelstrom", base = "Character.maelstrom_base_drone_griffin",
        appearance = "militech_griffin__basic_griffin_arasaka_01" },
      { key = "NUSA",      name = "NUSA",      base = "Character.q301_shuttle_fs_griffin",
        appearance = "nusa_griffin__basic_griffin_nusa_01" },
      { key = "Arasaka",   name = "Arasaka",   base = "Character.sts_ep1_12_voodooboy_base_drone_griffin",
        appearance = "militech_griffin__basic_griffin_arasaka_01" },
    } },

  { key = "Bombus", pts = 1, name = "Bombus", fly = true, dmg = 1.2, hp = 2.0,
    reaction = "ReactionPresets.Mechanical_Aggressive",
    factions = {
      { key = "Militech",   name = "Militech",   base = "Character.militech_base_drone_bombus" },
      { key = "KangTao",    name = "Kang Tao",   base = "Character.kangtao_base_drone_bombus" },
      { key = "NCPD",       name = "NCPD",       base = "Character.ncpd_base_drone_bombus" },
      { key = "Aldecaldos", name = "Aldecaldos", base = "Character.aldecaldos_base_drone_bombus" },
      { key = "Barghest",   name = "Barghest",   base = "Character.kurtz_base_drone_bombus" },
      { key = "NetWatch",   name = "NetWatch",   base = "Character.cvi_netwatch_drone_bombus_medium",
        appearance = "zetatech_bombus__basic_surveillance_netwatch_01" },
      { key = "Delamain",   name = "Delamain",   base = "Character.sq025_delamain_drone_bombus",
        appearance = "zetatech_bombus__basic_delamain_drone_01" },
    } },
  { key = "Minotaur", pts = 4, name = "Minotaur", fly = false, dmg = 2.0, paintByRecord = true,
    factions = {
      { key = "Militech", name = "Militech", base = "Character.militech_base_minotaur" },
      { key = "Arasaka",  name = "Arasaka",  base = "Character.arasaka_base_minotaur" },
      { key = "NCPD",     name = "NCPD",     base = "Character.ncpd_base_minotaur" },
      { key = "Barghest", name = "Barghest", base = "Character.kurtz_base_minotaur" },
    } },

  { key = "Android", template = "dronecompanion\\characters\\dc_android.ent", pts = 2, name = "Android", fly = false, dmg = 1.5, hp = 2.0,
    factions = {
      { key = "NCPD",        name = "NCPD",         base = "Character.prevention_android_rifle_ma",
        appearance = "corpo__android_ma_ncpd_droid__lvl1_01" },
      { key = "Militech",    name = "Militech",     base = "Character.militech_android_android2_crusher_ma",
        appearance = "corpo__android_ma_militech_droid__lvl2_01" },
      { key = "Arasaka",     name = "Arasaka",      base = "Character.arasaka_android_android2_shingen_ma",
        appearance = "corpo__android_ma_arasaka_droid__lvl2_01" },
      { key = "KangTao",     name = "Kang Tao",     base = "Character.kangtao_android_android2_dian_ma",
        appearance = "corpo__android_ma_kang_tao_droid__lvl2_01" },
      { key = "Maelstrom",   name = "Maelstrom",    base = "Character.maelstrom_android_android2_copperhead_ma",
        appearance = "gang__android_ma_maelstrom_droid__lvl2_01" },
      { key = "Wraiths",     name = "Wraiths",      base = "Character.wraiths_android_android2_pulsar_ma",
        appearance = "gang__android_ma_wraith_droid__lvl1_01" },
      { key = "Scavengers",  name = "Scavengers",   base = "Character.scavenger_android_android2_pulsar_ma",
        appearance = "gang__android_ma_scavenger_droid__lvl2_01" },
      { key = "SixthStreet", name = "Sixth Street", base = "Character.sixthstreet_android_android2_saratoga_ma",
        appearance = "gang__android_ma_6th_street_droid_lvl1_01" },
      { key = "Security",    name = "Security",     base = "Character.security_android_android2_ajax_ma",
        appearance = "corpo__android_ma_militech_droid__lvl2_01" },
      { key = "NUSA",        name = "NUSA",         base = "Character.q301_shuttle_fs_android_02",
        appearance = "corpo__android_ma_nusa_droid__lvl2_01" },
      { key = "MaxTac",      name = "MaxTac",       base = "Character.prevention_android_rifle_ma",
        appearance = "corpo__android_ma_maxtac_droid__lvl2_01" },
      { key = "Barghest",    name = "Barghest",     base = "Character.prevention_dogtown_droid_ma",
        appearance = "corpo__android_ma_kurtz_droid__lvl2_02" },
    } },

  { key = "Flathead", pts = 1, name = "Flathead (static)", fly = false, hp = 4.0,
    statsFrom = "Character.militech_base_drone_bombus", escort = true, static = true,
    factions = {
      { key = "Militech", name = "Militech", base = "Character.q003_spiderbot" },
    } },

  { key = "Chimera", pts = 5, name = "Chimera (static)", fly = false, hp = 2.0,
    statsFrom = "Character.militech_base_minotaur", escort = true, static = true,
    factions = {
      { key = "Militech", name = "Militech", base = "Character.main_boss_chimera" },
    } },

  { key = "Cerberus", pts = 4, name = "Cerberus (escort)", fly = false, hp = 2.0,
    statsFrom = "Character.militech_base_minotaur", escort = true,
    factions = {
      { key = "Arasaka", name = "Arasaka", base = "Character.Cerberus_NPC_Base" },
    } },
}

local function localized(key, english)
  local text = G.STR and G.STR[key]
  if not text or text == key then return english end
  return text
end

local function localName(entry, prefix)
  local english, key = entry.name, prefix .. entry.key:lower()
  entry.name = nil
  setmetatable(entry, { __index = function(_, field)
    if field == "name" then return localized(key, english) end
  end })
end

G.MODELS = {}
for _, ch in ipairs(G.CHASSIS) do
  localName(ch, "chassis_")
  for _, fac in ipairs(ch.factions) do
    localName(fac, "faction_")
    table.insert(G.MODELS, setmetatable({
      chassis = ch.key, faction = fac.key,
      key = ch.key .. fac.key,
      base = fac.base,
      fly = ch.fly, dmg = ch.dmg, hp = ch.hp,
      reaction = ch.reaction, statsFrom = ch.statsFrom, escort = ch.escort,
      static = ch.static,
      weapon = fac.weapon or ch.weapon,
      appearance = fac.appearance,
      template = ch.template,
      paintByRecord = ch.paintByRecord,
    }, { __index = function(_, field)
      if field == "name" then
        return string.format(localized("model_name", "%s %s"), fac.name, ch.name)
      end
    end }))
  end
end

function G.recordId(model, instance)
  return G.TDB .. model.key .. instance
end

function G.chassisOf(key)
  for _, ch in ipairs(G.CHASSIS) do
    if ch.key == key then return ch end
  end
end

function G.modelOf(recordStr)
  if G.hijack and G.hijack.is(recordStr) then return G.hijack.modelOf(recordStr) end
  local key = tostring(recordStr):gsub("^" .. G.TDB, ""):gsub("%d+$", "")
  for _, model in ipairs(G.MODELS) do
    if model.key == key then return model end
  end
  return nil
end

G.FAMILIES = {}
for _, ch in ipairs(G.CHASSIS) do
  table.insert(G.FAMILIES, { fam = ch.key, name = ch.name })
end

function G.familyOf(key)
  for _, f in ipairs(G.FAMILIES) do
    if key:find(f.fam, 1, true) then return f.fam end
  end
  return nil
end

local function skinList(entries)
  local out = {}
  for _, e in ipairs(entries) do
    out[#out + 1] = { app = e[1], label = e[2], n = e[3] }
  end
  return out
end

local function numbered(prefix, label, count, fmt)
  local out = {}
  for i = 1, count do
    out[#out + 1] = { string.format(fmt, prefix, i), label, i }
  end
  return out
end

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, e in ipairs(list) do out[#out + 1] = e end
  end
  return out
end

G.SKINS = {
  Octant = skinList({
    { "zetatech_octant_basic_militech_01", "skin_militech" },
    { "zetatech_octant_basic_arasaka_01", "skin_arasaka" },
    { "zetatech_octant_basic_kang_tao_01", "skin_kangtao" },
    { "zetatech_octant_basic_traumateam_01", "skin_trauma" },
    { "zetatech_octant_basic_border_patrol_01", "skin_border" },
  }),
  Wyvern = skinList({
    { "militech_wyvern__basic_militech_01", "skin_militech" },
    { "militech_wyvern__basic_arasaka_01", "skin_arasaka" },
    { "militech_wyvern__basic_ep1_01", "skin_barghest", 1 },
    { "militech_wyvern__basic_ep1_02", "skin_barghest", 2 },
    { "militech_wyvern__basic_muamar_01", "skin_muamar", 1 },
    { "militech_wyvern__basic_muamar_02", "skin_muamar", 2 },
  }),
  Griffin = skinList({
    { "militech_griffin__basic_griffin_arasaka_01", "skin_arasaka" },
    { "militech_griffin__basic_griffin_kangtao_01", "skin_kangtao" },
    { "militech_griffin__basic_griffin_police_01", "skin_ncpd" },
    { "militech_griffin__basic_griffin_q304", "skin_barghest" },
    { "nusa_griffin__basic_griffin_nusa_01", "skin_nusa" },
  }),
  Bombus = skinList({
    { "zetatech_bombus__basic_delamain_drone_01", "skin_delamain" },
    { "zetatech_bombus__basic_nanny_drone_blue", "skin_nanny_blue" },
    { "zetatech_bombus__basic_nanny_drone_violet", "skin_nanny_violet" },
    { "zetatech_bombus__basic_nanny_drone_white", "skin_nanny_white" },
    { "zetatech_bombus__basic_surveillance_drone_01", "skin_surveillance" },
    { "zetatech_bombus__basic_surveillance_netwatch_01", "skin_netwatch" },
    { "zetatech_bombus__basic_surveillance_police_01", "skin_ncpd" },
    { "zetatech_bombus__basic_surveillance_service_01", "skin_service" },
    { "zetatech_bombus__basic_ep1_01", "skin_barghest" },
  }),
  Minotaur = skinList({
    { "mch_003__minotaur_militech_01", "skin_militech" },
    { "mch_003__minotaur_arasaka_01", "skin_arasaka" },
    { "mch_003__minotaur_police_01", "skin_ncpd" },
    { "mch_003__minotaur_kurt", "skin_barghest" },
  }),
  Android = skinList(concat({
    { "corpo__android_ma_arasaka_droid__lvl2_01", "skin_arasaka" },
    { "corpo__android_ma_militech_droid__lvl2_01", "skin_militech" },
    { "corpo__android_ma_ncpd_droid__lvl1_01", "skin_ncpd" },
    { "corpo__android_ma_kang_tao_droid__lvl2_01", "skin_kangtao" },
    { "gang__android_ma_kangtao_droid__lvl2_01", "skin_kangtao_gang" },
    { "corpo__android_ma_maxtac_droid__lvl2_01", "skin_maxtac" },
    { "corpo__android_ma_nusa_droid__lvl2_01", "skin_nusa" },
    { "corpo__android_ma__q305__nusa_droid_border", "skin_nusa_border" },
    { "corpo__android_ma_kurtz_droid__lvl2_01", "skin_barghest", 1 },
    { "corpo__android_ma_kurtz_droid__lvl2_02", "skin_barghest", 2 },
    { "corpo__android_ma_kurtz_droid__lvl2_03", "skin_barghest", 3 },
  },
    numbered("gang__android_ma_maelstrom_droid__lvl2", "skin_maelstrom", 4, "%s_%02d"),
    numbered("gang__android_ma_wraith_droid__lvl1", "skin_wraith", 5, "%s_%02d"),
    numbered("gang__android_ma_scavenger_droid__lvl2", "skin_scavenger", 6, "%s_%02d"),
    numbered("gang__android_ma_6th_street_droid_lvl1", "skin_sixth", 6, "%s_%02d"),
    numbered("corpo__android_ma__ow__droid_cz", "skin_combatzone", 5, "%s_%02d"),
    numbered("corpo__android_ma__sq011__kerry_bodyguard", "skin_kerry", 5, "%s_%02d"),
  {
    { "corpo__android_ma__sts_ep1_12__voodoo_droid_01", "skin_voodoo", 1 },
    { "corpo__android_ma__sts_ep1_12__voodoo_droid_02", "skin_voodoo", 2 },
    { "corpo__android_ma__sts_ep1_12__voodoo_boss", "skin_voodoo_boss" },
    { "corpo__android_ma__q306__orbital_air_droid_01", "skin_orbital" },
    { "corpo__android_ma_casino_droid_01", "skin_casino" },
    { "corpo__android_ma__ow__droid_vendor_01", "skin_vendor" },
    { "corpo__android_ma__q303__barmaid_droid", "skin_maid" },
    { "corpo__android_ma__sts_ep1_13__communication_droid", "skin_comm" },
    { "corpo__android_ma__mq060__nitro_youth_droid", "skin_nitro" },
    { "corpo__android_ma__mq060__nitro_youth_communication_droid", "skin_nitro_comm" },
  })),
}

function G.skinsFor(model)
  if not model then return nil end
  return G.SKINS[model.chassis]
end

function G.shardId(fam)
  return G.TDB .. "Shard" .. fam
end

G.POINTS_BASE = 3

function G.giveItem(id, count)
  local given = false
  pcall(function()
    Game.AddToInventory(id, count or 1)
    given = true
  end)
  return given
end

G.MOVED_BINDS = {
  ["tab_commands|2|toggle|hud"] = "tab_settings|2|toggle|hud",
  ["tab_commands|2|toggle|minimap"] = "tab_settings|2|toggle|minimap",
  ["tab_commands|1|toggle|lookprompt"] = "tab_settings|2|toggle|lookprompt",
  ["tab_commands|1|toggle|camhacks"] = "tab_commands|2|toggle|camhacks",
  ["tab_commands|1|toggle|androidhacks"] = "tab_commands|2|toggle|androidhacks",
  ["tab_commands|1|toggle|immersive"] = "tab_drones|1|toggle|immersive",
  ["tab_commands|1|toggle|rigger"] = "tab_drones|1|toggle|rigger",
}

function G.hackOffList()
  local list = {}
  for key in pairs(G.settings.hacksOff or {}) do list[#list + 1] = key end
  table.sort(list)
  return list
end

function G.takeItem(id, count)
  local taken = false
  pcall(function()
    local player = Game.GetPlayer()
    local item = ItemID.FromTDBID(TweakDBID.new(id))
    local ts = Game.GetTransactionSystem()
    local n = math.min(count or 1, ts:GetItemQuantity(player, item))
    taken = n > 0 and ts:RemoveItem(player, item, n)
  end)
  return taken == true
end

function G.capacityId()
  return G.TDB .. "CapacityModule"
end

function G.pointsOf(fam)
  for _, ch in ipairs(G.CHASSIS) do
    if ch.key == fam then return ch.pts or 0 end
  end
  return 0
end

G.tuning = require("tuning")(G)

G.settings = { immersive = true, autoAbilities = true, explosive = false,
  loadout = "default", hud = true, spawnBehind = false, matchFacing = false,
  minimap = true, rigger = true, hudscale = 1.0, hudx = 10.0, hudy = 140.0,
  androidHacks = false, camHacks = true, theme = "corpo", mechArmor = false, androidHeads = false,
  autoHolster = false, stealthGhost = true, scanFocus = true, androidLoot = true, skins = {},
  dronesImmortal = false,
  spawnMuted = false, protectV = false, recon = false,
  autoSummon = 0, lookPrompt = true, hijackBosses = false, menusub = {}, opengroups = {}, enabled = true, notify = true,
  menubg = 0, menukey = "IK_F8", padcombo = "LB+X", padopen = true, squadwin = false, hotkeys = {}, padbinds = {},
  descbox = true, menuseen = false, langpick = "auto" }

G.DEFAULTS = { screenscale = 1.0 }
for k, v in pairs(G.settings) do
  if type(v) ~= "table" then G.DEFAULTS[k] = v end
end

G.UI_SCALE_MIN, G.UI_SCALE_MAX, G.UI_SCALE_STEP = 0.7, 2.0, 0.05
G.HUD_POS = { hudx = { 0.0, 3600.0, 10.0 }, hudy = { 0.0, 2000.0, 140.0 } }

function G.clampHudPos(key, v)
  local lim = G.HUD_POS[key]
  if type(v) ~= "number" then return lim[3] end
  return math.min(math.max(v, lim[1]), lim[2])
end

function G.pushPhoneChoices()
  local player = Game.GetPlayer()
  if not player or not G.squad then return end
  local parts = {}
  for slot = 1, G.squad.SLOTS do
    if G.squad.presets[slot] then
      parts[#parts + 1] = "preset" .. slot .. "=" .. string.format(G.STR.phone_summon, G.squad.presetLabel(slot))
    end
  end
  parts[#parts + 1] = "regroup=" .. G.STR.phone_regroup
  parts[#parts + 1] = "holster=" .. G.STR.phone_holster
  parts[#parts + 1] = "dismissall=" .. G.STR.phone_dismiss
  local encoded = table.concat(parts, "|")
  pcall(function() player:DCSetPhoneChoices(encoded) end)
end

function G.clampScale(value)
  value = tonumber(value) or 1
  if value < G.UI_SCALE_MIN then value = G.UI_SCALE_MIN end
  if value > G.UI_SCALE_MAX then value = G.UI_SCALE_MAX end
  return math.floor(value / G.UI_SCALE_STEP + 0.5) * G.UI_SCALE_STEP
end


function G.skinsEncoded()
  local parts = {}
  for key, app in pairs(G.settings.skins or {}) do
    parts[#parts + 1] = key .. "=" .. app
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

function G.menuSubEncoded()
  local parts = {}
  for id, i in pairs(G.settings.menusub or {}) do parts[#parts + 1] = id .. "=" .. i end
  table.sort(parts)
  return table.concat(parts, ",")
end

function G.openGroupsEncoded()
  local parts = {}
  for key in pairs(G.settings.opengroups or {}) do parts[#parts + 1] = key end
  table.sort(parts)
  return table.concat(parts, ";")
end

local function pairsEncoded(map)
  local parts = {}
  for key, value in pairs(map or {}) do parts[#parts + 1] = key .. "=" .. value end
  table.sort(parts)
  return table.concat(parts, ";")
end

function G.saveSettings()
  local f = io.open("settings.json", "w")
  if not f then return end
  local parts = {
    string.format('"immersive":%s', tostring(G.settings.immersive == true)),
    string.format('"autoAbilities":%s', tostring(G.settings.autoAbilities == true)),
    string.format('"explosive":%s', tostring(G.settings.explosive == true)),
    string.format('"loadout":"%s"', G.settings.loadout or "default"),
    string.format('"hud":%s', tostring(G.settings.hud == true)),
    string.format('"spawnBehind":%s', tostring(G.settings.spawnBehind == true)),
    string.format('"matchFacing":%s', tostring(G.settings.matchFacing == true)),
    string.format('"minimap":%s', tostring(G.settings.minimap == true)),
    string.format('"rigger":%s', tostring(G.settings.rigger == true)),
    string.format('"androidHacks":%s', tostring(G.settings.androidHacks == true)),
    string.format('"camHacks":%s', tostring(G.settings.camHacks == true)),
    string.format('"mechArmor":%s', tostring(G.settings.mechArmor == true)),
    string.format('"androidHeads":%s', tostring(G.settings.androidHeads == true)),
    string.format('"autoHolster":%s', tostring(G.settings.autoHolster == true)),
    string.format('"stealthGhost":%s', tostring(G.settings.stealthGhost == true)),
    string.format('"scanFocus":%s', tostring(G.settings.scanFocus == true)),
    string.format('"androidLoot":%s', tostring(G.settings.androidLoot == true)),
    string.format('"dronesImmortal":%s', tostring(G.settings.dronesImmortal == true)),
    string.format('"spawnMuted":%s', tostring(G.settings.spawnMuted == true)),
    string.format('"protectV":%s', tostring(G.settings.protectV == true)),
    string.format('"recon":%s', tostring(G.settings.recon == true)),
    string.format('"lookPrompt":%s', tostring(G.settings.lookPrompt ~= false)),
    string.format('"hijackBosses":%s', tostring(G.settings.hijackBosses == true)),
    string.format('"hacksOff":"%s"', table.concat(G.hackOffList(), ",")),
    string.format('"enabled":%s', tostring(G.settings.enabled ~= false)),
    string.format('"notify":%s', tostring(G.settings.notify ~= false)),
    string.format('"menubg":%d', G.settings.menubg or 0),
    string.format('"menukey":"%s"', G.settings.menukey or "IK_F8"),
    string.format('"padcombo":"%s"', G.settings.padcombo or "LB+X"),
    string.format('"padopen":%s', tostring(G.settings.padopen ~= false)),
    string.format('"descbox":%s', tostring(G.settings.descbox ~= false)),
    string.format('"menuseen":%s', tostring(G.settings.menuseen == true)),
    string.format('"langpick":"%s"', G.settings.langpick or "auto"),
    string.format('"hotkeys":"%s"', pairsEncoded(G.settings.hotkeys)),
    string.format('"padbinds":"%s"', pairsEncoded(G.settings.padbinds)),
    string.format('"menupos":"%s"', G.settings.menupos and (G.settings.menupos.x .. "," .. G.settings.menupos.y) or ""),
    string.format('"squadwin":%s', tostring(G.settings.squadwin == true)),
    string.format('"squadpos":"%s"', G.settings.squadpos and (G.settings.squadpos.x .. "," .. G.settings.squadpos.y) or ""),
    string.format('"menutab":"%s"', G.settings.menutab or ""),
    string.format('"selected":"%s"', G.ui and G.MODELS[G.ui.selectedIndex].key or G.settings.selected or ""),
    string.format('"menusub":"%s"', G.menuSubEncoded()),
    string.format('"opengroups":"%s"', G.openGroupsEncoded()),
    string.format('"skins":"%s"', G.skinsEncoded()),
    string.format('"theme":"%s"', G.settings.theme or "corpo"),
    string.format('"hudscale":%.2f', G.settings.hudscale or 1.0),
    string.format('"hudx":%.0f', G.settings.hudx or 10.0),
    string.format('"hudy":%.0f', G.settings.hudy or 140.0),
    string.format('"screenscale":%.2f', G.settings.screenscale or 1.0),
    string.format('"autoSummon":%d', G.settings.autoSummon or 0),
    '"acqv2":true',
  }
  for _, key in ipairs(G.tuning.KEYS) do
    table.insert(parts, string.format('"g_%s":%.3f', key, G.tuning.get(key)))
  end
  f:write("{" .. table.concat(parts, ",") .. "}")
  f:close()
end

local function loadSettings()
  local f = io.open("settings.json", "r")
  if not f then return end
  local raw = f:read("*a") or ""
  f:close()
  G.settings.immersive = raw:find('"immersive":false', 1, true) == nil
  G.settings.autoAbilities = raw:find('"autoAbilities":false', 1, true) == nil
  G.settings.explosive = raw:find('"explosive":true', 1, true) ~= nil
  G.settings.loadout = raw:match('"loadout":"([^"]+)"') or "default"
  G.settings.hud = raw:find('"hud":false', 1, true) == nil
  G.settings.spawnBehind = raw:find('"spawnBehind":true', 1, true) ~= nil
  G.settings.matchFacing = raw:find('"matchFacing":true', 1, true) ~= nil
  G.settings.minimap = raw:find('"minimap":false', 1, true) == nil
  G.settings.rigger = raw:find('"rigger":false', 1, true) == nil
  G.settings.androidHacks = raw:find('"androidHacks":true', 1, true) ~= nil
  G.settings.camHacks = raw:find('"camHacks":false', 1, true) == nil
  G.settings.mechArmor = raw:find('"mechArmor":true', 1, true) ~= nil
  G.settings.androidHeads = raw:find('"androidHeads":true', 1, true) ~= nil
  G.settings.autoHolster = raw:find('"autoHolster":true', 1, true) ~= nil
  G.settings.stealthGhost = raw:find('"stealthGhost":false', 1, true) == nil
  G.settings.scanFocus = raw:find('"scanFocus":false', 1, true) == nil
  G.settings.androidLoot = raw:find('"androidLoot":false', 1, true) == nil
  G.settings.dronesImmortal = raw:find('"dronesImmortal":true', 1, true) ~= nil
  G.settings.spawnMuted = raw:find('"spawnMuted":true', 1, true) ~= nil
  G.settings.protectV = raw:find('"protectV":true', 1, true) ~= nil
  G.settings.recon = raw:find('"recon":true', 1, true) ~= nil
  G.settings.lookPrompt = raw:find('"lookPrompt":false', 1, true) == nil
  G.settings.hijackBosses = raw:find('"hijackBosses":true', 1, true) ~= nil
  G.settings.hacksOff = {}
  for key in (raw:match('"hacksOff":"([%a,]*)"') or ""):gmatch("%a+") do G.settings.hacksOff[key] = true end
  G.settings.enabled = raw:find('"enabled":false', 1, true) == nil
  G.settings.notify = raw:find('"notify":false', 1, true) == nil
  G.settings.menubg = math.min(math.max(tonumber(raw:match('"menubg":(%d+)')) or 0, 0), 6)
  G.settings.menukey = raw:match('"menukey":"(IK_[%w_]+)"') or "IK_F8"
  G.settings.padcombo = raw:match('"padcombo":"([^"]+)"') or "LB+X"
  G.settings.padopen = raw:find('"padopen":false', 1, true) == nil
  G.settings.descbox = raw:find('"descbox":false', 1, true) == nil
  G.settings.menuseen = raw:find('"menuseen":true', 1, true) ~= nil
  G.settings.langpick = raw:match('"langpick":"(%a+)"') or "auto"
  G.settings.hotkeys = {}
  for bind, key in (raw:match('"hotkeys":"([^"]*)"') or ""):gmatch("([^;=]+)=(IK_[%w_]+)") do
    G.settings.hotkeys[G.MOVED_BINDS[bind] or bind] = key
  end
  G.settings.padbinds = {}
  for id, combo in (raw:match('"padbinds":"([^"]*)"') or ""):gmatch("(%w+)=([^;]*)") do
    G.settings.padbinds[id] = combo
  end
  local mx, my = (raw:match('"menupos":"([^"]*)"') or ""):match("^(%-?%d+),(%-?%d+)$")
  G.settings.menupos = mx and { x = tonumber(mx), y = tonumber(my) } or nil
  G.settings.squadwin = raw:find('"squadwin":true', 1, true) ~= nil
  local sx, sy = (raw:match('"squadpos":"([^"]*)"') or ""):match("^(%-?%d+),(%-?%d+)$")
  G.settings.squadpos = sx and { x = tonumber(sx), y = tonumber(sy) } or nil
  G.settings.menutab = raw:match('"menutab":"([%w_]+)"')
  G.settings.selected = raw:match('"selected":"([%w_]+)"')
  G.settings.menusub = {}
  for id, i in (raw:match('"menusub":"([^"]*)"') or ""):gmatch("([%w_]+)=(%d+)") do
    G.settings.menusub[id] = tonumber(i)
  end
  G.settings.opengroups = {}
  for key in (raw:match('"opengroups":"([^"]*)"') or ""):gmatch("[^;]+") do
    G.settings.opengroups[key] = true
  end
  G.settings.skins = {}
  for key, app in (raw:match('"skins":"([^"]*)"') or ""):gmatch("([%w%.]+)=([%w_]+)") do
    G.settings.skins[key] = app
  end
  G.settings.theme = raw:match('"theme":"(%a+)"') or "corpo"
  G.settings.hudscale = G.clampScale(raw:match('"hudscale":([%d%.]+)') or 1.0)
  G.settings.hudx = G.clampHudPos("hudx", tonumber(raw:match('"hudx":([%d%.]+)')))
  G.settings.hudy = G.clampHudPos("hudy", tonumber(raw:match('"hudy":([%d%.]+)')))
  G.settings.screenscale = G.clampScale(raw:match('"screenscale":([%d%.]+)') or 1.0)
  G.settings.autoSummon = math.min(math.max(tonumber(raw:match('"autoSummon":(%d+)')) or 0, 0), 5)
  for _, key in ipairs(G.tuning.KEYS) do
    local v = tonumber(raw:match('"g_' .. key .. '":([%-%d%.]+)'))
    if v then G.tuning.global[key] = G.tuning.clamp(key, v) end
  end
  if raw:find('"acqv2":true', 1, true) == nil then
    G.settings.immersive = true
    G.settings.rigger = true
  end
end
loadSettings()
G.INSTANCES = G.tuning.LIMITS.instances[2]

local BACKUP_FILE = "settings.backup.json"
local SQUAD_BACKUP_FILE = "squad.backup.json"

local function writeSquadBackup(stamp)
  if not G.squad or not G.perks then return false end
  local data = { backupat = stamp, perks = G.perks.save(), kills = G.squad.kills, deaths = G.squad.deaths,
    squad = G.squad.save() }
  local ok, encoded = pcall(function() local s = json.encode(data) return s end)
  if not ok or type(encoded) ~= "string" then return false end
  local f = io.open(SQUAD_BACKUP_FILE, "w")
  if not f then return false end
  f:write(encoded)
  f:close()
  return true
end

local function readSquadBackup()
  local f = io.open(SQUAD_BACKUP_FILE, "r")
  if not f then return nil end
  local raw = f:read("*a") or ""
  f:close()
  local ok, data = pcall(function() local d = json.decode(raw) return d end)
  if ok and type(data) == "table" then return data end
  return nil
end

function G.restoreSquadBackup()
  local data = readSquadBackup()
  if not data or not G.squad or not G.perks then return false end
  G.perks.load(data.perks)
  G.squad.kills = type(data.kills) == "table" and data.kills or {}
  G.squad.deaths = type(data.deaths) == "table" and data.deaths or {}
  G.squad.load(data.squad)
  return true
end

function G.backupInfo()
  local f = io.open(BACKUP_FILE, "r")
  if not f then return nil end
  local raw = f:read("*a") or ""
  f:close()
  return raw:match('"backupat":"([^"]+)"') or "?"
end

function G.backupSettings()
  G.saveSettings()
  local f = io.open("settings.json", "r")
  if not f then return false end
  local raw = f:read("*a") or ""
  f:close()
  local out = io.open(BACKUP_FILE, "w")
  if not out then return false end
  local stamp = os.date("%Y-%m-%d %H:%M")
  out:write('{"backupat":"' .. stamp .. '",' .. raw:sub(2))
  out:close()
  writeSquadBackup(stamp)
  return true
end

function G.restoreSettings()
  local f = io.open(BACKUP_FILE, "r")
  if not f then return false end
  local raw = f:read("*a") or ""
  f:close()
  local out = io.open("settings.json", "w")
  if not out then return false end
  out:write(raw)
  out:close()
  loadSettings()
  for i, model in ipairs(G.MODELS) do
    if model.key == G.settings.selected then G.ui.selectedIndex = i end
  end
  G.saveSettings()
  G.applySettings()
  G.onLanguageChanged()
  G.restoreSquadBackup()
  if G.menu and G.menu.push then pcall(G.menu.push) end
  return true
end

function G.applySettings()
  G.tuning.commit()
  if G.records then
    G.records.applyMechArmor()
    G.records.applyAndroidHeads()
    for _, model in ipairs(G.MODELS) do
      if model.chassis == "Android" then G.records.applyLoadout(model, G.settings.loadout) end
    end
  end
  if G.squad then G.squad.hudRefresh() end
  if G.input then G.input.reload() end
  if G.inkmenu then G.inkmenu.sendCombo() end
end

function G.resetAll()
  G.backupSettings()
  for key, value in pairs(G.DEFAULTS) do G.settings[key] = value end
  for key, value in pairs(G.settings) do
    if type(value) == "table" then G.settings[key] = {} end
  end
  G.settings.menupos, G.settings.menutab, G.settings.selected, G.settings.squadpos = nil, nil, nil, nil
  G.ui.selectedIndex = 1
  G.tuning.global = {}
  G.saveSettings()
  G.applySettings()
  G.onLanguageChanged()
end

function G.setEnabled(on)
  G.settings.enabled = on
  G.saveSettings()
  if not on then
    if G.dronecam.active then G.dronecam.stop() end
    G.companion.stashed = nil
    G.companion.dismissAll(true)
    G.prompt.set(nil)
  end
  G.squad.lastHud = nil
end

local strCache = {}

function G.clearStrCache()
  strCache = {}
end

G.LANGS = { "en", "pt", "es", "fr", "de", "ru", "zh", "pl" }
G.LANG_NAMES = { en = "English", pt = "Portuguese (Brazil)", es = "Spanish", fr = "French", de = "German",
  ru = "Russian", zh = "Chinese (Simplified)", pl = "Polish" }
local NEEDS_GAME_FONT = { ru = { "ru", "ua" }, zh = { "zh-cn" } }

local function gameLangCode()
  local ok, value = pcall(function()
    return Game.GetSettingsSystem():GetVar("/language", "OnScreen"):GetValue()
  end)
  if not ok or not value then return "" end
  return (type(value) == "string" and value or NameToString(value)):lower()
end

function G.langCode()
  local pick = G.settings.langpick
  if not G.LANG_NAMES[pick or ""] then return nil end
  local need = NEEDS_GAME_FONT[pick]
  if not need then return pick end
  local game = gameLangCode()
  for _, prefix in ipairs(need) do
    if game:sub(1, #prefix) == prefix then return pick end
  end
  return "en"
end

local function packText(player, code, key)
  local text
  pcall(function() text = player:DCGetText(code, key) end)
  return (type(text) == "string" and text ~= "") and text or nil
end

function G.text(key)
  local code = G.langCode()
  if code then
    local player
    pcall(function() player = Game.GetPlayer() end)
    if player then
      local text = packText(player, code, key) or (code ~= "en" and packText(player, "en", key))
      if text then return text, true end
    end
  end
  local text
  pcall(function() text = Game.GetLocalizedTextByKey(CName.new(key)) end)
  if not text or text == "" or text:find("Mod-DroneCompanion", 1, true) then return nil end
  return text, code == nil
end

G.STR = setmetatable({}, { __index = function(_, key)
  local hit = strCache[key]
  if hit then return hit end
  local text, stable = G.text("Mod-DroneCompanion-L-" .. key)
  if not text then return key end
  if stable then strCache[key] = text end
  return text
end })

function G.pushLang(player)
  pcall(function()
    player = player or Game.GetPlayer()
    if player then player:DCSetLang(G.langCode() or "") end
  end)
end

function G.onLanguageChanged()
  G.clearStrCache()
  G.pushLang()
  if G.inkmenu then G.inkmenu.countsDirty = true end
  if G.squad then G.squad.hudRefresh() end
  G.pushPhoneChoices()
end

function G.setLangPick(code)
  G.settings.langpick = code
  G.saveSettings()
  G.onLanguageChanged()
end

local lastUiLang
function G.syncLanguage()
  local ok, uiLang = pcall(function()
    local player = Game.GetPlayer()
    return player and player:DCUiLanguage() or nil
  end)
  if ok and type(uiLang) == "string" and uiLang ~= "" and uiLang ~= lastUiLang then
    lastUiLang = uiLang
    G.onLanguageChanged()
  end
end

local trailFile = io.open("trail.log", "w")
if trailFile then trailFile:close() end

function G.log(text)
  print("[DroneCompanion] " .. text)
  if spdlog then spdlog.info(text) end
  local f = io.open("trail.log", "a")
  if not f then return end
  f:write(os.date("%H:%M:%S "), text, "\n")
  f:close()
end

local notifyQueue = {}
local notifyBusyUntil = 0

local function showNotify(text, duration)
  if G.inkmenu and G.inkmenu.toast(text, duration) then return end
  local msg = SimpleScreenMessage.new()
  msg.message = text
  msg.isShown = true
  msg.duration = duration
  local defs = Game.GetAllBlackboardDefs()
  Game.GetBlackboardSystem():Get(defs.UI_Notifications)
    :SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(msg), true)
end

local function notifyDuration(text)
  return math.min(5.0, math.max(2.5, #text / 22))
end

function G.notifyPump()
  if #notifyQueue == 0 or os.clock() < notifyBusyUntil then return end
  local text = table.remove(notifyQueue, 1)
  local duration = notifyDuration(text)
  notifyBusyUntil = os.clock() + duration
  showNotify(text, duration)
end

function G.notify(text)
  if os.clock() >= notifyBusyUntil then
    local duration = notifyDuration(text)
    notifyBusyUntil = os.clock() + duration
    showNotify(text, duration)
    return
  end
  if #notifyQueue >= 3 then table.remove(notifyQueue, 1) end
  notifyQueue[#notifyQueue + 1] = text
end

local RARE_GAP = 30.0
local rareAt = {}

function G.notifyRare(kind, text)
  local now = os.clock()
  if rareAt[kind] and now - rareAt[kind] < RARE_GAP then return end
  rareAt[kind] = now
  G.notify(text)
end

G.records = require("records")(G)
G.perks = require("perks")(G)
G.abilities = require("abilities")(G)
G.hacks = require("hacks")(G)
G.netrunner = require("netrunner")(G)
G.input = require("input")(G)
G.hotkeys = require("hotkeys")(G)
G.companion = require("companion")(G)
G.arena = require("arena")(G)
G.dronecam = require("dronecam")(G)
G.orders = require("orders")(G)
G.chauffeur = require("chauffeur")(G)
G.squad = require("squad")(G)
G.armory = require("armory")(G)
G.skins = require("skins")(G)
G.ghost = require("ghost")(G)
G.hijack = require("hijack")(G)
G.loot = require("loot")(G)
G.wreck = require("wreck")(G)
G.prompt = require("prompt")(G)
require("icons")(G)
local ui = require("ui")(G)
G.ui = ui
G.menu = require("menu")(G)
G.native = require("native")(G)
G.inkmenu = require("inkmenu")(G, G.native)
G.menu.registerInk(G.native)
require("settingstab")(G, G.native)
G.shard = require("shard")(G)

registerForEvent("onInit", function()
  G.records.setup()
  G.ghost.setup()
  G.shard.setup()
  G.shard.installCraftHook()
  Cron.Every(1.0, G.netrunner.tick)
  G.companion.installHooks()
  G.input.actions = { toggle = ui.actToggle, cycle = ui.actCycle,
    command = function() G.orders.trigger() end,
    commandfly = function() G.orders.trigger("fly") end,
    commandground = function() G.orders.trigger("ground") end,
    chdrive = G.chauffeur.onAutodrive, chcam = G.chauffeur.cycleCamera,
    preset1 = function() G.squad.loadPreset(1) end,
    preset2 = function() G.squad.loadPreset(2) end,
    preset3 = function() G.squad.loadPreset(3) end,
    preset4 = function() G.squad.loadPreset(4) end,
    preset5 = function() G.squad.loadPreset(5) end,
    stanceall = function() G.companion.cycleStanceAll(1) end,
    hijack = function() G.hijack.trigger() end,
    holster = G.companion.toggleHolsterAll,
    dismissall = function() G.companion.dismissAll() end,
    regroup = function() G.orders.release() end,
    waypoint = function() G.orders.toWaypoint() end,
    repair = function() G.wreck.onChoice() end,
    chattack = G.chauffeur.passengerAttack }
  G.input.install()
  G.menu.install()
  G.inkmenu.install()
  G.chauffeur.install()
  G.loot.install()

  Observe("PlayerPuppet", "DCKeyCombo", function(_, id)
    G.input.fireById(tostring(id))
  end)
  Observe("PlayerPuppet", "DCKill", function(_, drone)
    G.squad.onKill(drone)
  end)
  local function refreshBinds()
    G.pushPhoneChoices()
    G.records.applyMechArmor()
    G.records.applyAndroidHeads()
    G.syncLanguage()
    if not G.recipesTaught and Game.GetPlayer() then
      G.recipesTaught = true
      G.shard.learnRecipes()
    end
  end
  refreshBinds()
  Cron.Every(2.0, refreshBinds)

  require("persistence")(G)
  local function guarded(label, fn)
    local ok, err = pcall(fn)
    if not ok then G.log(label .. " error: " .. tostring(err)) end
  end
  Cron.Every(1.0, function()
    guarded("watchdogTick", G.companion.watchdogTick)
    guarded("tuning.flush", G.tuning.flush)
    guarded("scanTick", G.orders.scanTick)
  end)
  Cron.Every(5.0, function() -- [CET-Cleans] was 2.0: android auto-loot scan is ~2-8 ms
    guarded("loot.tick", G.loot.tick)
  end)
  Cron.Every(0.25, function()
    guarded("muteTick", G.companion.muteTick)
    guarded("hacks.tick", G.hacks.tick)
    guarded("prompt.tick", G.prompt.tick)
  end)
  Cron.Every(0.5, function()
    guarded("ghost.tick", G.ghost.tick)
    guarded("wreck.tick", G.wreck.tick)
    guarded("hudTick", G.squad.hudTick)
    guarded("notifyPump", G.notifyPump)
    guarded("vehicleTick", G.companion.vehicleTick)
  end)
  G.log("loaded")
end)

registerForEvent("onUpdate", function(delta)
  Cron.Update(delta)
  G.companion.muteFrame()
  G.companion.elevatorTick()
  G.dronecam.frame(delta)
  G.inkmenu.tick(delta)
end)

return G
