-- SelfTracker: keeps the current character's snapshot in db.global.self.
local _, ns = ...

local SelfTracker = {}

-- Internal message, sent when the own record changed (version bumped).
SelfTracker.UPDATED = "CF_SELF_UPDATED"

local EQUIPMENT_DEBOUNCE = 2

function SelfTracker.start(addon)
  -- CF-19: an empty quest log is stored only after a turn-in or abandon (it may not be loaded yet otherwise).
  local questRemoved = false

  -- PLAYER_LEVEL_UP passes the new level; UnitLevel can still return the old one then.
  local function refresh(levelOverride)
    local info = ns.SelfInfo.read()
    if levelOverride then
      info.level = levelOverride
    end
    -- CF-18: points per Vanilla tree and the role guessed from the main tree.
    info.talents, info.mainTree = ns.Talents.summarize(info.talentNodes, info.classFile)
    info.autoRole = ns.Talents.autoRole(info.classFile, info.mainTree)
    -- CF-19: quest log per character (nil when not readable: the snapshot keeps the old one).
    info.quests = ns.Quests.fromLog(info.questLog, questRemoved)
    questRemoved = false
    -- CF-22: level-ups and new profession ranks for the activity feed, from the snapshot difference.
    local stored = info.guid and addon.db.global.self.chars[info.guid]
    local before = stored and { level = stored.level, professions = stored.professions }
    local changed = ns.Snapshot.apply(addon.db.global.self, info, GetServerTime())
    local after = info.guid and addon.db.global.self.chars[info.guid]
    ns.FeedTracker.record(after, ns.Feed.changes(before, after), changed)
    if changed then
      addon:SendMessage(SelfTracker.UPDATED)
    end
  end

  -- CF-22: a turned-in quest counts for the feed under its area (log header), read before the log
  -- refresh removes it. A quest the stored log does not know (accepted and turned in between two log
  -- reads, common in dungeons) counts under the zone you are in.
  local function questTurnedIn(questID)
    local guid = ns.SelfInfo.read().guid
    local char = guid and addon.db.global.self.chars[guid]
    if not char then return end
    local quest = type(questID) == "number" and char.quests and char.quests[questID]
    local zone = quest and quest.area or ns.SelfInfo.zone()
    ns.FeedTracker.record(char, { { kind = "quest", zone = zone } })
  end

  local refreshDebounced = ns.Timer.debounce(EQUIPMENT_DEBOUNCE, function() refresh() end)

  local function markPlayed()
    ns.Snapshot.markPlayed(addon.db.global.self, ns.SelfInfo.read().guid, GetServerTime())
  end

  addon:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason, arg)
    if reason == "equipment" or reason == "talents" or reason == "quests" then
      refreshDebounced()
    elseif reason == "questRemoved" or reason == "questTurnedIn" then
      if reason == "questTurnedIn" then questTurnedIn(arg) end
      questRemoved = true
      refreshDebounced()
    elseif reason == "level" then
      refresh(arg)
    elseif reason == "logout" then
      markPlayed()
    else
      refresh()
    end
  end)

  refresh()
  markPlayed()
end

-- Sets the own display name (CF-04): cleaned plain text, empty clears it. A synced change: bumps the
-- version, and SelfTracker.UPDATED makes Sync send a HELLO after the debounce.
function SelfTracker.setDisplayName(addon, text)
  local own = addon.db.global.self
  local name = ns.Merge.cleanName(text)
  if own.displayName == name then return end
  own.displayName = name
  own.version = ns.Merge.nextVersion(own.version, GetServerTime())
  addon:SendMessage(SelfTracker.UPDATED)
end

-- Sets the role of an own character (CF-18): "tank", "heal", "dps", or nil for the auto role.
function SelfTracker.setRoleOverride(addon, guid, role)
  if ns.Snapshot.setRoleOverride(addon.db.global.self, guid, role, GetServerTime()) then
    addon:SendMessage(SelfTracker.UPDATED)
  end
end

ns.SelfTracker = SelfTracker
return SelfTracker
