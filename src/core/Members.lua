-- Members: community member map keyed by GUID. Pure Lua, no WoW globals.
local _, ns = ...

local Members = {}

local FIELDS = { "name", "classID", "level", "zone", "presence", "raceID", "faction" }

-- Builds members[guid] = { name, classID, level, zone, presence, raceID, faction }
-- from raw C_Club member infos. Members without a GUID are skipped (GUID is the key).
-- The C_Club field `race` becomes raceID.
function Members.build(infos)
  local members = {}
  for _, info in ipairs(infos or {}) do
    if info.guid then
      members[info.guid] = {
        name = info.name,
        classID = info.classID,
        level = info.level,
        zone = info.zone,
        presence = info.presence,
        raceID = info.race,
        faction = info.faction,
      }
    end
  end
  return members
end

-- True if both maps have the same GUIDs with identical fields.
function Members.equal(a, b)
  for guid, ma in pairs(a) do
    local mb = b[guid]
    if not mb then return false end
    for _, field in ipairs(FIELDS) do
      if ma[field] ~= mb[field] then return false end
    end
  end
  for guid in pairs(b) do
    if not a[guid] then return false end
  end
  return true
end

-- Same "in game" presence values as core/Linker.lua (Online, Away, Busy).
local IN_GAME_PRESENCE = { [1] = true, [4] = true, [5] = true }

-- Remembers where in-game members are: locations[guid] = { zone, seenAt }.
-- Kept after they log off, so "last seen in <zone>" can be shown. Local only, never synced.
function Members.recordLocations(locations, members, now)
  for guid, m in pairs(members) do
    if IN_GAME_PRESENCE[m.presence] and m.zone and m.zone ~= "" then
      locations[guid] = { zone = m.zone, seenAt = now }
    end
  end
end

ns.Members = Members
return Members
