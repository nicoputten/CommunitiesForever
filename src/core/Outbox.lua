-- Outbox: FIFO queue of outgoing chunks with a send-rate limit. Pure Lua, no WoW globals.
local _, ns = ...

local Outbox = {}

Outbox.DEFAULT_INTERVAL = 0.2 -- seconds between chunks, across all targets

--[[ local box = Outbox.new(interval)
  box:push(target, chunk)
  box:pop(now) -> target, chunk          when a chunk may be sent now
               -> nil, waitSeconds       when chunks wait for the rate limit
               -> nil                    when empty
  box:wait(now) -> seconds until the next chunk may go out
  box:size()
  box:drop(target) -> count             removes every queued chunk for target (CF-112: it went offline)
]]
function Outbox.new(interval)
  -- queue[first..last]; explicit indexes because # is unreliable once the front is cleared.
  local box = { interval = interval or Outbox.DEFAULT_INTERVAL, queue = {}, first = 1, last = 0, nextAt = nil }

  function box.push(self, target, chunk)
    self.last = self.last + 1
    self.queue[self.last] = { target = target, chunk = chunk }
  end

  function box.size(self)
    return self.last - self.first + 1
  end

  -- Seconds until the next chunk may be sent (0 = now), without taking anything.
  function box.wait(self, now)
    if not self.nextAt then return 0 end
    return math.max(0, self.nextAt - now)
  end

  function box.drop(self, target)
    local kept, count = {}, 0
    for i = self.first, self.last do
      local item = self.queue[i]
      if item and item.target == target then
        count = count + 1
      elseif item then
        kept[#kept + 1] = item
      end
    end
    if count > 0 then self.queue, self.first, self.last = kept, 1, #kept end
    return count
  end

  function box.pop(self, now)
    if self:size() <= 0 then
      self.queue, self.first, self.last = {}, 1, 0
      return nil
    end
    if self.nextAt and now < self.nextAt then
      return nil, self.nextAt - now
    end
    local item = self.queue[self.first]
    self.queue[self.first] = nil
    self.first = self.first + 1
    self.nextAt = now + self.interval
    return item.target, item.chunk
  end

  return box
end

ns.Outbox = Outbox
return Outbox
