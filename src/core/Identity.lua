-- Identity: who a record belongs to when it travels over the community (CF-28 part 2b). Pure Lua.
-- People are keyed by BattleTag when we know it (Battle.net friends, relays) and by "aid:<accountId>"
-- otherwise. On the community wire every person key is an "aid:" key: BattleTags never leave Battle.net.
-- Each account makes a random account ID once and sends it with its record (`aid`).
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
