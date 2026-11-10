-- Missions: PvP fights: kills, deaths, duels, battlegrounds (CF-80). CF-118: the PvP dailies of pool version 6 (the
-- Skirmish's kills, territory and timing missions, the Hunt-like ones and the Duel slot's missions).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Kills come from the day's scored kills (Doomsday.scoreKills: counted world kills only), each with the local extras
-- DoomsdayTracker adds at the kill (myClass, myFaction, friends = { friend key, ... } grouped then, sinceLogin);
-- facts.fights = { duels = { { t, won, friend, class, lvl, myLvl, zone } }, capital (bool), town (bool) }. Local facts
-- of the day or week only: nothing new is sent (only the goals done, as always).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Fights = {}

Fights.MAX_DUELS = 50        -- duels kept per day or week (a cap, as Goals' lists)
Fights.DOUBLE_SECONDS = 30   -- p.double30: 2 kills by one character within this
Fights.HOT_START = 600       -- p.hotStart: a kill within 10 minutes of logging in
Fights.EARLY_HOUR = 12       -- p.earlyBlood: realm time before 12:00
Fights.MIDNIGHT_UNTIL = 5    -- p.midnightRaid: realm time 00:00 to 04:59
Fights.YOUNG_LEVEL = 30      -- p.youngBlood: a character below level 30
-- Healer classes (p.healerDown), by token and by id.
local HEALERS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true, [5] = true, [11] = true, [2] = true,
                  [7] = true }

local function text(v) return type(v) == "string" and v ~= "" and v or nil end

local function factsOf(f)
  local x = f.fights
  if type(x) ~= "table" then
    x = {}
    f.fights = x
  end
  if type(x.duels) ~= "table" then x.duels = {} end
  return x
end

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

-- ===== Observations =====

--[[ fightDuel: a finished duel of an own character. { t, won (bool), friend (the opponent's friend key, nil: not a
  friend's community character), class (the opponent's class token, nil: unknown), lvl, myLvl, zone } ]]
ns.Goals.registerKind("fightDuel", function(f, obs)
  if type(obs.won) ~= "boolean" then return end
  local x = factsOf(f)
  if #x.duels >= Fights.MAX_DUELS then return end
  x.duels[#x.duels + 1] = { t = type(obs.t) == "number" and obs.t or nil, won = obs.won, friend = text(obs.friend),
                            class = text(obs.class), lvl = type(obs.lvl) == "number" and obs.lvl or nil,
                            myLvl = type(obs.myLvl) == "number" and obs.myLvl or nil, zone = text(obs.zone) }
end)

