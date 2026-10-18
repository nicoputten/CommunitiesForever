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
--   /fp quests          quest log API: functions, events, log size, every entry (CF-19)
--   /fp calendar        C_Calendar: functions, enums, events this month and next (dungeon planner)
--   /fp calendar create button: try to create a community sign-up test event (/fp calendar player: private)
--   /fp feed [off]      log instance, boss, group, battleground, death, level, quest and skill events
--   /fp chat           community chat: functions, channel name and index, which chat windows show it
--   /fp chat watch     log community messages (CLUB_MESSAGE_ADDED, CHAT_MSG_COMMUNITIES_CHANNEL)
--   /fp chat color|tab|flash  button: color the channel orange / open a community-only tab / flash + sound
--   /fp talents [all]   specializations + C_ClassTalents / C_Traits: config, trees, point pools, nodes
--                       with ranks spent (all: every node of the tree)
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

-- Logs how talents are stored: active config, trees, point pools, nodes (all with showAll, else
-- only nodes with ranks spent), then the specialization API (does Forever map its Vanilla trees?).
local function Talents(showAll)
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
      if node and (showAll or (node.ranksPurchased or 0) > 0) then
        spent = spent + (node.ranksPurchased or 0)
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

-- Logs every return value of fn(...) guarded, under label.
local function LogCall(label, fn, ...)
  if not fn then log(label, "does not exist") return end
  local results = { pcall(fn, ...) }
  if not results[1] then log(label, "error", results[2]) return end
  log(label, "->", unpack(results, 2, table.maxn(results)))
end

local function Specializations()
  log("== SPECIALIZATIONS ==")
  local cs = C_SpecializationInfo
  if cs then
    local names = {}
    for name, value in pairs(cs) do
      if type(value) == "function" then names[#names + 1] = name end
    end
    table.sort(names)
    log("C_SpecializationInfo functions:", table.concat(names, ", "))
  end
  LogCall("GetNumSpecializations()", GetNumSpecializations)
  LogCall("C_SpecializationInfo.GetSpecialization()", cs and cs.GetSpecialization)
  local count = GetNumSpecializations and GetNumSpecializations() or 0
  for i = 1, math.max(count, 3) do
    LogCall("C_SpecializationInfo.GetSpecializationInfo(" .. i .. ")", cs and cs.GetSpecializationInfo, i)
    LogCall("GetSpecializationInfo(" .. i .. ")", GetSpecializationInfo, i)
    LogCall("GetSpecializationRole(" .. i .. ")", GetSpecializationRole, i)
  end
  local _, _, classID = UnitClass("player")
  for i = 1, 4 do
    LogCall("GetSpecializationInfoForClassID(" .. tostring(classID) .. ", " .. i .. ")",
      GetSpecializationInfoForClassID, classID, i)
  end
end

-- Shows candidate icons for shared dungeon quests (CF-19, V32) in chat, numbered, so one can be picked.
-- Atlases are checked with C_Texture.GetAtlasInfo; file textures have no existence check (blank = missing).
local ICON_ATLASES = {
  "Dungeon", "Raid", "questlog-questtypeicon-dungeon", "questlog-questtypeicon-raid",
  "questlog-questtypeicon-group", "worldquest-icon-dungeon", "QuestNormal", "QuestDaily",
  "PetJournal-FavoritesIcon", "auctionhouse-icon-favorite", "socialqueuing-icon-group",
}
local ICON_FILES = {
  "Interface\\Icons\\INV_ValentinesCard01", "Interface\\Icons\\INV_ValentinesCandy",
  "Interface\\Icons\\INV_Misc_Gem_Ruby_02", "Interface\\Icons\\INV_Misc_Key_14",
  "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2",
  "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4",
  "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6",
  "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7",
}

local function Icons()
  log("== ICONS == (number, icon, name; atlas: exists)")
  local n = 0
  local hasCheck = C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil
  log("exists C_Texture.GetAtlasInfo", hasCheck)
  for _, name in ipairs(ICON_ATLASES) do
    n = n + 1
    local exists = hasCheck and C_Texture.GetAtlasInfo(name) ~= nil
    log(string.format("#%d |A:%s:16:16|a atlas %s: %s", n, name, name, S(exists)))
  end
  for _, path in ipairs(ICON_FILES) do
    n = n + 1
    log(string.format("#%d |T%s:16:16|t file %s", n, path, path))
  end
end

-- Logs the quest log API (CF-19): which functions and events exist, the log size, and every entry.
local function Quests()
  log("== QUESTS ==")
  local q = C_QuestLog
  for _, name in ipairs({ "GetNumQuestLogEntries", "GetInfo", "GetQuestIDForLogIndex", "GetTitleForQuestID",
      "GetMaxNumQuestsCanAccept", "IsComplete", "GetQuestObjectives",
      "GetLogIndexForQuestID", "IsOnQuest" }) do
    log("exists C_QuestLog." .. name, q ~= nil and q[name] ~= nil)
  end
  log("exists GetQuestLogTitle", GetQuestLogTitle ~= nil, "GetNumQuestLogEntries", GetNumQuestLogEntries ~= nil)
  for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
      "QUEST_COMPLETE", "UNIT_QUEST_LOG_CHANGED" }) do
    log("event", event, C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(event))
  end
  if not q then return end
  if q.GetMaxNumQuestsCanAccept then log("max quests", q.GetMaxNumQuestsCanAccept()) end
  if not (q.GetNumQuestLogEntries and q.GetInfo) then return end

  local entries, quests = q.GetNumQuestLogEntries()
  log("GetNumQuestLogEntries ->", entries, quests)
  local dumpedHeader, dumpedQuest = false, false
  for i = 1, entries or 0 do
    local info = q.GetInfo(i)
    if info then
      log("entry", i, "questID", info.questID, "header", info.isHeader, "title", info.title, "level", info.level,
        "hidden", info.isHidden, "task", info.isTask, "complete", q.IsComplete and info.questID and
        q.IsComplete(info.questID))
      -- Full field list once for a header and once for a quest.
      if info.isHeader and not dumpedHeader then
        dumpedHeader = true
        DumpTable("headerInfo", info)
      elseif not info.isHeader and not dumpedQuest then
        dumpedQuest = true
        DumpTable("questInfo", info)
      end
    end
  end
