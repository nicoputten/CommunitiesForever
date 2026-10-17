-- Linker: visibility + linking -> view model (ARCHITECTURE core rules 1-3).
-- Pure Lua, no WoW globals.
local _, ns = ...

local Linker = {}

-- C_Club member presence values that mean "in game" (Enum.ClubMemberPresence:
-- 1 Online, 4 Away, 5 Busy; 2 OnlineMobile and 3 Offline are not in game).
local IN_GAME_PRESENCE = { [1] = true, [4] = true, [5] = true }

-- Internal grouping key for own characters while the own BattleTag is unknown.
local SELF_KEY = "\0self"

-- Display name priority: local nickname > owner's displayName > BattleTag name part.
function Linker.displayName(battleTag, ownerDisplayName, nickname)
  if nickname and nickname ~= "" then return nickname end
  if ownerDisplayName and ownerDisplayName ~= "" then return ownerDisplayName end
  return (tostring(battleTag):match("^([^#]+)")) or tostring(battleTag)
end

-- Picks the BattleTag a visible character links to, or nil (unlinked), plus the link source.
-- Order: own character > presence (if a current friend) > a current friend's record.
-- Several records claiming the GUID: newest char.updatedAt wins, then BattleTag order.
local function linkFor(guid, input)
  local self = input.self or {}
  if guid == input.selfGuid or (self.chars and self.chars[guid]) then
    return self.battleTag, "self"
  end

  local p = input.presence[guid]
  if p and input.friends[p.battleTag] then
    return p.battleTag, "presence"
  end

  local best, bestUpdated
  for bt, person in pairs(input.people) do
    local char = input.friends[bt] and person.chars and person.chars[guid]
    if char then
      local updated = char.updatedAt or 0
      if not best or updated > bestUpdated or (updated == bestUpdated and bt < best) then
        best, bestUpdated = bt, updated
      end
    end
  end
  if best then
    return best, "record"
  end
  return nil
end

local function recordFor(guid, bt, input)
  if bt == nil then return nil end
  local self = input.self or {}
  if bt == self.battleTag and self.chars and self.chars[guid] then
    return self.chars[guid]
  end
  local person = input.people[bt]
  return person and person.chars and person.chars[guid]
end

-- Row for a visible character: live community data plus record data when available.
local function charRow(guid, member, record, presence, source)
  record = record or {}
  return {
    guid = guid,
    name = member.name or record.name,
    classID = member.classID,
    classFile = record.classFile,
    level = member.level or record.level,
    raceID = member.raceID or record.raceID,
    zone = member.zone,
    online = IN_GAME_PRESENCE[member.presence] == true,
    ilvl = record.ilvl,
    professions = record.professions,
    realm = record.realm,
    updatedAt = record.updatedAt,
    lastSeen = presence and presence.lastSeen,
    linkSource = source,
  }
end

local function byOnlineThenName(a, b)
  if a.online ~= b.online then return a.online end
  local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
  if na ~= nb then return na < nb end
  return a.guid < b.guid
end

--[[ Builds the view model.
input = {
  members   = { [guid] = { name, classID, level, zone, presence, raceID, faction } },  -- selected community
  friends   = { [battleTag] = true },                                                -- current BNet friends
  online    = { [battleTag] = { guid, name, className, level, gameAccountID } },      -- friends in Forever now
  people    = { [battleTag] = { displayName, version, chars = { [guid] = Char } } },  -- accepted records
  presence  = { [guid] = { battleTag, lastSeen } },
  self      = { battleTag, displayName, chars = { [guid] = Char } },
  selfGuid  = current character GUID,
  nicknames = { [battleTag] = "Name" },
}
returns {
  people   = { { battleTag, displayName, isSelf, online, currentChar, chars = { row, ... } }, ... },
  unlinked = { row, ... },
}
Only people with at least one visible (community member) character are listed.
currentChar is the visible row of the character they are on now, or a minimal
{ guid, name, className, level, visible = false } when that character is not in the community.
]]
function Linker.build(raw)
  local self = raw.self or {}
  -- Own characters group under this key even when the BattleTag is unknown (BNet offline).
  local selfKey = self.battleTag or SELF_KEY
  local input = {
    members = raw.members or {},
    friends = raw.friends or {},
    online = raw.online or {},
    people = raw.people or {},
    presence = raw.presence or {},
    nicknames = raw.nicknames or {},
    self = { battleTag = selfKey, displayName = self.displayName, chars = self.chars or {} },
    selfGuid = raw.selfGuid,
  }
  self = input.self

  local byTag, unlinked = {}, {}
  for guid, member in pairs(input.members) do
    local bt, source = linkFor(guid, input)
    local row = charRow(guid, member, recordFor(guid, bt, input), input.presence[guid], source)
    if bt then
      byTag[bt] = byTag[bt] or {}
      table.insert(byTag[bt], row)
    else
      row.linkSource = nil
      unlinked[#unlinked + 1] = row
    end
  end

  local people = {}
  for bt, rows in pairs(byTag) do
    table.sort(rows, byOnlineThenName)
    local isSelf = bt == self.battleTag
    local ownerName = isSelf and self.displayName or (input.people[bt] and input.people[bt].displayName)

    local currentGuid, current
    if isSelf then
      currentGuid = input.selfGuid
    elseif input.online[bt] then
      currentGuid = input.online[bt].guid
    end
    for _, row in ipairs(rows) do
      if row.guid == currentGuid then current = row end
    end
    if currentGuid and not current and input.online[bt] then
      local o = input.online[bt]
      current = { guid = o.guid, name = o.name, className = o.className, level = o.level, visible = false }
    end

    local displayName
    if bt == SELF_KEY then
      displayName = (ownerName and ownerName ~= "") and ownerName or "You"
    else
      displayName = Linker.displayName(bt, ownerName, input.nicknames[bt])
    end

    people[#people + 1] = {
      battleTag = bt ~= SELF_KEY and bt or nil,
      displayName = displayName,
      isSelf = isSelf,
      online = isSelf or input.online[bt] ~= nil,
      currentChar = current,
      chars = rows,
    }
  end

  table.sort(people, function(a, b)
    if a.online ~= b.online then return a.online end
    local na, nb = a.displayName:lower(), b.displayName:lower()
    if na ~= nb then return na < nb end
    return (a.battleTag or "") < (b.battleTag or "")
  end)
  table.sort(unlinked, byOnlineThenName)

  return { people = people, unlinked = unlinked }
end

ns.Linker = Linker
return Linker
