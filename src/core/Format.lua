-- Format: turns the Linker view model into the main window's tree and detail models.
-- Pure Lua, no WoW globals. Colors, textures and class names are applied by the UI.
-- Requires ns.Quests (load core/Quests.lua first).
local _, ns = ...

local Format = {}

local MINUTE, HOUR, DAY = 60, 3600, 86400

-- Shortens text to at most maxChars characters, ending in "..." when cut. UTF-8 safe.
function Format.truncate(text, maxChars)
  text = tostring(text)
  local chars = {}
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    chars[#chars + 1] = char
  end
  if #chars <= maxChars then return text end
  return table.concat(chars, "", 1, math.max(1, maxChars - 3)) .. "..."
end

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

-- Secondary professions by skillLine (verified): First Aid 129, Cooking 185, Fishing 356.
local SECONDARY_SKILL_LINES = { [129] = true, [185] = true, [356] = true }

-- Professions sorted by name: { { name, rank, max, fraction } }, fraction in 0..1.
-- filter(skillLine) limits the list when given.
function Format.professionList(professions, filter)
  local list = {}
  for skillLine, p in pairs(professions or {}) do
    if not filter or filter(skillLine) then
      local fraction = 0
      if (p.max or 0) > 0 then fraction = math.min(1, math.max(0, (p.rank or 0) / p.max)) end
      list[#list + 1] = { name = p.name, rank = p.rank, max = p.max, fraction = fraction }
    end
  end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  return list
end

-- Professions grouped: { { title = "Primary", list }, { title = "Secondary", list } }, empty groups left out.
function Format.professionGroups(professions)
  local groups = {}
  local primary = Format.professionList(professions, function(id) return not SECONDARY_SKILL_LINES[id] end)
  local secondary = Format.professionList(professions, function(id) return SECONDARY_SKILL_LINES[id] end)
  if #primary > 0 then groups[#groups + 1] = { title = "Primary", list = primary } end
  if #secondary > 0 then groups[#groups + 1] = { title = "Secondary", list = secondary } end
  return groups
end

-- When a character was last seen: presence (friends), lastPlayed (own), last zone seen
-- in the community, last data change.
local function lastSeen(row)
  local seen = math.max(row.lastSeen or 0, row.lastPlayed or 0, row.lastZoneAt or 0, row.updatedAt or 0)
  return seen > 0 and seen or nil
end

-- "Offline - last seen in The Barrens[ on Alice Example], 2 h ago"; parts are left out when unknown.
local function offlineStatus(row, now, withName)
  local seen = lastSeen(row)
  if not row.lastZone and not seen then return "Offline" end
  local parts = {}
  if row.lastZone then parts[#parts + 1] = "in " .. row.lastZone end
  if withName then parts[#parts + 1] = "on " .. tostring(row.name) end
  local text = "Offline - last seen"
  if #parts > 0 then text = text .. " " .. table.concat(parts, " ") end
  if seen then text = text .. (#parts > 0 and ", " or " ") .. Format.ago(seen, now) end
  return text
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
  { value, text, online, isSelf, count, children = { { value = guid, name, classFile, classID, level, online } } }
People first (Linker order), then an "Unlinked" group when there are unlinked characters.
The UI turns name/classFile into colored text.
]]
-- Your own character rows (CF-19: quests are matched against all of them, alts as of their last login).
local function ownRows(view)
  for _, person in ipairs(view.people) do
    if person.isSelf then return person.chars end
  end
  return {}
end

function Format.tree(view)
  local nodes = {}
  local own = ownRows(view)
  for _, person in ipairs(view.people) do
    local children = {}
    for _, c in ipairs(person.chars) do
      children[#children + 1] = { value = c.guid, name = c.name, classFile = c.classFile, classID = c.classID,
                                  level = c.level, online = c.online, outside = c.outside or false,
                                  sharedDungeon = not person.isSelf and ns.Quests.sharesDungeon(c.quests, own) }
    end
    nodes[#nodes + 1] = { value = groupValue(person), text = personTitle(person), online = person.online,
                          isSelf = person.isSelf, usesAddon = person.usesAddon, count = #children,
                          children = children }
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

-- CF-34: the line on a person's card saying whether they run the addon.
Format.USES_ADDON = "Runs CommunitiesForever."
Format.NO_ADDON = "Does not run CommunitiesForever: only what the community list shows (class, level, zone)."

local function findPerson(view, value)
  for _, person in ipairs(view.people) do
    if groupValue(person) == value then return person end
  end
end

-- own: one of your characters ("played" instead of "seen"). The time is in the stats, not the status.
-- Role names for display (CF-18).
Format.ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }

-- Talents for the character card (CF-18), in the classic notation players use ("Arms 17 / 0 / 0"):
-- { role, roleSource, mainName, numbers = "17 / 0 / 0", treeNames = "Arms · Fury · Protection" }
-- or nil without talent data. mainName is nil without spent points. roleSource is "player"
-- (override) or "talents" (guessed).
function Format.talentSummary(row)
  if type(row.talents) ~= "table" or #row.talents == 0 then return nil end
  local best
  local numbers, names = {}, {}
  for i, tree in ipairs(row.talents) do
    local points = tree.points or 0
    if points > 0 and (not best or points > (row.talents[best].points or 0)) then best = i end
    numbers[#numbers + 1] = tostring(points)
    names[#names + 1] = tostring(tree.name)
  end
  return {
    role = row.role and Format.ROLE_NAMES[row.role] or nil,
    roleSource = row.roleOverride and "player" or "talents",
    mainName = best and row.talents[best].name or nil,
    numbers = table.concat(numbers, " / "),
    treeNames = table.concat(names, " \194\183 "),
  }
end

-- At most this many quest lines on a card unless expanded with "Show all" (CF-19).
Format.MAX_QUEST_LINES = 5

-- Cuts areas from Quests.shared/sharedAcross to MAX_QUEST_LINES quest lines, unless showAll.
local function limitQuests(all, total, showAll)
  local areas, shown = {}, 0
  local limit = showAll and math.huge or Format.MAX_QUEST_LINES
  for _, area in ipairs(all) do
    if shown >= limit then break end
    local quests = {}
    for _, quest in ipairs(area.quests) do
      if shown >= limit then break end
      quests[#quests + 1] = quest
      shown = shown + 1
    end
    areas[#areas + 1] = { area = area.area, dungeon = area.dungeon, quests = quests }
  end
  return { total = total, more = total - shown, areas = areas,
           expandable = total > Format.MAX_QUEST_LINES, showAll = showAll or false }
end

--[[ Quests a friend's character shares with your characters (CF-19), for the character card:
  { total, more, expandable, showAll,
    areas = { { area, dungeon, quests = { { questID, title, ownChars = { { name, classFile } } } } } } }
Dungeon areas first (see Quests.shared). Without showAll only the first MAX_QUEST_LINES quests are listed;
more = the rest. expandable: more than MAX_QUEST_LINES in total (the UI offers Show all / Show fewer).
]]
function Format.sharedQuests(row, own, showAll)
  local all, total = ns.Quests.shared(row.quests, own)
  return limitQuests(all, total, showAll)
end

-- Same for the person card: quests any of the friend's characters shares with yours; each quest also has
-- theirChars = { { name, classFile } } (see Quests.sharedAcross).
function Format.personSharedQuests(rows, own, showAll)
  local all, total = ns.Quests.sharedAcross(rows, own)
  return limitQuests(all, total, showAll)
end

local function characterDetail(row, owner, now, own, sharedWith, showAllQuests)
  local where
  if row.online then
    where = row.zone and row.zone ~= "" and ("Online in " .. row.zone) or "Online"
  elseif row.lastZone then
    where = string.format("Offline - last %s in %s", own and "played" or "seen", row.lastZone)
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
    outside = row.outside or false,
    online = row.online,
    stats = {
      { label = "Level", value = tostring(row.level or "?") },
      { label = "Item level", value = row.ilvl and tostring(row.ilvl) or "-" },
      { label = own and "Last played" or "Last seen", value = Format.seen(row, now) },
    },
    professions = Format.professionGroups(row.professions),
    talents = Format.talentSummary(row),
    -- CF-19: only on a friend's characters (nil on your own and on Unlinked characters).
    sharedQuests = sharedWith and Format.sharedQuests(row, sharedWith, showAllQuests) or nil,
  }
end

--[[ Detail model for the selected tree path, or a message when nothing (valid) is selected:
  { kind = "message", text }
  { kind = "person", title, battleTag, online, status, current,
    source,                            -- "Updated 3 h ago via Alice"
    addon,                             -- CF-34: Format.USES_ADDON / NO_ADDON; nil on your own card
    characters = { { guid, name, classFile, classID, level, seen } },
    sharedQuests }                     -- CF-19: see personSharedQuests; nil on your own card
  { kind = "unlinked", characters = ... }                        -- same character entries
  { kind = "character", guid, name, classFile, classID, owner, status, online, stats,
    professions = { { title, list } },   -- see professionGroups
    talents, sharedQuests }              -- talentSummary; sharedQuests (CF-19) only on a friend's character
showAllQuests: list every shared quest instead of the first MAX_QUEST_LINES.
]]
function Format.detail(view, path, now, showAllQuests)
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
        local friend = person and not person.isSelf
        return characterDetail(row, person and person.displayName or "Unlinked", now, person and person.isSelf,
                               friend and ownRows(view) or nil, showAllQuests)
      end
    end
    return Format.detail(view, nil, now)
  end

  local characters = {}
  for _, row in ipairs(rows) do
    characters[#characters + 1] = { guid = row.guid, name = row.name, classFile = row.classFile,
                                    classID = row.classID, level = row.level, seen = Format.seen(row, now),
                                    role = row.role,
                                    own = person and person.isSelf or false, outside = row.outside or false }
  end
  if not person then
    return { kind = "unlinked", characters = characters }
  end

  local status
  if person.online and person.currentChar then
    status = "Online on " .. tostring(person.currentChar.name) ..
      ((person.currentChar.visible == false or person.currentChar.outside) and " (not in community)" or "")
  elseif person.online then
    status = "Online"
  else
    -- The character seen most recently tells where the person was last.
    local latest, latestAt
    for _, row in ipairs(rows) do
      local at = lastSeen(row) or 0
      if not latest or at > latestAt then latest, latestAt = row, at end
    end
    status = latest and offlineStatus(latest, now, true) or "Offline"
  end
  -- CF-20: a relayed record says who passed it on and how old its data is.
  local source
  if person.via then
    source = person.updatedAt and string.format("Updated %s via %s", Format.ago(person.updatedAt, now),
      tostring(person.viaName)) or ("Via " .. tostring(person.viaName))
  end
  return { kind = "person", title = personTitle(person), battleTag = person.battleTag, online = person.online,
           -- CF-34: who runs the addon; nil on your own card.
           addon = not person.isSelf and (person.usesAddon and Format.USES_ADDON or Format.NO_ADDON) or nil,
           status = status, current = person.currentChar, characters = characters, source = source,
           -- CF-19: all quests the friend shares with you, over all their characters (not on your own card).
           sharedQuests = not person.isSelf and Format.personSharedQuests(rows, ownRows(view), showAllQuests)
             or nil }
end

-- Message for the whole window instead of tree and detail, or nil.
-- state = { passive = bool, selected = bool, active = bool, communityName = string|nil,
--           characterName = string|nil }
-- active is false on a character that is not a member of the selected community; passive: no community on
-- the account and none on this character (see Clubs.passive).
Format.PASSIVE_TEXT = "You're not in a community yet.\n\n"
  .. "CommunitiesForever is for friends who play together without a guild: it works with an in-game "
  .. "community you share. Once this character is in one, the addon sets itself up and shows your friends, "
  .. "their characters, their activity and the dungeons you can run together.\n\n"
  .. "Got an invite link from a friend? Click it in chat and choose Join. Got an invite code? Open Blizzard's "
  .. "Communities window and join with the code. No community yet? Create one there and invite your friends."

function Format.emptyState(view, state)
  if state.passive then
    return Format.PASSIVE_TEXT
  end
  if not state.selected then
    return "Select a community in settings (/cf settings)."
  end
  if not state.active then
    return string.format("Your account has characters in %s, but %s isn't a member, so it can't be shown "
      .. "here. Log in on a member character, or invite this one.", state.communityName or "the selected community",
      state.characterName or "this character")
  end
  if #view.people == 0 and #view.unlinked == 0 then
    return "Nobody in this community yet."
  end
  return nil
end

-- CF-33: who is online, for the minimap button tooltip. Other people only (not yourself), sorted by display
-- name, at most `max` entries. Returns { entries = { { displayName, name, classFile, classID, level }, ... },
-- more = N } with N the people left out.
Format.ONLINE_MAX = 15
Format.NOBODY_ONLINE = "Nobody online right now."

function Format.onlineList(view, max)
  max = max or Format.ONLINE_MAX
  local all = {}
  for _, person in ipairs(view.people or {}) do
    if person.online and not person.isSelf then
      local char = person.currentChar or {}
      all[#all + 1] = { displayName = tostring(person.displayName), name = char.name, classFile = char.classFile,
                        classID = char.classID, level = char.level }
    end
  end
  table.sort(all, function(a, b)
    local x, y = a.displayName:lower(), b.displayName:lower()
    if x ~= y then return x < y end
    return tostring(a.name) < tostring(b.name)
  end)
  local entries = {}
  for i = 1, math.min(#all, max) do entries[i] = all[i] end
  return { entries = entries, more = #all - #entries }
end

-- Login notification (CF-15): "Alice is online on Alice Example (Mage 11)".
-- character = { name, className, level }; className and level are left out when unknown.
function Format.loginNotice(displayName, character)
  local details = {}
  if character.className and character.className ~= "" then details[#details + 1] = character.className end
  if character.level then details[#details + 1] = tostring(character.level) end
  local suffix = #details > 0 and (" (" .. table.concat(details, " ") .. ")") or ""
  return string.format("%s is online on %s%s", tostring(displayName), tostring(character.name), suffix)
end

-- Level-up announcement (CF-16): "Alice's Alice Example reached level 12".
function Format.levelUpNotice(displayName, characterName, level)
  return string.format("%s's %s reached level %s", tostring(displayName), tostring(characterName), tostring(level))
end

Format.TOOLTIP_UNLINKED = "CommunitiesForever member"

-- Tooltip lines for hovered units (CF-14): { [guid] = text } for every character in the view.
-- Linked to someone else: "Alice · 3 characters". Unlinked member: "CommunitiesForever member".
-- Your own characters get no line.
function Format.tooltipLines(view)
  local lines = {}
  for _, person in ipairs(view.people) do
    if not person.isSelf then
      local count = #person.chars
      local text = string.format("%s \194\183 %d character%s", person.displayName, count, count == 1 and "" or "s")
      for _, row in ipairs(person.chars) do
        lines[row.guid] = text
      end
    end
  end
  for _, row in ipairs(view.unlinked) do
    lines[row.guid] = Format.TOOLTIP_UNLINKED
  end
  return lines
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
