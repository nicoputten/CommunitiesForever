-- DoomsdayAlerts: Doomsday's crown toast (CF-57; board DD07AddonToday, part 5). The toast "First to finish today!"
-- when you take the crown (only with a community this character is in, CF-85), once per day.
-- CF-91: no chat lines any more (goals done, bonus kills, someone else's crown, swaps): the celebration banners
-- (CF-67) and the Doomsday tab show them.
local _, ns = ...

local DoomsdayAlerts = {}

local addonRef, events

local function settings() return addonRef.db.global.settings end

-- What was announced today: { day, keys = { [key] = true } } (local, reset when the day turns).
local function announced(day)
  local d = addonRef.db.global.self.doomsday
  if not d then return {} end
  if not d.announced or d.announced.day ~= day then d.announced = { day = day, keys = {} } end
  return d.announced.keys
end

local function once(day, key)
  local keys = announced(day)
  if keys[key] then return false end
  keys[key] = true
  return true
end

-- The crown: the toast when it's yours.
local function crown(state)
  local c = state.crown
  if not c or not once(state.day, "crown") then return end
  if not c.mine then return end
  -- CF-85: no toast without a community this character is in (tracked quietly; told once, so not later either).
  if ns.CommunitySelection.active() == nil then return end
  ns.CrownToast.show({
    title = "First to finish today!",
    line = "All three dailies done at " .. (date and c.at and ns.DoomsdayView.timeText(c.at, state.dayStart, date)
      or "?"),
    flavour = string.format("The crown is yours until %s. Others have been told, gently.",
      date and ns.DoomsdayView.timeText(ns.Doomsday.dayStart(state.day + 1, ns.DoomsdayTracker.schedule().offset,
        state.reset), state.dayStart, date) or "the reset"),
  }, settings().ambientEffects ~= false)
end

-- Goals done (DoomsdayTracker.CHANGED) or a friend's record arrived (they may have taken the crown).
local function check()
  local state = ns.DoomsdayTracker.state()
  if state then crown(state) end
end

function DoomsdayAlerts.start(addon)
  addonRef = addon
  events = events or LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.DoomsdayTracker.CHANGED, check)
  events:RegisterMessage(ns.Sync.PEOPLE_UPDATED, check)
end

ns.DoomsdayAlerts = DoomsdayAlerts
return DoomsdayAlerts
