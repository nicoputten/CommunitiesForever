-- PlaceEvents: the events of the places missions (CF-73). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Places.lua.
-- Watches nothing yet: CF-73 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local PlaceEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function PlaceEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Places = PlaceEvents
return PlaceEvents
