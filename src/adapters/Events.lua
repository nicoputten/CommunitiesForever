-- Events: guarded WoW event registration. Registering an event the client
-- does not know raises an error, so unverified event names go through here.
local _, ns = ...

local Events = {}

-- C_EventUtils.IsEventValid is unverified on Forever (VERIFY.md V13); without it, assume valid.
function Events.isValid(event)
  if C_EventUtils and C_EventUtils.IsEventValid then
    return C_EventUtils.IsEventValid(event)
  end
  return true
end

-- Registers event on an AceEvent object if the client knows it. Returns true if registered.
function Events.register(target, event, handler)
  if not Events.isValid(event) then
    return false
  end
  target:RegisterEvent(event, handler)
  return true
end

ns.Events = Events
return Events
