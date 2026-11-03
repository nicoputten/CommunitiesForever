-- FightEvents: the events of the fights missions (CF-80). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Fights.lua.
-- Watches nothing yet: CF-80 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local FightEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function FightEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Fights = FightEvents
return FightEvents
