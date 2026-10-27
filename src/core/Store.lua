-- Store: SavedVariables schema and defaults. Pure Lua, no WoW globals.
local _, ns = ...

local Store = {}

Store.SCHEMA_VERSION = 2

-- AceDB defaults table. schemaVersion is deliberately not a default: AceDB
-- strips values equal to their default on logout, so a defaulted version
-- would never be saved and migrations could not tell old data from new.
function Store.defaults()
  return {
    global = {
      settings = { notifications = true, minimap = {}, window = {}, tree = {}, sendInterval = 0.2,
                   shareActivity = true,    -- CF-22
                   chatAlert = true, chatSound = false, chatKeepGeneral = true, chatTab = {},  -- CF-25
                   openOnLogin = false, ambientEffects = true,  -- CF-43
                   levelUpToast = true },  -- CF-44
      self = { version = 0, chars = {} },
      people = {},
      presence = {},
      locations = {},
      runs = {},          -- CF-23: run in progress per own character (not synced)
      pending = {},       -- CF-47: plans, answers, asks and pings waiting to reach the website
    },
  }
end

--[[ Upgrade pattern (CLAUDE.md rule 8): Store.MIGRATIONS[n](global) brings saved data from schema n to
n + 1, in place. A step renames or reshapes fields, derives what it can from the old data and leaves the
rest empty (nil, 0, {}); the code reading the data handles empty values. Bump SCHEMA_VERSION with every
step, never edit a released step, and give each step a spec with old data as it was saved (tests/fixtures). ]]
Store.MIGRATIONS = {}

-- 1 -> 2 (CF-47): the pending list for the website. Nothing to derive: earlier versions had no such items.
Store.MIGRATIONS[1] = function(global)
  if type(global.pending) ~= "table" then global.pending = {} end
end

-- Stamps the schema version on a fresh database and runs the migrations for older data. Data from a newer
-- schema (the addon was downgraded) is left untouched: returns global, "newer".
function Store.init(global)
  local version = global.schemaVersion
  if version == nil then
    global.schemaVersion = Store.SCHEMA_VERSION
    return global
  end
  if type(version) ~= "number" or version > Store.SCHEMA_VERSION then
    return global, "newer"
  end
  while version < Store.SCHEMA_VERSION do
    local step = assert(Store.MIGRATIONS[version], "no migration from schema " .. version)
    step(global)
    version = version + 1
    global.schemaVersion = version
  end
  return global
end

ns.Store = Store
return Store
