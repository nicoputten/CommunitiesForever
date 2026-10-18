-- Dungeons: the dungeon planner (CF-24). Pure Lua, no WoW globals.
-- Which Vanilla dungeons fit your characters, who else is in range, a suggested group, and the
-- community calendar events that mention a dungeon.
local _, ns = ...

local Dungeons = {}

Dungeons.GROUP_SIZE = 5
Dungeons.PLANNED_DAYS = 3 -- a calendar run this close counts as planned (tab counter, Planned list)

--[[ Vanilla dungeons with their usual level ranges. areas: quest log headers (CF-19) of the dungeon's
quests; Scarlet Monastery and Dire Maul share one header over their wings. Raids are left out. ]]
Dungeons.LIST = {
  { id = "rfc", name = "Ragefire Chasm", min = 13, max = 18, areas = { "Ragefire Chasm" } },
  { id = "wc", name = "Wailing Caverns", min = 17, max = 24, areas = { "Wailing Caverns" } },
  { id = "dm", name = "The Deadmines", min = 17, max = 26, areas = { "The Deadmines", "Deadmines" } },
  { id = "sfk", name = "Shadowfang Keep", min = 22, max = 30, areas = { "Shadowfang Keep" } },
  { id = "bfd", name = "Blackfathom Deeps", min = 24, max = 32, areas = { "Blackfathom Deeps" } },
  { id = "stocks", name = "The Stockade", min = 24, max = 32, areas = { "The Stockade" } },
  { id = "gnomer", name = "Gnomeregan", min = 29, max = 38, areas = { "Gnomeregan" } },
  { id = "rfk", name = "Razorfen Kraul", min = 29, max = 38, areas = { "Razorfen Kraul" } },
  { id = "smgy", name = "Scarlet Monastery Graveyard", min = 26, max = 36, areas = { "Scarlet Monastery" } },
  { id = "smlib", name = "Scarlet Monastery Library", min = 29, max = 39, areas = { "Scarlet Monastery" } },
  { id = "smarm", name = "Scarlet Monastery Armory", min = 32, max = 42, areas = { "Scarlet Monastery" } },
  { id = "smcath", name = "Scarlet Monastery Cathedral", min = 35, max = 45, areas = { "Scarlet Monastery" } },
  { id = "rfd", name = "Razorfen Downs", min = 37, max = 46, areas = { "Razorfen Downs" } },
  { id = "ulda", name = "Uldaman", min = 41, max = 51, areas = { "Uldaman" } },
  { id = "zf", name = "Zul'Farrak", min = 44, max = 54, areas = { "Zul'Farrak" } },
  { id = "mara", name = "Maraudon", min = 46, max = 55, areas = { "Maraudon" } },
  { id = "st", name = "Sunken Temple", min = 50, max = 56, areas = { "Sunken Temple", "Temple of Atal'Hakkar" } },
  { id = "brd", name = "Blackrock Depths", min = 52, max = 60, areas = { "Blackrock Depths" } },
  { id = "lbrs", name = "Lower Blackrock Spire", min = 55, max = 60,
    areas = { "Lower Blackrock Spire", "Blackrock Spire" } },
  { id = "ubrs", name = "Upper Blackrock Spire", min = 55, max = 60,
    areas = { "Upper Blackrock Spire", "Blackrock Spire" } },
  { id = "dme", name = "Dire Maul", min = 55, max = 60, areas = { "Dire Maul" } },
  { id = "scholo", name = "Scholomance", min = 58, max = 60, areas = { "Scholomance" } },
  { id = "strat", name = "Stratholme", min = 58, max = 60, areas = { "Stratholme" } },
}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local function byId()
  local map = {}
  for _, d in ipairs(Dungeons.LIST) do map[d.id] = d end
  return map
end

function Dungeons.get(id) return byId()[id] end

local function inRange(dungeon, level)
  return type(level) == "number" and level >= dungeon.min and level <= dungeon.max
end

-- Quest IDs of a character's quests for a dungeon (by quest log area).
local function questsFor(dungeon, quests)
  local areas, ids = {}, {}
  for _, a in ipairs(dungeon.areas) do areas[a] = true end
  for id, q in pairs(quests or {}) do
    if type(q) == "table" and q.area and areas[q.area] then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

