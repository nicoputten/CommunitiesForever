-- QuestEvents: the events of the quests missions (CF-71). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Quests.lua.
-- Watches nothing yet: CF-71 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local QuestEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function QuestEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Quests = QuestEvents
return QuestEvents
