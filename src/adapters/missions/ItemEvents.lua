-- ItemEvents: the events of the items missions (CF-75). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Items.lua.
-- Watches nothing yet: CF-75 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local ItemEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function ItemEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Items = ItemEvents
return ItemEvents
