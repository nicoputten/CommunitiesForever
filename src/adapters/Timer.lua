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

-- Runs fn every `seconds` (CF-53). C_Timer.NewTicker is unverified on Forever (VERIFY.md V82): without it
-- nothing repeats. Returns true when it runs.
function Timer.every(seconds, fn)
  if not (C_Timer and C_Timer.NewTicker) then return false end
  C_Timer.NewTicker(seconds, fn)
  return true
end

ns.Timer = Timer
return Timer
