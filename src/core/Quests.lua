-- Quests: own quest log per character and quests shared with friends (CF-19). Pure Lua, no WoW globals.
local _, ns = ...

local Quests = {}

-- Quest tag IDs (Enum.QuestTag on Mainline): Dungeon 81, Raid 62.
local DUNGEON_TAGS = { [81] = true, [62] = true }

-- Vanilla dungeon and raid names as quest log headers (English), fallback when the tag is unknown.
Quests.DUNGEON_AREAS = {
  ["Ragefire Chasm"] = true, ["Wailing Caverns"] = true, ["The Deadmines"] = true, ["Deadmines"] = true,
  ["Shadowfang Keep"] = true, ["The Stockade"] = true, ["Blackfathom Deeps"] = true, ["Gnomeregan"] = true,
  ["Razorfen Kraul"] = true, ["Scarlet Monastery"] = true, ["Razorfen Downs"] = true, ["Uldaman"] = true,
  ["Zul'Farrak"] = true, ["Maraudon"] = true, ["Temple of Atal'Hakkar"] = true, ["Sunken Temple"] = true,
  ["Blackrock Depths"] = true, ["Lower Blackrock Spire"] = true, ["Upper Blackrock Spire"] = true,
  ["Blackrock Spire"] = true, ["Dire Maul"] = true, ["Scholomance"] = true, ["Stratholme"] = true,
  ["Molten Core"] = true, ["Onyxia's Lair"] = true, ["Blackwing Lair"] = true, ["Zul'Gurub"] = true,
  ["Ruins of Ahn'Qiraj"] = true, ["Temple of Ahn'Qiraj"] = true, ["Ahn'Qiraj"] = true, ["Naxxramas"] = true,
}

--[[ Quest log as stored in a Char: { [questID] = { title, area, dungeon } } from raw log entries:
  entries = { { questID, title, isHeader, isHidden, tagID } } in log order; headers name the area of the
  quests below them. Hidden entries and entries without a questID are skipped. Returns nil for nil input
  (quest log not readable), so a snapshot can keep its previous data.
]]
function Quests.fromLog(entries)
  if type(entries) ~= "table" then return nil end
  local quests, area = {}, nil
  for _, entry in ipairs(entries) do
    if entry.isHeader then
      area = entry.title
    elseif type(entry.questID) == "number" and entry.questID > 0 and not entry.isHidden then
      local dungeon = DUNGEON_TAGS[entry.tagID] == true or (area ~= nil and Quests.DUNGEON_AREAS[area] == true)
      quests[entry.questID] = { title = entry.title, area = area, dungeon = dungeon }
    end
  end
  return quests
end

--[[ Quests a friend's character shares with any of your characters, matched by quest ID:
  friendQuests = { [questID] = { title, area, dungeon } }
  ownChars = { { name, classFile, quests = { [questID] = ... } } }
Returns areas = { { area, dungeon, quests = { { questID, title, ownChars = { { name, classFile } } } } } },
dungeon areas first, then by area name; quests by title. Also returns the total number of shared quests.
]]
function Quests.shared(friendQuests, ownChars)
  local byArea, areas, total = {}, {}, 0
  for questID, quest in pairs(friendQuests or {}) do
    local mine = {}
    for _, own in ipairs(ownChars or {}) do
      if own.quests and own.quests[questID] then
        mine[#mine + 1] = { name = own.name, classFile = own.classFile }
      end
    end
    if #mine > 0 then
      table.sort(mine, function(a, b) return tostring(a.name) < tostring(b.name) end)
      local key = quest.area or "Other"
      local area = byArea[key]
      if not area then
        area = { area = key, dungeon = false, quests = {} }
        byArea[key] = area
        areas[#areas + 1] = area
      end
      area.dungeon = area.dungeon or quest.dungeon == true
      area.quests[#area.quests + 1] = { questID = questID, title = quest.title, ownChars = mine }
      total = total + 1
    end
  end
  for _, area in ipairs(areas) do
    table.sort(area.quests, function(a, b) return tostring(a.title) < tostring(b.title) end)
  end
  table.sort(areas, function(a, b)
    if a.dungeon ~= b.dungeon then return a.dungeon end
    return a.area < b.area
  end)
  return areas, total
end

-- True if the friend's character shares at least one dungeon quest with any of your characters.
function Quests.sharesDungeon(friendQuests, ownChars)
  for _, area in ipairs((Quests.shared(friendQuests, ownChars))) do
    if area.dungeon then return true end
  end
  return false
end

ns.Quests = Quests
return Quests