--[[ fightPlace: the own character entered a zone or a town (a subzone). { faction (the character's), zone, subzone }
  An enemy capital (Doomsday.CAPITALS of the other faction) is p.tourist's; an enemy town (Doomsday.TOWNS) is
  p.raidParty's. ]]
ns.Goals.registerKind("fightPlace", function(f, obs)
  local enemy = ns.Doomsday.HUNTER_OF[obs.faction]
  if not enemy then return end
  local x = factsOf(f)
  if ns.Doomsday.inList(ns.Doomsday.CAPITALS[enemy], text(obs.zone)) then x.capital = true end
  if ns.Doomsday.inList(ns.Doomsday.TOWNS[enemy], text(obs.subzone)) then x.town = true end
end)

-- ===== Progress =====

-- Counted world kills (the PvP track), optionally filtered.
local function kills(f, test)
  local list = {}
  for _, s in ipairs(f.scored or {}) do
    if s.counted and s.track == "pvp" and type(s.kill) == "table" and (not test or test(s.kill)) then
      list[#list + 1] = s.kill
    end
  end
  return list
end

local function any(f, test) return #kills(f, test) > 0 and 1 or 0, 1 end

local function diff(k)
  if k.lvl == -1 then return 99 end -- a skull is above anyone
  if type(k.lvl) ~= "number" or type(k.myLvl) ~= "number" then return nil end
  return k.lvl - k.myLvl
end

-- The realm hour of a kill (0 to 23), from its server time and the realm offset; nil without either.
local function realmHour(f, k)
  if type(k.t) ~= "number" or type(f.offset) ~= "number" then return nil end
  return math.floor(((k.t + f.offset) % 86400) / 3600)
end

local function distinct(list, key)
  local seen = {}
  for _, k in ipairs(list) do
    local v = key(k)
    if v ~= nil then seen[v] = true end
  end
  return count(seen)
end

-- A kill's race and class as "<raceId>:<classId>" (the tokens mapped to ids when the ids are missing), or nil.
local RACE_IDS, CLASS_IDS = {}, {}
for id, token in pairs(ns.Doomsday.RACE_TOKENS) do RACE_IDS[token] = id end
for id, token in pairs(ns.Doomsday.CLASS_TOKENS) do CLASS_IDS[token] = id end
function Fights.targetKey(k)
  local race = type(k.raceId) == "number" and k.raceId or RACE_IDS[k.race]
  local class = type(k.classId) == "number" and k.classId or CLASS_IDS[k.class]
  if not race or not class then return nil end
  return race .. ":" .. class
end

-- Whether a kill matches any of today's Hunts (f.hunts) in part ("race", "class") or whole (nil).
local function quarry(f, k, part)
  for _, h in ipairs(f.hunts or {}) do
    if ns.Doomsday.huntMatches(h, k, part) then return true end
  end
  return false
end

-- The most kills by one character within `seconds` of each other.
local function burst(list, seconds)
  local byChar = {}
  for _, k in ipairs(list) do
    if type(k.t) == "number" then
      local key = k.char or ""
      byChar[key] = byChar[key] or {}
      table.insert(byChar[key], k.t)
    end
  end
  local best = 0
  for _, times in pairs(byChar) do
    table.sort(times)
    local first = 1
    for i = 1, #times do
      while times[i] - times[first] > seconds do first = first + 1 end
      best = math.max(best, i - first + 1)
    end
  end
  return best
end

local function friendsAt(k) return type(k.friends) == "table" and #k.friends or 0 end

local function fights(f) return type(f.fights) == "table" and f.fights or {} end

local function duels(f, test)
  local n = 0
  for _, d in ipairs(type(fights(f).duels) == "table" and fights(f).duels or {}) do
    if not test or test(d) then n = n + 1 end
  end
  return n
end

local function won(d) return d.won == true end

local PROGRESS = {
  -- Kills
  ["p.hk3"] = function(f) return math.min(#kills(f), 3), 3 end,
  ["p.kills10"] = function(f) return math.min(#kills(f), 10), 10 end,
  ["p.upLevel"] = function(f) return any(f, function(k) return (diff(k) or -1) >= 1 end) end,
  ["p.punchUp5"] = function(f) return any(f, function(k) return (diff(k) or -1) >= 5 end) end,
  ["p.fairFight"] = function(f) return any(f, function(k) return diff(k) == 0 end) end,
  ["p.mirror"] = function(f)
    return any(f, function(k) return text(k.class) ~= nil and k.class == k.myClass end)
  end,
  ["p.races3"] = function(f)
    return math.min(distinct(kills(f), function(k) return k.raceId or k.race end), 3), 3
  end,
  ["p.healerDown"] = function(f)
    return any(f, function(k) return HEALERS[k.classId] == true or HEALERS[k.class] == true end)
  end,
  ["p.double30"] = function(f) return math.min(burst(kills(f), Fights.DOUBLE_SECONDS), 2), 2 end,
  -- Hunt-like
  ["p.closeEnough"] = function(f) return any(f, function(k) return quarry(f, k, "race") end) end,
  ["p.halfHunt"] = function(f) return any(f, function(k) return quarry(f, k, "class") end) end,
  ["p.rareQuarry"] = function(f)
    local rare = type(f.rareTargets) == "table" and f.rareTargets or {}
    return any(f, function(k)
      local key = Fights.targetKey(k)
      return key ~= nil and rare[key] == true
    end)
  end,
  -- Territory
  ["p.contestedHk"] = function(f)
    return any(f, function(k) return ns.Doomsday.inList(ns.Doomsday.CONTESTED, k.zone) end)
  end,
  ["p.enemyLand"] = function(f)
    return any(f, function(k)
      local enemy = ns.Doomsday.HUNTER_OF[k.myFaction]
      return enemy ~= nil and ns.Doomsday.inList(ns.Doomsday.TERRITORY[enemy], k.zone)
    end)
  end,
  ["p.zones3"] = function(f) return math.min(distinct(kills(f), function(k) return text(k.zone) end), 3), 3 end,
  ["p.zoneDay"] = function(f)
    return any(f, function(k) return f.zone ~= nil and k.zone == f.zone end)
  end,
  ["p.tourist"] = function(f) return fights(f).capital == true and 1 or 0, 1 end,
  ["p.raidParty"] = function(f) return fights(f).town == true and 1 or 0, 1 end,
  -- Together
  ["p.duoKill"] = function(f) return any(f, function(k) return friendsAt(k) >= 1 end) end,
  ["p.trioKills"] = function(f) return any(f, function(k) return friendsAt(k) >= 2 end) end,
  -- Everyone in the group gets an HK: a kill while grouped with friends, each of whom has an HK that day too
  -- (f.friendKills = { [friend key] = true }, from their synced feeds).
  ["p.sharedGlory"] = function(f)
    local others = type(f.friendKills) == "table" and f.friendKills or {}
    return any(f, function(k)
      if friendsAt(k) == 0 then return false end
      for _, friend in ipairs(k.friends) do
        if not others[friend] then return false end
      end
      return true
    end)
  end,
  -- Timing
  ["p.earlyBlood"] = function(f)
    return any(f, function(k)
      local h = realmHour(f, k)
      return h ~= nil and h < Fights.EARLY_HOUR
    end)
  end,
  ["p.midnightRaid"] = function(f)
    return any(f, function(k)
      local h = realmHour(f, k)
      return h ~= nil and h < Fights.MIDNIGHT_UNTIL
    end)
  end,
  ["p.youngBlood"] = function(f)
    return any(f, function(k) return type(k.myLvl) == "number" and k.myLvl < Fights.YOUNG_LEVEL end)
  end,
  ["p.hotStart"] = function(f)
    return any(f, function(k)
      return type(k.sinceLogin) == "number" and k.sinceLogin >= 0 and k.sinceLogin <= Fights.HOT_START
    end)
  end,
  ["p.twoBlades"] = function(f) return math.min(distinct(kills(f), function(k) return k.char end), 2), 2 end,
  -- Duels
  ["p.duelFirst"] = function(f)
    return math.min(duels(f, function(d) return d.friend ~= nil end), 1), 1
  end,
  ["p.duelWin"] = function(f) return math.min(duels(f, won), 1), 1 end,
  ["p.duel3"] = function(f) return math.min(duels(f, won), 3), 3 end,
  ["p.spar"] = function(f) return math.min(duels(f, function(d) return d.friend ~= nil end), 1), 1 end,
  ["p.duelUp"] = function(f)
    return math.min(duels(f, function(d)
      return won(d) and type(d.lvl) == "number" and type(d.myLvl) == "number" and d.lvl > d.myLvl
    end), 1), 1
  end,
  ["p.styles3"] = function(f)
    local seen = {}
    for _, d in ipairs(type(fights(f).duels) == "table" and fights(f).duels or {}) do
      if d.class then seen[d.class] = true end
    end
    return math.min(count(seen), 3), 3
  end,
  ["p.cityDuel"] = function(f)
    local capitals = {}
    for _, list in pairs(ns.Doomsday.CAPITALS) do
      for _, zone in ipairs(list) do capitals[#capitals + 1] = zone end
    end
    return math.min(duels(f, function(d) return won(d) and ns.Doomsday.inList(capitals, d.zone) end), 1), 1
  end,
  ["p.bothWays"] = function(f)
    return (duels(f, won) > 0 and #kills(f) > 0) and 1 or 0, 1
  end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Fights.IDS = {}
for id in pairs(PROGRESS) do Fights.IDS[#Fights.IDS + 1] = id end
table.sort(Fights.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Fights = Fights
return Fights
