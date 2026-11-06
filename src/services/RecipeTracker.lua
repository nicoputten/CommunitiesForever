-- RecipeTracker (CF-38): scans the own profession window into the current character (core/Recipes.lua) on
-- TRADE_SKILL_SHOW, list updates, NEW_RECIPE_LEARNED and SKILL_LINES_CHANGED, at most once per second. A changed
-- link or specialisation is a synced change (version bump, HELLO through SelfTracker.UPDATED).
local _, ns = ...

local RecipeTracker = {}

function RecipeTracker.start(addon)
  -- open: the own window is open; ownView: the last window opened was the own one (false after a friend's linked
  -- view, whose list may still be what GetAllRecipeIDs gives once it closed).
  local state, open, ownView = {}, false, nil

  local function scan()
    local own = addon.db.global.self
    local guid = ns.SelfInfo.guid()
    local char = guid and own.chars and own.chars[guid]
    if not char or (not open and ownView == false) then return end
    local read = ns.TradeSkill.read(open)
    if open then ownView = read ~= nil end
    if not read then return end -- someone else's recipes (a clicked link)
    local now = GetServerTime()
    local synced = ns.Recipes.apply(char, read, now)
    if synced then
      char.updatedAt = now
      own.version = ns.Merge.nextVersion(own.version, now)
      addon:SendMessage(ns.SelfTracker.UPDATED)
    end
  end

  local function request()
    local wait = ns.Recipes.throttle(state, GetTime(), ns.Recipes.THROTTLE)
    if wait == 0 then
      scan()
    elseif wait then
      ns.Timer.after(wait, function()
        ns.Recipes.ran(state, GetTime())
        scan()
      end)
    end
  end

  ns.TradeSkill.watch(function(event)
    if event == "TRADE_SKILL_CLOSE" then
      open = false
      return
    end
    if event == "TRADE_SKILL_SHOW" then open = true end
    request()
  end)
  RecipeTracker.scanNow = scan -- specs
end

ns.RecipeTracker = RecipeTracker
return RecipeTracker
