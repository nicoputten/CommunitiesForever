-- PvpInfo: PvP counters, duels and deaths of the logged-in character (CF-52). Thin wrapper: raw values
-- only, the rules are in core/Pvp.lua. None of these APIs are verified on Forever (VERIFY.md V79 to V81):
-- each is guarded, and a missing or secret value is nil.
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

-- The game's format strings for the duel and honor messages (nil when missing).
function PvpInfo.formats()
  return { knockout = readable(DUEL_WINNER_KNOCKOUT), retreat = readable(DUEL_WINNER_RETREAT),
           honor = readable(COMBATLOG_HONORGAIN) }
end

-- The last damage of the latest death recap: subevent, environmentalType, sourceGUID; or nil.
-- C_DeathRecap.GetRecapEvents() without an id is assumed to give the latest death (VERIFY.md V81).
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
  return readable(last.event), readable(last.environmentalType), readable(last.sourceGUID)
end

-- CF-55b: an enemy player at a unit token: full name, { lvl (-1 skull), class, race (tokens), rank }, or nil.
-- Unverified (VERIFY.md V74): every value guarded, a secret one is nil.
function PvpInfo.enemy(unit)
  if not (UnitExists and UnitIsPlayer and GetUnitName) then return nil end
  if not (call(UnitExists, unit) and call(UnitIsPlayer, unit)) then return nil end
  local enemy = call(UnitIsEnemy, "player", unit) or call(UnitCanAttack, "player", unit)
  if not enemy then return nil end
  local name = call(GetUnitName, unit, true)
  if type(name) ~= "string" or name == "" then return nil end
  local _, class = call(UnitClass, unit)
  local _, race = call(UnitRace, unit)
  local fields = { lvl = call(UnitLevel, unit), class = class, race = race }
  local rankID = call(UnitPVPRank, unit)
  if rankID then
    local _, number = call(GetPVPRankInfo, rankID, unit)
    if type(number) == "number" then fields.rank = math.max(0, number) end
  end
  return name, fields
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

-- Damage the player takes, from the combat log. Under the Midnight restrictions an addon may not be
-- allowed to register it: then it is skipped (pcall), and deaths fall back to timers or "other".
local function watchCombatLog(addon)
  if not CombatLogGetCurrentEventInfo or not ns.Events.isValid("COMBAT_LOG_EVENT_UNFILTERED") then return false end
  local ok = pcall(addon.RegisterEvent, addon, "COMBAT_LOG_EVENT_UNFILTERED", function()
    local values = { pcall(CombatLogGetCurrentEventInfo) }
    if not values[1] then return end
    local subevent, sourceGUID, sourceFlags, destGUID = values[3], values[5], values[7], values[9]
    if readable(destGUID) == nil or destGUID ~= UnitGUID("player") then return end
    addon:SendMessage(PvpInfo.CHANGED, "damage", readable(subevent), readable(values[13]), readable(sourceFlags),
      readable(sourceGUID))
  end)
  return ok
end

-- Translates the events into PvpInfo.CHANGED messages. Returns whether the combat log could be watched.
function PvpInfo.watch(addon)
  for event, reason in pairs(EVENTS) do
    ns.Events.register(addon, event, function(_, ...)
      addon:SendMessage(PvpInfo.CHANGED, reason, ...)
    end)
  end
  for event, unit in pairs(UNIT_EVENTS) do
    ns.Events.register(addon, event, function(_, token)
      addon:SendMessage(PvpInfo.CHANGED, "unit", unit or token)
    end)
  end
  return watchCombatLog(addon)
end

ns.PvpInfo = PvpInfo
return PvpInfo
