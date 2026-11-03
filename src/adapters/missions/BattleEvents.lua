-- BattleEvents: the events of the battle missions (CF-81). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Battle.lua.
-- Watches nothing yet: CF-81 builds it. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local BattleEvents = {}

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function BattleEvents.watch(addon) -- luacheck: no unused args
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Battle = BattleEvents
return BattleEvents
