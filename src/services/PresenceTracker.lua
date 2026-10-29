-- PresenceTracker: which Battle.net friends are in Forever, on which character.
-- Writes db.global.presence and announces friends coming online, switching and going offline.
local _, ns = ...

local PresenceTracker = {}

-- Internal messages.
PresenceTracker.UPDATED = "CF_PRESENCE_UPDATED"         -- (): snapshot changed in any way
PresenceTracker.FRIEND_ONLINE = "CF_FRIEND_ONLINE"      -- (battleTag, guid)
PresenceTracker.FRIEND_SWITCHED = "CF_FRIEND_SWITCHED"  -- (battleTag, guid, previousGuid)
PresenceTracker.FRIEND_OFFLINE = "CF_FRIEND_OFFLINE"    -- (battleTag, previousGuid)
PresenceTracker.HIDDEN_FOUND = "CF_HIDDEN_FOUND"        -- (battleTag, gameAccountID): an "Appear offline" friend
                                                         -- sent us data; for sync only, never shown as online

local REFRESH_DEBOUNCE = 1

local addonRef
local snapshot -- nil until the first refresh (the login baseline)
local hidden = {}     -- this session's "Appear offline" friends: { [gameAccountID] = { battleTag, guid } }
local triedAt = {}    -- unknown senders looked up: { [gameAccountID] = time } (at most every RESOLVE_WAIT seconds)
local RESOLVE_WAIT = 30
local LOGIN_REREADS = { 5, 30 } -- seconds after login: friends' game accounts may not be filled in at first

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
  for gameAccountID, h in pairs(hidden) do
    if next.friends[h.battleTag] then ns.Friends.addHidden(next, gameAccountID, h.battleTag, h.guid) end
  end
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
  hidden, triedAt = {}, {}
  refresh()
  -- Read again a little later: at login Battle.net may not have filled in friends' game accounts yet.
  if C_Timer and C_Timer.After then
    for _, seconds in ipairs(LOGIN_REREADS) do C_Timer.After(seconds, refresh) end
  end
end

--[[ A Battle.net message from a game account that isn't in the snapshot (Messenger): a friend who appears
offline, or one Battle.net hasn't reported yet. Reads the friends again, then asks the game who sent it
(Friends.resolveHidden). A friend found that way counts for sync and linking for this session, never as
online. Returns the BattleTag or nil. ]]
function PresenceTracker.resolveSender(gameAccountID)
  if type(gameAccountID) ~= "number" then return nil end
  local now = GetServerTime()
  if triedAt[gameAccountID] and now - triedAt[gameAccountID] < RESOLVE_WAIT then return nil end
  triedAt[gameAccountID] = now
  refresh()
  local known = snapshot and snapshot.gameAccounts[gameAccountID]
  if known then return known end
  local info = ns.Presence.gameAccountInfo(gameAccountID)
  local guid = info and type(info.playerGuid) == "string" and info.playerGuid or nil
  local bt = ns.Friends.resolveHidden(info, ns.Presence.battleTagForGuid(guid), snapshot and snapshot.friends,
    addonRef.db.global.presence, addonRef.db.global.people, ns.Presence.wowClient(), ns.Presence.projectID())
  if not bt then return nil end
  hidden[gameAccountID] = { battleTag = bt, guid = guid }
  refresh()
  addonRef:SendMessage(PresenceTracker.HIDDEN_FOUND, bt, gameAccountID)
  return bt
end

-- Whether this friend appears offline to us on Battle.net but sent us data this session: never shown as online.
function PresenceTracker.isHidden(battleTag)
  if not battleTag or (snapshot and snapshot.online[battleTag]) then return false end
  for _, h in pairs(hidden) do
    if h.battleTag == battleTag then return true end
  end
  return false
end

-- Session map gameAccountID -> battleTag for Forever game accounts online now (CF-10 sender lookup).
function PresenceTracker.battleTagFor(gameAccountID)
  return snapshot and snapshot.gameAccounts[gameAccountID]
end

-- All Forever game accounts online now: { [gameAccountID] = battleTag }. Do not modify.
function PresenceTracker.gameAccounts()
  return snapshot and snapshot.gameAccounts or {}
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
