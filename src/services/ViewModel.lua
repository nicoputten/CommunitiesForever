-- ViewModel: gathers tracker and DB state and runs the Linker. The UI renders its result only.
local _, ns = ...

local ViewModel = {}

-- Returns the Linker view model plus selfName (the character you are on, for messages).
function ViewModel.build(addon)
  local global = addon.db.global
  local player = ns.SelfInfo.read()
  local view = ns.Linker.build({
    members = ns.MemberTracker.members(),
    friends = ns.PresenceTracker.friends(),
    online = ns.Sync.online(),   -- CF-28: Battle.net friends and community peers
    offline = ns.Sync.offline(), -- CF-28: said BYE since their last HELLO
    people = global.people,
    presence = global.presence,
    locations = global.locations,
    self = global.self,
    selfGuid = player.guid,
  })
  view.selfName = player.name
  if ns.Debug.enabled() then ns.Debug.decorate(view, player.guid, GetServerTime()) end -- hidden /cf debugon, view only
  return view
end

ns.ViewModel = ViewModel
return ViewModel
