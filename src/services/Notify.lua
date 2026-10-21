-- Notify: chat lines for linked friends: coming online or switching character (CF-15), and their
-- characters levelling up (CF-16, from accepted records).
--   "Alice is online on Alice Example (Mage 11)"
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
  if ns.CommunitySelection.passive() then return end
  local now = GetServerTime()
  local last = lastNotified[battleTag]
  if last and now - last < REPEAT_SECONDS then return end

  local person = linkedPerson(battleTag)
  local online = ns.Sync.online()[battleTag] -- CF-28: also community peers
  if not person or not online then return end
  local className = online.className
  if not className and online.classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    local info = C_CreatureInfo.GetClassInfo(online.classID)
    className = info and info.className
  end

  lastNotified[battleTag] = now
  addonRef:Print(ns.Format.loginNotice(person.displayName,
    { name = online.name, className = className, level = online.level }))
end

-- Level-ups older than this are not announced: relayed records (CF-20) can arrive hours later.
local LEVEL_UP_MAX_AGE = 15 * 60

-- CF-16: "Alice's Alice Example reached level 12" for characters of linked people.
local function announceLevelUp(battleTag, up)
  if addonRef.db.global.settings.levelUps == false then return end
  if not up.updatedAt or GetServerTime() - up.updatedAt > LEVEL_UP_MAX_AGE then return end
  local person = linkedPerson(battleTag)
  if not person then return end
  for _, row in ipairs(person.chars) do
    if row.guid == up.guid then
      addonRef:Print(ns.Format.levelUpNotice(person.displayName, row.name or up.name, up.level))
      return
    end
  end
end

function Notify.start(addon)
  addonRef = addon
  lastNotified = {}
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.PresenceTracker.FRIEND_ONLINE, function(_, battleTag) notify(battleTag) end)
  events:RegisterMessage(ns.PresenceTracker.FRIEND_SWITCHED, function(_, battleTag) notify(battleTag) end)
  events:RegisterMessage(ns.Sync.LEVEL_UP, function(_, battleTag, up) announceLevelUp(battleTag, up) end)
  events:RegisterMessage(ns.Sync.PEER_ONLINE, function(_, key) notify(key) end) -- CF-28
end

ns.Notify = Notify
return Notify
