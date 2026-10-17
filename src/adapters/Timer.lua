-- Timer: C_Timer helpers (C_Timer.NewTimer verified, API-FINDINGS.md).
local _, ns = ...

local Timer = {}

-- Returns a function that runs fn once, `seconds` after the last call to it.
function Timer.debounce(seconds, fn)
  local pending
  return function()
    if pending then
      pending:Cancel()
    end
    pending = C_Timer.NewTimer(seconds, function()
      pending = nil
      fn()
    end)
  end
end

ns.Timer = Timer
return Timer
