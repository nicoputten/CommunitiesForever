-- Text: small text helpers shared by the core (CF-59). Pure Lua, no WoW globals.
local _, ns = ...

local Text = {}

-- 1234 -> "1,234".
function Text.thousands(n)
  local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (s:gsub("^,", ""))
end

ns.Text = Text
return Text
