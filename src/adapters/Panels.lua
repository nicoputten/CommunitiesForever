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

-- CF-47: reloads the UI from a click, so the game saves now ("Reload now to post on Discord"). C_UI.Reload
-- and ReloadUI are unverified from an addon button on Forever (VERIFY.md V68). Returns false when neither
-- exists or the call failed (the caller asks the player to type /reload).
function Panels.reload()
  local reload = (C_UI and C_UI.Reload) or ReloadUI
  if not reload then return false end
  return (pcall(reload))
end

-- CF-47: UTC seconds of a local date and time ({ year, month, day, hour, min }), via the game's time()
-- (unverified on Forever, VERIFY.md V71). nil without it.
function Panels.localTime(parts)
  if not time then return nil end
  local ok, t = pcall(time, { year = parts.year, month = parts.month, day = parts.day, hour = parts.hour,
                              min = parts.min, sec = 0 })
  return ok and type(t) == "number" and t or nil
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
