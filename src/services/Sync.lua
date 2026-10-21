-- Sync: HELLO / REQ / RECORD flow between friends (ARCHITECTURE "Sync protocol"), over Battle.net and
-- (CF-28) over the community: community members running the addon who are not your Battle.net friends.
--   HELLO {bt, ver, known}  on login, when a friend starts Forever or a community member comes online,
--                           after an own record change or a newly accepted record (5 s debounce).
--                           known = { [key] = version } of the records we can relay (CF-20).
--   REQ   {bt, want}        for the sender's own record when its ver is newer, or for a relayed
--                           record (want = its key) when its known version is newer.
--   RECORD {...}            answer to REQ: own record (all own characters) or a stored one (relay).
--   BYE   {}                (CF-28, community) on logout, best effort: the sender is offline.
-- Over the community every person key is an "aid:<accountId>" key (core/Identity.lua): BattleTags only
-- travel over Battle.net.
local _, ns = ...

local Sync = {}

-- Internal message, sent after an accepted RECORD changed people[key].
Sync.PEOPLE_UPDATED = "CF_PEOPLE_UPDATED"

-- Internal message (CF-16): (key, { guid, name, level, updatedAt }) for each character of an
-- accepted record that has a higher level than before.
Sync.LEVEL_UP = "CF_LEVEL_UP"

-- Internal messages (CF-28): a community member running the addon came online (key, guid), or
-- someone's community online state changed (the window refreshes).
Sync.PEER_ONLINE = "CF_PEER_ONLINE"
Sync.PEERS_CHANGED = "CF_PEERS_CHANGED"

Sync.NEWER_VERSION_NOTICE = "A friend uses a newer CommunitiesForever version. Update to keep syncing with them."

local HELLO_DEBOUNCE = 5
local DEDUPE_SECONDS = 60
local IN_GAME = { [1] = true, [4] = true, [5] = true } -- community presence Online, Away, Busy

local addonRef, helloDebounced
local lastHello, lastReq, noticeShown
local peers = {}   -- CF-28: community peers met by HELLO: name -> { guid, key, at }
local offline = {} -- CF-28: guid -> true after a BYE or a failed whisper (until the next HELLO)

local function global()
  return addonRef.db.global
end

local function now()
  return GetServerTime()
end

local function own() return global().self end

-- Same message (same key) to the same target at most once per 60 s.
local function recentlySent(log, key, value)
  local last = log[key]
  return last and last.value == value and now() - last.at < DEDUPE_SECONDS
end

local function remember(log, key, value)
  log[key] = { value = value, at = now() }
end

local function isCommunity(target) return type(target) == "string" end

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

-- Our key as the target sees it: BattleTag over Battle.net, "aid:" key over the community.
local function ownWireKey(target)
  if isCommunity(target) then return own().accountId and ns.Identity.aidKey(own().accountId) end
  return own().battleTag
end

local function sendHello(target, force)
  local key = ownWireKey(target)
  if not key then return end -- nothing to identify us by yet
  local known = knownVersions()
  if isCommunity(target) then known = ns.Identity.knownForCommunity(global().people, own(), known) end
  local signature = helloSignature(own().version, known)
  if not force and recentlySent(lastHello, target, signature) then return end
  remember(lastHello, target, signature)
  ns.Messenger.send(target, { t = "HELLO", bt = key, ver = own().version, known = known })
end

-- CF-28: community members online now who are not reached over Battle.net: { [name] = guid }.
local function communityTargets()
  local targets, viaBattleNet = {}, {}
  for _, presence in pairs(ns.PresenceTracker.online()) do
    if presence.guid then viaBattleNet[presence.guid] = true end
  end
  local selfGuid = ns.SelfInfo.read().guid
  for guid, member in pairs(ns.MemberTracker.members()) do
    if guid ~= selfGuid and IN_GAME[member.presence] and not viaBattleNet[guid] and not offline[guid]
       and type(member.name) == "string" then
      targets[member.name] = guid
    end
  end
  return targets
end

local function broadcastHello(force)
  for gameAccountID in pairs(ns.PresenceTracker.gameAccounts()) do
    sendHello(gameAccountID, force)
  end
  for name in pairs(communityTargets()) do
    sendHello(name, force)
  end
end

