-- Linker: visibility + linking -> view model (ARCHITECTURE core rules 1-3).
-- Pure Lua, no WoW globals.
local _, ns = ...

local Linker = {}

-- C_Club member presence values that mean "in game" (Enum.ClubMemberPresence:
-- 1 Online, 4 Away, 5 Busy; 2 OnlineMobile and 3 Offline are not in game).
local IN_GAME_PRESENCE = { [1] = true, [4] = true, [5] = true }

-- Internal grouping key for own characters while the own BattleTag is unknown.
local SELF_KEY = "\0self"

-- Display name priority: owner's displayName > BattleTag name part.
function Linker.displayName(battleTag, ownerDisplayName)
  if ownerDisplayName and ownerDisplayName ~= "" then return ownerDisplayName end
  return (tostring(battleTag):match("^([^#]+)")) or tostring(battleTag)
end

-- Who relayed a record: a person's display name, or (CF-28) the community member's character name.
local function viaDisplayName(via, input)
  local guid = type(via) == "string" and via:match("^member:(.+)$")
  if guid then
    local member = input.members[guid]
    return member and member.name or "a community member"
  end
  return Linker.displayName(via, input.people[via] and input.people[via].displayName)
end

local function trusted(bt, person, input)
  return input.friends[bt] or person.via or (type(bt) == "string" and bt:sub(1, 4) == "aid:")
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
    -- A friend's own record, a record relayed by a friend (CF-20), or one that came over the community
    -- (CF-28, "aid:" key): trust is the community.
    local char = trusted(bt, person, input) and person.chars and person.chars[guid]
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
local function charRow(guid, member, record, presence, location, source)
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
    talents = record.talents,         -- CF-18
    quests = record.quests,           -- CF-19
    role = record.role,
    roleOverride = record.roleOverride,
    realm = record.realm,
    updatedAt = record.updatedAt,
    lastPlayed = record.lastPlayed,
    lastSeen = presence and presence.lastSeen,
    lastZone = location and location.zone,
    lastZoneAt = location and location.seenAt,
    linkSource = source,
  }
end

-- Community characters first, then alts outside the community (CF-17); online first, then name.
local function byOnlineThenName(a, b)
  if (a.outside or false) ~= (b.outside or false) then return not a.outside end
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
  locations = { [guid] = { zone, seenAt } },                                       -- last zone seen
  self      = { battleTag, displayName, chars = { [guid] = Char } },
  selfGuid  = current character GUID,
}
returns {
  people   = { { battleTag, displayName, isSelf, online, usesAddon, currentChar, chars = { row, ... },
                 via, viaName, updatedAt }, ... },   -- via: relayed record (CF-20)
  unlinked = { row, ... },
}
Only people with at least one visible (community member) character are listed. Their alts outside
the community that are known from a record are listed after their community characters with
row.outside = true (CF-17).
currentChar is the row of the character they are on now, or a minimal
{ guid, name, className, level, visible = false } when that character is not known at all.
]]
function Linker.build(raw)
  local self = raw.self or {}
  -- Own characters group under this key even when the BattleTag is unknown (BNet offline).
  local selfKey = self.battleTag or SELF_KEY
  local input = {
    members = raw.members or {},
    friends = raw.friends or {},
    online = raw.online or {},
    offline = raw.offline or {},
    people = raw.people or {},
    presence = raw.presence or {},
    locations = raw.locations or {},
    self = { battleTag = selfKey, displayName = self.displayName, chars = self.chars or {}, feed = self.feed },
    selfGuid = raw.selfGuid,
  }
  self = input.self

  local byTag, unlinked = {}, {}
  for guid, member in pairs(input.members) do
    local bt, source = linkFor(guid, input)
    local row = charRow(guid, member, recordFor(guid, bt, input), input.presence[guid], input.locations[guid], source)
    -- CF-28: a BYE over the community overrules a community presence that still says online.
    if input.offline[guid] then row.online = false end
    if bt then
      byTag[bt] = byTag[bt] or {}
      table.insert(byTag[bt], row)
    else
      row.linkSource = nil
      unlinked[#unlinked + 1] = row
    end
  end

  -- Alts outside the community (CF-17): characters from the own record or a friend's record that
  -- are not members. Shown only under an owner who already has a visible member character,
  -- never in Unlinked. Owner resolution is the same as for members (self, presence, record).
  local candidates = {}
  for guid in pairs(self.chars) do candidates[guid] = true end
  for bt, person in pairs(input.people) do
    if trusted(bt, person, input) then
      for guid in pairs(person.chars or {}) do candidates[guid] = true end
    end
  end
  for guid in pairs(candidates) do
    if not input.members[guid] then
      local bt, source = linkFor(guid, input)
      if bt and byTag[bt] then
        local record = recordFor(guid, bt, input)
        local row = charRow(guid, {}, record, input.presence[guid], input.locations[guid], source)
        row.outside = true
        local o = bt ~= self.battleTag and input.online[bt]
        row.online = (bt == self.battleTag and guid == input.selfGuid) or (o and o.guid == guid) or false
        table.insert(byTag[bt], row)
      end
    end
  end

  local people = {}
  for bt, rows in pairs(byTag) do
    -- CF-15 fix: the community presence can stay "Online" after a logout. For yourself and your
    -- Battle.net friends, Battle.net presence (live, with the character's GUID) decides which character
    -- is online: only the one they are on, none when they are not in Forever. People linked without a
    -- friendship (relayed records, CF-20) keep the community presence, the only one there is.
    -- CF-28: the same for people met over the community (HELLO says which character they are on).
    if bt == selfKey or input.friends[bt] or (bt:sub(1, 4) == "aid:" and input.online[bt]) then
      local onGuid = bt == selfKey and input.selfGuid or (input.online[bt] and input.online[bt].guid)
      for _, row in ipairs(rows) do row.online = onGuid ~= nil and row.guid == onGuid end
    end
    table.sort(rows, byOnlineThenName)
    local isSelf = bt == self.battleTag
    local ownerName = isSelf and self.displayName or (input.people[bt] and input.people[bt].displayName)
    -- CF-20: relayed record (via = friend who passed it on) and when its data last changed.
    local record = not isSelf and input.people[bt]
    local via = record and record.via or nil
    local updatedAt
    for _, c in pairs(record and record.chars or {}) do
      if c.updatedAt and (not updatedAt or c.updatedAt > updatedAt) then updatedAt = c.updatedAt end
    end

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
    elseif bt:sub(1, 4) == "aid:" and not (ownerName and ownerName ~= "") then
      -- CF-28: no BattleTag to fall back on: the name of their first character.
      displayName = rows[1] and rows[1].name or "Unknown"
    else
      displayName = Linker.displayName(bt, ownerName)
    end

    people[#people + 1] = {
      battleTag = bt ~= SELF_KEY and bt or nil,
      displayName = displayName,
      isSelf = isSelf,
      online = isSelf or input.online[bt] ~= nil,
      -- CF-34: runs the addon: we have a record from them (their own or relayed). Without one we only know
      -- what the community list and Battle.net presence show.
      usesAddon = isSelf or (record and record.version ~= nil) or false,
      currentChar = current,
      chars = rows,
      via = via,
      viaName = via and viaDisplayName(via, input),
      updatedAt = updatedAt,
      receivedAt = record and record.receivedAt or nil, -- CF-40: when their record last arrived (the footer)
      feed = isSelf and self.feed or (record and record.feed) or nil, -- CF-22 activity feed
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
