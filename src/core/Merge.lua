-- Merge: record accept rules and version rules. Pure Lua, no WoW globals.
-- Requires ns.Feed (load core/Feed.lua first).
local _, ns = ...

local Merge = {}

-- Owner-side version rule (ARCHITECTURE core rule 5): strictly increasing,
-- and close to server time so a reinstall with an empty DB still wins.
function Merge.nextVersion(previous, now)
  return math.max((previous or 0) + 1, now)
end

-- Display names (CF-04) are shown in other players' UI, so only plain text: WoW escape sequences
-- ('|', e.g. colors or textures) are removed, whitespace is collapsed and the length is capped.
Merge.MAX_DISPLAY_NAME = 24

function Merge.cleanName(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("|", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
  local chars = {}
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #chars == Merge.MAX_DISPLAY_NAME then break end
    chars[#chars + 1] = char
  end
  text = table.concat(chars):match("^(.-)%s*$")
  return text ~= "" and text or nil
end

-- Copy of received character data with WoW escape sequences ('|') removed from every string
-- (names, professions, talents), so a modified addon cannot inject colors, textures or links.
local function stripEscapes(value, depth)
  if type(value) == "string" then return (value:gsub("|", "")) end
  if type(value) ~= "table" or depth > 4 then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = stripEscapes(v, depth + 1) end
  return copy
end

-- Invite code shared with the record (CF-21): only the expected fields, or nil.
local function cleanInvite(invite)
  if type(invite) ~= "table" or type(invite.code) ~= "string" or type(invite.setAt) ~= "number"
      or invite.clubId == nil then
    return nil
  end
  return { clubId = invite.clubId, code = invite.code, setAt = invite.setAt }
end

-- The RECORD message for the own record: all own characters (CF-17 feedback: always shared;
-- the receiver decides what to show, see core rule 1). CF-22: the activity feed only when
-- shareActivity is not false ("Share my activity" setting).
function Merge.outgoingRecord(selfRecord, shareActivity)
  local chars = {}
  for guid, char in pairs(selfRecord.chars or {}) do
    chars[guid] = char
  end
  return {
    t = "RECORD",
    bt = selfRecord.battleTag,
    displayName = selfRecord.displayName,
    version = selfRecord.version,
    chars = chars,
    invite = cleanInvite(selfRecord.invite),
    feed = shareActivity ~= false and selfRecord.feed or nil,
  }
end

local function validChars(chars)
  if type(chars) ~= "table" then return false end
  for guid, char in pairs(chars) do
    if type(guid) ~= "string" or type(char) ~= "table" then return false end
  end
  return true
end

-- Relayed versions may be at most this far ahead of server time (versions are close to server time).
Merge.MAX_FUTURE_SECONDS = 300

local function hasMember(chars, members)
  for guid in pairs(chars) do
    if members[guid] then return true end
  end
  return false
end

--[[ Accept rule for an incoming RECORD (ARCHITECTURE core rule 4, "Accept rule").
  senderBattleTag: what the sender's gameAccountID resolved to via presence (nil: unknown sender)
  relay (CF-20, optional): { ownBattleTag, now, members } enables relayed records; without it only
    the owner's own record is accepted (CF-11 behavior).
  Direct record (record.bt == sender): newer than stored, or stored is a relayed copy (the owner's
    record always replaces a relayed one, even at a lower version).
  Relayed record (record.bt ~= sender): not our own BattleTag, newer than stored, not more than
    MAX_FUTURE_SECONDS ahead of server time, at least one character in our selected community.
The protocol version is checked earlier by the codec. Returns true, or false and a reason:
"sender", "old", "malformed", "own", "future", "community".
]]
function Merge.accept(stored, record, senderBattleTag, relay)
  if type(record) ~= "table" then return false, "malformed" end
  if not senderBattleTag or type(record.bt) ~= "string" then return false, "sender" end
  if type(record.version) ~= "number" or not validChars(record.chars) then return false, "malformed" end

  if record.bt == senderBattleTag then
    if stored and not stored.via and (stored.version or 0) >= record.version then return false, "old" end
    return true
  end

  if not relay then return false, "sender" end
  if record.bt == relay.ownBattleTag then return false, "own" end
  if stored and (stored.version or 0) >= record.version then return false, "old" end
  if record.version > relay.now + Merge.MAX_FUTURE_SECONDS then return false, "future" end
  if not hasMember(record.chars, relay.members or {}) then return false, "community" end
  return true
end

-- Stores an accepted record: people[bt] = { displayName, version, receivedAt, chars, via, invite, feed }.
-- via is the BattleTag of the friend who relayed it, nil when it came from the owner.
function Merge.store(people, record, now, senderBattleTag)
  people[record.bt] = {
    displayName = Merge.cleanName(record.displayName),
    version = record.version,
    receivedAt = now,
    chars = stripEscapes(record.chars, 0),
    via = senderBattleTag ~= record.bt and senderBattleTag or nil,
    invite = cleanInvite(record.invite),
    feed = ns.Feed.clean(record.feed), -- CF-22; nil when the owner does not share it
  }
end

-- Versions of the records we can relay, for HELLO.known: { [battleTag] = version }.
-- Only people with at least one character in our selected community; when we cannot see the
-- community on this character (members empty), everything we hold.
function Merge.knownVersions(people, members)
  local known = {}
  local checkMembers = next(members or {}) ~= nil
  for bt, person in pairs(people or {}) do
    if type(person.version) == "number" and (not checkMembers or hasMember(person.chars or {}, members)) then
      known[bt] = person.version
    end
  end
  return known
end

-- Level-ups between a stored and a newer record of the same person (CF-16):
-- { { guid, name, level, updatedAt } } for characters that existed before with a lower level.
-- Characters seen for the first time are not level-ups. Sorted by name.
function Merge.levelUps(oldChars, newChars)
  local ups = {}
  for guid, char in pairs(newChars or {}) do
    local before = oldChars and oldChars[guid]
    if before and type(before.level) == "number" and type(char.level) == "number" and char.level > before.level then
      ups[#ups + 1] = { guid = guid, name = char.name, level = char.level, updatedAt = char.updatedAt }
    end
  end
  table.sort(ups, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return ups
end

-- A stored record as a RECORD message, to relay it (CF-20).
function Merge.relayRecord(people, battleTag)
  local person = people[battleTag]
  if not person then return nil end
  return { t = "RECORD", bt = battleTag, displayName = person.displayName, version = person.version,
           chars = person.chars, invite = cleanInvite(person.invite), feed = person.feed }
end

ns.Merge = Merge
return Merge
