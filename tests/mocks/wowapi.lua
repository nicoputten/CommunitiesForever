-- Minimal WoW API mock for adapter, service and UI specs.
-- Core specs (src/core) must not use this: core takes all input as arguments.
-- Grow it per story, only with APIs the code under test actually calls.
local wowapi = {}

local installed = {}

local function set(name, value)
  installed[name] = true
  _G[name] = value
end

local function deepCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = deepCopy(v) end
  return copy
end

-- Default player, values taken from the FriendProbe run (API-FINDINGS.md).
local function defaultPlayer()
  return {
    guid = "Player-4619-01627852",
    name = "Ves Doombringer",
    classFile = "PALADIN",
    race = { "Tauren", "Tauren", 6 },
    level = 11,
    faction = { "Horde", "Horde" },
    realm = "Classic Beta PvP",
    itemLevel = { 1.5625, 1.5625, 1.5625 },
    battleTag = "Vestras#2858",
    -- GetProfessions() slots (prof1, prof2, archaeology, fishing, cooking) -> profession index
    professionSlots = { [1] = 10, [5] = 12 },
    -- GetProfessionInfo(index) returns
    professionInfo = {
      [10] = { "Mining", 136248, 64, 150, 2, 54, 186, 0, -1, 0, "Mining" },
      [12] = { "Cooking", 133971, 2, 75, 1, 60, 185, 0, -1, 0, "Cooking" },
    },
  }
end