--[[ Everyone who could join, from the Linker view model:
  view = { people = { { battleTag, displayName, isSelf, chars = { row } } }, unlinked = { row } }
Returns { { key, displayName, own, guid, name, classFile, classID, level, role, online, quests } }.
key: one per person (BattleTag), or per character for unlinked community members (each is someone
else, CF-24 decision). Characters without a known level are left out. ]]
function Dungeons.candidates(view)
  local list = {}
  local function add(key, displayName, own, row)
    if type(row.level) ~= "number" then return end
    list[#list + 1] = { key = key, displayName = displayName, own = own, guid = row.guid, name = row.name,
                        classFile = row.classFile, classID = row.classID, level = row.level, role = row.role,
                        online = row.online == true, quests = row.quests }
  end
  for _, person in ipairs(view and view.people or {}) do
    local key = person.isSelf and "self" or person.battleTag
    for _, row in ipairs(person.chars or {}) do add(key, person.displayName, person.isSelf == true, row) end
  end
  for _, row in ipairs(view and view.unlinked or {}) do add("member:" .. tostring(row.guid), nil, false, row) end
  return list
end

local function mid(dungeon) return (dungeon.min + dungeon.max) / 2 end

-- Better pick first: more quests for the dungeon, online, the one you are on, closer to the middle of
-- the range, then by name (stable).
local function better(dungeon, selfGuid)
  return function(a, b)
    if #a.questIDs ~= #b.questIDs then return #a.questIDs > #b.questIDs end
    if a.online ~= b.online then return a.online end
    local ac, bc = a.guid == selfGuid, b.guid == selfGuid
    if ac ~= bc then return ac end
    local da, db = math.abs(a.level - mid(dungeon)), math.abs(b.level - mid(dungeon))
    if da ~= db then return da < db end
    return tostring(a.name) < tostring(b.name)
  end
end

--[[ Dungeons that fit at least one of your characters, most people in range first (then lowest level):
  { { dungeon, fits, people = n, quests = n distinct quest IDs, candidates = { candidate + questIDs } } }
Candidates are sorted best first (see better). include: optional { [dungeonId] = true } listed even when
none of your characters fits (planned runs, fits = false). ]]
function Dungeons.overview(candidates, selfGuid, include)
  local result = {}
  for _, dungeon in ipairs(Dungeons.LIST) do
    local list, people, mine, questSet, questCount = {}, {}, false, {}, 0
    for _, c in ipairs(candidates or {}) do
      if inRange(dungeon, c.level) then
        local entry = {}
        for k, v in pairs(c) do entry[k] = v end
        entry.questIDs = questsFor(dungeon, c.quests)
        for _, id in ipairs(entry.questIDs) do
          if not questSet[id] then
            questSet[id] = true
            questCount = questCount + 1
          end
        end
        list[#list + 1] = entry
        people[c.key] = true
        if c.own then mine = true end
      end
    end
    if mine or (include and include[dungeon.id]) then
      table.sort(list, better(dungeon, selfGuid))
      local count = 0
      for _ in pairs(people) do count = count + 1 end
      result[#result + 1] = { dungeon = dungeon, fits = mine, people = count, quests = questCount,
                              candidates = list }
    end
  end
  table.sort(result, function(a, b)
    if a.people ~= b.people then return a.people > b.people end
    if a.dungeon.min ~= b.dungeon.min then return a.dungeon.min < b.dungeon.min end
    return a.dungeon.name < b.dungeon.name
  end)
  return result
end

--[[ Suggested group for one overview entry: up to GROUP_SIZE characters, at most one per person.
Your best character first (in overview order: quests, online, the one you are on); then a tank and a
healer by role (CF-18) if someone has one; then the rest by quests for the dungeon, online, level.
Returns { candidate, ... } with candidate.reason: "you", "tank", "healer" or nil. ]]
function Dungeons.suggest(entry)
  local group, used = {}, {}
  local function take(c, reason)
    c.reason = reason
    group[#group + 1] = c
    used[c.key] = true
  end
  local function first(filter)
    for _, c in ipairs(entry.candidates) do
      if not used[c.key] and filter(c) then return c end
    end
  end
  local own = first(function(c) return c.own end)
  if own then take(own, "you") end
  local function hasRole(role)
    for _, c in ipairs(group) do if c.role == role then return true end end
    return false
  end
  local function all(role)
    local list = {}
    for _, c in ipairs(entry.candidates) do
      if not used[c.key] and c.role == role then list[#list + 1] = c end
    end
    return list
  end
  local needTank, needHeal = not hasRole("tank"), not hasRole("heal")
  local tanks, heals = needTank and all("tank") or {}, needHeal and all("heal") or {}
  -- Tank and healer from two different people (someone with both a tank and a healer character can
  -- only bring one), best tank first.
  local pairFound = false
  for _, t in ipairs(tanks) do
    for _, h in ipairs(heals) do
      if not pairFound and t.key ~= h.key then
        take(t, "tank")
        take(h, "healer")
        pairFound = true
      end
    end
  end
  if not pairFound then
    if tanks[1] then take(tanks[1], "tank") elseif heals[1] then take(heals[1], "healer") end
  end
  while #group < Dungeons.GROUP_SIZE do
    local c = first(function() return true end)
    if not c then break end
    take(c, nil)
  end
  return group
end

-- The title to give the calendar event: the dungeon name, which is what events are matched on.
function Dungeons.eventTitle(dungeon)
  return dungeon.name
end

-- Minutes since 1970-01-01 of a CalendarTime { year, month, monthDay, hour, minute }: exact across
-- months, so "within 3 days" works at a month end.
local function minutes(t)
  local y, m, d = t.year or 1970, t.month or 1, t.monthDay or 1
  y = m <= 2 and y - 1 or y
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m > 2 and m - 3 or m + 9) + 2) / 5) + d - 1
  local days = era * 146097 + yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy - 719468
  return (days * 24 + (t.hour or 0)) * 60 + (t.minute or 0)
