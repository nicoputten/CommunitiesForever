-- Missions: friends and places (CF-73).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Facts of a day or week under facts.places = { zones = { [zone] = true }, newZones = { [guid|zone] = true },
-- crossSea, nostalgia, daredevil, sameZone (bools), onlineMax (most other friends online at once),
-- carry (count), carryDays = { [day] = true }, chat (count), chatDays = { [day] = true } }.
-- Local stored data (PlaceEvents): self.doomsday.zonesSeen = { [guid] = { [zone] = true } }. Optional, nil =
-- unknown (rule 8).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Places = {}

Places.CARRY_GAP = 5       -- d.carry: a friend this many levels or more below the own character
Places.NOSTALGIA_GAP = 20  -- d.nostalgia: the zone's highest suggested level this far below the character's
Places.DAREDEVIL_GAP = 5   -- d.daredevil: the zone's lowest suggested level this far above the character's
Places.CONTINENTS = { [0] = true, [1] = true } -- GetInstanceInfo instance IDs outside instances (V35)
Places.MAX_ZONES = 50      -- zones and new zones kept per day or week (a cap, as Goals' lists)
Places.FEED_OTHER = "Other" -- the feed's zone for quests without one (Feed.add): never a zone

-- Enum.ClubMemberPresence values that mean "in game" (as Linker and Members: Online, Away, Busy).
local IN_GAME = { [1] = true, [4] = true, [5] = true }

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function text(v) return type(v) == "string" and v ~= "" and v or nil end

local function factsOf(f)
  local p = f.places
  if type(p) ~= "table" then
    p = { zones = {}, newZones = {}, crossSea = false, nostalgia = false, daredevil = false, sameZone = false,
          onlineMax = 0, carry = 0, carryDays = {}, chat = 0, chatDays = {} }
    f.places = p
  end
  return p
end

-- ===== Helpers for PlaceEvents (the decisions stay here) =====

--[[ The BattleTag of each friend's character: people = { [bt] = { chars = { [guid] } } } and presence =
{ [guid] = { battleTag } }, own BattleTag (mine) left out, as DoomsdayTracker's owners. ]]
function Places.owners(people, presence, mine)
  local byGuid = {}
  for bt, person in pairs(type(people) == "table" and people or {}) do
    if bt ~= mine and type(person) == "table" and type(person.chars) == "table" then
      for guid in pairs(person.chars) do byGuid[guid] = bt end
    end
  end
  for guid, link in pairs(type(presence) == "table" and presence or {}) do
    if type(link) == "table" and link.battleTag and link.battleTag ~= mine and not byGuid[guid] then
      byGuid[guid] = link.battleTag
    end
  end
  return byGuid
end

--[[ Friends in game right now, from the selected community's members (members = { [guid] = { zone, presence } },
MemberTracker): the number of other friends (distinct BattleTags of byGuid, Places.owners) with a community
character in game, and whether one of them is in zone (the own zone; nil: unknown, never the same). ]]
function Places.friendsNow(members, byGuid, zone)
  local seen, n, same = {}, 0, false
  for guid, m in pairs(type(members) == "table" and members or {}) do
    local bt = type(byGuid) == "table" and byGuid[guid]
    if bt and type(m) == "table" and IN_GAME[m.presence] then
      if not seen[bt] then seen[bt], n = true, n + 1 end
      if text(zone) and m.zone == zone then same = true end
    end
  end
  return n, same
end

--[[ Whether the group holds a friend's community character CARRY_GAP or more levels below level (the own
character's). The friend's level: the higher of the member's (C_Club, can lag behind) and the friend's synced
record's (people), CF-123. ]]
function Places.carry(groupGuids, members, byGuid, people, level)
  if type(groupGuids) ~= "table" or type(level) ~= "number" then return false end
  members = type(members) == "table" and members or {}
  for _, guid in ipairs(groupGuids) do
    local bt = type(byGuid) == "table" and byGuid[guid]
    if bt and members[guid] then
      local person = type(people) == "table" and people[bt]
      local char = type(person) == "table" and type(person.chars) == "table" and person.chars[guid]
      local theirs = ns.Members.level(type(members[guid]) == "table" and members[guid].level or nil,
        type(char) == "table" and char.level or nil)
      if type(theirs) == "number" and theirs <= level - Places.CARRY_GAP then return true end
    end
  end
  return false
end

-- Whether a community chat message (channel, senderGuid) is an own message in the selected community's
-- channel (selected; nil: none). ownGuids = { [guid] = true }.
function Places.ownMessage(channel, selected, senderGuid, ownGuids)
  return selected ~= nil and channel == selected and type(senderGuid) == "string"
    and type(ownGuids) == "table" and ownGuids[senderGuid] == true
end

-- The continent of a place (GetInstanceInfo type and instanceID): 0 or 1 outside instances, else nil.
function Places.continent(instanceType, instanceID)
  if instanceType ~= "none" or not Places.CONTINENTS[instanceID] then return nil end
  return instanceID
end

--[[ Zone level ranges from Group Finder's activities (V46): activities = { { name, shortName, min, max,
difficultyID, maxNumPlayers } }. Zones are the activities without a difficulty and group size; each is known by
its full and short name. Returns { [name] = { min, max } }. ]]
function Places.zoneRanges(activities)
  local ranges = {}
  for _, a in ipairs(type(activities) == "table" and activities or {}) do
    if type(a) == "table" and (a.difficultyID or 0) == 0 and (a.maxNumPlayers or 0) == 0
        and type(a.min) == "number" and type(a.max) == "number" and a.min > 0 then
      local range = { min = a.min, max = a.max }
      if text(a.name) then ranges[a.name] = ranges[a.name] or range end
      if text(a.shortName) then ranges[a.shortName] = ranges[a.shortName] or range end
    end
  end
  return ranges
end

--[[ The zones each own character quested in, from the stored own feed (feed = { [day] = { [guid] = { quests =
{ [zone] = count } } } }): the start of self.doomsday.zonesSeen. ]]
function Places.seedZones(feed)
  local seen = {}
  for _, day in pairs(type(feed) == "table" and feed or {}) do
    for guid, entry in pairs(type(day) == "table" and day or {}) do
      local quests = type(entry) == "table" and type(entry.quests) == "table" and entry.quests or {}
      for zone in pairs(quests) do
        if text(zone) and zone ~= Places.FEED_OTHER then
          seen[guid] = seen[guid] or {}
          seen[guid][zone] = true
        end
      end
    end
  end
  return seen
end

-- Adds a zone to a character's set (seen = self.doomsday.zonesSeen, in place). True when it is new.
function Places.markZone(seen, guid, zone)
  if type(seen) ~= "table" or type(guid) ~= "string" or not text(zone) then return false end
  local set = seen[guid]
  if type(set) ~= "table" then
    set = {}
    seen[guid] = set
  end
  if set[zone] then return false end
  set[zone] = true
  return true
end

-- ===== Observations =====

--[[ placeZone: the own character entered a zone outside instances (ZONE_CHANGED_NEW_AREA, and the login).
  { guid, zone, new (bool: Places.markZone), level (the character's), min, max (the zone's suggested levels,
  Places.zoneRanges; nil: no match, never counts), continent and previous (Places.continent of now and of the
  last place this session; nil: unknown) } ]]
ns.Goals.registerKind("placeZone", function(f, obs)
  local p = factsOf(f)
  local zone = text(obs.zone)
  if zone and (p.zones[zone] or count(p.zones) < Places.MAX_ZONES) then p.zones[zone] = true end
  if zone and obs.new == true and type(obs.guid) == "string" and count(p.newZones) < Places.MAX_ZONES then
    p.newZones[obs.guid .. "|" .. zone] = true
  end
  if Places.CONTINENTS[obs.continent] and Places.CONTINENTS[obs.previous] and obs.continent ~= obs.previous then
    p.crossSea = true
  end
  if type(obs.level) == "number" then
    if type(obs.max) == "number" and obs.max <= obs.level - Places.NOSTALGIA_GAP then p.nostalgia = true end
    if type(obs.min) == "number" and obs.min >= obs.level + Places.DAREDEVIL_GAP then p.daredevil = true end
  end
end)

--[[ placeFriends: friends in game while a character plays (the community's members changed, or the own zone).
  { online (other friends in game, Places.friendsNow), sameZone (bool) } ]]
ns.Goals.registerKind("placeFriends", function(f, obs)
  local p = factsOf(f)
  if type(obs.online) == "number" and obs.online > p.onlineMax then p.onlineMax = obs.online end
  if obs.sameZone == true then p.sameZone = true end
end)

--[[ placeGroup: the own character is grouped with a friend's community character CARRY_GAP or more levels lower
  (Places.carry). { carry (bool), day (Doomsday day) } ]]
ns.Goals.registerKind("placeGroup", function(f, obs)
  if obs.carry ~= true then return end
  local p = factsOf(f)
  p.carry = p.carry + 1
  if type(obs.day) == "number" then p.carryDays[obs.day] = true end
end)

-- placeChat: an own message in the selected community's channel (Places.ownMessage). { day (Doomsday day) }
ns.Goals.registerKind("placeChat", function(f, obs)
  local p = factsOf(f)
  p.chat = p.chat + 1
  if type(obs.day) == "number" then p.chatDays[obs.day] = true end
end)

-- ===== Progress =====

local function pl(f) return type(f.places) == "table" and f.places or {} end
local function bool(value) return value and 1 or 0 end

local PROGRESS = {
  ["d.sameZone"] = function(f) return bool(pl(f).sameZone), 1 end,
  ["d.online3"] = function(f) return pl(f).onlineMax or 0, 3 end,
  ["d.carry"] = function(f) return pl(f).carry or 0, 1 end,
  ["d.chatHello"] = function(f) return pl(f).chat or 0, 1 end,
  ["d.roam4"] = function(f) return count(pl(f).zones), 4 end,
  ["d.newZone"] = function(f) return count(pl(f).newZones), 1 end,
  ["d.crossSea"] = function(f) return bool(pl(f).crossSea), 1 end,
  ["d.nostalgia"] = function(f) return bool(pl(f).nostalgia), 1 end,
  ["d.daredevil"] = function(f) return bool(pl(f).daredevil), 1 end,

  ["w.chatDays5"] = function(f) return count(pl(f).chatDays), 5 end,
  ["w.mentor3"] = function(f) return count(pl(f).carryDays), 3 end,
  ["w.newZones3"] = function(f) return count(pl(f).newZones), 3 end,
  ["w.roam10"] = function(f) return count(pl(f).zones), 10 end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Places.IDS = {}
for id in pairs(PROGRESS) do Places.IDS[#Places.IDS + 1] = id end
table.sort(Places.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Places = Places
return Places
