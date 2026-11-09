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
-- CF-112: how the "No player named" filter is set up and what it saw (/cf sync debug, VERIFY.md V53 and V129).
local filter = { via = nil, hidden = 0, shown = 0, secret = 0, lastShown = nil }
local lastLine, lastLineAt -- the line the filter last hid (it runs once per chat window for the same line)

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
  local now = Transport.now()
  ns.Reach.prune(whispered, now)
  whispered[name] = now
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

-- CF-112: { via, hidden, shown, secret, lastShown }: the filter function used ("ChatFrameUtil.AddMessageEventFilter",
-- "ChatFrame_AddMessageEventFilter" or nil when none exists), lines hidden, "No player named" lines not for a whisper
-- of ours (shown as usual; lastShown the last name in them) and unreadable (secret) system lines seen soon after a
-- whisper of ours (shown: they can't be compared).
function Transport.filterInfo()
  return { via = filter.via, hidden = filter.hidden, shown = filter.shown, secret = filter.secret,
           lastShown = filter.lastShown }
end

--[[ Whispering someone offline makes the game print "No player named '...' is currently playing." (CHAT_MSG_SYSTEM,
ERR_CHAT_PLAYER_NOT_FOUND_S): hide that line when it names a character we whispered in the last Reach.FAILED_WINDOW
seconds, and report it once as WHISPER_FAILED (with the name as we whispered it). The name in the line is compared
without case and "-Realm" (core/Reach), so "First Last-Realm" in the line matches our "First Last". A secret line
can't be read or compared: shown. Unverified on Forever (VERIFY.md V53, V129). ]]
local function onSystemLine(addon, message)
  if ns.Safe.secret(message) then
    if next(whispered) then filter.secret = filter.secret + 1 end
    return false
  end
  if type(message) ~= "string" then return false end
  local now = Transport.now()
  if message == lastLine and lastLineAt and now - lastLineAt < 1 then return true end -- the next chat window
  local format = ns.Safe.value(ERR_CHAT_PLAYER_NOT_FOUND_S)
  local reported = ns.Reach.notFoundName(type(format) == "string" and format or ns.Reach.NOT_FOUND_TEXT, message)
  if not reported then return false end
  local name = ns.Reach.matchFailure(whispered, reported, now)
  if not name then
    filter.shown, filter.lastShown = filter.shown + 1, reported
    return false
  end
  filter.hidden = filter.hidden + 1
  lastLine, lastLineAt = message, now
  addon:SendMessage(Transport.WHISPER_FAILED, name)
  return true
end

-- Registers the CHAT_MSG_SYSTEM filter once, with whichever filter function exists (both guarded, V53).
local function registerFilter(addon)
  if filter.via then return end
  local candidates = {
    { ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter, "ChatFrameUtil.AddMessageEventFilter" },
    { ChatFrame_AddMessageEventFilter, "ChatFrame_AddMessageEventFilter" },
  }
  for _, candidate in ipairs(candidates) do
    if type(candidate[1]) == "function" then
      local ok = pcall(candidate[1], "CHAT_MSG_SYSTEM", function(_, _, message) return onSystemLine(addon, message) end)
      if ok then
        filter.via = candidate[2]
        return
      end
    end
  end
end

function Transport.watch(addon, prefix)
  -- BN_CHAT_MSG_ADDON(prefix, text, channel, senderGameAccountID) is verified (API-FINDINGS.md).
  ns.Events.register(addon, "BN_CHAT_MSG_ADDON", function(_, ...)
    local messagePrefix, text, _, senderID = ns.Safe.values(...) -- CF-108: secret as nil
    if messagePrefix == prefix then
      addon:SendMessage(Transport.RECEIVED, text, senderID)
    end
  end)
  ns.Events.register(addon, "PLAYER_REGEN_ENABLED", function() -- VERIFY.md V24
    addon:SendMessage(Transport.COMBAT_ENDED)
  end)
  -- CF-28: community whispers. CHAT_MSG_ADDON(prefix, text, channel, sender) is verified (V50).
  local events = LibStub("AceEvent-3.0"):Embed({})
  ns.Events.register(events, "CHAT_MSG_ADDON", function(_, ...)
    local messagePrefix, text, channel, sender, target, _, localID, channelName = ns.Safe.values(...) -- CF-108
    if messagePrefix ~= prefix then return end
    if channel == "WHISPER" then
      addon:SendMessage(Transport.WHISPER_RECEIVED, text, Transport.shortName(sender))
    elseif channel == "CHANNEL" then
      addon:SendMessage(Transport.CHANNEL_RECEIVED, text, Transport.shortName(sender), target, localID, channelName)
    end
  end)
  registerFilter(addon)
  -- CF-112: ChatFrameUtil may not be there yet this early on some clients: try once more after the loading screen.
  if not filter.via then
    ns.Events.register(events, "PLAYER_ENTERING_WORLD", function() registerFilter(addon) end)
  end
end

ns.Transport = Transport
return Transport
