-- ExtendedEvents: the events of the extended missions (CF-74). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Extended.lua.
-- Watches nothing yet: CF-74 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local ExtendedEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function ExtendedEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Extended = ExtendedEvents
return ExtendedEvents
