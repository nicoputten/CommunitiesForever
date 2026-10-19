-- Debug: hidden /cf debugon and /cf debugoff. Adds a fake friend to the window's view model only,
-- so features like shared quests (CF-19) can be checked without a second client. Never stored in
-- the DB and never synced (sync reads db.global, not the view). Lasts until /cf debugoff or /reload.
local _, ns = ...

local Debug = {}

local enabled = false

Debug.BATTLE_TAG = "DebugFriend#0000"
Debug.GUID = "Player-0-DEBUG001"
Debug.ALT_GUID = "Player-0-DEBUG002"
-- Fake dungeon quest, shared with your current character so the dungeon icon and badge show.
Debug.DUNGEON_QUEST_ID = 999999001
local SHARED_QUESTS = 6     -- main: more than Format.MAX_QUEST_LINES, so "+N more" shows
local ALT_SHARED_QUESTS = 2 -- alt: the same first quests, so two friend characters share them

function Debug.enabled() return enabled end
function Debug.set(on) enabled = on and true or false end

local function copy(quests)
  local result = {}
  for id, quest in pairs(quests or {}) do result[id] = quest end
  return result
end

-- The first `count` quests (by ID) of `quests`, plus the fake dungeon quest.
local function pick(quests, ids, count, dungeonQuest)
  local result = { [Debug.DUNGEON_QUEST_ID] = dungeonQuest }
  for i = 1, math.min(count, #ids) do result[ids[i]] = quests[ids[i]] end
  return result
end

-- Adds the fake friend (a main and an alt) to a Linker view model, in place.
-- selfGuid: the character you are on; its quests are copied so they are shared. now: server time.
function Debug.decorate(view, selfGuid, now)
  local dungeonQuest = { title = "Debug: Into the Deeps", area = "Blackfathom Deeps", dungeon = true }
  local own, ids = {}, {}

  for _, person in ipairs(view.people) do
    if person.isSelf then
      for _, row in ipairs(person.chars) do
        if row.guid == selfGuid then
          own = row.quests or {}
          for id in pairs(own) do ids[#ids + 1] = id end
          table.sort(ids)
          -- Copy of the stored quests: the DB table must not change.
          row.quests = copy(row.quests)
          row.quests[Debug.DUNGEON_QUEST_ID] = dungeonQuest
        end
      end
    end
  end

  local main = {
    guid = Debug.GUID, name = "Debug Character", classFile = "MAGE", classID = 8, level = 30,
    online = true, zone = "Debug Zone", ilvl = 25,
    professions = { [202] = { name = "Engineering", rank = 140, max = 150 },
                    [186] = { name = "Mining", rank = 150, max = 150 },
                    [185] = { name = "Cooking", rank = 80, max = 150 },
                    [129] = { name = "First Aid", rank = 225, max = 225 } },
    talents = { { name = "Arcane", points = 10 }, { name = "Fire", points = 0 }, { name = "Frost", points = 11 } },
    role = "dps",
    quests = pick(own, ids, SHARED_QUESTS, dungeonQuest),
  }
  local alt = {
    guid = Debug.ALT_GUID, name = "Debug Alt", classFile = "WARRIOR", classID = 1, level = 28,
    online = false, lastSeen = (now or 0) - 3600, lastZone = "Debug Zone", ilvl = 22,
    professions = { [171] = { name = "Alchemy", rank = 60, max = 150 } },
    talents = { { name = "Arms", points = 0 }, { name = "Fury", points = 2 }, { name = "Protection", points = 17 } },
    role = "tank", roleOverride = "tank",
    quests = pick(own, ids, ALT_SHARED_QUESTS, dungeonQuest),
  }
  -- CF-22: a sample activity feed (today: more parts than fit on a line and a second character).
  local today = ns.FeedTracker.today()
  local feed = {
    [today] = {
      [Debug.GUID] = { name = main.name, classFile = main.classFile, at = (now or 0) - 600, levelFrom = 27,
                       levelTo = 30, quests = { Ashenvale = 6, ["Stonetalon Mountains"] = 3, Barrens = 1 },
                       ranks = { Engineering = "Expert" }, learned = { Mining = true } },
      [Debug.ALT_GUID] = { name = alt.name, classFile = alt.classFile, at = (now or 0) - 5400,
                           quests = { Durotar = 2 },
                           -- CF-23: a raid and battlegrounds of their own, and a dungeon run with you
                           -- (your current character as companion), which shows as a shared line.
                           runs = { { name = "Molten Core", kind = "raid", bosses = 4, with = {} },
                                    { name = "Warsong Gulch", kind = "pvp", won = true, with = {} },
                                    { name = "Warsong Gulch", kind = "pvp", won = false, with = {} },
                                    { name = "Blackfathom Deeps", kind = "party", bosses = 3,
                                      with = { selfGuid } },
                                    { name = "Blackfathom Deeps", kind = "party", bosses = 2,
                                      with = { selfGuid } } } },
    },
    [today - 1] = {
      [Debug.ALT_GUID] = { name = alt.name, classFile = alt.classFile, at = (now or 0) - 86400, levelFrom = 19,
                           levelTo = 21, quests = { Barrens = 4 } },
    },
  }
  view.people[#view.people + 1] = { battleTag = Debug.BATTLE_TAG, displayName = "Debug Friend", isSelf = false,
                                    online = true, currentChar = main, chars = { main, alt }, feed = feed }
  return view
end

ns.Debug = Debug
return Debug
