-- RunsFile: the planned runs file Data\Runs.lua (CF-45). Thin wrapper around the CF_RUNS global it sets;
-- the checks are in core/PlannedRuns.lua. The game runs the file only at login or /reload, so it is read
-- once per load: the global is cleared and the checked copy kept here.
local _, ns = ...

local RunsFile = {}

local read, runs, reason, doomsday = false, nil, nil, nil

-- The checked runs, or nil and the reason (see PlannedRuns.validate; "unreadable" when checking failed).
function RunsFile.read()
  if not read then
    read = true
    local raw = CF_RUNS
    CF_RUNS = nil
    -- CF-56: the reset setting (checked by Goals); a table that errors when read gives none.
    local okDoomsday, value = pcall(function() return type(raw) == "table" and raw.doomsday or nil end)
    doomsday = okDoomsday and value or nil
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

ns.RunsFile = RunsFile
return RunsFile
