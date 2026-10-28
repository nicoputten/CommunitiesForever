-- Describe: stable, human-readable text for records (used by /cf self for testing).
-- Pure Lua, no WoW globals. Requires ns.Pvp (CF-52) for the PvP line, ns.Doomsday (CF-56) for /cf doomsday.
local _, ns = ...

local Describe = {}

local function sortedKeys(t, less)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, less)
  return keys
end

local function age(updatedAt, now)
  if not updatedAt then return "never" end
  return string.format("%ds ago", math.max(0, now - updatedAt))
end

-- Lines describing the own record: header, then per character (sorted by name)
-- a summary line and a professions line (sorted by skillLine).
function Describe.selfRecord(record, now)
  local chars = record.chars or {}
  local guids = sortedKeys(chars, function(a, b)
    return (chars[a].name or a) < (chars[b].name or b)
  end)

  local lines = {
    string.format("BattleTag %s, version %s, %d character(s)",
      tostring(record.battleTag), tostring(record.version), #guids),
  }

  for _, guid in ipairs(guids) do
    local c = chars[guid]
    lines[#lines + 1] = string.format("%s: %s level %s, ilvl %s, race %s, %s, %s, updated %s (%s)",
      tostring(c.name), tostring(c.classFile), tostring(c.level), tostring(c.ilvl), tostring(c.raceID),
      tostring(c.faction), tostring(c.realm), age(c.updatedAt, now), tostring(c.updatedAt))

    local profs = {}
    local professions = c.professions or {}
    for _, skillLine in ipairs(sortedKeys(professions)) do
      local p = professions[skillLine]
      profs[#profs + 1] = string.format("%s %s/%s [%d]", tostring(p.name), tostring(p.rank), tostring(p.max), skillLine)
    end
    lines[#lines + 1] = "  " .. (#profs > 0 and table.concat(profs, ", ") or "no professions")
    local pvp = c.pvp
    if pvp then -- CF-52
      local rank = ns.Pvp.rankText(pvp, c.faction)
      lines[#lines + 1] = string.format("  PvP: %s honorable kills, %s, this week %s kills and %s honor; "
        .. "%s deaths, duels %s won %s lost", tostring(pvp.hk or "?"), rank or "rank unknown",
        tostring(pvp.weekKills or "?"), tostring(pvp.weekHonor or "?"), tostring(pvp.deaths or 0),
        tostring(pvp.duelsWon or 0), tostring(pvp.duelsLost or 0))
    end
    if c.talents then
      local split = {}
      for _, t in ipairs(c.talents) do split[#split + 1] = string.format("%s %d", tostring(t.name), t.points or 0) end
      lines[#lines + 1] = string.format("  talents: %s, role %s%s", table.concat(split, " / "), tostring(c.role),
        c.roleOverride and " (set by player)" or "")
    end
  end
  return lines
end

-- Lines describing community members, sorted by name (then GUID).
-- The header says when the member data last changed, so event-driven updates can be checked.
function Describe.members(members, communityName, changedAt, now)
  local guids = sortedKeys(members, function(a, b)
    local na, nb = members[a].name or a, members[b].name or b
    if na ~= nb then return na < nb end
    return a < b
  end)

  local lines = { string.format("%s: %d member(s), last change %s", tostring(communityName), #guids,
    age(changedAt, now)) }
  for _, guid in ipairs(guids) do
    local m = members[guid]
    lines[#lines + 1] = string.format("%s: level %s, class %s, race %s, faction %s, presence %s, zone %s, %s",
      tostring(m.name), tostring(m.level), tostring(m.classID), tostring(m.raceID), tostring(m.faction),
      tostring(m.presence), tostring(m.zone), guid)
  end
  return lines
end

-- Lines describing Battle.net friends in Forever and stored presence links, sorted by BattleTag.
function Describe.friends(friends, online, presence, now)
  local friendCount = 0
  for _ in pairs(friends) do friendCount = friendCount + 1 end
  local tags = sortedKeys(online)

  local lines = { string.format("%d Battle.net friend(s), %d online in Forever", friendCount, #tags) }
  for _, bt in ipairs(tags) do
    local c = online[bt]
    lines[#lines + 1] = string.format("%s: %s (%s %s), game account %s, %s",
      bt, tostring(c.name), tostring(c.className), tostring(c.level), tostring(c.gameAccountID), c.guid)
  end

  local guids = sortedKeys(presence, function(a, b)
    if presence[a].battleTag ~= presence[b].battleTag then return presence[a].battleTag < presence[b].battleTag end
    return a < b
  end)
  lines[#lines + 1] = string.format("Presence links: %d", #guids)
  for _, guid in ipairs(guids) do
    local p = presence[guid]
    lines[#lines + 1] = string.format("  %s -> %s, seen %s", guid, p.battleTag, age(p.lastSeen, now))
  end
  return lines
end

local function describeRow(row, now)
  local where = row.online and ("online, " .. tostring(row.zone)) or "offline"
  local seen = row.lastSeen and (", seen " .. age(row.lastSeen, now)) or ""
  local source = row.linkSource and (", via " .. row.linkSource) or ""
  return string.format("%s: level %s, ilvl %s, %s%s%s",
    tostring(row.name), tostring(row.level), tostring(row.ilvl), where, seen, source)
end

-- Lines describing the Linker view model: people with their characters, then Unlinked.
function Describe.view(view, now)
  local lines = { string.format("%d people, %d unlinked", #view.people, #view.unlinked) }
  for _, p in ipairs(view.people) do
    local status = "offline"
    if p.online then
      local current = p.currentChar
      status = current and ("online on " .. tostring(current.name) ..
        (current.visible == false and " (not in community)" or "")) or "online"
    end
    lines[#lines + 1] = string.format("%s (%s)%s, %s",
      p.displayName, tostring(p.battleTag), p.isSelf and " [you]" or "", status)
    for _, row in ipairs(p.chars) do
      lines[#lines + 1] = "  " .. describeRow(row, now)
    end
  end
  if #view.unlinked > 0 then
    lines[#lines + 1] = "Unlinked:"
    for _, row in ipairs(view.unlinked) do
      lines[#lines + 1] = "  " .. describeRow(row, now)
    end
  end
  return lines
end

local SOURCES = { game = "realm clock", site = "the site's time zone", cet = "CET/CEST, no realm clock" }

local function goalLines(lines, title, entry, progress, clock)
  lines[#lines + 1] = title
  for _, id in ipairs(entry.set or {}) do
    local goal = ns.Doomsday.goal(id)
    local text = id == "hunt" and "The Hunt" or (goal and goal.text) or ("a goal from a newer version (" .. id .. ")")
    local p = progress[id] or {}
    local state
    if entry.done and entry.done[id] then
      state = "done " .. clock(entry.done[id])
    else
      state = string.format("%s/%s", tostring(p.value or 0), tostring(p.target or "?"))
    end
    local original = entry.swapped and entry.swapped[id]
    local instead = original and ns.Doomsday.goal(original)
    lines[#lines + 1] = string.format("  %s: %s%s", text, state,
      original and (" (instead of: " .. (instead and instead.text or original) .. ")") or "")
  end
end

--[[ CF-56: /cf doomsday. state: DoomsdayTracker.state(); clock(t): a server time as the player's clock ("20:14"). ]]
function Describe.doomsday(state, clock)
  if not state then return { "Doomsday is not ready yet." } end
  local lines = { string.format("Doomsday %s, resets in %s (day %d, week %d, %s)", state.label,
    ns.Doomsday.duration(state.resetsIn), state.day, state.week, SOURCES[state.source] or tostring(state.source)) }
  goalLines(lines, "Today:", state.today, state.progress, clock)
  goalLines(lines, "This week:", state.thisWeek, state.weekProgress, clock)
  lines[#lines + 1] = string.format("Streak %d (best %d). This week: PvE %d, PvP %d (kills and goals; duels on "
    .. "the site).", state.streak, state.best, state.points.pve, state.points.pvp)
  return lines
end

ns.Describe = Describe
return Describe
