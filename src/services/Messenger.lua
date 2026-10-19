-- Messenger: sends and receives protocol messages over Battle.net.
-- Out: encode -> chunk -> Outbox (throttled, held during combat) -> BNSendGameData.
-- In: chunk -> reassemble -> decode -> resolve sender BattleTag via presence -> CF_MESSAGE_RECEIVED.
-- CF-28 reliable delivery: sent parts are kept for a minute; a receiver missing parts of a message asks
-- for them (MISS) and gets only those again. /cf sync debug traces parts, misses and resends.
local _, ns = ...

local Messenger = {}

-- Internal messages.
Messenger.RECEIVED = "CF_MESSAGE_RECEIVED"           -- (message, senderBattleTag, senderGameAccountID)
Messenger.UNSUPPORTED = "CF_MESSAGE_UNSUPPORTED"     -- (pv, senderBattleTag): a friend runs a newer protocol

local addonRef, codec, outbox, reassembler, pumpTimer, sentStore, missTimer
local msgPrefix, msgCounter = "", 0
local stats = { sent = 0, received = 0, dropped = 0, resent = 0, missed = 0 }

-- /cf sync debug (settings.syncDebug): one chat line per part, miss, resend and complete message.
function Messenger.debugOn()
  return addonRef ~= nil and addonRef.db.global.settings.syncDebug == true
end

function Messenger.setDebug(on)
  addonRef.db.global.settings.syncDebug = on or nil
end

local function trace(text, ...)
  if Messenger.debugOn() then addonRef:Print("|cffa0a0a0[sync]|r " .. string.format(text, ...)) end
end

local function who(gameAccountID)
  return tostring(ns.PresenceTracker.battleTagFor(gameAccountID) or gameAccountID)
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
    ns.Transport.send(target, ns.Protocol.PREFIX, chunk)
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

-- Queues a message for one game account. Returns the number of chunks.
function Messenger.send(gameAccountID, message)
  local msgId = nextMsgId()
  local chunks = ns.Protocol.chunk(codec:encode(message), msgId)
  for _, chunk in ipairs(chunks) do
    outbox:push(gameAccountID, chunk)
  end
  sentStore:put(gameAccountID, msgId, chunks, ns.Transport.now())
  trace("to %s: %s %s in %d part(s)", who(gameAccountID), tostring(message.t), msgId, #chunks)
  schedulePump()
  return #chunks
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

local function receive(text, senderID)
  local battleTag = ns.PresenceTracker.battleTagFor(senderID)
  if not battleTag then
    stats.dropped = stats.dropped + 1 -- not a friend in Forever right now
    return
  end
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
  addonRef:SendMessage(Messenger.RECEIVED, message, battleTag, senderID)
end

-- Counters for /cf ping and debugging.
function Messenger.stats()
  return { sent = stats.sent, received = stats.received, dropped = stats.dropped, queued = outbox:size(),
           resent = stats.resent, missed = stats.missed }
end

function Messenger.start(addon)
  addonRef = addon
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
  addon:RegisterMessage(ns.Transport.RECEIVED, function(_, text, senderID) receive(text, senderID) end)
  addon:RegisterMessage(ns.Transport.COMBAT_ENDED, function() schedulePump() end)
end

ns.Messenger = Messenger
return Messenger
