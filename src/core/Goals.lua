-- Goals: the own Doomsday goals tracked and shared (CF-56). Pure Lua, no WoW globals. Requires ns.Doomsday.
-- Facts are counted live per Doomsday day and week (the feed is cut at realm midnight, a Doomsday day at the
-- reset) and kept locally (self.doomsday); only the goals with their `done` times travel (RECORD `goals`).
local _, ns = ...

local Goals = {}

Goals.KEEP_DAYS = 14   -- stored days and weeks of the own goals and facts
Goals.KEEP_WEEKS = 2
Goals.SEND_DAYS = 7    -- sent in RECORD: the last 7 days, this and last week
Goals.MAX_SET_DAY = 5  -- 3 PvE dailies, the Skirmish, the Hunt
Goals.MAX_SET_WEEK = 4 -- 3 PvE weeklies, the Bounty
Goals.MAX_ID = 24
Goals.MAX_KILLS = 300  -- kills kept per day (a week keeps 1000)
Goals.MAX_WEEK_KILLS = 1000

-- Bosses per dungeon for w.fullClear (by the instance name the feed stores), from the game's DungeonEncounter
-- table (Classic Era, checked 2026-10-28). Dungeons with wings or optional bosses there (Scarlet Monastery,
-- Blackrock Spire, Dire Maul, Stratholme, Scholomance, Blackfathom Deeps, Sunken Temple) wait for counts from
-- launch (VERIFY.md CF-56). Changing it needs an addon release.
Goals.BOSSES = {
  ["Ragefire Chasm"] = 4, ["Wailing Caverns"] = 8, ["The Deadmines"] = 7, ["Deadmines"] = 7,
  ["Shadowfang Keep"] = 8, ["The Stockade"] = 5, ["Stormwind Stockade"] = 5, ["Gnomeregan"] = 5,
  ["Razorfen Kraul"] = 6, ["Razorfen Downs"] = 6, ["Uldaman"] = 8, ["Zul'Farrak"] = 8, ["Maraudon"] = 8,
  ["Blackrock Depths"] = 21,
}

-- Profession skill lines (as GetProfessionInfo gives them).
local SECONDARY = { [185] = true, [129] = true, [356] = true } -- Cooking, First Aid, Fishing
local FISHING = 356
local CRAFTING = { [171] = true, [164] = true, [333] = true, [202] = true, [165] = true, [197] = true }
local CAPS = { [75] = true, [150] = true, [225] = true, [300] = true }

-- ===== The schedule: realm offset and the reset setting =====

-- Last Sunday of a month (day of month).
local function lastSunday(year, month)
  local days = month == 2 and ((year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) and 29 or 28)
    or ((month == 4 or month == 6 or month == 9 or month == 11) and 30 or 31)
  local n = ns.Doomsday.dayNumberOf(year, month, days)
  return days - (n + 4) % 7 -- (n + 4) % 7 is the weekday, 0 = Sunday
end

-- CET/CEST (Europe/Paris) at a server time: +2 h from the last Sunday of March 01:00 UTC to the last Sunday of
-- October 01:00 UTC, else +1 h. The last fallback when neither the game clock nor the site gives the offset.
function Goals.cetOffset(serverTime)
  local year = ns.Doomsday.civil(math.floor(serverTime / 86400))
  local from = ns.Doomsday.dayNumberOf(year, 3, lastSunday(year, 3)) * 86400 + 3600
  local to = ns.Doomsday.dayNumberOf(year, 10, lastSunday(year, 10)) * 86400 + 3600
  return (serverTime >= from and serverTime < to) and 7200 or 3600
end

local function number(v, min, max)
  if type(v) ~= "number" or v ~= v or v < min or v > max then return nil end
  return math.floor(v)
end

--[[ The reset setting from the runs file or a friend's HELLO, cleaned: { reset, changedAt, offset, offsetUntil,
offsetAfter } (docs/DOOMSDAY.md "Schedule"). reset: seconds after realm midnight (0 to 86399); changedAt: when it
took effect (0: never changed); offset: the realm zone's UTC offset now (seconds east), until offsetUntil, then
offsetAfter. Every field optional; nil when nothing is usable. ]]
function Goals.cleanSetting(raw)
  if type(raw) ~= "table" then return nil end
  local s = {
    reset = number(raw.reset, 0, 86399),
    changedAt = number(raw.changedAt, 0, 1e11),
    offset = number(raw.offset, -50400, 50400),
    offsetUntil = number(raw.offsetUntil, 0, 1e11),
    offsetAfter = number(raw.offsetAfter, -50400, 50400),
  }
  if s.offset == nil then s.offsetUntil, s.offsetAfter = nil, nil end
  return next(s) and s or nil
end

