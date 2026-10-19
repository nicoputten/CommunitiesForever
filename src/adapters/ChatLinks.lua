-- ChatLinks: clickable addon links in chat (CF-27). Thin wrapper. A link is
-- |Haddon:CommunitiesForever:<path>|h[text]|h; a click arrives as ChatLinks.CLICKED with the path.
-- How the click reaches addons on Forever is unverified (VERIFY.md V47): both the EventRegistry
-- "SetItemRef" callback and a SetItemRef hook are used, and a click reported by both counts once.
local ADDON_NAME, ns = ...

local ChatLinks = {}

ChatLinks.CLICKED = "CF_CHAT_LINK_CLICKED" -- (path)

local LINK_COLOR = "|cff71d5ff"
local PREFIX = "addon:" .. ADDON_NAME .. ":"

local addonRef
local lastLink, lastAt

-- "[text]" as a clickable link for path (letters, digits, ':', '#', '_' and '-').
function ChatLinks.link(path, text)
  return string.format("%s|H%s%s|h[%s]|h|r", LINK_COLOR, PREFIX, path, text)
end

-- Handles a clicked link (from either hook). Returns true when it was one of ours.
function ChatLinks.dispatch(link)
  if type(link) ~= "string" or link:sub(1, #PREFIX) ~= PREFIX then return false end
  local now = GetTime and GetTime() or 0
  if link == lastLink and lastAt and now - lastAt < 1 then return true end -- the other hook, same click
  lastLink, lastAt = link, now
  addonRef:SendMessage(ChatLinks.CLICKED, link:sub(#PREFIX + 1))
  return true
end

function ChatLinks.watch(addon)
  addonRef = addon
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) ChatLinks.dispatch(link) end, ChatLinks)
  end
  if SetItemRef and hooksecurefunc then
    hooksecurefunc("SetItemRef", function(link) ChatLinks.dispatch(link) end)
  end
end

ns.ChatLinks = ChatLinks
return ChatLinks
