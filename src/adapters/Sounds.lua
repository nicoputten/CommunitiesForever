-- Sounds: the game's own sounds for the celebration banners (CF-67), no sound files of our own. PlaySound and
-- SOUNDKIT.TELL_MESSAGE are verified (V37); the SOUNDKIT entries below are unverified on Forever (VERIFY.md V88):
-- each weight tries its list in order and plays the first one the game has, on the effects channel.
local _, ns = ...

local Sounds = {}

Sounds.CELEBRATION = {
  small = { "IG_QUEST_LIST_COMPLETE" },
  medium = { "UI_EPICLOOT_TOAST", "IG_QUEST_LIST_COMPLETE" },
  big = { "UI_LEGENDARY_LOOT_TOAST", "UI_EPICLOOT_TOAST", "IG_QUEST_LIST_COMPLETE" },
}

-- Plays the sound of a weight ("small", "medium", "big"). Returns the SOUNDKIT key played, or nil.
function Sounds.celebrate(weight)
  if not (PlaySound and SOUNDKIT) then return nil end
  for _, key in ipairs(Sounds.CELEBRATION[weight] or {}) do
    local id = SOUNDKIT[key]
    if id then
      local ok = pcall(PlaySound, id, "SFX")
      if ok then return key end
    end
  end
  return nil
end

ns.Sounds = Sounds
return Sounds
