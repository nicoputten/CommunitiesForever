-- BattleEvents: the events of the battle missions (CF-81). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Battle.lua.
-- The zone's PvP type (C_PvP.GetZonePVPInfo, V123: "friendly" verified in the own capital cities) on entering a
-- zone (Instance events: ZONE_CHANGED_NEW_AREA, the login) and on each own PvP kill (DoomsdayTracker.KILL), so the
-- day's facts know the type of the zone a kill was in. Every unverified call is guarded (VERIFY.md).
local _, ns = ...

local BattleEvents = {}

local ZONE_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_ENTERING_WORLD = true }
local addonRef, events

-- The current zone's PvP type ("friendly", "hostile", "contested", "sanctuary", ...), nil when unknown or none.
local function pvpType()
  local get = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  if not get then return nil end
  local ok, value = pcall(get)
  if not ok or ns.Safe.secret(value) or type(value) ~= "string" or value == "" then return nil end
  return value
end

local function sendZone(zone)
  zone = zone or ns.SelfInfo.zone()
  local kind = pvpType()
  if zone and kind then
    addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, "battleZone", { zone = zone, pvpType = kind })
  end
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function BattleEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace other services' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  -- GetRealZoneText can be nil right after a loading screen (V35): read the zone a moment later.
  local zoneLater = ns.Timer.debounce(1, sendZone)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if ZONE_EVENTS[event] then zoneLater() end
  end)
  -- A kill: the type of the zone the kill entry names (it was read at the same moment).
  events:RegisterMessage(ns.DoomsdayTracker.KILL, function(_, scored)
    local kill = type(scored) == "table" and scored.kill
    sendZone(type(kill) == "table" and type(kill.zone) == "string" and kill.zone or nil)
  end)
  zoneLater()
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Battle = BattleEvents
return BattleEvents
