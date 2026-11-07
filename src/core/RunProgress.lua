-- RunProgress: a planned run's boss progress, its place in the Runs tab and the tab's badge (CF-106, board DL01).
-- Pure Lua, no WoW globals. The progress rule is shared with the site (tests/fixtures/run-progress-cases.json).
-- Requires ns.Dungeons (the fit rule), ns.PlannedRuns (answers) and ns.Calendar.
local _, ns = ...

local RunProgress = {}

RunProgress.BEFORE = 3600          -- kills count from this long before the start ...
RunProgress.NO_BOSS_FOR = 3 * 3600 -- a run without a kill leaves the list this long after its start

-- The characters of a run's group: those who answered I'm in or Maybe, and the organiser ({ [guid] = true }).
function RunProgress.group(run)
  local set = {}
  for _, a in ipairs(type(run) == "table" and run.answers or {}) do
    if type(a) == "table" and type(a.guid) == "string" and (a.answer == "in" or a.answer == "maybe") then
      set[a.guid] = true
    end
  end
  local o = type(run) == "table" and run.organiser
  if type(o) == "table" and type(o.guid) == "string" then set[o.guid] = true end
  return set
end

--[[ A run's boss progress (designer's rules 2026-11-07):
  run = { startsAt, state, answers, organiser }; bosses = DungeonLoot.bosses (id, name, final, optional);
  kills = { { guid, encounterID, at } } (the kill log, any character); now; resetAt = the first daily reset after
  the start (the Doomsday day boundary).
A kill counts when its character is in the run's group, its encounter is one of the dungeon's bosses and it is from
BEFORE before the start until resetAt. Optional bosses don't count; cleared = the final boss died; on a cleared run
an optional boss not killed is skipped.
Returns { state = "upcoming" | "noBoss" | "going" | "cleared", killed = { [encounterID] = at }, done, total,
cleared, skipped = { [encounterID] = true }, firstKill, visible, label }. visible: in the addon's list: before the
start; NO_BOSS_FOR after it without a kill; until resetAt with kills. A cancelled run is never visible. ]]
function RunProgress.progress(run, bosses, kills, now, resetAt)
  local p = { killed = {}, done = 0, total = 0, cleared = false, skipped = {} }
  local startsAt = type(run) == "table" and run.startsAt or 0
  local group = RunProgress.group(run)
  local byId = {}
  for _, b in ipairs(bosses or {}) do
    if b.id ~= nil then byId[b.id] = b end
    if not b.optional then p.total = p.total + 1 end
  end
  local any = false
  for _, k in ipairs(kills or {}) do
    local b = type(k) == "table" and byId[k.encounterID]
    if b and group[k.guid] and type(k.at) == "number" and k.at >= startsAt - RunProgress.BEFORE
       and (type(resetAt) ~= "number" or k.at < resetAt) then
      if not p.killed[b.id] or k.at < p.killed[b.id] then p.killed[b.id] = k.at end
      if not p.firstKill or k.at < p.firstKill then p.firstKill = k.at end
      any = true
    end
  end
  for id, _ in pairs(p.killed) do
    local b = byId[id]
    if not b.optional then p.done = p.done + 1 end
    if b.final then p.cleared = true end
  end
  if p.cleared then
    for _, b in ipairs(bosses or {}) do
      if b.optional and not p.killed[b.id] then p.skipped[b.id] = true end
    end
  end
  if any then
    p.state = p.cleared and "cleared" or "going"
    p.label = string.format("%d/%d bosses", p.done, p.total)
  elseif now >= startsAt then
    p.state = "noBoss"
    p.label = "no boss yet"
  else
    p.state = "upcoming"
  end
  if type(run) == "table" and run.state == "cancelled" then
    p.visible = false
  elseif p.state == "upcoming" then
    p.visible = true
  elseif p.state == "noBoss" then
    p.visible = now < startsAt + RunProgress.NO_BOSS_FOR
  else
    p.visible = type(resetAt) ~= "number" or now < resetAt
  end
  return p
end

-- True when at least one of the levels fits the dungeon (an unknown dungeon fits everyone: nothing to say no to).
function RunProgress.anyFits(dungeon, levels)
  if not dungeon then return true end
  for _, level in ipairs(levels or {}) do
    if ns.Dungeons.fits(dungeon, level) then return true end
  end
  return false
end

--[[ A run row's status on the right (board DL01, DL03 E): "noBoss" (started, no kill yet), your answer "in" |
"maybe" | "cant", "organiser", "nofit" (none of your characters fits; you can still answer), "answer" (waiting for
yours). ctx = { me, levels = your characters' levels, dungeon, progress }. ]]
function RunProgress.rowStatus(run, ctx)
  if ctx.progress and ctx.progress.state == "noBoss" then return "noBoss" end
  local mine = ns.PlannedRuns.yourAnswer(run, ctx.me)
  if mine and (mine.answer == "in" or mine.answer == "maybe" or mine.answer == "cant") then return mine.answer end
  if ns.PlannedRuns.isOrganiser(run, ctx.me) then return "organiser" end
  if not RunProgress.anyFits(ctx.dungeon, ctx.levels) then return "nofit" end
  return "answer"
end

--[[ The badge on the Runs tab: runs that haven't started, that you haven't answered (nor organise), and where at
least one of your characters fits. "No fit" runs never count. ctx = { me, levels, dungeonOf(run), now }. ]]
function RunProgress.badge(runs, ctx)
  local n = 0
  for _, run in ipairs(runs or {}) do
    if run.state ~= "cancelled" and type(run.startsAt) == "number" and ctx.now < run.startsAt
       and not ns.PlannedRuns.yourAnswer(run, ctx.me) and not ns.PlannedRuns.isOrganiser(run, ctx.me)
       and RunProgress.anyFits(ctx.dungeonOf and ctx.dungeonOf(run), ctx.levels) then
      n = n + 1
    end
  end
  return n
end

-- The day group of a run by its local start: "Today" (started ones too), "Tomorrow" or "Later". dateFn: os.date or
-- the game's date.
RunProgress.DAYS = { "Today", "Tomorrow", "Later" }
function RunProgress.dayGroup(at, now, dateFn)
  local t, n = dateFn("*t", at), dateFn("*t", now)
  local diff = ns.Calendar.dayNumber(t.year, t.month, t.day) - ns.Calendar.dayNumber(n.year, n.month, n.day)
  if diff <= 0 then return "Today" end
  if diff == 1 then return "Tomorrow" end
  return "Later"
end

ns.RunProgress = RunProgress
return RunProgress
