-- Messenger: sends and receives protocol messages over Battle.net.
-- Out: encode -> chunk -> Outbox (throttled, held during combat) -> BNSendGameData.
-- In: chunk -> reassemble -> decode -> resolve sender BattleTag via presence -> CF_MESSAGE_RECEIVED.
local _, ns = ...

local Messenger = {}

-- Internal messages.
Messenger.RECEIVED = "CF_MESSAGE_RECEIVED"           -- (message, senderBattleTag, senderGameAccountID)
Messenger.UNSUPPORTED = "CF_MESSAGE_UNSUPPORTED"     -- (pv, senderBattleTag): a friend runs a newer protocol

local addonRef, codec, outbox, reassembler, pumpTimer
local msgPrefix, msgCounter = "", 0
local stats = { sent = 0, received = 0, dropped = 0 }

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
  local chunks = ns.Protocol.chunk(codec:encode(message), nextMsgId())
  for _, chunk in ipairs(chunks) do
    outbox:push(gameAccountID, chunk)
  end
  schedulePump()
  return #chunks
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
  local encoded = reassembler:add(senderID, text, ns.Transport.now())
  if not encoded then return end

  local message, reason, pv = codec:decode(encoded)
  if not message then
    stats.dropped = stats.dropped + 1
    if reason == "unsupported" then
      addonRef:SendMessage(Messenger.UNSUPPORTED, pv, battleTag)
    end
    return
  end
  stats.received = stats.received + 1
  addonRef:SendMessage(Messenger.RECEIVED, message, battleTag, senderID)
end

-- Counters for /cf ping and debugging.
function Messenger.stats()
  return { sent = stats.sent, received = stats.received, dropped = stats.dropped, queued = outbox:size() }
end

function Messenger.start(addon)
  addonRef = addon
  codec = ns.Protocol.codec(LibStub("LibSerialize"), LibStub("LibDeflate"))
  outbox = ns.Outbox.new(addon.db.global.settings.sendInterval)
  reassembler = ns.Protocol.reassembler()
  pumpTimer = nil
  msgCounter = 0
  -- Per-session id prefix, so ids after a /reload do not collide with chunks still pending on the receiver.
  msgPrefix = string.format("%x", GetServerTime() % 1048576) .. "x"
  stats = { sent = 0, received = 0, dropped = 0 }

  ns.Transport.registerPrefix(ns.Protocol.PREFIX)
  ns.Transport.watch(addon, ns.Protocol.PREFIX)
  addon:RegisterMessage(ns.Transport.RECEIVED, function(_, text, senderID) receive(text, senderID) end)
  addon:RegisterMessage(ns.Transport.COMBAT_ENDED, function() schedulePump() end)
end

ns.Messenger = Messenger
return Messenger
