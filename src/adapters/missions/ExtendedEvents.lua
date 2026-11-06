-- ExtendedEvents: the events of the extended missions (CF-74). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Extended.lua.
-- It listens to the existing trackers' messages and doesn't change them: fishing and trades (GoalEvents, V84,
-- V85), loot and money (LootInfo, V83, V105, CF-53), boss kills (Instance events, read after ActivityTracker
-- counted them), group changes, the quest hand-in and logout (SelfInfo), and a minute clock for sessions, the
-- time alive (CF-52's deaths as DoomsdayTracker keeps them) and the night.
-- Local stored data: self.doomsday.sessionMoney and self.doomsday.cooked (see Extended).
local _, ns = ...

local ExtendedEvents = {}

local BOSS_EVENTS = { ENCOUNTER_END = true, BOSS_KILL = true }
local addonRef, events, ticking
local lastHour       -- the local hour last sent (extClock)
local lastTurnIn     -- server time of the last quest hand-in
local pendingReward  -- { at, quality }: an uncommon item received before its quest's hand-in was seen

local function global() return addonRef.db.global end
local function own() return global().self end

local function doomsday()
  local s = own()
  s.doomsday = s.doomsday or {}
  return s.doomsday
end

local function send(kind, obs)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs)
end

local function members()
  local ok, list = pcall(ns.MemberTracker.members)
  return ok and type(list) == "table" and list or {}
end

local function owners()
  return ns.Missions.Places.owners(global().people, global().presence, own().battleTag)
end

-- The current character's last death (server time) as DoomsdayTracker keeps it, or nil.
local function lastDeath(guid)
  local chars = doomsday().chars
  local state = type(chars) == "table" and chars[guid]
  return type(state) == "table" and state.death or nil
end

-- Item class and subclass (C_Item.GetItemInfoInstant, V105), or nil.
local function itemClass(id)
  if not (C_Item and C_Item.GetItemInfoInstant and type(id) == "number") then return nil end
  local classID, subclassID = select(6, ns.Safe.call(C_Item.GetItemInfoInstant, id))
  return classID, subclassID
end

local function grouped()
  return ns.Missions.Extended.friendsInGroup(ns.Instance.groupGuids(), members(), owners(), ns.SelfInfo.zone())
end

-- ===== Fishing and trades (GoalEvents) =====

local function onFish()
  local friends, here = grouped()
  send("extFish", { zone = ns.SelfInfo.zone(), friend = next(friends) ~= nil and here,
                    hour = ns.SelfInfo.gameTime() })
end

local function onTrade(partner, given)
  local friend = type(partner) == "string" and owners()[partner] or nil
  send("extTrade", { friend = friend, fed = ns.Missions.Extended.gaveCooked(given, doomsday().cooked) })
end

-- ===== Loot and money (LootInfo) =====

local function pushedFormats()
  local all = ns.LootInfo.formats()
  return { pushed = all.pushed, pushedMultiple = all.pushedMultiple }
end

local function onLoot(text)
  local Extended = ns.Missions.Extended
  local pushed = ns.Loot.parse(text, pushedFormats())
  local item = pushed or ns.Loot.parse(text, ns.LootInfo.formats())
  if not item then return end
  local quality = Extended.quality(item, (ns.LootInfo.item(item.id)))
  local source = pushed and "pushed" or item.source
  send("extLoot", { source = source, quality = quality, count = item.count })
  if source == "created" and Extended.isFood(itemClass(item.id)) then
    local d = doomsday()
    d.cooked = d.cooked or {}
    Extended.markCooked(d.cooked, item.id)
  elseif source == "pushed" and (quality or -1) >= Extended.UNCOMMON then
    local now = GetServerTime()
    if Extended.isReward(now, lastTurnIn) then
      send("extReward", { quality = quality })
    else
      pendingReward = { at = now, quality = quality }
    end
  end
end

local function onTurnIn()
  lastTurnIn = GetServerTime()
  if pendingReward and ns.Missions.Extended.isReward(pendingReward.at, lastTurnIn) then
    send("extReward", { quality = pendingReward.quality })
  end
  pendingReward = nil
end

local function sessionMoney()
  local d = doomsday()
  local now = GetServerTime()
  d.sessionMoney = ns.Missions.Extended.sessionMoney(d.sessionMoney, ns.SelfInfo.guid(), ns.LootInfo.money(), now)
    or d.sessionMoney
  return d.sessionMoney
end

local function onMoney()
  local start = doomsday().sessionMoney
  local guid = ns.SelfInfo.guid()
  if type(start) ~= "table" or start.guid ~= guid then return end
  send("extMoney", { start = start.money, now = ns.LootInfo.money() })
end

local function onLogout()
  local start = doomsday().sessionMoney
  if type(start) == "table" and start.guid == ns.SelfInfo.guid() then start.at = GetServerTime() end
end

-- ===== Bosses and groups (Instance events) =====

-- After a boss kill: the current run as ActivityTracker keeps it (db.global.runs[guid]).
local function onBoss()
  local guid = ns.SelfInfo.guid()
  local run = guid and global().runs and global().runs[guid]
  if type(run) ~= "table" or run.kind ~= "party" or (run.bossCount or 0) < 1 then return end
  send("extBoss", { guid = guid, name = run.name, startedAt = run.startedAt, death = lastDeath(guid) })
end

local function onGroup()
  local friends = grouped()
  if next(friends) ~= nil then send("extGroup", { day = ns.DoomsdayTracker.today() }) end
end

-- ===== The minute clock =====

local function tick()
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  local t = date and date("*t")
  local hour = type(t) == "table" and t.hour or nil
  if hour ~= nil and hour ~= lastHour then
    lastHour = hour
    send("extClock", { hour = hour })
  end
  local session = ns.Play.last(own().feed, guid)
  if type(session) == "table" then
    send("extAlive", { now = GetServerTime(), from = session.from, death = lastDeath(guid) })
  end
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function ExtendedEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace the other trackers' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  -- ActivityTracker counts the boss in the same message: read the run a moment later.
  local bossLater = ns.Timer.debounce(0.5, onBoss)
  events:RegisterMessage(ns.GoalEvents.CHANGED, function(_, reason, a, b)
    if reason == "fish" then onFish() elseif reason == "trade" then onTrade(a, b) end
  end)
  events:RegisterMessage(ns.LootInfo.CHANGED, function(_, reason, text)
    if reason == "loot" then onLoot(text) elseif reason == "money" then onMoney() end
  end)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if BOSS_EVENTS[event] then bossLater() elseif event == "GROUP_ROSTER_UPDATE" then onGroup() end
  end)
  events:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason)
    if reason == "questTurnedIn" then onTurnIn() elseif reason == "logout" then onLogout() end
  end)
  sessionMoney()
  lastHour = nil
  tick()
  onGroup()
  if not ticking then ticking = ns.Timer.every(60, tick) end
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Extended = ExtendedEvents
return ExtendedEvents
