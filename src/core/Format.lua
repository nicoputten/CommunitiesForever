-- Format: turns the Linker view model into the main window's tree and detail models.
-- Pure Lua, no WoW globals. Colors, textures and class names are applied by the UI.
local _, ns = ...

local Format = {}

local MINUTE, HOUR, DAY = 60, 3600, 86400

-- Tree value of the Unlinked group, and of own characters without a known BattleTag.
Format.UNLINKED = "~unlinked" -- BattleTags never start with "~"
Format.SELF = "~self"

-- Separator AceGUI TreeGroup uses between path parts ("parent\001child").
local PATH_SEPARATOR = "\001"

-- "just now", "5 min ago", "3 h ago", "2 d ago"; "never" without a timestamp.
function Format.ago(timestamp, now)
  if not timestamp then return "never" end
  local seconds = math.max(0, now - timestamp)
  if seconds < MINUTE then return "just now" end
  if seconds < HOUR then return string.format("%d min ago", math.floor(seconds / MINUTE)) end
  if seconds < DAY then return string.format("%d h ago", math.floor(seconds / HOUR)) end
  return string.format("%d d ago", math.floor(seconds / DAY))
end

-- Professions sorted by name: { { name, rank, max, fraction } }, fraction in 0..1.
function Format.professionList(professions)
  local list = {}
  for _, p in pairs(professions or {}) do
    local fraction = 0
    if (p.max or 0) > 0 then fraction = math.min(1, math.max(0, (p.rank or 0) / p.max)) end
    list[#list + 1] = { name = p.name, rank = p.rank, max = p.max, fraction = fraction }
  end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  return list
end

-- When a character was last seen: presence (friends), lastPlayed (own), last data change.
local function lastSeen(row)
  local seen = math.max(row.lastSeen or 0, row.lastPlayed or 0, row.updatedAt or 0)
  return seen > 0 and seen or nil
end

-- "Now" when online, else "3 h ago" / "never".
function Format.seen(row, now)
  if row.online then return "Now" end
  return Format.ago(lastSeen(row), now)
end

-- Unique tree path of a character under its group.
function Format.path(groupValue, guid)
  return groupValue .. PATH_SEPARATOR .. guid
end

-- Splits a TreeGroup path into group value and character GUID (nil for a group).
function Format.splitPath(path)
  local group, guid = path:match("^([^\001]+)\001(.+)$")
  if group then return group, guid end
  return path, nil
end

local function groupValue(person)
  return person.battleTag or Format.SELF
end

local function personTitle(person)
  return person.isSelf and (person.displayName .. " (you)") or person.displayName
end

--[[ Tree for AceGUI TreeGroup. Each node:
  { value, text, online, isSelf, children = { { value = guid, name, classFile, classID, level, online } } }
People first (Linker order), then an "Unlinked" group when there are unlinked characters.
The UI turns name/classFile into colored text.
]]
function Format.tree(view)
  local nodes = {}
  for _, person in ipairs(view.people) do
    local children = {}
    for _, c in ipairs(person.chars) do
      children[#children + 1] = { value = c.guid, name = c.name, classFile = c.classFile, classID = c.classID,
                                  level = c.level, online = c.online }
    end
    nodes[#nodes + 1] = { value = groupValue(person), text = personTitle(person), online = person.online,
                          isSelf = person.isSelf, children = children }
  end
  if #view.unlinked > 0 then
    local children = {}
    for _, c in ipairs(view.unlinked) do
      children[#children + 1] = { value = c.guid, name = c.name, classID = c.classID, level = c.level,
                                  online = c.online }
    end
    nodes[#nodes + 1] = { value = Format.UNLINKED, text = "Unlinked", unlinked = true, children = children }
  end
  return nodes
end

local function findPerson(view, value)
  for _, person in ipairs(view.people) do
    if groupValue(person) == value then return person end
  end
end

local function characterDetail(row, owner, now)
  local where
  if row.online then
    where = row.zone and row.zone ~= "" and ("Online in " .. row.zone) or "Online"
  else
    where = "Offline"
  end
  return {
    kind = "character",
    guid = row.guid,
    name = row.name,
    classFile = row.classFile,
    classID = row.classID,
    owner = owner,
    status = where,
    online = row.online,
    stats = {
      { label = "Level", value = tostring(row.level or "?") },
      { label = "Item level", value = row.ilvl and tostring(row.ilvl) or "-" },
      { label = "Last seen", value = Format.seen(row, now) },
    },
    professions = Format.professionList(row.professions),
  }
end

--[[ Detail model for the selected tree path, or a message when nothing (valid) is selected:
  { kind = "message", text }
  { kind = "person", title, battleTag, online, status, current,
    characters = { { guid, name, classFile, classID, level, seen } } }
  { kind = "unlinked", characters = ... }                        -- same character entries
  { kind = "character", guid, name, classFile, classID, owner, status, online, stats, professions }
]]
function Format.detail(view, path, now)
  if not path then
    return { kind = "message", text = "Select a person or character on the left." }
  end
  local group, guid = Format.splitPath(path)

  local rows, person
  if group == Format.UNLINKED then
    rows = view.unlinked
  else
    person = findPerson(view, group)
    if not person then return Format.detail(view, nil, now) end
    rows = person.chars
  end

  if guid then
    for _, row in ipairs(rows) do
      if row.guid == guid then
        return characterDetail(row, person and person.displayName or "Unlinked", now)
      end
    end
    return Format.detail(view, nil, now)
  end

  local characters = {}
  for _, row in ipairs(rows) do
    characters[#characters + 1] = { guid = row.guid, name = row.name, classFile = row.classFile,
                                    classID = row.classID, level = row.level, seen = Format.seen(row, now) }
  end
  if not person then
    return { kind = "unlinked", characters = characters }
  end

  local status
  if person.online and person.currentChar then
    status = "Online on " .. tostring(person.currentChar.name) ..
      (person.currentChar.visible == false and " (not in community)" or "")
  elseif person.online then
    status = "Online"
  else
    status = "Offline"
  end
  return { kind = "person", title = personTitle(person), battleTag = person.battleTag, online = person.online,
           status = status, current = person.currentChar, characters = characters }
end

-- Message for the whole window instead of tree and detail, or nil.
function Format.emptyState(view, communitySelected)
  if not communitySelected then
    return "Select a community in settings (/cf settings)."
  end
  if #view.people == 0 and #view.unlinked == 0 then
    return "Nobody in this community yet."
  end
  return nil
end

-- Hint shown under the detail when only you are linked so far.
function Format.friendsHint(view)
  for _, person in ipairs(view.people) do
    if not person.isSelf then return nil end
  end
  return "No linked friends yet. Friends show up when they log in while you are online, or when they run the addon."
end

ns.Format = Format
return Format
