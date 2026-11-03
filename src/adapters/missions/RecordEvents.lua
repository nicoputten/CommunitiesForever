-- RecordEvents: the events of the records missions (CF-72). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Records.lua.
-- Watches nothing yet: CF-72 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local RecordEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function RecordEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Records = RecordEvents
return RecordEvents
