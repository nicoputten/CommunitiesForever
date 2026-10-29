-- FriendProbe: the launch checklist (CF-60). It checks the open API questions and story steps of VERIFY.md
-- in-game (Claude Code cannot run WoW), so one zip is all a friend installs.
-- - Silent: no chat output during play. Everything goes to FriendProbeDB (the saved file, WTF\Account\<account>\
--   SavedVariables\FriendProbe.lua): the log (capped), and per checklist item its result.
-- - Automatic: from the first login until STOP_AT (2026-11-18) it logs and checks by itself; nothing to type.
-- - /fp opens the checklist window: six play sessions, automatic ticks, Yes / No for what it can't judge, test
--   buttons (reload, links and invites, invite all) and Copy report.
-- The items are in Checklist.lua (data, kept in step with VERIFY.md by tests/spec/ProbeChecklist_spec.lua).
-- Already answered checks were removed; see docs/API-FINDINGS.md and the git history for the old probes.
local _, ns = ...

local MAX_LOG = 2000
-- Until when the probe runs by itself: 2026-11-18 00:00 UTC (two weeks after launch).
local STOP_AT = 1794960000

local function S(v)
  local ok, s = pcall(tostring, v)
  return ok and s or "<secret/err>"
end

local function log(...)
  FriendProbeDB = FriendProbeDB or {}
  FriendProbeDB.log = FriendProbeDB.log or {}
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = S((select(i, ...))) end
  local line = table.concat(parts, " ")
  local l = FriendProbeDB.log
  l[#l + 1] = date("%H:%M:%S ") .. line
  while #l > MAX_LOG do table.remove(l, 1) end
end

-- The client the probe runs on: "forever" (WOW_PROJECT_ID 18), "retail" (1, a dry run before launch) or
-- "project <n>". Results are kept per client: a Retail answer never closes a Forever item.
function ns.client()
  if WOW_PROJECT_ID == 18 then return "forever" end
  if WOW_PROJECT_ID == 1 then return "retail" end
  return "project " .. S(WOW_PROJECT_ID)
end

-- This client's results: { [id] = result }.
function ns.results()
  FriendProbeDB = FriendProbeDB or {}
  FriendProbeDB.results = FriendProbeDB.results or {}
  local client = ns.client()
  FriendProbeDB.results[client] = FriendProbeDB.results[client] or {}
  return FriendProbeDB.results[client]
end

-- A checklist item's result: status "pass" | "fail" | "yes" | "no" | "info", with what was seen. A pass stays (once
-- it worked, the question is answered); later fails are kept as detail. Stored per client and item, with the
-- character, the build and the time.
local function result(id, status, detail)
  local results = ns.results()
  local r = results[id]
  if r and r.status == "pass" and status ~= "pass" and status ~= "no" then
    r.later = S(detail)
    return
  end
  results[id] = { status = status, detail = S(detail):sub(1, 200), at = date("%Y-%m-%d %H:%M"),
                  char = GetUnitName and S(GetUnitName("player", true)) or "?",
                  build = GetBuildInfo and S((select(2, GetBuildInfo()))) or "?" }
  log("RESULT", ns.client(), id, status, S(detail))
  if ns.refresh then ns.refresh() end
end
ns.result = result

