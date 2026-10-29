-- DoomsdayAlerts: Doomsday's chat lines and the crown toast (CF-57; board DD07AddonToday, parts 4 and 5).
-- Chat lines (setting "Doomsday in chat", on by default): a daily, the Hunt, the Skirmish or a weekly done, a
-- kill worth bonus points, someone else took the crown, a goal swapped for you. The toast "First to finish
-- today!" when you take the crown (always). Each crown and swap line once per day; swaps are told when the day
-- turns while you play or with the first goal done that day, never at login (three lines at every login is noise).
local _, ns = ...

local DoomsdayAlerts = {}

local addonRef, events

local function settings() return addonRef.db.global.settings end

-- Lines only with the setting on and a community this character is in (passive: no lines at all).
function DoomsdayAlerts.chatOn()
  return addonRef ~= nil and settings().doomsdayChat ~= false and ns.CommunitySelection.active() ~= nil
end

local function say(text)
  if text and DoomsdayAlerts.chatOn() then addonRef:Print(text) end
end

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

local function arrow() return ns.Theme.bundledFonts() and "\226\134\146" or "to" end

-- Swaps of today not told yet.
local function swaps(state)
  for new, original in pairs(state.today.swapped or {}) do
    if once(state.day, "swap:" .. new) then
      say(ns.DoomsdayView.swapLine(ns.DoomsdayView.goalText(original), ns.DoomsdayView.goalText(new), arrow()))
    end
  end
end

-- The crown: the toast when it's yours, a chat line when someone else has it.
local function crown(state)
  local c = state.crown
  if not c or not once(state.day, "crown") then return end
  if c.mine then
    ns.CrownToast.show({
      title = "First to finish today!",
      line = "All three dailies done at " .. (date and c.at and date("%H:%M", c.at) or "?"),
      flavour = string.format("The crown is yours until %s. Others have been told, gently.",
        date and date("%H:%M", ns.Doomsday.dayStart(state.day + 1, ns.DoomsdayTracker.schedule().offset,
          state.reset)) or "the reset"),
    }, settings().ambientEffects ~= false)
  else
    local done, total = ns.DoomsdayView.doneCount(ns.DoomsdayView.rows(state.today, state.progress, state.hunts))
    say(ns.DoomsdayView.crownLine(c.name, done, total))
  end
end

local function currentCharName()
  local guid = ns.SelfInfo.guid()
  local c = guid and addonRef.db.global.self.chars[guid]
  return c and c.name or "you"
end

-- Goals just done (DoomsdayTracker.CHANGED).
local function goalsDone(newly, weekly)
  local state = ns.DoomsdayTracker.state()
  if not state then return end
  local dailies, doneDailies = 0, 0
  for _, id in ipairs(state.today.set) do
    local g = ns.Doomsday.goal(id)
    if g and g.slot == "daily" then
      dailies = dailies + 1
      if state.today.done[id] then doneDailies = doneDailies + 1 end
    end
  end
  for _, id in ipairs(newly or {}) do
    local g = ns.Doomsday.goal(id)
    if id == "hunt" then
      say(ns.DoomsdayView.huntDoneLine(state.hunts and state.hunts[1], currentCharName()))
    elseif g and g.slot == "daily" then
      say(ns.DoomsdayView.dailyDoneLine(g.text, doneDailies, dailies))
    elseif g and g.slot == "skirmish" then
      say(ns.DoomsdayView.skirmishDoneLine(g.text))
    end
  end
  for _, id in ipairs(weekly or {}) do
    local g = ns.Doomsday.goal(id)
    if g then say(ns.DoomsdayView.weeklyDoneLine(g.text, g.slot == "bounty" and "pvp" or "pve")) end
  end
  crown(state)
  swaps(state)
end

-- A friend's record arrived: they may have taken the crown.
local function peopleUpdated()
  local state = ns.DoomsdayTracker.state()
  if state then crown(state) end
end

function DoomsdayAlerts.start(addon)
  addonRef = addon
  events = events or LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.DoomsdayTracker.CHANGED, function(_, newly, weekly) goalsDone(newly, weekly) end)
  events:RegisterMessage(ns.DoomsdayTracker.KILL, function(_, scored) say(ns.DoomsdayView.killLine(scored)) end)
  events:RegisterMessage(ns.Sync.PEOPLE_UPDATED, peopleUpdated)
end

ns.DoomsdayAlerts = DoomsdayAlerts
return DoomsdayAlerts
