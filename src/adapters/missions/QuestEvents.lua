-- QuestEvents: the events of the quests missions (CF-71). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Quests.lua.
-- QUEST_TURNED_IN and QUEST_ACCEPTED exist (V23); QUEST_ACCEPTED's arguments are unverified (VERIFY.md CF-71).
local _, ns = ...

local QuestEvents = {}

local call = ns.Safe.call

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function QuestEvents.watch(addon)
  local events = LibStub("AceEvent-3.0"):Embed({})
  local function send(obs)
    addon:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, obs.kind, obs)
  end
  -- Before SelfTracker's debounced refresh: the stored log still has the quest.
  ns.Events.register(events, "QUEST_TURNED_IN", function(_, questID)
    questID = ns.Safe.value(questID) -- CF-108: secret as nil
    local global = addon.db.global
    local guid = call(UnitGUID, "player")
    local char = guid and global.self.chars and global.self.chars[guid]
    if not char then return end
    local grouped = ns.Missions.Quests.friendInGroup(ns.Instance.groupGuids(), global.people, global.presence,
      global.self.battleTag)
    send(ns.Missions.Quests.turnIn(char, questID, GetServerTime(), grouped))
  end)
  -- Mainline passes questID; Classic passed (questLogIndex, questID): the last number is the quest ID.
  ns.Events.register(events, "QUEST_ACCEPTED", function(_, a, b)
    a, b = ns.Safe.value(a), ns.Safe.value(b) -- CF-108: secret as nil
    local questID = type(b) == "number" and b or a
    if type(questID) == "number" then send({ kind = "questAccepted", questID = questID }) end
  end)
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Quests = QuestEvents
return QuestEvents
