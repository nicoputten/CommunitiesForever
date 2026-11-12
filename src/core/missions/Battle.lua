-- Missions: PvP extras: taunts, the flag, battleground scores, zones, the killer (CF-81).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Built: p.homeGuard (CF-99, retired from pool version 4), from the zone PvP type (V123: "friendly" reads only in the
-- own capitals). CF-104 (pool version 4): the PvP flag (V121: UnitIsPVP("player") after PLAYER_FLAGS_CHANGED) for
-- p.flagUp, p.flagHour, b.flagged3h; revenge (p.revenge) from the death recap's killer (V120) and the kill's victim
-- (CF-110), both by GUID. Facts of a day or week under facts.battle = { zones = { [zone] = pvpType }, flagged =
-- { [guid] = seconds }, flagRun = { [guid] = seconds flagged since the last death or unflag }, flagBest = { [guid] =
-- longest such run }, killers = { [guid] = the GUID of the player who last killed that character }, revenge (count) }.
-- CF-118 (pool version 6): flagStay = { [guid] = seconds flagged since the flag last dropped (a death doesn't end
-- it) }, flagStayBest, flagZone = { [zone] = seconds flagged there, all characters }, flagParty (seconds flagged
-- while grouped with 2 or more friends) for p.flag60, p.boldQuest, p.holdout, p.patrol.
-- CF-121: fallen = { { killer, name, at } } (a grouped friend's character died to that player, from the friend's FELL
-- message; at most MAX_FALLEN), avenge (count) for p.avenge and b.avenge3.
-- Local facts of the day or week only (the FELL message is CF-121's, docs/SYNC.md).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Battle = {}

Battle.MAX_ZONES = 50 -- zones kept per day or week (a cap, as Goals' lists)
Battle.FRIENDLY = "friendly"
Battle.MAX_SECONDS = 600 -- the most one flag observation may add (a stuck timer never fills a goal)
Battle.MAX_CHARS = 50    -- characters kept per day or week in the flag and killer maps
Battle.AVENGE_WINDOW = 600 -- CF-121: seconds after a friend's death its killer can be avenged
Battle.MAX_FALLEN = 20     -- CF-121: friends' deaths kept per day or week

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function text(v) return type(v) == "string" and v ~= "" and v or nil end

local function factsOf(f)
  local b = f.battle
  if type(b) ~= "table" then
    b = { zones = {} }
    f.battle = b
  end
  -- Facts of an earlier version have only the zones: the newer maps start empty.
  for _, key in ipairs({ "zones", "flagged", "flagRun", "flagBest", "killers", "flagStay", "flagStayBest",
                         "flagZone", "fallen" }) do
    if type(b[key]) ~= "table" then b[key] = {} end
  end
  return b
end

-- Whether a GUID is a player's ("Player-..."): the death recap's killer must be one. GUIDs are keys, never names.
function Battle.isPlayerGuid(guid)
  return type(guid) == "string" and guid:match("^Player%-") ~= nil
end

local function guidOf(v) return type(v) == "string" and v ~= "" and v or nil end

-- Sets map[key] = value unless the map is full and has no such key yet.
local function keep(map, key, value)
  if map[key] ~= nil or count(map) < Battle.MAX_CHARS then map[key] = value end
end

-- ===== Observations =====

--[[ battleZone: the PvP type of the zone the own character is in (C_PvP.GetZonePVPInfo), read on entering a
  zone and on each own PvP kill. { zone (GetRealZoneText), pvpType ("friendly", "hostile", ...; nil: none) }.
  A zone without a type is not kept; the latest type of a zone wins. ]]
ns.Goals.registerKind("battleZone", function(f, obs)
  local zone, pvpType = text(obs.zone), text(obs.pvpType)
  if not zone or not pvpType then return end
  local b = factsOf(f)
  if b.zones[zone] or count(b.zones) < Battle.MAX_ZONES then b.zones[zone] = pvpType end
end)

--[[ battleFlag: time the own character was flagged for PvP (UnitIsPVP("player"), V121), sent while flagged and
  when the flag drops. { guid (the character), seconds (flagged since the last observation, at most MAX_SECONDS),
  on (false: the flag dropped, the run ends after these seconds), zone (CF-118: the zone now, nil: unknown),
  friends (CF-118: friends in the group now, nil: unknown) } ]]
ns.Goals.registerKind("battleFlag", function(f, obs)
  local guid = guidOf(obs.guid)
  if not guid then return end
  local b = factsOf(f)
  local s = type(obs.seconds) == "number" and obs.seconds > 0 and math.min(obs.seconds, Battle.MAX_SECONDS) or 0
  if s > 0 then
    keep(b.flagged, guid, (b.flagged[guid] or 0) + s)
    keep(b.flagRun, guid, (b.flagRun[guid] or 0) + s)
    if (b.flagRun[guid] or 0) > (b.flagBest[guid] or 0) then keep(b.flagBest, guid, b.flagRun[guid]) end
    keep(b.flagStay, guid, (b.flagStay[guid] or 0) + s)
    if (b.flagStay[guid] or 0) > (b.flagStayBest[guid] or 0) then keep(b.flagStayBest, guid, b.flagStay[guid]) end
    local zone = text(obs.zone)
    if zone and (b.flagZone[zone] or count(b.flagZone) < Battle.MAX_ZONES) then
      b.flagZone[zone] = (b.flagZone[zone] or 0) + s
    end
    if type(obs.friends) == "number" and obs.friends >= 2 then
      b.flagParty = (type(b.flagParty) == "number" and b.flagParty or 0) + s
    end
  end
  if obs.on == false then
    b.flagRun[guid] = nil
    b.flagStay[guid] = nil
  end
end)

--[[ battleDeath: the own character died (PLAYER_DEAD). { guid (the character), killer (the GUID of the death
  recap's last damage source, C_DeathRecap, V120; nil: unknown) } The flagged run starts over; the killer is kept
  when it is a player, else the character has no killer to avenge (the last death counts). ]]
ns.Goals.registerKind("battleDeath", function(f, obs)
  local guid = guidOf(obs.guid)
  if not guid then return end
  local b = factsOf(f)
  b.flagRun[guid] = nil
  if Battle.isPlayerGuid(obs.killer) and obs.killer ~= guid then
    keep(b.killers, guid, obs.killer)
  else
    b.killers[guid] = nil
  end
end)

--[[ battleFriendFell (CF-121): a friend's character in your group died to a player (their FELL message: their
  death recap's killer). { killer (the killer's GUID, nil when the recap gave none), name (the killer's name as the
  game gives it, never split; nil: unknown), at (server time of the death) }. Kept until avenged or
  AVENGE_WINDOW has passed; one without a player GUID and without a name is dropped. ]]
ns.Goals.registerKind("battleFriendFell", function(f, obs)
  local killer = Battle.isPlayerGuid(obs.killer) and obs.killer or nil
  local name = text(obs.name)
  if not (killer or name) or type(obs.at) ~= "number" then return end
  local b = factsOf(f)
  local kept = {}
  for _, e in ipairs(b.fallen) do
    if type(e) == "table" and type(e.at) == "number" and obs.at - e.at <= Battle.AVENGE_WINDOW then
      kept[#kept + 1] = e
    end
  end
  if #kept >= Battle.MAX_FALLEN then table.remove(kept, 1) end
  kept[#kept + 1] = { killer = killer, name = name, at = obs.at }
  b.fallen = kept
end)

-- CF-121: the fallen friend's entry whose killer is this victim: by GUID when the friend's recap gave one, else by
-- the whole name; the death at most AVENGE_WINDOW before the kill (and not after it). Its index, or nil.
function Battle.avenged(fallen, victim, name, at)
  if type(fallen) ~= "table" or type(at) ~= "number" then return nil end
  for i, e in ipairs(fallen) do
    local fits = type(e) == "table" and type(e.at) == "number" and at >= e.at and at - e.at <= Battle.AVENGE_WINDOW
    local same = fits and ((e.killer ~= nil and e.killer == victim) or (e.killer == nil and e.name ~= nil
      and e.name == name))
    if fits and same then return i end
  end
  return nil
end

--[[ battleVictim: an own PvP kill whose victim was picked by GUID (CF-110: your target, mouseover or a nameplate).
  { guid (the character), victim (the victim's GUID), bg (true: in a battleground), name (CF-121: the victim's name,
  nil: unknown), at (CF-121: server time of the kill, nil: unknown) } The kill of the player who last killed that
  character, outside a battleground, is a revenge; that killer is avenged then (once per death). CF-121: the kill of
  a player who killed a grouped friend within AVENGE_WINDOW is an avenge (once per friend's death; a battleground
  counts too). ]]
ns.Goals.registerKind("battleVictim", function(f, obs)
  local guid, victim = guidOf(obs.guid), guidOf(obs.victim)
  if not guid or not victim then return end
  local b = factsOf(f)
  local i = Battle.avenged(b.fallen, victim, text(obs.name), obs.at)
  if i then
    table.remove(b.fallen, i)
    b.avenge = (type(b.avenge) == "number" and b.avenge or 0) + 1
  end
  if obs.bg == true then return end
  if b.killers[guid] == victim then
    b.killers[guid] = nil
    b.revenge = (type(b.revenge) == "number" and b.revenge or 0) + 1
  end
end)

-- ===== Progress =====

local function zones(f)
  return type(f.battle) == "table" and type(f.battle.zones) == "table" and f.battle.zones or {}
end

-- Counted kills on the PvP track (Doomsday.scoreKills) in a zone of the given PvP type.
local function countedIn(f, pvpType)
  local types, n = zones(f), 0
  for _, s in ipairs(f.scored or {}) do
    local zone = type(s.kill) == "table" and s.kill.zone
    if s.counted and s.track == "pvp" and zone ~= nil and types[zone] == pvpType then n = n + 1 end
  end
  return n
end

local function battle(f) return type(f.battle) == "table" and f.battle or {} end

local function map(f, key)
  local m = battle(f)[key]
  return type(m) == "table" and m or {}
end

-- The most seconds of one character in a map, in whole minutes.
local function bestMinutes(m)
  local best = 0
  for _, s in pairs(m) do
    if type(s) == "number" and s > best then best = s end
  end
  return math.floor(best / 60)
end

-- The seconds of all characters, in whole minutes.
local function totalMinutes(m)
  local total = 0
  for _, s in pairs(m) do
    if type(s) == "number" and s > 0 then total = total + s end
  end
  return math.floor(total / 60)
end

-- CF-118: minutes flagged in the zones of a list, all characters.
local function zoneMinutes(f, test)
  local total = 0
  for zone, s in pairs(map(f, "flagZone")) do
    if type(s) == "number" and s > 0 and test(zone) then total = total + s end
  end
  return math.floor(total / 60)
end

-- CF-118: whether a quest was handed in in a contested zone (facts.quests = { [zone] = n }).
local function contestedQuest(f)
  for zone, n in pairs(type(f.quests) == "table" and f.quests or {}) do
    if type(n) == "number" and n > 0 and ns.Doomsday.inList(ns.Doomsday.CONTESTED, zone) then return true end
  end
  return false
end

local PROGRESS = {
  ["p.flag60"] = function(f) return math.min(bestMinutes(map(f, "flagStayBest")), 60), 60 end,
  -- Quest flagged in a contested zone for 20 min: 20 minutes flagged in contested zones and a quest handed in in one.
  ["p.boldQuest"] = function(f)
    local minutes = math.min(zoneMinutes(f, function(zone) return ns.Doomsday.inList(ns.Doomsday.CONTESTED, zone) end),
      20)
    if minutes >= 20 and not contestedQuest(f) then minutes = 19 end
    return minutes, 20
  end,
  ["p.holdout"] = function(f)
    return math.min(zoneMinutes(f, function(zone) return f.zone ~= nil and zone == f.zone end), 10), 10
  end,
  ["p.patrol"] = function(f)
    local s = battle(f).flagParty
    return math.min(math.floor((type(s) == "number" and s or 0) / 60), 20), 20
  end,
  ["p.homeGuard"] = function(f) return countedIn(f, Battle.FRIENDLY), 1 end,
  ["p.flagUp"] = function(f) return bestMinutes(map(f, "flagged")), 10 end,
  ["p.flagHour"] = function(f) return bestMinutes(map(f, "flagBest")), 30 end,
  ["b.flagged3h"] = function(f) return totalMinutes(map(f, "flagged")), 180 end,
  ["p.revenge"] = function(f)
    local n = battle(f).revenge
    return type(n) == "number" and n or 0, 1
  end,
  -- CF-121
  ["p.avenge"] = function(f)
    local n = battle(f).avenge
    return type(n) == "number" and n or 0, 1
  end,
  ["b.avenge3"] = function(f)
    local n = battle(f).avenge
    return type(n) == "number" and n or 0, 3
  end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Battle.IDS = {}
for id in pairs(PROGRESS) do Battle.IDS[#Battle.IDS + 1] = id end
table.sort(Battle.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Battle = Battle
return Battle
