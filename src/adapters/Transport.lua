-- Transport: Battle.net addon messages (BNSendGameData, BN_CHAT_MSG_ADDON), community whispers
-- (C_ChatInfo.SendAddonMessage WHISPER, CHAT_MSG_ADDON; CF-28) and combat state.
-- Thin wrapper: queueing, throttling and decoding live in core/Outbox, core/Protocol, services/Messenger.
local _, ns = ...

local Transport = {}

-- Internal messages.
Transport.RECEIVED = "CF_TRANSPORT_RECEIVED"     -- (text, senderGameAccountID) for our prefix only
Transport.COMBAT_ENDED = "CF_TRANSPORT_COMBAT_ENDED"
Transport.WHISPER_RECEIVED = "CF_TRANSPORT_WHISPER_RECEIVED" -- (text, senderName) for our prefix (CF-28)
Transport.WHISPER_FAILED = "CF_TRANSPORT_WHISPER_FAILED"     -- (name): "no player named ..." after a whisper
-- CF-31: (text, senderName, target, localID, channelName) for our prefix on a chat channel; which of the
-- last three name the channel is unverified (V59), so all are passed on.
Transport.CHANNEL_RECEIVED = "CF_TRANSPORT_CHANNEL_RECEIVED"

-- Bytes per addon whisper: longer text is cut silently (verified, V50).
Transport.WHISPER_MAX = 255

local whispered = {} -- name -> time of our last whisper (to recognize "player not found" for it)
local FAILED_WINDOW = 10

-- C_ChatInfo.RegisterAddonMessagePrefix is verified (API-FINDINGS.md).
function Transport.registerPrefix(prefix)
  return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
end

-- BNSendGameData(gameAccountID, prefix, text) is verified (API-FINDINGS.md).
function Transport.send(gameAccountID, prefix, text)
  BNSendGameData(gameAccountID, prefix, text)
end

-- An addon whisper to a character (verified, V50: arrives at once, also to yourself).
function Transport.whisper(name, prefix, text)
  whispered[name] = Transport.now()
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(prefix, text, "WHISPER", name)
  end
end

-- A sender name without "-Realm" (the community lists names without it).
function Transport.shortName(name)
  if type(name) ~= "string" then return nil end
  return name:match("^(.-)%-[^%-]+$") or name
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
  -- CF-28: community whispers. CHAT_MSG_ADDON(prefix, text, channel, sender) is verified (V50).
  local events = LibStub("AceEvent-3.0"):Embed({})
  ns.Events.register(events, "CHAT_MSG_ADDON", function(_, messagePrefix, text, channel, sender, target, _,
                                                       localID, channelName)
    if messagePrefix ~= prefix then return end
    if channel == "WHISPER" then
      addon:SendMessage(Transport.WHISPER_RECEIVED, text, Transport.shortName(sender))
    elseif channel == "CHANNEL" then
      addon:SendMessage(Transport.CHANNEL_RECEIVED, text, Transport.shortName(sender), target, localID, channelName)
    end
  end)
  -- Whispering someone who just went offline makes the game print "No player named ... is currently
  -- playing": hide that line for names we whispered seconds ago, and report it (unverified, VERIFY.md V53).
  local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  local pattern = ERR_CHAT_PLAYER_NOT_FOUND_S
  if addFilter and type(pattern) == "string" then
    addFilter("CHAT_MSG_SYSTEM", function(_, _, message)
      if type(message) ~= "string" then return false end
      for name, at in pairs(whispered) do
        if Transport.now() - at < FAILED_WINDOW and message == pattern:format(name) then
          addon:SendMessage(Transport.WHISPER_FAILED, name)
          return true
        end
      end
      return false
    end)
  end
end

ns.Transport = Transport
return Transport
