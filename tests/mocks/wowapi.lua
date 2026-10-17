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
    for _, setter in ipairs({ "Title", "StatusText", "Layout", "Text", "FullWidth", "FontObject",
                              "Color", "Width", "Height", "RelativeWidth" }) do
      w["Set" .. setter] = function(widget, value) widget[setter:sub(1, 1):lower() .. setter:sub(2)] = value end
    end
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
    bnSent = {},           -- BNSendGameData calls: { gameAccountID, prefix, text }
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
    UnitGUID = function() return p.guid end,
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
    },
    InCombatLockdown = function() return state.inCombat end,
    GetTime = function() return state.time end,
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
    Enum = {
      ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 },
    },
  }
  if opts.validEvents then
    local valid = {}
    for _, event in ipairs(opts.validEvents) do valid[event] = true end
    globals.C_EventUtils = { IsEventValid = function(event) return valid[event] == true end }
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
function wowapi.sentMessages(state, message)
  local found = {}
  for _, entry in ipairs(state.sent) do
    if entry[1] == message then found[#found + 1] = { unpack(entry, 2) } end
  end
  return found
end

-- Removes everything install() set, plus the addon's own globals.
function wowapi.uninstall()
  for name in pairs(installed) do _G[name] = nil end
  installed = {}
  _G.CommunitiesForever = nil
  _G.CommunitiesForeverDB = nil
end

return wowapi
