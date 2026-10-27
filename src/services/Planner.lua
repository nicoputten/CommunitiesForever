-- Planner: planned runs for the Dungeons tab (CF-46; CF-24's calendar events were replaced). The runs come
-- from Data\Runs.lua (written by the uploader, read at login and /reload) and from friends' addons over
-- sync (Sync.lua: RUNS); the newer updatedAt wins. The newest list is kept in global.plannedRuns, so a
-- friend without the uploader still sees runs after a /reload.
-- CF-47: what you plan, answer or ask to post goes into global.pending (core/Pending.lua) until the runs
-- data lists it as received. Your pending plans and answers show in the list at once; as the organiser you
-- also see answers friends sent from their game (RUNANSWER) before the site has them.
local _, ns = ...

local Planner = {}

-- Internal message: the runs changed (the window refreshes).
Planner.UPDATED = "CF_PLANNER_UPDATED"

local addonRef
local current     -- checked runs data, see PlannedRuns.validate
local heard = {}  -- CF-47: answers friends sent you as organiser: [runId] = { answer, ... }
local counter = 0

local function global() return addonRef.db.global end

local function now() return GetServerTime() end

local function pending()
  global().pending = type(global().pending) == "table" and global().pending or {}
  return global().pending
end

-- Keeps data when newer than what we have. Returns true when it was taken.
local function take(data)
  if not ns.PlannedRuns.isNewer(current, data, now()) then return false end
  current = data
  global().plannedRuns = ns.PlannedRuns.wire(data)
  ns.Pending.confirm(pending(), data.received) -- CF-47: what the site has is no longer pending
  return true
end

function Planner.start(addon)
  addonRef = addon
  current, heard = nil, {}
  -- The dungeon list from the game's Group Finder (names and level ranges, Forever's new dungeons).
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
  -- Stored runs are checked again: SavedVariables are a file too.
  local ok, stored = pcall(ns.PlannedRuns.validate, global().plannedRuns)
  if ok and stored then current = stored end
  take(ns.RunsFile.read())
  ns.Pending.prune(pending(), now())
  -- CF-47: an ask older than 10 minutes when the game saves is not posted.
  local events = LibStub("AceEvent-3.0"):Embed({})
  ns.Events.register(events, "PLAYER_LOGOUT", function() ns.Pending.prune(pending(), now()) end)
end

-- The checked runs data, or nil.
function Planner.data() return current end

-- updatedAt of the runs we have (0: none), for HELLO (Sync.lua).
function Planner.updatedAt() return current and current.updatedAt or 0 end

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

local function samePerson(a, b, me)
  if a.guid and a.guid == b.guid then return true end
  if a.battleTag and a.battleTag == b.battleTag then return true end
  return me ~= nil and ns.PlannedRuns.yourAnswer({ answers = { a } }, me) ~= nil
    and ns.PlannedRuns.yourAnswer({ answers = { b } }, me) ~= nil
end

