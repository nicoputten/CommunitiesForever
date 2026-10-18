-- Snapshot: build and compare character snapshots. Pure Lua, no WoW globals.
-- Requires ns.Merge (load core/Merge.lua first).
local _, ns = ...

local Snapshot = {}

-- Synced scalar Char fields. updatedAt and lastPlayed are metadata and never compared.
local SCALAR_FIELDS = { "guid", "name", "classFile", "raceID", "level", "faction", "realm", "ilvl",
  "mainTree", "autoRole", "roleOverride", "role" }   -- CF-18: talents and role

-- Builds a Char from raw SelfInfo values.
-- info.professions is a list of { name, rank, max, skillLine }; entries without skillLine are skipped.
-- ilvl is floored like the character pane, so fractional noise does not bump the version.
function Snapshot.build(info)
  local char = {}
  for _, field in ipairs(SCALAR_FIELDS) do
    char[field] = info[field]
  end
  if char.ilvl then
    char.ilvl = math.floor(char.ilvl)
  end

  char.professions = {}
  for _, p in ipairs(info.professions or {}) do
    if p.skillLine then
      char.professions[p.skillLine] = { name = p.name, rank = p.rank, max = p.max }
    end
  end

  -- CF-18: info.talents = { { name, points } x3 } (already summarized), info.autoRole from the main tree.
  if type(info.talents) == "table" then
    char.talents = {}
    for i, tree in ipairs(info.talents) do
      char.talents[i] = { name = tree.name, points = tree.points }
    end
  end
  char.role = char.roleOverride or char.autoRole
  char.quests = info.quests -- CF-19: { [questID] = { title, area, dungeon } }, already normalized
  return char
end

-- Same quest IDs (progress, titles and areas do not count: no version bump on quest progress).
local function questsEqual(a, b)
  if a == nil or b == nil then return a == b end
  for id in pairs(a) do
    if not b[id] then return false end
  end
  for id in pairs(b) do
    if not a[id] then return false end
  end
  return true
end

local function talentsEqual(a, b)
  if a == nil or b == nil then return a == b end
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].name ~= b[i].name or a[i].points ~= b[i].points then return false end
  end
  return true
end

local function professionsEqual(a, b)
  for skillLine, pa in pairs(a) do
    local pb = b[skillLine]
    if not pb or pa.name ~= pb.name or pa.rank ~= pb.rank or pa.max ~= pb.max then
      return false
    end
  end
  for skillLine in pairs(b) do
    if not a[skillLine] then return false end
  end
  return true
end

-- True if two Chars have identical synced fields.
function Snapshot.equal(a, b)
  if a == nil or b == nil then
    return a == b
  end
  for _, field in ipairs(SCALAR_FIELDS) do
    if a[field] ~= b[field] then return false end
  end
  return professionsEqual(a.professions or {}, b.professions or {}) and talentsEqual(a.talents, b.talents)
    and questsEqual(a.quests, b.quests)
end

-- Stores the current character in the own record (db.global.self).
-- Bumps record.version and sets updatedAt only when a synced field changed.
-- Returns true if the record changed.
function Snapshot.apply(record, info, now)
  if info.battleTag then
    record.battleTag = info.battleTag
  end
  if not info.guid then
    return false
  end

  local previous = record.chars[info.guid]
  local char = Snapshot.build(info)
  if previous then
    -- Talent data may not be readable yet (login): keep what we had instead of wiping it.
    if char.talents == nil then
      char.talents, char.mainTree, char.autoRole = previous.talents, previous.mainTree, previous.autoRole
    end
    if char.quests == nil then char.quests = previous.quests end
    -- The role override is set by the player in settings, not read from the game.
    char.roleOverride = previous.roleOverride
    char.role = char.roleOverride or char.autoRole
  end
  if Snapshot.equal(previous, char) then
    return false
  end

  char.updatedAt = now
  char.lastPlayed = previous and previous.lastPlayed
  record.chars[char.guid] = char
  record.version = ns.Merge.nextVersion(record.version, now)
  return true
end

-- Sets or clears (nil) the role override of an own character (CF-18). A synced change: bumps the
-- version. Returns true if something changed.
function Snapshot.setRoleOverride(record, guid, override, now)
  local char = guid and record.chars[guid]
  if not char or char.roleOverride == override then return false end
  char.roleOverride = override
  char.role = override or char.autoRole
  record.version = ns.Merge.nextVersion(record.version, now)
  return true
end

-- Records when a character was last played (login, logout). Not a synced-field change:
-- no version bump; the value travels with the next record that is sent anyway.
function Snapshot.markPlayed(record, guid, now)
  local char = guid and record.chars[guid]
  if char then
    char.lastPlayed = now
  end
end

ns.Snapshot = Snapshot
return Snapshot
