-- BossKills: which bosses characters killed and when (CF-103). Pure Lua, no WoW globals.
-- Kill times come from three places: finished runs in the records' feeds (run.bossKills), kills friends shared
-- live (KILL message, db.global.liveKills) and the own runs in progress (db.global.runs). BossKills.collect puts
-- them together for the Runs tab (CF-106) and anything else that shows boss progress.
local _, ns = ...

local BossKills = {}

BossKills.KEEP_SECONDS = 2 * 86400 -- live kills are kept two days: a run's window ends at the next daily reset
BossKills.MAX_PER_CHAR = 40        -- live kills kept per character (a modified addon must not blow up the store)
BossKills.MAX_CHARS = 200          -- characters with live kills
local MAX_TEXT = 40

local function wholeId(value)
  return type(value) == "number" and value > 0 and value <= 1e7 and value == math.floor(value)
end

local function validTime(value)
  return type(value) == "number" and value == value and value > 0 and value < math.huge
end

--[[ A received KILL message as a kill, or nil when it is not one:
  message = { guid, instance, name, encounter, at } (docs/SYNC.md "KILL").
Returns { guid, instance, name, encounter, at }. Times later than now + maxFuture or older than KEEP_SECONDS
are dropped (a wrong clock, or a message held back for days). ]]
function BossKills.cleanLive(message, now, maxFuture)
  if type(message) ~= "table" or type(message.guid) ~= "string" or #message.guid > 80 or message.guid == "" then
    return nil
  end
  if not wholeId(message.encounter) or not validTime(message.at) then return nil end
  if type(now) == "number" then
    if message.at > now + (maxFuture or 0) or message.at < now - BossKills.KEEP_SECONDS then return nil end
  end
  local name = type(message.name) == "string" and message.name:gsub("|", ""):sub(1, MAX_TEXT) or nil
  return { guid = message.guid, encounter = message.encounter, at = math.floor(message.at),
           instance = wholeId(message.instance) and message.instance or nil, name = name ~= "" and name or nil }
end

local function count(map)
  local n = 0
  for _ in pairs(map) do n = n + 1 end
  return n
end

--[[ Adds a kill (BossKills.cleanLive) to the live store { [guid] = { [encounterID] = at } }, in place: as a run
in a record would, the earliest time per boss stays. Returns true when the store changed. ]]
function BossKills.addLive(store, kill)
  if type(store) ~= "table" or type(kill) ~= "table" then return false end
  local kills = store[kill.guid]
  if not kills then
    if count(store) >= BossKills.MAX_CHARS then return false end
    kills = {}
    store[kill.guid] = kills
  end
  local have = kills[kill.encounter]
  if have ~= nil and have <= kill.at then return false end
  if have == nil and count(kills) >= BossKills.MAX_PER_CHAR then return false end
  kills[kill.encounter] = kill.at
  return true
end

-- Drops live kills older than KEEP_SECONDS (and anything that is not a kill), in place.
function BossKills.trimLive(store, now)
  if type(store) ~= "table" then return end
  for guid, kills in pairs(store) do
    if type(kills) == "table" then
      for id, at in pairs(kills) do
        if not validTime(at) or (type(now) == "number" and at < now - BossKills.KEEP_SECONDS) then kills[id] = nil end
      end
    end
    if type(kills) ~= "table" or next(kills) == nil then store[guid] = nil end
  end
end

-- Own runs in progress (db.global.runs = { [guid] = run }) in the live store's shape. Kills without a time
-- (saved before CF-103 and not migrated) are left out.
function BossKills.fromRuns(runs)
  local result = {}
  if type(runs) ~= "table" then return result end
  for guid, run in pairs(runs) do
    if type(run) == "table" and type(run.bosses) == "table" then
      for id, at in pairs(run.bosses) do
        if wholeId(id) and validTime(at) then
          result[guid] = result[guid] or {}
          result[guid][id] = at
        end
      end
    end
  end
  return result
end

-- A list ({ a, b }) or a set ({ [a] = true }) as a set.
local function asSet(values)
  local set = {}
  if type(values) ~= "table" then return set end
  for k, v in pairs(values) do
    if type(k) == "number" and k == math.floor(k) and k >= 1 and k <= #values then
      set[v] = true
    elseif v then
      set[k] = true
    end
  end
  return set
end

--[[ All kills of the given encounters by the given characters from `from` until `to` (both inclusive, server
time; either nil = open).
  records: the stored records, a list or map of anything with a `feed` (db.global.people values, db.global.self).
  live: a list of maps in the live store's shape { [guid] = { [encounterID] = at } } (db.global.liveKills,
        BossKills.fromRuns(db.global.runs)).
  guids, encounterIDs: lists or sets (for a dungeon: the encounter IDs of its bosses).
Returns { [encounterID] = { at = earliest kill, by = { [guid] = that character's earliest kill } } }; an encounter
nobody killed is missing. Runs without bossKills (older clients: a count only) add nothing. ]]
function BossKills.collect(records, live, guids, encounterIDs, from, to)
  local chars, wanted, result = asSet(guids), asSet(encounterIDs), {}
  local function add(guid, id, at)
    if not (chars[guid] and wanted[id] and validTime(at)) then return end
    if (from and at < from) or (to and at > to) then return end
    local kill = result[id]
    if not kill then
      kill = { at = at, by = {} }
      result[id] = kill
    elseif at < kill.at then
      kill.at = at
    end
    if not kill.by[guid] or at < kill.by[guid] then kill.by[guid] = at end
  end
  for _, record in pairs(type(records) == "table" and records or {}) do
    local feed = type(record) == "table" and record.feed
    if type(feed) == "table" then
      for _, day in pairs(feed) do
        for guid, entry in pairs(type(day) == "table" and day or {}) do
          if chars[guid] and type(entry) == "table" and type(entry.runs) == "table" then
            for _, run in ipairs(entry.runs) do
              if type(run) == "table" and type(run.bossKills) == "table" then
                for id, at in pairs(run.bossKills) do add(guid, id, at) end
              end
            end
          end
        end
      end
    end
  end
  for _, store in ipairs(type(live) == "table" and live or {}) do
    for guid, kills in pairs(type(store) == "table" and store or {}) do
      if chars[guid] and type(kills) == "table" then
        for id, at in pairs(kills) do add(guid, id, at) end
      end
    end
  end
  return result
end

ns.BossKills = BossKills
return BossKills
