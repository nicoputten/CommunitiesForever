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
PlannedRuns.MAX_FIT = 24         -- CF-49: an answer's fit label ("carry \194\183 +12")

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
  a.fit = text(raw.fit, PlannedRuns.MAX_FIT) -- CF-49 (web WEB-47): the site's levelFit label
  a.reserve = raw.reserve == true or nil      -- CF-49: an I'm in waiting for a full role (sent as maybe)
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
  r.dungeonName = text(raw.dungeonName, 60) -- CF-63: the site's name, for an id the addon doesn't know
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
then free damage slots, then any; "maybe" answers fill what is left. A reserve (CF-49) takes no slot
(PlannedRuns.reserves). An empty tank or healer slot is missing when nobody in range who hasn't said no plays
that role, else open. ]]
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
      if a.answer == kind and not a.reserve then place(a, kind == "maybe") end
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

-- CF-49: reserves, oldest first: I'm in answers waiting for a full role (the site sends them as maybe).
function PlannedRuns.reserves(run)
  local list = {}
  for _, a in ipairs(run.answers or {}) do
    if a.reserve then list[#list + 1] = a end
  end
  return list
end

--[[ CF-49: how an answer's character fits the run: { kind, label } by levelFit when the addon knows the
character's level (fresher than the file), else the site's fit text (kind nil), else nil. ]]
function PlannedRuns.fitOf(a, char, dungeon)
  if dungeon and char and type(char.level) == "number" then
    return PlannedRuns.levelFit(char.level, dungeon.min, dungeon.max)
  end
  if a and a.fit then return { label = a.fit } end
  return nil
end

--[[ One of your characters for a free tank, healer or damage slot ("Grom Ashfeller fits tank"), when you
haven't answered: candidate, role; or nil. CF-49: the character is suggested by levelFit (fits or a few over)
and its class can play the free role, its own role first. The character you are on first. ]]
function PlannedRuns.youFit(run, candidates, dungeon, me, selfGuid)
  if PlannedRuns.yourAnswer(run, me) or PlannedRuns.isOrganiser(run, me) then return nil end
  if not dungeon then return nil end
  local free = {}
  for _, slot in ipairs(PlannedRuns.slots(run, candidates, dungeon)) do
    if not slot.answer then free[slot.role] = true end
  end
  local function roleFor(c)
    local own = c.role or "dps"
    if free[own] and PlannedRuns.canPlay(c.classFile, own) then return own end
    for _, r in ipairs(PlannedRuns.rolesFor(c.classFile)) do
      if free[r] then return r end
    end
    return nil
  end
  local best, bestRole
  for _, c in ipairs(candidates or {}) do
    local role = c.own and PlannedRuns.levelFit(c.level, dungeon.min, dungeon.max).suggested and roleFor(c)
    if role and (not best or c.guid == selfGuid) then best, bestRole = c, role end
  end
  if best then return best, bestRole end
  return nil
end

--[[ Characters not suggested for the run that may still join it (CF-49, levelFit: 1-5 below or a carry),
not answered yet: { { char, fit } }, your own first, then low before carries, then the smallest gap. ]]
function PlannedRuns.close(run, candidates, dungeon)
  local answered, list = {}, {}
  for _, a in ipairs(run.answers or {}) do
    if a.guid then answered[a.guid] = true end
  end
  if not dungeon then return list end
  for _, c in ipairs(candidates or {}) do
    if not answered[c.guid] and type(c.level) == "number" then
      local fit = PlannedRuns.levelFit(c.level, dungeon.min, dungeon.max)
      -- "Close" (could fill's fallback): 1-5 below or a carry; 6+ below is never suggested (CF-50).
      if fit.kind == "low" or fit.kind == "carry" then
        local gap = c.level < dungeon.min and dungeon.min - c.level or c.level - dungeon.max
        list[#list + 1] = { char = c, fit = fit, gap = gap }
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.char.own == true) ~= (b.char.own == true) then return a.char.own == true end
    if a.fit.kind ~= b.fit.kind then return a.fit.kind == "low" end
    if a.gap ~= b.gap then return a.gap < b.gap end
    return tostring(a.char.name) < tostring(b.char.name)
  end)
  return list
end

-- ===== Level fit and roles (CF-49, the web's WEB-47) =====

PlannedRuns.CARRY_FROM = 10 -- levels above the range from which a character carries the group
PlannedRuns.LOW_UNTIL = 5   -- levels below the range that are "low"; more is "tooLow" (never suggested)

--[[ How a level fits min-max, one rule with the site and Discord:
  { kind = "fits"|"over"|"carry"|"low"|"tooLow", label, canPick, suggested, note }
canPick: may answer I'm in with it: always since CF-50 (the web's WEB-52, Nico's "recommend, never restrict"),
6+ below too with "This will be tough."; suggested: offered as "could fill". An unknown level counts as too low. ]]
function PlannedRuns.levelFit(level, min, max)
  if type(level) ~= "number" then
    return { kind = "tooLow", label = "level unknown", canPick = true, suggested = false }
  end
  if level > max then
    local over = level - max
    if over >= PlannedRuns.CARRY_FROM then
      return { kind = "carry", label = "carry \194\183 +" .. over, canPick = true, suggested = false,
               note = "Little XP for you here." }
    end
    return { kind = "over", label = "+" .. over .. " over", canPick = true, suggested = true }
  end
  if level < min then
    local below = min - level
    if below <= PlannedRuns.LOW_UNTIL then
      return { kind = "low", label = below .. " below", canPick = true, suggested = false,
               note = "This will be tough." }
    end
    return { kind = "tooLow", label = below .. " below", canPick = true, suggested = false,
             note = "This will be tough." }
  end
  return { kind = "fits", label = "fits", canPick = true, suggested = true }
end

PlannedRuns.CLASS_ROLES = {
  WARRIOR = { "tank", "dps" },
  PALADIN = { "tank", "heal", "dps" },
  DRUID = { "tank", "heal", "dps" },
  PRIEST = { "heal", "dps" },
  SHAMAN = { "heal", "dps" },
  MAGE = { "dps" },
  WARLOCK = { "dps" },
  HUNTER = { "dps" },
  ROGUE = { "dps" },
}

-- The roles a class can fill (tank, heal, dps; a new list each time); all three for an unknown class.
function PlannedRuns.rolesFor(classFile)
  local roles = PlannedRuns.CLASS_ROLES[classFile] or { "tank", "heal", "dps" }
  local copy = {}
  for i, r in ipairs(roles) do copy[i] = r end
  return copy
end

-- True when the class can fill the role.
function PlannedRuns.canPlay(classFile, role)
  for _, r in ipairs(PlannedRuns.rolesFor(classFile)) do
    if r == role then return true end
  end
  return false
end

-- The role to start on for a character: its own (the addon's) when the class can play it, else the first.
function PlannedRuns.defaultRole(classFile, role)
  if role and PlannedRuns.canPlay(classFile, role) then return role end
  return PlannedRuns.rolesFor(classFile)[1]
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

-- ===== CF-62: the Dungeons tab v2 (board AG02Dungeons) =====

PlannedRuns.INVITE_LEAD = 15 * 60 -- Invite all (and Invite in "Online now, fits") opens this long before the start

-- The run list's groups by local start: "Today" (or "Tonight" from 17:00), "Tomorrow", "This week" (the next 6
-- days), "Later". Runs that started already count as today.
PlannedRuns.BUCKETS = { "Today", "Tonight", "Tomorrow", "This week", "Later" }
function PlannedRuns.bucket(at, now, dateFn)
  local t, n = dateFn("*t", at), dateFn("*t", now)
  local diff = days(t) - days(n)
  if diff <= 0 then return t.hour >= 17 and "Tonight" or "Today" end
  if diff == 1 then return "Tomorrow" end
  if diff < 7 then return "This week" end
  return "Later"
end

-- The time on a run row: "20:30" today, else "Fri 20:00" (this week) or "Fri 6 Nov 20:00".
function PlannedRuns.rowTime(at, now, dateFn)
  local t, n = dateFn("*t", at), dateFn("*t", now)
  local clock = string.format("%02d:%02d", t.hour, t.min)
  local diff = days(t) - days(n)
  if diff <= 0 then return clock end
  if diff < 7 then return WEEKDAYS[t.wday] .. " " .. clock end
  return string.format("%s %d %s %s", WEEKDAYS[t.wday], t.day, MONTHS[t.month], clock)
end

-- A dungeon's short name for the run list: "Scarlet Monastery: Graveyard" -> "SM: Graveyard"; others unchanged.
function PlannedRuns.shortName(name)
  if type(name) ~= "string" then return name end
  local prefix, rest = name:match("^(.-): (.+)$")
  if not prefix then return name end
  local initials = prefix:gsub("(%a)%a*%s*", "%1")
  return initials .. ": " .. rest
end

-- Whether Invite all (and Invite) is open: from INVITE_LEAD before the start.
function PlannedRuns.inviteOpen(run, now)
  return type(run) == "table" and type(run.startsAt) == "number" and now >= run.startsAt - PlannedRuns.INVITE_LEAD
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

-- ===== CF-62: what the site knows, for Friends ("Not synced yet") and the Dungeons empty state =====
PlannedRuns.MAX_FRIENDS = 50
PlannedRuns.MAX_FRIEND_CHARS = 20

-- The site's base URL (CF_RUNS.site), or nil: an http(s) address without spaces.
function PlannedRuns.site(raw)
  local address = type(raw) == "table" and text(raw.site, PlannedRuns.MAX_URL)
  return address and address:match("^https?://%S+$") or nil
end

--[[ The friends the site knows (CF_RUNS.friends, web PR #130): { { name, chars = { { name, realm, classFile, level,
seenAt } } } }, display names only, the uploader left out by the site. Cleaned and capped; {} without. ]]
function PlannedRuns.friends(raw)
  local list = type(raw) == "table" and type(raw.friends) == "table" and raw.friends or {}
  local out = {}
  for _, f in ipairs(list) do
    if #out >= PlannedRuns.MAX_FRIENDS then break end
    local name = type(f) == "table" and text(f.name, 24)
    if name and name ~= "" then
      local chars = {}
      for _, c in ipairs(type(f.chars) == "table" and f.chars or {}) do
        if #chars >= PlannedRuns.MAX_FRIEND_CHARS then break end
        local cname = type(c) == "table" and text(c.name, 40)
        if cname and cname ~= "" then
          local class = type(c.classFile) == "string" and c.classFile:match("^%u+$") and #c.classFile <= 12
            and c.classFile or nil
          chars[#chars + 1] = { name = cname, realm = text(c.realm, 40), classFile = class,
                                level = number(c.level, 1, 100), seenAt = time(c.seenAt) }
        end
      end
      out[#out + 1] = { name = name, chars = chars }
    end
  end
  return out
end

-- ===== CF-63: an interactive Dungeons tab (logic only; the UI waits for the design boards) =====

local FIT_ORDER = { fits = 1, over = 2, low = 3, carry = 4, tooLow = 5 }
PlannedRuns.ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "Damage" }