end

-- ===== Calendar (dungeon planner) =====
-- Function and event names are unverified on Forever: every one is checked or registered guarded.
local CALENDAR_FUNCS = { "OpenCalendar", "GetMonthInfo", "GetNumDayEvents", "GetDayEvent", "OpenEvent",
  "GetEventInfo", "CloseEvent", "CanAddEvent", "CreatePlayerEvent", "CreateCommunitySignUpEvent",
  "CreateGuildSignUpEvent", "EventSetTitle", "EventSetDescription", "EventSetDate", "EventSetTime",
  "EventSetType", "EventSetClubId", "AddEvent", "EventSignUp", "GetNumInvites", "EventGetInvite",
  "GetMinDate", "GetMaxCreateDate" }
local CALENDAR_EVENTS = { "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_NEW_EVENT", "CALENDAR_ACTION_PENDING",
  "CALENDAR_UPDATE_ERROR", "CALENDAR_OPEN_EVENT", "CALENDAR_UPDATE_EVENT", "CALENDAR_UPDATE_INVITE_LIST" }

local calendarListWanted = false

-- Every calendar event this month and next (the list arrives after OpenCalendar, async).
local function CalendarList()
  local cal = C_Calendar
  if not (cal and cal.GetNumDayEvents and cal.GetDayEvent) then log("calendar list API missing") return end
  local dumped = false
  for offset = 0, 1 do
    local month = cal.GetMonthInfo and cal.GetMonthInfo(offset)
    if offset == 0 then DumpTable("monthInfo", month) end
    for day = 1, (month and month.numDays) or 31 do
      for i = 1, cal.GetNumDayEvents(offset, day) or 0 do
        local e = cal.GetDayEvent(offset, day, i)
        if e then
          log(string.format("event month+%d day %d: %s", offset, day, S(e.title)), "calendarType", e.calendarType,
            "eventType", e.eventType, "clubID", e.clubID, "invitedBy", e.invitedBy, "inviteStatus", e.inviteStatus)
          if e.startTime then DumpTable("  startTime", e.startTime) end
          if not dumped then dumped = true DumpTable("  dayEvent", e) end
        end
      end
    end
  end
  log("calendar list done")
end

