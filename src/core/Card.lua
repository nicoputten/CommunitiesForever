-- Card: the Friends tab's card models (CF-40; split from Format.lua in CF-59): a person's card, a character's card
-- (tiles, professions, talents, shared quests, the PvP line) and the Unlinked list. Pure Lua, no WoW globals.
-- Requires ns.Format (paths, seen texts, profession lists) and, for the PvP line, ns.Doomsday and ns.DoomsdayView.
local _, ns = ...

local Card = {}
local Format = ns.Format
local findPerson, ownRows = Format.findPerson, Format.ownRows
local lastSeen, offlineStatus, personTitle = Format.lastSeen, Format.offlineStatus, Format.personTitle

-- CF-34: the line on a person's card saying whether they run the addon.
Card.USES_ADDON = "Runs CommunitiesForever."
Card.NO_ADDON = "Does not run CommunitiesForever: only what the community list shows (class, level, zone)."


-- own: one of your characters ("played" instead of "seen"). The time is in the stats, not the status.
-- Role names for display (CF-18).
Card.ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }

-- Talents for the character card (CF-18), in the classic notation players use ("Arms 17 / 0 / 0"):
-- { role, roleSource, mainName, numbers = "17 / 0 / 0", treeNames = "Arms · Fury · Protection" }
-- or nil without talent data. mainName is nil without spent points. roleSource is "player"
-- (override) or "talents" (guessed).
function Card.talentSummary(row)
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
    role = row.role and Card.ROLE_NAMES[row.role] or nil,
    roleSource = row.roleOverride and "player" or "talents",
    mainName = best and row.talents[best].name or nil,
    numbers = table.concat(numbers, " / "),
    treeNames = table.concat(names, " \194\183 "),
  }
end

-- At most this many quest lines on a card unless expanded with "Show all" (CF-19).
Card.MAX_QUEST_LINES = 5

-- Cuts areas from Quests.shared/sharedAcross to MAX_QUEST_LINES quest lines, unless showAll.
local function limitQuests(all, total, showAll)
  local areas, shown = {}, 0
  local limit = showAll and math.huge or Card.MAX_QUEST_LINES
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
           expandable = total > Card.MAX_QUEST_LINES, showAll = showAll or false }
end

--[[ Quests a friend's character shares with your characters (CF-19), for the character card:
  { total, more, expandable, showAll,
    areas = { { area, dungeon, quests = { { questID, title, ownChars = { { name, classFile } } } } } } }
Dungeon areas first (see Quests.shared). Without showAll only the first MAX_QUEST_LINES quests are listed;
more = the rest. expandable: more than MAX_QUEST_LINES in total (the UI offers Show all / Show fewer).
]]
function Card.sharedQuests(row, own, showAll)
  local all, total = ns.Quests.shared(row.quests, own)
  return limitQuests(all, total, showAll)
end

-- Same for the person card: quests any of the friend's characters shares with yours; each quest also has
-- theirChars = { { name, classFile } } (see Quests.sharedAcross).
function Card.personSharedQuests(rows, own, showAll)
  local all, total = ns.Quests.sharedAcross(rows, own)
  return limitQuests(all, total, showAll)
end

-- CF-40: profession bars on the vanilla scale (300): fill = rank, shading up to the current maximum, lines at
-- the training steps 75, 150 and 225; secondary professions are drawn muted.
Card.SKILL_SCALE = 300
Card.SKILL_TICKS = { 0.25, 0.5, 0.75 }

function Card.skillBar(profession, secondary)
  local scale = Card.SKILL_SCALE
  local function part(x) return math.max(0, math.min(1, (x or 0) / scale)) end
  return { fill = part(profession.rank), cap = part(profession.max), ticks = Card.SKILL_TICKS,
           muted = secondary and true or false }
end

-- CF-40: talent trees as bars: points out of 31 (a full tree in vanilla), the tree with the most points marked.
Card.TREE_POINTS = 31

