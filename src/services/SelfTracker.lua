-- SelfTracker: keeps the current character's snapshot in db.global.self.
local _, ns = ...

local SelfTracker = {}

-- Internal message, sent when the own record changed (version bumped).
SelfTracker.UPDATED = "CF_SELF_UPDATED"

local EQUIPMENT_DEBOUNCE = 2

function SelfTracker.start(addon)
  local equipmentTimer

  -- PLAYER_LEVEL_UP passes the new level; UnitLevel can still return the old one then.
  local function refresh(levelOverride)
    local info = ns.SelfInfo.read()
    if levelOverride then
      info.level = levelOverride
    end
    if ns.Snapshot.apply(addon.db.global.self, info, GetServerTime()) then
      addon:SendMessage(SelfTracker.UPDATED)
    end
  end

  -- C_Timer.NewTimer is unverified on Forever (VERIFY.md V14); without it, refresh at once.
  local function refreshDebounced()
    if not (C_Timer and C_Timer.NewTimer) then
      refresh()
      return
    end
    if equipmentTimer then
      equipmentTimer:Cancel()
    end
    equipmentTimer = C_Timer.NewTimer(EQUIPMENT_DEBOUNCE, function()
      equipmentTimer = nil
      refresh()
    end)
  end

  addon:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason, arg)
    if reason == "equipment" then
      refreshDebounced()
    elseif reason == "level" then
      refresh(arg)
    else
      refresh()
    end
  end)

  refresh()
end

ns.SelfTracker = SelfTracker
return SelfTracker
