-- PresenceTracker: which Battle.net friends are in Forever, on which character.
-- Writes db.global.presence and announces friends coming online, switching and going offline.
local _, ns = ...

local PresenceTracker = {}

-- Internal messages.
PresenceTracker.UPDATED = "CF_PRESENCE_UPDATED"         -- (): snapshot changed in any way
PresenceTracker.FRIEND_ONLINE = "CF_FRIEND_ONLINE"      -- (battleTag, guid)
PresenceTracker.FRIEND_SWITCHED = "CF_FRIEND_SWITCHED"  -- (battleTag, guid, previousGuid)
PresenceTracker.FRIEND_OFFLINE = "CF_FRIEND_OFFLINE"    -- (battleTag, previousGuid)

local REFRESH_DEBOUNCE = 1

local addonRef
local snapshot -- nil until the first refresh (the login baseline)

-- Shallow-compares two maps whose values are scalars or flat tables.
local function sameMap(a, b)
  for k, va in pairs(a) do
    local vb = b[k]
    if type(va) == "table" and type(vb) == "table" then
      for field, value in pairs(va) do
        if vb[field] ~= value then return false end
      end
      for field in pairs(vb) do
        if va[field] == nil then return false end
      end
    elseif va ~= vb then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function refresh()
  local next = ns.Friends.snapshot(ns.Presence.friendAccounts(), ns.Presence.wowClient(), ns.Presence.projectID())
  local previous = snapshot
  snapshot = next

  ns.Friends.recordPresence(addonRef.db.global.presence, next, GetServerTime())

  for _, change in ipairs(ns.Friends.changes(previous, next)) do
    if change.kind == "online" then
      addonRef:SendMessage(PresenceTracker.FRIEND_ONLINE, change.battleTag, change.guid)
    elseif change.kind == "switched" then
      addonRef:SendMessage(PresenceTracker.FRIEND_SWITCHED, change.battleTag, change.guid, change.previousGuid)
    else
      addonRef:SendMessage(PresenceTracker.FRIEND_OFFLINE, change.battleTag, change.previousGuid)
    end
  end

  if not previous or not sameMap(previous.friends, next.friends) or not sameMap(previous.online, next.online) then
    addonRef:SendMessage(PresenceTracker.UPDATED)
  end
end

function PresenceTracker.start(addon)
  addonRef = addon
  snapshot = nil
  local refreshDebounced = ns.Timer.debounce(REFRESH_DEBOUNCE, refresh)
  addon:RegisterMessage(ns.Presence.CHANGED, refreshDebounced)
  refresh()
end

-- Session map gameAccountID -> battleTag for Forever game accounts online now (CF-10 sender lookup).
function PresenceTracker.battleTagFor(gameAccountID)
  return snapshot and snapshot.gameAccounts[gameAccountID]
end

-- Set of current Battle.net friends: { [battleTag] = true }. Do not modify.
function PresenceTracker.friends()
  return snapshot and snapshot.friends or {}
end

-- Friends online in Forever: { [battleTag] = { guid, name, className, level, gameAccountID } }. Do not modify.
function PresenceTracker.online()
  return snapshot and snapshot.online or {}
end

ns.PresenceTracker = PresenceTracker
return PresenceTracker
