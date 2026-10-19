-- GroupFinder: the dungeons the game's Group Finder offers, with its level ranges (CF-24, V46 verified).
-- Thin, guarded wrapper around C_LFGList; Forever's new dungeons come from here.
local _, ns = ...

local GroupFinder = {}

-- Dungeon activities: { { activityID, name, shortName, min, max } }, or {} when the API is missing.
-- Dungeons are the activities with a difficulty and a group size (zones have difficultyID 0 and
-- maxNumPlayers 0, V46); battlegrounds and raids-only flags are left out.
function GroupFinder.dungeons()
  local lfg = C_LFGList
  if not (lfg and lfg.GetAvailableCategories and lfg.GetAvailableActivities and lfg.GetActivityInfoTable) then
    return {}
  end
  local result, seen = {}, {}
  local ok = pcall(function()
    for _, categoryID in ipairs(lfg.GetAvailableCategories() or {}) do
      for _, activityID in ipairs(lfg.GetAvailableActivities(categoryID) or {}) do
        local info = lfg.GetActivityInfoTable(activityID)
        if type(info) == "table" and not seen[activityID] and (info.difficultyID or 0) > 0
           and (info.maxNumPlayers or 0) > 0 and (info.maxNumPlayers or 0) <= 10 and not info.isPvpActivity then
          seen[activityID] = true
          result[#result + 1] = { activityID = activityID, name = info.fullName, shortName = info.shortName,
                                  min = info.minLevelSuggestion, max = info.maxLevelSuggestion }
        end
      end
    end
  end)
  return ok and result or {}
end

ns.GroupFinder = GroupFinder
return GroupFinder
