-- CommunitySelection: owns settings.clubId. Validates it against the subscribed clubs.
local _, ns = ...

local CommunitySelection = {}

-- Internal message: (clubId or nil). Sent when the selected community changes or is cleared.
CommunitySelection.CHANGED = "CF_COMMUNITY_CHANGED"

CommunitySelection.GONE_NOTICE = "Your community is no longer available. Select one with /cf settings."

local addonRef
local initialClubsLoaded = false
local noticeShown = false

local function settings()
  return addonRef.db.global.settings
end

local function setClub(clubId)
  if settings().clubId == clubId then return end
  settings().clubId = clubId
  addonRef:SendMessage(CommunitySelection.CHANGED, clubId)
end

local function clearGone()
  setClub(nil)
  if not noticeShown then
    noticeShown = true
    addonRef:Print(CommunitySelection.GONE_NOTICE)
  end
end

local function validate()
  local status = ns.Clubs.status(settings().clubId, ns.Community.subscribedClubs(),
    ns.Community.characterType(), initialClubsLoaded)
  if status == "missing" then
    clearGone()
  end
end

function CommunitySelection.start(addon)
  addonRef = addon
  initialClubsLoaded = false
  noticeShown = false
  addon:RegisterMessage(ns.Community.CLUBS_CHANGED, function(_, event, clubId)
    if event == "INITIAL_CLUBS_LOADED" then
      initialClubsLoaded = true
    end
    -- The removed club may still be listed while CLUB_REMOVED fires, so clear directly.
    if event == "CLUB_REMOVED" and clubId ~= nil and clubId == settings().clubId then
      clearGone()
      return
    end
    validate()
  end)
  validate()
end

-- Selectable communities as a sorted list of { clubId, name }.
function CommunitySelection.list()
  return ns.Clubs.selectable(ns.Community.subscribedClubs(), ns.Community.characterType())
end

function CommunitySelection.selected()
  return settings().clubId
end

function CommunitySelection.select(clubId)
  noticeShown = false
  setClub(clubId)
end

ns.CommunitySelection = CommunitySelection
return CommunitySelection
