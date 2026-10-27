-- Planner: planned runs for the Dungeons tab (CF-46; CF-24's calendar events were replaced). The runs come
-- from Data\Runs.lua (written by the uploader, read at login and /reload) and from friends' addons over
-- sync (Sync.lua: RUNS); the newer updatedAt wins. The newest list is kept in global.plannedRuns, so a
-- friend without the uploader still sees runs after a /reload.
local _, ns = ...

local Planner = {}

-- Internal message: the runs changed (the window refreshes).
Planner.UPDATED = "CF_PLANNER_UPDATED"

local addonRef
local current -- checked runs data, see PlannedRuns.validate

local function global() return addonRef.db.global end

local function now() return GetServerTime() end

-- Keeps data when newer than what we have. Returns true when it was taken.
local function take(data)
  if not ns.PlannedRuns.isNewer(current, data, now()) then return false end
  current = data
  global().plannedRuns = ns.PlannedRuns.wire(data)
  return true
end

function Planner.start(addon)
  addonRef = addon
  current = nil
  -- The dungeon list from the game's Group Finder (names and level ranges, Forever's new dungeons).
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
  -- Stored runs are checked again: SavedVariables are a file too.
  local ok, stored = pcall(ns.PlannedRuns.validate, global().plannedRuns)
  if ok and stored then current = stored end
  take(ns.RunsFile.read())
end

-- The checked runs data, or nil.
function Planner.data() return current end

-- updatedAt of the runs we have (0: none), for HELLO (Sync.lua).
function Planner.updatedAt() return current and current.updatedAt or 0 end

-- Runs to show now, soonest first.
function Planner.upcoming() return ns.PlannedRuns.upcoming(current, now()) end

-- Runs to send: forCommunity drops BattleTags. nil when we have none.
function Planner.outgoing(forCommunity) return ns.PlannedRuns.wire(current, forCommunity) end

-- Runs a friend sent (untrusted). Returns true when they replaced ours.
function Planner.receive(raw)
  local ok, data = pcall(ns.PlannedRuns.validate, raw)
  if not (ok and data) or not take(data) then return false end
  addonRef:SendMessage(Planner.UPDATED)
  return true
end

-- Your BattleTag and characters, to find your answers ({ battleTag, guids }).
function Planner.me()
  local own = global().self
  local guids = {}
  for guid in pairs(own.chars or {}) do guids[guid] = true end
  local selfGuid = ns.SelfInfo.read().guid
  if selfGuid then guids[selfGuid] = true end
  return { battleTag = own.battleTag, guids = guids }
end

ns.Planner = Planner
return Planner
