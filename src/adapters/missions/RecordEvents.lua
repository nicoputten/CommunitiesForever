-- RecordEvents: the events of the records missions (CF-72). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Records.lua.
-- Level-ups (SelfInfo "level"), boss kills of the current party run (Instance events, read after
-- ActivityTracker counted them), professions (SelfTracker.UPDATED) and the login.
-- Local stored data: self.doomsday.dungeonsSeen and self.doomsday.lastLogin (see Records).
local _, ns = ...

local RecordEvents = {}

local BOSS_EVENTS = { ENCOUNTER_END = true, BOSS_KILL = true }
local addonRef, events

local function own() return addonRef.db.global.self end

local function doomsday()
  local s = own()
  s.doomsday = s.doomsday or {}
  return s.doomsday
end

local function send(kind, obs)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs)
end

local function members()
  local ok, list = pcall(ns.MemberTracker.members)
  return ok and type(list) == "table" and list or {}
end

local function onLevel(level)
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  local info = ns.Instance.info()
  local g = addonRef.db.global
  send("recordDing", {
    guid = guid,
    level = type(level) == "number" and level or nil,
    instance = info and info.type,
    friend = ns.Missions.Records.friendGrouped(ns.Instance.groupGuids(), members(), g.people, g.presence,
      own().battleTag),
    day = ns.DoomsdayTracker.today(),
  })
end

-- After a boss kill: the current run as ActivityTracker keeps it (db.global.runs[guid]).
local function onBoss()
  local guid = ns.SelfInfo.guid()
  local run = guid and addonRef.db.global.runs and addonRef.db.global.runs[guid]
  if type(run) ~= "table" or run.kind ~= "party" or (run.bossCount or 0) < 1 then return end
  local d = doomsday()
  d.dungeonsSeen = d.dungeonsSeen or {}
  send("recordBoss", {
    guid = guid,
    name = run.name,
    bosses = run.bossCount,
    seconds = GetServerTime() - (run.startedAt or GetServerTime()),
    new = ns.Missions.Records.markDungeon(d.dungeonsSeen, guid, run.name),
  })
end

local function onSkills()
  local guid = ns.SelfInfo.guid()
  local char = guid and own().chars and own().chars[guid]
  if not char then return end
  local profs = {}
  for line, p in pairs(char.professions or {}) do
    if type(p) == "table" then profs[line] = p.rank end
  end
  send("recordSkills", { guid = guid, professions = profs })
end

local function onLogin()
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  local d = doomsday()
  d.lastLogin = d.lastLogin or {}
  local now = GetServerTime()
  local previous = ns.Missions.Records.login(d.lastLogin, own().chars, guid, now)
  local today, schedule = ns.DoomsdayTracker.today()
  send("recordLogin", { guid = guid, previous = previous, now = now,
                        since = ns.Doomsday.dayStart(today - 1, schedule.offset, schedule.reset) })
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function RecordEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace SelfTracker's and ActivityTracker's handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  -- ActivityTracker counts the boss in the same message: read the run a moment later.
  local bossLater = ns.Timer.debounce(0.5, onBoss)
  events:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason, arg)
    if reason == "level" then
      onLevel(arg)
    elseif reason == "logout" then
      ns.Missions.Records.played(doomsday().lastLogin, ns.SelfInfo.guid(), GetServerTime())
    end
  end)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if BOSS_EVENTS[event] then bossLater() end
  end)
  events:RegisterMessage(ns.SelfTracker.UPDATED, onSkills)
  -- The dungeons of the stored feed count as run once, at the first start with CF-72.
  local d = doomsday()
  if d.dungeonsSeen == nil then d.dungeonsSeen = ns.Missions.Records.seedDungeons(own().feed) end
  onLogin()
  onSkills()
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Records = RecordEvents
return RecordEvents
