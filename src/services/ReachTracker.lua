-- ReachTracker (CF-112): feeds core/Reach with what tells whether a character is online, and answers whether an
-- addon whisper may go to it. Sources: Battle.net (PresenceTracker: a friend on this character, or on another one),
-- the community presence (MemberTracker), messages heard from the character (whispers, our channel, the guild's addon
-- channel) and failed whispers (Transport.WHISPER_FAILED, the game's "No player named" line).
-- Used by Messenger (sync whispers) and GuildInvites (CF-84); both whisper through Transport.whisper.
local _, ns = ...

local ReachTracker = {}

local IN_GAME = { [1] = true, [4] = true, [5] = true } -- community presence Online, Away, Busy

local reach

local function now() return ns.Transport.now() end

-- True when a Battle.net friend is on this character now, false when the character's owner (a Battle.net friend)
-- is in Forever on another character, nil when Battle.net can't tell. Friends who appear offline are in
-- characters() too (they are online), so they never count as "on another character" by mistake.
local function battleNet(guid, addon)
  if type(guid) ~= "string" then return nil end
  local characters = ns.PresenceTracker.characters()
  if characters[guid] then return true end
  local people = addon and addon.db and addon.db.global and addon.db.global.people
  local key = people and ns.Identity.personOfGuid(people, guid)
  if not key then return nil end
  for _, owner in pairs(characters) do
    if owner == key then return false end
  end
  return nil
end

local addonRef

-- The GUID of a community member by name (exact, as the member list gives it), or nil.
local function memberGuid(name)
  for guid, member in pairs(ns.MemberTracker.members()) do
    if member.name == name then return guid end
  end
  return nil
end

local function refreshPresence()
  local t = now()
  for _, member in pairs(ns.MemberTracker.members()) do
    if type(member.name) == "string" then reach:presence(member.name, IN_GAME[member.presence] == true, t) end
  end
end

--[[ "online" | "offline" | "failed" | "unknown" for a whisper target. guid: the character's GUID when the caller
knows it (else looked up in the community member list by name). ]]
function ReachTracker.status(name, guid)
  if not reach then return "unknown" end
  return reach:status(name, battleNet(guid or memberGuid(name), addonRef), now())
end

-- Whether an addon whisper may go to name now. allowUnknown: also when no source knows (CF-84's alt, outside the
-- guild, sees no presence of the members it asks). Returns bool, status.
function ReachTracker.mayWhisper(name, guid, allowUnknown)
  local status = ReachTracker.status(name, guid)
  return status == "online" or (allowUnknown == true and status == "unknown"), status
end

-- Something arrived from name: online now.
function ReachTracker.heard(name)
  if reach and type(name) == "string" then reach:heard(name, now()) end
end

-- /cf sync debug: the names blocked after a failed whisper and how the chat filter is set up.
function ReachTracker.describe()
  local names = {}
  for key in pairs(reach and reach:blocked() or {}) do names[#names + 1] = key end
  table.sort(names)
  local filter = ns.Transport.filterInfo()
  return string.format("whisper filter: %s; hidden %d, not ours %d, unreadable %d%s; blocked until online: %s",
    filter.via or "not registered", filter.hidden, filter.shown, filter.secret,
    filter.lastShown and (" (last not ours: " .. filter.lastShown .. ")") or "",
    #names > 0 and table.concat(names, ", ") or "none")
end

function ReachTracker.start(addon)
  addonRef = addon
  reach = ns.Reach.new()
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.Transport.WHISPER_FAILED, function(_, name)
    if type(name) == "string" then reach:failed(name, now()) end
  end)
  events:RegisterMessage(ns.Transport.WHISPER_RECEIVED, function(_, _, name) ReachTracker.heard(name) end)
  events:RegisterMessage(ns.Transport.CHANNEL_RECEIVED, function(_, _, name) ReachTracker.heard(name) end)
  events:RegisterMessage(ns.Guild.WHISPER_RECEIVED, function(_, _, name) ReachTracker.heard(name) end)
  events:RegisterMessage(ns.Guild.GUILD_RECEIVED, function(_, _, name) ReachTracker.heard(name) end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, refreshPresence)
  refreshPresence()
end

ns.ReachTracker = ReachTracker
return ReachTracker
