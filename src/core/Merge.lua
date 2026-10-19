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
  -- false (not nil) when not shared, so relays pass "stopped sharing" on (CF-28).
  local feed = selfRecord.feed
  if shareActivity == false then feed = false end
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
    feed = feed,
    aid = selfRecord.accountId, -- CF-28: links this BattleTag to its community key for friends
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

-- Removal times of characters a record carries (CF-28): { [guid] = time } with numeric times only.
local function cleanRemoved(removed)
  if type(removed) ~= "table" then return {} end
  local result = {}
  for guid, at in pairs(removed) do
    if type(guid) == "string" and type(at) == "number" and at == at then result[guid] = at end
  end
  return result
end

--[[ Per-character merge (CF-28, also for relay). Returns the merged chars and removed maps.
  removed = { [guid] = time }: characters the owner's own record dropped.
  direct (the record came from its owner): the owner's record is the truth for its characters. They
    replace the stored copies (a level may go down here: that is how a wrong level gets corrected), and
    characters it no longer lists are removed (at `now`).
  relayed: each character is compared on its own updatedAt and the newer copy stays, so a relay never
    puts a character back to older data; a relayed copy never lowers a level. Timestamps more than
    MAX_FUTURE_SECONDS ahead of `now` are ignored (characters and removals), so a broken or modified
    client cannot make a copy win forever. A removal only takes away a copy that is not newer than it. ]]
function Merge.mergeChars(storedChars, storedRemoved, incoming, incomingRemoved, direct, now)
  incoming = incoming or {}
  local chars, removed = {}, {}
  for guid, at in pairs(storedRemoved or {}) do removed[guid] = at end

  if direct then
    for guid, char in pairs(incoming) do
      chars[guid] = char
      removed[guid] = nil
    end
    for guid in pairs(storedChars or {}) do
      if not incoming[guid] then removed[guid] = now end
    end
    return chars, removed
  end

  local limit = (now or 0) + Merge.MAX_FUTURE_SECONDS
  for guid, at in pairs(incomingRemoved or {}) do
    if at <= limit and (not removed[guid] or at > removed[guid]) then removed[guid] = at end
  end
  for guid, char in pairs(storedChars or {}) do chars[guid] = char end

  for guid, char in pairs(incoming) do
    local stored = chars[guid]
    local at = type(char.updatedAt) == "number" and char.updatedAt or 0
    local future = at > limit
    local older = stored and (stored.updatedAt or 0) >= at
    if not future and not older then
      local copy = char
      if stored and type(stored.level) == "number" and type(char.level) == "number" and stored.level > char.level then
        copy = {}
        for k, v in pairs(char) do copy[k] = v end
        copy.level = stored.level -- a relayed copy never lowers a level
      end
      chars[guid] = copy
    end
  end

  -- A removal takes away copies that are not newer than it; a newer copy means the character is back.
  for guid, at in pairs(removed) do
    local char = chars[guid]
    if char and (char.updatedAt or 0) > at then
      removed[guid] = nil
    else
      chars[guid] = nil
    end
  end
  return chars, removed
end

--[[ The activity feed to store (CF-22, merged per day and character since CF-28). From the owner, the
record's feed is the truth (none: drop it). Relayed: false = the owner stopped sharing (drop it when the
record is newer); nil = unknown (keep what is stored); a feed merges with the stored one. ]]
local function mergedFeed(stored, record, newer, direct, now)
  if direct then return ns.Feed.clean(record.feed) end
  if record.feed == false then
    if newer then return nil end
    return stored and stored.feed
  end
  -- Relayed activity entries more than MAX_FUTURE_SECONDS ahead are ignored (as for characters).
  return ns.Feed.merge(stored and stored.feed, ns.Feed.clean(record.feed), now + Merge.MAX_FUTURE_SECONDS)
end

--[[ Stores an accepted record: people[bt] = { displayName, version, receivedAt, chars, removed, via,
invite, feed }. via is the BattleTag of the friend who relayed it, nil when it came from the owner.
Characters merge one by one (Merge.mergeChars); the other fields come from the record when it is not
older than what is stored. ]]
function Merge.store(people, record, now, senderBattleTag)
  local stored = people[record.bt]
  local direct = senderBattleTag == record.bt
  local chars, removed = Merge.mergeChars(stored and stored.chars, stored and stored.removed,
    stripEscapes(record.chars, 0), cleanRemoved(record.removed), direct, now)
  local newer = not stored or (stored.version or 0) <= record.version or direct
  local displayName, invite
  if newer then
    displayName, invite = Merge.cleanName(record.displayName), cleanInvite(record.invite)
  else
    displayName, invite = stored.displayName, stored.invite
  end
  people[record.bt] = {
    displayName = displayName,
    -- The owner's own record sets the version, even below a relayed copy's (CF-20).
    version = direct and record.version or math.max(record.version, stored and stored.version or 0),
    receivedAt = now,
    chars = chars,
    removed = next(removed) and removed or nil,
    feedOff = (record.feed == false and newer) or (not direct and record.feed == nil and stored and stored.feedOff)
      or nil,
    via = senderBattleTag ~= record.bt and senderBattleTag or nil,
    -- CF-28: the account ID (community key) of this person, once known.
    aid = (type(record.aid) == "string" and record.aid:match("^[0-9a-f]+$") and #record.aid <= 32 and record.aid)
      or (stored and stored.aid) or nil,
    invite = invite,
    feed = mergedFeed(stored, record, newer, direct, now),
  }
end

--[[ CF-28: when people[key] (a BattleTag) has an account ID and data arrived earlier over the community
under "aid:<id>", that copy is merged into people[key] as a relayed record and the "aid:" entry removed,
so one person never shows twice. Returns true when it merged. ]]
function Merge.absorb(people, key, now)
  local person = people[key]
  local aidKey = person and person.aid and ("aid:" .. person.aid)
  local other = aidKey and aidKey ~= key and people[aidKey]
  if not other then return false end
  local via = person.via
  Merge.store(people, { bt = key, version = math.min(other.version or 0, person.version or 0), chars = other.chars,
                        removed = other.removed, displayName = person.displayName, invite = person.invite,
                        feed = other.feed }, now, "aid-merge")
  people[key].via = via -- the merge itself is not a relay
  people[aidKey] = nil
  return true
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
  local feed = person.feed
  if feed == nil and person.feedOff then feed = false end -- "stopped sharing" passes on (CF-28)
  return { t = "RECORD", bt = battleTag, displayName = person.displayName, version = person.version,
           chars = person.chars, removed = person.removed, invite = cleanInvite(person.invite), feed = feed }
end

ns.Merge = Merge
return Merge
