-- PvpTracker: PvP counters, honorable kills by zone, deaths and duels of the own characters (CF-52).
-- Keeps `chars[guid].pvp` in the own record and adds the events to the activity feed (FeedTracker).
-- Counter changes travel with the feed's debounced bump; a new PvP rank bumps the version right away.
-- CF-55b: one pvpKills entry per honor message of a kill, its victim fields from the players seen shortly
-- before (target, mouseover, nameplates); kills the counter shows without an honor message get an entry
-- without a victim.
local _, ns = ...

local PvpTracker = {}

local addonRef
-- The last damage taken ({ kind, at }, Pvp.damage) and the mirror timers ({ [name] = { startedAt, stoppedAt } }).
local lastDamage, timers = nil, {}
-- CF-55b: enemy players seen (Pvp.remember), the game's rank names, and the kills each source reported since
-- the counter last rose (the counter fallback compares them after Pvp.FALLBACK_DELAY).
local seen, rankNumbers, honorKills, counterKills, fallbackLater = {}, nil, 0, 0, nil

local function own() return addonRef.db.global.self end

local function currentChar()
  local guid = ns.SelfInfo.guid()
  return guid and own().chars[guid]
end

local PVP_FIELDS = { "hk", "rank", "rankName", "weekKills", "weekHonor", "deaths", "duelsWon", "duelsLost" }

local function differs(a, b)
  for _, field in ipairs(PVP_FIELDS) do
    if (a or {})[field] ~= (b or {})[field] then return true end
  end
  return false
end

local function bumpNow()
  own().version = ns.Merge.nextVersion(own().version, GetServerTime())
  addonRef:SendMessage(ns.SelfTracker.UPDATED)
end

-- Reads the counters. countKills: a kill event, so a higher lifetime count adds kills to the feed (the
-- first read after login only sets the base).
local function refresh(countKills)
  local char = currentChar()
  if not char then return end
  local before = char.pvp
  local pvp = ns.Pvp.build(ns.PvpInfo.read(), before)
  local kills = countKills and ns.Pvp.newKills(before and before.hk, pvp and pvp.hk) or 0
  if not differs(before, pvp) then return end
  char.pvp = pvp
  char.updatedAt = GetServerTime() -- relays merge characters on updatedAt
  if kills > 0 then
    ns.FeedTracker.record(char, { { kind = "kills", zone = ns.SelfInfo.zone(), count = kills } })
    counterKills = counterKills + kills
    fallbackLater()
  end
  if pvp and pvp.rank ~= nil and pvp.rank ~= (before and before.rank) then
    bumpNow()
  elseif kills == 0 then
    ns.FeedTracker.changedLater()
  end
end

-- CF-55b: one raw kill of the current character. name nil: a kill the counter showed without an honor message.
local function recordKill(char, name, rank)
  local now = GetServerTime()
  local info = ns.Instance.info()
  local kill = { t = now, zone = ns.SelfInfo.zone(), name = name, rank = rank, myLvl = char.level,
                 solo = ns.PvpInfo.solo(), bg = info ~= nil and info.type == "pvp" }
  ns.FeedTracker.record(char, { { kind = "pvpKill", kill = ns.Pvp.killEntry(kill, ns.Pvp.recall(seen, name, now)) } })
end

-- Counter rises the honor messages didn't explain get entries without a victim.
local function fallback()
  local char = currentChar()
  local missing = counterKills - honorKills
  counterKills, honorKills = 0, 0
  if not char then return end
  for _ = 1, math.min(missing, ns.Pvp.MAX_KILLS_PER_CHANGE) do recordKill(char, nil, nil) end
end

-- Without a readable lifetime count, each honor message of a kill (the game's COMBATLOG_HONORGAIN) counts.
local function honor(text)
  local char = currentChar()
  if not char then return end
  rankNumbers = rankNumbers or ns.PvpInfo.rankNumbers()
  local victim, rank = ns.Pvp.victim(text, ns.PvpInfo.formats().honor, rankNumbers)
  local counted = char.pvp and char.pvp.hk ~= nil -- the counter fallback runs only with a readable counter
  if victim then
    if counted then honorKills = honorKills + 1 end
    recordKill(char, victim, rank)
  end
  if counted then return refresh(true) end
  if ns.GameText.parse(text, ns.PvpInfo.formats().honor) then
    ns.FeedTracker.record(char, { { kind = "kills", zone = ns.SelfInfo.zone(), count = 1 } })
  end
end

-- Adds a death or duel to the feed and the lifetime counters.
local function record(char, event, statDeaths)
  char.pvp = char.pvp or {}
  ns.Pvp.count(char.pvp, event, statDeaths)
  char.updatedAt = GetServerTime()
  ns.FeedTracker.record(char, { event })
end

local function died()
  local char = currentChar()
  if not char then return end
  local now = GetServerTime()
  local damage = lastDamage
  if not (damage and now - damage.at <= ns.Pvp.CAUSE_WINDOW) then
    local subevent, environment, sourceGuid = ns.PvpInfo.recapDamage()
    damage = ns.Pvp.damage(subevent, environment, nil, sourceGuid, now)
  end
  local cause = ns.Pvp.deathCause(damage, timers, now)
  lastDamage, timers = nil, {}
  record(char, { kind = "death", t = now, zone = ns.SelfInfo.zone(), cause = cause }, ns.PvpInfo.totalDeaths())
end

local function system(text)
  local duel = ns.Pvp.duel(text, ns.PvpInfo.formats(), ns.SelfInfo.fullName())
  local char = duel and currentChar()
  if not char then return end
  record(char, { kind = "duel", t = GetServerTime(), won = duel.won, vs = duel.vs })
end

local HANDLERS = {
  kills = function() refresh(true) end,
  honor = honor,
  dead = died,
  system = system,
  timerStart = function(name)
    if type(name) == "string" then timers[name] = { startedAt = GetServerTime() } end
  end,
  timerStop = function(name)
    if type(name) == "string" and timers[name] then timers[name].stoppedAt = GetServerTime() end
  end,
  unit = function(unit)
    local name, fields = ns.PvpInfo.enemy(unit)
    if name then ns.Pvp.remember(seen, name, fields, GetServerTime()) end
  end,
  damage = function(subevent, environment, sourceFlags, sourceGuid)
    lastDamage = ns.Pvp.damage(subevent, environment, sourceFlags, sourceGuid, GetServerTime()) or lastDamage
  end,
}

function PvpTracker.start(addon)
  addonRef = addon
  lastDamage, timers = nil, {}
  seen, rankNumbers, honorKills, counterKills = {}, nil, 0, 0
  fallbackLater = ns.Timer.debounce(ns.Pvp.FALLBACK_DELAY, fallback)
  PvpTracker.combatLog = ns.PvpInfo.watch(addon)
  addon:RegisterMessage(ns.PvpInfo.CHANGED, function(_, reason, ...)
    local handler = HANDLERS[reason]
    if handler then handler(...) end
  end)
  refresh(false)
end

ns.PvpTracker = PvpTracker
return PvpTracker
