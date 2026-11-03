-- WorldEvents: the events of the world missions (CF-76). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/World.lua.
-- Watches nothing yet: CF-76 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local WorldEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function WorldEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.World = WorldEvents
return WorldEvents