-- Fakes for the Ace3 behavior the addon relies on. Records activity in state.
local function fakeLibs(state)
  local mixin = {}

  -- AceConsole
  function mixin:Print(message)
    state.printed[#state.printed + 1] = message
  end
  function mixin:RegisterChatCommand(command, method)
    state.slash[command] = function(input) self[method](self, input) end
  end
  -- Like AceConsole: up to n whitespace-separated arguments.
  function mixin:GetArgs(input, n)
    local args = {}
    for word in (input or ""):gmatch("%S+") do
      if #args < (n or 1) then args[#args + 1] = word end
    end
    return unpack(args, 1, n or 1)
  end

  -- AceEvent: one handler per (object, event/message), like the real library; function
  -- callbacks receive (eventOrMessage, ...). state.events[event] keeps the last handler.
  local eventMixin = {}
  function eventMixin:RegisterEvent(event, handler)
    state.events[event] = handler
    state.eventHandlers[event] = state.eventHandlers[event] or {}
    state.eventHandlers[event][self] = handler
  end
  function eventMixin:RegisterMessage(message, handler)
    state.messageHandlers[message] = state.messageHandlers[message] or {}
    state.messageHandlers[message][self] = handler
  end
  function eventMixin:SendMessage(message, ...)
    state.sent[#state.sent + 1] = { message, ... }
    for _, handler in pairs(state.messageHandlers[message] or {}) do
      handler(message, ...)
    end
  end
  for k, v in pairs(eventMixin) do mixin[k] = v end

  local AceEvent = {}
  function AceEvent:Embed(target)
    for k, v in pairs(eventMixin) do target[k] = v end
    return target
  end

  local AceAddon = {}
  function AceAddon:NewAddon(object, name)
    for k, v in pairs(mixin) do object[k] = v end
    object.name = name
    state.addon = object
    return object
  end

  local AceDB = {}
  function AceDB:New(svName, defaults)
    local db = { global = deepCopy(defaults.global) }
    state.db = db
    state.svName = svName
    return db
  end

  local AceConfig = {}
  function AceConfig:RegisterOptionsTable(appName, options)
    state.optionsApp = appName
    state.options = type(options) == "function" and options() or options
  end

  local AceConfigDialog = {}
  function AceConfigDialog:AddToBlizOptions(appName, name)
    state.blizOptions = { appName, name }
  end
  function AceConfigDialog:Open(appName)
    state.openedDialog = appName
  end

  -- AceGUI: widgets record what was set on them; containers keep their children.
  local AceGUI = {}
  function AceGUI:Create(widgetType)
    local w = { type = widgetType, children = {}, callbacks = {}, shown = true, frame = {} }
    function w.frame.IsShown() return w.shown end
    -- CF-32: keyboard input (frame.keyboard, frame.propagate, frame.scripts.OnKeyDown).
    w.frame.scripts = {}
    function w.frame:EnableKeyboard(on) self.keyboard = on end
    function w.frame:SetPropagateKeyboardInput(on)
      assert(not state.inCombat, "SetPropagateKeyboardInput in combat")
      self.propagate = on
    end
    function w.frame:SetScript(name, fn) self.scripts[name] = fn end
    function w:SetCallback(name, fn) self.callbacks[name] = fn end
    function w:Fire(name, ...) if self.callbacks[name] then self.callbacks[name](self, name, ...) end end
    function w:AddChild(child) self.children[#self.children + 1] = child end
    function w:ReleaseChildren() self.children = {} end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false; self:Fire("OnClose") end
    function w:SetStatusTable(t) self.status = t end
    function w:PauseLayout() self.paused = true end
    function w:ResumeLayout() self.paused = false end
    function w:DoLayout() self.layouts = (self.layouts or 0) + 1 end
    function w:SetTree(t) self.tree = t; self:RefreshTree() end
    -- Like TreeGroup: one button per visible row, level 1 = group, 2 = child.
    function w:RefreshTree()
      self.buttons = {}
      for _, node in ipairs(self.tree or {}) do
        for level, n in ipairs({ node, unpack(node.children or {}) }) do
          local button = { level = level == 1 and 1 or 2, text = {} }
          function button:SetNormalFontObject(font) self.normalFont = font end
          function button:SetHighlightFontObject(font) self.highlightFont = font end
          button.node = n
          self.buttons[#self.buttons + 1] = button
        end
      end
    end
    function w:SetTreeWidth(width, resizable) self.treeWidth, self.treeResizable = width, resizable end
    function w:SelectByValue(path)
      self.status = self.status or {}
      self.status.selected = path
      self:Fire("OnGroupSelected", path)
    end
    function w:SelectByPath(...) self:SelectByValue(table.concat({ ... }, "\001")) end
    function w:SetTabs(tabs) self.tabs = tabs end
    function w:SelectTab(value) self.selectedTab = value; self:Fire("OnGroupSelected", value) end
    function w:EnableButtonTooltips(enable) self.buttonTooltips = enable end
    for _, setter in ipairs({ "Title", "StatusText", "Layout", "Text", "FullWidth", "FullHeight", "Highlight",
                              "FontObject",
                              "Color", "Width", "Height", "RelativeWidth",
                              "Label", "Value", "Disabled", "MaxLetters" }) do
      w["Set" .. setter] = function(widget, value) widget[setter:sub(1, 1):lower() .. setter:sub(2)] = value end
    end
    function w:SetList(list, order) self.list, self.order = list, order end
    function w:DisableButton(disabled) self.buttonDisabled = disabled end
    function w:GetText() return self.text end
    function w:GetValue() return self.value end
    if widgetType == "Frame" then
      w.statusbg = { Hide = function(bg) bg.hidden = true end }
      w.statustext = { GetParent = function() return w.statusbg end }
    end
    state.guiWidgets[#state.guiWidgets + 1] = w
    return w
  end

  local LDB = {}
  function LDB:NewDataObject(name, object)
    state.ldbObjects[name] = object
    return object
  end

  local DBIcon = {}
  function DBIcon:Register(name, object, db)
    state.minimapIcon = { name = name, object = object, db = db, shown = not db.hide }
  end
  function DBIcon:Show(name) state.minimapIcon.shown = true; assert(name == state.minimapIcon.name) end
  function DBIcon:Hide(name) state.minimapIcon.shown = false; assert(name == state.minimapIcon.name) end

  return {
    ["AceAddon-3.0"] = AceAddon,
    ["AceDB-3.0"] = AceDB,
    ["AceEvent-3.0"] = AceEvent,
    ["AceConfig-3.0"] = AceConfig,
    ["AceConfigDialog-3.0"] = AceConfigDialog,
    ["AceGUI-3.0"] = AceGUI,
    ["LibDataBroker-1.1"] = LDB,
    ["LibDBIcon-1.0"] = DBIcon,
    -- The real pure-Lua libraries (tests/helpers.lua loads them from Libs/).
    LibSerialize = require("helpers").lib("LibSerialize"),
    LibDeflate = require("helpers").lib("LibDeflate"),
  }, mixin
end

-- Installs the mock globals and returns a state table for assertions.
-- opts.metadata: TOC metadata returned by C_AddOns.GetAddOnMetadata (nil field = missing)
-- opts.missing: set of global names to leave undefined, e.g. { GetAverageItemLevel = true }
-- opts.validEvents: if set, C_EventUtils.IsEventValid accepts only these event names
function wowapi.install(opts)
  opts = opts or {}
  local missing = opts.missing or {}
  local state = {
    printed = {},
    slash = {},
    events = {},
    eventHandlers = {},
    guiWidgets = {},
    ldbObjects = {},
    messageHandlers = {},
    sent = {},
    timers = {},
    metadata = opts.metadata or { Version = "0.1.0" },
    serverTime = 1000,
    time = 500,            -- GetTime()
    inCombat = false,      -- InCombatLockdown()
    chatFilters = {},      -- chat message filters per event (ChatFrame_AddMessageEventFilter)
    bnSent = {},           -- BNSendGameData calls: { gameAccountID, prefix, text }
    whispers = {},         -- C_ChatInfo.SendAddonMessage calls (CF-28)
    prefixes = {},         -- registered addon message prefixes
    player = defaultPlayer(),
    -- C_Club.GetSubscribedClubs() result; clubType 1 = Character, 2 = Guild, 0 = BattleNet
    clubs = {
      { clubId = "23125681", name = "Forever Friends", clubType = 1 },
      { clubId = "999", name = "My Guild", clubType = 2 },
      { clubId = "777", name = "Other Friends", clubType = 1 },
    },
    -- clubMembers[clubId] = list of C_Club.GetMemberInfo results (fields as verified)
    clubMembers = {
      ["23125681"] = {
        { memberId = 1, guid = "Player-4619-01627852", name = "Ves Doombringer", classID = 2, level = 11,
          zone = "Durotar", presence = 1, race = 6, faction = 0, isSelf = true, clubType = 1, role = 1 },
        { memberId = 2, guid = "Player-4619-01789956", name = "Garraka Doombringer", classID = 8, level = 11,
          zone = "Orgrimmar", presence = 1, race = 2, faction = 0, isSelf = false, clubType = 1, role = 4 },
      },
    },
    focusedClubs = {},
    redeemed = {},         -- C_Club.RedeemTicket calls
    tooltipPostCalls = {}, -- TooltipDataProcessor.AddTooltipPostCall registrations
    -- state.talentNodes: class talent tree nodes { posX, ranks } (CF-18); nil = not available.
    -- state.questLog: quest log entries { questID, title, isHeader, isHidden, tagID } (CF-19); nil = not available.
    atlases = { ["worldquest-icon-dungeon"] = true }, -- C_Texture.GetAtlasInfo knows these atlas names
    calendarTime = { year = 2026, month = 10, monthDay = 18 }, -- C_DateAndTime.GetCurrentCalendarTime (realm date)
    -- Battle.net friends: { battleTag, gameAccounts = { C_BattleNet game account infos } }
    friends = {
      { battleTag = "Sjaakovich#2232", gameAccounts = {
        { clientProgram = "WoW", wowProjectID = 18, isOnline = true, characterName = "Garraka Doombringer",
          realmName = "ClassicBetaPvP", realmDisplayName = "Classic Beta PvP", className = "Mage",
          characterLevel = 11, factionName = "Horde", playerGuid = "Player-4619-01789956", gameAccountID = 5 },
        { clientProgram = "BSAp", isOnline = true, gameAccountID = 6 },
      } },
      { battleTag = "Retailer#1111", gameAccounts = {
        { clientProgram = "WoW", wowProjectID = 1, isOnline = true, characterName = "Mainline Guy",
          playerGuid = "Player-1-AAAA", gameAccountID = 7 },
      } },
      { battleTag = "Offline#3333", gameAccounts = {} },
    },
  }
  local libs, mixin = fakeLibs(state)
  state.aceMixin = mixin
  local p = state.player

  local globals = {
    WOW_PROJECT_ID = 18,
    GetServerTime = function() return state.serverTime end,
    LibStub = function(major) return assert(libs[major], "mock LibStub: unknown lib " .. major) end,
    C_AddOns = {
      GetAddOnMetadata = function(_, field) return state.metadata[field] end,
    },
    C_Timer = {
      NewTimer = function(seconds, callback)
        local timer = { seconds = seconds, callback = callback }
        function timer:Cancel() self.cancelled = true end
        state.timers[#state.timers + 1] = timer
        return timer
      end,
    },
    -- CF-23: other units (party1, raid3, ...) from state.unitGuids; the player otherwise.
    UnitGUID = function(unit)
      if unit and state.unitGuids and state.unitGuids[unit] ~= nil then return state.unitGuids[unit] end
      return p.guid
    end,
    -- Like Forever for some characters: first and last name split over two returns (V9).
    UnitName = function() return p.name:match("^(%S+)"), p.name:match("^%S+ (.+)$") end,
    GetUnitName = function(_, showServer) assert(showServer == true); return p.name end,
    UnitClassBase = function() return p.classFile end,
    UnitRace = function() return unpack(p.race) end,
    UnitLevel = function() return p.level end,
    UnitFactionGroup = function() return unpack(p.faction) end,
    GetRealmName = function() return p.realm end,
    GetAverageItemLevel = function() return unpack(p.itemLevel) end,
    GetProfessions = function()
      local s = p.professionSlots
      return s[1], s[2], s[3], s[4], s[5]
    end,
    GetProfessionInfo = function(index) return unpack(p.professionInfo[index]) end,
    BNGetInfo = function() return nil, p.battleTag end,
    BNSendGameData = function(gameAccountID, prefix, text)
      state.bnSent[#state.bnSent + 1] = { gameAccountID, prefix, text }
    end,
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function(prefix) state.prefixes[prefix] = true; return 0 end,
      -- CF-28: addon whispers in state.whispers: { prefix, text, channel, target }.
      SendAddonMessage = function(prefix, text, channel, target)
        state.whispers[#state.whispers + 1] = { prefix, text, channel, target }
        return 0
      end,
    },
    InCombatLockdown = function() return state.inCombat end,
    -- CF-28: chat filters (state.chatFilters[event] = { fn, ... }) and the system line for a failed whisper.
    ChatFrame_AddMessageEventFilter = function(event, fn)
      state.chatFilters[event] = state.chatFilters[event] or {}
      table.insert(state.chatFilters[event], fn)
    end,
    ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing.",
    GetTime = function() return state.time end,
    C_ClassTalents = {
      GetActiveConfigID = function() return state.talentNodes and 9038911 or nil end,
    },
    C_Traits = {
      GetConfigInfo = function() return { name = "Warrior", treeIDs = { 1117 } } end,
      GetTreeNodes = function()
        local ids = {}
        for i = 1, #(state.talentNodes or {}) do ids[i] = 100000 + i end
        return ids
      end,
      GetNodeInfo = function(_, nodeID)
        local node = state.talentNodes[nodeID - 100000]
        return node and { ID = nodeID, posX = node.posX, ranksPurchased = node.ranks, maxRanks = 5 }
      end,
    },
    C_QuestLog = {
      GetNumQuestLogEntries = function()
        if not state.questLog then return nil end
        local quests = 0
        for _, e in ipairs(state.questLog) do
          if not e.isHeader then quests = quests + 1 end
        end
        return #state.questLog, quests
      end,
      GetInfo = function(index)
        local e = state.questLog and state.questLog[index]
        return e and { questID = e.isHeader and 0 or e.questID, title = e.title, level = 1,
                       isHeader = e.isHeader or false, isHidden = e.isHidden or false }
      end,
      GetQuestTagInfo = function(questID)
        for _, e in ipairs(state.questLog or {}) do
          if e.questID == questID and e.tagID then return { tagID = e.tagID, tagName = "Dungeon" } end
        end
      end,
    },
    C_DateAndTime = {
      GetCurrentCalendarTime = function() return state.calendarTime and deepCopy(state.calendarTime) end,
    },
    date = os.date,
    C_Texture = {
      GetAtlasInfo = function(name) return state.atlases[name] and { width = 32, height = 32 } or nil end,
    },
    C_Club = {
      GetSubscribedClubs = function() return deepCopy(state.clubs) end,
      GetClubMembers = function(clubId)
        local ids = {}
        for _, m in ipairs(state.clubMembers[clubId] or {}) do ids[#ids + 1] = m.memberId end
        return ids
      end,
      GetMemberInfo = function(clubId, memberId)
        for _, m in ipairs(state.clubMembers[clubId] or {}) do
          if m.memberId == memberId then return deepCopy(m) end
        end
      end,
      RedeemTicket = function(code)
        state.redeemed[#state.redeemed + 1] = code
      end,
      FocusMembers = function(clubId)
        state.focusedClubs[#state.focusedClubs + 1] = clubId
      end,
    },
    GameFontNormal = { name = "GameFontNormal" },
    GameFontNormalHuge = { name = "GameFontNormalHuge" },
    GameFontNormalLarge = { name = "GameFontNormalLarge" },
    GameFontHighlight = { name = "GameFontHighlight" },
    GameFontHighlightLarge = { name = "GameFontHighlightLarge" },
    GameFontHighlightSmall = { name = "GameFontHighlightSmall" },
    GameFontDisable = { name = "GameFontDisable" },
    RAID_CLASS_COLORS = {
      MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    },
    C_CreatureInfo = {
      GetClassInfo = function(classID)
        local files = { [2] = "PALADIN", [8] = "MAGE" }
        local names = { [2] = "Paladin", [8] = "Mage" }
        return files[classID] and { classFile = files[classID], className = names[classID] }
      end,
    },
    BNET_CLIENT_WOW = "WoW",
    BNGetNumFriends = function()
      return #state.friends
    end,
    C_BattleNet = {
      GetFriendAccountInfo = function(i)
        local f = state.friends[i]
        return f and { battleTag = f.battleTag }
      end,
      GetFriendNumGameAccounts = function(i)
        return #state.friends[i].gameAccounts
      end,
      GetFriendGameAccountInfo = function(i, j)
        return deepCopy(state.friends[i].gameAccounts[j])
      end,
    },
    TooltipDataProcessor = {
      AddTooltipPostCall = function(dataType, callback)
        state.tooltipPostCalls[#state.tooltipPostCalls + 1] = { dataType = dataType, callback = callback }
      end,
    },
    Enum = {
      ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 },
      TooltipDataType = { Unit = 2 },
    },
  }
  if opts.validEvents then
    local valid = {}
    for _, event in ipairs(opts.validEvents) do valid[event] = true end
    globals.C_EventUtils = { IsEventValid = function(event) return valid[event] == true end }
  end

  -- CF-25: chat windows. state.chatWindows[i] = { name, channels = { channel names } }; joined channels
  -- in state.chatChannels[name] = index; ChangeChatColor calls in state.chatColors, flashes, sounds.
  state.chatChannels = { ["Community:23125681:1"] = 6 }
  state.chatWindows = { { name = "General", channels = { "Community:23125681:1" } },
                        { name = "Combat Log", channels = {} } }
  state.chatColors, state.flashed, state.sounds = {}, {}, {}
  local function chatFrame(i)
    local f = { id = i }
    function f.GetID(frame) return frame.id end
    function f.AddChannel(frame, channel)
      table.insert(state.chatWindows[frame.id].channels, channel)
      return state.chatChannels[channel]
    end
    function f.RemoveChannel(frame, channel)
      local list = state.chatWindows[frame.id].channels
      for k = #list, 1, -1 do if list[k] == channel then table.remove(list, k) end end
    end
    return f
  end
  for i = 1, 10 do globals["ChatFrame" .. i] = chatFrame(i) end
  globals.NUM_CHAT_WINDOWS = 10
  globals.SELECTED_CHAT_FRAME = globals.ChatFrame1
  globals.SOUNDKIT = { TELL_MESSAGE = 3081 }
  globals.Chat_GetCommunitiesChannelName = function(clubId, streamId)
    return "Community:" .. clubId .. ":" .. streamId
  end
  globals.GetChannelName = function(name) return state.chatChannels[name] or 0 end
  globals.ChangeChatColor = function(chatType, r, g, b) state.chatColors[chatType] = { r = r, g = g, b = b } end
  -- Like Mainline: name, fontSize, r, g, b, alpha, shown, locked, docked. A window with closed = true is
  -- what closing a chat tab leaves: the name stays, shown and docked are off (CF-26 feedback).
  globals.GetChatWindowInfo = function(i)
    local w = state.chatWindows[i]
    if not w then return "" end
    return w.name, 14, 1, 1, 1, 1, not w.closed, false, (not w.closed) and 1 or nil
  end
  globals.GetChatWindowChannels = function(i)
    local result = {}
    for _, c in ipairs(state.chatWindows[i] and state.chatWindows[i].channels or {}) do
      result[#result + 1] = c
      result[#result + 1] = state.chatChannels[c] or 0
    end
    return unpack(result)
  end
  globals.FCF_StartAlertFlash = function(frame) state.flashed[#state.flashed + 1] = frame.id end
  globals.PlaySound = function(id) state.sounds[#state.sounds + 1] = id end
  globals.FCF_OpenNewWindow = function(name)
    state.chatWindows[#state.chatWindows + 1] = { name = name, channels = {} }
    return globals["ChatFrame" .. #state.chatWindows]
  end
  globals.ChatFrame_RemoveAllMessageGroups = function() end
  globals.C_Club.GetStreams = function() return { { streamId = 1, name = "General", streamType = 0 } } end
  globals.Enum = globals.Enum or {}
  globals.Enum.ClubStreamType = { General = 0 }

  -- CF-23: instances. state.instance = { name, type, instanceID } (outside: Kalimdor, type "none");
  -- state.group = { guid, ... } of the other group members (party1.. or raid1.. with state.inRaid);
  -- state.bgWinner / state.bgTeam for GetBattlefieldWinner / GetBattlefieldArenaFaction.
  state.instance = { name = "Kalimdor", type = "none", instanceID = 1 }
  state.group = {}
  globals.GetInstanceInfo = function()
    local i = state.instance
    return i.name, i.type, 0, "", 5, 0, false, i.instanceID
  end
  globals.GetRealZoneText = function() return state.zone end
  globals.GetNumGroupMembers = function() return #state.group > 0 and #state.group + 1 or 0 end
  globals.IsInRaid = function() return state.inRaid == true end
  globals.GetBattlefieldWinner = function() return state.bgWinner end
  globals.GetBattlefieldArenaFaction = function() return state.bgTeam end
  local function groupUnits()
    state.unitGuids = {}
    for i, guid in ipairs(state.group) do
      state.unitGuids[(state.inRaid and "raid" or "party") .. i] = guid
    end
  end
  -- CF-24: calendar. state.calendarEvents[monthOffset][day] = { GetDayEvent results }; OpenCalendar
  -- calls are counted in state.calendarOpened, ToggleCalendar sets state.calendarToggled.
  state.calendarEvents, state.calendarOpened, state.calendarOpenedEvents, state.calendarInvites = {}, 0, {}, {}
  globals.C_Calendar = {
    OpenCalendar = function() state.calendarOpened = state.calendarOpened + 1 end,
    GetMonthInfo = function() return { numDays = 31 } end,
    GetNumDayEvents = function(offset, day)
      local month = state.calendarEvents[offset]
      return month and month[day] and #month[day] or 0
    end,
    GetDayEvent = function(offset, day, i) return state.calendarEvents[offset][day][i] end,
    -- Opened events in state.calendarOpenedEvents ({ offset, day, index }); their invites from
    -- state.calendarInvites["offset:day:index"] = { inviteStatus, ... }. CALENDAR_OPEN_EVENT is fired by the spec.
    OpenEvent = function(offset, day, index)
      state.calendarOpenedEvents[#state.calendarOpenedEvents + 1] = { offset, day, index }
      state.calendarCurrent = offset .. ":" .. day .. ":" .. index
    end,
    GetNumInvites = function() return #(state.calendarInvites[state.calendarCurrent] or {}) end,
    EventGetInvite = function(i) return { inviteStatus = state.calendarInvites[state.calendarCurrent][i] } end,
    CloseEvent = function() state.calendarCurrent = nil end,
  }
  globals.ToggleCalendar = function() state.calendarToggled = true end
  -- CF-24: Group Finder. state.lfgActivities[activityID] = GetActivityInfoTable result, all in category 2.
  state.lfgActivities = {}
  globals.C_LFGList = {
    GetAvailableCategories = function() return { 2 } end,
    GetAvailableActivities = function()
      local ids = {}
      for id in pairs(state.lfgActivities) do ids[#ids + 1] = id end
      table.sort(ids)
      return ids
    end,
    GetActivityInfoTable = function(id) return state.lfgActivities[id] end,
  }

  state.setGroup = function(guids, inRaid)
    state.group, state.inRaid = guids, inRaid
    groupUnits()
  end

  for name, value in pairs(globals) do
    if not missing[name] then set(name, value) end
  end
  return state
end

-- Fires a registered WoW event handler (as AceEvent would).
function wowapi.fireEvent(state, event, ...)
  local handlers = assert(state.eventHandlers[event], "no handler registered for " .. event)
  for _, handler in pairs(handlers) do
    handler(event, ...)
  end
end

-- Runs all pending, non-cancelled C_Timer timers.
function wowapi.runTimers(state)
  local timers = state.timers
  state.timers = {}
  for _, timer in ipairs(timers) do
    if not timer.cancelled then timer.callback() end
  end
end

-- Messages sent with the given name, as arrays of their arguments.
-- Simulates hovering a unit: runs the registered unit tooltip post-calls and returns the added lines.
-- data defaults to { guid = guid }; pass data to test other shapes.
function wowapi.hoverUnit(state, guid, data)
  local added = {}
  local tooltip = {
    AddLine = function(_, text, r, g, b) added[#added + 1] = { text = text, r = r, g = g, b = b } end,
    GetUnit = function() return "Someone", "mouseover" end,
  }
  for _, call in ipairs(state.tooltipPostCalls) do
    if call.dataType == _G.Enum.TooltipDataType.Unit then
      call.callback(tooltip, data or { guid = guid })
    end
  end
  return added
end

function wowapi.sentMessages(state, message)
  local found = {}
  for _, entry in ipairs(state.sent) do
    if entry[1] == message then found[#found + 1] = { unpack(entry, 2) } end
  end
  return found
end

-- Several clients in one spec (tests/net.lua): the globals of the current install and the addon, to put
-- back later with activate(), so each client runs against its own mock.
local ADDON_GLOBALS = { "CommunitiesForever", "CommunitiesForeverDB",
                        "BINDING_HEADER_COMMUNITIESFOREVER", "BINDING_NAME_COMMUNITIESFOREVER_TOGGLE" }

function wowapi.snapshot()
  local globals = {}
  for name in pairs(installed) do globals[name] = _G[name] end
  for _, name in ipairs(ADDON_GLOBALS) do globals[name] = _G[name] end
  return globals
end

function wowapi.activate(globals)
  for name, value in pairs(globals) do
    _G[name] = value
    installed[name] = true
  end
end

-- Removes everything install() set, plus the addon's own globals.
function wowapi.uninstall()
  for name in pairs(installed) do _G[name] = nil end
  installed = {}
  _G.CommunitiesForever = nil
  _G.CommunitiesForeverDB = nil
end

return wowapi
