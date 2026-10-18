-- Calendar: reading calendar events and opening Blizzard's calendar (CF-24). Thin, guarded wrappers.
-- Reading events and ToggleCalendar are verified (V33, V42); creating events is blocked for addons (V34).
-- Opening an event to read its invites (sign-ups) is unverified (VERIFY.md V43).
local _, ns = ...

local Calendar = {}

-- Internal messages: the event list arrived or changed (after OpenCalendar); an event opened with
-- Calendar.openEvent is loaded (its invites can be read).
Calendar.UPDATED = "CF_CALENDAR_UPDATED"
Calendar.EVENT_OPENED = "CF_CALENDAR_EVENT_OPENED"

local MONTHS_AHEAD = 1 -- this month and the next

-- Asks the client for the event list; CALENDAR_UPDATE_EVENT_LIST follows (V33).
function Calendar.request()
  if C_Calendar and C_Calendar.OpenCalendar then C_Calendar.OpenCalendar() end
end

-- Now as a CalendarTime { year, month, monthDay, weekday, hour, minute } (V36), or nil.
function Calendar.now()
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    return C_DateAndTime.GetCurrentCalendarTime()
  end
  return nil
end

-- Events this month and next: { { title, calendarType, eventType, startTime, inviteStatus, invitedBy,
-- offset, day, index } } (offset, day, index: where the event is, for openEvent).
function Calendar.events()
  local cal = C_Calendar
  if not (cal and cal.GetNumDayEvents and cal.GetDayEvent) then return {} end
  local events = {}
  for offset = 0, MONTHS_AHEAD do
    local info = cal.GetMonthInfo and cal.GetMonthInfo(offset)
    local days = type(info) == "table" and info.numDays or 31
    for day = 1, days do
      for i = 1, cal.GetNumDayEvents(offset, day) or 0 do
        local e = cal.GetDayEvent(offset, day, i)
        if type(e) == "table" then
          events[#events + 1] = { title = e.title, calendarType = e.calendarType, eventType = e.eventType,
                                  startTime = e.startTime, inviteStatus = e.inviteStatus, invitedBy = e.invitedBy,
                                  offset = offset, day = day, index = i }
        end
      end
    end
  end
  return events
end

-- Loads an event's details; CALENDAR_OPEN_EVENT follows (V43). Returns false when it cannot be asked.
function Calendar.openEvent(offset, day, index)
  if not (C_Calendar and C_Calendar.OpenEvent) then return false end
  C_Calendar.OpenEvent(offset, day, index)
  return true
end

-- Invite statuses of the opened event: { status, ... } (Enum.CalendarStatus, V43).
function Calendar.invites()
  local cal, statuses = C_Calendar, {}
  if not (cal and cal.GetNumInvites and cal.EventGetInvite) then return statuses end
  for i = 1, cal.GetNumInvites() or 0 do
    local invite = cal.EventGetInvite(i)
    if type(invite) == "table" and invite.inviteStatus ~= nil then statuses[#statuses + 1] = invite.inviteStatus end
  end
  return statuses
end

function Calendar.closeEvent()
  if C_Calendar and C_Calendar.CloseEvent then C_Calendar.CloseEvent() end
end

-- Opens Blizzard's calendar (verified, V42). Returns true if it opened.
function Calendar.open()
  if ToggleCalendar then
    ToggleCalendar()
    return true
  end
  return false
end

function Calendar.watch(addon)
  local events = LibStub("AceEvent-3.0"):Embed({})
  ns.Events.register(events, "CALENDAR_UPDATE_EVENT_LIST", function()
    addon:SendMessage(Calendar.UPDATED)
  end)
  ns.Events.register(events, "CALENDAR_OPEN_EVENT", function()
    addon:SendMessage(Calendar.EVENT_OPENED)
  end)
end

ns.Calendar = Calendar
return Calendar
