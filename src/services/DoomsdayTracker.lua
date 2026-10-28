-- DoomsdayTracker: the own Doomsday goals (CF-56). Counts facts per Doomsday day and week from what the own
-- characters do (FeedTracker passes every feed event here; snapshot changes add item level and professions),
-- marks goals done as soon as Doomsday says so, and keeps the reset setting (runs file, friends' HELLO).
-- Local: self.doomsday = { days = { [n] = facts }, weeks = { [w] = facts }, chars = { [guid] = { death, level } } }.
-- Sent: self.goals = { days = { [n] = { set, swapped, done, at } }, weeks = { ... }, streak = { n, last }, best }.
local _, ns = ...

local DoomsdayTracker = {}

-- Internal message, sent when a goal got done or the day turned (the window refreshes).
DoomsdayTracker.CHANGED = "CF_DOOMSDAY_CHANGED"

local addonRef, events

local function global() return addonRef.db.global end
local function own() return global().self end

local function store()
  local s = own()
  s.doomsday = s.doomsday or {}
  s.doomsday.days = s.doomsday.days or {}
  s.doomsday.weeks = s.doomsday.weeks or {}
  s.doomsday.chars = s.doomsday.chars or {}
  s.goals = s.goals or {}
  s.goals.days = s.goals.days or {}
  s.goals.weeks = s.goals.weeks or {}
  return s.doomsday, s.goals
end

-- ===== Schedule =====

-- The reset setting in use (settings.doomsdayReset; nil: 19:00 and CET/CEST).
function DoomsdayTracker.setting()
  return addonRef and global().settings.doomsdayReset or nil
end

-- A setting from the runs file or a friend's HELLO: the newer one is kept. Returns true when it changed.
function DoomsdayTracker.receiveSetting(raw)
  if not addonRef then return false end
  local incoming = ns.Goals.cleanSetting(raw)
  local current = DoomsdayTracker.setting()
  local newer = ns.Goals.newerSetting(current, incoming)
  if newer == current then return false end
  global().settings.doomsdayReset = newer
  return true
end

-- { reset, offset, source } now.
function DoomsdayTracker.schedule()
  local now = GetServerTime()
  local hour, minute = ns.SelfInfo.gameTime()
  return ns.Goals.schedule(DoomsdayTracker.setting(), ns.Doomsday.realmOffset(hour, minute, now), now)
end

function DoomsdayTracker.today()
  local s = DoomsdayTracker.schedule()
  return ns.Doomsday.day(GetServerTime(), s.offset, s.reset), s
end

-- ===== Who is who =====

-- Friend keys (BattleTags) by character GUID and by full name, other people only.
local function owners()
  local byGuid, byName = {}, {}
  local mine = own().battleTag
  for bt, person in pairs(global().people or {}) do
    if bt ~= mine then
      for guid, c in pairs(person.chars or {}) do
        byGuid[guid] = bt
        if type(c.name) == "string" then byName[c.name] = bt end
      end
    end
  end
  for guid, link in pairs(global().presence or {}) do
    if link.battleTag and link.battleTag ~= mine and not byGuid[guid] then byGuid[guid] = link.battleTag end
  end
  return byGuid, byName
end

local function communityNames()
  local names = {}
  local ok, members = pcall(ns.MemberTracker.members)
  for _, m in pairs(ok and members or {}) do
    if type(m.name) == "string" then names[m.name] = true end
  end
  return names
end

local function friendQuestLog()
  local mine = own().battleTag
  for bt, person in pairs(global().people or {}) do
    if bt ~= mine then
      for _, c in pairs(person.chars or {}) do
        if type(c.quests) == "table" and next(c.quests) then return true end
      end
    end
  end
  return false
end

local function dungeonInRange()
  for _, c in pairs(own().chars or {}) do
    for _, d in ipairs(ns.Dungeons.LIST or {}) do
      if type(c.level) == "number" and c.level >= d.min and c.level <= d.max then return true end
    end
  end
  return false
end

-- Factions of the own characters, for the bounty's enemy lists.
local function factions()
  local seen, list = {}, {}
  for _, c in pairs(own().chars or {}) do
    if (c.faction == "Horde" or c.faction == "Alliance") and not seen[c.faction] then
      seen[c.faction] = true
      list[#list + 1] = c.faction
    end
  end
  table.sort(list)
  return list
end

-- ===== Goals of the day and week =====

local function factsFor(map, key)
  map[key] = map[key] or ns.Goals.newFacts()
  return map[key]
end

-- The day's goals entry, made once per day (a swap is fixed for the day once made).
local function dayEntry(n)
  local facts, goals = store()
  local entry = goals.days[n]
  if entry then return entry end
  local f = factsFor(facts.days, n)
  local situation = ns.Goals.situation(own().chars, f.chars, friendQuestLog(), dungeonInRange())
  local drawn = ns.Doomsday.goalsForDay(n, situation)
  local set = drawn.set
  if drawn.hunt then set[#set + 1] = "hunt" end
  entry = { set = set, swapped = drawn.swapped, done = {}, at = GetServerTime() }
  goals.days[n] = entry
  f.zone, f.hunts = drawn.zone, drawn.hunt
  return entry
end

local function weekEntry(w)
  local facts, goals = store()
  local entry = goals.weeks[w]
  if entry then return entry end
  local situation = ns.Goals.situation(own().chars, nil, friendQuestLog(), dungeonInRange())
  local drawn = ns.Doomsday.goalsForWeek(w, situation)
  entry = { set = drawn.set, swapped = drawn.swapped, done = {}, at = GetServerTime() }
  goals.weeks[w] = entry
  factsFor(facts.weeks, w).zone = drawn.zone
  return entry
end

local function huntList(hunts)
  if not hunts then return nil end
  local list = {}
  for _, f in ipairs(factions()) do
    if hunts[f] then list[#list + 1] = hunts[f] end
  end
  return list
end

-- Progress of goal id on facts f, with the schedule and lists it needs.
local function progressOf(f, schedule, community, hunts)
  local pf = ns.Goals.progressFacts(f, { schedule = schedule, community = community, zone = f.zone,
                                         hunts = huntList(hunts), factions = factions() })
  return function(id) return ns.Doomsday.progress(id, pf) end
end

-- The streak and the best from the own days.
local function updateStreak(today)
  local _, goals = store()
  local counts = {}
  for n, e in pairs(goals.days) do
    local c = 0
    for _ in pairs(e.done or {}) do c = c + 1 end
    counts[n] = c
  end
  local streak, best = ns.Doomsday.streak(counts, today, goals.best)
  goals.streak, goals.best = { n = streak, last = today }, best
end

-- Checks today's and this week's goals; a goal done bumps the version (debounced) and tells the window.
local function evaluate()
  local today, schedule = DoomsdayTracker.today()
  local week = ns.Doomsday.week(today)
  local facts = store()
  local community = communityNames()
  local day, wk = dayEntry(today), weekEntry(week)
  local df, wf = factsFor(facts.days, today), factsFor(facts.weeks, week)
  local newly = ns.Goals.mark(day, progressOf(df, schedule, community, df.hunts), GetServerTime())
  for _, id in ipairs(newly) do
    if id == "hunt" then ns.Goals.observe(wf, { kind = "hunt", day = today }) end
  end
  local weekly = ns.Goals.mark(wk, progressOf(wf, schedule, community), GetServerTime())
  updateStreak(today)
  ns.Goals.prune(facts.days, today, ns.Goals.KEEP_DAYS)
  ns.Goals.prune(facts.weeks, week, ns.Goals.KEEP_WEEKS)
  local _, goals = store()
  ns.Goals.prune(goals.days, today, ns.Goals.KEEP_DAYS)
  ns.Goals.prune(goals.weeks, week, ns.Goals.KEEP_WEEKS)
  if #newly + #weekly > 0 then
    ns.FeedTracker.changedLater()
    addonRef:SendMessage(DoomsdayTracker.CHANGED, newly, weekly)
  end
  return newly, weekly
end

-- ===== Observations =====

-- Adds an observation to today's and this week's facts.
local function observe(obs)
  local today = DoomsdayTracker.today()
  local facts = store()
  ns.Goals.observe(factsFor(facts.days, today), obs, ns.Goals.MAX_KILLS)
  ns.Goals.observe(factsFor(facts.weeks, ns.Doomsday.week(today)), obs, ns.Goals.MAX_WEEK_KILLS)
end

local function highestOther(guid)
  local best
  for g, c in pairs(own().chars or {}) do
    if g ~= guid and type(c.level) == "number" and (not best or c.level > best) then best = c.level end
  end
  return best
end

-- Feed events of an own character (FeedTracker.record), translated into facts.
local function fromFeed(char, list)
  local byGuid, byName = owners()
  local state = store().chars
  local now = GetServerTime()
  for _, e in ipairs(list) do
    local k = e.kind
    if k == "quest" then
      observe({ kind = "quest", zone = e.zone })
    elseif k == "level" and type(e.from) == "number" and type(e.to) == "number" and e.to > e.from then
      local cs = state[char.guid] or {}
      state[char.guid] = cs
      local other = highestOther(char.guid)
      local clean = (cs.death or 0) <= (cs.level or 0) or cs.level == nil
      observe({ kind = "level", guid = char.guid, count = e.to - e.from, alt = other ~= nil and e.to <= other,
                clean = clean and cs.level ~= nil })
      cs.level = now
    elseif k == "learned" then
      observe({ kind = "learned" })
    elseif k == "run" and e.instance == "party" then
      local friends = {}
      for _, guid in ipairs(e.with or {}) do
        if byGuid[guid] then friends[byGuid[guid]] = true end
      end
      local n = 0
      for _ in pairs(friends) do n = n + 1 end
      observe({ kind = "run", name = e.name, bosses = e.bosses, friends = n })
    elseif k == "pvpKill" then
      observe({ kind = "kill", kill = e.kill, char = char.guid })
    elseif k == "death" then
      state[char.guid] = state[char.guid] or {}
      state[char.guid].death = e.t or now
      observe({ kind = "death", t = e.t or now, char = char.guid })
    elseif k == "duel" then
      observe({ kind = "duel", friend = byName[e.vs] })
    elseif k == "rare" then
      observe({ kind = "rare", count = e.count })
    elseif k == "epic" then
      observe({ kind = "rare", count = 1 }) -- "rare or better"
    elseif k == "group" then
      observe({ kind = "group", friend = byGuid[e.guid] })
    elseif k == "session" and type(e.from) == "number" then
      local t = date and date("*t", e.from)
      if t and t.hour < 9 then observe({ kind = "earlyBird" }) end -- your own clock (DOOMSDAY.md d.earlyBird)
    end
  end
end

-- The current character as it is now: login, item level, professions, the session so far, shared quests.
local function fromSnapshot()
  local guid = ns.SelfInfo.guid()
  local char = guid and own().chars[guid]
  if not char then return end
  local today = DoomsdayTracker.today()
  local profs = {}
  for line, p in pairs(char.professions or {}) do profs[line] = { rank = p.rank, max = p.max } end
  observe({ kind = "char", guid = guid, ilvl = char.ilvl, professions = profs, day = today })
  local session = ns.Play.last(own().feed, guid)
  if session then observe({ kind = "session", seconds = (session.to or 0) - (session.from or 0) }) end
  -- d.shared3: the most quests this character's log shares with one friend's synced logs.
  local mine, best = char.quests or {}, 0
  local mineBt = own().battleTag
  for bt, person in pairs(global().people or {}) do
    if bt ~= mineBt then
      local shared = {}
      for _, c in pairs(person.chars or {}) do
        for id in pairs(c.quests or {}) do
          if mine[id] then shared[id] = true end
        end
      end
      local n = 0
      for _ in pairs(shared) do n = n + 1 end
      best = math.max(best, n)
    end
  end
  if best > 0 then observe({ kind = "shared", count = best }) end
end

-- CF-56's local trackers (fishing, trades, discoveries; crafted items from PlayTracker), for goals that join
-- a later pool once their APIs are verified. Not sent on their own: only a goal done is.
local function fromGoalEvent(reason, a, b)
  if reason == "fish" then
    observe({ kind = "fish", count = a })
  elseif reason == "trade" then
    local byGuid = owners()
    observe({ kind = "trade", friend = byGuid[a], items = b })
  elseif reason == "discovered" then
    for _, format in ipairs(ns.GoalEvents.formats()) do
      if ns.GameText.parse(a, format) then
        observe({ kind = "discovery" })
        break
      end
    end
  end
end

-- An item one of the own characters created (PlayTracker's loot messages).
function DoomsdayTracker.observeCrafted(id)
  if not addonRef then return end
  observe({ kind = "crafted", id = id })
end

-- ===== Public =====

-- Called by FeedTracker.record for every batch of own feed events.
function DoomsdayTracker.observeFeed(char, list)
  if not addonRef or not char or not char.guid then return end
  fromFeed(char, list)
  evaluate()
end

-- The goals for RECORD (Goals.outgoing), or nil before start.
function DoomsdayTracker.outgoing()
  if not addonRef then return nil end
  local today, schedule = DoomsdayTracker.today()
  local _, goals = store()
  return ns.Goals.outgoing(goals, today, ns.Doomsday.week(today), ns.Doomsday.POOL_VERSION, schedule.reset)
end

--[[ What /cf doomsday prints and the tab shows: { day, week, label, resetsIn, source, today = entry,
week = entry, progress = { [id] = { value, target, done } }, weekProgress, streak, best, points = { pve, pvp } } ]]
function DoomsdayTracker.state()
  if not addonRef then return nil end
  local today, schedule = DoomsdayTracker.today()
  local week = ns.Doomsday.week(today)
  local facts, goals = store()
  local day, wk = dayEntry(today), weekEntry(week)
  local community = communityNames()
  local df, wf = factsFor(facts.days, today), factsFor(facts.weeks, week)
  local dayProgress, weekProgress = progressOf(df, schedule, community, df.hunts), progressOf(wf, schedule, community)
  local function list(entry, fn)
    local result = {}
    for _, id in ipairs(entry.set) do
      local value, target, done = fn(id)
      result[id] = { value = value, target = target, done = entry.done[id] ~= nil or done }
    end
    return result
  end
  -- This week's points: the days of this week and the week's goals, plus this week's kill points.
  local done = {}
  for n, e in pairs(goals.days) do
    if ns.Doomsday.week(n) == week then
      for id, at in pairs(e.done or {}) do done[n .. ":" .. id] = at end
    end
  end
  local points = { pve = 0, pvp = 0 }
  for key in pairs(done) do
    local track, p = ns.Doomsday.goalPoints(key:match(":(.+)$"))
    if track then points[track] = points[track] + p end
  end
  for id in pairs(wk.done) do
    local track, p = ns.Doomsday.goalPoints(id)
    if track then points[track] = points[track] + p end
  end
  for _, s in ipairs(ns.Doomsday.scoreKills(wf.kills, schedule, community)) do
    if s.track == "pvp" then points.pvp = points.pvp + s.points end
  end
  return { day = today, week = week, label = ns.Doomsday.label(today),
           resetsIn = ns.Doomsday.resetsIn(GetServerTime(), schedule.offset, schedule.reset), source = schedule.source,
           today = day, thisWeek = wk, progress = list(day, dayProgress), weekProgress = list(wk, weekProgress),
           streak = goals.streak and goals.streak.n or 0, best = goals.best or 0, points = points }
end

function DoomsdayTracker.start(addon)
  addonRef = addon
  store()
  DoomsdayTracker.receiveSetting(ns.RunsFile.doomsday())
  events = events or LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function()
    fromSnapshot()
    evaluate()
  end)
  ns.GoalEvents.watch(addon)
  events:RegisterMessage(ns.GoalEvents.CHANGED, function(_, reason, a, b)
    fromGoalEvent(reason, a, b)
    evaluate()
  end)
  fromSnapshot()
  evaluate()
end

ns.DoomsdayTracker = DoomsdayTracker
return DoomsdayTracker
