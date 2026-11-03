-- Missions: levels, play and dungeons on recorded data (CF-72).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Facts of a day or week under facts.records = { levelDays = { [day] = true }, lowbie, dingDungeon, dingFriend,
-- speedRun (bool), newDungeons = { [guid|name] = true }, skillBase = { [guid] = { [line] = rank } },
-- skillGain = { [line] = n }, switchUp (bool), dustOff (bool) }.
-- Local stored data (RecordEvents): self.doomsday.dungeonsSeen = { [guid] = { [name] = true } } and
-- self.doomsday.lastLogin = { [guid] = server time }. Both optional, nil = unknown (rule 8).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Records = {}

Records.LOWBIE = 20             -- d.lowbie: the level before the ding is below this
Records.SPEED_BOSSES = 3        -- d.speedRun: bosses of one dungeon ...
Records.SPEED_SECONDS = 45 * 60 -- ... within this time of the first entry
Records.IDLE_SECONDS = 7 * 86400 -- d.dustOff: a week away
Records.COOKING, Records.FISHING, Records.FIRST_AID = 185, 356, 129 -- skill lines
Records.MAX_NEW = 50            -- new dungeons kept per day or week (a cap, as Goals' lists)

local SKILL_LINES = { [Records.COOKING] = true, [Records.FISHING] = true, [Records.FIRST_AID] = true }

local function factsOf(f)
  local r = f.records
  if type(r) ~= "table" then
    r = { levelDays = {}, lowbie = 0, dingDungeon = 0, dingFriend = 0, speedRun = false, newDungeons = {},
          skillBase = {}, skillGain = {}, switchUp = false, dustOff = false }
    f.records = r
  end
  return r
end

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

-- ===== Helpers for RecordEvents (the decisions stay here) =====

--[[ Whether one of the group's GUIDs is a friend's community character: a member of the selected community
(members = { [guid] = member }) owned by another BattleTag (people = { [bt] = { chars = { [guid] = c } } },
presence = { [guid] = { battleTag } }, mine = the own BattleTag). ]]
function Records.friendGrouped(groupGuids, members, people, presence, mine)
  if type(groupGuids) ~= "table" or type(members) ~= "table" then return false end
  for _, guid in ipairs(groupGuids) do
    if members[guid] then
      for bt, person in pairs(people or {}) do
        if bt ~= mine and type(person) == "table" and type(person.chars) == "table" and person.chars[guid] then
          return true
        end
      end
      local link = type(presence) == "table" and presence[guid]
      if type(link) == "table" and link.battleTag and link.battleTag ~= mine then return true end
    end
  end
  return false
end

--[[ The dungeons each own character has a party run of, from the stored own feed (feed = { [day] = { [guid] =
{ runs = { { name, kind, bosses } } } } }): the start of self.doomsday.dungeonsSeen. ]]
function Records.seedDungeons(feed)
  local seen = {}
  for _, day in pairs(type(feed) == "table" and feed or {}) do
    for guid, entry in pairs(type(day) == "table" and day or {}) do
      for _, run in ipairs(type(entry) == "table" and type(entry.runs) == "table" and entry.runs or {}) do
        if type(run) == "table" and run.kind == "party" and type(run.name) == "string" then
          seen[guid] = seen[guid] or {}
          seen[guid][run.name] = true
        end
      end
    end
  end
  return seen
end

-- Adds a dungeon to a character's set (seen = self.doomsday.dungeonsSeen, in place). True when it is new.
function Records.markDungeon(seen, guid, name)
  if type(seen) ~= "table" or type(guid) ~= "string" or type(name) ~= "string" then return false end
  local set = seen[guid]
  if type(set) ~= "table" then
    set = {}
    seen[guid] = set
  end
  if set[name] then return false end
  set[name] = true
  return true
end

--[[ The last login of each own character before this one (lastLogin = self.doomsday.lastLogin, in place):
seeded once from the stored lastPlayed of the other characters (the current one is already marked played at
login, so it stays unknown until its next login). chars = { [guid] = { lastPlayed } }. Returns the previous
login of guid (nil: unknown) and records now. ]]
function Records.login(lastLogin, chars, guid, now)
  if type(lastLogin) ~= "table" or type(guid) ~= "string" then return nil end
  for g, c in pairs(type(chars) == "table" and chars or {}) do
    if g ~= guid and lastLogin[g] == nil and type(c) == "table" and type(c.lastPlayed) == "number" then
      lastLogin[g] = c.lastPlayed
    end
  end
  local previous = lastLogin[guid]
  if type(now) == "number" then lastLogin[guid] = now end
  return type(previous) == "number" and previous or nil
end

-- The character was played until now (logout): its next login compares with this (lastLogin in place).
function Records.played(lastLogin, guid, now)
  if type(lastLogin) == "table" and type(guid) == "string" and type(now) == "number" then lastLogin[guid] = now end
end

-- ===== Observations =====

--[[ recordDing: a level gained by the current character (PLAYER_LEVEL_UP).
  { guid, level (the new one), instance (GetInstanceInfo type, "party" in a dungeon), friend (bool: grouped with
  a friend's community character, Records.friendGrouped), day (Doomsday day) } ]]
ns.Goals.registerKind("recordDing", function(f, obs)
  local r = factsOf(f)
  if type(obs.day) == "number" then r.levelDays[obs.day] = true end
  if type(obs.level) == "number" and obs.level - 1 < Records.LOWBIE then r.lowbie = r.lowbie + 1 end
  if obs.instance == "party" then r.dingDungeon = r.dingDungeon + 1 end
  if obs.friend == true then r.dingFriend = r.dingFriend + 1 end
end)

--[[ recordBoss: a boss of the current party run died (the run as ActivityTracker keeps it).
  { guid, name (the dungeon), bosses (killed so far in this run), seconds (since the first entry), new (bool:
  the first boss of a dungeon this character had no earlier run of, Records.markDungeon) } ]]
ns.Goals.registerKind("recordBoss", function(f, obs)
  local r = factsOf(f)
  if type(obs.bosses) == "number" and obs.bosses >= Records.SPEED_BOSSES and type(obs.seconds) == "number"
      and obs.seconds <= Records.SPEED_SECONDS then
    r.speedRun = true
  end
  if obs.new == true and type(obs.guid) == "string" and type(obs.name) == "string"
      and count(r.newDungeons) < Records.MAX_NEW then
    r.newDungeons[obs.guid .. "|" .. obs.name] = true
  end
end)

--[[ recordSkills: the professions of the current character (each snapshot change).
  { guid, professions = { [skillLine] = rank } }. The first sight of a character that day or week is the base;
  a line learned later counts from 0 (as Goals' skill points). Only Cooking, Fishing and First Aid. ]]
ns.Goals.registerKind("recordSkills", function(f, obs)
  if type(obs.guid) ~= "string" or type(obs.professions) ~= "table" then return end
  local r = factsOf(f)
  local base = r.skillBase[obs.guid]
  if base == nil then
    base = {}
    for line, rank in pairs(obs.professions) do
      if SKILL_LINES[line] and type(rank) == "number" then base[line] = rank end
    end
    r.skillBase[obs.guid] = base
    return
  end
  for line, rank in pairs(obs.professions) do
    if SKILL_LINES[line] and type(rank) == "number" then
      local was = base[line] or 0
      if rank > was then
        r.skillGain[line] = (r.skillGain[line] or 0) + (rank - was)
        base[line] = rank
      end
    end
  end
end)

--[[ recordLogin: a character logged in. { guid, previous (its last login, Records.login; nil: unknown), now,
  since (start of the previous Doomsday day) }. ]]
ns.Goals.registerKind("recordLogin", function(f, obs)
  if type(obs.previous) ~= "number" then return end
  local r = factsOf(f)
  if type(obs.since) == "number" and obs.previous < obs.since then r.switchUp = true end
  if type(obs.now) == "number" and obs.now - obs.previous >= Records.IDLE_SECONDS then r.dustOff = true end
end)

-- ===== Progress =====

local function rec(f) return type(f.records) == "table" and f.records or {} end
local function bool(value) return value and 1 or 0 end

local function runs(f)
  local n = 0
  for _ in ipairs(f.runs or {}) do n = n + 1 end
  return n
end

local function bosses(f)
  local n = 0
  for _, run in ipairs(f.runs or {}) do n = n + (run.bosses or 0) end
  return n
end

local function gain(f, line) return (rec(f).skillGain or {})[line] or 0 end

local PROGRESS = {
  ["d.levels2"] = function(f) return f.levels or 0, 2 end,
  ["d.lowbie"] = function(f) return rec(f).lowbie or 0, 1 end,
  ["d.dingDungeon"] = function(f) return rec(f).dingDungeon or 0, 1 end,
  ["d.dingFriend"] = function(f) return rec(f).dingFriend or 0, 1 end,
  ["d.dungeons2"] = function(f) return runs(f), 2 end,
  ["d.speedRun"] = function(f) return bool(rec(f).speedRun), 1 end,
  ["d.newDungeon"] = function(f) return count(rec(f).newDungeons), 1 end,
  ["d.chars3"] = function(f) return f.chars or 0, 3 end,
  ["d.switchUp"] = function(f) return bool(rec(f).switchUp), 1 end,
  ["d.dustOff"] = function(f) return bool(rec(f).dustOff), 1 end,
  ["d.cookSkill5"] = function(f) return gain(f, Records.COOKING), 5 end,
  ["d.fishSkill5"] = function(f) return gain(f, Records.FISHING), 5 end,
  ["d.aidSkill5"] = function(f) return gain(f, Records.FIRST_AID), 5 end,

  ["w.levels5"] = function(f) return f.levels or 0, 5 end,
  ["w.levelDays3"] = function(f) return count(rec(f).levelDays), 3 end,
  ["w.dungeons5"] = function(f) return runs(f), 5 end,
  ["w.bosses15"] = function(f) return bosses(f), 15 end,
  ["w.newDungeons2"] = function(f) return count(rec(f).newDungeons), 2 end,
  ["w.days7"] = function(f) return f.days or 0, 7 end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Records.IDS = {}
for id in pairs(PROGRESS) do Records.IDS[#Records.IDS + 1] = id end
table.sort(Records.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Records = Records
return Records
