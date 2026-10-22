-- FriendProbe: checks the open API questions in VERIFY.md in-game (Claude Code cannot run WoW).
-- Commands:
--   /fp start       clear the log, then run every check below and switch on feed logging
--   /fp invite      chat links per friend online in Forever: test link, request invite, invite by name,
--                   invite via Battle.net (V47 link clicks, V48 invites; CF-27). Needs a friend online.
--   /fp menu        right-click menu test window (V57, CF-37): Blizzard context menu, whisper, copy box,
--                   right-click on an AceGUI tree row
--   /fp feed off    stop feed logging (V35)
--   /fp clear       wipe the saved log
-- Checks (by VERIFY.md number):
--   context  build, character, addons (CommunitiesForever, Questie, QuestieDB)
--   V8       community IDs, to compare between two clients
--   V30      talents: per tree the nodes with points (position and spell), for another class than Warrior
--   V41      chat windows: every GetChatWindowInfo return (a closed tab: shown and docked off?)
--   V46      dungeons the client knows: Group Finder (C_LFGList) activities with level ranges, and the old
--            Dungeon Finder list (GetLFGDungeonInfo) beyond the Vanilla entries
--   V35      feed logging: instance, boss, group and battleground events (stays on after /reload)
--   V49      addon message in the community channel (does it arrive, also back at yourself?)
--   V50      whisper addon messages to yourself: size limit (200, 255, 256 bytes) and a burst of 30
--   V52      community member presence (run after a member logged out: still online?)
--   V57      which menu, whisper and invite functions exist (the clicks need /fp menu)
--   /fp comm whisper <name>  addon whisper to a character (V51: a character of the other faction)
--   /fp comm channel         one addon message in the community channel (V49: run on two clients)
--   /fp comm summary         what came back so far
-- Already answered checks were removed; see docs/API-FINDINGS.md and the git history for the old probes.
-- The log is saved in FriendProbeDB (WTF\Account\<account>\SavedVariables\FriendProbe.lua) on /reload or logout.

local MAX_LOG = 3000
local LFG_MAX_ID = 3000

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

-- ===== V30: talents per tree =====
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

