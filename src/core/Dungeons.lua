-- Dungeons: the dungeon planner (CF-24). Pure Lua, no WoW globals.
-- Which Vanilla dungeons fit your characters, who else is in range and a suggested group. (CF-46: the
-- calendar event matching was removed; planned runs come from the website, core/PlannedRuns.lua.)
local _, ns = ...

local Dungeons = {}

Dungeons.GROUP_SIZE = 5

--[[ Vanilla dungeons with their usual level ranges. areas: quest log headers (CF-19) of the dungeon's
quests; Scarlet Monastery and Dire Maul share one header over their wings. areaIds: AreaTable IDs, the
`zoneOrSort` of the dungeon's quests in QuestieDB (from its zone enum and Forever dungeon table, whose
notes give the IDs some dungeons' quests use instead: Gnomeregan 133, Razorfen Kraul 1717, Uldaman 1517,
Zul'Farrak 978, Sunken Temple 1417; the Scarlet Monastery wings and Blackrock Spire share theirs).
Raids are left out. ]]
Dungeons.STATIC = {
  { id = "rfc", activities = { 798 }, name = "Ragefire Chasm", min = 13, max = 18, areaIds = { 2437 },
    areas = { "Ragefire Chasm" } },
  { id = "wc", activities = { 796 }, name = "Wailing Caverns", min = 17, max = 24, areaIds = { 718 },
    areas = { "Wailing Caverns" } },
  { id = "dm", activities = { 799 }, name = "The Deadmines", min = 17, max = 26, areaIds = { 1581 },
    areas = { "The Deadmines", "Deadmines" } },
  { id = "sfk", activities = { 800 }, name = "Shadowfang Keep", min = 22, max = 30, areaIds = { 209 },
    areas = { "Shadowfang Keep" } },
  { id = "bfd", activities = { 801 }, name = "Blackfathom Deeps", min = 24, max = 32, areaIds = { 719 },
    areas = { "Blackfathom Deeps" } },
  { id = "stocks", activities = { 802 }, name = "The Stockade", min = 24, max = 32, areaIds = { 717 },
    areas = { "The Stockade" } },
  { id = "gnomer", activities = { 803 }, name = "Gnomeregan", min = 29, max = 38, areaIds = { 721, 133 },
    areas = { "Gnomeregan" } },
  { id = "rfk", activities = { 804 }, name = "Razorfen Kraul", min = 29, max = 38, areaIds = { 491, 1717 },
    areas = { "Razorfen Kraul" } },
  { id = "smgy", activities = { 805 }, name = "Scarlet Monastery Graveyard", min = 26, max = 36, areaIds = { 796 },
    areas = { "Scarlet Monastery" } },
  { id = "smlib", activities = { 829 }, name = "Scarlet Monastery Library", min = 29, max = 39, areaIds = { 796 },
    areas = { "Scarlet Monastery" } },
  { id = "smarm", activities = { 827 }, name = "Scarlet Monastery Armory", min = 32, max = 42, areaIds = { 796 },
    areas = { "Scarlet Monastery" } },
  { id = "smcath", activities = { 828 }, name = "Scarlet Monastery Cathedral", min = 35, max = 45, areaIds = { 796 },
    areas = { "Scarlet Monastery" } },
  { id = "rfd", activities = { 806 }, name = "Razorfen Downs", min = 37, max = 46, areaIds = { 722 },
    areas = { "Razorfen Downs" } },
  { id = "ulda", activities = { 807 }, name = "Uldaman", min = 41, max = 51, areaIds = { 1337, 1517 },
    areas = { "Uldaman" } },
  { id = "zf", activities = { 808 }, name = "Zul'Farrak", min = 44, max = 54, areaIds = { 1176, 978 },
    areas = { "Zul'Farrak" } },
  { id = "mara", activities = { 809 }, name = "Maraudon", min = 46, max = 55, areaIds = { 2100 },
    areas = { "Maraudon" } },
  { id = "st", activities = { 810 }, name = "Sunken Temple", min = 50, max = 56, areaIds = { 1417, 1477 },
    areas = { "Sunken Temple", "Temple of Atal'Hakkar" } },
  { id = "brd", activities = { 811 }, name = "Blackrock Depths", min = 52, max = 60, areaIds = { 1584 },
    areas = { "Blackrock Depths" } },
  { id = "lbrs", activities = { 812 }, name = "Lower Blackrock Spire", min = 55, max = 60, areaIds = { 1583 },
    areas = { "Lower Blackrock Spire", "Blackrock Spire" } },
  { id = "ubrs", activities = { 837 }, name = "Upper Blackrock Spire", min = 55, max = 60, areaIds = { 1583 },
    areas = { "Upper Blackrock Spire", "Blackrock Spire" } },
  { id = "dme", activities = { 813, 814, 815 }, name = "Dire Maul", min = 55, max = 60, areaIds = { 2557 },
    areas = { "Dire Maul" } },
  { id = "scholo", activities = { 797 }, name = "Scholomance", min = 58, max = 60, areaIds = { 2057 },
    areas = { "Scholomance" } },
  { id = "strat", activities = { 816, 1603 }, name = "Stratholme", min = 58, max = 60, areaIds = { 2017 },
    areas = { "Stratholme" } },
}