end

-- The dungeon an event title names, or nil. By name, "The" optional ("Deadmines run"); the longest
-- matching name wins, so a wing beats a shorter name it contains.
function Dungeons.dungeonOf(title)
  if type(title) ~= "string" then return nil end
  local lower, best = title:lower(), nil
  for _, d in ipairs(Dungeons.LIST) do
    local name = d.name:lower()
    local short = name:gsub("^the ", "")
    if (lower:find(name, 1, true) or lower:find(short, 1, true)) and (not best or #d.name > #best.name) then
      best = d
    end
  end
  return best
end

local function upcoming(e, now)
  return type(e.title) == "string" and e.calendarType ~= "HOLIDAY" and type(e.startTime) == "table"
    and (not now or minutes(e.startTime) >= minutes(now))
end

local function soonest(a, b) return minutes(a.startTime) < minutes(b.startTime) end

--[[ Upcoming calendar events whose title names the dungeon, soonest first. Holidays and events that
started before `now` are left out. events: { { title, calendarType, startTime, inviteStatus, ... } }
(C_Calendar.GetDayEvent, V33/V42); now: CalendarTime. ]]
function Dungeons.events(events, dungeon, now)
  local result = {}
  for _, e in ipairs(events or {}) do
    if upcoming(e, now) and Dungeons.dungeonOf(e.title) == dungeon then result[#result + 1] = e end
  end
  table.sort(result, soonest)
  return result
end

-- Runs planned within PLANNED_DAYS: { { dungeon, event } }, soonest first.
function Dungeons.planned(events, now)
  local result, limit = {}, now and (minutes(now) + Dungeons.PLANNED_DAYS * 24 * 60)
  for _, e in ipairs(events or {}) do
    local dungeon = upcoming(e, now) and Dungeons.dungeonOf(e.title)
    if dungeon and (not limit or minutes(e.startTime) <= limit) then
      result[#result + 1] = { dungeon = dungeon, event = e }
    end
  end
  table.sort(result, function(a, b) return soonest(a.event, b.event) end)
  return result
end

-- Sign-ups of an event from its invite statuses (Enum.CalendarStatus on Mainline, V43): signed up,
-- accepted and confirmed count; tentative separately.
local SIGNED = { [1] = true, [3] = true, [6] = true }
function Dungeons.signUps(statuses)
  local signed, tentative = 0, 0
  for _, status in ipairs(statuses or {}) do
    if SIGNED[status] then signed = signed + 1 elseif status == 8 then tentative = tentative + 1 end
  end
  return signed, tentative
end

-- "Sat 20:00", short for the dungeon list.
function Dungeons.shortTime(t)
  return string.format("%s %02d:%02d", WEEKDAYS[t.weekday] or "?", t.hour or 0, t.minute or 0)
end

-- "Sat 25 Oct, 20:00".
function Dungeons.eventTime(t)
  return string.format("%s %d %s, %02d:%02d", WEEKDAYS[t.weekday] or "?", t.monthDay or 0,
    MONTHS[t.month] or "?", t.hour or 0, t.minute or 0)
end

-- Your sign-up for an event from its inviteStatus (Enum.CalendarStatus on Mainline), or nil.
local STATUS = { [1] = "you're available", [3] = "you confirmed", [6] = "you signed up", [8] = "you're tentative",
                 [2] = "you declined", [0] = "you're invited" }
function Dungeons.signUp(inviteStatus)
  return STATUS[inviteStatus]
end

ns.Dungeons = Dungeons
return Dungeons
