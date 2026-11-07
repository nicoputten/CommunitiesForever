-- BossKills: the kill log the Runs and Dungeons tabs read (CF-106), built against data contract 1 (CF-103 builds the
-- sending side): each run in a feed has the optional `bossKills = { [encounterID] = at }` (server time) next to its
-- `bosses` count, in your own feed (global.self.feed) and in friends' records (people[bt].feed); the run in progress
-- (global.runs[guid]) may carry it too. Older data has none: such runs count only, they give no kill here.
-- Live kills from online friends (CF-103's message) come in through BossKills.add, which CF-103 calls; until it
-- merges nothing calls it. Kills are read on demand; nothing is stored here.
local _, ns = ...

local BossKills = {}

BossKills.CHANGED = "CF_BOSS_KILLS_CHANGED"
BossKills.MAX_LIVE = 200

local live = {} -- { { guid, encounterID, at } } from BossKills.add, this session only
local addonRef

local function global()
  return addonRef and addonRef.db and addonRef.db.global or nil
end

function BossKills.start(addon)
  addonRef = addon
  live = {}
end

-- Adds the kills of one feed (Feed = { [day] = { [guid] = entry } }) to out.
local function fromFeed(feed, out)
  if type(feed) ~= "table" then return end
  for _, chars in pairs(feed) do
    for guid, entry in pairs(type(chars) == "table" and chars or {}) do
      for _, run in ipairs(type(entry) == "table" and type(entry.runs) == "table" and entry.runs or {}) do
        if type(run) == "table" and type(run.bossKills) == "table" then
          local with = type(run.with) == "table" and run.with or {}
          for encounterID, at in pairs(run.bossKills) do
            if type(at) == "number" then
              out[#out + 1] = { guid = guid, encounterID = tonumber(encounterID) or encounterID, at = at, with = with }
            end
          end
        end
      end
    end
  end
end

--[[ Every known kill: { { guid, encounterID, at, with = { guid, ... } } } (the same kill may appear from several
characters of the group; RunProgress and DungeonLoot cope with that). ]]
function BossKills.all()
  local out = {}
  local g = global()
  if g then
    fromFeed(g.self and g.self.feed, out)
    for _, person in pairs(type(g.people) == "table" and g.people or {}) do
      if type(person) == "table" then fromFeed(person.feed, out) end
    end
    for guid, run in pairs(type(g.runs) == "table" and g.runs or {}) do
      if type(run) == "table" and type(run.bossKills) == "table" then
        local with = {}
        for w in pairs(type(run.with) == "table" and run.with or {}) do with[#with + 1] = w end
        for encounterID, at in pairs(run.bossKills) do
          if type(at) == "number" then
            out[#out + 1] = { guid = guid, encounterID = tonumber(encounterID) or encounterID, at = at, with = with }
          end
        end
      end
    end
  end
  for _, k in ipairs(live) do out[#out + 1] = k end
  return out
end

-- A live kill (CF-103: a friend's boss kill message, or your own ENCOUNTER_END). Ignores broken values.
function BossKills.add(guid, encounterID, at, with)
  if type(guid) ~= "string" or encounterID == nil or type(at) ~= "number" then return false end
  if #live >= BossKills.MAX_LIVE then table.remove(live, 1) end
  live[#live + 1] = { guid = guid, encounterID = encounterID, at = at, with = type(with) == "table" and with or {} }
  if addonRef and addonRef.SendMessage then addonRef:SendMessage(BossKills.CHANGED) end
  return true
end

ns.BossKills = BossKills
return BossKills
