-- Missions: friends and places (CF-73).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Registers nothing yet: CF-73 builds it.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Places = {}

ns.Missions = ns.Missions or {}
ns.Missions.Places = Places
return Places
