-- Feed: the activity feed (CF-22). Pure Lua, no WoW globals.
-- Each client records what its own characters did, aggregated per realm day and character, and syncs
-- it with its record (field `feed`). The window shows one line per person per day.
local _, ns = ...

local Feed = {}

Feed.KEEP_DAYS = 7  -- today and the 6 days before
Feed.MAX_PARTS = 3  -- parts on a line before "+N"
Feed.MILESTONES = { 10, 20, 40, 60 }
-- Profession max skill -> rank name (single-tier Vanilla professions).
Feed.RANKS = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

local WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- Limits for received feeds (a modified addon must not blow up the saved variables or the window).
local MAX_TEXT = 40
local MAX_CHARS_PER_DAY = 50
local MAX_ZONES = 20
local MAX_PROFESSIONS = 10
local MAX_COUNT = 1000
local MAX_RUNS = 30        -- CF-23: dungeon, raid and battleground runs per character and day
local MAX_COMPANIONS = 40
local MAX_BOSSES = 40
local RUN_KINDS = { party = true, raid = true, pvp = true }

-- Day number (days since 1970-01-01) of a calendar date. Pure, so days compare and subtract easily.
function Feed.dayNumber(year, month, day)
  -- Days from civil (Howard Hinnant's algorithm).
  local y = month <= 2 and year - 1 or year
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local m = month <= 2 and month + 9 or month - 3
  local doy = math.floor((153 * m + 2) / 5) + day - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- "Today", "Yesterday", or the weekday name for older days.
function Feed.dayLabel(day, today)
  if day == today then return "Today" end
  if day == today - 1 then return "Yesterday" end
  return WEEKDAYS[(day + 4) % 7 + 1] -- day 0 (1970-01-01) was a Thursday
end

--[[ Events from the difference between the stored and the new snapshot of the current character:
  { kind = "level", from, to } | { kind = "rank", name, rank } | { kind = "learned", name }
before nil (first snapshot of this character): no events. A rank event needs the max skill to go up to
a known rank. From no professions at all only a single new one counts as learned: several appearing at
once means they could not be read before (login), not that they were all learned now.
]]
function Feed.changes(before, after)
  local events = {}
  if type(before) ~= "table" or type(after) ~= "table" then return events end
  if type(before.level) == "number" and type(after.level) == "number" and after.level > before.level then
    events[#events + 1] = { kind = "level", from = before.level, to = after.level }
  end
  local old, new = before.professions or {}, after.professions or {}
  local hadAny, added = next(old) ~= nil, {}
  for id, p in pairs(new) do
    local was = old[id]
    if not was then
      added[#added + 1] = p.name
    elseif (p.max or 0) > (was.max or 0) and Feed.RANKS[p.max] then
      events[#events + 1] = { kind = "rank", name = p.name, rank = Feed.RANKS[p.max] }
    end
  end
  if hadAny or #added == 1 then
    for _, name in ipairs(added) do events[#events + 1] = { kind = "learned", name = name } end
  end
  return events
end

local function entryFor(feed, day, char, now)
  local today = feed[day]
  if not today then
    today = {}
    feed[day] = today
  end
  local entry = today[char.guid]
  if not entry then
    entry = {}
    today[char.guid] = entry
  end
  entry.name, entry.classFile, entry.at = char.name, char.classFile, now
  return entry
end

--[[ Adds an event of one own character to the feed (in place):
  feed = { [day] = { [guid] = { name, classFile, at, levelFrom, levelTo,
                                quests = { [zone] = count }, ranks = { [profession] = rank },
                                learned = { [profession] = true },
                                runs = { { name, kind, bosses, won, with = { guid, ... } } } } } }
char = { guid, name, classFile }. event: see Feed.changes, { kind = "quest", zone }, or a finished run
(CF-23, see Runs.finish): { kind = "run", instance = "party"|"raid"|"pvp", name, bosses, won, with }.
]]
function Feed.add(feed, day, char, event, now)
  local entry = entryFor(feed, day, char, now)
  if event.kind == "level" then
    entry.levelFrom = entry.levelFrom or event.from
    entry.levelTo = math.max(entry.levelTo or event.to, event.to)
  elseif event.kind == "quest" then
    entry.quests = entry.quests or {}
    local zone = event.zone or "Other"
    entry.quests[zone] = (entry.quests[zone] or 0) + 1
  elseif event.kind == "rank" then
    entry.ranks = entry.ranks or {}
    entry.ranks[event.name] = event.rank
  elseif event.kind == "learned" then
    entry.learned = entry.learned or {}
    entry.learned[event.name] = true
  elseif event.kind == "run" then
    entry.runs = entry.runs or {}
    if #entry.runs < MAX_RUNS then
      entry.runs[#entry.runs + 1] = { name = event.name, kind = event.instance, bosses = event.bosses,
                                      won = event.won, with = event.with }
    end
  end
end

-- Drops days older than KEEP_DAYS (in place). Returns true if something was removed.
function Feed.trim(feed, today)
  local removed = false
  for day in pairs(feed) do
    if type(day) ~= "number" or day <= today - Feed.KEEP_DAYS or day > today + 1 then
      feed[day] = nil
      removed = true
    end
  end
  return removed
end

local function cleanText(value)
  if type(value) ~= "string" then return nil end
  local text = value:gsub("|", ""):sub(1, MAX_TEXT)
  return text ~= "" and text or nil
end

local function cleanNumber(value, max)
  if type(value) ~= "number" or value ~= value then return nil end
  return math.max(0, math.min(max, math.floor(value)))
end

-- Up to `limit` cleaned keys of a map; value(v) returns the cleaned value or nil to skip.
local function cleanMap(map, limit, value)
  if type(map) ~= "table" then return nil end
  local result, count = {}, 0
  for k, v in pairs(map) do
    local key, cleaned = cleanText(k), value(v)
    if key and cleaned ~= nil then
      result[key] = cleaned
      count = count + 1
      if count >= limit then break end
    end
  end
  return count > 0 and result or nil
end

local function isTrue(v) return v == true or nil end

-- CF-23: received runs, only the expected fields.
local function cleanRuns(runs)
  if type(runs) ~= "table" then return nil end
  local result = {}
  for _, run in ipairs(runs) do
    if #result >= MAX_RUNS then break end
    local name = type(run) == "table" and cleanText(run.name)
    if name and RUN_KINDS[run.kind] then
      local with = {}
      if type(run.with) == "table" then
        for _, guid in ipairs(run.with) do
          if #with >= MAX_COMPANIONS then break end
          local clean = cleanText(guid)
          if clean then with[#with + 1] = clean end
        end
      end
      result[#result + 1] = { name = name, kind = run.kind, bosses = cleanNumber(run.bosses, MAX_BOSSES),
                              won = type(run.won) == "boolean" and run.won or nil, with = with }
    end
  end
  return #result > 0 and result or nil
end

-- Copy of a received feed with only the expected fields, cleaned and limited, or nil.
function Feed.clean(feed)
  if type(feed) ~= "table" then return nil end
  local result, days = {}, 0
  for day, chars in pairs(feed) do
    if type(day) == "number" and day == math.floor(day) and type(chars) == "table" and days < Feed.KEEP_DAYS + 1 then
      local cleanDay, count = {}, 0
      for guid, e in pairs(chars) do
        if type(guid) == "string" and type(e) == "table" and count < MAX_CHARS_PER_DAY then
          cleanDay[guid] = {
            name = cleanText(e.name),
            classFile = cleanText(e.classFile),
            at = cleanNumber(e.at, math.huge),
            levelFrom = cleanNumber(e.levelFrom, 100),
            levelTo = cleanNumber(e.levelTo, 100),
            quests = cleanMap(e.quests, MAX_ZONES, function(v) return cleanNumber(v, MAX_COUNT) end),
            ranks = cleanMap(e.ranks, MAX_PROFESSIONS, cleanText),
            learned = cleanMap(e.learned, MAX_PROFESSIONS, isTrue),
            runs = cleanRuns(e.runs),
          }
          count = count + 1
        end
      end
      if count > 0 then
        result[day] = cleanDay
        days = days + 1
      end
    end
  end
  return next(result) and result or nil
end

-- "questing in Westfall (9)", "... in Westfall and Redridge (12)", "... in Westfall, Redridge +2 zones (15)".
local function questingText(quests)
  local zones, total = {}, 0
  for zone, count in pairs(quests) do
    if count > 0 then
      zones[#zones + 1] = { zone = zone, count = count }
      total = total + count
    end
  end
  if total == 0 then return nil end
  table.sort(zones, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.zone < b.zone
  end)
  local where
  if #zones == 1 then
    where = zones[1].zone
  elseif #zones == 2 then
    where = zones[1].zone .. " and " .. zones[2].zone
  else
    local rest = #zones - 2
    where = string.format("%s, %s +%d %s", zones[1].zone, zones[2].zone, rest, rest == 1 and "zone" or "zones")
  end
  return string.format("questing in %s (%d)", where, total)
end

local function sortedKeys(map)
  local keys = {}
  for k in pairs(map or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- ===== Runs (CF-23): dungeons, raids, battlegrounds and playing together =====

local TIMES = "\195\151" -- multiplication sign, Latin-1: in the WoW fonts (unlike the arrow)
local RUN_ORDER = { raid = 1, party = 2, pvp = 3 }

-- Who took part in a run: the owner plus companions that belong to a person (sorted BattleTags), and
-- the names of companions who are community members without a linked person. Other GUIDs are left out.
-- ctx = { owner = battleTag, personOf = { [guid] = battleTag }, names = { [guid] = name } }
local function participants(run, ctx)
  local tags, seen, names = { ctx.owner }, { [ctx.owner] = true }, {}
  for _, guid in ipairs(run.with or {}) do
    local tag = ctx.personOf and ctx.personOf[guid]
    if tag then
      if not seen[tag] then
        seen[tag] = true
        tags[#tags + 1] = tag
      end
    elseif ctx.names and ctx.names[guid] then
      names[#names + 1] = ctx.names[guid]
    end
  end
  table.sort(tags, function(a, b) return tostring(a) < tostring(b) end)
  return tags, names
end

local function newAggregate(kind, name)
  return { kind = kind, name = name, count = 0, bosses = 0, won = 0, known = 0, names = {} }
end

-- Adds one run to an aggregate { [key] = { kind, name, count, bosses, won, known, names = { [name] = true } } }.
local function aggregate(agg, run, names)
  local key = run.kind == "pvp" and "pvp" or (run.kind .. ":" .. run.name)
  local a = agg[key]
  if not a then
    a = newAggregate(run.kind, run.name)
    agg[key] = a
  end
  a.count = a.count + 1
  a.bosses = math.max(a.bosses, run.bosses or 0)
  if run.won ~= nil then a.known = a.known + 1 end
  if run.won then a.won = a.won + 1 end
  for _, name in ipairs(names or {}) do a.names[name] = true end
end

-- Merges aggregates of the same runs recorded by several people: each records the same visits, so the
-- largest numbers win (not the sum).
local function mergeMax(into, agg)
  for key, a in pairs(agg) do
    local b = into[key]
    if not b then
      b = newAggregate(a.kind, a.name)
      into[key] = b
    end
    b.count, b.bosses = math.max(b.count, a.count), math.max(b.bosses, a.bosses)
    b.won, b.known = math.max(b.won, a.won), math.max(b.known, a.known)
    for name in pairs(a.names) do b.names[name] = true end
  end
end

-- " with Alice Example", " with A and B", " with A, B +2".
local function withText(names)
  local list = sortedKeys(names)
  if #list == 0 then return "" end
  if #list == 1 then return " with " .. list[1] end
  if #list == 2 then return " with " .. list[1] .. " and " .. list[2] end
  return string.format(" with %s, %s +%d", list[1], list[2], #list - 2)
end

local function runText(a)
  local times = a.count > 1 and (" " .. TIMES .. a.count) or ""
  local text
  if a.kind == "party" then
    text = "ran " .. a.name .. times
  elseif a.kind == "raid" then
    text = string.format("raided %s%s (%d %s)", a.name, times, a.bosses, a.bosses == 1 and "boss" or "bosses")
  elseif a.count == 1 then
    text = "1 battleground" .. (a.known > 0 and (a.won > 0 and " (won)" or " (lost)") or "")
  else
    text = string.format("%d battlegrounds", a.count) .. (a.known > 0 and string.format(" (%d won)", a.won) or "")
  end
  return text .. withText(a.names)
end

-- Parts for an aggregate: raids, then dungeons, then battlegrounds; by name.
local function runParts(agg)
  local list = {}
  for _, a in pairs(agg) do list[#list + 1] = a end
  table.sort(list, function(a, b)
    if a.kind ~= b.kind then return RUN_ORDER[a.kind] < RUN_ORDER[b.kind] end
    return a.name < b.name
  end)
  local parts = {}
  for i, a in ipairs(list) do parts[i] = runText(a) end
  return parts
end

--[[ Parts of one character's day, in order of importance: raids, dungeons and battlegrounds (CF-23),
milestone or level range, profession ranks, learned professions, questing. Milestone: the highest of
MILESTONES reached that day replaces the range ("reached 40", "reached 60!").
ctx (optional, see participants): runs together with another person are left out here; they show on a
shared line (Feed.days). Without ctx every run is the character's own and companions are left out. ]]
function Feed.parts(entry, ctx)
  local parts = {}
  if entry.runs then
    ctx = ctx or { owner = "" }
    local agg = {}
    for _, run in ipairs(entry.runs) do
      local tags, names = participants(run, ctx)
      if #tags == 1 then aggregate(agg, run, names) end
    end
    for _, part in ipairs(runParts(agg)) do parts[#parts + 1] = part end
  end
  if entry.levelTo and entry.levelFrom and entry.levelTo > entry.levelFrom then
    local milestone
    for _, m in ipairs(Feed.MILESTONES) do
      if entry.levelFrom < m and entry.levelTo >= m then milestone = m end
    end
    if milestone then
      parts[#parts + 1] = milestone == 60 and "reached 60!" or ("reached " .. milestone)
    else
      parts[#parts + 1] = string.format("%d to %d", entry.levelFrom, entry.levelTo) -- the WoW font has no arrow
    end
  end
  for _, name in ipairs(sortedKeys(entry.ranks)) do
    parts[#parts + 1] = string.format("%s reached %s", name, entry.ranks[name])
  end
  for _, name in ipairs(sortedKeys(entry.learned)) do
    parts[#parts + 1] = "learned " .. name
  end
  local questing = entry.quests and questingText(entry.quests)
  if questing then parts[#parts + 1] = questing end
  return parts
end

local function firstParts(parts)
  local shown = {}
  for i = 1, math.min(Feed.MAX_PARTS, #parts) do shown[i] = parts[i] end
  return shown
end

-- "Alice", "Alice and Bob", "Alice, Bob and Carol".
local function joinNames(list)
  if #list <= 1 then return list[1] or "" end
  return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

-- Collects the runs of one feed entry that were done with other people into the day's shared groups.
local function collectShared(groups, entry, ctx)
  for _, run in ipairs(entry.runs or {}) do
    local tags, companions = participants(run, ctx)
    if #tags > 1 then
      local key = table.concat(tags, "\001")
      local group = groups[key]
      if not group then
        group = { tags = tags, byOwner = {}, at = 0 }
        groups[key] = group
      end
      group.byOwner[ctx.owner] = group.byOwner[ctx.owner] or {}
      aggregate(group.byOwner[ctx.owner], run, companions)
      group.at = math.max(group.at, entry.at or 0)
    end
  end
end

-- The shared line of a group of people (you first, then by display name).
local function sharedLine(key, group, byTag)
  local merged = {}
  for _, agg in pairs(group.byOwner) do mergeMax(merged, agg) end
  local who = {}
  for _, tag in ipairs(group.tags) do who[#who + 1] = byTag[tag] end
  table.sort(who, function(a, b)
    if (a.isSelf or false) ~= (b.isSelf or false) then return a.isSelf or false end
    return tostring(a.displayName) < tostring(b.displayName)
  end)
  local displayNames = {}
  for i, person in ipairs(who) do displayNames[i] = tostring(person.displayName) end
  local parts = runParts(merged)
  local shown = firstParts(parts)
  return { shared = true, key = key, title = joinNames(displayNames), battleTags = group.tags, at = group.at,
           parts = parts, shown = shown, more = #parts - #shown, extraChars = 0, others = {} }
end

--[[ Lines for the Activity tab, newest day first:
  { { day, label, lines = { line, ... } } }
A person's line: { displayName, isSelf, battleTag, at, char = { name, classFile }, parts, shown, more,
                   extraChars, others = { { char, parts } } }
A shared line (CF-23: two or more people in the same runs): { shared = true, key, title, battleTags, at,
                   parts, shown, more, extraChars = 0, others = {} }. Those runs are left out of the
                   people's own lines.
people: Linker people (each with displayName, isSelf, battleTag, feed, chars = { { guid } }).
members: optional { [guid] = name } of the selected community: companions who are members but not linked
to a person show by character name ("with Alice Example"); other companions are left out.
Per person and day the character with the most parts (then the latest) is the main one; shown = its first
MAX_PARTS parts, more = the rest, extraChars = other characters with activity that day (listed in others).
Within a day the line active most recently comes first.
]]
function Feed.days(people, today, members)
  local personOf, byTag, names = {}, {}, {}
  for _, person in ipairs(people or {}) do
    if person.battleTag then
      byTag[person.battleTag] = person
      for _, row in ipairs(person.chars or {}) do
        if row.guid then personOf[row.guid] = person.battleTag end
      end
    end
  end
  for guid, name in pairs(members or {}) do
    if not personOf[guid] and type(name) == "string" then names[guid] = name end
  end

  local byDay, sharedByDay = {}, {}
  for _, person in ipairs(people or {}) do
    local ctx = { owner = person.battleTag or "", personOf = personOf, names = names }
    for day, chars in pairs(person.feed or {}) do
      if type(day) == "number" and day > today - Feed.KEEP_DAYS and day <= today then
        sharedByDay[day] = sharedByDay[day] or {}
        local list = {}
        for guid, entry in pairs(chars) do
          if person.battleTag then collectShared(sharedByDay[day], entry, ctx) end
          local parts = Feed.parts(entry, ctx)
          if #parts > 0 then
            list[#list + 1] = { guid = guid, char = { name = entry.name, classFile = entry.classFile },
                                parts = parts, at = entry.at or 0 }
          end
        end
        if #list > 0 then
          table.sort(list, function(a, b)
            if #a.parts ~= #b.parts then return #a.parts > #b.parts end
            if a.at ~= b.at then return a.at > b.at end
            return a.guid < b.guid
          end)
          local main, latest, others = list[1], 0, {}
          for i, c in ipairs(list) do
            latest = math.max(latest, c.at)
            if i > 1 then others[#others + 1] = { char = c.char, parts = c.parts } end
          end
          local shown = firstParts(main.parts)
          byDay[day] = byDay[day] or {}
          table.insert(byDay[day], {
            displayName = person.displayName, isSelf = person.isSelf or false, battleTag = person.battleTag,
            at = latest, char = main.char, parts = main.parts, shown = shown,
            more = #main.parts - #shown, extraChars = #others, others = others,
          })
        end
      end
    end
  end

  for day, groups in pairs(sharedByDay) do
    for key, group in pairs(groups) do
      byDay[day] = byDay[day] or {}
      table.insert(byDay[day], sharedLine(key, group, byTag))
    end
  end

  local days = {}
  for day, lines in pairs(byDay) do
    table.sort(lines, function(a, b)
      if a.at ~= b.at then return a.at > b.at end
      return tostring(a.title or a.displayName) < tostring(b.title or b.displayName)
    end)
    days[#days + 1] = { day = day, label = Feed.dayLabel(day, today), lines = lines }
  end
  table.sort(days, function(a, b) return a.day > b.day end)
  return days
end

ns.Feed = Feed
return Feed