local function Calendar()
  log("== CALENDAR ==")
  log("exists C_Calendar", C_Calendar ~= nil)
  if not C_Calendar then return end
  for _, name in ipairs(CALENDAR_FUNCS) do log("exists C_Calendar." .. name, C_Calendar[name] ~= nil) end
  if Enum and Enum.CalendarEventType then DumpTable("Enum.CalendarEventType", Enum.CalendarEventType) end
  if Enum and Enum.CalendarType then DumpTable("Enum.CalendarType", Enum.CalendarType) end
  LogCall("GetCurrentCalendarTime", C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
  calendarListWanted = true
  LogCall("OpenCalendar", C_Calendar.OpenCalendar) -- the list follows on CALENDAR_UPDATE_EVENT_LIST
end

local function FirstCharacterCommunity()
  for _, club in ipairs(C_Club and C_Club.GetSubscribedClubs and C_Club.GetSubscribedClubs() or {}) do
    if Enum and Enum.ClubType and club.clubType == Enum.ClubType.Character then return club.clubId, club.name end
  end
end

-- Tries to create a test event tomorrow 20:00 ("community": sign-up event in the first character community,
-- "player": a private event). Runs from a button click, since creating may need a hardware event.
local function CalendarCreate(kind)
  log("== CALENDAR CREATE ==", kind)
  local cal = C_Calendar
  if not cal then log("C_Calendar missing") return end
  local clubId, clubName = FirstCharacterCommunity()
  if kind == "community" then
    log("community", clubName, clubId)
    LogCall("CreateCommunitySignUpEvent", cal.CreateCommunitySignUpEvent)
  else
    LogCall("CreatePlayerEvent", cal.CreatePlayerEvent)
  end
  LogCall("EventSetTitle", cal.EventSetTitle, "FriendProbe test (delete me)")
  LogCall("EventSetDescription", cal.EventSetDescription, "Test event from FriendProbe. Safe to delete.")
  if Enum and Enum.CalendarEventType and Enum.CalendarEventType.Dungeon then
    LogCall("EventSetType", cal.EventSetType, Enum.CalendarEventType.Dungeon)
  end
  local tomorrow = date("*t", time() + 86400)
  LogCall("EventSetDate", cal.EventSetDate, tomorrow.month, tomorrow.day, tomorrow.year)
  LogCall("EventSetTime", cal.EventSetTime, 20, 0)
  if kind == "community" and clubId then LogCall("EventSetClubId", cal.EventSetClubId, clubId) end
  LogCall("CanAddEvent", cal.CanAddEvent)
  LogCall("AddEvent", cal.AddEvent)
  log("done; check the calendar, then /fp calendar to see if the event is listed")
end

local calendarButton
local function CalendarButton(kind)
  if not calendarButton then
    calendarButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    calendarButton:SetSize(320, 28)
    calendarButton:SetPoint("CENTER", 0, 120)
  end
  calendarButton:SetText("FriendProbe: create " .. kind .. " test event")
  calendarButton:SetScript("OnClick", function(self)
    self:Hide()
    local ok, err = pcall(CalendarCreate, kind)
    if not ok then log("calendar create error", err) end
  end)
  calendarButton:Show()
  log("click the button in the middle of the screen to create a " .. kind .. " test event")
end

-- ===== Activity feed events =====
-- /fp feed on: logs every event the activity feed could use (also after /reload) until /fp feed off.
local FEED_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END",
  "BOSS_KILL", "GROUP_ROSTER_UPDATE", "UPDATE_BATTLEFIELD_STATUS", "PVP_MATCH_ACTIVE", "PVP_MATCH_COMPLETE",
  "PLAYER_DEAD", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "CHAT_MSG_SKILL", "SKILL_LINES_CHANGED" }

local function LogInstance()
  if GetInstanceInfo then
    local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
    log("  instance", name, "type", instanceType, "difficulty", difficultyID, difficultyName, "max", maxPlayers,
      "id", instanceID)
  else
    log("  GetInstanceInfo missing")
  end
  log("  zone", GetRealZoneText and GetRealZoneText(), "subzone", GetSubZoneText and GetSubZoneText())
  LogCall("  IsInInstance", IsInInstance)
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
    local ok = pcall(feedFrame.RegisterEvent, feedFrame, event)
    log("feed register", event, ok and "ok" or "UNKNOWN EVENT")
  end
end

feedFrame:SetScript("OnEvent", function(_, event, ...)
  if not (FriendProbeDB and FriendProbeDB.feed) then return end
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
  elseif event == "PVP_MATCH_COMPLETE" then
    LogCall("  GetBattlefieldWinner", GetBattlefieldWinner)
    LogCall("  UnitFactionGroup", UnitFactionGroup, "player")
  end
end)

