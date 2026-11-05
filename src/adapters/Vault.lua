-- Vault: the guild code and the guild member list for alts (CF-84), kept OUT of CommunitiesForeverDB.
-- The uploader sends the whole CommunitiesForever.lua SavedVariables file to the website, so the code may not live
-- there. It lives in CommunitiesForeverVaultDB, the SavedVariables of the companion folder CommunitiesForever_Vault
-- (shipped in the same package, its own file CommunitiesForever_Vault.lua, which the uploader never reads). The
-- vault loads first (## OptionalDeps), and its one file makes the table, so here it is a table when the folder is
-- installed and enabled, and nil otherwise: then the feature stays off. Thin: no rules, see core/GuildInvite.lua.
local _, ns = ...

local Vault = {}

Vault.VERSION = 1

--[[ The vault's data, or nil when the companion folder is missing or disabled:
  CommunitiesForeverVaultDB = { v = 1, guilds = { [guild name, lower case] = { code, at, roster } } }
  roster[guid] = { name, seen } (core/GuildInvite.updateRoster). Shapes of an unknown newer `v` are left alone. ]]
function Vault.data()
  local db = CommunitiesForeverVaultDB
  if type(db) ~= "table" then return nil end
  if db.v == nil then db.v = Vault.VERSION end
  if type(db.v) ~= "number" or db.v > Vault.VERSION then return nil end
  if type(db.guilds) ~= "table" then db.guilds = {} end
  return db
end

function Vault.available()
  return Vault.data() ~= nil
end

-- The entry of one guild (made when `create`), or nil.
function Vault.guild(guildName, create)
  local db = Vault.data()
  if not db or type(guildName) ~= "string" or guildName == "" then return nil end
  local key = guildName:lower()
  local entry = db.guilds[key]
  if type(entry) ~= "table" then
    if not create then return nil end
    entry = {}
    db.guilds[key] = entry
  end
  return entry
end

ns.Vault = Vault
return Vault
