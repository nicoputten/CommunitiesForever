-- PlaceEvents: the events of the friends and places missions (CF-73). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Places.lua.
-- Zones entered (Instance events: ZONE_CHANGED_NEW_AREA, the login), friends in game and in the same zone
-- (MemberTracker), a lower friend in the group (GROUP_ROSTER_UPDATE, levels) and own community chat messages
-- (ChatFrames.MESSAGE; guild chat when the community is a guild, CF-83). Zone level ranges from Group Finder's
-- zone activities (C_LFGList, V46).
-- Local stored data: self.doomsday.zonesSeen (see Places).
local _, ns = ...

local PlaceEvents = {}

local ZONE_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_ENTERING_WORLD = true }
local addonRef, events
local lastContinent -- the continent of the last place outside instances this session
local ranges        -- zone level ranges, read once Group Finder has them

local function global() return addonRef.db.global end
local function own() return global().self end

local function doomsday()
  local s = own()
  s.doomsday = s.doomsday or {}
  return s.doomsday
end

local function send(kind, obs)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs)
end

local function members()
  local ok, list = pcall(ns.MemberTracker.members)
  return ok and type(list) == "table" and list or {}
end

local function owners()
  return ns.Missions.Places.owners(global().people, global().presence, own().battleTag)
end

local function level()
  local guid = ns.SelfInfo.guid()
  local char = guid and own().chars and own().chars[guid]
  return type(char) == "table" and char.level or nil
end

-- Group Finder's zone activities (V46: category 116 "Quests & Zones"; zones have difficultyID 0 and
-- maxNumPlayers 0). The zone names it gives are unverified against GetRealZoneText (VERIFY.md CF-73).
local function zoneActivities()
  local lfg = C_LFGList
  if not (lfg and lfg.GetAvailableCategories and lfg.GetAvailableActivities and lfg.GetActivityInfoTable) then
    return {}
  end
  local result = {}
  local ok = pcall(function()
    for _, categoryID in ipairs(lfg.GetAvailableCategories() or {}) do
      for _, activityID in ipairs(lfg.GetAvailableActivities(categoryID) or {}) do
        local info = lfg.GetActivityInfoTable(activityID)
        if type(info) == "table" and not info.isPvpActivity then
          result[#result + 1] = { name = info.fullName, shortName = info.shortName, min = info.minLevelSuggestion,
                                  max = info.maxLevelSuggestion, difficultyID = info.difficultyID,
                                  maxNumPlayers = info.maxNumPlayers }
        end
      end
    end
  end)
  return ok and result or {}
end

local function zoneRanges()
  if ranges == nil or next(ranges) == nil then ranges = ns.Missions.Places.zoneRanges(zoneActivities()) end
  return ranges
end

local function checkFriends()
  local zone = ns.SelfInfo.zone()
  local online, sameZone = ns.Missions.Places.friendsNow(members(), owners(), zone)
  if online > 0 then send("placeFriends", { online = online, sameZone = sameZone }) end
end

local function checkGroup()
  local carry = ns.Missions.Places.carry(ns.Instance.groupGuids(), members(), owners(), global().people, level())
  if carry then send("placeGroup", { carry = true, day = ns.DoomsdayTracker.today() }) end
end

local function onZone()
  local guid = ns.SelfInfo.guid()
  local info = ns.Instance.info()
  if not guid or not info then return end
  checkFriends()
  if info.type ~= "none" then return end
  local zone = ns.SelfInfo.zone()
  local continent = ns.Missions.Places.continent(info.type, info.instanceID)
  if zone then
    local d = doomsday()
    d.zonesSeen = d.zonesSeen or {}
    local range = zoneRanges()[zone] or {}
    send("placeZone", {
      guid = guid,
      zone = zone,
      new = ns.Missions.Places.markZone(d.zonesSeen, guid, zone),
      level = level(),
      min = range.min,
      max = range.max,
      continent = continent,
      previous = lastContinent,
    })
  end
  if continent then lastContinent = continent end
end

local function ownGuids()
  local guids = {}
  for guid in pairs(own().chars or {}) do guids[guid] = true end
  local current = ns.SelfInfo.guid()
  if current then guids[current] = true end
  return guids
end

-- The chat channel of the selected community: guild chat for a guild (CF-83), else the community's stream.
local function selectedChannel()
  local clubId = ns.CommunitySelection.active()
  if not clubId then return nil end
  if ns.CommunitySelection.isGuild() then return ns.ChatFrames.GUILD end
  return ns.ChatFrames.channel(clubId)
end

local function onChat(_, channel, senderGuid)
  local selected = selectedChannel()
  if ns.Missions.Places.ownMessage(channel, selected, senderGuid, ownGuids()) then
    send("placeChat", { day = ns.DoomsdayTracker.today() })
  end
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function PlaceEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace other services' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  -- GetRealZoneText can be nil right after a loading screen (V35): read the zone a moment later.
  local zoneLater = ns.Timer.debounce(1, onZone)
  -- GROUP_ROSTER_UPDATE fires often, also without a change (V35).
  local groupLater = ns.Timer.debounce(2, checkGroup)
  local friendsLater = ns.Timer.debounce(2, checkFriends)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if ZONE_EVENTS[event] then
      zoneLater()
    elseif event == "GROUP_ROSTER_UPDATE" then
      groupLater()
    end
  end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function()
    friendsLater()
    groupLater()
  end)
  events:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason)
    if reason == "level" then groupLater() end
  end)
  events:RegisterMessage(ns.ChatFrames.MESSAGE, onChat)
  -- The zones of the stored feed count as visited once, at the first start with CF-73.
  local d = doomsday()
  if d.zonesSeen == nil then d.zonesSeen = ns.Missions.Places.seedZones(own().feed) end
  zoneLater()
  groupLater()
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Places = PlaceEvents
return PlaceEvents
