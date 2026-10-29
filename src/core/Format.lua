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

-- Separator between path parts (the AceGUI tree's, so stored selections keep working) ("parent\001child").
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

-- CF-62: "You" for yourself (no BattleTag or display name of your own in the window).
local function personTitle(person)
  return person.isSelf and "You" or person.displayName
end

Format.SITE = "site:" -- CF-62: the list value prefix of a friend known only from the website

--[[ The Friends list (CF-40): people and their characters. Each node:
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

function Format.tree(view, siteFriends)
  local online, offline = {}, {}
  local own = ownRows(view)
  local synced = {}
  for _, person in ipairs(view.people) do
    if person.displayName then synced[person.displayName:lower()] = true end
    local children = {}
    for _, c in ipairs(person.chars) do
      local _, shared = nil, nil
      if not person.isSelf then _, shared = ns.Quests.shared(c.quests, own) end
      children[#children + 1] = { value = c.guid, name = c.name, classFile = c.classFile, classID = c.classID,
                                  level = c.level, online = c.online, outside = c.outside or false,
                                  shared = shared } -- CF-40: quests shared with you (friends' characters only)
    end
    -- CF-62: grouped "Online" then "Offline" (you count as online), keeping the Linker order within.
    local isOnline = person.online or person.isSelf or false
    local list = isOnline and online or offline
    list[#list + 1] = { value = groupValue(person), text = personTitle(person), online = person.online,
                        isSelf = person.isSelf, usesAddon = person.usesAddon, count = #children,
                        children = children, section = isOnline and "online" or "offline" }
  end
  local nodes = {}
  for _, n in ipairs(online) do nodes[#nodes + 1] = n end
  for _, n in ipairs(offline) do nodes[#nodes + 1] = n end
  -- CF-62: friends the website knows who haven't synced (CF-65: under "From the website", their character count).
  for _, f in ipairs(siteFriends or {}) do
    if not synced[f.name:lower()] then
      nodes[#nodes + 1] = { value = Format.SITE .. f.name, text = f.name, website = true, count = #f.chars,
                            children = {}, section = "website" }
    end
  end
  if #view.unlinked > 0 then
    local children = {}
    for _, c in ipairs(view.unlinked) do
      children[#children + 1] = { value = c.guid, name = c.name, classID = c.classID, level = c.level,
                                  online = c.online }
    end
    nodes[#nodes + 1] = { value = Format.UNLINKED, text = "Unlinked", unlinked = true, children = children,
                          section = "unlinked" }
  end
  return nodes
end

-- CF-62: the list's section headers: "Online · 2", "Offline · 1", "From the website · 6" (CF-65, was "Not synced
-- yet"; nil for Unlinked).
function Format.sectionTitle(section, count)
  local titles = { online = "Online", offline = "Offline", website = "From the website" }
  return titles[section] and string.format("%s \194\183 %d", titles[section], count) or nil
end

-- CF-62: friends whose record arrived this session (since `since`, server time), and the newest arrival.
local function syncedSince(view, since)
  local count, newest = 0, nil
  for _, person in ipairs(view.people or {}) do
    local at = person.receivedAt
    if not person.isSelf and type(at) == "number" and at >= (since or 0) then
      count = count + 1
      if not newest or at > newest then newest = at end
    end
  end
  return count, newest
end

--[[ CF-62 (was "Synced with <person> 2 min ago" / "Not synced yet", CF-42): "Synced with 2 friends · 22:41" (the
newest arrival in your clock), or "Synced with 0 friends · waiting for someone online". since: the session's start;
clock(t): "22:41". ]]
function Format.syncedText(view, since, clock)
  local count, newest = syncedSince(view, since)
  if count == 0 then return "Synced with 0 friends \194\183 waiting for someone online" end
  return string.format("Synced with %d friend%s \194\183 %s", count, count == 1 and "" or "s",
    clock and clock(newest) or "")
end

-- CF-62: the Friends tab footer: "Synced with 2 friends this session · 3 of your characters" (your own characters,
-- never "0 characters from 0 friends").
function Format.friendsFooter(view, since)
  local count = syncedSince(view, since)
  local own = 0
  for _, person in ipairs(view.people or {}) do
    if person.isSelf then own = #(person.chars or {}) end
  end
  return string.format("Synced with %d friend%s this session \194\183 %d of your character%s", count,
    count == 1 and "" or "s", own, own == 1 and "" or "s")
end

function Format.findPerson(view, value)
  for _, person in ipairs(view.people) do
    if groupValue(person) == value then return person end
  end
end
local findPerson = Format.findPerson

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

--[[ CF-37: the right-click menu for a tree path (a person or a character), or nil when there is none (your
own rows, the Unlinked header). { title, items = { { label, action = "whisper"|"invite", name, battleTag,
enabled } } }. A person's items act on the character they are on now; offline, or a character that is not
online: the items are disabled and the title says Offline. ]]
Format.MENU_WHISPER, Format.MENU_INVITE = "Whisper", "Invite to group"

local function menuItems(name, battleTag, enabled)
  return {
    { label = Format.MENU_WHISPER, action = "whisper", name = name, battleTag = battleTag, enabled = enabled },
    { label = Format.MENU_INVITE, action = "invite", name = name, battleTag = battleTag, enabled = enabled },
  }
end

function Format.contextMenu(view, path)
  if type(path) ~= "string" then return nil end
  local group, guid = Format.splitPath(path)
  local person = group ~= Format.UNLINKED and findPerson(view, group) or nil
  if person and person.isSelf then return nil end
  if not guid then
    if not person then return nil end
    local current = person.online and person.currentChar or nil
    local name = current and current.name
    if not name then
      return { title = tostring(person.displayName) .. " - Offline", items = menuItems(nil, person.battleTag, false) }
    end
    return { title = string.format("%s (on %s)", tostring(person.displayName), name),
             items = menuItems(name, person.battleTag, true) }
  end
  local rows = person and person.chars or view.unlinked or {}
  for _, row in ipairs(rows) do
    if row.guid == guid then
      local online = row.online == true
      return { title = tostring(row.name) .. (online and "" or " - Offline"),
               items = menuItems(row.name, person and person.battleTag, online) }
    end
  end
  return nil
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

-- CF-59: shared with core/Card.lua.
Format.ownRows, Format.lastSeen, Format.offlineStatus, Format.personTitle = ownRows, lastSeen, offlineStatus,
  personTitle

ns.Format = Format
return Format
