-- Calendar: day numbers (days since 1970-01-01) and calendar dates, for the activity feed's realm days and
-- Doomsday's days (CF-59: one copy). Pure Lua, no WoW globals.
local _, ns = ...

local Calendar = {}

-- Day number of a calendar date (days from civil, Howard Hinnant's algorithm).
function Calendar.dayNumber(year, month, day)
  local y = month <= 2 and year - 1 or year
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local m = month <= 2 and month + 9 or month - 3
  local doy = math.floor((153 * m + 2) / 5) + day - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- Calendar date of a day number: year, month, day (civil from days, the inverse of dayNumber).
function Calendar.date(dayNumber)
  local z = dayNumber + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp < 10 and mp + 3 or mp - 9
  return yoe + era * 400 + (m <= 2 and 1 or 0), m, d
end

-- Weekday of a day number: 0 Sunday to 6 Saturday (day 0 was a Thursday).
function Calendar.weekday(dayNumber)
  return (dayNumber + 4) % 7
end

Calendar.WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
Calendar.MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

ns.Calendar = Calendar
return Calendar
