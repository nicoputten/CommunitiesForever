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

-- The checks the probe runs, in report order (FriendProbe's `auto` items without those that show something or
-- act: V47, V48, V50b, V51, V67, V68, V75, V118). CF-96: the checks the launch results (build 70790) answered are
-- gone (docs/API-FINDINGS.md "Forever launch probe"); results stored for them stay in the saved data, uploaded as they
-- are, and only leave the /cf fp report. CF-98: V60 and V60b (recipes, services/LaunchProbeRecipes.lua) added.
-- CF-101: V60c (a recipe's profession and details for CF-38) added; V70, V76 and V121 answered (export of
-- 2026-11-06 21:33) and gone. CF-105: V60 and V60c answered (export of 2026-11-07, builds 70790 and 70840) and gone;
-- V60b (a friend's link while they are offline) stays. CF-109: V114 answered and gone. CF-113: V120 answered (export
-- of 2026-11-09) and gone; V101 checks only buying (posting answered). CF-116: V73 (the honor message has no
-- victim) and V80 (the duel lines, answered on Retail) are gone; V142 (races beyond Vanilla's eight, the Skyborne)
-- added. CF-120 (export of 2026-11-12): V101, V108 and V142 answered, V60b (a known fail) and V96 closed, all gone;
-- V74 (a skull's UnitLevel) added back, as no probe ever looked for it; V123 looks at every zone change; V85 (the
-- items you put in a trade, which w.craftTrade reads) added, as no export ever reported it. CF-120 (Nico): a check
-- that never answered is not dropped but tried another way: V8, V79, V96, V99, V100, V106, V118, V119
-- (services/LaunchProbeWorld.lua). CF-122: V146 (the Hunt alerts' nameplate crosshair, the target frame's portrait)
-- added; HuntPrey reports it (LaunchProbe.report).
Probe.IDS = {
  "V82", "V35b", "V74", "Hunt", "V85", "V122", "V123",
  "V8", "V79", "V96", "V99", "V100", "V106", "V118", "V119", "V146",
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

-- True when key was looked at less than `seconds` ago; otherwise remembers now and returns false.
function Probe.throttled(seen, key, now, seconds)
  local last = seen[key]
  if last and now - last < (seconds or Probe.THROTTLE) then return true end
  seen[key] = now
  return false
end

-- ===== The Hunt: the victim picked at a kill =====

-- CF-110: the Hunt's result for a kill counted by the lifetime counter, its victim picked from the enemy players
-- around the kill (core Pvp.resolveVictims' first entry, or nil): "pass" with race and class, "info" when the victim
-- lacks one or none fit. CF-117: it says which path found the victim (HUNT_PATHS: dead at once, dead after the
-- delay; CF-120: the low health path is gone, V143) and how many candidates there were; never the victim's name.
Probe.HUNT_PATHS = { dead = "dead at once", later = "dead after the delay" }

function Probe.huntPick(pick, candidates)
  local seen = type(candidates) == "number" and (", " .. candidates .. " candidate" .. (candidates == 1 and "" or "s"))
    or ""
  if type(pick) ~= "table" then
    return "info", "kill counted, no victim: no enemy player as target, mouseover or nameplate dead"
      .. seen
  end
  local path = Probe.HUNT_PATHS[pick.path]
  local how = "via " .. tostring(pick.source) .. (path and (", " .. path) or "")
  if type(pick.race) == "string" and type(pick.class) == "string" then
    return "pass", string.format("%s %s %s%s", pick.race, pick.class, how, seen)
  end
  return "info", string.format("victim %s, without race and class%s", how, seen)
end

-- ===== V74: an enemy player shown with a skull (CF-120) =====
-- The game shows a skull for an enemy player 10 or more levels above you (SKULL_GAP). No probe looked for it before
-- CF-120 (FriendProbe only logged it), so the exports never answered it.

Probe.SKULL_GAP = 10

--[[ V74's result for one enemy player looked at: status, detail, or nil for an ordinary level. level: UnitLevel of
the enemy (nil when missing or secret, secret: true then); own: your UnitLevel; source: "target", "mouseover",
"nameplate". "pass" for -1 (the skull), and for a readable level SKULL_GAP or more above yours (a skull that reads as
its level); "info" for a secret level. ]]
function Probe.skull(level, own, secret, source)
  local via = " via " .. tostring(source)
  if secret then return "info", "enemy player's UnitLevel secret" .. via end
  if level == -1 then return "pass", "skull: UnitLevel -1" .. via end
  if type(level) == "number" and type(own) == "number" and own > 0 and level >= own + Probe.SKULL_GAP then
    return "pass", string.format("%d+ levels above: UnitLevel %d at own %d (not -1)%s", Probe.SKULL_GAP, level, own,
      via)
  end
  return nil
end

-- ===== V123: the zone's PvP type (CF-120) =====
-- Up to CF-120 the probe read the type once per new type in a session, only on ZONE_CHANGED_NEW_AREA and at login,
-- so only "friendly" and "sanctuary" ever showed. It now reads at every zone change and again ZONE_RECHECK seconds
-- later, and keeps a count of the zones seen per type.

Probe.ZONE_RECHECK = 2 -- seconds after a zone change the type is read again (it may lag behind the event)

--[[ Adds a zone's type to the session's counts in place: counts = { [type] = { [zone] = true } } (type "none" for
no type). Returns true when this zone is new for its type. ]]
function Probe.zoneSeen(counts, zone, pvpType)
  local kind = type(pvpType) == "string" and pvpType ~= "" and pvpType or "none"
  zone = type(zone) == "string" and zone ~= "" and zone or "?"
  counts[kind] = counts[kind] or {}
  if counts[kind][zone] then return false end
  counts[kind][zone] = true
  return true
end

--[[ V123's result from the counts: status, detail. "pass" once a type other than "friendly", "sanctuary" or none was
read (the question: "hostile", "contested"); else "info". The detail lists the types with how many zones gave each,
sorted by type. ]]
function Probe.zoneResult(counts)
  local kinds, other = {}, false
  for kind, zones in pairs(counts) do
    local n = 0
    for _ in pairs(zones) do n = n + 1 end
    kinds[#kinds + 1] = kind .. " " .. n
    if kind ~= "friendly" and kind ~= "sanctuary" and kind ~= "none" then other = true end
  end
  table.sort(kinds)
  return other and "pass" or "info", "zones per type: " .. table.concat(kinds, ", ")
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
