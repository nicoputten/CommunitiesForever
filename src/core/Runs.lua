-- Runs: dungeon, raid and battleground visits of the current character (CF-23). Pure Lua, no WoW globals.
-- A run starts when the character enters an instance and ends when it leaves; Runs.finish decides
-- whether it counts for the activity feed.
local _, ns = ...

local Runs = {}

Runs.MIN_SECONDS = 600     -- dungeons and raids count after at least 10 minutes inside ...
Runs.MIN_BOSSES = 1        -- ... and at least one boss killed
Runs.MAX_COMPANIONS = 40   -- a full raid
-- Instance types (GetInstanceInfo) that make a run. Arenas and scenarios do not exist in Vanilla.
Runs.KINDS = { party = true, raid = true, pvp = true }

-- Battleground team index of a faction (winner index of PVP_MATCH_COMPLETE / GetBattlefieldWinner on
-- Mainline: 0 Horde, 1 Alliance; unverified on Forever, VERIFY.md V35).
local TEAMS = { Horde = 0, Alliance = 1 }

function Runs.teamOf(faction)
  return TEAMS[faction]
end

--[[ New run for an instance, or nil when the instance type does not make one:
  instance = { name, type, instanceID } (GetInstanceInfo). day: realm day number (the feed day).
run = { name, kind, instanceID, day, startedAt, lastAt, bosses = { [encounterID] = true }, bossCount,
        with = { [guid] = true }, ended, won } ]]
function Runs.start(instance, now, day)
  if type(instance) ~= "table" or not Runs.KINDS[instance.type] or type(instance.name) ~= "string" then
    return nil
  end
  return { name = instance.name, kind = instance.type, instanceID = instance.instanceID, day = day,
           startedAt = now, lastAt = now, bosses = {}, bossCount = 0, with = {} }
end

-- True if the character is still in the run's instance.
function Runs.same(run, instance)
  if type(run) ~= "table" or type(instance) ~= "table" or instance.type ~= run.kind then return false end
  if run.instanceID ~= nil and instance.instanceID ~= nil then return run.instanceID == instance.instanceID end
  return run.name == instance.name
end

-- Something happened inside: the run lasted at least until now.
function Runs.touch(run, now)
  if run and type(now) == "number" and now > (run.lastAt or 0) then run.lastAt = now end
end

-- A boss died. Returns true when it is a new one (ENCOUNTER_END and BOSS_KILL can both report it).
function Runs.boss(run, encounterID, now)
  if not run or encounterID == nil then return false end
  Runs.touch(run, now)
  if run.bosses[encounterID] then return false end
  run.bosses[encounterID] = true
  run.bossCount = run.bossCount + 1
  return true
end

-- Adds group members that are members of the selected community (other players are left out, CF-23).
-- guids: list; members: { [guid] = anything }; selfGuid is skipped. Returns the number added.
function Runs.companions(run, guids, members, selfGuid)
  if not run then return 0 end
  local count, added = 0, 0
  for _ in pairs(run.with) do count = count + 1 end
  for _, guid in ipairs(guids or {}) do
    if count >= Runs.MAX_COMPANIONS then break end
    if type(guid) == "string" and guid ~= selfGuid and members and members[guid] and not run.with[guid] then
      run.with[guid] = true
      count, added = count + 1, added + 1
    end
  end
  return added
end

-- A battleground match ended. winner and team: team indexes (nil when unknown); won stays nil then.
-- Returns true the first time.
function Runs.matchEnded(run, winner, team, now)
  if not run or run.kind ~= "pvp" or run.ended then return false end
  Runs.touch(run, now)
  run.ended = true
  if type(winner) == "number" and type(team) == "number" then run.won = winner == team end
  return true
end

local function sortedKeys(map)
  local keys = {}
  for k in pairs(map) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

--[[ Feed event for a finished run, or nil plus the reason it does not count:
  { kind = "run", instance = "party"|"raid"|"pvp", name, bosses, won, with = { guid, ... } }
Dungeons and raids: at least MIN_SECONDS inside (until lastAt) and MIN_BOSSES bosses. Battlegrounds:
the match ended while the character was inside. ]]
function Runs.finish(run)
  if type(run) ~= "table" then return nil, "no run" end
  local event = { kind = "run", instance = run.kind, name = run.name, with = sortedKeys(run.with) }
  if run.kind == "pvp" then
    if not run.ended then return nil, "left before the match ended" end
    event.won = run.won
    return event
  end
  local seconds = (run.lastAt or 0) - (run.startedAt or 0)
  if seconds < Runs.MIN_SECONDS then
    return nil, string.format("%d min inside, needs %d", math.floor(seconds / 60), Runs.MIN_SECONDS / 60)
  end
  if run.bossCount < Runs.MIN_BOSSES then return nil, "no boss killed" end
  event.bosses = run.bossCount
  return event
end

ns.Runs = Runs
return Runs
