-- Store: SavedVariables schema and defaults. Pure Lua, no WoW globals.
local _, ns = ...

local Store = {}

Store.SCHEMA_VERSION = 1

-- AceDB defaults table. schemaVersion is deliberately not a default: AceDB
-- strips values equal to their default on logout, so a defaulted version
-- would never be saved and migrations could not tell old data from new.
function Store.defaults()
  return {
    global = {
      settings = { notifications = true, minimap = {}, window = {}, tree = {}, sendInterval = 0.2,
                   shareActivity = true,    -- CF-22
                   chatAlert = true, chatSound = false, chatKeepGeneral = true, chatTab = {} },  -- CF-25
      self = { version = 0, chars = {} },
      people = {},
      presence = {},
      locations = {},
    },
  }
end

-- Stamps the schema version on a fresh database. Migrations hook in here later.
function Store.init(global)
  if global.schemaVersion == nil then
    global.schemaVersion = Store.SCHEMA_VERSION
  end
  return global
end

ns.Store = Store
return Store
