-- Clubs: which communities can be selected, and whether the stored one still exists.
-- Pure Lua, no WoW globals. Club entries: { clubId, name, clubType }.
local _, ns = ...

local Clubs = {}

-- types: the selectable club types, a set { [clubType] = true } (CF-83: character communities and the guild)
-- or a single clubType.
local function allowed(types, clubType)
  if type(types) == "table" then return clubType ~= nil and types[clubType] == true end
  return clubType == types
end

-- Selectable clubs (character communities and the guild, see ARCHITECTURE), sorted by name, then clubId.
-- Entries: { clubId, name, clubType }.
function Clubs.selectable(clubs, types)
  local list = {}
  for _, club in ipairs(clubs or {}) do
    if allowed(types, club.clubType) and club.clubId ~= nil then
      list[#list + 1] = { clubId = club.clubId, name = club.name or tostring(club.clubId), clubType = club.clubType }
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
--   "unknown" stored club not found, but club data may not be loaded yet (empty list, not loaded), or a club's id
--             or type is hidden (nil, CF-119)
function Clubs.status(storedId, clubs, types, loaded)
  if storedId == nil then
    return "none"
  end
  local selectable = Clubs.selectable(clubs, types)
  for _, club in ipairs(selectable) do
    if club.clubId == storedId then return "ok" end
  end
  -- CF-119: a club whose id or type the game hides (nil) may be the stored one: not "missing" yet.
  for _, club in ipairs(clubs or {}) do
    if club.clubId == nil or club.clubType == nil then return "unknown" end
  end
  if loaded or #(clubs or {}) > 0 then
    return "missing"
  end
  return "unknown"
end

-- True when the addon has nothing to work with: no community chosen for the account and this character is
-- in no character community and no guild either. The addon then stays passive (no setup, sync, notices or minimap
-- button) until a community appears.
function Clubs.passive(storedId, clubs, types)
  return storedId == nil and #Clubs.selectable(clubs, types) == 0
end

ns.Clubs = Clubs
return Clubs
