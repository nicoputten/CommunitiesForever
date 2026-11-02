-- Screen: the screen's width in pixels, for the celebration banner's size (CF-67). GetPhysicalScreenSize is
-- unverified on Forever (VERIFY.md V89): without it the width is unknown (nil) and the banner keeps its full size.
local _, ns = ...

local Screen = {}

function Screen.width()
  if not GetPhysicalScreenSize then return nil end
  local ok, width = pcall(GetPhysicalScreenSize)
  if ok and type(width) == "number" and width > 0 then return width end
  return nil
end

ns.Screen = Screen
return Screen