-- CF-42: where each dungeon's entrance is, for the card's header (English, rule 6). Dungeons only the Group
-- Finder knows (Forever's new ones) have none.
Dungeons.ZONES = {
  rfc = "Orgrimmar", wc = "The Barrens", dm = "Westfall", sfk = "Silverpine Forest", bfd = "Ashenvale",
  stocks = "Stormwind City", gnomer = "Dun Morogh", rfk = "The Barrens", smgy = "Tirisfal Glades",
  smlib = "Tirisfal Glades", smarm = "Tirisfal Glades", smcath = "Tirisfal Glades", rfd = "The Barrens",
  ulda = "Badlands", zf = "Tanaris", mara = "Desolace", st = "Swamp of Sorrows", brd = "Blackrock Mountain",
  lbrs = "Blackrock Mountain", ubrs = "Blackrock Mountain", dme = "Feralas", scholo = "Western Plaguelands",
  strat = "Eastern Plaguelands",
}

-- The dungeons in use: STATIC, updated from the Group Finder when it is available (applyGroupFinder).
Dungeons.LIST = Dungeons.STATIC

--[[ Rebuilds LIST from STATIC and the Group Finder's dungeon activities (CF-24, V46):
  activities = { { activityID, name, shortName, min, max } } (C_LFGList; only dungeons).
Only dungeons the Group Finder offers are listed (feedback: no Stockade on a Horde character). A dungeon
in STATIC linked to activities takes the game's level range (lowest min, highest max of its activities,
e.g. the Dire Maul wings). Activities not linked to STATIC are dungeons STATIC does not know (Forever's new
ones): they are added with the game's name and range, without quest area data. Without activities LIST
stays STATIC. (The Stockade's activity 802 is assumed from the numbering: Horde characters do not see it.) ]]
function Dungeons.applyGroupFinder(activities)
  if type(activities) ~= "table" or #activities == 0 then
    Dungeons.LIST = Dungeons.STATIC
    return Dungeons.LIST
  end
  local byActivity = {}
  for _, a in ipairs(activities) do
    if type(a.activityID) == "number" then byActivity[a.activityID] = a end
  end
  local list, linked = {}, {}
  for _, d in ipairs(Dungeons.STATIC) do
    local copy = {}
    for k, v in pairs(d) do copy[k] = v end
    local min, max, offered
    for _, activityID in ipairs(d.activities or {}) do
      local a = byActivity[activityID]
      if a then
        linked[activityID], offered = true, true
        if type(a.min) == "number" and a.min > 0 then min = math.min(min or a.min, a.min) end
        if type(a.max) == "number" and a.max > 0 then max = math.max(max or a.max, a.max) end
      end
    end
    if min and max and min <= max then copy.min, copy.max = min, max end
    if offered then list[#list + 1] = copy end
  end
  for _, a in ipairs(activities) do
    if not linked[a.activityID] and type(a.name) == "string" and type(a.min) == "number" and type(a.max) == "number"
       and a.min > 0 and a.max >= a.min then
      list[#list + 1] = { id = "lfg" .. a.activityID, activities = { a.activityID }, name = a.name, min = a.min,
                          max = a.max, areaIds = {}, areas = { a.name } }
    end
  end
  Dungeons.LIST = list
  return list
end

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

--[[ Dungeons that fit the character you are on (selfGuid; CF-42: the list follows it), most people in range
first (then lowest level). Without selfGuid any of your characters counts.
  { { dungeon, fits, selfGuid, people = n, quests = n distinct quest IDs, candidates = { candidate + questIDs } } }
Candidates are sorted best first (see better). include: optional { [dungeonId] = true } listed even when
it does not fit (a planned run's dungeon, fits = false). ]]
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
        if c.own and (not selfGuid or c.guid == selfGuid) then mine = true end
      end
    end
    if mine or (include and include[dungeon.id]) then
      table.sort(list, better(dungeon, selfGuid))
      local count = 0
      for _ in pairs(people) do count = count + 1 end
      result[#result + 1] = { dungeon = dungeon, fits = mine, selfGuid = selfGuid, people = count,
                              quests = questCount, candidates = list }
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
The character you are on first (CF-42; without entry.selfGuid your best one: quests, online); then a tank
and a healer by role (CF-18) if someone has one; then the rest by quests for the dungeon, online, level.
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
  local own = first(function(c) return c.own and (not entry.selfGuid or c.guid == entry.selfGuid) end)
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

--[[ CF-42: the suggested group as five slots: tank, healer, three damage.
  { { role = "tank"|"heal"|"dps", char = candidate or nil, own = true|nil, missing = true|nil } }
A character goes to the slot of its role; the rest (damage, no role, a second tank or healer) fill the
damage slots, then any free slot. An empty tank or healer slot is missing (nobody in range brings one), an
empty damage slot is open. own: the character you are on (selfGuid). ]]
function Dungeons.slots(group, selfGuid)
  local slots = { { role = "tank" }, { role = "heal" }, { role = "dps" }, { role = "dps" }, { role = "dps" } }
  local rest = {}
  for _, c in ipairs(group or {}) do
    if c.role == "tank" and not slots[1].char then slots[1].char = c
    elseif c.role == "heal" and not slots[2].char then slots[2].char = c
    else rest[#rest + 1] = c end
  end
  for _, order in ipairs({ { 3, 4, 5 }, { 1, 2 } }) do
    for _, i in ipairs(order) do
      if not slots[i].char and #rest > 0 then slots[i].char = table.remove(rest, 1) end
    end
  end
  for _, slot in ipairs(slots) do
    if slot.char then
      slot.own = (selfGuid ~= nil and slot.char.guid == selfGuid) or nil
    elseif slot.role ~= "dps" then
      slot.missing = true
    end
  end
  return slots
end

-- CF-42: your other characters in range, not in the group ("Alternatives for you"), and everyone else in
-- range who is not in it ("Also in range"), in overview order.
function Dungeons.outside(entry, group)
  local inGroup, alternatives, others = {}, {}, {}
  for _, c in ipairs(group or {}) do inGroup[c.guid] = true end
  for _, c in ipairs(entry.candidates or {}) do
    if not inGroup[c.guid] then
      if c.own then alternatives[#alternatives + 1] = c else others[#others + 1] = c end
    end
  end
  return alternatives, others
end

-- The dungeon a text names, or nil (/cf ask Deadmines). By name, "The" optional ("Deadmines run"); the
-- longest matching name wins, so a wing beats a shorter name it contains.
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

-- ===== Dungeon quests (CF-24 feedback: "4/6", which quests you have and which you can still pick up) =====

-- True if a quest's requiredRaces mask allows the faction's race mask (0 = every race). Masks reach
-- bit 33 (Forever Skyborne races), beyond 32-bit bit operations, so this works on doubles bit by bit.
function Dungeons.factionAllows(requiredRaces, factionMask)
  if type(requiredRaces) ~= "number" or requiredRaces == 0 or type(factionMask) ~= "number" then return true end
  local a, b = requiredRaces, factionMask
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then return true end
    a, b = math.floor(a / 2), math.floor(b / 2)
  end
  return false
end

--[[ The quests of a dungeon for your character, with who in range has them.
  dungeon: a LIST entry. data: QuestieDB quests per area, or nil when QuestieDB is not installed:
    { [areaId] = { { id, name, level, requiredLevel, requiredRaces } } }
  ctx = { char = your character (candidate: level, quests), candidates = everyone in range (with
          questIDs, see overview), factionMask, completed = { [questID] = true } or nil }
Returns { complete = data ~= nil, have = n, total = n, quests = { { id, name, level, requiredLevel,
state = "have" | "available" | "later" | "done", holders = { name, ... } } } }, sorted: have, available,
later, done; then by level. total = have + available: quests you have or could pick up now. Without
data, the list is what anyone in range has in their quest log. ]]
function Dungeons.quests(dungeon, data, ctx)
  ctx = ctx or {}
  local char = ctx.char or {}
  local known, list = {}, {}
  local function add(id, name, level, requiredLevel)
    if known[id] then return known[id] end
    local q = { id = id, name = name, level = level, requiredLevel = requiredLevel, holders = {} }
    known[id] = q
    list[#list + 1] = q
    return q
  end
  if data then
    for _, areaId in ipairs(dungeon.areaIds or {}) do
      for _, q in ipairs(data[areaId] or {}) do
        if Dungeons.factionAllows(q.requiredRaces, ctx.factionMask) then
          add(q.id, q.name, q.level, q.requiredLevel)
        end
      end
    end
  end
  -- Quests in the logs of people in range (also when QuestieDB lacks one), with who has them.
  for _, c in ipairs(ctx.candidates or {}) do
    for _, id in ipairs(c.questIDs or questsFor(dungeon, c.quests)) do
      local logged = c.quests and c.quests[id]
      local q = add(id, logged and logged.title, nil, nil)
      q.name = q.name or (logged and logged.title)
      if c.guid ~= char.guid then q.holders[#q.holders + 1] = c.name end
    end
  end

  local have, total = 0, 0
  for _, q in ipairs(list) do
    if char.quests and char.quests[q.id] then
      q.state = "have"
    elseif ctx.completed and ctx.completed[q.id] then
      q.state = "done"
    elseif type(q.requiredLevel) == "number" and type(char.level) == "number" and q.requiredLevel > char.level then
      q.state = "later"
    else
      q.state = "available"
    end
    if q.state == "have" then have = have + 1 end
    if q.state == "have" or q.state == "available" then total = total + 1 end
    table.sort(q.holders)
  end
  local order = { have = 1, available = 2, later = 3, done = 4 }
  table.sort(list, function(a, b)
    if a.state ~= b.state then return order[a.state] < order[b.state] end
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  return { complete = data ~= nil, have = have, total = total, quests = list }
end

ns.Dungeons = Dungeons
return Dungeons
