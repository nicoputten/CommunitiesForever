-- FriendProbe: checks the open API questions in VERIFY.md in-game (Claude Code cannot run WoW).
-- Commands:
--   /fp start       clear the log, then run every check below and switch on feed logging
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

-- ===== Commands =====
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
  Section("V35 FEED", FeedOn)
  log("start done: /reload, then send WTF\\Account\\<account>\\SavedVariables\\FriendProbe.lua")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name ~= "FriendProbe" then return end
  FriendProbeDB = FriendProbeDB or {}
  if FriendProbeDB.feed then FeedRegister() end
end)

SLASH_FRIENDPROBE1 = "/fp"
SlashCmdList.FRIENDPROBE = function(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "start" then
    Start()
  elseif cmd == "feed" and arg == "off" then
    FriendProbeDB.feed = nil
    log("feed logging off")
  elseif cmd == "clear" then
    FriendProbeDB.log = {}
    print("|cff33ff99FP|r log cleared")
  else
    print("|cff33ff99FP|r /fp start (clear the log and run all open checks) | feed off | clear")
  end
end
