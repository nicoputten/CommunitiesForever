-- ChatFrames: thin wrappers around Blizzard's chat windows for the community chat (CF-25).
-- Verified on Forever (API-FINDINGS.md V37, V39) unless noted; every call is guarded.
local _, ns = ...

local ChatFrames = {}

-- Internal message: (channel, senderGuid) for each community chat message (text is hidden, V38).
ChatFrames.MESSAGE = "CF_COMMUNITY_CHAT_MESSAGE"

-- Channel name of a community's General stream ("Community:<clubId>:<streamId>"), or nil.
function ChatFrames.channel(clubId)
  if not (clubId and C_Club and C_Club.GetStreams and Chat_GetCommunitiesChannelName) then return nil end
  local streams = C_Club.GetStreams(clubId) or {}
  local stream = streams[1]
  for _, s in ipairs(streams) do
    if Enum and Enum.ClubStreamType and s.streamType == Enum.ClubStreamType.General then stream = s end
  end
  return stream and Chat_GetCommunitiesChannelName(clubId, stream.streamId) or nil
end

-- Channel index (0 or nil while the client has not joined it yet).
function ChatFrames.index(channel)
  if not (channel and GetChannelName) then return nil end
  local index = GetChannelName(channel)
  return type(index) == "number" and index > 0 and index or nil
end

function ChatFrames.setColor(index, color)
  if index and ChangeChatColor then ChangeChatColor("CHANNEL" .. index, color.r, color.g, color.b) end
end

local function frame(index) return _G["ChatFrame" .. index] end

-- A closed chat tab keeps its name (CF-26 feedback): GetChatWindowInfo returns name, fontSize, r, g, b,
-- alpha, shown, locked, docked (Mainline order, unverified on Forever: VERIFY.md V41). A window that is
-- neither shown nor docked is closed. With fewer returns every named window counts, as before.
local function closed(...)
  if select("#", ...) < 9 then return false end
  local shown, docked = select(7, ...), select(9, ...)
  return not shown and not docked
end

-- Chat windows in use: { { index, name, hasChannel } }. Closed windows are left out.
function ChatFrames.windows(channel)
  local windows = {}
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local name = GetChatWindowInfo and GetChatWindowInfo(i)
    if name and name ~= "" and not closed(GetChatWindowInfo(i)) then
      local has = false
      for _, c in ipairs({ GetChatWindowChannels and GetChatWindowChannels(i) }) do
        if c == channel then has = true end
      end
      windows[#windows + 1] = { index = i, name = name, hasChannel = has }
    end
  end
  return windows
end

-- Index of the chat window you are looking at. SELECTED_CHAT_FRAME is unverified (VERIFY.md V40).
function ChatFrames.selected()
  local f = SELECTED_CHAT_FRAME
  return f and f.GetID and f:GetID() or nil
end

function ChatFrames.flash(index)
  if FCF_StartAlertFlash and frame(index) then FCF_StartAlertFlash(frame(index)) end
end

function ChatFrames.playSound()
  if PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then PlaySound(SOUNDKIT.TELL_MESSAGE) end
end

-- Opens a new chat tab that shows only the channel. Returns its window index, or nil.
function ChatFrames.createTab(name, channel)
  if not (FCF_OpenNewWindow and channel) then return nil end
  local f = FCF_OpenNewWindow(name)
  if not f then return nil end
  if ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(f) end
  if f.AddChannel then f:AddChannel(channel) end
  return f.GetID and f:GetID() or nil
end

function ChatFrames.addChannel(index, channel)
  local f = frame(index)
  if f and f.AddChannel then f:AddChannel(channel) end
end

function ChatFrames.removeChannel(index, channel)
  local f = frame(index)
  if f and f.RemoveChannel then f:RemoveChannel(channel) end
end

function ChatFrames.watch(addon)
  ns.Events.register(addon, "CHAT_MSG_COMMUNITIES_CHANNEL", function(_, ...)
    -- arg 9: channel name, arg 12: sender GUID (V38)
    local channel, guid = select(9, ...), select(12, ...)
    addon:SendMessage(ChatFrames.MESSAGE, channel, guid)
  end)
end

ns.ChatFrames = ChatFrames
return ChatFrames
