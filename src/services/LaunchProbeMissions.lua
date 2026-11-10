--[[ LaunchProbeMissions (CF-82): the hidden probe's checks for the Doomsday mission catalogue and the PvP catalogue
(V122, V123). Same rules as services/LaunchProbe.lua: silent, guarded, cheap, no raw chat text and no player names.
Left out: the jump hook (V118, a "blocked" popup is a possible answer) and the campfire (V119, judged by eye).
CF-96: only the checks the launch results (build 70790) left open run: V96, V101, V108 (the emote part), V114 and
V120 to V123. The answered ones are in docs/API-FINDINGS.md "Forever launch probe". CF-109: V114 answered (build
70862), its check is gone. CF-113: V120 answered (build 70862: the recap names a player killer), its check is gone;
posting an auction answered (AUCTION_HOUSE_AUCTION_CREATED), V101 checks only buying. ]]
local _, ns = ...

local Probe = ns.Probe
local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, Vals, readable, str, get = u.Val, u.Vals, u.readable, u.str, u.get
local matches, result, note, info, passed, now = u.matches, u.result, u.note, u.info, u.passed, u.now
local on = LaunchProbe.on

-- ===== V108: an emote on a target (the whisper part is answered) =====
-- CF-117, bug 14: a typed /wave never reached the DoEmote hook on Forever. Also hooked: C_ChatInfo.PerformEmote (only
-- when it exists), and CHAT_MSG_TEXT_EMOTE with your own GUID as the sender (its 12th argument) shows that an emote
-- happened even when no hook fired. No chat text and no names are kept (Probe.emote).
local EMOTE_APIS = { "DoEmote", "C_ChatInfo.PerformEmote" }
local lastEmote -- { via, at }: the last hooked emote

-- Your target as Probe.emote's target ("enemy", "friendly", "unknown", "none") and whether its GUID is readable.
local function EmoteTarget()
  if not get(UnitIsPlayer, "target") then return "none", false end
  local guid = str(get(UnitGUID, "target")) and true or false
  local theirs, mine = get(UnitFactionGroup, "target"), get(UnitFactionGroup, "player")
  if not (str(theirs) and str(mine)) then return "unknown", guid end
  return theirs ~= mine and "enemy" or "friendly", guid
end

local function Emote(via, token)
  lastEmote = { via = via, at = now() }
  if passed("V108") then return end
  local target, guid = EmoteTarget()
  local status, detail = Probe.emote(via, str(token) and token or nil, target, guid)
  if status == "pass" then result("V108", status, detail) else info("V108", detail) end
end

for _, api in ipairs(EMOTE_APIS) do
  LaunchProbe.hook(api, function(token) Emote(api, token) end)
end

on("CHAT_MSG_TEXT_EMOTE", function(...)
  local sender, mine = select(12, ...), get(UnitGUID, "player")
  if not (str(sender) and str(mine) and sender == mine) then return end
  if lastEmote and now() - lastEmote.at <= Probe.EMOTE_PAIR then
    note("V108", "chat line after " .. lastEmote.via)
    return
  end
  local target, guid = EmoteTarget()
  local apis = {}
  for _, api in ipairs(EMOTE_APIS) do
    if LaunchProbe.hookable(api) then apis[api] = true end
  end
  local _, detail = Probe.emote("chat", nil, target, guid, apis)
  info("V108", detail)
end)

-- ===== V96, V101: home inn, buying at the auction house (posting and V114, summons, answered: CF-113, CF-109) =====
-- A pass stored for a posted auction (before CF-113) is replaced by the first buy's pass (Probe.record).
local function Message(text)
  if str(text) and matches(text, "ERR_AUCTION_WON_S") then result("V101", "pass", "bought: ERR_AUCTION_WON_S") end
end
on("UI_INFO_MESSAGE", function(_, text) Message(text) end)
on("CHAT_MSG_SYSTEM", Message)

on("AUCTION_HOUSE_PURCHASE_COMPLETED", function()
  result("V101", "pass", "bought: AUCTION_HOUSE_PURCHASE_COMPLETED")
end)
on("PLAYER_BINDING_CHANGED", function()
  local place = get(GetBindLocation)
  result("V96", str(place) and "pass" or "fail", "GetBindLocation " .. Val(place))
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

-- ===== V123: the zone's PvP type =====
-- "friendly" is answered (capital cities); it keeps looking for the other types (CF-96): each new type in a session
-- is noted, and a type other than "friendly" becomes the result.
local zoneTypes = {} -- this session's types seen: { [type] = true }
local function ZonePvp()
  local zonePvp = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  if not zonePvp then
    result("V123", "fail", "GetZonePVPInfo missing")
    return
  end
  local pvpType = get(zonePvp)
  local zone = Val(get(GetRealZoneText))
  local kind = str(pvpType) and pvpType or "none"
  if zoneTypes[kind] then return end
  zoneTypes[kind] = true
  note("V123", zone .. ": " .. (str(pvpType) and pvpType or Val(pvpType)))
  if not str(pvpType) then
    info("V123", "no PvP type in " .. zone .. " (" .. Val(pvpType) .. ")")
  elseif pvpType ~= "friendly" or not passed("V123") then
    result("V123", "pass", zone .. ": " .. pvpType)
  end
end
on("ZONE_CHANGED_NEW_AREA", ZonePvp)
LaunchProbe.atLogin(ZonePvp)
