-- CommunitySelection: owns settings.clubId (account-wide) and whether this character can see it.
-- Community membership is per character, so the selection is never cleared automatically:
-- on a character that is not a member, the community is just not available (CF-17 feedback).
local _, ns = ...

local CommunitySelection = {}

-- Internal message: (clubId or nil). Sent when the selection or its availability changes.
CommunitySelection.CHANGED = "CF_COMMUNITY_CHANGED"

-- Internal message: (passive). Sent when the addon turns passive or active (see Clubs.passive).
CommunitySelection.PASSIVE_CHANGED = "CF_PASSIVE_CHANGED"

local addonRef
local initialClubsLoaded = false
local available = true
local removedClubId -- selected club removed for this character this session (may still be listed)
local passive = false

local function settings()
  return addonRef.db.global.settings
end

local function findClub(clubId)
  for _, club in ipairs(CommunitySelection.list()) do
    if club.clubId == clubId then return club end
  end
end

local function refreshPassive()
  local now = ns.Clubs.passive(settings().clubId, ns.Community.subscribedClubs(), ns.Community.selectableTypes())
  if now ~= passive then
    passive = now
    addonRef:SendMessage(CommunitySelection.PASSIVE_CHANGED, passive)
  end
end

-- Recomputes availability for this character and remembers the name while it is visible.
local function refreshAvailability()
  refreshPassive()
  local clubId = settings().clubId
  local status = ns.Clubs.status(clubId, ns.Community.subscribedClubs(), ns.Community.selectableTypes(),
    initialClubsLoaded)
  local club = clubId and findClub(clubId)
  if club and club.clubId ~= removedClubId then
    settings().clubName = club.name
    settings().clubType = club.clubType
  end
  -- "unknown" (club data not loaded yet) counts as available, so nothing flickers at login.
  local now = clubId ~= nil and status ~= "missing" and clubId ~= removedClubId
  if now ~= available then
    available = now
    addonRef:SendMessage(CommunitySelection.CHANGED, clubId)
  end
end

local function setClub(clubId)
  if settings().clubId == clubId then return end
  settings().clubId = clubId
  local club = clubId and findClub(clubId)
  settings().clubName = club and club.name or nil
  settings().clubType = club and club.clubType or nil
  removedClubId = nil
  available = clubId ~= nil
  addonRef:SendMessage(CommunitySelection.CHANGED, clubId)
  refreshAvailability()
end

-- CF-91: quietly (the window shows the community; the "Showing community ..." chat line is gone).
local function autoSelect(club)
  setClub(club.clubId)
end

-- With nothing selected: pick the one just joined, or the only community (a character community or the guild).
local function autoSelectIfNone(joinedClubId)
  if settings().clubId ~= nil then return end
  local list = CommunitySelection.list()
  for _, club in ipairs(list) do
    if joinedClubId ~= nil and club.clubId == joinedClubId then
      autoSelect(club)
      return
    end
  end
  if #list == 1 then
    autoSelect(list[1])
  end
end

function CommunitySelection.start(addon)
  addonRef = addon
  initialClubsLoaded = false
  removedClubId = nil
  available = settings().clubId ~= nil
  passive = ns.Clubs.passive(settings().clubId, ns.Community.subscribedClubs(), ns.Community.selectableTypes())
  addon:RegisterMessage(ns.Community.CLUBS_CHANGED, function(_, event, clubId)
    if event == "INITIAL_CLUBS_LOADED" then
      initialClubsLoaded = true
    end
    -- The removed club may still be listed while CLUB_REMOVED fires, so remember it.
    if event == "CLUB_REMOVED" and clubId ~= nil and clubId == settings().clubId then
      removedClubId = clubId
    elseif event == "CLUB_ADDED" and clubId == removedClubId then
      removedClubId = nil
    end
    if event == "CLUB_ADDED" then
      autoSelectIfNone(clubId)
    end
    refreshAvailability()
  end)
  autoSelectIfNone()
  refreshAvailability()
end

-- Selectable communities for this character as a sorted list of { clubId, name }.
function CommunitySelection.list()
  return ns.Clubs.selectable(ns.Community.subscribedClubs(), ns.Community.selectableTypes())
end

-- True while there is no community to work with (see Clubs.passive): no setup, sync, notices or minimap
-- button until this character joins one.
function CommunitySelection.passive()
  return passive
end

-- The selected community (account-wide), even when this character cannot see it.
function CommunitySelection.selected()
  return settings().clubId
end

-- The selected community if this character is a member of it, else nil.
function CommunitySelection.active()
  return available and settings().clubId or nil
end

-- Name of the selected community, remembered from a character that could see it.
function CommunitySelection.name()
  return settings().clubName
end

-- CF-83: true when the selected community is a guild (its type remembered from a character that could see it).
-- A guild has no invite links and its chat is guild chat, not a community stream.
function CommunitySelection.isGuild()
  local clubType = settings().clubType
  return settings().clubId ~= nil and clubType ~= nil and clubType == ns.Community.guildType()
end

function CommunitySelection.select(clubId)
  setClub(clubId)
end

ns.CommunitySelection = CommunitySelection
return CommunitySelection
