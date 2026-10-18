-- Planner: calendar events for the dungeon planner (CF-24). Reads the event list at login and when it
-- changes, and the sign-ups of runs planned within Dungeons.PLANNED_DAYS: those need each event opened
-- (C_Calendar.OpenEvent, one at a time, V43), so they are fetched in a queue.
local _, ns = ...

local Planner = {}

-- Internal message: the events or sign-up counts changed (the window refreshes).
Planner.UPDATED = "CF_PLANNER_UPDATED"

Planner.OPEN_TIMEOUT = 5 -- seconds to wait for CALENDAR_OPEN_EVENT before giving up on an event

local addonRef
local events = {}
local signUps = {} -- event key -> { signed, tentative }, or false when it could not be read
local queue, opening = {}, nil

local function key(e)
  return tostring(e.title) .. "@" .. ns.Dungeons.eventTime(e.startTime)
end

local openNext

local function finishOpening(result)
  if not opening then return end
  signUps[key(opening)] = result
  opening = nil
  addonRef:SendMessage(Planner.UPDATED)
  openNext()
end

function openNext()
  if opening or #queue == 0 then return end
  opening = table.remove(queue, 1)
  if not ns.Calendar.openEvent(opening.offset, opening.day, opening.index) then
    queue = {}
    finishOpening(false)
    return
  end
  local waiting = opening
  C_Timer.NewTimer(Planner.OPEN_TIMEOUT, function()
    if opening == waiting then finishOpening(false) end
  end)
end

local function refresh()
  events = ns.Calendar.events()
  local queued = {}
  for _, e in ipairs(queue) do queued[key(e)] = true end
  if opening then queued[key(opening)] = true end
  for _, p in ipairs(ns.Dungeons.planned(events, ns.Calendar.now())) do
    local k = key(p.event)
    if signUps[k] == nil and not queued[k] then
      queue[#queue + 1] = p.event
      queued[k] = true
    end
  end
  addonRef:SendMessage(Planner.UPDATED)
  openNext()
end

function Planner.start(addon)
  addonRef = addon
  events, signUps, queue, opening = {}, {}, {}, nil
  addon:RegisterMessage(ns.Calendar.UPDATED, refresh)
  addon:RegisterMessage(ns.Calendar.EVENT_OPENED, function()
    if not opening then return end
    local statuses = ns.Calendar.invites()
    ns.Calendar.closeEvent()
    finishOpening({ ns.Dungeons.signUps(statuses) })
  end)
  ns.Calendar.request()
end

-- Asks for the event list again (the Dungeons tab does when it opens).
function Planner.request()
  ns.Calendar.request()
end

function Planner.events() return events end

-- Runs planned within PLANNED_DAYS: { { dungeon, event, signed, tentative } } (counts nil when unknown).
function Planner.planned()
  local result = ns.Dungeons.planned(events, ns.Calendar.now())
  for _, p in ipairs(result) do
    local counts = signUps[key(p.event)]
    if counts then p.signed, p.tentative = counts[1], counts[2] end
  end
  return result
end

-- Sign-ups of an event when known: signed, tentative.
function Planner.signUpsOf(event)
  local counts = signUps[key(event)]
  if counts then return counts[1], counts[2] end
  return nil
end

ns.Planner = Planner
return Planner
