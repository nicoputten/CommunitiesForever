-- Missions: quest details at turn-in and accept (CF-71).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Quests = {}

Quests.BURST_SECONDS = 600 -- d.questBurst: 3 quests within 10 minutes
Quests.BURST_COUNT = 3
Quests.MAX_ACCEPTED = 100  -- distinct quest IDs kept per day or week (d.accept5 needs 5)
Quests.MAX_CHARS = 20      -- characters with turn-in times kept per day or week

-- Quest log headers of class quests: the class name, English (CLAUDE.md rule 6).
Quests.CLASS_HEADERS = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local function num(v) return type(v) == "number" and v or nil end

--[[ True when one of groupGuids is a friend's character: a character of another BattleTag in people
({ [battleTag] = { chars = { [guid] } } }) or presence ({ [guid] = { battleTag } }), as DoomsdayTracker's owners.
Own alts (ownTag) never count. ]]
function Quests.friendInGroup(groupGuids, people, presence, ownTag)
  for _, guid in ipairs(groupGuids or {}) do
    for tag, person in pairs(people or {}) do
      if tag ~= ownTag and type(person) == "table" and type(person.chars) == "table" and person.chars[guid] then
        return true
      end
    end
    local link = type(presence) == "table" and presence[guid]
    if type(link) == "table" and link.battleTag and link.battleTag ~= ownTag then return true end
  end
  return false
end

--[[ The questDone observation of a hand-in, from the stored own character (Snapshot Char: guid, level, classFile,
quests) and the questID. The quest's details come from the stored log, read before its refresh removes the
quest; a quest the log doesn't know (accepted and handed in between two reads) has none. t: server time.
grouped: a friend's community character in the group (Quests.friendInGroup). ]]
function Quests.turnIn(char, questID, t, grouped)
  char = type(char) == "table" and char or {}
  local quest = type(questID) == "number" and type(char.quests) == "table" and char.quests[questID] or nil
  quest = type(quest) == "table" and quest or {}
  return {
    kind = "questDone", t = num(t), guid = char.guid, charLevel = num(char.level), classFile = char.classFile,
    level = num(quest.level), group = num(quest.suggestedGroup), area = quest.area, dungeon = quest.dungeon == true,
    grouped = grouped == true,
  }
end

local function facts(f)
  if type(f.quests2) ~= "table" then f.quests2 = {} end
  return f.quests2
end

local function add(q, key) q[key] = (q[key] or 0) + 1 end

--[[ facts.quests2 = { up, group, class, dungeon, together (counts), burst (most quests one character handed in
within BURST_SECONDS), times = { [guid] = { t, ... } } (the last BURST_COUNT - 1), accepted = { [questID] = true },
acceptedCount }. ]]
local function questDone(f, obs)
  local q = facts(f)
  if obs.level and obs.charLevel and obs.level > obs.charLevel then add(q, "up") end
  if obs.group and obs.group > 0 then add(q, "group") end
  local header = obs.classFile and Quests.CLASS_HEADERS[obs.classFile]
  if header and obs.area == header then add(q, "class") end
  if obs.dungeon == true then add(q, "dungeon") end
  if obs.grouped == true then add(q, "together") end
  if type(obs.t) == "number" and type(obs.guid) == "string" then
    q.times = type(q.times) == "table" and q.times or {}
    local list = q.times[obs.guid]
    if type(list) ~= "table" then
      local n = 0
      for _ in pairs(q.times) do n = n + 1 end
      if n >= Quests.MAX_CHARS then return end
      list = {}
      q.times[obs.guid] = list
    end
    local inWindow = 1
    for _, t in ipairs(list) do
      if type(t) == "number" and obs.t - t <= Quests.BURST_SECONDS and obs.t >= t then inWindow = inWindow + 1 end
    end
    q.burst = math.max(q.burst or 0, inWindow)
    list[#list + 1] = obs.t
    while #list > Quests.BURST_COUNT - 1 do table.remove(list, 1) end
  end
end

local function questAccepted(f, obs)
  local id = num(obs.questID)
  if not id or id <= 0 then return end
  local q = facts(f)
  q.accepted = type(q.accepted) == "table" and q.accepted or {}
  if q.accepted[id] or (q.acceptedCount or 0) >= Quests.MAX_ACCEPTED then return end
  q.accepted[id] = true
  q.acceptedCount = (q.acceptedCount or 0) + 1
end

local function counter(key, target)
  return function(pf)
    local q = type(pf.quests2) == "table" and pf.quests2 or {}
    return math.min(num(q[key]) or 0, target), target
  end
end

Quests.PROGRESS = {
  ["d.questUp"] = counter("up", 1),
  ["d.groupQuest"] = counter("group", 1),
  ["d.classQuest"] = counter("class", 1),
  ["d.dungeonQuest"] = counter("dungeon", 1),
  ["d.questBurst"] = counter("burst", Quests.BURST_COUNT),
  ["d.accept5"] = counter("acceptedCount", 5),
  ["d.questTogether"] = counter("together", 1),
  -- Weeklies that read this data (DOOMSDAY-WEEKLY-CATALOGUE.md, listed by CF-79).
  ["w.groupQuests3"] = counter("group", 3),
  ["w.questUp5"] = counter("up", 5),
  ["w.duoQuests5"] = counter("together", 5),
}

ns.Goals.registerKind("questDone", questDone)
ns.Goals.registerKind("questAccepted", questAccepted)
for id, fn in pairs(Quests.PROGRESS) do ns.Doomsday.registerProgress(id, fn) end

ns.Missions = ns.Missions or {}
ns.Missions.Quests = Quests
return Quests
