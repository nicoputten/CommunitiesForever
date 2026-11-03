-- Missions: items, crafting, cooking, First Aid and care (CF-75).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Registers nothing yet: CF-75 builds it.
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Items = {}

ns.Missions = ns.Missions or {}
ns.Missions.Items = Items
return Items
