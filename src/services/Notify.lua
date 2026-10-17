-- Notify: chat line when a linked friend comes online in Forever or switches character (CF-15).
--   "Sjaak is online on Garraka Doombringer (Mage 11)"
-- Only for people linked in the selected community, never for yourself, at most once per person
-- per 30 s, and only when settings.notifications is on (default). Friends already online at login
-- are the baseline and produce no message (CF-07).
local _, ns = ...

local Notify = {}

local REPEAT_SECONDS = 30

local addonRef, lastNotified

local function linkedPerson(battleTag)
  for _, person in ipairs(ns.ViewModel.build(addonRef).people) do
    if person.battleTag == battleTag and not person.isSelf then return person end
  end
end

local function notify(battleTag)
  if addonRef.db.global.settings.notifications == false then return end
  local now = GetServerTime()
  local last = lastNotified[battleTag]
  if last and now - last < REPEAT_SECONDS then return end

  local person = linkedPerson(battleTag)
  local online = ns.PresenceTracker.online()[battleTag]
  if not person or not online then return end

  lastNotified[battleTag] = now
  addonRef:Print(ns.Format.loginNotice(person.displayName,
    { name = online.name, className = online.className, level = online.level }))
end

function Notify.start(addon)
  addonRef = addon
  lastNotified = {}
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.PresenceTracker.FRIEND_ONLINE, function(_, battleTag) notify(battleTag) end)
  events:RegisterMessage(ns.PresenceTracker.FRIEND_SWITCHED, function(_, battleTag) notify(battleTag) end)
end

ns.Notify = Notify
return Notify
