-- Dungeons: the dungeon planner (CF-24). Pure Lua, no WoW globals.
-- Which Vanilla dungeons fit your characters, who else is in range, a suggested group, and the
-- community calendar events that mention a dungeon.
local _, ns = ...

local Dungeons = {}

Dungeons.GROUP_SIZE = 5

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

-- Words in an event title that point at a dungeon (lower case), besides its name.
local ALIASES = {
  rfc = { "rfc" }, wc = { "wc" }, dm = { "deadmines", "vc" }, sfk = { "sfk" }, bfd = { "bfd" },
  stocks = { "stockade", "stocks" }, gnomer = { "gnomer" }, rfk = { "rfk" },
  smgy = { "sm gy", "graveyard" }, smlib = { "sm lib", "library" }, smarm = { "sm arm", "armory" },
  smcath = { "sm cath", "cathedral" }, rfd = { "rfd" }, ulda = { "ulda" }, zf = { "zf" },
  mara = { "mara" }, st = { "atal'hakkar" }, brd = { "brd" }, lbrs = { "lbrs" }, ubrs = { "ubrs" },
  dme = { "dm east", "dm west", "dm north", "dire maul" }, scholo = { "scholo" }, strat = { "strat" },
}

local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }
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
  { { dungeon, people = n, quests = n distinct quest IDs, candidates = { candidate + questIDs } } }
Candidates are sorted best first (see better). ]]
function Dungeons.overview(candidates, selfGuid)
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
    if mine then
      table.sort(list, better(dungeon, selfGuid))
      local count = 0
      for _ in pairs(people) do count = count + 1 end
      result[#result + 1] = { dungeon = dungeon, people = count, quests = questCount, candidates = list }
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

-- "<dungeon> run", the title to give the calendar event.
function Dungeons.eventTitle(dungeon)
  return dungeon.name .. " run"
end

-- "Ann Example (Tank), Ben Example (Healer), Cid Example" for the event description.
function Dungeons.groupText(group)
  local names = {}
  for i, c in ipairs(group) do
    local role = c.role and ROLE_NAMES[c.role]
    names[i] = tostring(c.name) .. (role and (" (" .. role .. ")") or "")
  end
  return table.concat(names, ", ")
end

local function minutes(t)
  -- Sortable minute count of a CalendarTime { year, month, monthDay, hour, minute }.
  return ((((t.year or 0) * 12 + (t.month or 0)) * 31 + (t.monthDay or 0)) * 24 + (t.hour or 0)) * 60
    + (t.minute or 0)
end

local function mentions(title, dungeon)
  local lower = title:lower()
  if lower:find(dungeon.name:lower(), 1, true) then return true end
  for _, word in ipairs(ALIASES[dungeon.id] or {}) do
    -- Whole words only, so "wc" does not match inside another word.
    local s, e = lower:find(word, 1, true)
    while s do
      local before, after = lower:sub(s - 1, s - 1), lower:sub(e + 1, e + 1)
      if not before:match("[%w']") and not after:match("[%w']") then return true end
      s, e = lower:find(word, e + 1, true)
    end
  end
  return false
end

--[[ Upcoming calendar events that mention the dungeon in their title, soonest first. Holidays are left
out; events that started before `now` too. events: { { title, calendarType, startTime, inviteStatus } }
(C_Calendar.GetDayEvent, V33); now: CalendarTime. ]]
function Dungeons.events(events, dungeon, now)
  local result = {}
  for _, e in ipairs(events or {}) do
    if type(e.title) == "string" and e.calendarType ~= "HOLIDAY" and type(e.startTime) == "table"
       and (not now or minutes(e.startTime) >= minutes(now)) and mentions(e.title, dungeon) then
      result[#result + 1] = e
    end
  end
  table.sort(result, function(a, b) return minutes(a.startTime) < minutes(b.startTime) end)
  return result
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
