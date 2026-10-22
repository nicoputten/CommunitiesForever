-- Keys: Esc closes an addon window (CF-32). Thin wrapper around the frame keyboard API.
-- UISpecialFrames would need a named global frame (CLAUDE.md rule 5), so the frame handles Esc itself:
-- it takes keyboard input but passes every key on, except Esc while it is shown.
-- EnableKeyboard / SetPropagateKeyboardInput are unverified on Forever (VERIFY.md V54) and
-- SetPropagateKeyboardInput is not allowed in combat, so nothing changes during combat (Esc then falls
-- through to the game menu as before).
local _, ns = ...

local Keys = {}

local function inCombat()
  return InCombatLockdown and InCombatLockdown()
end

local function propagate(frame, on)
  if not inCombat() then frame:SetPropagateKeyboardInput(on) end
end

-- frame: a Blizzard frame (an AceGUI widget's .frame); close(): hides the window. Returns true when set
-- up; false when the API is missing or in combat (call again on the next show).
function Keys.closeOnEscape(frame, close)
  if not (frame and frame.EnableKeyboard and frame.SetPropagateKeyboardInput and frame.SetScript) then
    return false
  end
  if inCombat() then return false end
  frame:SetPropagateKeyboardInput(true)
  frame:EnableKeyboard(true)
  frame:SetScript("OnKeyDown", function(self, key)
    if inCombat() then return end
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput(false) -- this Esc closes the window, not the game menu too
      close()
      -- Pass keys on again from the next event on, so a window shown later never swallows input.
      C_Timer.NewTimer(0, function() propagate(self, true) end)
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
  return true
end

ns.Keys = Keys
return Keys