-- Asks a peer for one record (want = key on its wire; nil = the peer's own record), once per version per 60 s.
local function request(target, want, version)
  local key = tostring(target) .. "|" .. tostring(want)
  if recentlySent(lastReq, key, version) then return end
  remember(lastReq, key, version)
  ns.Messenger.send(target, { t = "REQ", bt = ownWireKey(target), want = want })
end

local function storedVersion(key)
  local stored = global().people[key]
  return stored and stored.version or 0
end

local function fromWire(key)
  return ns.Identity.fromWire(global().people, own(), key)
end

-- CF-28: a community member running the addon said HELLO: online on that character.
local function peerSeen(name, guid, key)
  local wasOnline = peers[name] ~= nil
  peers[name] = { guid = guid, key = key, at = now() }
  local wasOffline = offline[guid]
  offline[guid] = nil
  if not wasOnline or wasOffline then
    addonRef:SendMessage(Sync.PEER_ONLINE, key, guid)
    addonRef:SendMessage(Sync.PEERS_CHANGED)
  end
end

local function peerGone(name)
  local peer = peers[name]
  peers[name] = nil
  local guid = peer and peer.guid
  if not guid then
    for g, member in pairs(ns.MemberTracker.members()) do
      if member.name == name then guid = g end
    end
  end
  if guid then
    offline[guid] = true
    addonRef:SendMessage(Sync.PEERS_CHANGED)
  end
end

local handlers = {}

function handlers.HELLO(message, senderKey, target, guid)
  if type(message.ver) ~= "number" or type(message.bt) ~= "string" then return end
  local key, isOwn = fromWire(message.bt)
  if isOwn then return end
  if guid then
    -- Community: an "aid:" key, and not a key of someone else than the sending character's owner.
    if not ns.Identity.isAidKey(message.bt) then return end
    if senderKey:sub(1, 7) ~= "member:" and senderKey ~= key then return end
    peerSeen(target, guid, key)
    sendHello(target, false) -- so they know us too (the dedupe stops ping-pong)
  elseif message.bt ~= senderKey then
    return
  end
  local person = global().people[key]
  -- The owner's record also replaces a relayed copy with a higher version.
  if message.ver > storedVersion(key) or (person and person.via) then
    request(target, nil, message.ver)
  end
  if type(message.known) ~= "table" then return end
  for wire, version in pairs(message.known) do
    if type(wire) == "string" and type(version) == "number" and wire ~= message.bt then
      local local_, ownKnown = fromWire(wire)
      if not ownKnown and version > storedVersion(local_) then
        request(target, wire, version)
      end
    end
  end
end

function handlers.REQ(message, _, target)
  local wireOwn = ownWireKey(target)
  if not wireOwn then return end
  if message.want == nil or message.want == wireOwn then
    -- All own characters are always shared (CF-17), so this works on any character.
    local record = ns.Merge.outgoingRecord(own(), ns.FeedTracker.shared())
    record.bt = wireOwn
    ns.Messenger.send(target, record)
  elseif type(message.want) == "string" then
    local key = fromWire(message.want)
    local record = ns.Merge.relayRecord(global().people, key)
    if not record then return end
    if isCommunity(target) then
      record.bt = ns.Identity.toCommunity(global().people, own(), key)
      if not record.bt then return end -- no account ID known: not shared over the community
    else
      record.bt = message.want
    end
    ns.Messenger.send(target, record)
  end
end

-- Relayed records that arrived before community member data had loaded (login), by key.
-- Checked again when the member list changes; kept in memory only.
local waitingForMembers = {}

--[[ senderKey: BattleTag (Battle.net) or the community sender key; guid: the sending character
(community only). Over the community a record counts as the owner's own (direct) only when it lists the
sending character and that character already belongs to this person (or the person is new), so nobody
can pose as someone else with a learned account ID; otherwise it is a relayed record. ]]
local function receiveRecord(message, senderKey, guid)
  if type(message.bt) ~= "string" then return end
  local key, isOwn = fromWire(message.bt)
  if isOwn then return end
  local people = global().people
  local accept = senderKey
  if guid then
    local stored = people[key]
    local listsSender = type(message.chars) == "table" and message.chars[guid] ~= nil
    local belongs = not stored or not next(stored.chars or {}) or (stored.chars and stored.chars[guid] ~= nil)
    accept = (listsSender and belongs) and key or ("member:" .. guid)
  end
  local record = {}
  for k, v in pairs(message) do record[k] = v end
  record.bt = key

  local members = ns.MemberTracker.members()
  local relay = { ownBattleTag = own().battleTag, now = now(), members = members }
  local ok, reason = ns.Merge.accept(people[key], record, accept, relay)
  if not ok then
    if reason == "community" and next(members) == nil then
      waitingForMembers[key] = { message = message, sender = senderKey, guid = guid }
    end
    return
  end
  waitingForMembers[key] = nil
  local previous = people[key]
  ns.Merge.store(people, record, now(), accept)
  if not ns.Identity.isAidKey(key) then ns.Merge.absorb(people, key, now()) end
  -- Level-ups from the merged characters (CF-28: an older copy inside the record is not a change).
  local levelUps = ns.Merge.levelUps(previous and previous.chars, people[key].chars)
  addonRef:SendMessage(Sync.PEOPLE_UPDATED, key)
  for _, up in ipairs(levelUps) do
    addonRef:SendMessage(Sync.LEVEL_UP, key, up)
  end
  helloDebounced() -- tell other friends we can relay something new
end

function handlers.RECORD(message, senderKey, _, guid)
  receiveRecord(message, senderKey, guid)
end

function handlers.BYE(_, _, target, guid)
  if guid then peerGone(target) end
end

local function retryWaiting()
  if next(ns.MemberTracker.members()) == nil then return end
  local waiting = waitingForMembers
  waitingForMembers = {}
  for _, entry in pairs(waiting) do
    receiveRecord(entry.message, entry.sender, entry.guid)
  end
end

-- CF-28: the account ID that keys you over the community, made once. Not a version bump: friends learn
-- it with your next record change (levels, quests and gear change often).
local function ensureAccountId()
  if ns.Identity.isAccountId(own().accountId) then return end
  own().accountId = ns.Identity.newAccountId(math.random)
end

function Sync.start(addon)
  addonRef = addon
  lastHello, lastReq, noticeShown, waitingForMembers, peers, offline = {}, {}, false, {}, {}, {}
  helloDebounced = ns.Timer.debounce(HELLO_DEBOUNCE, function() broadcastHello(false) end)
  ensureAccountId()

  -- Own AceEvent object: other modules listen to some of these messages on the addon object.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function() helloDebounced() end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function()
    retryWaiting()
    helloDebounced() -- CF-28: members who came online get a HELLO (the dedupe skips the others)
  end)
  events:RegisterMessage(ns.PresenceTracker.FRIEND_ONLINE, function(_, battleTag)
    for gameAccountID, bt in pairs(ns.PresenceTracker.gameAccounts()) do
      if bt == battleTag then sendHello(gameAccountID, true) end
    end
  end)
  events:RegisterMessage(ns.Messenger.RECEIVED, function(_, message, senderKey, target, guid)
    local handler = handlers[message.t]
    if handler then handler(message, senderKey, target, guid) end
  end)
  events:RegisterMessage(ns.Messenger.UNSUPPORTED, function()
    if not noticeShown then
      noticeShown = true
      addonRef:Print(Sync.NEWER_VERSION_NOTICE)
    end
  end)
  events:RegisterMessage(ns.Transport.WHISPER_FAILED, function(_, name) peerGone(name) end)
  -- Nothing is sent while passive (no community); joining one catches up at once.
  events:RegisterMessage(ns.CommunitySelection.PASSIVE_CHANGED, function(_, passive)
    if not passive then Sync.announce() end
  end)
  ns.Events.register(events, "PLAYER_LOGOUT", function()
    for name in pairs(peers) do ns.Messenger.send(name, { t = "BYE" }) end
  end)

  broadcastHello(false)
end

-- The own record changed outside SelfTracker (e.g. invite link, CF-21): HELLO after the debounce.
function Sync.ownRecordChanged()
  helloDebounced()
end

-- /cf sync: announce the own version to every friend and community member online now (no dedupe).
function Sync.announce()
  broadcastHello(true)
end

--[[ CF-28: people online now, Battle.net friends and community peers together:
{ [key] = { guid, name, className, level, gameAccountID | target } }. ]]
function Sync.online()
  local result = {}
  for bt, presence in pairs(ns.PresenceTracker.online()) do result[bt] = presence end
  local members = ns.MemberTracker.members()
  for name, peer in pairs(peers) do
    if not result[peer.key] and not offline[peer.guid] then
      local member = members[peer.guid] or {}
      result[peer.key] = { guid = peer.guid, name = name, level = member.level, classID = member.classID,
                           target = name }
    end
  end
  return result
end

-- CF-28: characters that said BYE (or could not be whispered) since their last HELLO: { [guid] = true }.
function Sync.offline()
  return offline
end

ns.Sync = Sync
return Sync
