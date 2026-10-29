-- RunsFile: the planned runs file Data\Runs.lua (CF-45). Thin wrapper around the CF_RUNS global it sets;
-- the checks are in core/PlannedRuns.lua. The game runs the file only at login or /reload, so it is read
-- once per load: the global is cleared and the checked copy kept here.
local _, ns = ...

local RunsFile = {}

local read, runs, reason, doomsday = false, nil, nil, nil
local site, friends -- CF-62

-- The checked runs, or nil and the reason (see PlannedRuns.validate; "unreadable" when checking failed).
function RunsFile.read()
  if not read then
    read = true
    local raw = CF_RUNS
    CF_RUNS = nil
    -- CF-56: the reset setting (checked by Goals); a table that errors when read gives none.
    local okDoomsday, value = pcall(function() return type(raw) == "table" and raw.doomsday or nil end)
    doomsday = okDoomsday and value or nil
    -- CF-62: the site's address and the friends it knows (both optional; a broken table gives none).
    local okSite, url = pcall(ns.PlannedRuns.site, raw)
    site = okSite and url or nil
    local okFriends, list = pcall(ns.PlannedRuns.friends, raw)
    friends = okFriends and list or {}
    local ok, result, why = pcall(ns.PlannedRuns.validate, raw)
    if ok then
      runs, reason = result, why
    else
      runs, reason = nil, "unreadable"
    end
  end
  return runs, reason
end

-- CF-56: the file's raw `doomsday` table ({ reset, changedAt, offset, offsetUntil, offsetAfter }), or nil.
function RunsFile.doomsday()
  RunsFile.read()
  return doomsday
end

-- CF-62: the site's base URL, or nil.
function RunsFile.site()
  RunsFile.read()
  return site
end

-- CF-62: the friends the site knows (PlannedRuns.friends), {} without.
function RunsFile.friends()
  RunsFile.read()
  return friends or {}
end

ns.RunsFile = RunsFile
return RunsFile
