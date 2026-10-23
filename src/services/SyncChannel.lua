-- SyncChannel: the hidden chat channel of the selected community (CF-31). Joins it while this character is
-- in the community (not while passive), leaves the old one when the community changes, keeps it out of the
-- chat windows. Sync broadcasts its HELLO and BYE here; everything else stays whispered.
local _, ns = ...

local SyncChannel = {}

local name -- the channel in use, or nil

-- Joins the channel for the current community, if it changed.
local function update()
  local wanted = not ns.CommunitySelection.passive() and ns.CommunitySelection.active()
    and ns.Chat.syncChannel(ns.CommunitySelection.name()) or nil
  if wanted == name then return end
  if name then ns.Channels.leave(name) end
  name = wanted
  if not name then return end
  ns.Channels.join(name)
  ns.Channels.hide(name)
  -- Joining finishes a moment later (and may add the channel to a chat window then): hide it again.
  local joined = name
  C_Timer.NewTimer(2, function()
    if name == joined then ns.Channels.hide(joined) end
  end)
end

function SyncChannel.start()
  name = nil
  ns.Channels.hideNotices(function() return name end)
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.CommunitySelection.CHANGED, update)
  events:RegisterMessage(ns.CommunitySelection.PASSIVE_CHANGED, update)
  -- The community's name may only be known once the club list loaded (first login): look again after
  -- CommunitySelection had its turn.
  events:RegisterMessage(ns.Community.CLUBS_CHANGED, function() C_Timer.NewTimer(0, update) end)
  ns.Events.register(events, "PLAYER_ENTERING_WORLD", update)
  update()
end

-- The channel's name while one is in use.
function SyncChannel.name()
  return name
end

-- Its index once joined, else nil (then everything is whispered).
function SyncChannel.index()
  return name and ns.Channels.index(name) or nil
end

-- True when an addon message on a chat channel came from ours (any argument may name it, V59).
function SyncChannel.isOurs(target, localID, channelName)
  if not name then return false end
  if type(target) == "string" and target:lower() == name then return true end
  if type(channelName) == "string" and channelName:lower():find(name, 1, true) then return true end
  local index = SyncChannel.index()
  return index ~= nil and localID == index
end

ns.SyncChannel = SyncChannel
return SyncChannel