-- Nodes with points spent, left to right (posX), with their spell: shows which tree each point is in.
local function Talents()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then log("talent API missing") return end
  local configID = C_ClassTalents.GetActiveConfigID()
  local info = configID and C_Traits.GetConfigInfo(configID)
  log("class", UnitClassBase("player"), "activeConfigID", S(configID))
  for _, treeID in ipairs(info and info.treeIDs or {}) do
    local spent = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local node = C_Traits.GetNodeInfo(configID, nodeID)
      if node and (node.ranksPurchased or 0) > 0 then spent[#spent + 1] = node end
    end
    table.sort(spent, function(a, b) return (a.posX or 0) < (b.posX or 0) end)
    log("tree", treeID, "nodes with points", #spent)
    for _, node in ipairs(spent) do
      local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
      log("  posX", node.posX, "posY", node.posY, "ranks", node.ranksPurchased, "spell",
        S(EntrySpellName(configID, entryID)))
    end
  end
  log("compare with /cf self: the points should sit under the right tree names (V30)")
end

-- ===== V41: chat windows =====
local function ChatWindows()
  if not GetChatWindowInfo then log("GetChatWindowInfo missing") return end
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
    if name and name ~= "" then
      log("window", i, S(name), "shown", S(shown), "docked", S(docked), "locked", S(locked),
        "uninteractable", S(uninteractable), "returns", select("#", GetChatWindowInfo(i)), "font", S(fontSize),
        "color", S(r), S(g), S(b), S(alpha))
    end
  end
  log("close a chat tab before /fp start to see what a closed one returns (V41)")
end

-- ===== V46: dungeons the client knows =====
-- Group Finder (premade groups, the "Looking For Group" window with level ranges): categories, activity
-- groups and every activity with all its fields.
local function GroupFinder()
  local lfg = C_LFGList
  for _, name in ipairs({ "GetAvailableCategories", "GetLfgCategoryInfo", "GetAvailableActivityGroups",
                          "GetActivityGroupInfo", "GetAvailableActivities", "GetActivityInfoTable" }) do
    log("exists C_LFGList." .. name, lfg ~= nil and lfg[name] ~= nil)
  end
  if not (lfg and lfg.GetAvailableCategories and lfg.GetAvailableActivities and lfg.GetActivityInfoTable) then return end
  if Enum and Enum.LFGListFilter then DumpTable("Enum.LFGListFilter", Enum.LFGListFilter) end
  for _, categoryID in ipairs(lfg.GetAvailableCategories() or {}) do
    DumpTable("category " .. categoryID, lfg.GetLfgCategoryInfo and lfg.GetLfgCategoryInfo(categoryID))
    if lfg.GetAvailableActivityGroups and lfg.GetActivityGroupInfo then
      for _, groupID in ipairs(lfg.GetAvailableActivityGroups(categoryID) or {}) do
        log("  activity group", groupID, lfg.GetActivityGroupInfo(groupID))
      end
    end
    local activities = lfg.GetAvailableActivities(categoryID) or {}
    log("  activities", #activities)
    for _, activityID in ipairs(activities) do
      DumpTable("  activity " .. activityID, lfg.GetActivityInfoTable(activityID))
    end
  end
end

-- Old Dungeon Finder IDs: a count per expansion level, and every dungeon-like entry beyond expansion 0
-- (the Vanilla list is known: V46 first run).
local function DungeonFinder()
  if not GetLFGDungeonInfo then log("GetLFGDungeonInfo missing") return end
  local perExpansion = {}
  for id = 1, LFG_MAX_ID do
    local name, typeID, subtypeID, minLevel, maxLevel, recLevel, _, _, expansionLevel, _, _, difficulty,
      maxPlayers = GetLFGDungeonInfo(id)
    if name then
      local key = S(expansionLevel)
      perExpansion[key] = (perExpansion[key] or 0) + 1
      if expansionLevel ~= 0 and (typeID == 1 or typeID == 2) then
        log("  LFG", id, S(name), "expansion", key, "type", S(typeID), "subtype", S(subtypeID), "levels",
          S(minLevel) .. "-" .. S(maxLevel), "rec", S(recLevel), "players", S(maxPlayers), "difficulty", S(difficulty))
      end
    end
  end
  for key, n in pairs(perExpansion) do log("LFG entries with expansion", key, n) end
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
    LogCall("  GetBattlefieldWinner", GetBattlefieldWinner)
  elseif event == "PVP_MATCH_COMPLETE" then
    LogCall("  GetBattlefieldWinner", GetBattlefieldWinner)
    LogCall("  GetBattlefieldArenaFaction", GetBattlefieldArenaFaction)
    LogCall("  UnitFactionGroup", UnitFactionGroup, "player")
  end
end)

local function FeedOn()
  FriendProbeDB.feed = true
  FeedRegister()
  log("feed logging on (stays on after /reload; /fp feed off stops it). Run a dungeon with a boss kill and a")
  log("battleground to the end, then /reload and send the log (V35).")
  LogInstance()
  LogGroup()
end

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

local function Invite()
  log("== V47/V48 INVITE ==")
  for _, name in ipairs({ "RequestInviteFromUnit", "InviteUnit", "ConfirmInviteUnit" }) do
    log("exists C_PartyInfo." .. name, C_PartyInfo ~= nil and C_PartyInfo[name] ~= nil)
  end
  log("exists BNInviteFriend", BNInviteFriend ~= nil, "EventRegistry", EventRegistry ~= nil)
  HookLinks()
  if not inviteWatching then
    inviteWatching = true
    for _, event in ipairs(INVITE_EVENTS) do pcall(inviteFrame.RegisterEvent, inviteFrame, event) end
  end
  print("|cff33ff99FP|r V47 " .. Link("test", 0, "click me: link test"))
  inviteTargets = {}
  for i = 1, BNGetNumFriends() do
    local acc = C_BattleNet.GetFriendAccountInfo(i)
    for j = 1, acc and C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
      local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
      if ga and ga.isOnline and ga.clientProgram == BNET_CLIENT_WOW and ga.wowProjectID == WOW_PROJECT_ID then
        local n = #inviteTargets + 1
        inviteTargets[n] = { name = ga.characterName, gameAccountID = ga.gameAccountID, battleTag = acc.battleTag }
        log("friend", n, S(ga.characterName), "gameAccountID", S(ga.gameAccountID))
        print("|cff33ff99FP|r V48 " .. S(ga.characterName) .. ": " .. Link("request", n, "ask them for an invite")
          .. " " .. Link("name", n, "invite by name") .. " " .. Link("bnet", n, "invite via Battle.net"))
      end
    end
  end
  if #inviteTargets == 0 then log("no friend online in Forever: the invite links need one") end
  log("click the test link, then each invite link once (leave the group between tries); /reload and send the log")
end

-- ===== V57: right-click menu (CF-37) =====
local function MenuApis()
  log("exists MenuUtil", MenuUtil ~= nil)
  log("exists MenuUtil.CreateContextMenu", MenuUtil ~= nil and MenuUtil.CreateContextMenu ~= nil)
  log("exists ChatFrameUtil.SendTell", ChatFrameUtil ~= nil and ChatFrameUtil.SendTell ~= nil)
  log("exists ChatFrame_SendTell", ChatFrame_SendTell ~= nil)
  log("exists ChatFrameUtil.OpenChat", ChatFrameUtil ~= nil and ChatFrameUtil.OpenChat ~= nil)
  log("exists ChatFrame_OpenChat", ChatFrame_OpenChat ~= nil)
  log("exists C_PartyInfo.InviteUnit", C_PartyInfo ~= nil and C_PartyInfo.InviteUnit ~= nil)
  log("exists AceGUI-3.0", LibStub ~= nil and LibStub("AceGUI-3.0", true) ~= nil)
  log("V57 clicks: /fp menu")
end

local menuWindow, copyBox

-- The name in a box, selected, so Ctrl+C copies it (WoW has no clipboard API; run 1: copying works).
-- Run 2: the box closes by itself after Ctrl+C and when it loses focus (a click elsewhere).
local function ShowCopy(name)
  if not copyBox then
    copyBox = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
    copyBox:SetSize(220, 24)
    copyBox:SetPoint("CENTER", 0, -120)
    copyBox:SetAutoFocus(false)
    copyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    copyBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    copyBox:SetScript("OnEditFocusLost", function(self)
      log("V57 copy box lost focus: hidden")
      self:Hide()
    end)
    copyBox:SetScript("OnKeyDown", function(self, key)
      if key == "C" and IsControlKeyDown and IsControlKeyDown() then
        log("V57 copy box saw Ctrl+C: hides now")
        C_Timer.After(0, function() self:ClearFocus() end)
      end
    end)
  end
  copyBox:SetText(name)
  copyBox:Show()
  copyBox:SetFocus()
  copyBox:HighlightText()
  log("V57 copy box shown with", name, "- press Ctrl+C: it should disappear; paste in chat to check")
end

-- The chat input that is open now, if any (functions guarded: which one exists is part of the answer).
local function ActiveChatInput()
  if ChatFrameUtil and ChatFrameUtil.GetActiveWindow then return ChatFrameUtil.GetActiveWindow(), "ChatFrameUtil" end
  if ChatEdit_GetActiveWindow then return ChatEdit_GetActiveWindow(), "ChatEdit" end
  return nil, "none"
end

local function Whisper(name)
  if ChatFrameUtil and ChatFrameUtil.SendTell then
    LogCall("V57 ChatFrameUtil.SendTell", ChatFrameUtil.SendTell, name)
  elseif ChatFrame_SendTell then
    LogCall("V57 ChatFrame_SendTell", ChatFrame_SendTell, name)
  else
    log("V57 no SendTell function")
  end
  C_Timer.After(0.2, function()
    local input, via = ActiveChatInput()
    if not input then
      log("V57 chat input after whisper: none open (via " .. via .. ")")
      return
    end
    log("V57 chat input after whisper: shown", S(input:IsShown()), "chatType",
      S(input.GetAttribute and input:GetAttribute("chatType")), "tellTarget",
      S(input.GetAttribute and input:GetAttribute("tellTarget")), "text", S(input:GetText()), "via", via)
  end)
end

-- Run 1: the menu draws below AceGUI windows. Raise it above them and log the strata.
local function RaiseMenu(menu, above)
  if type(menu) ~= "table" or not menu.GetFrameStrata then
    log("V57 CreateContextMenu returned", type(menu), "- cannot raise it")
    return
  end
  local before = menu:GetFrameStrata()
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  if above and above.GetFrameLevel and menu.SetFrameLevel then menu:SetFrameLevel(above:GetFrameLevel() + 50) end
  log("V57 menu strata", S(before), "->", S(menu:GetFrameStrata()), "level", S(menu.GetFrameLevel and menu:GetFrameLevel()))
end

local treeFrame -- the AceGUI test window (its frame), so the menu can go above it

local function OpenMenu(owner, name, title)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    log("V57 MenuUtil.CreateContextMenu missing: CF-37 needs its own popup")
    return
  end
  local ok, menu = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
    root:CreateTitle(title or name)
    root:CreateButton("Whisper", function() log("V57 menu click: Whisper") Whisper(name) end)
    root:CreateButton("Copy name", function() log("V57 menu click: Copy name") ShowCopy(name) end)
    root:CreateButton("Invite (logs only)", function() log("V57 menu click: Invite") end)
  end)
  if not ok then
    log("V57 CreateContextMenu error", S(menu))
    return
  end
  log("V57 CreateContextMenu opened")
  RaiseMenu(menu, treeFrame)
end

-- AceGUI makes the tree's row buttons when it lays the tree out (run 1: none existed yet), and reuses them:
-- hook every row button once, now and after each refresh.
local function HookTreeRows(tree, name)
  local hooked = 0
  for _, row in ipairs(tree.buttons or {}) do
    if row.HookScript and not row.fpHooked then
      row.fpHooked = true
      row:HookScript("OnMouseUp", function(self, mouse)
        log("V57 tree row mouse up", mouse, "on", S(self.uniquevalue), "level", S(self.level))
        if mouse == "RightButton" then
          OpenMenu(self, name, self.level == 1 and "Person: Bob (playing " .. name .. ")" or nil)
        end
      end)
      hooked = hooked + 1
    end
  end
  if hooked > 0 then log("V57 tree rows hooked", hooked) end
end

-- A test window: a plain button, and (with CommunitiesForever's AceGUI) a tree like the Friends list.
local function MenuTest()
  local name = GetUnitName("player", true)
  if menuWindow then menuWindow:Show() return end
  menuWindow = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
  menuWindow:SetSize(260, 120)
  menuWindow:SetPoint("CENTER", 0, 120)
  local button = CreateFrame("Button", nil, menuWindow, "UIPanelButtonTemplate")
  button:SetSize(200, 26)
  button:SetPoint("TOP", 0, -36)
  button:SetText("Right-click me")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(self, mouse)
    log("V57 plain button click", mouse)
    if mouse == "RightButton" then OpenMenu(self, name) end
  end)
  log("V57 test window open: right-click the button, try Whisper and Copy name")

  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  if not AceGUI then
    log("V57 no AceGUI (load CommunitiesForever too) - tree row test skipped")
    return
  end
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("FP tree row test")
  frame:SetWidth(320)
  frame:SetHeight(220)
  frame:SetLayout("Fill")
  treeFrame = frame.frame
  log("V57 AceGUI window strata", S(treeFrame:GetFrameStrata()), "level", S(treeFrame:GetFrameLevel()))
  local tree = AceGUI:Create("TreeGroup")
  if tree.EnableButtonTooltips then tree:EnableButtonTooltips(false) end -- as in the Friends list
  tree:SetTree({ { value = "p", text = "Person", children = { { value = "c", text = name } } } })
  tree:SetStatusTable({ groups = { p = true } })
  frame:AddChild(tree)
  local refresh = tree.RefreshTree
  tree.RefreshTree = function(self, ...)
    refresh(self, ...)
    HookTreeRows(self, name)
  end
  tree:RefreshTree()
  C_Timer.After(0.2, function() HookTreeRows(tree, name) end)
  log("V57 right-click the Person row and the", name, "row: does the menu open, above this window?")
end

-- ===== Commands =====
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
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, text, channel, target)
  log(label, "len", #text, "->", ok and S(result) or ("error " .. S(result)))
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
  else
    log("addon message <-", S(sender), "channel", S(channel), "len", #S(text), "target", S(target), "zoneChannelID",
      S(zoneChannelID), "localID", S(localID), "name", S(name), "text", S(text):sub(1, 20))
  end
end)

