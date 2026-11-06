-- Missions: the existing trackers, extended (CF-74).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- It reads the built-in facts of CF-52, CF-53 and CF-56 (fish, trades, discoveries, sessions, the early bird) and
-- adds its own under facts.extended = { fishZones = { [zone] = true }, fishFriend, fishNight (counts),
-- night (bool), sessionMax, aliveMax (seconds), cleanRuns = { [guid|name|startedAt] = true }, profit (bool),
-- green, reward, crafted, fed (counts), tradeFriends = { [friend] = true }, groupDays = { [day] = true } }.
-- Local stored data (ExtendedEvents): self.doomsday.sessionMoney = { guid, money, at } and
-- self.doomsday.cooked = { [itemID] = true }. Both optional, nil = unknown (rule 8).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Extended = {}

Extended.NIGHT_FROM, Extended.NIGHT_UNTIL = 23, 3   -- d.nightOwl: local hours 23:00 to 03:00
Extended.FISH_NIGHT_FROM, Extended.FISH_NIGHT_UNTIL = 21, 5 -- d.fishNight: realm hours 21:00 to 05:00
Extended.UNCOMMON = 2              -- item quality (Enum.ItemQuality): green
Extended.REWARD_SECONDS = 5        -- d.reward: an item received this close to a quest hand-in is its reward
Extended.CONTINUE = 300            -- seconds: a login this soon after the last logout continues the session
Extended.FOOD_CLASS, Extended.FOOD_SUBCLASS = 0, 5 -- food and drink (V105)
Extended.MAX_KEYS = 50             -- zones, runs and friends kept per day or week (a cap, as Goals' lists)
Extended.MAX_COOKED = 200          -- dishes kept in self.doomsday.cooked

-- Link colours by quality, for items the game has not cached yet (as Loot's, with the lower qualities).
local COLORS = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function text(v) return type(v) == "string" and v ~= "" and v or nil end
local function num(v) return type(v) == "number" and v or nil end

local function factsOf(f)
  local e = f.extended
  if type(e) ~= "table" then
    e = { fishZones = {}, fishFriend = 0, fishNight = 0, night = false, sessionMax = 0, aliveMax = 0, cleanRuns = {},
          profit = false, green = 0, reward = 0, crafted = 0, fed = 0, tradeFriends = {}, groupDays = {} }
    f.extended = e
  end
  return e
end

local function mark(set, key)
  if key ~= nil and not set[key] and count(set) < Extended.MAX_KEYS then set[key] = true end
end

-- ===== Helpers for ExtendedEvents (the decisions stay here) =====

-- Whether a local hour (0 to 23) is in d.nightOwl's night.
function Extended.isNight(hour)
  if type(hour) ~= "number" then return false end
  return hour >= Extended.NIGHT_FROM or hour < Extended.NIGHT_UNTIL
end

-- Whether a realm hour (GetGameTime) is in d.fishNight's night.
function Extended.isFishNight(hour)
  if type(hour) ~= "number" then return false end
  return hour >= Extended.FISH_NIGHT_FROM or hour < Extended.FISH_NIGHT_UNTIL
end

--[[ The quality of a parsed loot message (Loot.parse: { color, linkQuality }): the game's (quality, nil when not
cached yet), else the link's |cnIQ quality, else its colour. nil when unknown. ]]
function Extended.quality(item, quality)
  if type(quality) == "number" then return quality end
  if type(item) ~= "table" then return nil end
  if type(item.linkQuality) == "number" then return item.linkQuality end
  return COLORS[item.color or ""]
end

-- Whether an item received at lootAt is the reward of a quest handed in at turnInAt (either order).
function Extended.isReward(lootAt, turnInAt)
  if type(lootAt) ~= "number" or type(turnInAt) ~= "number" then return false end
  return math.abs(lootAt - turnInAt) <= Extended.REWARD_SECONDS
end

--[[ Friends' community characters in the group: groupGuids (Instance.groupGuids), members = { [guid] = { zone } }
(MemberTracker), byGuid = { [guid] = friend } (Places.owners), zone (the own zone, nil: unknown). Returns
{ [friend] = true } and whether one of them is here: in zone, or its zone unknown (grouped is near enough). ]]
function Extended.friendsInGroup(groupGuids, members, byGuid, zone)
  local friends, here = {}, false
  if type(groupGuids) ~= "table" or type(members) ~= "table" or type(byGuid) ~= "table" then return friends, here end
  for _, guid in ipairs(groupGuids) do
    local m, friend = members[guid], byGuid[guid]
    if type(m) == "table" and friend then
      friends[friend] = true
      local theirs = text(m.zone)
      if theirs == nil or text(zone) == nil or theirs == zone then here = true end
    end
  end
  return friends, here
end

--[[ The money a session started with (stored = self.doomsday.sessionMoney, nil the first time): a login of the
same character within CONTINUE seconds of its last logout (a /reload) continues the session, else a new one
starts with money. Returns the record to store, { guid, money, at }, or nil when guid or money is unknown. ]]
function Extended.sessionMoney(stored, guid, money, now)
  if type(guid) ~= "string" or type(money) ~= "number" then return nil end
  if type(stored) == "table" and stored.guid == guid and type(stored.money) == "number" and type(now) == "number"
      and type(stored.at) == "number" and now - stored.at <= Extended.CONTINUE and now >= stored.at then
    return { guid = guid, money = stored.money, at = now }
  end
  return { guid = guid, money = money, at = now }
end

-- Whether an item is food or drink by its class and subclass (C_Item.GetItemInfoInstant, V105).
function Extended.isFood(classID, subclassID)
  return classID == Extended.FOOD_CLASS and subclassID == Extended.FOOD_SUBCLASS
end

-- Adds a dish an own character created to cooked (self.doomsday.cooked, in place, capped).
function Extended.markCooked(cooked, id)
  if type(cooked) ~= "table" or type(id) ~= "number" or cooked[id] then return end
  if count(cooked) < Extended.MAX_COOKED then cooked[id] = true end
end

-- Whether a trade gave one of the own dishes: given = { itemID, ... }, cooked = self.doomsday.cooked.
function Extended.gaveCooked(given, cooked)
  if type(given) ~= "table" or type(cooked) ~= "table" then return false end
  for _, id in ipairs(given) do
    if cooked[id] then return true end
  end
  return false
end

-- ===== Observations =====

--[[ extFish: fishing loot (CF-56's fishing tracker, V84). { zone (GetRealZoneText), friend (bool: a friend's
community character in the group, here: Extended.friendsInGroup), hour (the realm clock, GetGameTime) } ]]
ns.Goals.registerKind("extFish", function(f, obs)
  local e = factsOf(f)
  mark(e.fishZones, text(obs.zone))
  if obs.friend == true then e.fishFriend = e.fishFriend + 1 end
  if Extended.isFishNight(obs.hour) then e.fishNight = e.fishNight + 1 end
end)

-- extClock: the player's local hour while logged in (at login and when the hour turns). { hour }
ns.Goals.registerKind("extClock", function(f, obs)
  if Extended.isNight(obs.hour) then factsOf(f).night = true end
end)

--[[ extAlive: the current session of the current character so far (every minute). { now, from (the session's
start, Play), death (the character's last death, nil: none known) }. The session time and the time alive since
the later of its start and the last death. ]]
ns.Goals.registerKind("extAlive", function(f, obs)
  local now, from = num(obs.now), num(obs.from)
  if not (now and from) or now < from then return end
  local e = factsOf(f)
  e.sessionMax = math.max(e.sessionMax, now - from)
  local since = math.max(from, num(obs.death) or from)
  if now >= since then e.aliveMax = math.max(e.aliveMax, now - since) end
end)

--[[ extBoss: a boss of the current party run died (the run as ActivityTracker keeps it). { guid, name,
startedAt (the run's first entry), death (the character's last death, nil: none known) }. Clean: no death since
the run started. ]]
ns.Goals.registerKind("extBoss", function(f, obs)
  local startedAt = num(obs.startedAt)
  if type(obs.guid) ~= "string" or not text(obs.name) or not startedAt then return end
  local death = num(obs.death)
  if death and death >= startedAt then return end
  mark(factsOf(f).cleanRuns, obs.guid .. "|" .. obs.name .. "|" .. startedAt)
end)

-- extMoney: the money changed. { start (the session's, Extended.sessionMoney), now } in copper.
ns.Goals.registerKind("extMoney", function(f, obs)
  local start, now = num(obs.start), num(obs.now)
  if start and now and now > start then factsOf(f).profit = true end
end)

--[[ extLoot: an own loot message (CHAT_MSG_LOOT, Loot.parse). { source = "looted" | "pushed" (received, e.g. a
quest reward) | "created", quality (Extended.quality, nil: unknown), count } ]]
ns.Goals.registerKind("extLoot", function(f, obs)
  local n = math.max(1, math.floor(num(obs.count) or 1))
  local e = factsOf(f)
  if obs.source == "created" then
    e.crafted = e.crafted + n
  elseif (obs.source == "looted" or obs.source == "pushed") and (num(obs.quality) or -1) >= Extended.UNCOMMON then
    e.green = e.green + n
  end
end)

-- extReward: an item received as a quest's reward (Extended.isReward). { quality (nil: unknown) }
ns.Goals.registerKind("extReward", function(f, obs)
  if (num(obs.quality) or -1) >= Extended.UNCOMMON then
    local e = factsOf(f)
    e.reward = e.reward + 1
  end
end)

--[[ extTrade: a completed trade (CF-56's trade tracker, V85). { friend (the partner's friend key, nil: not a
friend's character), fed (bool: it gave one of the own dishes, Extended.gaveCooked) } ]]
ns.Goals.registerKind("extTrade", function(f, obs)
  local friend = text(obs.friend)
  if not friend then return end
  local e = factsOf(f)
  mark(e.tradeFriends, friend)
  if obs.fed == true then e.fed = e.fed + 1 end
end)

-- extGroup: a friend's community character is in the group. { day (Doomsday day) }
ns.Goals.registerKind("extGroup", function(f, obs)
  if type(obs.day) == "number" then mark(factsOf(f).groupDays, obs.day) end
end)

-- ===== Progress =====

local function ext(f) return type(f.extended) == "table" and f.extended or {} end
local function bool(value) return value and 1 or 0 end
local function hours(n) return n * 3600 end

local function cleanRuns(f) return count(ext(f).cleanRuns) end

local PROGRESS = {
  ["d.fish50"] = function(f) return f.fish or 0, 50 end,
  ["d.fishZones"] = function(f) return count(ext(f).fishZones), 2 end,
  ["d.fishFriend"] = function(f) return ext(f).fishFriend or 0, 1 end,
  ["d.fishNight"] = function(f) return ext(f).fishNight or 0, 1 end,
  ["d.nightOwl"] = function(f) return bool(ext(f).night), 1 end,
  ["d.session1h"] = function(f) return math.max(f.longestSession or 0, ext(f).sessionMax or 0), hours(1) end,
  ["d.deathless"] = function(f) return ext(f).aliveMax or 0, hours(1) end,
  ["d.cleanRun"] = function(f) return cleanRuns(f), 1 end,
  ["d.profit"] = function(f) return bool(ext(f).profit), 1 end,
  ["d.green5"] = function(f) return ext(f).green or 0, 5 end,
  ["d.reward"] = function(f) return ext(f).reward or 0, 1 end,
  ["d.craft5"] = function(f) return ext(f).crafted or 0, 5 end,
  ["d.feedFriend"] = function(f) return ext(f).fed or 0, 1 end,
  ["d.discover1"] = function(f) return f.discoveries or 0, 1 end,
  ["d.discover3"] = function(f) return f.discoveries or 0, 3 end,

  ["w.cleanRuns2"] = function(f) return cleanRuns(f), 2 end,
  ["w.fish100"] = function(f) return f.fish or 0, 100 end,
  ["w.fishZones4"] = function(f) return count(ext(f).fishZones), 4 end,
  ["w.dayAndNight"] = function(f) return bool(f.earlyBird) + bool(ext(f).night), 2 end,
  ["w.deathless3h"] = function(f) return ext(f).aliveMax or 0, hours(3) end,
  ["w.friendDays3"] = function(f) return count(ext(f).groupDays), 3 end,
  ["w.trades3"] = function(f) return count(ext(f).tradeFriends), 3 end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Extended.IDS = {}
for id in pairs(PROGRESS) do Extended.IDS[#Extended.IDS + 1] = id end
table.sort(Extended.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Extended = Extended
return Extended