local function Feed(arg)
  FriendProbeDB = FriendProbeDB or {}
  if arg == "off" then
    FriendProbeDB.feed = nil
    log("feed logging off")
    return
  end
  FriendProbeDB.feed = true
  FeedRegister()
  log("feed logging on (stays on after /reload; /fp feed off stops it)")
  LogInstance()
  LogGroup()
end

-- ===== Community chat (CF-25) =====
-- Function names are unverified on Forever: existence is logged, every call is guarded.
local CHAT_FUNCS = { "FCF_OpenNewWindow", "FCF_StartAlertFlash", "FCF_SetWindowName", "ChatFrame_AddChannel",
  "ChatFrame_RemoveAllMessageGroups", "ChatFrame_RemoveChannel", "ChatFrame_AddMessageEventFilter",
  "ChangeChatColor", "GetChannelList", "GetChannelName", "GetChatWindowInfo", "GetChatWindowChannels",
  "Chat_GetCommunitiesChannelName", "Chat_GetCommunitiesChannel", "PlaySound", "issecretvalue" }
local CHAT_EVENTS = { "CLUB_MESSAGE_ADDED", "CHAT_MSG_COMMUNITIES_CHANNEL" }

local chatWatching = false

-- The community channel name ("Community:<clubId>:<streamId>") and channel index of the first
-- character community's general stream.
local function CommunityChannel()
  local clubId, clubName = FirstCharacterCommunity()
  if not clubId then log("no character community") return end
  local streams = C_Club.GetStreams and C_Club.GetStreams(clubId) or {}
  local stream = streams[1]
  for _, s in ipairs(streams) do
    DumpTable("stream", s)
    if Enum and Enum.ClubStreamType and s.streamType == Enum.ClubStreamType.General then stream = s end
  end
  if not stream then log("no stream for", clubName) return end
  local name = Chat_GetCommunitiesChannelName and Chat_GetCommunitiesChannelName(clubId, stream.streamId)
  local index = name and GetChannelName and GetChannelName(name)
  log("community", clubName, clubId, "stream", stream.streamId, "channel name", name, "index", index)
  return name, index, clubId, stream.streamId
end

