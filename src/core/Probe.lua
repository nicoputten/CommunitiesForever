-- Probe (CF-82): the hidden launch probe's results, pure. FriendProbe's automatic checks run inside the addon
-- (services/LaunchProbe.lua) and land here: compact results per client in CommunitiesForeverDB.global.probe, which
-- the uploader already sends to the site. Pure Lua, no WoW globals: times, builds and values come in as arguments.
local _, ns = ...

local Probe = {}

-- Until when the probe runs by itself: 2026-11-18 00:00 UTC, as FriendProbe (two weeks after launch).
Probe.STOP_AT = 1794960000
Probe.DETAIL_MAX = 120    -- characters of a result's detail and of a log line
Probe.LOG_LINES = 3       -- log lines kept per item
Probe.MAX_BYTES = 30 * 1024 -- the whole section, as the saved file writes it (estimated)
Probe.THROTTLE = 60       -- seconds between two looks at the same unit
Probe.SEEN_MAX = 200      -- players remembered for the Hunt before the list starts over

-- The checks the probe runs, in report order (FriendProbe's `auto` items without those that show something or
-- act: V47, V48, V50b, V51, V67, V68, V75, V118). CF-96: the checks the launch results (build 70790) answered are
-- gone (docs/API-FINDINGS.md "Forever launch probe"); results stored for them stay in the saved data, uploaded as they
-- are, and only leave the /cf fp report. CF-98: V60 and V60b (recipes, services/LaunchProbeRecipes.lua) added.
-- CF-101: V60c (a recipe's profession and details for CF-38) added; V70, V76 and V121 answered (export of
-- 2026-11-06 21:33) and gone. CF-105: V60 and V60c answered (export of 2026-11-07, builds 70790 and 70840) and gone;
-- V60b (a friend's link while they are offline) stays.
Probe.IDS = {
  "V82", "V35b", "V73", "Hunt", "V80", "V96", "V101", "V108", "V120", "V122", "V123",
  "V60b",
}

-- True while the probe should run: before STOP_AT and not stopped by hand.
function Probe.running(now, section)
  if type(now) ~= "number" or now >= Probe.STOP_AT then return false end
  return not (type(section) == "table" and section.stopped)
end

-- The client's name for the results: "forever" (WOW_PROJECT_ID 18), "retail" (1, a dry run) or "project <n>".
-- Results are kept per client: a Retail answer never stands for Forever.
function Probe.client(projectId)
  if projectId == 18 then return "forever" end
  if projectId == 1 then return "retail" end
  return "project " .. tostring(projectId)
end

-- Text cut to max characters (DETAIL_MAX by default); nil stays nil.
function Probe.clip(text, max)
  if text == nil then return nil end
  text = tostring(text)
  max = max or Probe.DETAIL_MAX
  if #text <= max then return text end
  return text:sub(1, max - 3) .. "..."
end

-- The probe section of a saved global table, created when missing (older data has none: rule 8).
function Probe.section(global)
  if type(global.probe) ~= "table" then global.probe = {} end
  if type(global.probe.results) ~= "table" then global.probe.results = {} end
  return global.probe
end

-- One client's results: { [id] = { status, detail, at, build, later, log } }.
function Probe.results(global, client)
  local results = Probe.section(global).results
  if type(results[client]) ~= "table" then results[client] = {} end
  return results[client]
end

-- True when the item passed (its check is answered and needs no more work).
function Probe.passed(results, id)
  local r = results[id]
  return type(r) == "table" and r.status == "pass"
end

--[[ Records a result: status "pass" | "fail" | "info", a short detail, the server time and the build. A pass stays
(once it worked, the question is answered): a later fail or info goes to `later`, the pass is kept. An info never
replaces a fail either. Returns true when the result changed. ]]
function Probe.record(results, id, status, detail, at, build)
  local r = results[id]
  detail = Probe.clip(detail)
  if type(r) == "table" and (r.status == "pass" or (r.status == "fail" and status == "info")) and status ~= "pass" then
    if r.later == detail then return false end
    r.later = detail
    return true
  end
  if type(r) ~= "table" then
    r = {}
    results[id] = r
  end
  if r.status == status and r.detail == detail then return false end
  r.status, r.detail, r.at, r.build, r.later = status, detail, at, build, nil
  return true
end

-- Adds a line to an item's log, keeping the last LOG_LINES. The item needs no result yet.
function Probe.note(results, id, line)
  local r = results[id]
  if type(r) ~= "table" then
    r = {}
    results[id] = r
  end
  if type(r.log) ~= "table" then r.log = {} end
  local log = r.log
  line = Probe.clip(line)
  if log[#log] == line then return end
  log[#log + 1] = line
  while #log > Probe.LOG_LINES do table.remove(log, 1) end
end

--[[ CF-101: the shape of a game message without anything private: every word that is not a word of one of the
formats (the game's own text) becomes "x", so a player's name ("Ann Example") reads "x x"; numbers and
punctuation stay. Colour codes are dropped and any other "|" becomes "!" (no escape codes in the log). nil when text
is not a string. ]]
function Probe.shape(text, formats)
  if type(text) ~= "string" then return nil end
  local known = {}
  for _, format in ipairs(type(formats) == "table" and formats or {}) do
    if type(format) == "string" then
      for word in format:gsub("%%%d?%$?[sd]", " "):gmatch("%a+") do known[word] = true end
    end
  end
  local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local shaped = plain:gsub("%a+", function(word) return known[word] and word or "x" end)
  return (shaped:gsub("|", "!"))
end

-- True when key was looked at less than `seconds` ago; otherwise remembers now and returns false.
function Probe.throttled(seen, key, now, seconds)
  local last = seen[key]
  if last and now - last < (seconds or Probe.THROTTLE) then return true end
  seen[key] = now
  return false
end

-- ===== The Hunt: a kill's victim, matched to an enemy player seen just before =====

--[[ Remembers an enemy player seen as target, mouseover or nameplate, under every name the game gave for them
(the name with and without realm, as the API returns them: names are never split, rule 4). fields = { race, class,
source }: readable strings or nil (secret or missing). ]]
function Probe.remember(seen, names, fields, now)
  if seen.count and seen.count >= Probe.SEEN_MAX then
    for k in pairs(seen) do seen[k] = nil end
  end
  local entry = { race = fields.race, class = fields.class, source = fields.source, at = now }
  for i = 1, table.maxn(names) do
    local name = names[i]
    if type(name) == "string" and name ~= "" then
      if not seen[name] then seen.count = (seen.count or 0) + 1 end
      seen[name] = entry
    end
  end
end

-- The Hunt's result for a kill whose honor message named `victim`: "pass" with race and class when the victim was
-- seen with both readable, "info" when named but not seen so, nil without a victim.
function Probe.hunt(seen, victim, now)
  if type(victim) ~= "string" or victim == "" then return nil end
  local entry = seen[victim]
  if type(entry) == "table" and type(entry.race) == "string" and type(entry.class) == "string" then
    return "pass", string.format("%s: %s %s via %s, %d s before the kill", victim, entry.race, entry.class,
      tostring(entry.source), math.floor((now or 0) - (entry.at or 0) + 0.5))
  end
  return "info", "victim " .. victim .. " named, but not seen with race and class before the kill"
end

-- CF-110: the Hunt's result for a kill counted by the lifetime counter, its victim picked from the enemy players at
-- the kill (core Pvp.pickVictims' entry, or nil): "pass" with race and class, "info" when the victim lacks one or
-- none fit.
function Probe.huntPick(pick)
  if type(pick) ~= "table" then
    return "info", "kill counted, no enemy player as target, mouseover or nameplate dead and seen alive just before"
  end
  if type(pick.race) == "string" and type(pick.class) == "string" then
    return "pass", string.format("%s: %s %s via %s at the kill", tostring(pick.name or "?"), pick.race, pick.class,
      tostring(pick.source))
  end
  return "info", "victim " .. tostring(pick.name or "?") .. " via " .. tostring(pick.source)
    .. " at the kill, without race and class"
end

-- ===== The size cap =====

-- Estimated size of a value as the saved file writes it (`["key"] = value,` per line, tab indented).
local function size(value, depth)
  local kind = type(value)
  if kind == "string" then return #value + 2 end
  if kind == "number" then return 12 end
  if kind == "boolean" then return 5 end
  if kind ~= "table" then return 3 end
  local total = 2 + depth
  for k, v in pairs(value) do
    total = total + depth + 1 + #tostring(k) + 7 + size(v, depth + 1)
  end
  return total
end

function Probe.size(section)
  return size(section, 1)
end

-- Every item of every client in the section, in a fixed order: { client, id, result }.
local function items(section)
  local list = {}
  for client, results in pairs(type(section.results) == "table" and section.results or {}) do
    if type(results) == "table" then
      for id, r in pairs(results) do
        if type(r) == "table" then list[#list + 1] = { client = client, id = id, r = r } end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.client ~= b.client then return tostring(a.client) < tostring(b.client) end
    return tostring(a.id) < tostring(b.id)
  end)
  return list
end

--[[ Keeps the section under maxBytes (MAX_BYTES by default): drops log lines first, the oldest of the item with the
most lines at a time, then the `later` details, then shortens details to 40 characters. Results themselves stay.
Returns the estimated size after. ]]
function Probe.trim(section, maxBytes)
  maxBytes = maxBytes or Probe.MAX_BYTES
  local current = Probe.size(section)
  if current <= maxBytes then return current end
  local list = items(section)
  while current > maxBytes do
    local most
    for _, item in ipairs(list) do
      local log = item.r.log
      if type(log) == "table" and #log > 0 and (not most or #log > #most.r.log) then most = item end
    end
    if not most then break end
    table.remove(most.r.log, 1)
    if #most.r.log == 0 then most.r.log = nil end
    current = Probe.size(section)
  end
  for _, item in ipairs(list) do
    if current <= maxBytes then break end
    if item.r.later then
      item.r.later = nil
      current = Probe.size(section)
    end
  end
  for _, item in ipairs(list) do
    if current <= maxBytes then break end
    if type(item.r.detail) == "string" and #item.r.detail > 40 then
      item.r.detail = Probe.clip(item.r.detail, 40)
      current = Probe.size(section)
    end
  end
  return current
end

-- ===== /cf fp =====

-- Counts of the probe's checks by status ("open": no result yet).
function Probe.summary(results)
  local counts = { pass = 0, fail = 0, info = 0, open = 0 }
  for _, id in ipairs(Probe.IDS) do
    local r = results[id]
    local status = type(r) == "table" and r.status
    if counts[status] then counts[status] = counts[status] + 1 else counts.open = counts.open + 1 end
  end
  return counts
end

-- The summary as one line.
function Probe.summaryLine(results, client, running)
  local c = Probe.summary(results)
  return string.format("Probe (%s): %d pass, %d fail, %d info, %d open; %s.", client, c.pass, c.fail, c.info, c.open,
    running and "running until 18 November" or "stopped")
end

--[[ The copyable report: the summary line, then one line per check (id, status, detail, later, time, build) and its
log lines. formatTime(at) turns a server time into text (the PC's clock). ]]
function Probe.report(results, client, running, formatTime)
  local lines = { Probe.summaryLine(results, client, running) }
  for _, id in ipairs(Probe.IDS) do
    local r = results[id]
    if type(r) == "table" and r.status then
      local line = string.format("%s %s: %s", id, r.status, tostring(r.detail))
      if r.later then line = line .. " (later: " .. tostring(r.later) .. ")" end
      line = line .. string.format(" [%s, build %s]", r.at and formatTime and formatTime(r.at) or "?",
        tostring(r.build))
      lines[#lines + 1] = line
    else
      lines[#lines + 1] = id .. " open"
    end
    for _, l in ipairs(type(r) == "table" and type(r.log) == "table" and r.log or {}) do
      lines[#lines + 1] = "  " .. tostring(l)
    end
  end
  local errors = results.error
  for _, l in ipairs(type(errors) == "table" and type(errors.log) == "table" and errors.log or {}) do
    lines[#lines + 1] = "error: " .. tostring(l)
  end
  return lines
end

ns.Probe = Probe
return Probe
