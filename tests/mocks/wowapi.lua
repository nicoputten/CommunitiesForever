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

-- Fakes for the Ace3 behavior Core.lua relies on. Records output in state.
local function fakeLibs(state)
  local AceConsole = {}
  function AceConsole:Print(message)
    state.printed[#state.printed + 1] = message
  end
  function AceConsole:RegisterChatCommand(command, method)
    state.slash[command] = function(input) self[method](self, input) end
  end
  function AceConsole:GetArgs(input)
    return (input or ""):match("^%s*(%S+)")
  end

  local AceAddon = {}
  function AceAddon:NewAddon(object, name)
    for k, v in pairs(AceConsole) do object[k] = v end
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

  return {
    ["AceAddon-3.0"] = AceAddon,
    ["AceDB-3.0"] = AceDB,
  }
end

-- Installs the mock globals and returns a state table for assertions.
-- opts.metadata: TOC metadata returned by C_AddOns.GetAddOnMetadata (nil field = missing)
-- opts.noAddOnsApi: leave C_AddOns undefined
function wowapi.install(opts)
  opts = opts or {}
  local state = {
    printed = {},
    slash = {},
    metadata = opts.metadata or { Version = "0.1.0" },
    serverTime = 0,
  }
  local libs = fakeLibs(state)

  set("WOW_PROJECT_ID", 18)
  set("GetServerTime", function() return state.serverTime end)
  set("LibStub", function(major) return assert(libs[major], "mock LibStub: unknown lib " .. major) end)
  if not opts.noAddOnsApi then
    set("C_AddOns", {
      GetAddOnMetadata = function(_, field) return state.metadata[field] end,
    })
  end
  return state
end

-- Removes everything install() set, plus the addon's own globals.
function wowapi.uninstall()
  for name in pairs(installed) do _G[name] = nil end
  installed = {}
  _G.CommunitiesForever = nil
  _G.CommunitiesForeverDB = nil
end

return wowapi
