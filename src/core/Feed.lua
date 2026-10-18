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
                                learned = { [profession] = true } } } }
char = { guid, name, classFile }. event: see Feed.changes, or { kind = "quest", zone }.
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

--[[ Parts of one character's day, in order of importance: milestone or level range, profession ranks,
learned professions, questing. Milestone: the highest of MILESTONES reached that day replaces the range
("reached 40", "reached 60!"). ]]
function Feed.parts(entry)
  local parts = {}
  if entry.levelTo and entry.levelFrom and entry.levelTo > entry.levelFrom then
    local milestone
    for _, m in ipairs(Feed.MILESTONES) do
      if entry.levelFrom < m and entry.levelTo >= m then milestone = m end
    end
    if milestone then
      parts[#parts + 1] = milestone == 60 and "reached 60!" or ("reached " .. milestone)
    else
      parts[#parts + 1] = string.format("%d \226\134\146 %d", entry.levelFrom, entry.levelTo)
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

--[[ Lines for the Activity tab, newest day first:
  { { day, label, lines = { { displayName, isSelf, battleTag, at,
                              char = { name, classFile }, parts, shown, more, extraChars,
                              others = { { char, parts } } } } } }
people: Linker people (each with displayName, isSelf, battleTag, feed). Per person and day the character
with the most parts (then the latest) is the main one; shown = its first MAX_PARTS parts, more = the rest,
extraChars = other characters with activity that day (listed in others). Within a day the person active
most recently comes first.
]]
function Feed.days(people, today)
  local byDay = {}
  for _, person in ipairs(people or {}) do
    for day, chars in pairs(person.feed or {}) do
      if type(day) == "number" and day > today - Feed.KEEP_DAYS and day <= today then
        local list = {}
        for guid, entry in pairs(chars) do
          local parts = Feed.parts(entry)
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
          local shown = {}
          for i = 1, math.min(Feed.MAX_PARTS, #main.parts) do shown[i] = main.parts[i] end
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

  local days = {}
  for day, lines in pairs(byDay) do
    table.sort(lines, function(a, b)
      if a.at ~= b.at then return a.at > b.at end
      return tostring(a.displayName) < tostring(b.displayName)
    end)
    days[#days + 1] = { day = day, label = Feed.dayLabel(day, today), lines = lines }
  end
  table.sort(days, function(a, b) return a.day > b.day end)
  return days
end

ns.Feed = Feed
return Feed
