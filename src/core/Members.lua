-- Members: community member map keyed by GUID. Pure Lua, no WoW globals.
local _, ns = ...

local Members = {}

local FIELDS = { "name", "classID", "level", "zone", "presence", "raceID", "faction", "role" }

-- Builds members[guid] = { name, classID, level, zone, presence, raceID, faction, role }
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
        role = info.role,             -- 1 Owner, 2 Leader, 3 Moderator, 4 Member (CF-21)
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

--[[ CF-111: records the own character's zone, read with the own API at login, at a zone change and at logout (the
member list sends no event for those). Same shape as recordLocations: locations[guid] = { zone, seenAt }. Keeps the
old entry when the GUID or the zone is not a non-empty string (the adapter passes nil for a secret or not yet loaded
zone) and never moves seenAt back. Returns true when it wrote. ]]
function Members.recordOwn(locations, guid, zone, now)
  if type(locations) ~= "table" or type(now) ~= "number" then return false end
  if type(guid) ~= "string" or guid == "" or type(zone) ~= "string" or zone == "" then return false end
  local old = locations[guid]
  if type(old) == "table" and type(old.seenAt) == "number" and old.seenAt > now then return false end
  locations[guid] = { zone = zone, seenAt = now }
  return true
end

--[[ CF-123: the level to show for a character known from the member list (C_Club, cached by the game: it can stay
behind after a level-up) and from a synced record (sent at every level-up). Levels only rise, so the higher one;
the one that is a number when only one is; nil when neither is. ]]
function Members.level(rosterLevel, recordLevel)
  local a = type(rosterLevel) == "number" and rosterLevel or nil
  local b = type(recordLevel) == "number" and recordLevel or nil
  if a and b then return a > b and a or b end
  return a or b
end

ns.Members = Members
return Members
