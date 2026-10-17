-- Format: turns the Linker view model into flat display rows for the main window.
-- Pure Lua, no WoW globals. Colors and textures are applied by the UI.
local _, ns = ...

local Format = {}

local MINUTE, HOUR, DAY = 60, 3600, 86400

-- "just now", "5 min ago", "3 h ago", "2 d ago"; "never" without a timestamp.
function Format.ago(timestamp, now)
  if not timestamp then return "never" end
  local seconds = math.max(0, now - timestamp)
  if seconds < MINUTE then return "just now" end
  if seconds < HOUR then return string.format("%d min ago", math.floor(seconds / MINUTE)) end
  if seconds < DAY then return string.format("%d h ago", math.floor(seconds / HOUR)) end
  return string.format("%d d ago", math.floor(seconds / DAY))
end

-- "Cooking 2/75, Mining 64/150" sorted by name; "" without professions.
function Format.professions(professions)
  local list = {}
  for _, p in pairs(professions or {}) do
    list[#list + 1] = p
  end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  local parts = {}
  for _, p in ipairs(list) do
    parts[#parts + 1] = string.format("%s %s/%s", tostring(p.name), tostring(p.rank), tostring(p.max))
  end
  return table.concat(parts, ", ")
end

-- Status of a character row: "Online - Durotar", "Seen 3 h ago" or "Offline".
function Format.status(row, now)
  if row.online then
    return row.zone and row.zone ~= "" and ("Online - " .. row.zone) or "Online"
  end
  -- lastPlayed: own characters (login/logout); lastSeen: presence; updatedAt: last data change.
  local seen = math.max(row.lastSeen or 0, row.lastPlayed or 0, row.updatedAt or 0)
  if seen > 0 then
    return "Seen " .. Format.ago(seen, now)
  end
  return "Offline"
end

-- line1 is the text after the (class-colored) name; line2 holds the professions.
-- The realm is not shown: everyone plays the same ruleset (one mega-realm).
local function charLines(row, now)
  local line1 = string.format("Lvl %s%s  %s", tostring(row.level or "?"),
    row.ilvl and ("  iLvl " .. row.ilvl) or "", Format.status(row, now))
  return line1, Format.professions(row.professions)
end

--[[ Flattens the view model into display rows, in order:
  { kind = "empty",   text }                                   -- whole-window empty state
  { kind = "section", text }                                   -- "People", "Unlinked"
  { kind = "spacer" }                                          -- blank line between people
  { kind = "person",  key, text, online, expanded, isSelf, current }  -- clickable header
      current = { name, classFile, classID, outside } or nil: "on <name>", outside = not in community
  { kind = "char",    guid, name, classFile, classID, line1, line2, online }  -- line1 follows the name
  { kind = "note",    text }                                   -- empty state inside a section
state = { communitySelected = bool, collapsed = { [personKey] = true }, now = serverTime }
personKey is the BattleTag, or "self" for own characters without a known BattleTag.
]]
function Format.rows(view, state)
  local rows = {}
  if not state.communitySelected then
    rows[1] = { kind = "empty", text = "Select a community in settings (/cf settings)." }
    return rows
  end

  rows[#rows + 1] = { kind = "section", text = "People" }
  local friendsShown = 0
  for index, person in ipairs(view.people) do
    if not person.isSelf then friendsShown = friendsShown + 1 end
    local key = person.battleTag or "self"
    local expanded = not state.collapsed[key]

    local text = person.displayName
    if person.isSelf then text = text .. " (you)" end
    local current
    if person.online and person.currentChar then
      local c = person.currentChar
      current = { name = c.name, classFile = c.classFile, classID = c.classID, outside = c.visible == false }
    elseif not person.online then
      text = text .. " - offline"
    end

    if index > 1 then rows[#rows + 1] = { kind = "spacer" } end
    rows[#rows + 1] = { kind = "person", key = key, text = text, online = person.online,
                        expanded = expanded, isSelf = person.isSelf, current = current }
    if expanded then
      for _, c in ipairs(person.chars) do
        local line1, line2 = charLines(c, state.now)
        rows[#rows + 1] = { kind = "char", guid = c.guid, name = c.name, classFile = c.classFile,
                            classID = c.classID, line1 = line1, line2 = line2, online = c.online }
      end
    end
  end
  if friendsShown == 0 then
    rows[#rows + 1] = { kind = "note", text = "No linked friends yet." }
  end

  if #view.unlinked > 0 then
    rows[#rows + 1] = { kind = "section", text = "Unlinked" }
    for _, c in ipairs(view.unlinked) do
      local line1 = string.format("Lvl %s  %s", tostring(c.level or "?"),
        c.online and Format.status(c, state.now) or "Offline")
      rows[#rows + 1] = { kind = "char", guid = c.guid, name = c.name, classID = c.classID,
                          line1 = line1, line2 = "", online = c.online }
    end
  end
  return rows
end

ns.Format = Format
return Format
