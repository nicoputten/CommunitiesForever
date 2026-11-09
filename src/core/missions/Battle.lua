-- Missions: PvP extras: taunts, the flag, battleground scores, zones, the killer (CF-81).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Built: p.homeGuard (CF-99, retired from pool version 4), from the zone PvP type (V123: "friendly" reads only in the
-- own capitals). CF-104 (pool version 4): the PvP flag (V121: UnitIsPVP("player") after PLAYER_FLAGS_CHANGED) for
-- p.flagUp, p.flagHour, b.flagged3h; revenge (p.revenge) from the death recap's killer (V120) and the kill's victim
-- (CF-110), both by GUID. Facts of a day or week under facts.battle = { zones = { [zone] = pvpType }, flagged =
-- { [guid] = seconds }, flagRun = { [guid] = seconds flagged since the last death or unflag }, flagBest = { [guid] =
-- longest such run }, killers = { [guid] = the GUID of the player who last killed that character }, revenge (count) }.
-- Local facts of the day or week only: nothing new is sent.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Battle = {}

Battle.MAX_ZONES = 50 -- zones kept per day or week (a cap, as Goals' lists)
Battle.FRIENDLY = "friendly"
Battle.MAX_SECONDS = 600 -- the most one flag observation may add (a stuck timer never fills a goal)
Battle.MAX_CHARS = 50    -- characters kept per day or week in the flag and killer maps

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
  for _, key in ipairs({ "zones", "flagged", "flagRun", "flagBest", "killers" }) do
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
  on (false: the flag dropped, the run ends after these seconds) } ]]
ns.Goals.registerKind("battleFlag", function(f, obs)
  local guid = guidOf(obs.guid)
  if not guid then return end
  local b = factsOf(f)
  local s = type(obs.seconds) == "number" and obs.seconds > 0 and math.min(obs.seconds, Battle.MAX_SECONDS) or 0
  if s > 0 then
    keep(b.flagged, guid, (b.flagged[guid] or 0) + s)
    keep(b.flagRun, guid, (b.flagRun[guid] or 0) + s)
    if (b.flagRun[guid] or 0) > (b.flagBest[guid] or 0) then keep(b.flagBest, guid, b.flagRun[guid]) end
  end
  if obs.on == false then b.flagRun[guid] = nil end
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

--[[ battleVictim: an own PvP kill whose victim was picked by GUID (CF-110: your target, mouseover or a nameplate).
  { guid (the character), victim (the victim's GUID), bg (true: in a battleground) } The kill of the player who
  last killed that character, outside a battleground, is a revenge; that killer is avenged then (once per death). ]]
ns.Goals.registerKind("battleVictim", function(f, obs)
  local guid, victim = guidOf(obs.guid), guidOf(obs.victim)
  if not guid or not victim or obs.bg == true then return end
  local b = factsOf(f)
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

local PROGRESS = {
  ["p.homeGuard"] = function(f) return countedIn(f, Battle.FRIENDLY), 1 end,
  ["p.flagUp"] = function(f) return bestMinutes(map(f, "flagged")), 10 end,
  ["p.flagHour"] = function(f) return bestMinutes(map(f, "flagBest")), 30 end,
  ["b.flagged3h"] = function(f) return totalMinutes(map(f, "flagged")), 180 end,
  ["p.revenge"] = function(f)
    local n = battle(f).revenge
    return type(n) == "number" and n or 0, 1
  end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Battle.IDS = {}
for id in pairs(PROGRESS) do Battle.IDS[#Battle.IDS + 1] = id end
table.sort(Battle.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Battle = Battle
return Battle
