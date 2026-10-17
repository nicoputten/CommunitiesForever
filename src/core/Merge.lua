-- Merge: record accept rules and version rules. Pure Lua, no WoW globals.
local _, ns = ...

local Merge = {}

-- Owner-side version rule (ARCHITECTURE core rule 5): strictly increasing,
-- and close to server time so a reinstall with an empty DB still wins.
function Merge.nextVersion(previous, now)
  return math.max((previous or 0) + 1, now)
end

-- The RECORD message for the own record: all own characters (CF-17 feedback: always shared;
-- the receiver decides what to show, see core rule 1).
function Merge.outgoingRecord(selfRecord)
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

-- Stores an accepted record: people[bt] = { displayName, version, receivedAt, chars, via }.
-- via is the BattleTag of the friend who relayed it, nil when it came from the owner.
function Merge.store(people, record, now, senderBattleTag)
  people[record.bt] = {
    displayName = type(record.displayName) == "string" and record.displayName or nil,
    version = record.version,
    receivedAt = now,
    chars = record.chars,
    via = senderBattleTag ~= record.bt and senderBattleTag or nil,
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

-- A stored record as a RECORD message, to relay it (CF-20).
function Merge.relayRecord(people, battleTag)
  local person = people[battleTag]
  if not person then return nil end
  return { t = "RECORD", bt = battleTag, displayName = person.displayName, version = person.version,
           chars = person.chars }
end

ns.Merge = Merge
return Merge
