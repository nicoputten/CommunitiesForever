-- RunStart: the reminder and the start of a planned run (CF-48). Pure Lua, no WoW globals.
-- When a reminder or a start is due, and at start time who is where: ready on the character they signed up
-- with, online on another character, offline, already in your group, or not coming.
local _, ns = ...

local RunStart = {}

RunStart.TICK = 15 -- seconds between checks
RunStart.DEFAULT_REMINDER = 30 -- minutes, when the runs data has none

local ORDER = { ["in"] = 1, maybe = 2, cant = 3 }

local function involved(run, me)
  if ns.PlannedRuns.isOrganiser(run, me) then return true end
  local mine = ns.PlannedRuns.yourAnswer(run, me)
  return mine ~= nil and mine.answer ~= "cant"
end

--[[ What became due after `last` up to `now`: { { kind = "reminder" | "start", run, organiser = true|nil } }.
Only for runs you organise or answered I'm in or Maybe. reminderMinutes: from the runs data (0: none). ]]
function RunStart.due(runs, me, last, now, reminderMinutes)
  local out = {}
  local minutes = reminderMinutes == nil and RunStart.DEFAULT_REMINDER or reminderMinutes
  for _, run in ipairs(runs or {}) do
    if involved(run, me) then
      local organiser = ns.PlannedRuns.isOrganiser(run, me) or nil
      local at = run.startsAt - minutes * 60
      if minutes > 0 and at > last and at <= now then
        out[#out + 1] = { kind = "reminder", run = run, organiser = organiser }
      end
      if run.startsAt > last and run.startsAt <= now then
        out[#out + 1] = { kind = "start", run = run, organiser = organiser }
      end
    end
  end
  return out
end

-- Who is online for an answer: key, presence (from Sync.online: { [key] = { guid, name, level, ... } }).
local function presenceOf(a, ctx)
  local key = a.battleTag or (ctx.keyOf and ctx.keyOf(a))
  local p = key and ctx.online[key]
  if not p and a.guid then
    for k, v in pairs(ctx.online) do
      if v.guid == a.guid then key, p = k, v end
    end
  end
  return key, p
end

--[[ Each friend's state at start time (you left out), I'm in first, then Maybe, then Can't:
  { { answer, key, presence, state = "ready" | "other" | "offline" | "grouped" | "cant" } }
ctx = { online = Sync.online(), keyOf(answer) -> person key or nil (from records by GUID),
        grouped = { [guid] = true } (your group) }.
ready: online on the character they signed up with (or any, when they named none); other: online on another
character (presence.name, presence.level); grouped: already in your group. ]]
function RunStart.states(run, me, ctx)
  local list = {}
  for _, a in ipairs(run.answers or {}) do
    if not ns.PlannedRuns.yourAnswer({ answers = { a } }, me) then
      local key, p = presenceOf(a, ctx)
      local state
      if a.answer == "cant" then
        state = "cant"
      elseif (a.guid and ctx.grouped[a.guid]) or (p and p.guid and ctx.grouped[p.guid]) then
        state = "grouped"
      elseif p and (not a.guid or p.guid == a.guid) then
        state = "ready"
      elseif p then
        state = "other"
      else
        state = "offline"
      end
      list[#list + 1] = { answer = a, key = key, presence = p, state = state }
    end
  end
  table.sort(list, function(x, y)
    local ox, oy = ORDER[x.answer.answer] or 9, ORDER[y.answer.answer] or 9
    if ox ~= oy then return ox < oy end
    return tostring(x.answer.name) < tostring(y.answer.name)
  end)
  return list
end

-- Invite everyone ready: "I'm in" answers online on their character, not grouped yet.
function RunStart.readyToInvite(states)
  local out = {}
  for _, s in ipairs(states) do
    if s.state == "ready" and s.answer.answer == "in" then out[#out + 1] = s end
  end
  return out
end

-- Ping everyone missing: I'm in or Maybe, offline (a ping on Discord reaches them outside the game).
function RunStart.missing(states)
  local out = {}
  for _, s in ipairs(states) do
    if s.state == "offline" and s.answer.answer ~= "cant" then out[#out + 1] = s end
  end
  return out
end

-- For everyone else: the organiser's state ("online", "other", "offline") and presence.
function RunStart.organiserState(run, ctx)
  local organiser = run.organiser
  if not organiser then return "offline", nil end
  local _, p = presenceOf(organiser, ctx)
  if not p then return "offline", nil end
  if organiser.guid and p.guid ~= organiser.guid then return "other", p end
  return "online", p
end

-- When the organiser is offline: the next person to whisper, the first ready "I'm in" answer.
function RunStart.nextPerson(states)
  for _, s in ipairs(states) do
    if s.state == "ready" and s.answer.answer == "in" then return s end
  end
  return nil
end

-- The whisper to a friend on another character (editable before sending).
function RunStart.switchText(dungeonName, current, signedUp)
  return string.format("You're on %s. Switch to %s? We're starting %s.", tostring(current), tostring(signedUp),
    tostring(dungeonName))
end

ns.RunStart = RunStart
return RunStart
