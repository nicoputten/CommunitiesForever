-- FeedTracker: records what the own characters do into db.global.self.feed (CF-22 activity feed).
-- SelfTracker reports the events; the feed travels with the own record (see Merge.outgoingRecord).
local _, ns = ...

local FeedTracker = {}

-- Internal message, sent when the own feed changed (the window refreshes).
FeedTracker.CHANGED = "CF_FEED_CHANGED"

-- A feed change bumps the own version at most this often, so questing does not sync every turn-in.
FeedTracker.BUMP_DEBOUNCE = 60

local addonRef, bumpDebounced
-- Own version when the last unsynced feed change was made; nil when nothing waits.
local pendingVersion

local function own() return addonRef.db.global.self end

local function bump()
  own().version = ns.Merge.nextVersion(own().version, GetServerTime())
  addonRef:SendMessage(ns.SelfTracker.UPDATED)
end

-- The debounced bump is skipped when the version moved on meanwhile (a snapshot change): that record
-- already carries the feed.
local function bumpPending()
  if pendingVersion ~= nil and own().version == pendingVersion then bump() end
  pendingVersion = nil
end

-- Today's realm day number.
function FeedTracker.today()
  return ns.Feed.dayNumber(ns.SelfInfo.today())
end

function FeedTracker.start(addon)
  addonRef = addon
  bumpDebounced = ns.Timer.debounce(FeedTracker.BUMP_DEBOUNCE, bumpPending)
  if own().feed then ns.Feed.trim(own().feed, FeedTracker.today()) end
end

-- Adds events (see Feed.changes, or { kind = "quest", zone }) of an own character { guid, name, classFile }.
-- bumped: the caller already bumped the own version after these events (no extra sync needed).
-- day: realm day number the events belong to (CF-23: a run counts on the day it started); default today.
function FeedTracker.record(char, events, bumped, day)
  if not addonRef or not char or not char.guid or #events == 0 then return end
  local feed = own().feed or {}
  own().feed = feed
  local today, now = FeedTracker.today(), GetServerTime()
  for _, event in ipairs(events) do
    ns.Feed.add(feed, day or today, char, event, now)
  end
  ns.Feed.trim(feed, today)
  if ns.DoomsdayTracker then ns.DoomsdayTracker.observeFeed(char, events) end -- CF-56: goal facts
  addonRef:SendMessage(FeedTracker.CHANGED)
  if bumped then return end
  pendingVersion = own().version
  bumpDebounced()
end

-- Something the own record carries changed without a feed event (CF-52: PvP counters): bumps the version
-- through the same debounce as feed changes.
function FeedTracker.changedLater()
  if not addonRef then return end
  pendingVersion = own().version
  bumpDebounced()
end

ns.FeedTracker = FeedTracker
return FeedTracker
