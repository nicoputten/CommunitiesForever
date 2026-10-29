-- Messenger: sends and receives protocol messages over Battle.net and (CF-28) community whispers.
-- A target is a Battle.net game account ID (number) or a community member's character name (string).
-- Out: encode -> chunk -> Outbox (throttled, held during combat) -> BNSendGameData.
-- In: chunk -> reassemble -> decode -> resolve sender BattleTag via presence -> CF_MESSAGE_RECEIVED.
-- CF-28 reliable delivery: sent parts are kept for a minute; a receiver missing parts of a message asks
-- for them (MISS) and gets only those again. /cf sync debug traces parts, misses and resends.
local _, ns = ...

local Messenger = {}

-- Internal messages.
-- (message, senderKey, replyTarget, senderGuid): senderKey is the BattleTag for Battle.net; for the
-- community (CF-28) the person key whose record lists the sending character, else "member:<guid>".
-- replyTarget is where to answer (game account ID or character name); senderGuid only for the community.
Messenger.RECEIVED = "CF_MESSAGE_RECEIVED"
Messenger.UNSUPPORTED = "CF_MESSAGE_UNSUPPORTED"     -- (pv, senderBattleTag): a friend runs a newer protocol

local addonRef, codec, outbox, reassembler, pumpTimer, sentStore, missTimer
local msgPrefix, msgCounter = "", 0
local stats = { sent = 0, received = 0, dropped = 0, resent = 0, missed = 0 }
local debugging = false -- CF-64: /cf sync debug, for this session only

-- /cf sync debug: one chat line per part, miss, resend and complete message. CF-64 (Nico): not saved, off at every
-- login and /reload (it was settings.syncDebug).
function Messenger.debugOn()
  return addonRef ~= nil and debugging
end

function Messenger.setDebug(on)
  debugging = on and true or false
end

local function trace(text, ...)
  if Messenger.debugOn() then addonRef:Print("|cffa0a0a0[sync]|r " .. string.format(text, ...)) end
end

-- CF-31: outbox target for the hidden community channel (a table, so it never equals a name or account).
local CHANNEL = {}

local function who(target)
  if target == CHANNEL then return "the community channel" end
  if type(target) == "string" then return target end
  return tostring(ns.PresenceTracker.battleTagFor(target) or target)
end

local function nextMsgId()
  msgCounter = msgCounter + 1
  return msgPrefix .. string.format("%x", msgCounter)
end

-- Sends queued chunks one per interval; stops while in combat until PLAYER_REGEN_ENABLED.
local function pump()
  pumpTimer = nil
  if ns.Transport.inCombat() then
    return -- resumed by COMBAT_ENDED
  end
  local target, chunk = outbox:pop(ns.Transport.now())
  if target then
    if target == CHANNEL then
      ns.Channels.send(ns.Protocol.PREFIX, chunk, ns.SyncChannel.index())
    elseif type(target) == "string" then
      ns.Transport.whisper(target, ns.Protocol.PREFIX, chunk) -- CF-28: a community member
    else
      ns.Transport.send(target, ns.Protocol.PREFIX, chunk)
    end
    stats.sent = stats.sent + 1
  end
  if outbox:size() > 0 then
    pumpTimer = C_Timer.NewTimer(math.max(outbox:wait(ns.Transport.now()), 0.01), pump)
  end
end

local function schedulePump()
  if not pumpTimer then
    pump()
  end
end

