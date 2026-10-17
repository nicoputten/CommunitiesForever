-- ViewModel: gathers tracker and DB state and runs the Linker. The UI renders its result only.
local _, ns = ...

local ViewModel = {}

function ViewModel.build(addon)
  local global = addon.db.global
  return ns.Linker.build({
    members = ns.MemberTracker.members(),
    friends = ns.PresenceTracker.friends(),
    online = ns.PresenceTracker.online(),
    people = global.people,
    presence = global.presence,
    self = global.self,
    selfGuid = ns.SelfInfo.read().guid,
    nicknames = global.nicknames,
  })
end

ns.ViewModel = ViewModel
return ViewModel
