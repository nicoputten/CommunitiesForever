--[[ LaunchProbeMissions (CF-82): the hidden probe's checks for the PvP catalogue (V122, V123) and the trade
(V85). Same rules as services/LaunchProbe.lua: silent, guarded, cheap, no raw chat text and no player names.
CF-96: only the checks the launch results (build 70790) left open run. The answered ones are in
docs/API-FINDINGS.md "Forever launch probe". CF-109 to CF-117 removed V114, V120 and the auction post. CF-120: V96,
V101 and V108 (the mission catalogue's checks) are gone; V123 reads the zone's type at every zone change. ]]
local _, ns = ...

local Probe = ns.Probe
local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, Vals, readable, str, get = u.Val, u.Vals, u.readable, u.str, u.get
local result, note, info, passed, after, now = u.result, u.note, u.info, u.passed, u.after, u.now
local on = LaunchProbe.on

-- ===== V85: the items you put in a trade (CF-120; w.craftTrade, adapters/GoalEvents.lua reads the same) =====
-- TRADE_PLAYER_ITEM_CHANGED(slot) and GetTradePlayerItemLink(slot): only the item ID is kept, never the partner.
on("TRADE_PLAYER_ITEM_CHANGED", function(slot)
  if passed("V85") then return end
  local link = type(slot) == "number" and readable(slot) and get(GetTradePlayerItemLink, slot)
  local id = str(link) and link:match("|Hitem:(%d+)")
  if id then
    result("V85", "pass", "TRADE_PLAYER_ITEM_CHANGED slot " .. slot .. ": item " .. id)
  else
    info("V85", "TRADE_PLAYER_ITEM_CHANGED slot " .. Val(slot) .. ", GetTradePlayerItemLink "
      .. (GetTradePlayerItemLink and Val(link or nil) or "missing"))
  end
end)

-- ===== V122: the battleground score (at most once a minute) =====
local scoreAt
on("UPDATE_BATTLEFIELD_SCORE", function()
  if passed("V122") or (scoreAt and now() - scoreAt < 60) then return end
  scoreAt = now()
  local me = get(UnitName, "player")
  local count = get(GetNumBattlefieldScores)
  local stats = {}
  for s = 1, get(GetNumBattlefieldStats) or 0 do stats[#stats + 1] = Vals(GetBattlefieldStatInfo, s) end
  for i = 1, type(count) == "number" and count or 0 do
    local name, _, honorableKills = GetBattlefieldScore(i)
    if str(name) and str(me) and name:find(me, 1, true) == 1 then
      if type(honorableKills) == "number" and readable(honorableKills) then
        result("V122", #stats > 0 and "pass" or "info", "own honorable kills " .. honorableKills .. "; " .. #stats
          .. " battleground stats" .. (#stats > 0 and (": " .. table.concat(stats, " / ")) or ""))
      else
        result("V122", "fail", "own honorable kills " .. Val(honorableKills))
      end
      return
    end
  end
end)

-- ===== V123: the zone's PvP type (CF-120) =====
-- Read at every zone change (ZONE_CHANGED_NEW_AREA, ZONE_CHANGED, ZONE_CHANGED_INDOORS, PLAYER_ENTERING_WORLD and the
-- login) and again Probe.ZONE_RECHECK seconds later. Each zone new for its type is noted with the type string read,
-- the PvP flag and the realm type's hint (C_PvP.IsWarModeActive, guarded); the result counts zones per type.
local zoneCounts = {} -- this session: { [type] = { [zone] = true } }
local function ZonePvp()
  local zonePvp = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  if not zonePvp then
    result("V123", "fail", "GetZonePVPInfo missing")
    return
  end
  local pvpType = get(zonePvp)
  local zone = get(GetRealZoneText)
  if not Probe.zoneSeen(zoneCounts, str(zone) and zone or nil, str(pvpType) and pvpType or nil) then return end
  local warMode = C_PvP and C_PvP.IsWarModeActive
  note("V123", Val(zone) .. ": " .. Val(pvpType) .. ", flagged " .. Val(get(UnitIsPVP, "player"))
    .. (warMode and (", war mode " .. Val(get(warMode))) or ""))
  local status, detail = Probe.zoneResult(zoneCounts)
  if status == "pass" then result("V123", status, detail) else info("V123", detail) end
end
local function ZoneChanged()
  ZonePvp()
  after(Probe.ZONE_RECHECK, ZonePvp)
end
for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }) do
  on(event, ZoneChanged)
end
LaunchProbe.atLogin(ZoneChanged)
-- For tests: forget this session's zones.
function LaunchProbe.zoneReset() zoneCounts = {} end
