-- CommunityChat: makes the selected community's chat stand out in Blizzard's chat (CF-25):
-- its own color (always), a flashing tab and optional sound on new messages, and a Community tab.
local _, ns = ...

local CommunityChat = {}

-- The channel joins a moment after login; retry coloring this often, this many times.
local RETRY_SECONDS, RETRIES = 3, 10

local addonRef
local colored = false -- the channel color was set since login

local function settings() return addonRef.db.global.settings end

local function say(text) addonRef:Print(text) end

-- Channel of the selected community, or nil (no selection, or not visible on this character).
function CommunityChat.channel()
  return ns.ChatFrames.channel(ns.CommunitySelection.active())
end

-- Colors the community channel. Returns "done", "waiting" (the client has not joined the channel yet)
-- or "none" (no community on this character).
function CommunityChat.applyColor()
  local channel = CommunityChat.channel()
  if not channel then return "none" end
  local index = ns.ChatFrames.index(channel)
  if not index then return "waiting" end
  ns.ChatFrames.setColor(index, ns.Chat.color(settings()))
  return "done"
end

local function applyColorWithRetry(tries)
  local result = CommunityChat.applyColor()
  colored = colored or result == "done"
  if result ~= "waiting" or tries <= 0 then return end
  C_Timer.NewTimer(RETRY_SECONDS, function() applyColorWithRetry(tries - 1) end)
end

local function ownGuids()
  local guids = {}
  for guid in pairs(addonRef.db.global.self.chars or {}) do guids[guid] = true end
  local current = ns.SelfInfo.read().guid
  if current then guids[current] = true end
  return guids
end

local function onMessage(_, channel, senderGuid)
  local state = { channel = CommunityChat.channel(), ownGuids = ownGuids(), enabled = settings().chatAlert ~= false }
  if not ns.Chat.shouldAlert({ channel = channel, senderGuid = senderGuid }, state) then return end
  for _, index in ipairs(ns.Chat.flashTargets(ns.ChatFrames.windows(state.channel), ns.ChatFrames.selected())) do
    ns.ChatFrames.flash(index)
  end
  if settings().chatSound then ns.ChatFrames.playSound() end
end

function CommunityChat.start(addon)
  addonRef = addon
  settings().chatTab = settings().chatTab or {}
  -- Own AceEvent object: the addon object already handles some of these messages.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.ChatFrames.MESSAGE, onMessage)
  events:RegisterMessage(ns.CommunitySelection.CHANGED, function() applyColorWithRetry(RETRIES) end)
  -- The selected community becomes active once the members of this character are known.
  events:RegisterMessage(ns.MemberTracker.UPDATED, function()
    if not colored then colored = CommunityChat.applyColor() == "done" end
  end)
  ns.ChatFrames.watch(addon)
  applyColorWithRetry(RETRIES)
end

-- Settings: the color ({ r, g, b }) or nil to go back to the default purple.
function CommunityChat.setColor(color)
  settings().chatColor = color and { r = color.r, g = color.g, b = color.b } or nil
  CommunityChat.applyColor()
end

function CommunityChat.tabName()
  return ns.Chat.tabName(ns.CommunitySelection.name())
end

-- Index of this character's Community tab, or nil.
function CommunityChat.tab()
  return ns.Chat.findTab(ns.ChatFrames.windows(CommunityChat.channel()), CommunityChat.tabName())
end

-- Creates the Community tab on this character (chat windows are saved per character).
function CommunityChat.createTab()
  local channel = CommunityChat.channel()
  if not channel then
    say("Select a community first (and log in on a character that is a member).")
    return false
  end
  if CommunityChat.tab() then
    say(string.format("This character already has a %s chat tab.", CommunityChat.tabName()))
    return false
  end
  local index = ns.ChatFrames.createTab(CommunityChat.tabName(), channel)
  if not index then
    say("Could not create the chat tab.")
    return false
  end
  local guid = ns.SelfInfo.read().guid
  if guid then settings().chatTab[guid] = true end
  if settings().chatKeepGeneral == false then CommunityChat.setKeepGeneral(false) end
  CommunityChat.applyColor()
  say(string.format("Created the %s chat tab: it shows only the community chat.", CommunityChat.tabName()))
  return true
end

-- "Keep community messages in General too": off removes the channel from the other chat windows
-- (only with a Community tab, so the chat never disappears); on adds it back to the first window.
function CommunityChat.setKeepGeneral(keep)
  settings().chatKeepGeneral = keep
  local channel, tab = CommunityChat.channel(), CommunityChat.tab()
  if not channel or not tab then return end
  for _, w in ipairs(ns.ChatFrames.windows(channel)) do
    if w.index ~= tab then
      if not keep and w.hasChannel then ns.ChatFrames.removeChannel(w.index, channel) end
      if keep and w.index == 1 and not w.hasChannel then ns.ChatFrames.addChannel(1, channel) end
    end
  end
end

ns.CommunityChat = CommunityChat
return CommunityChat
