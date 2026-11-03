-- Missions: quest details at turn-in and accept (CF-71).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Registers nothing yet: CF-71 builds it.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Quests = {}

ns.Missions = ns.Missions or {}
ns.Missions.Quests = Quests
return Quests
