-- PlayTracker: loot, notable items, gold, play sessions and groups with community characters of the own
-- characters, into the activity feed (CF-53). Loot and gold changes bump the version through the feed's
-- debounce; a session's end moves without a bump (the next one carries it).
local _, ns = ...

local PlayTracker = {}

local addonRef, events
-- Money at the last read (copper; nil until read), the current session and its feed entry.
local lastMoney, session, sessionEntry

local function own() return addonRef.db.global.self end

local function currentChar()
  local guid = ns.SelfInfo.guid()
  return guid and own().chars[guid]
end

local function loot(text)
  local item = ns.Loot.parse(text, ns.LootInfo.formats())
  local char = item and currentChar()
  if not char then return end
  local quality, slot = ns.LootInfo.item(item.id)
  local list = ns.Loot.events(item, quality, slot, char.level)
  if #list > 0 then ns.FeedTracker.record(char, list) end
end

local function money()
  local now = ns.LootInfo.money()
  local event = ns.Loot.gold(lastMoney, now)
  lastMoney = now or lastMoney
  local char = event and currentChar()
  if char then ns.FeedTracker.record(char, { event }) end
end

-- Community characters in the group that are not yet in today's entry.
local function groups()
  local char = currentChar()
  if not char then return end
  local ok, members = pcall(ns.MemberTracker.members)
  if not ok or not members then return end
  local feed = own().feed or {}
  local today = feed[ns.FeedTracker.today()]
  local known = today and today[char.guid] and today[char.guid].groups or {}
  local list = {}
  for _, guid in ipairs(ns.Instance.groupGuids()) do
    if members[guid] and guid ~= char.guid and not known[guid] then
      list[#list + 1] = { kind = "group", guid = guid }
    end
  end
  if #list > 0 then ns.FeedTracker.record(char, list) end
end

-- Login: continue the last session of this character when it ended moments ago, else start one.
local function startSession()
  local char = currentChar()
  if not char then return end
  local now = GetServerTime()
  session, sessionEntry = ns.Play.resume(own().feed, char.guid, now)
  if session then return end
  ns.FeedTracker.record(char, { { kind = "session", from = now } }, true) -- no sync of its own
  session, sessionEntry = ns.Play.last(own().feed, char.guid)
end

local function touch()
  ns.Play.touch(session, sessionEntry, GetServerTime())
end

function PlayTracker.start(addon)
  addonRef = addon
  lastMoney, session, sessionEntry = ns.LootInfo.money(), nil, nil
  events = events or LibStub("AceEvent-3.0"):Embed({})
  ns.LootInfo.watch(addon)
  events:RegisterMessage(ns.LootInfo.CHANGED, function(_, reason, text)
    if reason == "loot" then loot(text) elseif reason == "money" then money() end
  end)
  events:RegisterMessage(ns.Instance.EVENT, function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then groups() elseif event == "PLAYER_LOGOUT" then touch() end
  end)
  startSession()
  ns.Timer.every(ns.Play.HEARTBEAT, touch)
end

ns.PlayTracker = PlayTracker
return PlayTracker