function Card.talentBars(row)
  if type(row.talents) ~= "table" or #row.talents == 0 then return nil end
  local best = 0
  for _, tree in ipairs(row.talents) do best = math.max(best, tree.points or 0) end
  local bars = {}
  for i, tree in ipairs(row.talents) do
    local points = tree.points or 0
    bars[i] = { name = tostring(tree.name), points = points,
                fraction = math.min(1, points / Card.TREE_POINTS), main = points > 0 and points == best }
  end
  return bars
end

-- CF-40: the line under a character's name: "played by <owner>" (or "your character") and where they are:
-- "online in <zone>", "offline, last seen in <zone> 2 h ago".
local function characterSubtitle(row, owner, own, now)
  -- owner nil: an Unlinked character (a community member not linked to a friend).
  local parts = { own and "your character" or (owner and ("played by " .. tostring(owner)) or "community member") }
  if row.online then
    parts[#parts + 1] = row.zone and row.zone ~= "" and ("online in " .. row.zone) or "online"
  else
    local text = "offline"
    local seen = lastSeen(row)
    if row.lastZone then text = text .. ", last " .. (own and "played" or "seen") .. " in " .. row.lastZone end
    if seen then text = text .. (row.lastZone and " " or ", last seen ") .. Format.ago(seen, now) end
    parts[#parts + 1] = text
  end
  if row.outside then parts[#parts + 1] = "not in community" end
  return table.concat(parts, " \194\183 ")
end

-- CF-40: the three tiles: level (with a bar to 60), item level, role (and where it comes from).
Card.MAX_LEVEL = 60

local function characterTiles(row, talents)
  local role = talents and talents.role
  return {
    { label = "Level", value = tostring(row.level or "?"),
      fraction = row.level and math.min(1, row.level / Card.MAX_LEVEL) or nil },
    { label = "Item level", value = row.ilvl and tostring(row.ilvl) or "-" },
    { label = "Role", value = role or "-",
      note = role and (talents.roleSource == "player" and "set by player" or "from talents") or nil },
  }
end

-- CF-57: this week's PvP kill points of one character from its owner's feed (view.doomsday: schedule, community).
local function weekKillPoints(feed, guid, dd, now)
  if not (feed and dd and dd.schedule) then return 0 end
  local D = ns.Doomsday
  local week = D.week(D.day(now, dd.schedule.offset, dd.schedule.reset))
  local kills = {}
  for _, chars in pairs(feed) do
    local e = type(chars) == "table" and chars[guid]
    for _, k in ipairs(e and e.pvpKills or {}) do kills[#kills + 1] = k end
  end
  local points = 0
  for _, s in ipairs(D.scoreKills(kills, dd.schedule, dd.community)) do
    if s.track == "pvp" and D.week(s.day) == week then points = points + s.points end
  end
  return points
end

local function characterDetail(row, owner, now, own, sharedWith, showAllQuests, person, dd)
  local talents = Card.talentSummary(row)
  return {
    kind = "character",
    guid = row.guid,
    name = row.name,
    classFile = row.classFile,
    classID = row.classID,
    outside = row.outside or false,
    online = row.online,
    professions = Format.professionGroups(row.professions),
    talents = talents,
    subtitle = characterSubtitle(row, owner, own, now), -- CF-40
    tiles = characterTiles(row, talents),
    talentBars = Card.talentBars(row),
    -- CF-19: only on a friend's characters (nil on your own and on Unlinked characters).
    sharedQuests = sharedWith and Card.sharedQuests(row, sharedWith, showAllQuests) or nil,
    -- CF-57: "Stone Guard, a.k.a. Mailbox Menace · 1,234 honorable kills · PvP 40 this week" or "PvP Virgin".
    pvp = row.pvp ~= nil and ns.DoomsdayView.pvpLine(row.pvp, row.factionName,
      weekKillPoints(person and person.feed, row.guid, dd, now)) or nil,
  }
end

--[[ Detail model for the selected tree path, or a message when nothing (valid) is selected:
  { kind = "message", text }
  { kind = "person", title, battleTag, online, status, current,
    source,                            -- "Updated 3 h ago via Alice"
    addon,                             -- CF-34: Card.USES_ADDON / NO_ADDON; nil on your own card
    characters = { { guid, name, classFile, classID, level, seen } },
    sharedQuests }                     -- CF-19: see personSharedQuests; nil on your own card
  { kind = "unlinked", characters = ... }                        -- same character entries
  { kind = "character", guid, name, classFile, classID, outside, online,
    professions = { { title, list } },   -- see professionGroups
    talents,                             -- talentSummary
    subtitle, tiles, talentBars,         -- CF-40: the line under the name, Level/Item level/Role, tree bars
    sharedQuests }                       -- CF-19: only on a friend's character
showAllQuests: list every shared quest instead of the first MAX_QUEST_LINES.
]]
-- CF-62: "Mining 240 · Blacksmithing 225" (highest first), or nil without professions.
function Card.professionsText(professions)
  local list = {}
  for _, p in pairs(professions or {}) do
    if type(p) == "table" and p.name then list[#list + 1] = p end
  end
  table.sort(list, function(a, b)
    if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  local parts = {}
  for _, p in ipairs(list) do parts[#parts + 1] = string.format("%s %d", p.name, p.rank or 0) end
  return #parts > 0 and table.concat(parts, " \194\183 ") or nil
end

-- CF-62: a friend known only from the website (Format.SITE path): their characters as the site saw them.
local function websiteDetail(siteFriends, name, now)
  for _, f in ipairs(siteFriends or {}) do
    if f.name == name then
      local characters = {}
      for _, c in ipairs(f.chars) do
        characters[#characters + 1] = { name = c.name, realm = c.realm, classFile = c.classFile, level = c.level,
                                        seen = c.seenAt and Format.ago(c.seenAt, now) or nil, website = true }
      end
      return { kind = "website", title = f.name, status = "from the website", characters = characters }
    end
  end
  return nil
end

function Card.detail(view, path, now, showAllQuests, siteFriends)
  if not path then
    return { kind = "message", text = "Select a person or character on the left." }
  end
  if path:sub(1, #Format.SITE) == Format.SITE then
    return websiteDetail(siteFriends, path:sub(#Format.SITE + 1), now) or Card.detail(view, nil, now)
  end
  local group, guid = Format.splitPath(path)

  local rows, person
  if group == Format.UNLINKED then
    rows = view.unlinked
  else
    person = findPerson(view, group)
    if not person then return Card.detail(view, nil, now) end
    rows = person.chars
  end

  if guid then
    for _, row in ipairs(rows) do
      if row.guid == guid then
        local friend = person and not person.isSelf
        return characterDetail(row, person and person.displayName, now, person and person.isSelf,
                               friend and ownRows(view) or nil, showAllQuests, person, view.doomsday)
      end
    end
    return Card.detail(view, nil, now)
  end

  local characters = {}
  for _, row in ipairs(rows) do
    characters[#characters + 1] = { guid = row.guid, name = row.name, classFile = row.classFile,
                                    classID = row.classID, level = row.level, seen = Format.seen(row, now),
                                    role = row.role,
                                    own = person and person.isSelf or false, outside = row.outside or false,
                                    -- CF-62: the character cards
                                    realm = row.realm, zone = row.zone or row.lastZone,
                                    professions = Card.professionsText(row.professions) }
  end
  if not person then
    return { kind = "unlinked", characters = characters }
  end

  local status
  if person.online and person.currentChar then
    local zone = person.currentChar.zone
    status = "Online on " .. tostring(person.currentChar.name) .. (zone and (" \194\183 " .. zone) or "") ..
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
  -- CF-62: no BattleTag on the card (not even your own); "You" for yourself.
  return { kind = "person", title = personTitle(person), isSelf = person.isSelf, online = person.online,
           -- CF-34: who runs the addon; nil on your own card.
           addon = not person.isSelf and (person.usesAddon and Card.USES_ADDON or Card.NO_ADDON) or nil,
           status = status, current = person.currentChar, characters = characters, source = source,
           -- CF-19: all quests the friend shares with you, over all their characters (not on your own card).
           sharedQuests = not person.isSelf and Card.personSharedQuests(rows, ownRows(view), showAllQuests)
             or nil }
end

ns.Card = Card
return Card
