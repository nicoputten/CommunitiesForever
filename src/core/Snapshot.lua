-- Snapshot: build and compare character snapshots. Pure Lua, no WoW globals.
-- Requires ns.Merge (load core/Merge.lua first).
local _, ns = ...

local Snapshot = {}

-- Synced scalar Char fields. updatedAt is metadata and never compared.
local SCALAR_FIELDS = { "guid", "name", "classFile", "raceID", "level", "faction", "realm", "ilvl" }

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
  return char
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
  return professionsEqual(a.professions or {}, b.professions or {})
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

  local char = Snapshot.build(info)
  if Snapshot.equal(record.chars[char.guid], char) then
    return false
  end

  char.updatedAt = now
  record.chars[char.guid] = char
  record.version = ns.Merge.nextVersion(record.version, now)
  return true
end

ns.Snapshot = Snapshot
return Snapshot
