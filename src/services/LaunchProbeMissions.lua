--[[ LaunchProbeMissions (CF-82): the hidden probe's checks for the Doomsday mission catalogue and the PvP catalogue
(V120 to V123). Same rules as services/LaunchProbe.lua: silent, guarded, cheap, no raw chat text and no player names
except the killer's (V120). Left out: the jump hook (V118, a "blocked" popup is a possible answer) and the campfire
(V119, judged by eye).
CF-96: only the checks the launch results (build 70790) left open run: V96, V101, V108 (the emote part), V114 and
V120 to V123. The answered ones are in docs/API-FINDINGS.md "Forever launch probe". ]]
local _, ns = ...

local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, Vals, readable, str, get = u.Val, u.Vals, u.readable, u.str, u.get
local matches, result, note, info, passed, after, now = u.matches, u.result, u.note, u.info, u.passed, u.after, u.now
local on = LaunchProbe.on

-- ===== V108: an emote on a target (the whisper part is answered) =====
LaunchProbe.hook("DoEmote", function(token)
  if passed("V108") then return end
  local theirs = get(UnitFactionGroup, "target")
  local enemy = get(UnitIsPlayer, "target") and theirs ~= nil and theirs ~= get(UnitFactionGroup, "player")
  local seen = "emote " .. Val(token) .. " on " .. (enemy and "an enemy-faction player" or "no enemy player")
  if str(token) and enemy then
    result("V108", "pass", seen)
  else
    info("V108", seen .. "; an emote at an enemy-faction player still to see")
  end
end)

-- ===== V96, V101, V114: home inn, auctions, summons =====
local function Message(text)
  if str(text) and matches(text, "ERR_AUCTION_STARTED") then result("V101", "pass", "posted: ERR_AUCTION_STARTED") end
end
on("UI_INFO_MESSAGE", function(_, text) Message(text) end)
on("CHAT_MSG_SYSTEM", Message)

on("AUCTION_HOUSE_AUCTION_CREATED", function() result("V101", "pass", "posted: AUCTION_HOUSE_AUCTION_CREATED") end)
on("PLAYER_BINDING_CHANGED", function()
  local place = get(GetBindLocation)
  result("V96", str(place) and "pass" or "fail", "GetBindLocation " .. Val(place))
end)

on("CONFIRM_SUMMON", function()
  local summoner = get(C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner)
  result("V114", str(summoner) and "pass" or "fail", "summoner " .. (str(summoner) and "readable" or Val(summoner)))
end)

-- ===== V120: who killed you, from the death recap (1 s after the death) =====
local function Killer()
  local recap = C_DeathRecap and C_DeathRecap.GetRecapEvents
  if not recap then
    result("V120", "fail", "C_DeathRecap.GetRecapEvents missing")
    return
  end
  local events = get(recap)
  if type(events) ~= "table" then
    info("V120", "no recap events (" .. Val(events) .. ")")
    return
  end
  local last
  for _, e in ipairs(events) do
    if type(e) == "table" then last = e end
  end
  if not last then return end
  local guid = last.sourceGUID
  note("V120", "last recap source: " .. (str(guid) and (guid:match("^(%a+)") or "?") or Val(guid)) .. ", name "
    .. (str(last.sourceName) and "readable" or Val(last.sourceName)))
  if str(last.sourceName) and str(guid) and guid:match("^Player%-") then
    result("V120", "pass", "killed by player " .. last.sourceName)
  else
    info("V120", "last recap source not a player with a name; a death to a player still to see")
  end
end
on("PLAYER_DEAD", function() after(1, Killer) end)

-- ===== V121: the PvP flag =====
local flagSeen
local function Flag()
  local flagged = UnitIsPVP and UnitIsPVP("player")
  if not readable(flagged) or flagged == flagSeen then
    if flagged == nil then result("V121", "fail", "UnitIsPVP missing") end
    return
  end
  flagSeen = flagged
  if flagged == true then result("V121", "pass", "UnitIsPVP true after a flag change") end
end
on("PLAYER_FLAGS_CHANGED", function(unit) if unit == "player" then Flag() end end)
LaunchProbe.atLogin(Flag)

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
