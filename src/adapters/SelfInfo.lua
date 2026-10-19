-- SelfInfo: reads the logged-in character from the WoW API and reports changes.
-- Thin wrapper: returns raw values, building and comparing is core/Snapshot.lua.
local _, ns = ...

local SelfInfo = {}

-- Internal message: (reason, ...event args). Reasons: "world", "level", "skills", "equipment", "logout",
-- "talents", "quests", "questRemoved", "questTurnedIn".
SelfInfo.CHANGED = "CF_SELF_CHANGED"

local EVENT_REASONS = {
  PLAYER_ENTERING_WORLD = "world",
  PLAYER_LEVEL_UP = "level",                 -- arg 1 is the new level
  SKILL_LINES_CHANGED = "skills",
  PLAYER_EQUIPMENT_CHANGED = "equipment",
  PLAYER_LOGOUT = "logout",                  -- VERIFY.md V22: handlers run before SavedVariables are written
  CHARACTER_POINTS_CHANGED = "talents",      -- CF-18 (verified to exist, V20)
  PLAYER_TALENT_UPDATE = "talents",
  TRAIT_CONFIG_UPDATED = "talents",
  QUEST_ACCEPTED = "quests",                 -- CF-19 (verified to exist, V23)
  QUEST_REMOVED = "questRemoved",           -- abandoned or completed: an empty log is real then
  QUEST_TURNED_IN = "questTurnedIn",         -- arg 1 is the questID (CF-22 activity feed)
  QUEST_LOG_UPDATE = "quests",               -- also fires when the log first loads
}

-- prof1, prof2, archaeology, fishing, cooking, with nil holes (API-FINDINGS.md).
local PROFESSION_SLOTS = 5

local function readProfessions()
  local list = {}
  if not (GetProfessions and GetProfessionInfo) then
    return list
  end
  local slots = { GetProfessions() }
  for k = 1, PROFESSION_SLOTS do
    local index = slots[k]
    if index then
      local name, _, rank, max, _, _, skillLine = GetProfessionInfo(index)
      list[#list + 1] = { name = name, rank = rank, max = max, skillLine = skillLine }
    end
  end
  return list
end

-- Equipped average item level (2nd return), nil if the API is missing.
local function readItemLevel()
  if not GetAverageItemLevel then
    return nil
  end
  local _, equipped = GetAverageItemLevel()
  return equipped
end

-- All nodes of the active class talent tree as { posX, ranks } (CF-18, layout in V29).
-- nil when the talent API is missing or not ready yet.
local function readTalentNodes()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
      and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
    return nil
  end
  local configID = C_ClassTalents.GetActiveConfigID()
  local config = configID and C_Traits.GetConfigInfo(configID)
  if not (config and config.treeIDs and config.treeIDs[1]) then return nil end
  local nodes = {}
  for _, treeID in ipairs(config.treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local node = C_Traits.GetNodeInfo(configID, nodeID)
      if node and node.posX then
        nodes[#nodes + 1] = { posX = node.posX, ranks = node.ranksPurchased or 0 }
      end
    end
  end
  return #nodes > 0 and nodes or nil
end

-- Raw quest log entries in log order (CF-19, V23): { questID, title, isHeader, isHidden, tagID }.
-- tagID from C_QuestLog.GetQuestTagInfo (unverified, VERIFY.md V31). nil when the log is not readable.
local function readQuestLog()
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return nil end
  local count = C_QuestLog.GetNumQuestLogEntries()
  if not count then return nil end
  local entries = {}
  for i = 1, count do
    local info = C_QuestLog.GetInfo(i)
    if info then
      local tagID
      if not info.isHeader and info.questID and info.questID > 0 and C_QuestLog.GetQuestTagInfo then
        local tag = C_QuestLog.GetQuestTagInfo(info.questID)
        tagID = tag and tag.tagID
      end
      entries[#entries + 1] = { questID = info.questID, title = info.title, isHeader = info.isHeader,
                                isHidden = info.isHidden, tagID = tagID }
    end
  end
  return entries
end

-- Full "First Last" name. UnitName returns first and last name separately for some characters
-- (last name in the second return, V9); GetUnitName("player", true) returns the full "First Last" name.
local function fullName()
  if GetUnitName then
    local name = GetUnitName("player", true)
    if name and name ~= "" then return name end
  end
  return (UnitName("player"))
end

-- UnitRace and UnitLevel/UnitFactionGroup are unverified on Forever (VERIFY.md V11).
function SelfInfo.read()
  local raceID
  if UnitRace then
    raceID = select(3, UnitRace("player"))
  end

  return {
    guid = UnitGUID("player"),
    name = fullName(),
    classFile = UnitClassBase("player"),
    raceID = raceID,
    level = UnitLevel and UnitLevel("player") or nil,
    faction = UnitFactionGroup and (UnitFactionGroup("player")) or nil,
    realm = GetRealmName(),
    ilvl = readItemLevel(),
    professions = readProfessions(),
    battleTag = (select(2, BNGetInfo())),
    talentNodes = readTalentNodes(),
    questLog = readQuestLog(),
  }
end

-- Translates WoW events into SelfInfo.CHANGED messages on the addon object.
-- Today's realm date (CF-22: the activity feed groups by realm day): year, month, day.
-- C_DateAndTime.GetCurrentCalendarTime is unverified on Forever (VERIFY.md V36); falls back to the
-- local date of the server time.
function SelfInfo.today()
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    local t = C_DateAndTime.GetCurrentCalendarTime()
    if t and t.year and t.month and t.monthDay then return t.year, t.month, t.monthDay end
  end
  local t = date("*t", GetServerTime())
  return t.year, t.month, t.day
end

-- The zone the player is in (a dungeon's name inside one), or nil. GetRealZoneText is verified but can
-- be nil right after a loading screen (API-FINDINGS V35).
function SelfInfo.zone()
  if not GetRealZoneText then return nil end
  local zone = GetRealZoneText()
  if issecretvalue and issecretvalue(zone) then return nil end
  if type(zone) ~= "string" or zone == "" then return nil end
  return zone
end

function SelfInfo.watch(addon)
  for event, reason in pairs(EVENT_REASONS) do
    ns.Events.register(addon, event, function(_, ...)
      addon:SendMessage(SelfInfo.CHANGED, reason, ...)
    end)
  end
end

ns.SelfInfo = SelfInfo
return SelfInfo
