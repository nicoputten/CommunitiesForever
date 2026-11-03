-- Missions: PvP extras: taunts, the flag, battleground scores, zones, the killer (CF-81).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Registers nothing yet: CF-81 builds it.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Battle = {}

ns.Missions = ns.Missions or {}
ns.Missions.Battle = Battle
return Battle
