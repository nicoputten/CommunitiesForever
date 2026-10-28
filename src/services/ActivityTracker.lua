-- ActivityTracker: dungeon, raid and battleground runs of the current character for the activity feed
-- (CF-23). The run in progress lives in db.global.runs[guid] (not synced), so a /reload or a
-- disconnect inside keeps it; a finished run that counts goes into the feed (FeedTracker).
-- /cf activity debug prints every instance event and what the tracker concluded (V35).
local _, ns = ...

local ActivityTracker = {}

local addonRef

local function db() return addonRef.db.global end

function ActivityTracker.debugOn()
  return addonRef ~= nil and db().settings.activityDebug == true
end

function ActivityTracker.setDebug(on)
  db().settings.activityDebug = on or nil
end

local function trace(text, ...)
  if ActivityTracker.debugOn() then
    addonRef:Print("|cffa0a0a0[activity]|r " .. string.format(text, ...))
  end
end

local function describe(...)
  local args = {}
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    args[#args + 1] = ns.Safe.secret(value) and "<secret>" or tostring(value)
  end
  return table.concat(args, ", ")
end

local function selfGuid() return ns.SelfInfo.read().guid end

local function members()
  local ok, list = pcall(ns.MemberTracker.members)
  return ok and list or {}
end

local function addCompanions(run, guid)
  local guids = ns.Instance.groupGuids()
  local added = ns.Runs.companions(run, guids, members(), guid)
  trace("group: %d other players, %d new community companions", #guids, added)
end

local function finish(guid, run)
  db().runs[guid] = nil
  local event, reason = ns.Runs.finish(run)
  local minutes = math.floor(((run.lastAt or 0) - (run.startedAt or 0)) / 60)
  if not event then
    trace("left %s (%s): not recorded, %s", tostring(run.name), tostring(run.kind), reason)
    return
  end
  trace("left %s (%s) after %d min, %d bosses, won %s, %d companions: recorded", tostring(run.name),
    tostring(run.kind), minutes, run.bossCount or 0, tostring(run.won), #event.with)
  ns.FeedTracker.record(db().self.chars[guid], { event }, false, run.day)
end

-- Where are we: ends a run that was left, starts one when entering an instance.
-- live: the character was playing until now (a zone change); false at login, where the time since the
-- logout does not count (the run ends at its last event or the logout).
local function check(now, live)
  local guid = selfGuid()
  if not guid then return end
  local run = db().runs[guid]
  local info = ns.Instance.info()
  trace("instance: %s", info and describe(info.name, info.type, info.instanceID) or "unknown")
  if not info then return end -- not readable: keep the run as it is
  if run and live then ns.Runs.touch(run, now) end
  if run and ns.Runs.same(run, info) then return end
  if run then finish(guid, run) end
  run = ns.Runs.start(info, now, ns.FeedTracker.today())
  if run then
    db().runs[guid] = run
    trace("entered %s (%s): run started", run.name, run.kind)
    addCompanions(run, guid)
  end
end

local function onEvent(event, ...)
  trace("%s: %s", event, describe(...))
  local now = GetServerTime()
  if event == "PLAYER_ENTERING_WORLD" then
    local isInitialLogin = ...
    check(now, isInitialLogin ~= true)
    return
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    check(now, true)
    return
  end
  local guid = selfGuid()
  local run = guid and db().runs[guid]
  if not run then return end
  if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
    ns.Runs.touch(run, now) -- the time inside counts until here
  elseif event == "ENCOUNTER_END" then
    -- Mainline: encounterID, encounterName, difficultyID, groupSize, success (1 = killed).
    local encounterID, _, _, _, success = ...
    if success == 1 and ns.Runs.boss(run, encounterID, now) then
      trace("boss killed (encounter %s): %d bosses", tostring(encounterID), run.bossCount)
    end
    addCompanions(run, guid)
  elseif event == "BOSS_KILL" then
    -- Mainline: encounterID, encounterName. A second source for the same kill (counted once).
    local encounterID = ...
    if ns.Runs.boss(run, encounterID, now) then
      trace("boss killed (BOSS_KILL %s): %d bosses", tostring(encounterID), run.bossCount)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    ns.Runs.touch(run, now)
    addCompanions(run, guid)
  elseif event == "PVP_MATCH_COMPLETE" or event == "UPDATE_BATTLEFIELD_STATUS" then
    if run.kind ~= "pvp" or run.ended then return end
    -- PVP_MATCH_COMPLETE passes the winner (Mainline); otherwise GetBattlefieldWinner once it is set.
    local winner = event == "PVP_MATCH_COMPLETE" and type((...)) == "number" and (...) or ns.Instance.winner()
    if winner == nil and event == "UPDATE_BATTLEFIELD_STATUS" then return end -- still running
    local team = ns.Instance.team() or ns.Runs.teamOf(ns.SelfInfo.read().faction)
    ns.Runs.matchEnded(run, winner, team, now)
    addCompanions(run, guid)
    trace("battleground ended: winner %s, your team %s, won %s", tostring(winner), tostring(team),
      tostring(run.won))
  end
end

function ActivityTracker.start(addon)
  addonRef = addon
  db().runs = db().runs or {}
  addon:RegisterMessage(ns.Instance.EVENT, function(_, event, ...) onEvent(event, ...) end)
  ns.Instance.watch(addon)
  check(GetServerTime(), false)
end

-- The run in progress on the current character (for /cf activity), or nil.
function ActivityTracker.current()
  local guid = selfGuid()
  return guid and db().runs[guid] or nil
end

ns.ActivityTracker = ActivityTracker
return ActivityTracker
