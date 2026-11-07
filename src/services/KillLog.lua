-- KillLog: every known boss kill as a list, for the Runs and Dungeons tabs (CF-106). The kills are CF-103's: each
-- feed run's `bossKills = { [encounterID] = at }` (data contract 1) in your feed (global.self.feed) and friends'
-- records (people[bt].feed), kills friends shared live (global.liveKills, the KILL message) and your runs in progress
-- (core BossKills.fromRuns). Older data has no times: such runs count only and give no kill here. RunProgress and
-- DungeonLoot decide which kills count; nothing is stored here. ActivityTracker.KILLS_CHANGED redraws the window.
local _, ns = ...

local KillLog = {}

local addonRef

local function global()
  return addonRef and addonRef.db and addonRef.db.global or nil
end

function KillLog.start(addon)
  addonRef = addon
end

-- Adds the kills of one feed (Feed = { [day] = { [guid] = entry } }) to out, with the run's group (`with`).
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

-- Adds a live store ({ [guid] = { [encounterID] = at } }) to out.
local function fromStore(store, out)
  for guid, kills in pairs(type(store) == "table" and store or {}) do
    for encounterID, at in pairs(type(kills) == "table" and kills or {}) do
      if type(guid) == "string" and type(at) == "number" then
        out[#out + 1] = { guid = guid, encounterID = tonumber(encounterID) or encounterID, at = at, with = {} }
      end
    end
  end
end

--[[ Every known kill: { { guid, encounterID, at, with = { guid, ... } } } (the same kill may appear from several
characters of the group and several sources; RunProgress and DungeonLoot cope with that). ]]
function KillLog.all()
  local out = {}
  local g = global()
  if not g then return out end
  fromFeed(g.self and g.self.feed, out)
  for _, person in pairs(type(g.people) == "table" and g.people or {}) do
    if type(person) == "table" then fromFeed(person.feed, out) end
  end
  fromStore(g.liveKills, out)
  fromStore(ns.BossKills.fromRuns(g.runs), out)
  return out
end

ns.KillLog = KillLog
return KillLog
