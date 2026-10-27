-- RunsFile: the planned runs file Data\Runs.lua (CF-45). Thin wrapper around the CF_RUNS global it sets;
-- the checks are in core/PlannedRuns.lua. The game runs the file only at login or /reload, so it is read
-- once per load: the global is cleared and the checked copy kept here.
local _, ns = ...

local RunsFile = {}

local read, runs, reason = false, nil, nil

-- The checked runs, or nil and the reason (see PlannedRuns.validate; "unreadable" when checking failed).
function RunsFile.read()
  if not read then
    read = true
    local raw = CF_RUNS
    CF_RUNS = nil
    local ok, result, why = pcall(ns.PlannedRuns.validate, raw)
    if ok then
      runs, reason = result, why
    else
      runs, reason = nil, "unreadable"
    end
  end
  return runs, reason
end

ns.RunsFile = RunsFile
return RunsFile
