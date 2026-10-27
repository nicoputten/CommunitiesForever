-- Queue: a small first-in, first-out list with a limit (CF-44: level-up announcements shown one at a time).
-- Pure Lua, no WoW globals.
local _, ns = ...

local Queue = {}

-- Adds item at the end. With more than max items waiting, the oldest are dropped. Returns how many dropped.
function Queue.push(list, item, max)
  list[#list + 1] = item
  local dropped = 0
  while max and #list > max do
    table.remove(list, 1)
    dropped = dropped + 1
  end
  return dropped
end

-- Takes the first item, or nil when the queue is empty.
function Queue.pop(list)
  return table.remove(list, 1)
end

ns.Queue = Queue
return Queue
