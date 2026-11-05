-- Celebrate: the celebration banners (CF-67; rules in core/Celebrations.lua, drawing in ui/CelebrationBanner.lua).
-- Your goals done (DoomsdayTracker.CHANGED), your new feats (DoomsdayBoard.FEATS) and friends' big moments (a
-- record arrived: Sync.PEOPLE_UPDATED) become banners and lines; they wait while you are busy (combat, an
-- encounter, a battleground or arena), fold when several come at once, and play one game sound. What is shown is
-- remembered in self.doomsday.celebrated (local, never sent), so a /reload shows nothing twice:
-- { own = { [key] = true }, friends = { [friend] = { keys, chars } } }.
local _, ns = ...

local Celebrate = {}

local addonRef, events
local queue, waiting = nil, {}
local timer
local startedAt, since -- GetTime() and server time at login (or /reload)

local function settings() return addonRef.db.global.settings end
local function own() return addonRef.db.global.self end

-- The switches (nil = on, CB09).
function Celebrate.bannersOn() return addonRef ~= nil and settings().celebrations ~= false end
function Celebrate.soundsOn() return addonRef ~= nil and settings().celebrationSounds ~= false end
function Celebrate.friendsOn() return Celebrate.bannersOn() and settings().celebrationFriends ~= false end

