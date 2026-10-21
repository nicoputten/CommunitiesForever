-- Clubs: which communities can be selected, and whether the stored one still exists.
-- Pure Lua, no WoW globals. Club entries: { clubId, name, clubType }.
local _, ns = ...

local Clubs = {}

-- Selectable clubs (only characterType, see ARCHITECTURE), sorted by name, then clubId.
function Clubs.selectable(clubs, characterType)
  local list = {}
  for _, club in ipairs(clubs or {}) do
    if club.clubType == characterType and club.clubId ~= nil then
      list[#list + 1] = { clubId = club.clubId, name = club.name or tostring(club.clubId) }
    end
  end
  table.sort(list, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return tostring(a.clubId) < tostring(b.clubId)
  end)
  return list
end

-- Status of the stored selection:
--   "none"    nothing stored
--   "ok"      stored club is selectable
--   "missing" club data is loaded and the stored club is not among the selectable clubs
--   "unknown" stored club not found, but club data may not be loaded yet (empty list, not loaded)
function Clubs.status(storedId, clubs, characterType, loaded)
  if storedId == nil then
    return "none"
  end
  local selectable = Clubs.selectable(clubs, characterType)
  for _, club in ipairs(selectable) do
    if club.clubId == storedId then return "ok" end
  end
  if loaded or #(clubs or {}) > 0 then
    return "missing"
  end
  return "unknown"
end

-- True when the addon has nothing to work with: no community chosen for the account and this character is
-- in no character community either. The addon then stays passive (no setup, sync, notices or minimap
-- button) until a community appears.
function Clubs.passive(storedId, clubs, characterType)
  return storedId == nil and #Clubs.selectable(clubs, characterType) == 0
end

ns.Clubs = Clubs
return Clubs
