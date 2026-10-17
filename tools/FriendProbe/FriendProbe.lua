-- FriendProbe: verifies the APIs the friend roster addon depends on.
-- Commands:
--   /fp info            own character, name format, professions, API existence
--   /fp friends         all BNet friend game accounts (presence data)
--   /fp ping            BNSendGameData ping to same-project WoW friends (they auto-reply PONG)
--   /fp big [bytes]     send a large BNet payload to find the size limit (default 4000)
--   /fp whisper <name>  addon WHISPER ping to a character name (tests name format + mega-realm)
--   /fp clubs [clubId]  communities (C_Club): club types, clubIds, all member fields
--   /fp ticket <code>   C_Club.RequestTicket: look up an invite code or link (result via CLUB_TICKET_RECEIVED)
--   /fp redeem <code>   C_Club.RedeemTicket: join with an invite code or link (logs blocked/forbidden actions)
--   /fp talents         C_ClassTalents / C_Traits: config, trees, point pools, nodes with ranks spent
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
  log("== CLUBS ==")
  if not (C_Club and C_Club.GetSubscribedClubs) then log("C_Club missing") return end
  local clubs = C_Club.GetSubscribedClubs() or {}
  log("subscribed clubs:", #clubs)
  for _, club in ipairs(clubs) do
    if filter == "" or S(club.clubId) == filter then
      log("-- club", club.clubId, club.name, "type", CLUB_TYPES[club.clubType] or club.clubType)
      DumpTable("clubinfo", club)
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

-- Invite code from a code or a full invite link (last path segment).
local function TicketCode(text)
  return (text or ""):match("([%w]+)%/?%s*$")
end

local function Ticket(cmd, arg)
  local code = TicketCode(arg)
  if not code then log("usage: /fp " .. cmd .. " <invite code or link>") return end
  local fn = cmd == "ticket" and "RequestTicket" or "RedeemTicket"
  if not (C_Club and C_Club[fn]) then log("C_Club." .. fn, "does not exist") return end
  -- A protected function does not raise a Lua error; it fires ADDON_ACTION_BLOCKED/FORBIDDEN (logged).
  log("C_Club." .. fn, code, "->", pcall(C_Club[fn], code))
end

-- Spell name for a trait entry (definition -> spellID -> name); nil when unknown.
local function EntrySpellName(configID, entryID)
  if not (entryID and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then return nil end
  local entry = C_Traits.GetEntryInfo(configID, entryID)
  local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  local spellID = definition and (definition.spellID or definition.overriddenSpellID)
  if not spellID then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  return GetSpellInfo and (GetSpellInfo(spellID))
end

-- Logs how talents are stored: active config, trees, point pools, nodes with ranks spent.
local function Talents()
  log("== TALENTS ==")
  for _, name in ipairs({ "GetActiveConfigID", "GetConfigIDsBySpecID", "GetStarterBuildActive" }) do
    log("exists C_ClassTalents." .. name, C_ClassTalents and C_ClassTalents[name] ~= nil)
  end
  for _, name in ipairs({ "GetConfigInfo", "GetTreeInfo", "GetTreeNodes", "GetNodeInfo", "GetTreeCurrencyInfo",
      "GetEntryInfo", "GetDefinitionInfo" }) do
    log("exists C_Traits." .. name, C_Traits and C_Traits[name] ~= nil)
  end
  log("exists C_SpecializationInfo", C_SpecializationInfo ~= nil, "GetNumSpecializations", GetNumSpecializations ~= nil)
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then return end

  local configID = C_ClassTalents.GetActiveConfigID()
  log("activeConfigID", configID)
  if not configID then return end
  local info = C_Traits.GetConfigInfo(configID)
  DumpTable("configInfo", info)
  for _, treeID in ipairs(info and info.treeIDs or {}) do
    log("-- tree", treeID)
    if C_Traits.GetTreeInfo then DumpTable("treeInfo", C_Traits.GetTreeInfo(configID, treeID)) end
    if C_Traits.GetTreeCurrencyInfo then
      for i, currency in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
        DumpTable("currency" .. i, currency)
      end
    end
    local nodes = C_Traits.GetTreeNodes(treeID) or {}
    local spent, shown = 0, 0
    log("nodes in tree", #nodes)
    for _, nodeID in ipairs(nodes) do
      local node = C_Traits.GetNodeInfo(configID, nodeID)
      if node and (node.ranksPurchased or 0) > 0 then
        spent = spent + node.ranksPurchased
        shown = shown + 1
        local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
        log("node", nodeID, "ranks", node.ranksPurchased, "/", node.maxRanks, "pos", node.posX, node.posY,
          "subTree", node.subTreeID, "groups", node.groupIDs and table.concat(node.groupIDs, ",") or "-",
          "spell", EntrySpellName(configID, entryID))
        if shown == 1 then DumpTable("firstNodeInfo", node) end
      end
    end
    log("ranks spent in tree", treeID, "=", spent)
  end
end

local clubUpdateSeen = {}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BN_CHAT_MSG_ADDON")
for _, event in ipairs({ "CLUB_MEMBERS_UPDATED", "CLUB_TICKET_RECEIVED", "CLUB_ADDED", "CLUB_ERROR",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
  pcall(f.RegisterEvent, f, event) -- names unverified on Forever: ignore unknown ones
end
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == "FriendProbe" then
      FriendProbeDB = FriendProbeDB or {}
      log("loaded; register prefix:", C_ChatInfo.RegisterAddonMessagePrefix(PREFIX))
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
  elseif event == "CLUB_TICKET_RECEIVED" or event == "CLUB_ADDED" or event == "CLUB_ERROR"
      or event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local args = { ... }
    log(event, unpack(args, 1, select("#", ...)))
    for _, value in ipairs(args) do
      if type(value) == "table" then DumpTable(event, value) end
    end
  elseif event == "CLUB_MEMBERS_UPDATED" then
    local clubId = S(...)
    if not clubUpdateSeen[clubId] then
      clubUpdateSeen[clubId] = true
      log("member data arrived for club", clubId, "(run /fp clubs again)")
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
  elseif cmd == "clubs" then Clubs(arg)
  elseif cmd == "ticket" or cmd == "redeem" then Ticket(cmd, arg)
  elseif cmd == "talents" then
    local ok, err = pcall(Talents)
    if not ok then log("talents error", err) end
  elseif cmd == "clear" then
    FriendProbeDB.log = {}
    print("|cff33ff99FP|r log cleared")
  else
    print("|cff33ff99FP|r /fp info | friends | ping | big [bytes] | whisper <name> | clubs [clubId] | ticket <code> | redeem <code> | talents | clear")
  end
end