-- Every field of a table on one line, sorted, so we see what Forever returns, not what we expect.
local function DumpTable(label, t)
  if type(t) ~= "table" then log(label, t) return end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return S(a) < S(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "table" then
      local inner = {}
      for ik, iv in pairs(v) do inner[#inner + 1] = S(ik) .. ":" .. S(iv) end
      v = "{" .. table.concat(inner, ",") .. "}"
    end
    parts[#parts + 1] = S(k) .. "=" .. S(v)
  end
  log(label, table.concat(parts, " "))
end

-- Logs every return value of fn(...) guarded, under label.
local function LogCall(label, fn, ...)
  if not fn then log(label, "does not exist") return end
  local results = { pcall(fn, ...) }
  if not results[1] then log(label, "error", results[2]) return end
  log(label, "->", unpack(results, 2, table.maxn(results)))
end

-- Runs one check; an error is logged and the next check still runs.
local function Section(title, fn)
  log("== " .. title .. " ==")
  local ok, err = pcall(fn)
  if not ok then log(title, "error", err) end
end

-- ===== Context =====
local function Context()
  log("build", GetBuildInfo())
  log("WOW_PROJECT_ID", WOW_PROJECT_ID)
  log("character", GetUnitName and GetUnitName("player", true), "class", UnitClassBase("player"),
    "level", UnitLevel("player"), "faction", UnitFactionGroup("player"), "race", select(3, UnitRace("player")))
  log("realm", GetRealmName())
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata
  for _, addon in ipairs({ "CommunitiesForever", "Questie", "QuestieDB" }) do
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon)
    log("addon", addon, "loaded", S(loaded), "version", S(getMeta and getMeta(addon, "Version")))
  end
  if LibQuestieDB then
    log("LibQuestieDB contract", S(LibQuestieDB.contractVersion), "min", S(LibQuestieDB.minSupportedContract),
      "mode", S(LibQuestieDB.readMode))
  end
end

-- ===== V8: community IDs =====
local function Clubs()
  if not (C_Club and C_Club.GetSubscribedClubs) then log("C_Club missing") return end
  local types = {}
  if Enum and Enum.ClubType then
    for k, v in pairs(Enum.ClubType) do types[v] = k end
  end
  for _, club in ipairs(C_Club.GetSubscribedClubs() or {}) do
    log("club", club.clubId, S(club.name), "type", types[club.clubType] or club.clubType)
  end
  log("compare these clubIds with the same /fp start on another client (V8)")
end

-- ===== V35: activity feed events (logged while on, also after /reload) =====
local FEED_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END",
  "BOSS_KILL", "GROUP_ROSTER_UPDATE", "UPDATE_BATTLEFIELD_STATUS", "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE" }

local function LogInstance()
  if GetInstanceInfo then
    local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
    log("  instance", name, "type", instanceType, "difficulty", difficultyID, difficultyName, "max", maxPlayers,
      "id", instanceID)
  end
end

local function LogGroup()
  LogCall("  GetNumGroupMembers", GetNumGroupMembers)
  LogCall("  IsInRaid", IsInRaid)
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists and UnitExists(unit) then log("  " .. unit, GetUnitName(unit, true), UnitGUID(unit)) end
  end
end

local feedFrame = CreateFrame("Frame")
local feedRegistered = false
local function FeedRegister()
  if feedRegistered then return end
  feedRegistered = true
  for _, event in ipairs(FEED_EVENTS) do
    if not pcall(feedFrame.RegisterEvent, feedFrame, event) then log("feed: unknown event", event) end
  end
end

feedFrame:SetScript("OnEvent", function(_, event, ...)
  if not ns.running() then return end
  local args = {}
  for i = 1, select("#", ...) do args[#args + 1] = S((select(i, ...))) end
  log("FEED " .. event, table.concat(args, " | "))
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    LogInstance()
  elseif event == "GROUP_ROSTER_UPDATE" or event == "ENCOUNTER_END" or event == "BOSS_KILL" then
    LogInstance()
    LogGroup()
  elseif event == "UPDATE_BATTLEFIELD_STATUS" and GetBattlefieldStatus then
    LogCall("  GetBattlefieldStatus", GetBattlefieldStatus, (...) or 1)
    LogCall("  GetBattlefieldWinner", GetBattlefieldWinner)
  elseif event == "PVP_MATCH_COMPLETE" then
    local winner = ...
    if type(winner) == "number" then result("V35b", "pass", "PVP_MATCH_COMPLETE winner " .. winner) end
    LogCall("  GetBattlefieldWinner", GetBattlefieldWinner)
    LogCall("  GetBattlefieldArenaFaction", GetBattlefieldArenaFaction)
    LogCall("  UnitFactionGroup", UnitFactionGroup, "player")
  end
end)


-- ===== V47/V48: addon chat links and party invites (CF-27) =====
-- Each link click is a hardware event, like the real Join and Invite links will be. Events around
-- invites and blocked actions are logged while the probe runs.
local INVITE_EVENTS = { "PARTY_INVITE_REQUEST", "GROUP_INVITE_CONFIRMATION", "PARTY_INVITE_CANCEL",
  "GROUP_ROSTER_UPDATE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UI_ERROR_MESSAGE" }
local inviteTargets = {}
local inviteWatching = false
local lastLink, lastLinkAt = nil, 0

local inviteFrame = CreateFrame("Frame")
inviteFrame:SetScript("OnEvent", function(_, event, ...)
  if not inviteWatching then return end
  local args = {}
  for i = 1, select("#", ...) do args[#args + 1] = S((select(i, ...))) end
  log("INVITE EVENT " .. event, table.concat(args, " | "))
end)

local function OnLink(source, link)
  local action, index = S(link):match("^addon:FriendProbe:(%a+):(%d+)")
  if not action then return end
  log("V47 link clicked via", source, action, index)
  result("V47", "pass", "link click reached the addon via " .. S(source))
  -- Both hooks may report the same click: act once.
  local now = GetTime()
  if lastLink == link and now - lastLinkAt < 1 then return end
  lastLink, lastLinkAt = link, now
  local t = inviteTargets[tonumber(index)]
  if action == "test" or not t then return end
  if action == "request" then
    LogCall("C_PartyInfo.RequestInviteFromUnit " .. t.name, C_PartyInfo and C_PartyInfo.RequestInviteFromUnit, t.name)
  elseif action == "name" then
    LogCall("C_PartyInfo.InviteUnit " .. t.name, C_PartyInfo and C_PartyInfo.InviteUnit, t.name)
  elseif action == "bnet" then
    LogCall("BNInviteFriend " .. S(t.gameAccountID), BNInviteFriend, t.gameAccountID)
  end
end

local linksHooked = false
local function HookLinks()
  if linksHooked then return end
  linksHooked = true
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink("EventRegistry", link) end, {})
    log("hooked EventRegistry SetItemRef")
  end
  if SetItemRef then
    hooksecurefunc("SetItemRef", function(link) OnLink("SetItemRef hook", link) end)
    log("hooked SetItemRef")
  end
end

local function Link(action, index, text)
  return string.format("|cff71d5ff|Haddon:FriendProbe:%s:%d|h[%s]|h|r", action, index, text)
end

-- Characters of Battle.net friends online in Forever: { name, gameAccountID, battleTag }.
local function OnlineFriends()
  local friends = {}
  for i = 1, BNGetNumFriends() do
    local acc = C_BattleNet.GetFriendAccountInfo(i)
    for j = 1, acc and C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
      local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
      if ga and ga.isOnline and ga.clientProgram == BNET_CLIENT_WOW and ga.wowProjectID == WOW_PROJECT_ID then
        friends[#friends + 1] = { name = ga.characterName, gameAccountID = ga.gameAccountID, battleTag = acc.battleTag }
      end
    end
  end
  return friends
end

local function WatchInvites()
  if inviteWatching then return end
  inviteWatching = true
  for _, event in ipairs(INVITE_EVENTS) do pcall(inviteFrame.RegisterEvent, inviteFrame, event) end
end

local function Invite()
  log("== V47/V48 INVITE ==")
  for _, name in ipairs({ "RequestInviteFromUnit", "InviteUnit", "ConfirmInviteUnit" }) do
    log("exists C_PartyInfo." .. name, C_PartyInfo ~= nil and C_PartyInfo[name] ~= nil)
  end
  log("exists BNInviteFriend", BNInviteFriend ~= nil, "EventRegistry", EventRegistry ~= nil)
  HookLinks()
  WatchInvites()
  -- The only chat output of the probe: the links have to be in chat to be clicked (the player pressed the test).
  print("|cff33ff99FP|r V47 " .. Link("test", 0, "click me: link test"))
  inviteTargets = OnlineFriends()
  for n, t in ipairs(inviteTargets) do
    log("friend", n, S(t.name), "gameAccountID", S(t.gameAccountID))
    print("|cff33ff99FP|r V48 " .. S(t.name) .. ": " .. Link("request", n, "ask them for an invite")
      .. " " .. Link("name", n, "invite by name") .. " " .. Link("bnet", n, "invite via Battle.net"))
  end
  if #inviteTargets == 0 then log("no friend online in Forever: the invite links need one") end
  log("click the test link, then each invite link once (leave the group between tries); /reload and send the log")
end

-- ===== V67-V69: planned runs (CF-45) =====
-- A small window with buttons: each click is a hardware event, like the addon's own buttons will be.
local function ButtonWindow(title, buttons)
  local window = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
  window:SetSize(280, 50 + 32 * #buttons)
  window:SetPoint("CENTER", 0, 160)
  window:SetFrameStrata("DIALOG")
  local label = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOP", 0, -6)
  label:SetText(title)
  for i, b in ipairs(buttons) do
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    button:SetSize(240, 26)
    button:SetPoint("TOP", 0, -36 - 32 * (i - 1))
    button:SetText(b.text)
    button:SetScript("OnClick", b.click)
  end
  return window
end

-- V67: is a changed Lua file in the addon folder re-read on /reload? ReloadProbe.lua ships with "A"; the
-- VERIFY.md step changes it on disk while the game runs. ReloadProbeLate.lua is not in the shipped TOC (a missing
-- file listed there shows a Lua warning at every login): the step adds the file and its TOC line by hand.
local function ReloadFile()
  log("V67 ReloadProbe.lua mark", S(FriendProbeReloadMark), "| ReloadProbeLate.lua",
    FriendProbeLateMark and S(FriendProbeLateMark) or "not loaded")
end

-- V68: may an addon reload the UI from a button click? The click is remembered in FriendProbeDB; after
-- the reload, ADDON_LOADED logs which call did it.
local reloadWindow
local function ReloadButtons()
  log("== V68 RELOAD FROM A CLICK ==")
  log("exists C_UI.Reload", C_UI ~= nil and C_UI.Reload ~= nil, "ReloadUI", ReloadUI ~= nil)
  WatchInvites() -- also logs ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN
  local function try(label, fn)
    return function()
      log("V68 click", label)
      FriendProbeDB.reloadBy = label
      LogCall("V68 " .. label, fn)
      C_Timer.After(2, function()
        FriendProbeDB.reloadBy = nil
        log("V68", label, "did not reload within 2 s")
      end)
    end
  end
  if reloadWindow then reloadWindow:Show() return end
  reloadWindow = ButtonWindow("V68: one click reloads", {
    { text = "C_UI.Reload()", click = try("C_UI.Reload", C_UI and C_UI.Reload) },
    { text = "ReloadUI()", click = try("ReloadUI", ReloadUI) },
  })
  log("V68 click a button: the UI should reload; after it, /fp reload again for the other one")
end

-- V69: one click invites several friends in a row by name (CF-48: Invite everyone ready).
local inviteAllWindow
local function InviteAll()
  log("== V69 INVITE SEVERAL ==")
  WatchInvites()
  local friends = OnlineFriends()
  for n, t in ipairs(friends) do log("friend", n, S(t.name)) end
  log("in group", S(GetNumGroupMembers and GetNumGroupMembers()))
  if #friends < 2 then log("V69 needs at least two friends online in Forever (now " .. #friends .. ")") end
  if inviteAllWindow then inviteAllWindow:Hide() end
  inviteAllWindow = ButtonWindow("V69: " .. #friends .. " friends online", {
    { text = "Invite all " .. #friends, click = function()
      log("V69 click: inviting", #friends)
      for _, t in ipairs(friends) do
        LogCall("V69 C_PartyInfo.InviteUnit " .. S(t.name), C_PartyInfo and C_PartyInfo.InviteUnit, t.name)
      end
      C_Timer.After(10, function() log("V69 after 10 s: in group", S(GetNumGroupMembers())) end)
    end },
  })
  log("V69 click Invite all (you not in a group); friends accept; /reload and send the log")
end

-- ===== V49-V52: community transport (CF-28) =====
local COMM_PREFIX = "FProbe"
local commReceived = {}

local function CommunityChannel()
  if not (C_Club and C_Club.GetSubscribedClubs) then return nil end
  for _, club in ipairs(C_Club.GetSubscribedClubs() or {}) do
    if Enum and Enum.ClubType and club.clubType == Enum.ClubType.Character then
      local streams = C_Club.GetStreams and C_Club.GetStreams(club.clubId) or {}
      local stream = streams[1]
      for _, st in ipairs(streams) do
        if Enum.ClubStreamType and st.streamType == Enum.ClubStreamType.General then stream = st end
      end
      local name = stream and Chat_GetCommunitiesChannelName and Chat_GetCommunitiesChannelName(club.clubId,
        stream.streamId)
      return name, name and GetChannelName and GetChannelName(name), club
    end
  end
end

local function SendAddon(label, text, channel, target)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then log(label, "SendAddonMessage missing") return end
  local ok, sent = pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, text, channel, target)
  log(label, "len", #text, "->", ok and S(sent) or ("error " .. S(sent)))
end

local function CommSummary()
  local tags = {}
  for tag in pairs(commReceived) do tags[#tags + 1] = tag end
  table.sort(tags)
  for _, tag in ipairs(tags) do log("received", tag, commReceived[tag]) end
  if #tags == 0 then log("nothing received back (yet)") end
end

local function CommunityTransport()
  if Enum and Enum.SendAddonMessageResult then DumpTable("Enum.SendAddonMessageResult", Enum.SendAddonMessageResult) end
  commReceived = {}
  local name, index, club = CommunityChannel()
  log("V49 community", S(club and club.name), "channel", S(name), "index", S(index))
  if index and index > 0 then
    SendAddon("V49 CHANNEL send", "V49:channel", "CHANNEL", index)
  else
    log("V49 no community channel index (open the community chat once?)")
  end
  local me = GetUnitName and GetUnitName("player", true)
  for _, size in ipairs({ 200, 255, 256 }) do
    SendAddon("V50 WHISPER self " .. size, "V50:" .. size .. ":" .. string.rep("x", size - #("V50:" .. size .. ":")),
      "WHISPER", me)
  end
  for i = 1, 30 do SendAddon("V50 burst " .. i, "V50:burst:" .. i, "WHISPER", me) end
  log("V49/V50 sent; wait 15 s before /reload (or /fp comm summary)")
  C_Timer.After(3, function() log("== V49/V50 RECEIVED after 3 s ==") CommSummary() end)
  C_Timer.After(10, function() log("== V49/V50 RECEIVED after 10 s ==") CommSummary() end)
end

local function CommunityPresence()
  local _, _, club = CommunityChannel()
  if not club then log("no character community") return end
  local presence = {}
  if Enum and Enum.ClubMemberPresence then
    for k, v in pairs(Enum.ClubMemberPresence) do presence[v] = k end
  end
  for _, memberId in ipairs(C_Club.GetClubMembers(club.clubId) or {}) do
    local m = C_Club.GetMemberInfo(club.clubId, memberId)
    if m then
      log("member", S(m.name), "presence", S(presence[m.presence] or m.presence), "level", S(m.level),
        "zone", S(m.zone), "self", S(m.isSelf))
    end
  end
  log("V52: note who logged out and when; if they still show Online after a few minutes, presence is stale")
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, _, prefix, text, channel, sender, target, zoneChannelID, localID, name)
  if prefix ~= COMM_PREFIX then return end
  local tag = S(text):match("^(V%d+:%a+)") or S(text):match("^(V%d+:%d+)") or "other"
  commReceived[tag] = (commReceived[tag] or 0) + 1
  if tag == "V50:burst" then
    -- Logged as they arrive (a /reload before a delayed summary lost the count in run 1).
    if commReceived[tag] % 10 == 0 then log("received V50:burst", commReceived[tag], "so far") end
    if commReceived[tag] == 30 then result("V50b", "pass", "all 30 burst whispers arrived") end
  else
    if tag == "V51:whisper" then result("V51", "pass", "whisper from " .. S(sender) .. " arrived") end
    log("addon message <-", S(sender), "channel", S(channel), "len", #S(text), "target", S(target), "zoneChannelID",
      S(zoneChannelID), "localID", S(localID), "name", S(name), "text", S(text):sub(1, 20))
  end
end)

-- ===== V73-V76 (CF-54), V79-V83 (CF-52, CF-53): kills, victims, deaths, duels, loot =====
-- /fp pvp switches the logging on (stays on after /reload; /fp pvp off). Every call is guarded: a missing
-- function logs "missing", a secret value "secret".
local function Val(v)
  if v == nil then return "missing" end
  if issecretvalue and issecretvalue(v) then return "secret" end
  return S(v)
end

-- Every return value of fn(...) through Val, or "missing" / "error".
local function Vals(fn, ...)
  if not fn then return "missing" end
  local results = { pcall(fn, ...) }
  if not results[1] then return "error " .. S(results[2]) end
  local parts = {}
  for i = 2, table.maxn(results) do parts[#parts + 1] = Val(results[i]) end
  return #parts > 0 and table.concat(parts, ", ") or "(nothing)"
end

-- Lua pattern of a game format string ("%s dies, honorable kill Rank: %s ..."), positional args too.
local function Pattern(format)
  if type(format) ~= "string" then return nil end
  local p = format:gsub("%%%d%$([sd])", "%%%1") -- "%1$s" -> "%s"
  p = p:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
  p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. p .. "$"
end

local PVP_EVENTS = { "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_PVP_KILLS_CHANGED", "NAME_PLATE_UNIT_ADDED",
  "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_DEAD", "CHAT_MSG_SYSTEM", "MIRROR_TIMER_START",
  "MIRROR_TIMER_STOP", "CHAT_MSG_LOOT", "PLAYER_MONEY", "LOOT_OPENED", "TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED",
  "UI_INFO_MESSAGE", "ENCOUNTER_START", "ENCOUNTER_END" }

-- V86: a "Discovered" message (ERR_ZONE_EXPLORED, ERR_ZONE_EXPLORED_XP).
local function Discovered(text)
  for _, key in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
    local p = Pattern(_G[key])
    if p and text:match(p) then
      log("V86 discovered", text)
      result("V86", "pass", key .. " matched: " .. text)
    end
  end
end
local pvpFrame = CreateFrame("Frame")
local pvpRegistered, combatLog = false, nil
local unitSeen = {}   -- guid -> GetTime() of the last V74 line (one line per player per minute)
local seenByName = {} -- full name -> the fields seen, for the honor message
local lastDamage      -- the last damage the player took (combat log)
local mirrorSeen      -- a MIRROR_TIMER event was seen (V81)
local encounter       -- an encounter is in progress (V70)
local tradePartner    -- V85: the trade partner's GUID, the items given
local tradeGiven = {}

local function Counters(label)
  log(label, "session", Vals(GetPVPSessionStats), "| lifetime", Vals(GetPVPLifetimeStats),
    "| this week", Vals(GetPVPThisWeekStats))
end

local function LogUnit(unit, source)
  if not (UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return end
  local enemy = (UnitIsEnemy and UnitIsEnemy("player", unit)) or (UnitCanAttack and UnitCanAttack("player", unit))
  if not enemy then return end
  local guid = UnitGUID(unit)
  local key = Val(guid)
  if unitSeen[key] and GetTime() - unitSeen[key] < 60 then return end
  unitSeen[key] = GetTime()
  local name = GetUnitName and GetUnitName(unit, true)
  local level = UnitLevel and UnitLevel(unit)
  local _, class = UnitClass(unit)
  local _, race = UnitRace(unit)
  local rank = UnitPVPRank and UnitPVPRank(unit)
  log("V74 unit", source, "name", Val(name), "level", Val(level), "class", Val(class), "race", Val(race),
    "UnitPVPRank", Val(rank), "rankInfo", rank and Vals(GetPVPRankInfo, rank, unit) or "missing", "guid", Val(guid))
  local fields = { level = level, class = class, race = race }
  local bad = {}
  for field, v in pairs(fields) do
    if v == nil or (issecretvalue and issecretvalue(v)) then bad[#bad + 1] = field .. " " .. Val(v) end
  end
  table.sort(bad)
  if #bad == 0 then
    result("V74", "pass", "level, class and race readable via " .. source)
  else
    result("V74", "fail", table.concat(bad, ", ") .. " via " .. source)
  end
  if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
    seenByName[name] = { level = level, class = class, race = race, rank = rank, at = GetTime(), source = source }
  end
end

local function Honor(text, ...)
  local args = { ... }
  for i = 1, #args do args[i] = Val(args[i]) end
  log("V73 honor", Val(text), "| other args:", table.concat(args, " | "))
  local pattern = Pattern(COMBATLOG_HONORGAIN)
  log("V73 honor format COMBATLOG_HONORGAIN", Val(COMBATLOG_HONORGAIN))
  local victim, rank
  if pattern and type(text) == "string" then victim, rank = text:match(pattern) end
  log("V73 honor parsed: victim", Val(victim), "rank", Val(rank))
  if victim then
    result("V73", "pass", "victim and rank from the honor message")
  elseif not pattern then
    result("V73", "fail", "COMBATLOG_HONORGAIN missing")
  else
    result("V73", "fail", "honor message did not match: " .. S(text):sub(1, 80))
  end
  local seen = victim and seenByName[victim]
  if seen then
    log("V73 victim seen", string.format("%.0f s before", GetTime() - seen.at), "via", seen.source, "level",
      Val(seen.level), "class", Val(seen.class), "race", Val(seen.race), "rank", Val(seen.rank))
  else
    log("V73 victim not seen as target, mouseover or nameplate")
  end
  local _, instanceType = GetInstanceInfo()
  log("V76 at the kill: group", Vals(IsInGroup), "instance", Val(instanceType), "zone", Vals(GetRealZoneText))
  local grouped = IsInGroup and IsInGroup()
  if type(grouped) == "boolean" and type(instanceType) == "string" then
    result("V76", "pass", "group " .. S(grouped) .. ", instance " .. instanceType)
  else
    result("V76", "fail", "IsInGroup " .. Vals(IsInGroup) .. ", instance " .. Val(instanceType))
  end
  Counters("V73 counters (honor)")
end

-- Damage to the player and party kills from the combat log, when an addon may register it (V75, V81).
local function CombatLogEvent()
  local info = { pcall(CombatLogGetCurrentEventInfo) }
  if not info[1] then return end
  local subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName =
    info[3], info[5], info[6], info[7], info[9], info[10]
  if subevent == "PARTY_KILL" and sourceGUID == UnitGUID("player") then
    log("V75 PARTY_KILL", Val(destName), Val(destGUID), "GetPlayerInfoByGUID", Vals(GetPlayerInfoByGUID, destGUID))
  elseif destGUID == UnitGUID("player") and type(subevent) == "string" and subevent:match("_DAMAGE$") then
    lastDamage = { subevent = subevent, name = sourceName, guid = sourceGUID, flags = sourceFlags,
                   environment = info[13], at = GetTime() }
    if subevent == "ENVIRONMENTAL_DAMAGE" then log("V81 environmental damage", Val(info[13])) end
  end
end

local function Dead()
  if lastDamage and GetTime() - lastDamage.at < 10 then
    log("V75 killed by", Val(lastDamage.name), Val(lastDamage.guid), "flags", Val(lastDamage.flags), "via",
      lastDamage.subevent, "environment", Val(lastDamage.environment))
  else
    log("V75 killed by: no damage in the combat log (" .. S(combatLog) .. ")")
  end
  log("V81 death recap GetRecapEvents()", Vals(C_DeathRecap and C_DeathRecap.GetRecapEvents))
  if C_DeathRecap and C_DeathRecap.GetRecapEvents then
    local ok, events = pcall(C_DeathRecap.GetRecapEvents)
    if ok and type(events) == "table" then
      for i, e in ipairs(events) do DumpTable("V81 recap " .. i, e) end
    end
  end
  log("V79 total deaths GetStatistic(60)", Vals(GetStatistic, 60))
  local sources = {}
  if combatLog == "registered" then sources[#sources + 1] = "combat log" end
  if C_DeathRecap and C_DeathRecap.GetRecapEvents then sources[#sources + 1] = "death recap" end
  if mirrorSeen then sources[#sources + 1] = "mirror timers" end
  result("V81", #sources > 0 and "pass" or "fail", #sources > 0 and table.concat(sources, ", ") or "no cause source")
  lastDamage = nil
end

pvpFrame:SetScript("OnEvent", function(_, event, ...)
  if not ns.running() then return end
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    CombatLogEvent()
  elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
    Honor(...)
  elseif event == "PLAYER_PVP_KILLS_CHANGED" then
    Counters("V73 PLAYER_PVP_KILLS_CHANGED")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    LogUnit((...), "nameplate")
  elseif event == "PLAYER_TARGET_CHANGED" then
    LogUnit("target", "target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    LogUnit("mouseover", "mouseover")
  elseif event == "PLAYER_DEAD" then
    Dead()
  elseif event == "CHAT_MSG_SYSTEM" then
    local text = ...
    local me = GetUnitName and GetUnitName("player", true)
    if type(text) == "string" and type(me) == "string" and text:find(me, 1, true) then
      log("V80 system", text)
      for _, f in ipairs({ DUEL_WINNER_KNOCKOUT, DUEL_WINNER_RETREAT }) do
        local p = Pattern(f)
        local a, b
        if p then a, b = text:match(p) end
        if a and (a == me or b == me) then result("V80", "pass", "duel line parsed: " .. text) end
      end
    end
    if type(text) == "string" then Discovered(text) end
  elseif event == "CHAT_MSG_LOOT" or event == "PLAYER_MONEY" then
    local text = ...
    log("V83 " .. event, Val(text), "money", Vals(GetMoney))
    for _, key in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
      local p = Pattern(_G[key])
      if p and type(text) == "string" and text:match(p) then result("V83", "pass", key .. " matched: " .. text) end
    end
  elseif event == "LOOT_OPENED" then
    local fishing = IsFishingLoot and IsFishingLoot()
    log("V84 LOOT_OPENED fishing", Val(fishing), "items", Vals(GetNumLootItems))
    if fishing then result("V84", "pass", "IsFishingLoot true, " .. Vals(GetNumLootItems) .. " items") end
  elseif event == "TRADE_SHOW" then
    tradePartner, tradeGiven = UnitGUID and UnitGUID("NPC"), {}
    log("V85 TRADE_SHOW partner", Val(tradePartner))
  elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
    tradeGiven[#tradeGiven + 1] = Vals(GetTradePlayerItemLink, (...))
  elseif event == "UI_INFO_MESSAGE" then
    local _, text = ...
    if type(text) == "string" and ERR_TRADE_COMPLETE and text == ERR_TRADE_COMPLETE then
      log("V85 trade complete with", Val(tradePartner), "gave", table.concat(tradeGiven, ", "))
      if tradePartner then result("V85", "pass", "trade complete, partner GUID " .. Val(tradePartner)) end
      tradePartner = nil
    elseif type(text) == "string" then
      Discovered(text)
    end
  elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
    encounter = event == "ENCOUNTER_START"
    local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    local busy = IsEncounterInProgress and IsEncounterInProgress()
    log("V70 " .. event, "lockdown", Val(locked), "in progress", Val(busy))
    if encounter and (locked == true or busy == true) then
      result("V70", "pass", "in a boss fight: lockdown " .. Val(locked) .. ", in progress " .. Val(busy))
    elseif encounter then
      result("V70", "fail", "in a boss fight both false/missing: " .. Val(locked) .. ", " .. Val(busy))
    end
  else
    mirrorSeen = true
    local args = {}
    for i = 1, select("#", ...) do args[#args + 1] = Val((select(i, ...))) end
    log("V81 " .. event, table.concat(args, " | "))
  end
end)

local function PvpRegister()
  if pvpRegistered then return end
  pvpRegistered = true
  for _, event in ipairs(PVP_EVENTS) do
    if not pcall(pvpFrame.RegisterEvent, pvpFrame, event) then log("pvp: unknown event", event) end
  end
end

-- V75: may an addon register the combat log? Only from the checklist's button, never at login: on Retail 12.1.5
-- Blizzard blocks it with a popup ("only available to the Blizzard UI ... disable this addon"), even inside pcall.
local function CombatLogTest()
  log("== V75 COMBAT LOG (button) ==")
  local ok, err = pcall(pvpFrame.RegisterEvent, pvpFrame, "COMBAT_LOG_EVENT_UNFILTERED")
  combatLog = ok and "registered" or ("blocked: " .. S(err))
  log("V75 combat log:", combatLog)
  result("V75", ok and "pass" or "fail", combatLog .. " (no error here can still mean Blizzard's popup showed)")
end


-- ===== V77, V78 (CF-54) and V79-V83 (CF-52, CF-53): values to read once =====
local WATCH_ITEMS = { 12784, 12360, 14342, 15063, 15062, 19807, 19970, 19979 }
local RIDING_LINES = { 148, 149, 150, 152, 533, 553, 554, 713, 762 }

local function RealmTime()
  log("V77 region GetCurrentRegion()", Vals(GetCurrentRegion))
  local region = GetCurrentRegion and GetCurrentRegion()
  result("V77", type(region) == "number" and "pass" or "fail", "region " .. Val(region))
  local hour, minute
  if GetGameTime then hour, minute = GetGameTime() end
  local now = GetServerTime()
  if type(hour) ~= "number" then
    log("V78 realm time: GetGameTime missing")
    result("V78", "fail", "GetGameTime missing")
    return
  end
  local diff = (hour * 60 + minute) - math.floor(now / 60) % 1440
  if diff > 720 then diff = diff - 1440 elseif diff <= -720 then diff = diff + 1440 end
  local offset = math.floor(diff / 15 + 0.5) * 15
  log(string.format("V78 realm time GetGameTime %02d:%02d, server (UTC) %s, offset %+d min", hour, minute,
    date("!%H:%M", now), offset))
  local sane = math.abs(offset) <= 14 * 60 and math.abs(diff - offset) <= 5
  result("V78", sane and "pass" or "fail", string.format("realm %02d:%02d, offset %+d min", hour, minute, offset))
end

local function DataApis()
  local hk = GetPVPLifetimeStats and GetPVPLifetimeStats()
  result("V79", type(hk) == "number" and "pass" or "fail", "lifetime " .. Vals(GetPVPLifetimeStats)
    .. ", rank " .. Vals(UnitPVPRank, "player") .. ", deaths " .. Vals(GetStatistic, 60))
  log("V79 lifetime", Vals(GetPVPLifetimeStats), "| UnitPVPRank", Vals(UnitPVPRank, "player"),
    "| this week", Vals(GetPVPThisWeekStats), "| deaths GetStatistic(60)", Vals(GetStatistic, 60))
  local rank = UnitPVPRank and UnitPVPRank("player")
  log("V79 GetPVPRankInfo(rank, player)", rank and Vals(GetPVPRankInfo, rank, "player") or "missing")
  log("V80 DUEL_WINNER_KNOCKOUT", Val(DUEL_WINNER_KNOCKOUT), "| DUEL_WINNER_RETREAT", Val(DUEL_WINNER_RETREAT))
  log("V81 C_DeathRecap", C_DeathRecap and "exists" or "missing", "GetRecapEvents",
    Val(C_DeathRecap and C_DeathRecap.GetRecapEvents))
  for _, line in ipairs(RIDING_LINES) do
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    if fn then
      local ok, info = pcall(fn, line)
      if ok and type(info) == "table" and (info.skillLevel or 0) > 0 then DumpTable("V82 skill line " .. line, info) end
    end
  end
  log("V82 GetProfessionInfoBySkillLineID", Val(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID),
    "| IsSpellKnown 33388/33391", Vals(IsSpellKnown, 33388), Vals(IsSpellKnown, 33391), "| GetNumSkillLines",
    Vals(GetNumSkillLines), "| C_Timer.NewTicker", Val(C_Timer and C_Timer.NewTicker))
  local riding = {}
  for _, line in ipairs(RIDING_LINES) do
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    local ok, info
    if fn then ok, info = pcall(fn, line) end
    if ok and type(info) == "table" and (info.skillLevel or 0) > 0 then riding[#riding + 1] = "line " .. line end
  end
  if IsSpellKnown and (IsSpellKnown(33388) or IsSpellKnown(33391)) then riding[#riding + 1] = "spell" end
  if #riding > 0 then result("V82", "pass", "riding from " .. table.concat(riding, ", ")) end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() or 0 do log("V82 skill", i, Vals(GetSkillLineInfo, i)) end
  end
  log("V83 LOOT_ITEM_SELF", Val(LOOT_ITEM_SELF), "| _MULTIPLE", Val(LOOT_ITEM_SELF_MULTIPLE), "| PUSHED",
    Val(LOOT_ITEM_PUSHED_SELF), "| CREATED", Val(LOOT_ITEM_CREATED_SELF), "| GetMoney", Vals(GetMoney))
  for _, id in ipairs(WATCH_ITEMS) do
    log("V83 item", id, Vals(C_Item and C_Item.GetItemNameByID, id), "quality",
      Vals(C_Item and C_Item.GetItemQualityByID, id), "slot", Vals(C_Item and C_Item.GetItemInfoInstant, id))
  end
end

-- ===== Automatic: static checks once per login, event logging while running =====

function ns.running()
  return GetServerTime() < STOP_AT and not (FriendProbeDB and FriendProbeDB.stopped)
end

-- V63, V71, V55, V68 and the API presence hints for the manual items.
local function StaticChecks()
  local clock = date and date("%H:%M")
  result("V63", type(clock) == "string" and clock:match("^%d%d:%d%d$") and "pass" or "fail", "date: " .. S(clock))
  local t = time and time({ year = 2026, month = 11, day = 6, hour = 20, min = 30 })
  result("V71", type(t) == "number" and math.abs(t - GetServerTime()) < 400 * 86400 and "pass" or "fail",
    "time() " .. S(t) .. " next to server " .. S(GetServerTime()))
  result("V55", GameTooltip and GameTooltip.AddDoubleLine and "pass" or "fail", "GameTooltip.AddDoubleLine "
    .. S(GameTooltip and GameTooltip.AddDoubleLine ~= nil))
  local hints = {
    V65 = ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow ~= nil,
    V66 = Settings and Settings.RegisterCanvasLayoutCategory ~= nil,
    V72 = (ChatFrameUtil and ChatFrameUtil.OpenChat ~= nil) or ChatFrame_OpenChat ~= nil,
    V59 = JoinTemporaryChannel ~= nil,
  }
  for id, present in pairs(hints) do
    local r = ns.results()[id]
    if not (r and (r.status == "yes" or r.status == "no")) then
      result(id, "info", present and "the API is there; check it by eye" or "the API is missing")
    end
  end
end

local function Auto()
  FriendProbeDB = FriendProbeDB or {}
  if not ns.running() then return end
  log("== FriendProbe login", S(GetUnitName and GetUnitName("player", true)), "==")
  Section("CONTEXT", Context)
  Section("V8 COMMUNITIES", Clubs)
  Section("V52 COMMUNITY PRESENCE", CommunityPresence)
  Section("V77/V78 REGION AND REALM TIME", RealmTime)
  Section("V79-V83 DOOMSDAY DATA APIS", DataApis)
  Section("STATIC CHECKS", StaticChecks)
  FeedRegister()
  PvpRegister()
  -- V50b once a day: the self-whisper burst (silent).
  local today = date("%Y-%m-%d")
  if FriendProbeDB.burstDay ~= today then
    FriendProbeDB.burstDay = today
    C_Timer.After(20, function() Section("V50b COMMUNITY TRANSPORT", CommunityTransport) end)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then
    Auto()
    return
  end
  if name ~= "FriendProbe" then return end
  FriendProbeDB = FriendProbeDB or {}
  if FriendProbeDB.reloadBy then
    log("V68 reloaded by", FriendProbeDB.reloadBy)
    result("V68", "pass", "reloaded by " .. S(FriendProbeDB.reloadBy) .. " from a click")
    FriendProbeDB.reloadBy = nil
  end
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX) end
end)

-- The test buttons of the checklist window.
ns.tests = {
  { text = "Test: reload", run = function() ReloadButtons() end },
  { text = "Test: links and invites", run = function() Invite() end },
  { text = "Test: invite all", run = function() InviteAll() end },
  { text = "Test: file reload (V67)", run = function() ReloadFile() end },
  { text = "Test the combat log: Blizzard shows a warning", run = function() CombatLogTest() end },
}
ns.log = log

-- Every event handler runs guarded: a secret value or a missing API in an instance (Midnight, Retail dry runs) is
-- logged, never shown as a Lua error.
for _, frame in ipairs({ feedFrame, inviteFrame, commFrame, pvpFrame, loader }) do
  local handler = frame:GetScript("OnEvent")
  frame:SetScript("OnEvent", function(...)
    local ok, err = pcall(handler, ...)
    if not ok then log("handler error", S((select(2, ...))), S(err)) end
  end)
end

-- /fp opens the checklist. /fp whisper <name> (V51) and /fp stop are the only other commands.
SLASH_FRIENDPROBE1 = "/fp"
SlashCmdList.FRIENDPROBE = function(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "whisper" and arg ~= "" then
    SendAddon("V51 WHISPER " .. arg, "V51:whisper from " .. S(GetUnitName("player", true)), "WHISPER", arg)
  elseif cmd == "stop" then
    FriendProbeDB.stopped = true
    log("stopped by /fp stop")
  else
    ns.toggleWindow()
  end
end
