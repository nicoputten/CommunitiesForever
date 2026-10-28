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
  -- CF-57: what the card needs for this week's PvP points (the schedule, the community's names).
  local community = {}
  for _, m in pairs(ns.MemberTracker.members() or {}) do
    if m.name then community[m.name] = true end
  end
  view.doomsday = { schedule = ns.DoomsdayTracker.schedule(), community = community }
  if ns.Debug.enabled() then ns.Debug.decorate(view, player.guid, GetServerTime()) end -- hidden /cf debugon, view only
  return view
end

ns.ViewModel = ViewModel
return ViewModel
