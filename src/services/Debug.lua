-- Debug: hidden /cf debugon and /cf debugoff. Adds a fake friend to the window's view model only,
-- so features like shared quests (CF-19) can be checked without a second client. Never stored in
-- the DB and never synced (sync reads db.global, not the view). Lasts until /cf debugoff or /reload.
local _, ns = ...

local Debug = {}

local enabled = false

Debug.BATTLE_TAG = "DebugFriend#0000"
Debug.GUID = "Player-0-DEBUG001"
-- Fake dungeon quest, shared with your current character so the dungeon icon and badge show.
Debug.DUNGEON_QUEST_ID = 999999001
local SHARED_QUESTS = 6 -- more than Format.MAX_QUEST_LINES, so "+N more" shows

function Debug.enabled() return enabled end
function Debug.set(on) enabled = on and true or false end

local function copy(quests)
  local result = {}
  for id, quest in pairs(quests or {}) do result[id] = quest end
  return result
end

-- Adds the fake friend to a Linker view model (in place). selfGuid: the character you are on.
function Debug.decorate(view, selfGuid)
  local dungeonQuest = { title = "Debug: Into the Deeps", area = "Blackfathom Deeps", dungeon = true }
  local friendQuests = { [Debug.DUNGEON_QUEST_ID] = dungeonQuest }

  for _, person in ipairs(view.people) do
    if person.isSelf then
      for _, row in ipairs(person.chars) do
        if row.guid == selfGuid then
          -- Copy of the stored quests: the DB table must not change.
          local ids = {}
          for id in pairs(row.quests or {}) do ids[#ids + 1] = id end
          table.sort(ids)
          for i = 1, math.min(SHARED_QUESTS, #ids) do friendQuests[ids[i]] = row.quests[ids[i]] end
          row.quests = copy(row.quests)
          row.quests[Debug.DUNGEON_QUEST_ID] = dungeonQuest
        end
      end
    end
  end

  local char = { guid = Debug.GUID, name = "Debug Character", classFile = "MAGE", classID = 8, level = 30,
                 online = true, zone = "Debug Zone", ilvl = 25, professions = {}, quests = friendQuests }
  view.people[#view.people + 1] = { battleTag = Debug.BATTLE_TAG, displayName = "Debug Friend", isSelf = false,
                                    online = true, currentChar = char, chars = { char } }
  return view
end

ns.Debug = Debug
return Debug
