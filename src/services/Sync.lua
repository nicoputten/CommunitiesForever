-- Sync: HELLO / REQ / RECORD flow between friends (ARCHITECTURE "Sync protocol"), over Battle.net and
-- (CF-28) over the community: community members running the addon who are not your Battle.net friends.
--   HELLO {bt, ver, known}  on login, when a friend starts Forever or a community member comes online,
--                           after an own record change or a newly accepted record (5 s debounce).
--                           known = { [key] = version } of the records we can relay (CF-20).
--   REQ   {bt, want}        for the sender's own record when its ver is newer, or for a relayed
--                           record (want = its key) when its known version is newer.
--   RECORD {...}            answer to REQ: own record (all own characters) or a stored one (relay).
--   BYE   {}                (CF-28, community) on logout, best effort: the sender is offline.
--   RUNS  {runs}            (CF-46) planned runs, to a peer whose HELLO showed an older ru (runs updatedAt).
--   RUNREQ {}               (CF-46) asks a peer whose HELLO showed a newer ru for its runs.
--   RUNANSWER {run, answer, guid, name, role}  (CF-47) your answer to a run, to its organiser when online.
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
-- CF-35: a newer release seen in a HELLO, once per session.
Sync.NEWER_RELEASE_NOTICE = "A newer version of CommunitiesForever is available (%s). Update with the CurseForge "
  .. "app or WowUp."

local HELLO_DEBOUNCE = 5
local RUNS_RETRY = 30 -- CF-46: seconds until runs held back by an encounter or PvP match are tried again
local DEDUPE_SECONDS = 60
local IN_GAME = { [1] = true, [4] = true, [5] = true } -- community presence Online, Away, Busy

local addonRef, helloDebounced
local lastHello, lastReq, lastRuns, noticeShown
local runsRetry = {} -- CF-46: target -> true while a retry timer is waiting
local releaseNoticeShown -- CF-35: once per session
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

-- The HELLO for a target. Over the community it says which hidden channel we listen on (ch, CF-31).
local function helloFor(community)
  local key = community and own().accountId and ns.Identity.aidKey(own().accountId) or (not community and
    own().battleTag) or nil
  if not key then return nil end -- nothing to identify us by yet
  local known = knownVersions()
  if community then known = ns.Identity.knownForCommunity(global().people, own(), known) end
  -- av (CF-35): our addon version; ch (CF-31): our channel. Older clients ignore both (rule 8). The channel
  -- is part of the signature: once it is ready, a new HELLO tells everyone (the 60 s dedupe would not).
  local ch = community and ns.SyncChannel.index() and ns.SyncChannel.name() or nil
  -- ru (CF-46): updatedAt of our planned runs (0: none); older clients ignore it.
  local ru = ns.Planner.updatedAt()
  -- dd (CF-56): the Doomsday reset setting we use, so friends without the uploader get it; older clients ignore it.
  local dd = ns.DoomsdayTracker.setting()
  return { t = "HELLO", bt = key, ver = own().version, known = known, av = addonRef.version, ch = ch, ru = ru,
           dd = dd },
         helloSignature(own().version, known) .. ";" .. tostring(ch) .. ";" .. tostring(ru) .. ";"
           .. tostring(dd and dd.changedAt) .. ";" .. tostring(dd and dd.offsetUntil)
end

local function sendHello(target, force)
  local message, signature = helloFor(isCommunity(target))
  if not message then return end
  if not force and recentlySent(lastHello, target, signature) then return end
  remember(lastHello, target, signature)
  ns.Messenger.send(target, message)
end

-- CF-31: the HELLO once on the hidden channel. Returns true when members on the channel have it (sent now,
-- or the same one less than 60 s ago); false when it cannot go there, so everyone is whispered.
local CHANNEL_KEY = "#channel"
local function channelHello(force)
  if not ns.SyncChannel.index() then return false end
  local message, signature = helloFor(true)
  if not message then return false end
  if not force and recentlySent(lastHello, CHANNEL_KEY, signature) then return true end
  if ns.Messenger.sendChannel(message) == 0 then return false end
  remember(lastHello, CHANNEL_KEY, signature)
  return true
end

-- A community member whose last HELLO said they listen on our channel.
local function onChannel(name)
  local peer = peers[name]
  return peer ~= nil and peer.channel == true
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
  -- CF-31: one HELLO on the hidden channel; a whisper only to members not known to listen there.
  local covered = channelHello(force)
  for name in pairs(communityTargets()) do
    if not (covered and onChannel(name)) then sendHello(name, force) end
  end
end

