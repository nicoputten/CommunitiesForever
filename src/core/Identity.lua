-- Identity: who a record belongs to when it travels over the community (CF-28 part 2b). Pure Lua.
-- People are keyed by BattleTag when we know it (Battle.net friends, relays) and by "aid:<accountId>"
-- otherwise. On the community wire every person key is an "aid:" key. Each account makes a random account ID
-- once and sends it with its record (`aid`). CF-90: an owner's own HELLO and record over the community also carry
-- its own BattleTag (`btag`), so guild members who are not Battle.net friends know each other by it
-- (Identity.claimBattleTag); a relay never sends someone else's.
local _, ns = ...

local Identity = {}

local AID_PREFIX = "aid:"
local ID_CHARS = "0123456789abcdef"
Identity.ID_LENGTH = 12

-- A new random account ID. random(n) returns 1..n (math.random in the game, injected for tests).
function Identity.newAccountId(random)
  local t = {}
  for i = 1, Identity.ID_LENGTH do
    local n = random(#ID_CHARS)
    t[i] = ID_CHARS:sub(n, n)
  end
  return table.concat(t)
end

function Identity.isAccountId(id)
  return type(id) == "string" and #id == Identity.ID_LENGTH and id:match("^[0-9a-f]+$") ~= nil
end

function Identity.aidKey(id) return AID_PREFIX .. id end

function Identity.isAidKey(key)
  return type(key) == "string" and key:sub(1, #AID_PREFIX) == AID_PREFIX
end

-- The account ID in an "aid:" key, or nil.
function Identity.accountIdOf(key)
  if not Identity.isAidKey(key) then return nil end
  local id = key:sub(#AID_PREFIX + 1)
  return Identity.isAccountId(id) and id or nil
end

--[[ A person key as it may go over the community: the "aid:" key, or nil when we do not know the
person's account ID (then it is not shared there). own = db.global.self (battleTag, accountId). ]]
function Identity.toCommunity(people, own, key)
  if own and (key == own.battleTag or key == Identity.aidKey(own.accountId or "")) then
    return own.accountId and Identity.aidKey(own.accountId) or nil
  end
  if Identity.isAidKey(key) then return key end
  local person = people and people[key]
  return person and Identity.isAccountId(person.aid) and Identity.aidKey(person.aid) or nil
end

--[[ The local key for a key from the wire: your own key for your own account ID, the BattleTag of a
person whose account ID we know, else the key itself. Returns key, isOwn. ]]
function Identity.fromWire(people, own, key)
  local id = Identity.accountIdOf(key)
  if not id then return key, own ~= nil and key == own.battleTag end
  if own and id == own.accountId then return own.battleTag or key, true end
  for k, person in pairs(people or {}) do
    if person.aid == id and not Identity.isAidKey(k) then return k, false end
  end
  return key, false
end

--[[ A community HELLO from a character of a known person whose account ID we do not know yet (e.g. their
record reached us through a relay, which carries no account ID): the game names the sending character, and
that character is theirs, so the account ID in the HELLO is theirs. Sets people[senderKey].aid and returns
true. Never overwrites a known account ID, never takes one another person already has, and only for a
BattleTag-keyed person (senderKey from Identity.personOfGuid). ]]
function Identity.bindAccountId(people, senderKey, wireKey)
  local id = Identity.accountIdOf(wireKey)
  local person = people and people[senderKey]
  if not id or not person or person.aid ~= nil or Identity.isAidKey(senderKey) then return false end
  for key, other in pairs(people) do
    if key ~= senderKey and other.aid == id then return false end
  end
  person.aid = id
  return true
end

-- CF-90: a BattleTag as it may come from the community wire: a name without "#", ":", spaces or control
-- characters, "#", then 3 to 10 digits; at most 40 bytes (names may hold non-ASCII letters).
function Identity.isBattleTag(text)
  return type(text) == "string" and #text <= 40 and text:match("^[^#:%s%c]+#%d%d%d%d?%d?%d?%d?%d?%d?%d?$") ~= nil
end

--[[ CF-90: a community HELLO or own record (wire key "aid:<id>", sent by the character guid) says its owner's
BattleTag is btag. Re-keys that person from "aid:<id>" to the BattleTag (keeping aid = id), in place, and returns
true when people changed (the caller then runs Merge.absorb(people, btag, now), which merges a stored "aid:" copy
into an existing BattleTag person). Returns false when there is nothing to change or the claim is refused.
ctx = { ownBattleTag, ownAccountId, friends = { [bt] = true }, online = { [bt] = char } (friends Battle.net shows
        in Forever now; nil = not known, then every friend counts as visible), presence = { [guid] = { battleTag } },
        characters = { [guid] = bt } (live Battle.net presence) }.
Refused (spoofing guards): not a valid BattleTag; your own BattleTag or account ID; a current Battle.net friend whom
Battle.net shows in Forever now (Battle.net links them: their own record over Battle.net carries the account ID;
CF-97: Battle.net can't name a friend who appears offline, V87, so their claim counts); the sending character linked
by Battle.net presence to another BattleTag; the account ID already known under another BattleTag; the sending character
in another person's record; an "aid:" person whose record does not list the sending character; a stored person with
that BattleTag who has another account ID, or none and does not list the sending character. The first owner of a
BattleTag keeps it. ]]
function Identity.claimBattleTag(people, wireKey, btag, guid, ctx)
  ctx = ctx or {}
  local id = Identity.accountIdOf(wireKey)
  if not id or type(people) ~= "table" or type(guid) ~= "string" or not Identity.isBattleTag(btag) then
    return false
  end
  if btag == ctx.ownBattleTag or id == ctx.ownAccountId then return false end
  if ctx.friends and ctx.friends[btag] and (ctx.online == nil or ctx.online[btag]) then return false end
  local link = ctx.presence and ctx.presence[guid]
  link = (type(link) == "table" and link.battleTag) or (ctx.characters and ctx.characters[guid])
  if link ~= nil and link ~= btag then return false end
  local aidKey = Identity.aidKey(id)
  for key, person in pairs(people) do
    if key ~= aidKey and key ~= btag and type(person) == "table" then
      if person.aid == id then return false end -- known under another BattleTag
      if person.chars and person.chars[guid] then return false end -- someone else's character
    end
  end
  local aidPerson = people[aidKey]
  if type(aidPerson) == "table" and next(aidPerson.chars or {}) and not aidPerson.chars[guid] then return false end
  local target = people[btag]
  if type(target) == "table" then
    if target.aid == id then return false end -- already known by it
    if target.aid ~= nil or not (target.chars and target.chars[guid]) then return false end
    target.aid = id
    return true
  end
  if type(aidPerson) ~= "table" then return false end -- nothing stored yet: their record carries it too
  aidPerson.aid = id
  people[btag] = aidPerson
  people[aidKey] = nil
  return true
end

-- The person key whose record lists this character GUID, or nil.
function Identity.personOfGuid(people, guid)
  for key, person in pairs(people or {}) do
    if person.chars and person.chars[guid] then return key end
  end
  return nil
end

--[[ Known versions for a HELLO over the community: only "aid:" keys (people without a known account ID
are left out). known = { [localKey] = version }. ]]
function Identity.knownForCommunity(people, own, known)
  local result = {}
  for key, version in pairs(known or {}) do
    local wire = Identity.toCommunity(people, own, key)
    if wire then result[wire] = version end
  end
  return result
end

ns.Identity = Identity
return Identity