-- Queues a message for one game account (number) or community member (character name). Returns the
-- number of chunks; nothing is sent while the addon is passive (no community, see Clubs.passive).
function Messenger.send(gameAccountID, message)
  if ns.CommunitySelection.passive() then return 0 end
  local msgId = nextMsgId()
  local size = type(gameAccountID) == "string" and ns.Protocol.COMMUNITY_CHUNK or nil
  local chunks = ns.Protocol.chunk(codec:encode(message), msgId, size)
  for _, chunk in ipairs(chunks) do
    outbox:push(gameAccountID, chunk)
  end
  sentStore:put(gameAccountID, msgId, chunks, ns.Transport.now())
  trace("to %s: %s %s in %d part(s)", who(gameAccountID), tostring(message.t), msgId, #chunks)
  schedulePump()
  return #chunks
end

-- CF-31: one message on the hidden community channel, to every member running the addon at once. Only
-- single-part messages (HELLO, BYE): a lost part could not be asked again from a broadcast. Returns 1 when
-- queued, 0 when it cannot go there (no channel yet, passive, or too big): the caller whispers instead.
function Messenger.sendChannel(message)
  if ns.CommunitySelection.passive() or not ns.SyncChannel.index() then return 0 end
  local msgId = nextMsgId()
  local chunks = ns.Protocol.chunk(codec:encode(message), msgId, ns.Protocol.COMMUNITY_CHUNK)
  if #chunks ~= 1 then return 0 end
  outbox:push(CHANNEL, chunks[1])
  trace("to %s: %s %s", who(CHANNEL), tostring(message.t), msgId)
  schedulePump()
  return 1
end

-- Asks the senders of incomplete messages for their missing parts; runs while messages are incomplete.
local missCheck
local function scheduleMissCheck()
  if not missTimer and reassembler:pendingCount() > 0 then
    missTimer = C_Timer.NewTimer(ns.Protocol.MISS_QUIET_SECONDS, missCheck)
  end
end

function missCheck()
  missTimer = nil
  for _, m in ipairs(reassembler:missing(ns.Transport.now())) do
    stats.missed = stats.missed + 1
    trace("from %s: %s missing part(s) %s of %d, asking again", who(m.sender), m.msgId,
      table.concat(m.parts, ","), m.total)
    outbox:push(m.sender, ns.Protocol.missMessage(m.msgId, m.parts))
    schedulePump()
  end
  scheduleMissCheck()
end

-- A MISS from a receiver: send those parts again (at most MAX_RESENDS times per message).
local function onMiss(senderID, msgId, parts)
  local chunks = sentStore:resend(senderID, msgId, parts, ns.Transport.now())
  if #chunks == 0 then
    trace("to %s: cannot resend %s (expired, unknown or resent %d times already)", who(senderID), msgId,
      ns.Protocol.MAX_RESENDS)
    return
  end
  for _, chunk in ipairs(chunks) do outbox:push(senderID, chunk) end
  stats.resent = stats.resent + #chunks
  trace("to %s: resent %d part(s) of %s", who(senderID), #chunks, msgId)
  schedulePump()
end

-- Queues a message for every friend game account online in Forever. Returns the number of targets.
function Messenger.broadcast(message)
  local count = 0
  for gameAccountID in pairs(ns.PresenceTracker.gameAccounts()) do
    Messenger.send(gameAccountID, message)
    count = count + 1
  end
  return count
end

-- One part (or a MISS) from a sender: senderID is the game account ID or the character name, battleTag
-- the sender key (see RECEIVED), guid the sending character (community only).
local function receive(text, senderID, battleTag, guid)
  if ns.CommunitySelection.passive() then return end
  local missId, missParts = ns.Protocol.parseMiss(text)
  if missId then
    onMiss(senderID, missId, missParts)
    return
  end
  if Messenger.debugOn() then
    local msgId, seq, total = text:match("^(%w+):(%d+):(%d+):")
    if msgId then trace("from %s: %s part %s/%s", battleTag, msgId, seq, total) end
  end
  local encoded = reassembler:add(senderID, text, ns.Transport.now())
  if not encoded then
    scheduleMissCheck()
    return
  end

  local message, reason, pv = codec:decode(encoded)
  if not message then
    stats.dropped = stats.dropped + 1
    if reason == "unsupported" then
      addonRef:SendMessage(Messenger.UNSUPPORTED, pv, battleTag)
    end
    return
  end
  stats.received = stats.received + 1
  trace("from %s: %s complete", battleTag, tostring(message.t))
  addonRef:SendMessage(Messenger.RECEIVED, message, battleTag, senderID, guid)
end

local function receiveBattleNet(text, senderID)
  -- A sender not in the snapshot may appear offline or not be reported yet: look it up once before dropping.
  local battleTag = ns.PresenceTracker.battleTagFor(senderID) or ns.PresenceTracker.resolveSender(senderID)
  if not battleTag then
    stats.dropped = stats.dropped + 1 -- not a friend in Forever right now
    return
  end
  receive(text, senderID, battleTag)
end

-- CF-28: only from characters that are members of the selected community.
local function receiveWhisper(text, name)
  local guid
  for g, member in pairs(ns.MemberTracker.members()) do
    if member.name == name then guid = g end
  end
  if not guid then
    stats.dropped = stats.dropped + 1
    return
  end
  if guid == ns.SelfInfo.read().guid then return end -- CF-31: our own broadcast, back from the channel
  local key = ns.Identity.personOfGuid(addonRef.db.global.people, guid) or ("member:" .. guid)
  receive(text, name, key, guid)
end

-- Counters for /cf ping and debugging.
function Messenger.stats()
  return { sent = stats.sent, received = stats.received, dropped = stats.dropped, queued = outbox:size(),
           resent = stats.resent, missed = stats.missed }
end

function Messenger.start(addon)
  addonRef = addon
  -- CF-64: sync debug is off at each start; the flag earlier versions saved is dropped (rule 8: an older version
  -- only reads its own flag, and nothing else uses it).
  debugging = false
  addon.db.global.settings.syncDebug = nil
  codec = ns.Protocol.codec(LibStub("LibSerialize"), LibStub("LibDeflate"))
  outbox = ns.Outbox.new(addon.db.global.settings.sendInterval)
  reassembler = ns.Protocol.reassembler()
  sentStore = ns.Protocol.sentStore()
  pumpTimer, missTimer = nil, nil
  msgCounter = 0
  -- Per-session id prefix, so ids after a /reload do not collide with chunks still pending on the receiver.
  msgPrefix = string.format("%x", GetServerTime() % 1048576) .. "x"
  stats = { sent = 0, received = 0, dropped = 0, resent = 0, missed = 0 }

  ns.Transport.registerPrefix(ns.Protocol.PREFIX)
  ns.Transport.watch(addon, ns.Protocol.PREFIX)
  addon:RegisterMessage(ns.Transport.RECEIVED, function(_, text, senderID) receiveBattleNet(text, senderID) end)
  addon:RegisterMessage(ns.Transport.WHISPER_RECEIVED, function(_, text, name) receiveWhisper(text, name) end)
  -- CF-31: the hidden channel carries the same parts as whispers; only from members, as for whispers.
  addon:RegisterMessage(ns.Transport.CHANNEL_RECEIVED, function(_, text, name, target, localID, channelName)
    if ns.SyncChannel.isOurs(target, localID, channelName) then receiveWhisper(text, name) end
  end)
  addon:RegisterMessage(ns.Transport.COMBAT_ENDED, function() schedulePump() end)
end

ns.Messenger = Messenger
return Messenger
