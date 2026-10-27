-- Panels: Blizzard's colour picker and the AddOns category in Options (CF-43). Thin, guarded wrappers; both
-- unverified on Forever (VERIFY.md V65, V66).
local _, ns = ...

local Panels = {}

-- Opens the colour picker at r, g, b. onChange(r, g, b) runs while picking and with the old colour on
-- Cancel. Returns true when the picker opened.
function Panels.pickColor(r, g, b, onChange)
  local picker = ColorPickerFrame
  if not (picker and picker.SetupColorPickerAndShow and picker.GetColorRGB) then return false end
  picker:SetupColorPickerAndShow({
    r = r, g = g, b = b, hasOpacity = false,
    swatchFunc = function() onChange(picker:GetColorRGB()) end,
    cancelFunc = function() onChange(r, g, b) end,
  })
  return true
end

-- Adds `frame` as the addon's page under Options › AddOns. Returns true when it was registered.
function Panels.registerOptions(frame, name)
  local settings = _G.Settings
  if not (settings and settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory) then
    return false
  end
  local ok, category = pcall(settings.RegisterCanvasLayoutCategory, frame, name)
  if not ok or not category then return false end
  return (pcall(settings.RegisterAddOnCategory, category))
end

ns.Panels = Panels
return Panels
