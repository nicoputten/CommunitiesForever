-- QuestieData: dungeon quests from the QuestieDB addon when it is installed (CF-24). Read at runtime,
-- nothing of it ships with this addon. Public API (QuestieDB docs/api.md): the LibQuestieDB global with
-- RequireContract and Enum.factionRaceMasks (contract 3), and the QuestDB global with GetAllIds and Get.
-- Unverified on Forever (VERIFY.md V44); every call is guarded.
local _, ns = ...

local QuestieData = {}

local CONTRACT = 3 -- Enum.factionRaceMasks needs contract 3

local cache -- { [areaId] = { quest, ... } } for the areas asked for, built once per session

-- True when a compatible QuestieDB is loaded.
function QuestieData.available()
  if not (LibQuestieDB and LibQuestieDB.RequireContract and QuestDB and QuestDB.GetAllIds and QuestDB.Get) then
    return false
  end
  local ok, compatible = pcall(LibQuestieDB.RequireContract, CONTRACT)
  return ok and compatible == true
end

-- requiredRaces mask of a faction ("Horde" / "Alliance") in the active flavor, or nil.
function QuestieData.factionMask(faction)
  local masks = LibQuestieDB and LibQuestieDB.Enum and LibQuestieDB.Enum.factionRaceMasks
  return masks and masks[faction] or nil
end

--[[ Quests whose zoneOrSort is one of the area IDs, class quests left out:
  { [areaId] = { { id, name, level, requiredLevel, requiredRaces } } }, or nil without QuestieDB.
Built on the first call (one pass over every quest ID), then cached for the session. ]]
function QuestieData.dungeonQuests(areaIds)
  if not QuestieData.available() then return nil end
  if cache then return cache end
  local wanted, result = {}, {}
  for _, id in ipairs(areaIds) do wanted[id] = true end
  local ok = pcall(function()
    for _, id in ipairs(QuestDB.GetAllIds()) do
      local area = QuestDB.Get(id, "zoneOrSort")
      if wanted[area] and (QuestDB.Get(id, "requiredClasses") or 0) == 0 then
        result[area] = result[area] or {}
        table.insert(result[area], { id = id, name = QuestDB.Get(id, "name"), level = QuestDB.Get(id, "questLevel"),
          requiredLevel = QuestDB.Get(id, "requiredLevel"), requiredRaces = QuestDB.Get(id, "requiredRaces") })
      end
    end
  end)
  if not ok then return nil end
  cache = result
  return cache
end

-- Quests the current character has turned in, of the given IDs: { [id] = true }, or nil when the game
-- cannot tell (C_QuestLog.IsQuestFlaggedCompleted, unverified on Forever: VERIFY.md V45).
function QuestieData.completed(ids)
  if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return nil end
  local done = {}
  for _, id in ipairs(ids) do
    if C_QuestLog.IsQuestFlaggedCompleted(id) then done[id] = true end
  end
  return done
end

function QuestieData.reset() cache = nil end

ns.QuestieData = QuestieData
return QuestieData
