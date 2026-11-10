-- FightEvents: the events of the fights missions (CF-80). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Fights.lua.
-- CF-118: the zone and town the own character is in (GetRealZoneText through SelfInfo.zone, GetSubZoneText, V115) on
-- entering a zone (Instance events: ZONE_CHANGED_NEW_AREA, the login) and a subzone (ZONE_CHANGED,
-- ZONE_CHANGED_INDOORS), with the character's faction: p.tourist (an enemy capital), p.raidParty (an enemy town).
-- Duels and kills reach the module through DoomsdayTracker (the feed's events). Every call is guarded.
local _, ns = ...

local FightEvents = {}

local ZONE_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_ENTERING_WORLD = true }
local addonRef, events

local function faction()
  local guid = ns.SelfInfo.guid()
  local char = guid and addonRef.db.global.self.chars and addonRef.db.global.self.chars[guid]
  return type(char) == "table" and char.faction or nil
end

local function sendPlace()
  local f = faction()
  if f ~= "Horde" and f ~= "Alliance" then return end
  local sub = ns.Safe.call(GetSubZoneText)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, "fightPlace", {
    faction = f, zone = ns.SelfInfo.zone(), subzone = type(sub) == "string" and sub ~= "" and sub or nil })
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function FightEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace other services' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  -- GetRealZoneText can be nil right after a loading screen (V35): read the zone a moment later.
  local later = ns.Timer.debounce(1, sendPlace)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if ZONE_EVENTS[event] then later() end
  end)
  ns.Events.register(events, "ZONE_CHANGED", later)
  ns.Events.register(events, "ZONE_CHANGED_INDOORS", later)
  later()
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Fights = FightEvents
return FightEvents