-- Asks a peer for one record (want = key on its wire; nil = the peer's own record), once per version per 60 s.
local function request(target, want, version)
  local key = tostring(target) .. "|" .. tostring(want)
  if recentlySent(lastReq, key, version) then return end
  remember(lastReq, key, version)
  ns.Messenger.send(target, { t = "REQ", bt = ownWireKey(target), want = want })
end

-- CF-46: our planned runs to a peer, at most once per updatedAt per 60 s. Never during an encounter or a PvP
-- match (Midnight's addon message restrictions): tried again RUNS_RETRY seconds later.
local function sendRuns(target)
  local runs = ns.Planner.outgoing(isCommunity(target))
  if not runs then return end
  if ns.Instance.messagingRestricted() then
    if not runsRetry[target] then
      runsRetry[target] = true
      C_Timer.NewTimer(RUNS_RETRY, function()
        runsRetry[target] = nil
        sendRuns(target)
      end)
    end
    return
  end
  if recentlySent(lastRuns, target, runs.updatedAt) then return end
  remember(lastRuns, target, runs.updatedAt)
  ns.Messenger.send(target, { t = "RUNS", runs = runs })
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
  -- Community: their character, but we know them without an account ID (e.g. from a relay): learn it now,
  -- and merge anything stored under that "aid:" key into them.
  if guid and ns.Identity.bindAccountId(global().people, senderKey, message.bt) then
    ns.Merge.absorb(global().people, senderKey, now())
  end
  local key, isOwn = fromWire(message.bt)
  if isOwn then return end
  if guid then
    -- Community: an "aid:" key, and not a key of someone else than the sending character's owner.
    if not ns.Identity.isAidKey(message.bt) then return end
    if senderKey:sub(1, 7) ~= "member:" and senderKey ~= key then return end
    local isNew = peers[target] == nil
    peerSeen(target, guid, key)
    -- CF-31: they listen on our channel (same name), so later HELLOs reach them there.
    peers[target].channel = message.ch ~= nil and message.ch == ns.SyncChannel.name()
    -- So they know us too (the dedupe stops ping-pong): always someone new to us (they may have joined
    -- after our last HELLO); later only members not on our channel, the others get our HELLOs there.
    if isNew or not (onChannel(target) and ns.SyncChannel.index()) then sendHello(target, false) end
  elseif message.bt ~= senderKey then
    return
  end
  -- CF-35: they run a newer release than we do (dev builds never count, Version.isNewer).
  if not releaseNoticeShown and ns.Version.isNewer(addonRef.version, message.av) then
    releaseNoticeShown = true
    addonRef:Print(string.format(Sync.NEWER_RELEASE_NOTICE, message.av))
  end
  -- CF-56: the Doomsday reset setting, the newer changedAt wins.
  if type(message.dd) == "table" then ns.DoomsdayTracker.receiveSetting(message.dd) end
  -- CF-46: planned runs, the newer updatedAt wins. A HELLO without ru is from a version without runs.
  if type(message.ru) == "number" then
    local ours = ns.Planner.updatedAt()
    if message.ru < ours then
      sendRuns(target)
    elseif message.ru > ours and not recentlySent(lastRuns, "req:" .. tostring(target), message.ru) then
      remember(lastRuns, "req:" .. tostring(target), message.ru)
      ns.Messenger.send(target, { t = "RUNREQ" })
    end
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
    local record = ns.Merge.outgoingRecord(own(), ns.DoomsdayTracker.outgoing())
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

-- CF-46: planned runs from a peer (checked like the runs file); newer ones replace ours and are announced.
function handlers.RUNS(message)
  if ns.Planner.receive(message.runs) then helloDebounced() end
end

function handlers.RUNREQ(_, _, target)
  sendRuns(target)
end

-- CF-47: a friend answered a run you organise, in game.
function handlers.RUNANSWER(message, senderKey)
  ns.Planner.answerReceived(message, senderKey)
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
  lastRuns, runsRetry = {}, {}
  releaseNoticeShown = false
  helloDebounced = ns.Timer.debounce(HELLO_DEBOUNCE, function() broadcastHello(false) end)
  ensureAccountId()

  -- Own AceEvent object: other modules listen to some of these messages on the addon object.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function() helloDebounced() end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function()
    retryWaiting()
    helloDebounced() -- CF-28: members who came online get a HELLO (the dedupe skips the others)
  end)
  -- A friend who appears offline sent us data: greet back so both sides sync (never a "came online" line).
  events:RegisterMessage(ns.PresenceTracker.HIDDEN_FOUND, function(_, _, gameAccountID)
    sendHello(gameAccountID, true)
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
    -- CF-31: one BYE on the channel; whispers to members not listening there.
    local covered = ns.Messenger.sendChannel({ t = "BYE" }) > 0
    for name in pairs(peers) do
      if not (covered and onChannel(name)) then ns.Messenger.send(name, { t = "BYE" }) end
    end
  end)

  broadcastHello(false)
end

-- CF-47: your answer (a Pending item) to the run's organiser, when they are online (Battle.net friend by
-- BattleTag, or a community peer on the organiser's character). Returns true when sent.
function Sync.sendRunAnswer(run, item)
  local organiser = run.organiser
  if not organiser or ns.Instance.messagingRestricted() then return false end
  for key, presence in pairs(Sync.online()) do
    local target = presence.gameAccountID or presence.target
    if target and ((organiser.battleTag and key == organiser.battleTag)
        or (organiser.guid and presence.guid == organiser.guid)) then
      ns.Messenger.send(target, { t = "RUNANSWER", run = run.id, answer = item.answer, guid = item.guid,
                                  name = item.name, role = item.role })
      return true
    end
  end
  return false
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
    -- A friend who appears offline on Battle.net stays offline here too (privacy), even when they greet us over
    -- the community: sync and linking only.
    if not result[peer.key] and not offline[peer.guid] and not ns.PresenceTracker.isHidden(peer.key) then
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
