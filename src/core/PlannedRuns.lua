-- PlannedRuns: checks the planned runs file (CF-45). Pure Lua, no WoW globals.
-- The uploader (UP-12) writes the website's upcoming runs into Data\Runs.lua as CF_RUNS; the game runs that
-- file at login or /reload. It is untrusted like received sync data: wrong types are dropped, WoW escape
-- sequences ('|') and control characters are removed, counts and string lengths are capped.
-- The shape is documented in docs/ARCHITECTURE.md "Planned runs file".
local _, ns = ...

local PlannedRuns = {}

PlannedRuns.VERSION = 1          -- format of CF_RUNS this addon reads; a newer one is ignored
PlannedRuns.MAX_RUNS = 50        -- runs kept (the site sends the next 14 days)
PlannedRuns.MAX_ANSWERS = 40     -- answers kept per run
PlannedRuns.MAX_NOTE = 200       -- characters
PlannedRuns.MAX_NAME = 48        -- character names and BattleTags
PlannedRuns.MAX_ID = 64
PlannedRuns.MAX_URL = 200
PlannedRuns.MAX_REMINDER = 1440  -- minutes
PlannedRuns.MAX_TIME = 4102444800 -- 2100-01-01 UTC: any later timestamp is broken data
PlannedRuns.MAX_UTC_OFFSET = 14 * 3600
PlannedRuns.MAX_RECEIVED = 200   -- CF-47: ids of game items the site has (Pending.confirm)

PlannedRuns.STATES = { open = true, full = true, started = true, cancelled = true }
PlannedRuns.ANSWERS = { ["in"] = true, maybe = true, cant = true }
PlannedRuns.ROLES = { tank = true, heal = true, dps = true }
PlannedRuns.SOURCES = { site = true, discord = true, game = true }