-- A copy of the run with answer a in place of that person's earlier one.
local function withAnswer(run, a, me)
  local copy = {}
  for k, v in pairs(run) do copy[k] = v end
  copy.answers = {}
  for _, old in ipairs(run.answers or {}) do
    if not samePerson(old, a, me) then copy.answers[#copy.answers + 1] = old end
  end
  copy.answers[#copy.answers + 1] = a
  return copy
end

-- Runs to show now, soonest first: the runs data with your pending plans and answers, and (as organiser)
-- answers friends sent you. pending = true on what has not reached the site yet.
function Planner.upcoming()
  local me = Planner.me()
  local list = ns.PlannedRuns.upcoming(current, now())
  for i, run in ipairs(list) do
    for _, a in ipairs(heard[run.id] or {}) do run = withAnswer(run, a, nil) end
    local mine = ns.Pending.answerFor(pending(), run.id)
    if mine then
      run = withAnswer(run, { guid = mine.guid, name = mine.name, battleTag = me.battleTag, answer = mine.answer,
                              role = mine.role, source = "game", pending = true }, me)
    end
    list[i] = run
  end
  for _, plan in ipairs(ns.Pending.ofKind(pending(), "plan")) do
    if plan.startsAt >= now() - ns.PlannedRuns.KEEP_STARTED then
      local lead = { guid = plan.guid, name = plan.name, battleTag = me.battleTag }
      list[#list + 1] = { id = plan.id, dungeon = plan.dungeon, startsAt = plan.startsAt, note = plan.note,
        source = "game", state = "open", pending = true, organiser = lead,
        answers = { { guid = plan.guid, name = plan.name, battleTag = me.battleTag, answer = "in", role = plan.role,
                      source = "game", pending = true } } }
    end
  end
  table.sort(list, function(a, b)
    if a.startsAt ~= b.startsAt then return a.startsAt < b.startsAt end
    return a.id < b.id
  end)
  return list
end

local function nextId()
  counter = counter + 1
  return ns.Pending.newId(global().self.accountId, now(), counter)
end

local function queue(item)
  item.id, item.at = nextId(), now()
  ns.Pending.add(pending(), item)
  addonRef:SendMessage(Planner.UPDATED)
  return item
end

-- CF-47: a run you plan (Plan a run). char = { guid, name, role }; startsAt UTC. Returns the item.
function Planner.plan(dungeonId, startsAt, char, note)
  return queue({ kind = "plan", dungeon = dungeonId, startsAt = startsAt, guid = char.guid, name = char.name,
                 role = char.role, note = ns.Pending.note(note) })
end

-- CF-47: your answer to a run (Sign up in game). Also sent to the organiser's addon when they are online.
function Planner.answer(run, answer, char)
  local item = queue({ kind = "answer", run = run.id, answer = answer, guid = char and char.guid,
                       name = char and char.name, role = char and char.role })
  ns.Sync.sendRunAnswer(run, item)
  return item
end

-- CF-47: an ask now to post on Discord too. char = { guid, name, role }.
function Planner.askOnDiscord(dungeonId, char, note)
  return queue({ kind = "ask", dungeon = dungeonId, guid = char.guid, name = char.name, role = char.role,
                 note = ns.Pending.note(note) })
end

-- CF-48: a Discord ping for a friend missing at start time.
function Planner.ping(run, battleTag)
  return queue({ kind = "ping", run = run.id, battleTag = battleTag })
end

-- True while an item (or your answer to a run) waits for the next /reload or upload.
function Planner.isPending(id)
  for _, item in ipairs(pending()) do
    if item.id == id then return true end
  end
  return false
end

function Planner.pending() return pending() end

-- CF-47: an answer a friend sent you over sync (untrusted). Kept only when you organise that run.
-- message = { run, answer, guid, name, role }; senderKey: their BattleTag or community key.
function Planner.answerReceived(message, senderKey)
  if type(message.run) ~= "string" or not ns.PlannedRuns.ANSWERS[message.answer] then return false end
  local run
  for _, r in ipairs(current and current.runs or {}) do
    if r.id == message.run then run = r end
  end
  if not run or not ns.PlannedRuns.isOrganiser(run, Planner.me()) then return false end
  -- Cleaned like the runs file; the BattleTag only from Battle.net (a community key has no "#").
  local battleTag = type(senderKey) == "string" and senderKey:find("#", 1, true) and senderKey or nil
  local clean = ns.PlannedRuns.validate({ updatedAt = 1, runs = { { id = "x", dungeon = "x", startsAt = 1,
    answers = { { guid = message.guid, name = message.name, answer = message.answer, role = message.role,
                  battleTag = battleTag } } } } })
  local a = clean and clean.runs[1] and clean.runs[1].answers[1]
  if not a then return false end
  a.source = "game"
  local list = heard[run.id] or {}
  for i = #list, 1, -1 do
    if samePerson(list[i], a) then table.remove(list, i) end
  end
  list[#list + 1] = a
  heard[run.id] = list
  addonRef:SendMessage(Planner.UPDATED)
  return true
end

ns.Planner = Planner
return Planner
