-- Merge: record accept rules and version rules. Pure Lua, no WoW globals.
local _, ns = ...

local Merge = {}

-- Owner-side version rule (ARCHITECTURE core rule 5): strictly increasing,
-- and close to server time so a reinstall with an empty DB still wins.
function Merge.nextVersion(previous, now)
  return math.max((previous or 0) + 1, now)
end

ns.Merge = Merge
return Merge