-- The newer of two settings: the later changedAt; on equal times the one with an offset change further out
-- (fresher offset data). nil-safe.
function Goals.newerSetting(a, b)
  if not a then return b end
  if not b then return a end
  if (b.changedAt or 0) ~= (a.changedAt or 0) then return (b.changedAt or 0) > (a.changedAt or 0) and b or a end
  return (b.offsetUntil or 0) > (a.offsetUntil or 0) and b or a
end

--[[ The schedule to use at serverTime: { reset, offset, source }. offset: from the game clock (gameOffset, nil
when not readable), else the setting's offset (offsetAfter once offsetUntil has passed), else CET/CEST. ]]
function Goals.schedule(setting, gameOffset, serverTime)
  setting = setting or {}
  local offset, source = gameOffset, "game"
  if offset == nil and setting.offset ~= nil then
    source = "site"
    offset = setting.offset
    if setting.offsetUntil and setting.offsetAfter and serverTime >= setting.offsetUntil then
      offset = setting.offsetAfter
    end
  end
  if offset == nil then offset, source = Goals.cetOffset(serverTime), "cet" end
  return { reset = setting.reset or ns.Doomsday.DEFAULT_RESET, offset = offset, source = source }
end

-- ===== Facts =====

-- Empty facts of one day or week.
function Goals.newFacts()
  return { quests = {}, levels = 0, altLevels = 0, altByChar = {}, cleanLevels = 0, ilvlBase = {}, ilvlGain = 0,
           runs = {}, skillBase = {}, skill = 0, secondary = false, learned = 0, capReached = false, chars = {},
           days = {}, friends = {}, rare = 0, earlyBird = false, longestSession = 0, kills = {}, deaths = {},
           duelFriends = {}, sharedMax = 0, huntDays = {}, fish = 0, trades = 0, crafted = {}, craftTrade = 0,
           discoveries = 0 }
end

local function push(list, item, max)
  if #list < max then list[#list + 1] = item end
end

--[[ Adds one observation to facts (in place). obs:
  { kind = "quest", zone } | { kind = "level", guid, count, alt (not your highest), clean (no death since the
  previous level) } | { kind = "run", name, bosses, friends } | { kind = "learned" }
  | { kind = "char", guid, ilvl, professions = { [skillLine] = { rank, max } }, day } (seen: login, a change)
  | { kind = "group", friend } | { kind = "rare", count } | { kind = "earlyBird" } | { kind = "session", seconds }
  | { kind = "kill", kill (a pvpKills entry), char } | { kind = "death", t, char } | { kind = "duel", friend }
  | { kind = "shared", count } | { kind = "hunt", day }
  | { kind = "fish", count } | { kind = "crafted", id } | { kind = "trade", friend, items = { itemID, ... } }
  | { kind = "discovery" } (CF-56's local trackers for goals that wait for data)
maxKills: the kill list's cap. ]]
function Goals.observe(f, obs, maxKills)
  local k = obs.kind
  if k == "quest" then
    local zone = obs.zone or "Other"
    f.quests[zone] = (f.quests[zone] or 0) + 1
  elseif k == "level" then
    local n = obs.count or 1
    f.levels = f.levels + n
    if obs.alt then
      f.altLevels = f.altLevels + n
      f.altByChar[obs.guid] = (f.altByChar[obs.guid] or 0) + n
    end
    if obs.clean then f.cleanLevels = f.cleanLevels + n end
  elseif k == "run" then
    local full = Goals.BOSSES[obs.name or ""]
    local run = { name = obs.name, bosses = obs.bosses or 0, friends = obs.friends or 0 }
    if full then run.fullClear = run.bosses >= full end -- nil: no boss count for that dungeon yet
    push(f.runs, run, 50)
  elseif k == "learned" then
    f.learned = f.learned + 1
  elseif k == "char" then
    f.chars[obs.guid] = true
    if obs.day then f.days[obs.day] = true end
    if type(obs.ilvl) == "number" then
      local base = f.ilvlBase[obs.guid]
      if base == nil then f.ilvlBase[obs.guid] = obs.ilvl else f.ilvlGain = math.max(f.ilvlGain, obs.ilvl - base) end
    end
    if type(obs.professions) == "table" then
      local base = f.skillBase[obs.guid]
      if base == nil then
        base = {}
        for line, p in pairs(obs.professions) do base[line] = p.rank or 0 end
        f.skillBase[obs.guid] = base
      else
        for line, p in pairs(obs.professions) do
          local was = base[line]
          local rank = p.rank or 0
          if was == nil then
            base[line] = 0 -- learned now: its points from 0 count
            was = 0
            if SECONDARY[line] then f.secondary = true end
          end
          if rank > was then
            f.skill = f.skill + (rank - was)
            if SECONDARY[line] then f.secondary = true end
            if CAPS[rank] and rank == p.max then f.capReached = true end
            base[line] = rank
          end
        end
      end
    end
  elseif k == "group" then
    if obs.friend then f.friends[obs.friend] = true end
  elseif k == "rare" then
    f.rare = f.rare + (obs.count or 1)
  elseif k == "earlyBird" then
    f.earlyBird = true
  elseif k == "session" then
    f.longestSession = math.max(f.longestSession, obs.seconds or 0)
  elseif k == "kill" then
    local kill = {}
    for key, v in pairs(obs.kill or {}) do kill[key] = v end
    kill.char = obs.char
    push(f.kills, kill, maxKills or Goals.MAX_KILLS)
  elseif k == "death" then
    push(f.deaths, { t = obs.t, char = obs.char }, maxKills or Goals.MAX_KILLS)
  elseif k == "duel" then
    if obs.friend then f.duelFriends[obs.friend] = true end
  elseif k == "shared" then
    f.sharedMax = math.max(f.sharedMax, obs.count or 0)
  elseif k == "hunt" then
    f.huntDays[obs.day] = true
  elseif k == "fish" then
    f.fish = (f.fish or 0) + (obs.count or 1)
  elseif k == "crafted" then
    f.crafted = f.crafted or {}
    if obs.id then f.crafted[obs.id] = true end
  elseif k == "trade" then
    if obs.friend then
      f.trades = (f.trades or 0) + 1
      for _, id in ipairs(obs.items or {}) do
        if f.crafted and f.crafted[id] then
          f.craftTrade = (f.craftTrade or 0) + 1
          break
        end
      end
    end
  elseif k == "discovery" then
    f.discoveries = (f.discoveries or 0) + 1
  end
end

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

--[[ Facts as Doomsday.progress reads them. ctx = { schedule, community = { [name] = true }, zone, hunts,
factions }. ]]
function Goals.progressFacts(f, ctx)
  ctx = ctx or {}
  local best = 0
  for _, n in pairs(f.altByChar or {}) do best = math.max(best, n) end
  return {
    quests = f.quests, sharedMax = f.sharedMax, levels = f.levels, altLevels = f.altLevels, altLevelsMax = best,
    cleanLevels = f.cleanLevels, ilvlGain = f.ilvlGain, runs = f.runs, skill = f.skill, secondary = f.secondary,
    learned = f.learned, capReached = f.capReached, chars = count(f.chars), days = count(f.days),
    groupFriends = count(f.friends), rare = f.rare, earlyBird = f.earlyBird, longestSession = f.longestSession,
    scored = ns.Doomsday.scoreKills(f.kills, ctx.schedule, ctx.community), deaths = f.deaths, zone = ctx.zone,
    hunts = ctx.hunts, huntDays = count(f.huntDays), duelFriends = count(f.duelFriends), factions = ctx.factions,
    fish = f.fish, trades = f.trades, craftTrade = f.craftTrade, discoveries = f.discoveries,
  }
end

-- ===== The situation for swaps =====

--[[ A friend's situation from their characters (Doomsday.goalsForDay): chars = { { level, ilvl, professions =
{ [skillLine] = { rank, max } } } }, playedToday = { [guid] = true }, friendQuestLog (bool), dungeonInRange
(bool, from the dungeon list). ]]
function Goals.situation(chars, playedToday, friendQuestLog, dungeonInRange)
  local s = { chars = 0, below60 = 0, altBelow60 = 0, ilvlReadable = false, hasProfession = false,
              hasFishing = false, hasCraftingProfession = false, professionBelow300 = false,
              friendQuestLog = friendQuestLog == true, dungeonInRange = dungeonInRange ~= false }
  local highestGuid
  for guid, c in pairs(chars or {}) do
    s.chars = s.chars + 1
    local level = c.level or 0
    if not s.highest or level > s.highest then s.highest, highestGuid = level, guid end
    if playedToday and playedToday[guid] and (not s.highestToday or level > s.highestToday) then
      s.highestToday = level
    end
    if c.ilvl ~= nil then s.ilvlReadable = true end
    for line, p in pairs(c.professions or {}) do
      if not SECONDARY[line] then s.hasProfession = true end
      if line == FISHING then s.hasFishing = true end
      if CRAFTING[line] then s.hasCraftingProfession = true end
      if (p.rank or 0) < 300 then s.professionBelow300 = true end
    end
  end
  for guid, c in pairs(chars or {}) do
    if (c.level or 0) < 60 then
      s.below60 = s.below60 + 1
      if guid ~= highestGuid then s.altBelow60 = s.altBelow60 + 1 end
    end
  end
  return s
end

-- ===== Goals: set, done, merge =====

--[[ Marks done goals (in place): entry = { set, swapped, done = { [id] = at }, at }; progress(id) returns
value, target, done. Returns the ids newly done. ]]
function Goals.mark(entry, progress, now)
  local newly = {}
  entry.done = entry.done or {}
  for _, id in ipairs(entry.set or {}) do
    if not entry.done[id] then
      local _, _, done = progress(id)
      if done then
        entry.done[id] = now
        newly[#newly + 1] = id
      end
    end
  end
  if #newly > 0 then entry.at = now end
  return newly
end

-- Drops days and weeks older than kept (in place): table keyed by day or week number.
function Goals.prune(map, newest, keep)
  for n in pairs(map or {}) do
    if type(n) ~= "number" or n <= newest - keep or n > newest + 1 then map[n] = nil end
  end
end

local function cleanId(id)
  if type(id) ~= "string" or #id > Goals.MAX_ID or not id:match("^[%w%.]+$") then return nil end
  return id
end

local function cleanEntry(e, maxSet)
  if type(e) ~= "table" then return nil end
  local set = {}
  for _, id in ipairs(type(e.set) == "table" and e.set or {}) do
    if #set >= maxSet then break end
    local clean = cleanId(id)
    if clean then set[#set + 1] = clean end
  end
  local swapped, done = {}, {}
  for new, old in pairs(type(e.swapped) == "table" and e.swapped or {}) do
    if cleanId(new) and cleanId(old) and count(swapped) < maxSet then swapped[new] = old end
  end
  for id, at in pairs(type(e.done) == "table" and e.done or {}) do
    local t = number(at, 0, 1e11)
    if cleanId(id) and t and count(done) < maxSet then done[id] = t end
  end
  return { set = set, swapped = swapped, done = done, at = number(e.at, 0, 1e11) or 0 }
end

local function cleanMap(map, maxEntries, maxSet)
  local result, n = {}, 0
  if type(map) ~= "table" then return result end
  for key, e in pairs(map) do
    local k = number(key, 0, 1e7)
    if k and k == key and n < maxEntries then
      local clean = cleanEntry(e, maxSet)
      if clean then
        result[k] = clean
        n = n + 1
      end
    end
  end
  return result
end

--[[ Copy of received `goals` with only the expected fields, or nil (CF-58: `false` from an older client and a
missing field both mean nothing sent). { days = { [n] = entry }, weeks = { [w] = entry }, streak, best, pool,
reset }; ids at most 24 characters, 5 per day and 4 per week, 7 days and 2 weeks, numbers >= 0. Ids of a newer
pool are kept. ]]
function Goals.clean(goals)
  if type(goals) ~= "table" then return nil end
  return {
    days = cleanMap(goals.days, Goals.SEND_DAYS, Goals.MAX_SET_DAY),
    weeks = cleanMap(goals.weeks, Goals.KEEP_WEEKS, Goals.MAX_SET_WEEK),
    streak = number(goals.streak, 0, 1e5),
    best = number(goals.best, 0, 1e5),
    pool = number(goals.pool, 0, 1e4),
    reset = number(goals.reset, 0, 86399),
  }
end

-- Merges cleaned goals (also for relay): per day and week the entry with the newer `at` wins (equal: the stored
-- one), the other fields from the newer side by its newest `at`. maxAt: incoming entries later are ignored.
function Goals.merge(stored, incoming, maxAt)
  if not incoming then return stored end
  if not stored then return incoming end
  local function newest(g)
    local t = 0
    for _, map in ipairs({ g.days or {}, g.weeks or {} }) do
      for _, e in pairs(map) do t = math.max(t, e.at or 0) end
    end
    return t
  end
  local result = { days = {}, weeks = {} }
  for _, part in ipairs({ "days", "weeks" }) do
    for n, e in pairs(stored[part] or {}) do result[part][n] = e end
    for n, e in pairs(incoming[part] or {}) do
      local have = result[part][n]
      local future = maxAt and (e.at or 0) > maxAt
      if not future and (not have or (e.at or 0) > (have.at or 0)) then result[part][n] = e end
    end
  end
  local from = newest(incoming) > newest(stored) and incoming or stored
  result.streak, result.best, result.pool, result.reset = from.streak, from.best, from.pool, from.reset
  return result
end

-- The own goals as RECORD sends them: the last SEND_DAYS days up to today, this and last week.
function Goals.outgoing(goals, today, week, pool, reset)
  if type(goals) ~= "table" then return nil end
  local days, weeks = {}, {}
  for n, e in pairs(goals.days or {}) do
    if n > today - Goals.SEND_DAYS and n <= today then days[n] = e end
  end
  for w, e in pairs(goals.weeks or {}) do
    if w >= week - 1 and w <= week then weeks[w] = e end
  end
  return { days = days, weeks = weeks, streak = goals.streak and goals.streak.n or 0, best = goals.best or 0,
           pool = pool, reset = reset }
end

ns.Goals = Goals
return Goals