local function ChatInfo()
  log("== CHAT ==")
  for _, fn in ipairs(CHAT_FUNCS) do log("exists " .. fn, _G[fn] ~= nil) end
  log("NUM_CHAT_WINDOWS", NUM_CHAT_WINDOWS, "SOUNDKIT.TELL_MESSAGE", SOUNDKIT and SOUNDKIT.TELL_MESSAGE)
  LogCall("GetChannelList", GetChannelList)
  local name = CommunityChannel()
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local windowName, _, _, _, _, _, shown = GetChatWindowInfo and GetChatWindowInfo(i)
    if windowName and windowName ~= "" then
      local channels = { GetChatWindowChannels and GetChatWindowChannels(i) }
      local has = false
      for _, c in ipairs(channels) do if c == name then has = true end end
      log("chat window", i, windowName, "shown", shown, "has community channel", has, "channels",
        table.concat((function() local t = {} for _, c in ipairs(channels) do t[#t + 1] = S(c) end return t end)(), ","))
    end
  end
  local info = ChatTypeInfo and ChatTypeInfo["COMMUNITIES_CHANNEL"]
  if info then DumpTable("ChatTypeInfo.COMMUNITIES_CHANNEL", info) end
end

-- Test actions, each from a button click (may need a hardware event).
local function ChatAction(action)
  log("== CHAT " .. action .. " ==")
  local name, index = CommunityChannel()
  if action == "color" then
    LogCall("ChangeChatColor CHANNEL" .. S(index), ChangeChatColor, "CHANNEL" .. S(index), 1, 0.5, 0)
    log("send a community message: is it orange now?")
  elseif action == "tab" then
    local ok, frame = pcall(FCF_OpenNewWindow, "FP Community")
    log("FCF_OpenNewWindow", ok, frame and frame.GetName and frame:GetName() or frame)
    if ok and frame then
      LogCall("ChatFrame_RemoveAllMessageGroups", ChatFrame_RemoveAllMessageGroups, frame)
      LogCall("ChatFrame_AddChannel", ChatFrame_AddChannel, frame, name)
      log("a tab FP Community should show only the community chat now; close it with right click -> Close")
    end
  elseif action == "flash" then
    for i = 1, NUM_CHAT_WINDOWS or 10 do
      local frame = _G["ChatFrame" .. i]
      local channels = { GetChatWindowChannels and GetChatWindowChannels(i) }
      for _, c in ipairs(channels) do
        if c == name and frame then LogCall("FCF_StartAlertFlash ChatFrame" .. i, FCF_StartAlertFlash, frame) end
      end
    end
    LogCall("PlaySound TELL_MESSAGE", PlaySound, SOUNDKIT and SOUNDKIT.TELL_MESSAGE)
  end
end

local chatButton
local function ChatButton(action)
  if not chatButton then
    chatButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    chatButton:SetSize(320, 28)
    chatButton:SetPoint("CENTER", 0, 80)
  end
  chatButton:SetText("FriendProbe: chat " .. action)
  chatButton:SetScript("OnClick", function(self)
    self:Hide()
    local ok, err = pcall(ChatAction, action)
    if not ok then log("chat " .. action .. " error", err) end
  end)
  chatButton:Show()
  log("click the button in the middle of the screen: chat " .. action)
end

-- Logs incoming community messages; whether their text is readable (secret values under Midnight).
local chatFrame = CreateFrame("Frame")
chatFrame:SetScript("OnEvent", function(_, event, ...)
  if not chatWatching then return end
  local args = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    local secret = issecretvalue and issecretvalue(v)
    args[#args + 1] = secret and "<secret>" or S(v)
  end
  log("CHAT " .. event, table.concat(args, " | "))
end)

local function ChatWatch(on)
  chatWatching = on
  if on then
    for _, event in ipairs(CHAT_EVENTS) do
      log("chat register", event, pcall(chatFrame.RegisterEvent, chatFrame, event) and "ok" or "UNKNOWN EVENT")
    end
  end
  log("chat watch", on and "on (until /reload or /fp chat unwatch)" or "off")
end

local clubUpdateSeen = {}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BN_CHAT_MSG_ADDON")
for _, event in ipairs({ "CLUB_MEMBERS_UPDATED", "CLUB_TICKET_RECEIVED", "CLUB_ADDED", "CLUB_ERROR",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
  pcall(f.RegisterEvent, f, event) -- names unverified on Forever: ignore unknown ones
end
for _, event in ipairs(CALENDAR_EVENTS) do pcall(f.RegisterEvent, f, event) end
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == "FriendProbe" then
      FriendProbeDB = FriendProbeDB or {}
      if FriendProbeDB.feed then FeedRegister() end
      log("loaded; register prefix:", C_ChatInfo.RegisterAddonMessagePrefix(PREFIX))
    end
  elseif event:sub(1, 9) == "CALENDAR_" then
    local args = {}
    for i = 1, select("#", ...) do args[#args + 1] = S((select(i, ...))) end
    log("calendar event", event, table.concat(args, " | "))
    if event == "CALENDAR_UPDATE_EVENT_LIST" and calendarListWanted then
      calendarListWanted = false
      local ok, err = pcall(CalendarList)
      if not ok then log("calendar list error", err) end
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
  elseif cmd == "quests" then
    local ok, err = pcall(Quests)
    if not ok then log("quests error", err) end
  elseif cmd == "calendar" then
    if arg == "create" or arg == "player" then
      CalendarButton(arg == "create" and "community" or "player")
    else
      local ok, err = pcall(Calendar)
      if not ok then log("calendar error", err) end
    end
  elseif cmd == "feed" then
    Feed(arg)
  elseif cmd == "chat" then
    if arg == "color" or arg == "tab" or arg == "flash" then
      ChatButton(arg)
    elseif arg == "watch" or arg == "unwatch" then
      ChatWatch(arg == "watch")
    else
      local ok, err = pcall(ChatInfo)
      if not ok then log("chat error", err) end
    end
  elseif cmd == "icons" then
    local ok, err = pcall(Icons)
    if not ok then log("icons error", err) end
  elseif cmd == "talents" then
    local okSpecs, errSpecs = pcall(Specializations)
    if not okSpecs then log("specializations error", errSpecs) end
    local ok, err = pcall(Talents, arg == "all")
    if not ok then log("talents error", err) end
  elseif cmd == "clear" then
    FriendProbeDB.log = {}
    print("|cff33ff99FP|r log cleared")
  else
    print("|cff33ff99FP|r /fp info | friends | ping | big [bytes] | whisper <name> | clubs [clubId] | ticket <code> | redeem <code> | talents [all] | quests | icons | calendar [create|player] | feed [off] | chat [watch|unwatch|color|tab|flash] | clear")
  end
end
