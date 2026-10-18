-- Calendar: reading calendar events and opening Blizzard's calendar (CF-24). Thin, guarded wrappers.
-- Reading is verified (V33); creating events is blocked for addons (V34). How a community event
-- looks in GetDayEvent and the calendar toggle are unverified (VERIFY.md V42).
local _, ns = ...

local Calendar = {}

-- Internal message: the event list arrived or changed (after OpenCalendar).
Calendar.UPDATED = "CF_CALENDAR_UPDATED"

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

-- Events this month and next: { { title, calendarType, eventType, startTime, inviteStatus, invitedBy } }.
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
                                  startTime = e.startTime, inviteStatus = e.inviteStatus, invitedBy = e.invitedBy }
        end
      end
    end
  end
  return events
end

-- Opens Blizzard's calendar. ToggleCalendar is unverified on Forever (V42). Returns true if it opened.
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
end

ns.Calendar = Calendar
return Calendar
