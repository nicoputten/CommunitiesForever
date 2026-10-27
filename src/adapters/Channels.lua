-- Channels: the hidden chat channel the addon broadcasts on (CF-31). Thin, guarded wrappers.
-- Unverified on Forever (VERIFY.md V59): JoinTemporaryChannel / JoinChannelByName, LeaveChannelByName,
-- addon messages with SendAddonMessage(prefix, text, "CHANNEL", index) and which CHAT_MSG_ADDON arguments
-- name the channel. Verified: GetChannelName (V37), C_ChatInfo.SendAddonMessage (V50), chat windows'
-- RemoveChannel (V39). Whatever is missing leaves the channel unused: the addon keeps whispering.
local _, ns = ...

local Channels = {}

-- Joins the channel (a temporary one: not saved, joined again at every login). Returns true when a join
-- function existed and ran.
function Channels.join(name)
  if not name then return false end
  if JoinTemporaryChannel then return pcall(JoinTemporaryChannel, name) == true end
  if JoinChannelByName then return pcall(JoinChannelByName, name) == true end
  return false
end

function Channels.leave(name)
  if name and LeaveChannelByName then pcall(LeaveChannelByName, name) end
end

-- Index of the joined channel, or nil (not joined yet, or joining did not work).
function Channels.index(name)
  return ns.ChatFrames.index(name)
end

-- Takes the channel out of every chat window, so nothing of it shows in chat.
function Channels.hide(name)
  for _, w in ipairs(ns.ChatFrames.windows(name)) do
    if w.hasChannel then ns.ChatFrames.removeChannel(w.index, name) end
  end
end

-- One addon message on the channel. Returns the send result (0 = accepted) or nil.
function Channels.send(prefix, text, index)
  if not (index and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return nil end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, text, "CHANNEL", index)
  return ok and result or nil
end

-- Hides Blizzard's "Joined/Changed Channel: [n. name]" lines for this channel. getName() returns the
-- channel in use (it changes with the community). Guarded like the whisper filter (V53).
function Channels.hideNotices(getName)
  local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if not addFilter then return end
  addFilter("CHAT_MSG_CHANNEL_NOTICE", function(_, _, ...)
    local name = getName()
    if not name then return false end
    for i = 1, select("#", ...) do
      local arg = select(i, ...)
      if type(arg) == "string" and arg:lower():find(name, 1, true) then return true end
    end
    return false
  end)
end

ns.Channels = Channels
return Channels