-- Plain text of at most max characters (UTF-8 aware), or nil when nothing is left.
local function text(value, max)
  if type(value) ~= "string" then return nil end
  value = value:sub(1, max * 4):gsub("|", ""):gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  local chars = {}
  for char in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #chars == max then break end
    chars[#chars + 1] = char
  end
  value = table.concat(chars):match("^(.-)%s*$")
  return value ~= "" and value or nil
end

-- An identifier (run id, dungeon id): letters, digits and _ - : . only, else nil.
local function token(value, max)
  if type(value) ~= "string" or #value > max or not value:match("^[%w_%-:%.]+$") then return nil end
  return value
end

-- A whole number within [min, max], else nil.
local function number(value, min, max)
  if type(value) ~= "number" or value ~= value then return nil end
  value = math.floor(value)
  if value < min or value > max then return nil end
  return value
end

local function time(value)
  return number(value, 1, PlannedRuns.MAX_TIME)
end

local function oneOf(set, value)
  if type(value) == "string" and set[value] then return value end
  return nil
end

-- A link to copy ("Edit or cancel on the website"): https only, no spaces or quotes.
local function url(value)
  if type(value) ~= "string" or #value > PlannedRuns.MAX_URL then return nil end
  if not value:match("^https://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+$") then return nil end
  return value
end

-- A person on a run: who they are (BattleTag) and which character (GUID, name); any part may be missing.
local function person(raw)
  if type(raw) ~= "table" then return nil end
  local p = {
    battleTag = text(raw.battleTag, PlannedRuns.MAX_NAME),
    guid = token(raw.guid, PlannedRuns.MAX_ID),
    name = text(raw.name, PlannedRuns.MAX_NAME),
  }
  if not (p.battleTag or p.guid or p.name) then return nil end
  return p
end

local function answer(raw)
  local a = person(raw)
  local choice = type(raw) == "table" and oneOf(PlannedRuns.ANSWERS, raw.answer)
  if not (a and choice) then return nil end
  a.answer = choice
  a.role = oneOf(PlannedRuns.ROLES, raw.role)
  a.source = oneOf(PlannedRuns.SOURCES, raw.source)
  a.at = time(raw.at)
  return a
end

-- Reads up to max entries of an array; stops at the first hole, never walks an oversized table.
local function readList(raw, max, clean)
  local out = {}
  if type(raw) ~= "table" then return out, 0 end
  local dropped = 0
  for i = 1, max do
    local item = raw[i]
    if item == nil then break end
    local value = clean(item)
    if value then out[#out + 1] = value else dropped = dropped + 1 end
  end
  if raw[max + 1] ~= nil then dropped = dropped + 1 end -- more than the cap (counted once)
  return out, dropped
end

local function cleanRun(raw)
  if type(raw) ~= "table" then return nil end
  local r = {
    id = token(raw.id, PlannedRuns.MAX_ID),
    dungeon = token(raw.dungeon, PlannedRuns.MAX_ID),
    startsAt = time(raw.startsAt),
  }
  if not (r.id and r.dungeon and r.startsAt) then return nil end
  r.state = oneOf(PlannedRuns.STATES, raw.state)
  r.source = oneOf(PlannedRuns.SOURCES, raw.source) -- CF-46: where it was planned
  r.note = text(raw.note, PlannedRuns.MAX_NOTE)
  r.url = url(raw.url)
  r.organiser = person(raw.organiser)
  if r.organiser and type(raw.organiser) == "table" then
    r.organiser.utcOffset = number(raw.organiser.utcOffset, -PlannedRuns.MAX_UTC_OFFSET, PlannedRuns.MAX_UTC_OFFSET)
  end
  r.answers = readList(raw.answers, PlannedRuns.MAX_ANSWERS, answer)
  return r
end

--[[ Clean copy of CF_RUNS, or nil and the reason:
  "missing" (no file data: CF_RUNS = nil, the shipped empty file), "not a table", "newer format"
  (a later addon version reads it: update the addon), "no updatedAt".
Result: { v, updatedAt, reminderMinutes, runs = { Run, ... } sorted by start time, dropped }
  dropped: runs left out (broken, duplicate id, or beyond MAX_RUNS). ]]
function PlannedRuns.validate(raw)
  if raw == nil then return nil, "missing" end
  if type(raw) ~= "table" then return nil, "not a table" end
  local v = raw.v == nil and 1 or number(raw.v, 1, math.huge)
  if not v then return nil, "not a table" end
  if v > PlannedRuns.VERSION then return nil, "newer format" end
  local updatedAt = time(raw.updatedAt)
  if not updatedAt then return nil, "no updatedAt" end

  local runs, dropped = readList(raw.runs, PlannedRuns.MAX_RUNS, cleanRun)
  local seen, unique = {}, {}
  for _, r in ipairs(runs) do
    if seen[r.id] then
      dropped = dropped + 1
    else
      seen[r.id] = true
      unique[#unique + 1] = r
    end
  end
  table.sort(unique, function(a, b)
    if a.startsAt ~= b.startsAt then return a.startsAt < b.startsAt end
    return a.id < b.id
  end)
  -- CF-47: ids of the plans, answers, asks and pings from the game that the site has.
  local received = readList(raw.received, PlannedRuns.MAX_RECEIVED, function(id)
    return token(id, PlannedRuns.MAX_ID)
  end)
  return {
    v = v,
    updatedAt = updatedAt,
    reminderMinutes = number(raw.reminderMinutes, 0, PlannedRuns.MAX_REMINDER),
    runs = unique,
    received = received,
    dropped = dropped,
  }
end

-- ===== Sharing (CF-46) =====

PlannedRuns.MAX_FUTURE_SECONDS = 300 -- an updatedAt further ahead of server time is broken data

-- True when incoming (checked) replaces current: a newer updatedAt, not too far in the future.
function PlannedRuns.isNewer(current, incoming, now)
  if not (incoming and incoming.updatedAt) then return false end
  if now and incoming.updatedAt > now + PlannedRuns.MAX_FUTURE_SECONDS then return false end
  return incoming.updatedAt > (current and current.updatedAt or 0)
end

-- What is stored and sent: the checked data without the dropped count. forCommunity: without BattleTags
-- (they only travel over Battle.net, ARCHITECTURE "Sync protocol").
function PlannedRuns.wire(data, forCommunity)
  if not data then return nil end
  local function who(p)
    if not p then return nil end
    local copy = {}
    for k, v in pairs(p) do copy[k] = v end
    if forCommunity then copy.battleTag = nil end
    return copy
  end
  local runs = {}
  for i, r in ipairs(data.runs or {}) do
    local copy = {}
    for k, v in pairs(r) do copy[k] = v end
    copy.organiser = who(r.organiser)
    copy.answers = {}
    for j, a in ipairs(r.answers or {}) do copy.answers[j] = who(a) end
    runs[i] = copy
  end
  local received = {}
  for i, id in ipairs(data.received or {}) do received[i] = id end
  return { v = data.v, updatedAt = data.updatedAt, reminderMinutes = data.reminderMinutes, runs = runs,
           received = received }
end

-- ===== The Dungeons tab (CF-46) =====

PlannedRuns.KEEP_STARTED = 2 * 3600 -- a started run stays listed this long after its start
PlannedRuns.CLOSE_LEVELS = 5        -- "Close": characters at most this many levels outside the range

-- Runs to show, soonest first: not cancelled, not started more than KEEP_STARTED ago.
function PlannedRuns.upcoming(data, now)
  local list = {}
  for _, r in ipairs(data and data.runs or {}) do
    if r.state ~= "cancelled" and r.startsAt >= now - PlannedRuns.KEEP_STARTED then list[#list + 1] = r end
  end
  return list
end

-- "I'm in" and "maybe" answers.
function PlannedRuns.counts(run)
  local yes, maybe = 0, 0
  for _, a in ipairs(run.answers or {}) do
    if a.answer == "in" then yes = yes + 1 elseif a.answer == "maybe" then maybe = maybe + 1 end
  end
  return yes, maybe
end

--[[ me = { battleTag, guids = { [guid] = true } }: you, by your BattleTag or one of your characters. ]]
local function isMe(p, me)
  if not (p and me) then return false end
  if p.guid and me.guids and me.guids[p.guid] then return true end
  return p.battleTag ~= nil and p.battleTag == me.battleTag
end

function PlannedRuns.isOrganiser(run, me) return isMe(run.organiser, me) end

-- Your answer to a run, or nil.
function PlannedRuns.yourAnswer(run, me)
  for _, a in ipairs(run.answers or {}) do
    if isMe(a, me) then return a end
  end
  return nil
end

local function samePerson(a, b)
  if not (a and b) then return false end
  if a.guid and a.guid == b.guid then return true end
  return a.battleTag ~= nil and a.battleTag == b.battleTag
end

local function inRange(dungeon, level)
  return dungeon ~= nil and type(level) == "number" and level >= dungeon.min and level <= dungeon.max
end

--[[ The five slots of a run: tank, healer, three damage.
  candidates: Dungeons.candidates (what the addon knows of each character: level, class, role, online);
  dungeon: its level range (nil when unknown).
  { { role, answer = answer | nil, char = candidate | nil, maybe = true | nil, missing = true | nil } }
"I'm in" answers fill the slot of their role (the site's role, else the role the addon knows, else damage),
then free damage slots, then any; "maybe" answers fill what is left. An empty tank or healer slot is missing
when nobody in range who hasn't said no plays that role, else open. ]]
function PlannedRuns.slots(run, candidates, dungeon)
  local byGuid = {}
  for _, c in ipairs(candidates or {}) do
    if c.guid then byGuid[c.guid] = c end
  end
  local slots = { { role = "tank" }, { role = "heal" }, { role = "dps" }, { role = "dps" }, { role = "dps" } }
  local function place(a, maybe)
    local c = a.guid and byGuid[a.guid]
    local role = a.role or (c and c.role) or "dps"
    -- Own role's slot first, then damage, then any free one.
    local order = role == "tank" and { 1, 3, 4, 5, 2 } or role == "heal" and { 2, 3, 4, 5, 1 }
      or { 3, 4, 5, 1, 2 }
    for _, i in ipairs(order) do
      if not slots[i].answer then
        slots[i].answer, slots[i].char, slots[i].maybe = a, c, maybe or nil
        return
      end
    end
  end
  for _, kind in ipairs({ "in", "maybe" }) do
    for _, a in ipairs(run.answers or {}) do
      if a.answer == kind then place(a, kind == "maybe") end
    end
  end
  local declined = {}
  for _, a in ipairs(run.answers or {}) do
    if a.answer == "cant" then declined[#declined + 1] = a end
  end
  for i = 1, 2 do
    local slot = slots[i]
    if not slot.answer then
      slot.missing = true
      for _, c in ipairs(candidates or {}) do
        local no = false
        for _, a in ipairs(declined) do
          if samePerson(a, { guid = c.guid }) then no = true end
        end
        if c.role == slot.role and inRange(dungeon, c.level) and not no then slot.missing = nil end
      end
    end
  end
  return slots
end

--[[ One of your characters in range for a free tank, healer or damage slot ("Grom Ashfeller fits tank"),
when you haven't answered: candidate, role; or nil. The character you are on first. ]]
function PlannedRuns.youFit(run, candidates, dungeon, me, selfGuid)
  if PlannedRuns.yourAnswer(run, me) or PlannedRuns.isOrganiser(run, me) then return nil end
  local free = {}
  for _, slot in ipairs(PlannedRuns.slots(run, candidates, dungeon)) do
    if not slot.answer then free[slot.role] = true end
  end
  local best
  for _, c in ipairs(candidates or {}) do
    if c.own and inRange(dungeon, c.level) and free[c.role or "dps"] then
      if not best or c.guid == selfGuid then best = c end
    end
  end
  if best then return best, best.role or "dps" end
  return nil
end

--[[ Characters just outside the dungeon's range, not answered yet: { { char, short = n } | { char, over = n } },
your own first, then the smallest gap. ]]
function PlannedRuns.close(run, candidates, dungeon)
  local answered, list = {}, {}
  for _, a in ipairs(run.answers or {}) do
    if a.guid then answered[a.guid] = true end
  end
  if not dungeon then return list end
  for _, c in ipairs(candidates or {}) do
    if not answered[c.guid] and type(c.level) == "number" then
      if c.level < dungeon.min and dungeon.min - c.level <= PlannedRuns.CLOSE_LEVELS then
        list[#list + 1] = { char = c, short = dungeon.min - c.level }
      elseif c.level > dungeon.max and c.level - dungeon.max <= PlannedRuns.CLOSE_LEVELS then
        list[#list + 1] = { char = c, over = c.level - dungeon.max }
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.char.own == true) ~= (b.char.own == true) then return a.char.own == true end
    local ga, gb = a.short or a.over, b.short or b.over
    if ga ~= gb then return ga < gb end
    return tostring(a.char.name) < tostring(b.char.name)
  end)
  return list
end

-- ===== Times (local time; dateFn: the game's date, os.date in tests) =====

local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- Days between two local dates { year, month, day } (civil calendar, no os.time needed).
local function days(d)
  local y, m = d.year, d.month
  y = m <= 2 and y - 1 or y
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m > 2 and m - 3 or m + 9) + 2) / 5) + d.day - 1
  return era * 146097 + yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
end

-- "Today 20:30", "Tomorrow 19:00", "Thu 21:00" (this week), "Thu 5 Nov 21:00".
function PlannedRuns.whenText(at, now, dateFn)
  local t, n = dateFn("*t", at), dateFn("*t", now)
  local clock = string.format("%02d:%02d", t.hour, t.min)
  local diff = days(t) - days(n)
  if diff == 0 then return "Today " .. clock end
  if diff == 1 then return "Tomorrow " .. clock end
  if diff > 1 and diff < 7 then return WEEKDAYS[t.wday] .. " " .. clock end
  return string.format("%s %d %s %s", WEEKDAYS[t.wday], t.day, MONTHS[t.month], clock)
end

-- "20:30" local time.
function PlannedRuns.clock(at, dateFn)
  local t = dateFn("*t", at)
  return string.format("%02d:%02d", t.hour, t.min)
end

-- CF-47: the organiser's clock time of a start ("20:00 for Bob"): utcOffset seconds east of UTC, or nil.
function PlannedRuns.theirClock(at, utcOffset, dateFn)
  if type(utcOffset) ~= "number" then return nil end
  local t = dateFn("!*t", at + utcOffset)
  return string.format("%02d:%02d", t.hour, t.min)
end

-- The civil date of a day number from days() (inverse).
local function civil(n)
  local era = math.floor(n / 146097)
  local doe = n - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local day = doy - math.floor((153 * mp + 2) / 5) + 1
  local month = mp < 10 and mp + 3 or mp - 9
  return { year = yoe + era * 400 + (month <= 2 and 1 or 0), month = month, day = day }
end

-- CF-47: Plan a run's days: today and the next 6 by the local calendar (no daylight saving surprises),
-- { { label = "Today" | "Wed", year, month, day } }.
function PlannedRuns.dayChoices(now, dateFn)
  local today = dateFn("*t", now)
  local first = days({ year = today.year, month = today.month, day = today.day })
  local list = {}
  for i = 0, 6 do
    local d = civil(first + i)
    -- days() counts from 0000-03-01, a Wednesday (index 4 in WEEKDAYS).
    d.label = i == 0 and "Today" or WEEKDAYS[(first + i + 3) % 7 + 1]
    list[#list + 1] = d
  end
  return list
end

-- CF-47: "20:30", "8:05" or "2030" typed as a time: hour, minute; or nil.
function PlannedRuns.parseClock(typed)
  if type(typed) ~= "string" then return nil end
  local h, m = typed:match("^%s*(%d%d?)[:%.]?(%d%d)%s*$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return nil end
  return h, m
end

-- "in 2 h 40 min", "in 25 min", "in 3 days", "started 10 min ago".
function PlannedRuns.untilText(at, now)
  local seconds = at - now
  if seconds < 0 then
    return string.format("started %d min ago", math.floor(-seconds / 60))
  end
  local minutes = math.ceil(seconds / 60)
  if minutes < 60 then return string.format("in %d min", minutes) end
  if minutes < 24 * 60 then
    local h, m = math.floor(minutes / 60), minutes % 60
    return m > 0 and string.format("in %d h %d min", h, m) or string.format("in %d h", h)
  end
  local d = math.floor(minutes / (24 * 60))
  return string.format("in %d day%s", d, d == 1 and "" or "s")
end

ns.PlannedRuns = PlannedRuns
return PlannedRuns
