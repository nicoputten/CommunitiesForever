-- PvpTracker: PvP counters, honorable kills by zone, deaths and duels of the own characters (CF-52).
-- Keeps `chars[guid].pvp` in the own record and adds the events to the activity feed (FeedTracker).
-- Counter changes travel with the feed's debounced bump; a new PvP rank bumps the version right away.
-- CF-55b: one pvpKills entry per honor message of a kill, its victim fields from the players seen shortly
-- before (target, mouseover, nameplates); kills the counter shows without an honor message get an entry
-- without a victim.
-- CF-110: Forever's honor message never names the victim (V73), so a counter rise picks the victim from the enemy
-- players looked at right then (Pvp.pickVictims: your target, mouseover or a nameplate, dead now and seen alive within
-- Pvp.KILL_WINDOW). A ticker keeps "seen alive" fresh during a fight. No fitting player: no victim, as before.
-- CF-117: the victim is often not dead yet at the rise (bug 13), so the rise remembers the candidates
-- (Pvp.killCandidates), the ticker and unit events keep looking at them (Pvp.observe), and Pvp.RECHECK_DELAY later a
-- last look picks (Pvp.resolveVictims: dead at once, dead after the delay, or the low health fallback).
local _, ns = ...

local PvpTracker = {}

local addonRef
-- The last damage taken ({ kind, at }, Pvp.damage) and the mirror timers ({ [name] = { startedAt, stoppedAt } }).
local lastDamage, timers = nil, {}
-- CF-55b: enemy players seen (Pvp.remember), the game's rank names, and the kills each source reported since
-- the counter last rose (the counter fallback compares them after Pvp.FALLBACK_DELAY).
local seen, rankNumbers, honorKills, counterKills, fallbackLater = {}, nil, 0, 0, nil
-- CF-110: enemy players by GUID with when they were last seen alive (Pvp.seeAlive), the victims picked at counter
-- rises since the fallback last ran, and the victims the honor messages named in that time.
local alive, picks, honorNames = {}, {}, {}
-- CF-117: the candidates of counter rises waiting for their re-check: { { pending, kills, bg } }.
local waiting = {}
-- CF-117: functions called with (victim or nil, path or nil, candidates) for each counter rise once resolved (the
-- launch probe's Hunt).
local resolvedFns = {}

-- CF-104: internal message (victimGuid, bg, victimName) for each victim picked at a kill counter rise (BattleEvents:
-- revenge; CF-121: avenge, the name for a friend's killer known only by name).
PvpTracker.VICTIM = "CF_PVP_VICTIM"

-- Seconds between looks at target, mouseover and nameplates for Pvp.seeAlive.
PvpTracker.LOOK_EVERY = 1

-- Remembers the enemy players seen alive and shows the looks to the rises waiting for their re-check.
local function see(looks, now)
  for _, look in ipairs(looks) do ns.Pvp.seeAlive(alive, look, now) end
  for _, wait in ipairs(waiting) do ns.Pvp.observe(wait.pending, looks, now) end
end

local function lookAround()
  see(ns.PvpInfo.looks(), GetServerTime())
end

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
    local info = ns.Instance.info()
    local wait = { pending = ns.Pvp.killCandidates(ns.PvpInfo.looks(), alive, GetServerTime()), kills = kills,
                   bg = info ~= nil and info.type == "pvp" }
    waiting[#waiting + 1] = wait
    ns.Timer.after(ns.Pvp.RECHECK_DELAY, function() PvpTracker.resolve(wait) end)
    fallbackLater()
  end
  if pvp and pvp.rank ~= nil and pvp.rank ~= (before and before.rank) then
    bumpNow()
  elseif kills == 0 then
    ns.FeedTracker.changedLater()
  end
end

-- CF-55b: one raw kill of the current character. name nil: a kill the counter showed without an honor message.
-- victim (CF-110): Pvp.pickVictims' entry, its fields instead of what was seen by name.
local function recordKill(char, name, rank, victim)
  local now = GetServerTime()
  local info = ns.Instance.info()
  local kill = { t = now, zone = ns.SelfInfo.zone(), name = name or (victim and victim.name), rank = rank,
                 myLvl = char.level, solo = ns.PvpInfo.solo(), bg = info ~= nil and info.type == "pvp" }
  ns.FeedTracker.record(char, { { kind = "pvpKill",
    kill = ns.Pvp.killEntry(kill, victim or ns.Pvp.recall(seen, name, now)) } })
end

-- Counter rises the honor messages didn't explain get entries with the victims picked at the rise (CF-110; one an
-- honor message already named is skipped), the rest without a victim.
local function fallback()
  local char = currentChar()
  local missing = counterKills - honorKills
  local victims = {}
  for _, victim in ipairs(picks) do
    if not (victim.name and honorNames[victim.name]) then victims[#victims + 1] = victim end
  end
  counterKills, honorKills, picks, honorNames = 0, 0, {}, {}
  if not char then return end
  for i = 1, math.min(missing, ns.Pvp.MAX_KILLS_PER_CHANGE) do recordKill(char, nil, nil, victims[i]) end
end

-- CF-117: a counter rise's re-check, Pvp.RECHECK_DELAY after it: one last look, then its victims (picks for the
-- feed entries, the VICTIM message for revenge) and the resolved functions. Before the fallback (Pvp.FALLBACK_DELAY).
function PvpTracker.resolve(wait)
  for i, w in ipairs(waiting) do
    if w == wait then table.remove(waiting, i) break end
  end
  local now = GetServerTime()
  local looks = ns.PvpInfo.looks()
  for _, look in ipairs(looks) do ns.Pvp.seeAlive(alive, look, now) end
  ns.Pvp.observe(wait.pending, looks, now, true)
  local victims = ns.Pvp.resolveVictims(wait.pending, wait.kills)
  for _, victim in ipairs(victims) do
    picks[#picks + 1] = victim
    addonRef:SendMessage(PvpTracker.VICTIM, victim.guid, wait.bg, victim.name)
  end
  for _, fn in ipairs(resolvedFns) do
    pcall(fn, victims[1], victims[1] and victims[1].path, #wait.pending.list)
  end
end

-- CF-117: fn(victim or nil, path or nil, candidates) runs once per counter rise when its victim is resolved.
function PvpTracker.onResolved(fn)
  resolvedFns[#resolvedFns + 1] = fn
end

-- Without a readable lifetime count, each honor message of a kill (the game's COMBATLOG_HONORGAIN or a variant,
-- PvpInfo.HONOR_FORMATS) counts.
local function honor(text)
  local char = currentChar()
  if not char then return end
  rankNumbers = rankNumbers or ns.PvpInfo.rankNumbers()
  local honors = ns.PvpInfo.formats().honors
  local victim, rank = ns.Pvp.victim(text, honors, rankNumbers)
  local counted = char.pvp and char.pvp.hk ~= nil -- the counter fallback runs only with a readable counter
  if victim then
    if counted then honorKills = honorKills + 1 end
    honorNames[victim] = true
    recordKill(char, victim, rank)
  end
  if counted then return refresh(true) end
  if ns.Pvp.honorArgs(text, honors) then
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
  -- CF-118: the opponent's class and level (your target) and the zone go to the Doomsday facts only: the feed keeps
  -- t, won and vs.
  local class, lvl = ns.PvpInfo.duelOpponent(duel.vs)
  record(char, { kind = "duel", t = GetServerTime(), won = duel.won, vs = duel.vs, zone = ns.SelfInfo.zone(),
                 oppClass = class, oppLvl = lvl })
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
    if not name then return end
    ns.Pvp.remember(seen, name, fields, GetServerTime())
    local look = ns.PvpInfo.look(unit, "unit")
    if look then see({ look }, GetServerTime()) end
  end,
  damage = function(subevent, environment, sourceFlags, sourceGuid)
    lastDamage = ns.Pvp.damage(subevent, environment, sourceFlags, sourceGuid, GetServerTime()) or lastDamage
  end,
}

function PvpTracker.start(addon)
  addonRef = addon
  lastDamage, timers = nil, {}
  seen, rankNumbers, honorKills, counterKills = {}, nil, 0, 0
  alive, picks, honorNames, waiting = {}, {}, {}, {}
  fallbackLater = ns.Timer.debounce(ns.Pvp.FALLBACK_DELAY, fallback)
  PvpTracker.combatLog = ns.PvpInfo.watch(addon)
  addon:RegisterMessage(ns.PvpInfo.CHANGED, function(_, reason, ...)
    local handler = HANDLERS[reason]
    if handler then handler(...) end
  end)
  ns.Timer.every(PvpTracker.LOOK_EVERY, lookAround)
  refresh(false)
end

ns.PvpTracker = PvpTracker
return PvpTracker
