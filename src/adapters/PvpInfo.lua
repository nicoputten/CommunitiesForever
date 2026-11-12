-- PvpInfo: PvP counters, duels and deaths of the logged-in character (CF-52). Thin wrapper: raw values
-- only, the rules are in core/Pvp.lua. On Forever (V79, V81, API-FINDINGS "Forever launch probe") lifetime
-- kills, deaths and the death recap work and UnitPVPRank is missing; the rest is open (VERIFY.md V79). Each is
-- guarded, and a missing or secret value is nil.
local _, ns = ...

local PvpInfo = {}

-- Internal message: (reason, ...). Reasons: "kills", "honor" (text), "dead", "system" (text),
-- "timerStart" (name), "timerStop" (name), "damage" (subevent, environmentalType, sourceFlags, sourceGUID),
-- "unit" (unit token: an enemy player may be seen there, CF-55b).
PvpInfo.CHANGED = "CF_PVP_CHANGED"

-- The game's statistic "Total deaths" (as on Retail).
local STAT_DEATHS = 60

local readable, call = ns.Safe.value, ns.Safe.call

-- { hk, rank, rankName, weekKills, weekHonor, deaths }, each nil when not readable.
-- GetPVPLifetimeStats: hk, dishonorable kills, highest rank. UnitPVPRank gives the rank id, which
-- GetPVPRankInfo turns into its name and number (1 to 14; 0 or less: none). GetPVPThisWeekStats: hk, honor.
function PvpInfo.read()
  local info = {}
  info.hk = call(GetPVPLifetimeStats)
  local rankID = call(UnitPVPRank, "player")
  if rankID then
    local name, number = call(GetPVPRankInfo, rankID, "player")
    if type(number) == "number" then
      info.rank = math.max(0, number)
      info.rankName = number > 0 and type(name) == "string" and name or nil
    end
  end
  info.weekKills, info.weekHonor = call(GetPVPThisWeekStats)
  info.deaths = PvpInfo.totalDeaths()
  return info
end

-- The game's total deaths (statistic, a string like "12"), or nil.
function PvpInfo.totalDeaths()
  local text = call(GetStatistic, STAT_DEATHS)
  return tonumber(text)
end

-- The game's honor message formats, tried in this order (CF-101: Forever's kill message did not match
-- COMBATLOG_HONORGAIN, V73; it has no PvP ranks, so it likely uses the variant without one). Missing ones are skipped.
PvpInfo.HONOR_FORMATS = { "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK", "COMBATLOG_HONORGAIN_EXHAUSTION1",
                          "COMBATLOG_HONORGAIN_EXHAUSTION2", "COMBATLOG_HONORGAIN_EXHAUSTION3",
                          "COMBATLOG_HONORGAIN_EXHAUSTION4" }

