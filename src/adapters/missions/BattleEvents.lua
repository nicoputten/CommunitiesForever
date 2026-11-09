-- BattleEvents: the events of the battle missions (CF-81). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Battle.lua.
-- The zone's PvP type (C_PvP.GetZonePVPInfo, V123: "friendly" verified in the own capital cities) on entering a
-- zone (Instance events: ZONE_CHANGED_NEW_AREA, the login) and on each own PvP kill (DoomsdayTracker.KILL), so the
-- day's facts know the type of the zone a kill was in. Every unverified call is guarded (VERIFY.md).
-- CF-104: the PvP flag (UnitIsPVP("player") read on PLAYER_FLAGS_CHANGED, at login and each minute, V121), the
-- death recap's killer at a death (C_DeathRecap through PvpInfo.recapDamage, V120: a player killer is unverified) and
-- the victim CF-110 picks at a kill (PvpTracker.VICTIM), both by GUID.
local _, ns = ...

local BattleEvents = {}

local ZONE_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_ENTERING_WORLD = true }
local addonRef, events
local flaggedSince -- CF-104: server time the flag was last seen up (and not yet sent), nil when not flagged

BattleEvents.FLAG_EVERY = 60 -- seconds between the flag reads (and the flagged time sent)
BattleEvents.RECAP_DELAY = 1 -- seconds after a death before the recap is read

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

-- ===== The PvP flag, deaths and victims (CF-104) =====

local function send(kind, obs) addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs) end

-- Sends the flagged time since the last send. on: false when the flag dropped.
local function flushFlag(now, on)
  local guid = ns.SelfInfo.guid()
  if flaggedSince and guid and now > flaggedSince then
    send("battleFlag", { guid = guid, seconds = now - flaggedSince, on = on })
  elseif guid and on == false then
    send("battleFlag", { guid = guid, seconds = 0, on = false })
  end
end

local function checkFlag()
  local now = GetServerTime()
  local flagged = ns.Safe.call(UnitIsPVP, "player") == true
  if flagged then
    if flaggedSince then flushFlag(now, true) end
    flaggedSince = now
  elseif flaggedSince then
    flushFlag(now, false)
    flaggedSince = nil
  end
end

local function onDead()
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  if flaggedSince then -- the time up to the death still counts; the death ends the run
    local now = GetServerTime()
    flushFlag(now, true)
    flaggedSince = now
  end
  ns.Timer.after(BattleEvents.RECAP_DELAY, function()
    local _, _, killer = ns.PvpInfo.recapDamage()
    send("battleDeath", { guid = guid, killer = type(killer) == "string" and killer or nil })
  end)
end

local function onVictim(_, victim, bg)
  local guid = ns.SelfInfo.guid()
  if guid and type(victim) == "string" then send("battleVictim", { guid = guid, victim = victim, bg = bg == true }) end
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
  ns.Events.register(events, "PLAYER_FLAGS_CHANGED", checkFlag) -- any unit: the read is the player's own flag
  ns.Events.register(events, "PLAYER_DEAD", onDead)
  events:RegisterMessage(ns.PvpTracker.VICTIM, onVictim)
  events:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason)
    if reason == "logout" and flaggedSince then flushFlag(GetServerTime(), true) end
  end)
  ns.Timer.every(BattleEvents.FLAG_EVERY, checkFlag)
  checkFlag()
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Battle = BattleEvents
return BattleEvents
