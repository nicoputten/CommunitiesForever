-- Missions: PvP extras: taunts, the flag, battleground scores, zones, the killer (CF-81).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Built so far: p.homeGuard (CF-99), from the zone PvP type (V123: "friendly" in the own faction's land reads;
-- a starting zone gave nothing). Facts of a day or week under facts.battle = { zones = { [zone] = pvpType } }:
-- the PvP type each zone showed when the own character was in it (zone, kill). No stored data.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Battle = {}

Battle.MAX_ZONES = 50 -- zones kept per day or week (a cap, as Goals' lists)
Battle.FRIENDLY = "friendly"

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
  return b
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

local PROGRESS = {
  ["p.homeGuard"] = function(f) return countedIn(f, Battle.FRIENDLY), 1 end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Battle.IDS = {}
for id in pairs(PROGRESS) do Battle.IDS[#Battle.IDS + 1] = id end
table.sort(Battle.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Battle = Battle
return Battle
