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
local function list(raw, max, clean)
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

local function run(raw)
  if type(raw) ~= "table" then return nil end
  local r = {
    id = token(raw.id, PlannedRuns.MAX_ID),
    dungeon = token(raw.dungeon, PlannedRuns.MAX_ID),
    startsAt = time(raw.startsAt),
  }
  if not (r.id and r.dungeon and r.startsAt) then return nil end
  r.state = oneOf(PlannedRuns.STATES, raw.state)
  r.note = text(raw.note, PlannedRuns.MAX_NOTE)
  r.url = url(raw.url)
  r.organiser = person(raw.organiser)
  if r.organiser and type(raw.organiser) == "table" then
    r.organiser.utcOffset = number(raw.organiser.utcOffset, -PlannedRuns.MAX_UTC_OFFSET, PlannedRuns.MAX_UTC_OFFSET)
  end
  r.answers = list(raw.answers, PlannedRuns.MAX_ANSWERS, answer)
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

  local runs, dropped = list(raw.runs, PlannedRuns.MAX_RUNS, run)
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
  return {
    v = v,
    updatedAt = updatedAt,
    reminderMinutes = number(raw.reminderMinutes, 0, PlannedRuns.MAX_REMINDER),
    runs = unique,
    dropped = dropped,
  }
end

ns.PlannedRuns = PlannedRuns
return PlannedRuns
