-- MemberTracker: members of the selected community, keyed by GUID.
local _, ns = ...

local MemberTracker = {}

-- Internal message, sent when the member map changed (including on selection change).
MemberTracker.UPDATED = "CF_MEMBERS_UPDATED"

local REFRESH_DEBOUNCE = 1

local addonRef
local current = {}
local changedAt

local function refresh()
  local clubId = ns.CommunitySelection.selected()
  local members = clubId and ns.Members.build(ns.Community.members(clubId)) or {}
  if not ns.Members.equal(current, members) then
    current = members
    changedAt = GetServerTime()
    addonRef:SendMessage(MemberTracker.UPDATED)
  end
end

local function select(clubId)
  if clubId then
    ns.Community.focusMembers(clubId)
  end
  refresh()
end

function MemberTracker.start(addon)
  addonRef = addon
  current = {}
  changedAt = nil
  local refreshDebounced = ns.Timer.debounce(REFRESH_DEBOUNCE, refresh)

  addon:RegisterMessage(ns.CommunitySelection.CHANGED, function(_, clubId)
    select(clubId)
  end)
  addon:RegisterMessage(ns.Community.MEMBERS_CHANGED, function(_, _, clubId)
    -- Events carry the clubId; ignore other clubs. Refresh if the event has none.
    if clubId == nil or clubId == ns.CommunitySelection.selected() then
      refreshDebounced()
    end
  end)

  select(ns.CommunitySelection.selected())
end

-- Current members[guid] = { name, classID, level, zone, presence, raceID, faction }. Do not modify.
function MemberTracker.members()
  return current
end

-- Server time of the last real change of the member map, nil if none yet.
function MemberTracker.changedAt()
  return changedAt
end

ns.MemberTracker = MemberTracker
return MemberTracker