--[[ CF-63b: your characters for a run's character dropdown, every one (any level may answer, CF-50), each with
how it fits: { { char, fit } }. Best fit first (fits, over, low, carry, too low), then the character you are on,
then the highest level. dungeon nil (unknown range): all count as fitting. ]]
function PlannedRuns.charChoices(candidates, dungeon, selfGuid)
  local list = {}
  for _, c in ipairs(candidates or {}) do
    if c.own then
      local fit = dungeon and PlannedRuns.levelFit(c.level, dungeon.min, dungeon.max)
        or { kind = "fits", label = "fits", canPick = true, suggested = true }
      list[#list + 1] = { char = c, fit = fit }
    end
  end
  table.sort(list, function(a, b)
    local fa, fb = FIT_ORDER[a.fit.kind] or 9, FIT_ORDER[b.fit.kind] or 9
    if fa ~= fb then return fa < fb end
    local sa, sb = a.char.guid == selfGuid, b.char.guid == selfGuid
    if sa ~= sb then return sa end
    local la, lb = tonumber(a.char.level) or 0, tonumber(b.char.level) or 0
    if la ~= lb then return la > lb end
    return tostring(a.char.name) < tostring(b.char.name)
  end)
  return list
end

--[[ CF-63b: the role toggles for a class in a run, with how full each role's slots are without your own answer:
{ { role, state = "open" | "full", label = "Healer · open" | "Damage · full" } }, the class's roles in the order
tank, heal, dps. "full": answering I'm in with it makes you a reserve. ]]
function PlannedRuns.roleChoices(run, candidates, dungeon, classFile, me)
  local others = {}
  for _, a in ipairs(type(run) == "table" and run.answers or {}) do
    if not (me and isMe(a, me)) then others[#others + 1] = a end
  end
  local free = {}
  for _, slot in ipairs(PlannedRuns.slots({ answers = others }, candidates, dungeon)) do
    if not slot.answer or slot.maybe then free[slot.role] = true end
  end
  local list = {}
  for _, role in ipairs(PlannedRuns.rolesFor(classFile)) do
    local state = free[role] and "open" or "full"
    list[#list + 1] = { role = role, state = state, label = PlannedRuns.ROLE_NAMES[role] .. " \194\183 " .. state }
  end
  return list
end

-- The first role a run still needs, tank before healer before damage: "tank" | "heal" | "dps" | nil.
function PlannedRuns.neededRole(run, candidates, dungeon)
  for _, slot in ipairs(PlannedRuns.slots(run, candidates, dungeon)) do
    if not slot.answer then return slot.role end
  end
  return nil
end

-- A run's time in a sentence: "at 20:30" today, else "on Fri 20:00" (rowTime).
local function atText(run, now, dateFn)
  local t = PlannedRuns.rowTime(run.startsAt, now, dateFn)
  return (t:find(" ", 1, true) and "on " or "at ") .. t
end

local NEED = { tank = "a Tank", heal = "a Healer", dps = "a damage dealer" }

--[[ CF-63b: the whisper prefilled to fill a slot (the player sends it): "Up for SM: Graveyard at 20:30? We need a
Healer." name: the dungeon's name (Dungeons.runName); role: the slot's, or nil. ]]
function PlannedRuns.whisperText(run, name, role, now, dateFn)
  local out = string.format("Up for %s %s?", tostring(PlannedRuns.shortName(name)), atText(run, now, dateFn))
  if NEED[role] then out = out .. " We need " .. NEED[role] .. "." end
  return out
end

-- CF-63b: the note of "Ask now for this run": "For SM: Graveyard 20:30 · need Healer" (GroupAsk keeps 120 chars).
function PlannedRuns.askNote(run, name, role, now, dateFn)
  local out = string.format("For %s %s", tostring(PlannedRuns.shortName(name)),
    PlannedRuns.rowTime(run.startsAt, now, dateFn))
  if PlannedRuns.ROLE_NAMES[role] then out = out .. " \194\183 need " .. PlannedRuns.ROLE_NAMES[role] end
  return out
end

PlannedRuns.PLAN_HOUR = 20       -- CF-63c: the planning chips' time, your clock
PlannedRuns.PLAN_MIN_LEAD = 3600 -- "Tonight" only while it is at least this far away

--[[ CF-63c: the planning chips: the next three evenings at PLAN_HOUR:00 your time,
{ { label = "Tonight 20:00" | "Tomorrow 20:00" | "Fri 20:00", startsAt } }. timeFn: local date table -> server
seconds (Panels.localTime in game, os.time in tests). Tonight only while it is at least PLAN_MIN_LEAD away. ]]
function PlannedRuns.planChips(now, dateFn, timeFn)
  local clock = string.format("%02d:00", PlannedRuns.PLAN_HOUR)
  local list = {}
  for i, d in ipairs(PlannedRuns.dayChoices(now, dateFn)) do
    if #list >= 3 then break end
    local at = timeFn({ year = d.year, month = d.month, day = d.day, hour = PlannedRuns.PLAN_HOUR, min = 0, sec = 0 })
    if type(at) == "number" and at - now >= PlannedRuns.PLAN_MIN_LEAD then
      local day = i == 1 and "Tonight" or i == 2 and "Tomorrow" or d.label
      list[#list + 1] = { label = day .. " " .. clock, startsAt = at }
    end
  end
  return list
end

ns.PlannedRuns = PlannedRuns
return PlannedRuns
