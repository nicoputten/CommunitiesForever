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
  (quest log not readable), so a snapshot can keep its previous data. An empty log also returns nil
  (it may not be loaded yet, e.g. right after login) unless allowEmpty: the player just turned in or
  abandoned a quest, so an empty log is real.
]]
function Quests.fromLog(entries, allowEmpty)
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
  if next(quests) == nil and not allowEmpty then return nil end
  return quests
end

local function byName(a, b) return tostring(a.name) < tostring(b.name) end

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
        mine[#mine + 1] = { name = own.name, classFile = own.classFile, classID = own.classID }
      end
    end
    if #mine > 0 then
      table.sort(mine, byName)
      local key = quest.area or "Other"
      local area = byArea[key]
      if not area then
        area = { area = key, dungeon = false, quests = {} }
        byArea[key] = area
        areas[#areas + 1] = area
      end
      area.dungeon = area.dungeon or quest.dungeon == true
      area.quests[#area.quests + 1] = { questID = questID, title = quest.title, ownChars = mine,
                                        theirChars = quest.theirChars }
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

--[[ Quests any of a friend's characters shares with any of yours (CF-19, person card):
  friendChars = { { name, classFile, quests } }, ownChars as for shared.
Same result as shared; each quest also has theirChars = { { name, classFile } }, the friend's characters
with that quest (sorted by name).
]]
function Quests.sharedAcross(friendChars, ownChars)
  local merged = {}
  for _, char in ipairs(friendChars or {}) do
    for questID, quest in pairs(char.quests or {}) do
      local entry = merged[questID]
      if not entry then
        entry = { title = quest.title, area = quest.area, dungeon = quest.dungeon, theirChars = {} }
        merged[questID] = entry
      end
      entry.dungeon = entry.dungeon or quest.dungeon
      entry.theirChars[#entry.theirChars + 1] = { name = char.name, classFile = char.classFile, classID = char.classID }
    end
  end
  for _, entry in pairs(merged) do table.sort(entry.theirChars, byName) end
  return Quests.shared(merged, ownChars)
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
