--[[ Belongs (CF-89): only people with a character in the selected community or guild take part. Pure Lua.
A person (BattleTag, or an "aid:" key for community peers) belongs when at least one of their characters is on the
roster, even while they play an alt outside it. Their characters are known from:
  - presence links (db.global.presence[guid].battleTag), kept after they log off;
  - the characters they are on right now (Battle.net presence, { [guid] = battleTag });
  - their own record (db.global.people[key].chars).
roster: db.global.members, { [guid] = { name, seenAt } }; nil while it is not known yet (login before the member
list loaded, right after choosing another community): then nobody is dropped or pruned. ]]
local _, ns = ...

local Belongs = {}

--[[ The keys that belong: { [key] = true }, or nil when the roster is not known.
ownKey (optional): your own BattleTag, which always belongs. ]]
function Belongs.keys(roster, presence, people, characters, ownKey)
  if type(roster) ~= "table" then return nil end
  local keys = {}
  if ownKey ~= nil then keys[ownKey] = true end
  for guid in pairs(roster) do
    local link = presence and presence[guid]
    if type(link) == "table" and type(link.battleTag) == "string" then keys[link.battleTag] = true end
    local bt = characters and characters[guid]
    if type(bt) == "string" then keys[bt] = true end
  end
  for key, person in pairs(people or {}) do
    if type(person) == "table" and type(person.chars) == "table" then
      for guid in pairs(person.chars) do
        if roster[guid] then
          keys[key] = true
          break
        end
      end
    end
  end
  return keys
end

-- Whether one key belongs: true or false, nil when the roster is not known (keys == nil).
function Belongs.is(keys, key)
  if keys == nil then return nil end
  return key ~= nil and keys[key] == true
end

--[[ Removes presence links of characters that are not on the roster and whose BattleTag does not belong, in place.
Returns the number removed. Does nothing while the roster is not known. ]]
function Belongs.prunePresence(presence, roster, keys)
  if type(presence) ~= "table" or type(roster) ~= "table" or keys == nil then return 0 end
  local removed = 0
  for guid, link in pairs(presence) do
    if not roster[guid] and not (type(link) == "table" and keys[link.battleTag]) then
      presence[guid] = nil
      removed = removed + 1
    end
  end
  return removed
end

-- Removes records of people who do not belong, in place. Returns the number removed. Nothing while not known.
function Belongs.prunePeople(people, keys)
  if type(people) ~= "table" or keys == nil then return 0 end
  local removed = 0
  for key in pairs(people) do
    if not keys[key] then
      people[key] = nil
      removed = removed + 1
    end
  end
  return removed
end

--[[ The roster to store (db.global.members, the site's proof of who is in the group): one entry per member of the
selected community, { [guid] = { name, seenAt = now } }, built from MemberTracker's members. ]]
function Belongs.roster(members, now)
  local roster = {}
  for guid, member in pairs(members or {}) do
    if type(guid) == "string" and type(member) == "table" then
      roster[guid] = { name = type(member.name) == "string" and member.name or nil, seenAt = now }
    end
  end
  return roster
end

ns.Belongs = Belongs
return Belongs
