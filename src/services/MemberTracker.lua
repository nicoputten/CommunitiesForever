-- MemberTracker: members of the selected community, keyed by GUID.
-- CF-89: also keeps db.global.members (the roster, as last seen by this client) and decides who belongs
-- (core/Belongs.lua): only people with a character on the roster sync with us and are stored.
local _, ns = ...

local MemberTracker = {}

-- Internal message, sent when the member map changed (including on selection change).
MemberTracker.UPDATED = "CF_MEMBERS_UPDATED"

local REFRESH_DEBOUNCE = 1

local addonRef
local current = {}
local changedAt
local rosterClub -- the selected club db.global.members was written for (assumed the current one at login)

local function global() return addonRef.db.global end

--[[ CF-89: the roster (db.global.members) is replaced as a whole from a member list read for the selected
community, but only from one that lists this character: at login the list loads late and can be empty or partial
until then. Without a selected community it is {}; with a selected community that this character cannot see (an
alt outside the guild) the last roster stays. Then records and presence links of people who do not belong are
removed (also the one-time cleanup of data stored before CF-89). ]]
local function updateRoster(clubId, members)
  local selected = ns.CommunitySelection.selected()
  if selected == nil then
    rosterClub = nil
    if global().members == nil or next(global().members) ~= nil then global().members = {} end
  else
    if selected ~= rosterClub then
      rosterClub = selected
      global().members = nil -- another community: not known until its member list has loaded
    end
    local selfGuid = ns.SelfInfo.guid()
    if clubId == nil or selfGuid == nil or members[selfGuid] == nil then return end
    global().members = ns.Belongs.roster(members, GetServerTime())
  end
  local keys = MemberTracker.belonging()
  ns.Belongs.prunePresence(global().presence, global().members, keys)
  ns.Belongs.prunePeople(global().people, keys)
end

local function refresh()
  local clubId = ns.CommunitySelection.active()
  local members = clubId and ns.Members.build(ns.Community.members(clubId)) or {}
  ns.Members.recordLocations(global().locations, members, GetServerTime())
  updateRoster(clubId, members)
  if not ns.Members.equal(current, members) then
    current = members
    changedAt = GetServerTime()
    addonRef:SendMessage(MemberTracker.UPDATED)
  end
end

-- CF-111: the own character's zone, read with the own API (the member list sends no event at a zone change or at
-- logout). SelfInfo.zone() is nil for a secret or not yet loaded zone; the GUID goes through Safe.value too.
local function recordOwn()
  ns.Members.recordOwn(global().locations, ns.Safe.value(ns.SelfInfo.guid()), ns.SelfInfo.zone(), GetServerTime())
end

-- CF-111: on the way out (logout, a loading screen): the friends' zones from the member list as it is now, then the
-- own zone, last, so it wins over a member list that hasn't caught up. Only the locations: no roster update and no
-- UPDATED message at logout. Guarded: an error here must not stop the logout handlers of other services.
local function recordOnLeave()
  ns.Safe.call(function()
    local clubId = ns.CommunitySelection.active()
    if clubId then
      ns.Members.recordLocations(global().locations, ns.Members.build(ns.Community.members(clubId)), GetServerTime())
    end
  end)
  ns.Safe.call(recordOwn)
end

local LEAVE_EVENTS = { PLAYER_LEAVING_WORLD = true, PLAYER_LOGOUT = true }
local ENTER_EVENTS = { PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true }

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
  rosterClub = ns.CommunitySelection.selected()
  local refreshDebounced = ns.Timer.debounce(REFRESH_DEBOUNCE, refresh)

  -- The message carries the selected club; only read members when this character can see it.
  addon:RegisterMessage(ns.CommunitySelection.CHANGED, function()
    select(ns.CommunitySelection.active())
  end)
  addon:RegisterMessage(ns.Community.MEMBERS_CHANGED, function(_, _, clubId)
    -- Events carry the clubId; ignore other clubs. Refresh if the event has none.
    if clubId == nil or clubId == ns.CommunitySelection.active() then
      refreshDebounced()
    end
  end)

  -- CF-111: the own location (Instance.EVENT, an own AceEvent object: addon:RegisterMessage would replace other
  -- handlers). GetRealZoneText can be nil right after a loading screen (V35): read it a moment later, and again at
  -- every zone change. On the way out right away: no timer runs after logout.
  local events = LibStub("AceEvent-3.0"):Embed({})
  local recordOwnLater = ns.Timer.debounce(REFRESH_DEBOUNCE, function() ns.Safe.call(recordOwn) end)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if ENTER_EVENTS[event] then
      recordOwnLater()
    elseif LEAVE_EVENTS[event] then
      recordOnLeave()
    end
  end)

  select(ns.CommunitySelection.active())
end

-- Current members[guid] = { name, classID, level, zone, presence, raceID, faction }. Do not modify.
function MemberTracker.members()
  return current
end

-- Server time of the last real change of the member map, nil if none yet.
function MemberTracker.changedAt()
  return changedAt
end

-- CF-89: the roster, db.global.members ({ [guid] = { name, seenAt } }): {} without a selected community, nil
-- while it is not known yet. Do not modify.
function MemberTracker.roster()
  if ns.CommunitySelection.selected() == nil then return {} end
  return global().members
end

-- CF-89: the keys (BattleTags, "aid:" keys) that belong, { [key] = true }; nil while the roster is not known.
function MemberTracker.belonging()
  local g = global()
  return ns.Belongs.keys(MemberTracker.roster(), g.presence, g.people, ns.PresenceTracker.characters(),
    g.self and g.self.battleTag)
end

-- CF-89: whether this person (BattleTag or "aid:" key) belongs: true, false, or nil while the roster is not known.
function MemberTracker.belongs(key)
  local own = global().self
  if key ~= nil and own and key == own.battleTag then return true end
  return ns.Belongs.is(MemberTracker.belonging(), key)
end

ns.MemberTracker = MemberTracker
return MemberTracker
