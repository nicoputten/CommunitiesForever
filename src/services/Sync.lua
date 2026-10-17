-- Sync: HELLO / REQ / RECORD flow between friends (ARCHITECTURE "Sync protocol").
--   HELLO {bt, ver}  on login, when a friend starts Forever, after an own record change (5 s debounce)
--   REQ   {bt}       when a friend advertises a newer version than we have
--   RECORD {...}     answer to REQ: own record with all own characters
local _, ns = ...

local Sync = {}

-- Internal message, sent after an accepted RECORD changed people[bt].
Sync.PEOPLE_UPDATED = "CF_PEOPLE_UPDATED"

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

-- Same message (kind + version) to the same game account at most once per 60 s.
local function recentlySent(log, gameAccountID, version)
  local last = log[gameAccountID]
  return last and last.version == version and now() - last.at < DEDUPE_SECONDS
end

local function sendHello(gameAccountID, force)
  local own = global().self
  if not own.battleTag then return end -- BNet not ready: nothing to identify us by
  if not force and recentlySent(lastHello, gameAccountID, own.version) then return end
  lastHello[gameAccountID] = { version = own.version, at = now() }
  ns.Messenger.send(gameAccountID, { t = "HELLO", bt = own.battleTag, ver = own.version })
end

local function broadcastHello(force)
  for gameAccountID in pairs(ns.PresenceTracker.gameAccounts()) do
    sendHello(gameAccountID, force)
  end
end

-- All own characters are always shared (CF-17), so the record does not depend on the
-- community member list and can be sent on any character.
local function sendRecord(gameAccountID)
  local own = global().self
  if not own.battleTag then return end
  ns.Messenger.send(gameAccountID, ns.Merge.outgoingRecord(own))
end

local handlers = {}

function handlers.HELLO(message, battleTag, gameAccountID)
  if type(message.ver) ~= "number" or message.bt ~= battleTag then return end
  local stored = global().people[battleTag]
  if stored and (stored.version or 0) >= message.ver then return end
  if recentlySent(lastReq, gameAccountID, message.ver) then return end
  lastReq[gameAccountID] = { version = message.ver, at = now() }
  ns.Messenger.send(gameAccountID, { t = "REQ", bt = global().self.battleTag })
end

function handlers.REQ(_, _, gameAccountID)
  sendRecord(gameAccountID)
end

function handlers.RECORD(message, battleTag)
  local people = global().people
  if not ns.Merge.accept(people[battleTag], message, battleTag) then return end
  ns.Merge.store(people, message, now())
  addonRef:SendMessage(Sync.PEOPLE_UPDATED, battleTag)
end

function Sync.start(addon)
  addonRef = addon
  lastHello, lastReq, noticeShown = {}, {}, false
  helloDebounced = ns.Timer.debounce(HELLO_DEBOUNCE, function() broadcastHello(false) end)

  -- Own AceEvent object: other modules listen to some of these messages on the addon object.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function() helloDebounced() end)
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

-- Settings changed what friends receive (share alts): bump the version and say HELLO.
function Sync.settingsChanged()
end

-- /cf sync: announce the own version to every friend in Forever now (no dedupe).
function Sync.announce()
  broadcastHello(true)
end

ns.Sync = Sync
return Sync
