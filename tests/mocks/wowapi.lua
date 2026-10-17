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
  function mixin:GetArgs(input)
    return (input or ""):match("^%s*(%S+)")
  end

  -- AceEvent: function callbacks receive (eventOrMessage, ...)
  function mixin:RegisterEvent(event, handler)
    state.events[event] = handler
  end
  function mixin:RegisterMessage(message, handler)
    state.messageHandlers[message] = handler
  end
  function mixin:SendMessage(message, ...)
    state.sent[#state.sent + 1] = { message, ... }
    local handler = state.messageHandlers[message]
    if handler then handler(message, ...) end
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

  return {
    ["AceAddon-3.0"] = AceAddon,
    ["AceDB-3.0"] = AceDB,
    ["AceConfig-3.0"] = AceConfig,
    ["AceConfigDialog-3.0"] = AceConfigDialog,
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
    messageHandlers = {},
    sent = {},
    timers = {},
    metadata = opts.metadata or { Version = "0.1.0" },
    serverTime = 1000,
    player = defaultPlayer(),
    -- C_Club.GetSubscribedClubs() result; clubType 1 = Character, 2 = Guild, 0 = BattleNet
    clubs = {
      { clubId = "23125681", name = "Forever Friends", clubType = 1 },
      { clubId = "999", name = "My Guild", clubType = 2 },
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
    UnitName = function() return p.name end,
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
    C_Club = {
      GetSubscribedClubs = function() return deepCopy(state.clubs) end,
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
  local handler = assert(state.events[event], "no handler registered for " .. event)
  handler(event, ...)
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