-- CF-85: without a community this character is in (none selected, or not a member), Doomsday is tracked quietly:
-- moments are remembered as shown, but no banner, line or sound comes up (the same gate as DoomsdayAlerts' lines).
function Celebrate.quiet() return ns.CommunitySelection.active() == nil end

local function store()
  local s = own()
  s.doomsday = s.doomsday or {}
  local c = s.doomsday.celebrated
  if type(c) ~= "table" then
    c = {}
    s.doomsday.celebrated = c
  end
  c.own = type(c.own) == "table" and c.own or {}
  c.friends = type(c.friends) == "table" and c.friends or {}
  return c
end

local function now() return GetTime and GetTime() or GetServerTime() end

-- Combat, an encounter, a battleground or arena (the same checks as the runs' sync, CF-46).
function Celebrate.busy()
  return ns.Transport.inCombat() or ns.Instance.messagingRestricted()
end

-- Opens the window on the Doomsday view of a banner (CB08).
local function open(view)
  if not ns.MainFrame.isShown() then ns.MainFrame.toggle() end
  ns.MainFrame.selectTab("doomsday")
  ns.DoomsdayTab.select(view or "today")
end

local function ambient() return settings().ambientEffects ~= false end

local check

local function schedule(seconds)
  if timer then return end
  timer = C_Timer.NewTimer(math.max(0.2, seconds or 0.5), function()
    timer = nil
    check()
  end)
end

local function showBanner(b)
  ns.CelebrationBanner.show(b, { ambient = ambient(), scale = ns.Celebrations.scale(ns.Screen.width()),
                                 onClick = open, onDone = function() check() end })
  if Celebrate.soundsOn() then ns.Sounds.celebrate(b.weight) end
end

-- Shows what is due: your banner first; friends' lines only while no banner of yours shows.
function check()
  if not addonRef then return end
  local busy = Celebrate.busy()
  local quiet = Celebrate.quiet()
  if not ns.CelebrationBanner.isShown() then
    local b = ns.Celebrations.take(queue, now(), busy)
    if b and Celebrate.bannersOn() and not quiet then showBanner(b) end
  end
  if quiet then
    for i = #waiting, 1, -1 do waiting[i] = nil end
  elseif not busy and not ns.CelebrationBanner.isShown() then
    while #waiting > 0 and Celebrate.friendsOn() do
      if not ns.CelebrationBanner.showFriend(waiting[1], { ambient = ambient(), onClick = open,
                                                          onDone = function() check() end }) then
        break
      end
      table.remove(waiting, 1)
    end
  end
  local wait = ns.Celebrations.waitFor(queue, now())
  if wait or (#waiting > 0 and not ns.CelebrationBanner.isShown()) then
    schedule(busy and 1 or wait or 1)
  end
end

-- Moments of yours: remembered by key (nothing twice), then queued.
local function add(moments, guid)
  if not Celebrate.bannersOn() then return end
  local day = ns.DoomsdayTracker.today()
  local week = ns.Doomsday.week(day)
  local c = store()
  local list = {}
  for _, m in ipairs(moments) do
    if ns.Celebrations.once(c.own, ns.Celebrations.ownKey(m, day, week, m.guid or guid)) then list[#list + 1] = m end
  end
  ns.Celebrations.prune(c.own, day, week)
  if #list == 0 or Celebrate.quiet() then return end -- CF-85: quiet, yet known: nothing comes up later
  ns.Celebrations.push(queue, list, now())
  check()
end

-- Goals just done (DoomsdayTracker.CHANGED: newly done today, this week).
local function goalsDone(newly, weekly)
  if #(newly or {}) + #(weekly or {}) == 0 then return end
  local state = ns.DoomsdayTracker.state()
  if not state then return end
  local weekStart = ns.Doomsday.dayStart(ns.Doomsday.weekStart(state.week), state.offset, state.reset)
  add(ns.Celebrations.goalMoments({
    newly = newly, weekly = weekly, today = state.today, thisWeek = state.thisWeek, dayLabel = state.label,
    weekLabel = date and ns.Celebrations.weekLabel(weekStart, date) or nil,
    duelDone = #(state.duels and state.duels.done or {}) > 0, hunts = state.hunts,
    crownMine = state.crown ~= nil and state.crown.mine == true, points = ns.DoomsdayView.todayPoints(state),
    streak = state.streak,
  }))
end

-- The derived feats of every character but one of yours: your other characters and every friend's (first in the
-- group, CB04).
local function othersFeats(exceptGuid)
  local others = {}
  local function derive(chars, feed)
    for guid, c in pairs(type(chars) == "table" and chars or {}) do
      if guid ~= exceptGuid and type(c) == "table" then
        local entries = {}
        for _, day in pairs(type(feed) == "table" and feed or {}) do
          if type(day) == "table" and type(day[guid]) == "table" then entries[#entries + 1] = day[guid] end
        end
        others[#others + 1] = ns.Feats.derive(c, entries)
      end
    end
  end
  derive(own().chars, own().feed)
  for bt, person in pairs(addonRef.db.global.people or {}) do
    if bt ~= own().battleTag then derive(person.chars, person.feed) end
  end
  return others
end

-- Your new feats (DoomsdayBoard.FEATS). Those found just after login were there before: known, not new.
local function featsNew(list)
  if now() - (startedAt or 0) < ns.Celebrations.LOGIN_QUIET then return end
  local moments = {}
  for _, entry in ipairs(list or {}) do
    local c = own().chars[entry.guid]
    if entry.feat and c then
      local m = ns.Celebrations.featMoment(entry.feat, c.name,
        ns.Celebrations.firstInGroup(entry.key, othersFeats(entry.guid)))
      m.guid = entry.guid
      moments[#moments + 1] = m
    end
  end
  add(moments)
end

-- Friends' records changed: their new big moments wait for their turn. Always remembered, shown only when on.
local function peopleUpdated()
  if not addonRef then return end
  local day = ns.DoomsdayTracker.today()
  local people = {}
  for bt, person in pairs(addonRef.db.global.people or {}) do
    if bt ~= own().battleTag and not tostring(bt):match("^aid:") and type(person) == "table" then
      people[bt] = person
    end
  end
  local lines = ns.Celebrations.friendMoments(store().friends, people, { day = day, week = ns.Doomsday.week(day),
                                              now = GetServerTime(), since = since, derive = ns.Feats.derive })
  if #lines == 0 or not Celebrate.friendsOn() or Celebrate.quiet() then return end
  ns.Celebrations.pushFriends(waiting, lines)
  check()
end

-- The settings' Preview (CB09): a medium sample banner at once, with its sound when sounds are on.
function Celebrate.preview()
  if not addonRef then return end
  local state = ns.DoomsdayTracker.state()
  showBanner(ns.Celebrations.preview(state and state.label))
end

function Celebrate.start(addon)
  addonRef = addon
  queue, waiting, timer = ns.Celebrations.newQueue(), {}, nil
  startedAt, since = now(), GetServerTime()
  store()
  events = events or LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.DoomsdayTracker.CHANGED, function(_, newly, weekly) goalsDone(newly, weekly) end)
  events:RegisterMessage(ns.DoomsdayBoard.FEATS, function(_, list) featsNew(list) end)
  events:RegisterMessage(ns.Sync.PEOPLE_UPDATED, peopleUpdated)
  events:RegisterMessage(ns.Transport.COMBAT_ENDED, function() check() end)
  peopleUpdated() -- the records you have: known from now on
end

-- For the specs.
function Celebrate.queue() return queue end
function Celebrate.waiting() return waiting end
function Celebrate.check() check() end

ns.Celebrate = Celebrate
return Celebrate