-- The game's format strings for the duel and honor messages (nil when missing); honors: the readable
-- HONOR_FORMATS strings, in order (empty when none is readable).
function PvpInfo.formats()
  local honors = {}
  for _, name in ipairs(PvpInfo.HONOR_FORMATS) do
    local format = readable(_G[name])
    if type(format) == "string" then honors[#honors + 1] = format end
  end
  return { knockout = readable(DUEL_WINNER_KNOCKOUT), retreat = readable(DUEL_WINNER_RETREAT),
           honor = readable(COMBATLOG_HONORGAIN), honors = honors }
end

-- The last damage of the latest death recap: subevent, environmentalType, sourceGUID, sourceName (CF-121; V120: a
-- player killer's name is readable); or nil.
-- C_DeathRecap.GetRecapEvents() without an id gives the latest death (V81, verified on Forever).
function PvpInfo.recapDamage()
  if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return nil end
  local events = call(C_DeathRecap.GetRecapEvents)
  if type(events) ~= "table" then return nil end
  local last, lastAt
  for _, e in ipairs(events) do
    local at = type(e) == "table" and readable(e.timestamp)
    if type(at) == "number" and (not lastAt or at > lastAt) then last, lastAt = e, at end
  end
  if not last then return nil end
  return readable(last.event), readable(last.environmentalType), readable(last.sourceGUID), readable(last.sourceName)
end

-- CF-55b: an enemy player at a unit token: full name, { lvl (-1 skull), class, race (tokens), rank, raceId, classId },
-- or nil. Level, class and race verified on Forever (V74); the skull is open (VERIFY.md V74), the rank missing (V79).
-- CF-118: raceId and classId are UnitRace's and UnitClass's third returns (the Hunt's ids; for enemy players
-- unverified, VERIFY.md CF-118). Every value guarded, a secret one is nil.
function PvpInfo.enemy(unit)
  if not (UnitExists and UnitIsPlayer and GetUnitName) then return nil end
  if not (call(UnitExists, unit) and call(UnitIsPlayer, unit)) then return nil end
  local enemy = call(UnitIsEnemy, "player", unit) or call(UnitCanAttack, "player", unit)
  if not enemy then return nil end
  local name = call(GetUnitName, unit, true)
  if type(name) ~= "string" or name == "" then return nil end
  local _, class, classId = call(UnitClass, unit)
  local _, race, raceId = call(UnitRace, unit)
  local fields = { lvl = call(UnitLevel, unit), class = class, race = race,
                   raceId = type(raceId) == "number" and raceId or nil,
                   classId = type(classId) == "number" and classId or nil }
  local rankID = call(UnitPVPRank, unit)
  if rankID then
    local _, number = call(GetPVPRankInfo, rankID, unit)
    if type(number) == "number" then fields.rank = math.max(0, number) end
  end
  return name, fields
end

-- CF-110: an enemy player at a unit token for the victim at a kill (core Pvp.seeAlive, Pvp.killCandidates):
-- { guid, name, enemy = true, dead, lvl, class, race, rank, health, source }, or nil when no enemy player is there.
-- UnitIsDead exists on Forever (bug 13's probe line); missing, it gives dead nil and no victim is picked. CF-117:
-- health is UnitHealth / UnitHealthMax (0 to 1; unverified for enemy players on Forever, VERIFY.md V143; likely
-- secret under the Midnight rules, then nil). Every value through Safe.call, so a secret one is nil before anything
-- compares it.
function PvpInfo.look(unit, source)
  local name, fields = PvpInfo.enemy(unit)
  if not name then return nil end
  local guid = call(UnitGUID, unit)
  if type(guid) ~= "string" or guid == "" then return nil end
  local dead = call(UnitIsDead, unit)
  if dead ~= nil then dead = dead == true end
  local health, most = call(UnitHealth, unit), call(UnitHealthMax, unit)
  health = type(health) == "number" and type(most) == "number" and most > 0 and health / most or nil
  return { guid = guid, name = name, enemy = true, dead = dead, lvl = fields.lvl, class = fields.class,
           race = fields.race, rank = fields.rank, raceId = fields.raceId, classId = fields.classId, health = health,
           source = source }
end

-- CF-118: the duel opponent's class token and level when your target is that player (vs: the full name the duel
-- message gave), else nil. A duel usually ends with the opponent targeted; a stranger's class is known only then. Every
-- value through Safe.call, a secret one is nil.
function PvpInfo.duelOpponent(vs)
  if type(vs) ~= "string" or vs == "" or not (UnitExists and GetUnitName) then return nil end
  if not call(UnitExists, "target") then return nil end
  local name = call(GetUnitName, "target", true)
  if type(name) ~= "string" or name ~= vs then return nil end
  local _, class = call(UnitClass, "target")
  local level = call(UnitLevel, "target")
  return type(class) == "string" and class or nil, type(level) == "number" and level > 0 and level or nil
end

PvpInfo.NAMEPLATES = 40

-- CF-110: the enemy players at your target, mouseover and the nameplate tokens nameplate1 to nameplate40, in that
-- order (PvpInfo.look of each).
function PvpInfo.looks()
  local list = {}
  local function add(unit, source)
    local look = PvpInfo.look(unit, source)
    if look then list[#list + 1] = look end
  end
  add("target", "target")
  add("mouseover", "mouseover")
  for i = 1, PvpInfo.NAMEPLATES do add("nameplate" .. i, "nameplate") end
  return list
end

-- The game's PvP rank names of both factions: { [name] = rank number }, for the honor message's rank.
-- GetPVPRankInfo(rankID, faction) with the Classic rank ids (rank 1 is id 5).
function PvpInfo.rankNumbers()
  local numbers = {}
  for id = 1, 18 do
    for _, faction in ipairs({ 0, 1 }) do
      local name, number = call(GetPVPRankInfo, id, faction)
      if type(name) == "string" and type(number) == "number" and number > 0 then numbers[name] = number end
    end
  end
  return numbers
end

-- true when not in a group, nil when unknown (IsInGroup, unverified: V76).
function PvpInfo.solo()
  local grouped = call(IsInGroup)
  if grouped == nil then return nil end
  return not grouped
end

local EVENTS = {
  PLAYER_PVP_KILLS_CHANGED = "kills",
  CHAT_MSG_COMBAT_HONOR_GAIN = "honor", -- arg 1 is the text
  PLAYER_DEAD = "dead",
  CHAT_MSG_SYSTEM = "system",           -- arg 1 is the text (duel results)
  MIRROR_TIMER_START = "timerStart",    -- arg 1 is the timer: BREATH, EXHAUSTION, FEIGNDEATH
  MIRROR_TIMER_STOP = "timerStop",
}

-- CF-55b: where an enemy player can be seen (V74). NAME_PLATE_UNIT_ADDED passes the unit token.
local UNIT_EVENTS = { PLAYER_TARGET_CHANGED = "target", UPDATE_MOUSEOVER_UNIT = "mouseover",
                      NAME_PLATE_UNIT_ADDED = false }

-- Translates the events into PvpInfo.CHANGED messages. Returns false: the combat log is never registered (CF-61,
-- Nico 2026-10-29). On Retail 12.1.5 registering it shows Blizzard's "only available to the Blizzard UI ... disable
-- this addon" banner, even inside pcall (API-FINDINGS "Retail dry runs"); Forever is unknown (V75). Death causes come
-- from the death recap and mirror timers instead.
function PvpInfo.watch(addon)
  for event, reason in pairs(EVENTS) do
    ns.Events.register(addon, event, function(_, ...)
      addon:SendMessage(PvpInfo.CHANGED, reason, ns.Safe.values(...)) -- CF-108: secret as nil
    end)
  end
  for event, unit in pairs(UNIT_EVENTS) do
    ns.Events.register(addon, event, function(_, token)
      addon:SendMessage(PvpInfo.CHANGED, "unit", unit or ns.Safe.value(token))
    end)
  end
  return false
end

ns.PvpInfo = PvpInfo
return PvpInfo
