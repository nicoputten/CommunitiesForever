-- Merge: record accept rules and version rules. Pure Lua, no WoW globals.
local _, ns = ...

local Merge = {}

-- Owner-side version rule (ARCHITECTURE core rule 5): strictly increasing,
-- and close to server time so a reinstall with an empty DB still wins.
function Merge.nextVersion(previous, now)
  return math.max((previous or 0) + 1, now)
end

-- Own characters that are members of the selected community, as a sorted list of GUIDs.
function Merge.sharedGuids(selfRecord, members)
  local guids = {}
  for guid in pairs(selfRecord.chars or {}) do
    if members[guid] then guids[#guids + 1] = guid end
  end
  table.sort(guids)
  return guids
end

-- Stable text for the shared set; when it changes, the record a friend receives changes too.
function Merge.sharedSignature(selfRecord, members)
  return table.concat(Merge.sharedGuids(selfRecord, members), ",")
end

-- The RECORD message for the own record: only own characters that are community members
-- (ARCHITECTURE "Sender includes only own characters that are current community members").
function Merge.outgoingRecord(selfRecord, members)
  local chars = {}
  for _, guid in ipairs(Merge.sharedGuids(selfRecord, members)) do
    chars[guid] = selfRecord.chars[guid]
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

-- Accept rule for an incoming RECORD (ARCHITECTURE "Accept rule"):
--   senderBattleTag is what the sender's gameAccountID resolved to via presence (nil: unknown sender)
--   record.bt must equal it, record.version must be newer than the stored one.
-- The protocol version is checked earlier by the codec. Returns true, or false and a reason:
-- "sender" (unknown sender or bt mismatch / spoof), "old", "malformed".
function Merge.accept(stored, record, senderBattleTag)
  if type(record) ~= "table" then return false, "malformed" end
  if not senderBattleTag or record.bt ~= senderBattleTag then return false, "sender" end
  if type(record.version) ~= "number" or not validChars(record.chars) then return false, "malformed" end
  if stored and (stored.version or 0) >= record.version then return false, "old" end
  return true
end

-- Stores an accepted record: people[bt] = { displayName, version, receivedAt, chars }.
function Merge.store(people, record, now)
  people[record.bt] = {
    displayName = type(record.displayName) == "string" and record.displayName or nil,
    version = record.version,
    receivedAt = now,
    chars = record.chars,
  }
end

ns.Merge = Merge
return Merge
