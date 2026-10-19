-- Sync: HELLO / REQ / RECORD flow between friends (ARCHITECTURE "Sync protocol").
--   HELLO {bt, ver, known}  on login, when a friend starts Forever, after an own record change or a
--                           newly accepted record (5 s debounce). known = { [battleTag] = version }
--                           of the records we can relay (CF-20).
--   REQ   {bt, want}        for the sender's own record when its ver is newer, or for a relayed
--                           record (want = BattleTag) when its known version is newer.
--   RECORD {...}            answer to REQ: own record (all own characters) or a stored one (relay).
local _, ns = ...

local Sync = {}

-- Internal message, sent after an accepted RECORD changed people[bt].
Sync.PEOPLE_UPDATED = "CF_PEOPLE_UPDATED"

-- Internal message (CF-16): (battleTag, { guid, name, level, updatedAt }) for each character of an
-- accepted record that has a higher level than before.
Sync.LEVEL_UP = "CF_LEVEL_UP"

Sync.NEWER_VERSION_NOTICE = "A friend uses a newer CommunitiesForever version. Update to keep syncing with them."

local HELLO_DEBOUNCE = 5
local DEDUPE_SECONDS = 60

local addonRef, helloDebounced
local lastHello, lastReq, noticeShown

local function global()
  return addonRef.db.global
end

local function now()
  return GetServerTime()
end

-- Same message (same key) to the same game account at most once per 60 s.
local function recentlySent(log, key, value)
  local last = log[key]
  return last and last.value == value and now() - last.at < DEDUPE_SECONDS
end

local function remember(log, key, value)
  log[key] = { value = value, at = now() }
end

local function knownVersions()
  return ns.Merge.knownVersions(global().people, ns.MemberTracker.members())
end

-- Stable text for "what this HELLO says", so a HELLO is repeated only when something changed.
local function helloSignature(version, known)
  local parts = {}
  for bt, v in pairs(known) do parts[#parts + 1] = bt .. "=" .. v end
  table.sort(parts)
  return tostring(version) .. ";" .. table.concat(parts, ",")
end

local function sendHello(gameAccountID, force)
  local own = global().self
  if not own.battleTag then return end -- BNet not ready: nothing to identify us by
  local known = knownVersions()
  local signature = helloSignature(own.version, known)
  if not force and recentlySent(lastHello, gameAccountID, signature) then return end
  remember(lastHello, gameAccountID, signature)
  ns.Messenger.send(gameAccountID, { t = "HELLO", bt = own.battleTag, ver = own.version, known = known })
end

local function broadcastHello(force)
  for gameAccountID in pairs(ns.PresenceTracker.gameAccounts()) do
    sendHello(gameAccountID, force)
  end
end

-- Asks a peer for one record (want = BattleTag; nil = the peer's own record), once per version per 60 s.
local function request(gameAccountID, want, version)
  local key = gameAccountID .. "|" .. tostring(want)
  if recentlySent(lastReq, key, version) then return end
  remember(lastReq, key, version)
  ns.Messenger.send(gameAccountID, { t = "REQ", bt = global().self.battleTag, want = want })
end

local function storedVersion(battleTag)
  local stored = global().people[battleTag]
  return stored and stored.version or 0
end

local handlers = {}

function handlers.HELLO(message, battleTag, gameAccountID)
  if type(message.ver) ~= "number" or message.bt ~= battleTag then return end
  local person = global().people[battleTag]
  -- The owner's record also replaces a relayed copy with a higher version.
  if message.ver > storedVersion(battleTag) or (person and person.via) then
    request(gameAccountID, nil, message.ver)
  end
  if type(message.known) ~= "table" then return end
  local own = global().self.battleTag
  for bt, version in pairs(message.known) do
    if type(bt) == "string" and type(version) == "number" and bt ~= own and bt ~= battleTag
        and version > storedVersion(bt) then
      request(gameAccountID, bt, version)
    end
  end
end

function handlers.REQ(message, _, gameAccountID)
  local own = global().self
  if not own.battleTag then return end
  if message.want == nil or message.want == own.battleTag then
    -- All own characters are always shared (CF-17), so this works on any character.
    ns.Messenger.send(gameAccountID, ns.Merge.outgoingRecord(own, ns.FeedTracker.shared()))
  elseif type(message.want) == "string" then
    local record = ns.Merge.relayRecord(global().people, message.want)
    if record then ns.Messenger.send(gameAccountID, record) end
  end
end

-- Relayed records that arrived before community member data had loaded (login), by BattleTag.
-- Checked again when the member list changes; kept in memory only.
local waitingForMembers = {}

local function receiveRecord(message, battleTag)
  local people = global().people
  local members = ns.MemberTracker.members()
  local relay = { ownBattleTag = global().self.battleTag, now = now(), members = members }
  local ok, reason = ns.Merge.accept(people[message.bt], message, battleTag, relay)
  if not ok then
    if reason == "community" and next(members) == nil then
      waitingForMembers[message.bt] = { message = message, sender = battleTag }
    end
    return
  end
  waitingForMembers[message.bt] = nil
  local previous = people[message.bt]
  ns.Merge.store(people, message, now(), battleTag)
  -- Level-ups from the merged characters (CF-28: an older copy inside the record is not a change).
  local levelUps = ns.Merge.levelUps(previous and previous.chars, people[message.bt].chars)
  addonRef:SendMessage(Sync.PEOPLE_UPDATED, message.bt)
  for _, up in ipairs(levelUps) do
    addonRef:SendMessage(Sync.LEVEL_UP, message.bt, up)
  end
  helloDebounced() -- tell other friends we can relay something new
end

function handlers.RECORD(message, battleTag)
  receiveRecord(message, battleTag)
end

local function retryWaiting()
  if next(ns.MemberTracker.members()) == nil then return end
  local waiting = waitingForMembers
  waitingForMembers = {}
  for _, entry in pairs(waiting) do
    receiveRecord(entry.message, entry.sender)
  end
end

function Sync.start(addon)
  addonRef = addon
  lastHello, lastReq, noticeShown, waitingForMembers = {}, {}, false, {}
  helloDebounced = ns.Timer.debounce(HELLO_DEBOUNCE, function() broadcastHello(false) end)

  -- Own AceEvent object: other modules listen to some of these messages on the addon object.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function() helloDebounced() end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function() retryWaiting() end)
  events:RegisterMessage(ns.PresenceTracker.FRIEND_ONLINE, function(_, battleTag)
    for gameAccountID, bt in pairs(ns.PresenceTracker.gameAccounts()) do
      if bt == battleTag then sendHello(gameAccountID, true) end
    end
  end)
  events:RegisterMessage(ns.Messenger.RECEIVED, function(_, message, battleTag, gameAccountID)
    local handler = handlers[message.t]
    if handler then handler(message, battleTag, gameAccountID) end
  end)
  events:RegisterMessage(ns.Messenger.UNSUPPORTED, function()
    if not noticeShown then
      noticeShown = true
      addonRef:Print(Sync.NEWER_VERSION_NOTICE)
    end
  end)

  broadcastHello(false)
end

-- The own record changed outside SelfTracker (e.g. invite link, CF-21): HELLO after the debounce.
function Sync.ownRecordChanged()
  helloDebounced()
end

-- /cf sync: announce the own version to every friend in Forever now (no dedupe).
function Sync.announce()
  broadcastHello(true)
end

ns.Sync = Sync
return Sync