local function Start()
  FriendProbeDB = FriendProbeDB or {}
  FriendProbeDB.log = {}
  log("FriendProbe start")
  Section("CONTEXT", Context)
  Section("V8 COMMUNITIES", Clubs)
  Section("V30 TALENTS", Talents)
  Section("V41 CHAT WINDOWS", ChatWindows)
  Section("V46 GROUP FINDER", GroupFinder)
  Section("V46 DUNGEON FINDER", DungeonFinder)
  Section("V52 COMMUNITY PRESENCE", CommunityPresence)
  Section("V49/V50 COMMUNITY TRANSPORT", CommunityTransport)
  Section("V35 FEED", FeedOn)
  Section("V57 MENU APIS", MenuApis)
  log("start done: /reload, then send WTF\\Account\\<account>\\SavedVariables\\FriendProbe.lua")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name ~= "FriendProbe" then return end
  FriendProbeDB = FriendProbeDB or {}
  if FriendProbeDB.feed then FeedRegister() end
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX) end
end)

SLASH_FRIENDPROBE1 = "/fp"
SlashCmdList.FRIENDPROBE = function(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "start" then
    Start()
  elseif cmd == "comm" then
    local target = arg:match("^whisper%s+(.+)$")
    if arg == "summary" then
      log("== V49/V50 RECEIVED ==")
      CommSummary()
    elseif arg == "channel" then
      local _, index = CommunityChannel()
      SendAddon("V49 CHANNEL send", "V49:channel from " .. S(GetUnitName("player", true)), "CHANNEL", index)
    elseif target then
      SendAddon("V51 WHISPER " .. target, "V51:whisper from " .. S(GetUnitName("player", true)), "WHISPER", target)
      log("V51: does the other character's /fp log show 'addon message <-'? (both need FriendProbe)")
    else
      print("|cff33ff99FP|r /fp comm whisper <character name> | channel | summary")
    end
  elseif cmd == "invite" then
    Invite()
  elseif cmd == "menu" then
    Section("V57 MENU", MenuTest)
  elseif cmd == "feed" and arg == "off" then
    FriendProbeDB.feed = nil
    log("feed logging off")
  elseif cmd == "clear" then
    FriendProbeDB.log = {}
    print("|cff33ff99FP|r log cleared")
  else
    print("|cff33ff99FP|r /fp start (clear the log and run all open checks) | invite | menu | comm whisper <name> | feed off | clear")
  end
end
