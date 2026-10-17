-- Transport: Battle.net addon messages (BNSendGameData, BN_CHAT_MSG_ADDON) and combat state.
-- Thin wrapper: queueing, throttling and decoding live in core/Outbox, core/Protocol, services/Messenger.
local _, ns = ...

local Transport = {}

-- Internal messages.
Transport.RECEIVED = "CF_TRANSPORT_RECEIVED"     -- (text, senderGameAccountID) for our prefix only
Transport.COMBAT_ENDED = "CF_TRANSPORT_COMBAT_ENDED"

-- C_ChatInfo.RegisterAddonMessagePrefix is verified (API-FINDINGS.md).
function Transport.registerPrefix(prefix)
  return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
end

-- BNSendGameData(gameAccountID, prefix, text) is verified (API-FINDINGS.md).
function Transport.send(gameAccountID, prefix, text)
  BNSendGameData(gameAccountID, prefix, text)
end

-- InCombatLockdown is unverified on Forever (VERIFY.md V24); without it, assume no combat.
function Transport.inCombat()
  return InCombatLockdown and InCombatLockdown() or false
end

-- GetTime (seconds, sub-second precision) for the send rate. Unverified (VERIFY.md V24).
function Transport.now()
  return GetTime and GetTime() or GetServerTime()
end

function Transport.watch(addon, prefix)
  -- BN_CHAT_MSG_ADDON(prefix, text, channel, senderGameAccountID) is verified (API-FINDINGS.md).
  ns.Events.register(addon, "BN_CHAT_MSG_ADDON", function(_, messagePrefix, text, _, senderID)
    if messagePrefix == prefix then
      addon:SendMessage(Transport.RECEIVED, text, senderID)
    end
  end)
  ns.Events.register(addon, "PLAYER_REGEN_ENABLED", function() -- VERIFY.md V24
    addon:SendMessage(Transport.COMBAT_ENDED)
  end)
end

ns.Transport = Transport
return Transport
