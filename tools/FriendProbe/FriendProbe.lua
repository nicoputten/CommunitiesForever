-- FriendProbe: verifies the APIs the friend roster addon depends on.
-- Commands:
--   /fp info            own character, name format, professions, API existence
--   /fp friends         all BNet friend game accounts (presence data)
--   /fp ping            BNSendGameData ping to same-project WoW friends (they auto-reply PONG)
--   /fp big [bytes]     send a large BNet payload to find the size limit (default 4000)
--   /fp whisper <name>  addon WHISPER ping to a character name (tests name format + mega-realm)
--   /fp communities [id] communities (C_Club): types, ids, all member fields (alias: /fp clubs)
--   /fp clear           wipe the saved log

local PREFIX = "FProbe"
local MAX_LOG = 3000
local MAX_MEMBERS = 50

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
  print("|cff33ff99FP|r " .. line)
  local l = FriendProbeDB.log
  l[#l + 1] = date("%H:%M:%S ") .. line
  while #l > MAX_LOG do table.remove(l, 1) end
end

local function ForEachGameAccount(cb)
  for i = 1, BNGetNumFriends() do
    local acc = C_BattleNet.GetFriendAccountInfo(i)
    if acc then
      for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
        local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if ga then cb(acc, ga) end
      end
    end
  end
end

local function Info()
  log("== INFO ==")
  log("build", GetBuildInfo())
  log("WOW_PROJECT_ID", WOW_PROJECT_ID)
  log("UnitName", UnitName("player"))
  log("UnitFullName", UnitFullName("player"))
  log("GetUnitName(true)", GetUnitName("player", true))
  log("realm", GetRealmName(), GetNormalizedRealmName())
  log("GUID", UnitGUID("player"))
  log("class/level/faction", UnitClassBase("player"), UnitLevel("player"), UnitFactionGroup("player"))
  log("BNGetInfo", BNGetInfo())

  for _, fn in ipairs({ "BNSendGameData", "BNGetNumFriends", "GetProfessions",
      "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo" }) do
    log("exists", fn, _G[fn] ~= nil)
  end
  log("exists C_BattleNet.GetFriendAccountInfo", C_BattleNet and C_BattleNet.GetFriendAccountInfo ~= nil)
  log("exists C_ChatInfo.SendAddonMessage", C_ChatInfo and C_ChatInfo.SendAddonMessage ~= nil)

  -- Mainline slots: prof1, prof2, archaeology, fishing, cooking (holes possible)
  local p = { GetProfessions() }
  for k = 1, 5 do
    if p[k] then log("prof slot", k, GetProfessionInfo(p[k])) else log("prof slot", k, "empty") end
  end
  -- Classic-style skill list, if it exists, to catch professions outside the 5 slots
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do log("skillline", i, GetSkillLineInfo(i)) end
  end
end

local function Friends()
  log("== FRIENDS ==")
  ForEachGameAccount(function(acc, ga)
    log(acc.battleTag, ga.clientProgram, "proj", ga.wowProjectID, "online", ga.isOnline,
      "char", ga.characterName, "realm", ga.realmName, ga.realmDisplayName,
      "class", ga.className, "lvl", ga.characterLevel, "fac", ga.factionName,
      "guid", ga.playerGuid, "gaID", ga.gameAccountID)
  end)
end

local function SendBN(text)
  local n = 0
  ForEachGameAccount(function(acc, ga)
    if ga.clientProgram == BNET_CLIENT_WOW and ga.wowProjectID == WOW_PROJECT_ID and ga.gameAccountID then
      local ok, err = pcall(BNSendGameData, ga.gameAccountID, PREFIX, text)
      log("BN send ->", acc.battleTag, ga.characterName, "len", #text, ok and "ok" or ("ERR " .. S(err)))
      n = n + 1
    end
  end)
  if n == 0 then log("no same-project WoW friends online") end
end

-- Dumps every field so we see exactly what Forever returns, not what we expect
local function DumpTable(label, t)
  if type(t) ~= "table" then log(label, t) return end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return S(a) < S(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = S(k) .. "=" .. S(t[k]) end
  log(label, table.concat(parts, " "))
end

local CLUB_TYPES = {}
if Enum and Enum.ClubType then
  for k, v in pairs(Enum.ClubType) do CLUB_TYPES[v] = k end
end

local function Clubs(filter)
  log("== COMMUNITIES ==")
  if not (C_Club and C_Club.GetSubscribedClubs) then log("C_Club missing") return end
  local clubs = C_Club.GetSubscribedClubs() or {}
  log("subscribed communities:", #clubs)
  for _, club in ipairs(clubs) do
    if filter == "" or S(club.clubId) == filter then
      log("-- community", club.name, "id", club.clubId, "type", CLUB_TYPES[club.clubType] or club.clubType)
      DumpTable("communityinfo", club)
      -- Member data loads async; this asks the client to fetch it
      if C_Club.FocusMembers then pcall(C_Club.FocusMembers, club.clubId) end
      local ids = C_Club.GetClubMembers(club.clubId) or {}
      log("members:", #ids)
      for i = 1, math.min(#ids, MAX_MEMBERS) do
        DumpTable("member", C_Club.GetMemberInfo(club.clubId, ids[i]))
      end
      if #ids > MAX_MEMBERS then log("... truncated", #ids - MAX_MEMBERS) end
    end
  end
end

local clubUpdateSeen = {}

-- "Name (id)" from the subscribed list; the id alone if the name is unknown.
local function CommunityName(clubId)
  if C_Club and C_Club.GetSubscribedClubs then
    for _, club in ipairs(C_Club.GetSubscribedClubs() or {}) do
      if S(club.clubId) == clubId then return S(club.name) .. " (" .. clubId .. ")" end
    end
  end
  return clubId
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BN_CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_ADDON")
pcall(f.RegisterEvent, f, "CLUB_MEMBERS_UPDATED")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == "FriendProbe" then
      FriendProbeDB = FriendProbeDB or {}
      local result = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
      log("loaded; message prefix", PREFIX, result == 0 and "registered" or ("NOT registered, result " .. S(result)))
    end
  elseif event == "BN_CHAT_MSG_ADDON" then
    local prefix, text, channel, senderID = ...
    if prefix ~= PREFIX then return end
    local info = C_BattleNet.GetGameAccountInfoByID(senderID)
    log("BN recv <-", info and info.characterName, "ch", channel, "len", #text, text:sub(1, 24))
    if text:sub(1, 4) == "PING" then
      pcall(BNSendGameData, senderID, PREFIX, "PONG from " .. S(UnitName("player")))
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = ...
    if prefix ~= PREFIX then return end
    log("addon recv <-", sender, "ch", channel, "len", #text, text:sub(1, 24))
    if text == "WPING" then
      log("whisper reply result:", C_ChatInfo.SendAddonMessage(PREFIX, "WPONG", "WHISPER", sender))
    end
  elseif event == "CLUB_MEMBERS_UPDATED" then
    local clubId = S(...)
    if not clubUpdateSeen[clubId] then
      clubUpdateSeen[clubId] = true
      log("member data arrived for community", CommunityName(clubId), "(run /fp communities again)")
    end
  end
end)

SLASH_FRIENDPROBE1 = "/fp"
SlashCmdList.FRIENDPROBE = function(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "info" then Info()
  elseif cmd == "friends" then Friends()
  elseif cmd == "ping" then SendBN("PING " .. S(UnitName("player")))
  elseif cmd == "big" then
    local size = tonumber(arg) or 4000
    SendBN("BIG" .. string.rep("x", size - 3))
  elseif cmd == "whisper" and arg ~= "" then
    log("whisper send result:", C_ChatInfo.SendAddonMessage(PREFIX, "WPING", "WHISPER", arg))
  elseif cmd == "communities" or cmd == "clubs" then Clubs(arg)
  elseif cmd == "clear" then
    FriendProbeDB.log = {}
    print("|cff33ff99FP|r log cleared")
  else
    print("|cff33ff99FP|r /fp info | friends | ping | big [bytes] | whisper <name> | communities [id] | clear")
  end
end
