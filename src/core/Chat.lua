-- Chat: rules for the community chat (CF-25): its color, which messages alert, which chat tabs flash.
-- Pure Lua, no WoW globals.
local _, ns = ...

local Chat = {}

-- Purple, readable on the dark chat background (#C080FF).
Chat.DEFAULT_COLOR = { r = 0.75, g = 0.5, b = 1 }

-- Chat tab names stay short (the tab is small).
Chat.MAX_TAB_NAME = 16

local function component(value)
  return type(value) == "number" and value >= 0 and value <= 1
end

-- The community chat color from settings.chatColor, or the default when unset or malformed.
function Chat.color(settings)
  local c = settings and settings.chatColor
  if type(c) == "table" and component(c.r) and component(c.g) and component(c.b) then
    return { r = c.r, g = c.g, b = c.b }
  end
  return { r = Chat.DEFAULT_COLOR.r, g = Chat.DEFAULT_COLOR.g, b = Chat.DEFAULT_COLOR.b }
end

--[[ True if a community chat message should alert:
  message = { channel, senderGuid }  -- from CHAT_MSG_COMMUNITIES_CHANNEL (text is hidden, V38)
  state = { channel, ownGuids = { [guid] = true }, enabled }
The message must be in the selected community's channel and not from one of your characters.
]]
function Chat.shouldAlert(message, state)
  if not state.enabled or not state.channel or message.channel ~= state.channel then return false end
  return not (message.senderGuid and state.ownGuids[message.senderGuid])
end

-- Chat windows to flash: those showing the channel, except the one you are looking at.
-- windows = { { index, hasChannel } }; selected = index of the selected window or nil.
function Chat.flashTargets(windows, selected)
  local targets = {}
  for _, w in ipairs(windows) do
    if w.hasChannel and w.index ~= selected then targets[#targets + 1] = w.index end
  end
  return targets
end

-- Tab name for the community chat: the community name (cut to MAX_TAB_NAME), or "Community".
function Chat.tabName(communityName)
  if type(communityName) ~= "string" or communityName == "" then return "Community" end
  local name = communityName:gsub("|", "")
  return name:sub(1, Chat.MAX_TAB_NAME)
end

-- The window index whose name is tabName, or nil. windows = { { index, name } }.
function Chat.findTab(windows, tabName)
  for _, w in ipairs(windows) do
    if w.name == tabName then return w.index end
  end
  return nil
end

ns.Chat = Chat
return Chat
