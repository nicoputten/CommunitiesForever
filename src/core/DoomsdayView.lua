-- DoomsdayView: what the Doomsday tab, its chat lines and the character card show (CF-57). Pure Lua, no WoW
-- globals: models built from DoomsdayTracker.state and the synced data; the UI only draws them.
-- Requires ns.Doomsday and ns.Pvp. Texts follow the boards (docs/design/doomsday-2026-10/DD07AddonToday).
local _, ns = ...

local DoomsdayView = {}

-- Race tokens (UnitRace) and class tokens as the texts name them, singular and plural.
local RACES = { Human = "Human", Dwarf = "Dwarf", NightElf = "Night Elf", Gnome = "Gnome", Orc = "Orc",
                Scourge = "Undead", Tauren = "Tauren", Troll = "Troll" }
local CLASSES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
                  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }

function DoomsdayView.className(token) return CLASSES[token] or tostring(token) end
function DoomsdayView.raceName(token) return RACES[token] or tostring(token) end

-- "Night Elf Druids" (plural) or "a Night Elf Druid".
function DoomsdayView.huntText(hunt, single)
  if not hunt then return nil end
  local text = DoomsdayView.raceName(hunt.race) .. " " .. DoomsdayView.className(hunt.class)
  if single then return "a " .. text end
  return text .. "s"
end

-- "3 d 4 h", "11 h 30 m", "12 m".
function DoomsdayView.until_(seconds)
  local minutes = math.max(0, math.floor(seconds / 60))
  if minutes >= 1440 then
    return string.format("%d d %d h", math.floor(minutes / 1440), math.floor(minutes % 1440 / 60))
  end
  return ns.Doomsday.duration(seconds)
end

local KIND = { daily = "Daily", weekly = "Weekly", skirmish = "Skirmish", bounty = "Bounty" }

-- The text of a goal id (the Hunt with its combination), or "A goal from a newer version" for an unknown id.
function DoomsdayView.goalText(id, hunts)
  if id == "hunt" then
    local parts = {}
    for _, h in ipairs(hunts or {}) do parts[#parts + 1] = DoomsdayView.huntText(h) end
    return #parts > 0 and table.concat(parts, " or ") or "The Hunt"
  end
  local g = ns.Doomsday.goal(id)
  return g and g.text or "A goal from a newer version"
end

--[[ Rows of a day's or week's goals: { { id, kind ("Daily", "Hunt", ...), text, value, target, done, at,
fraction, instead (the original's text when swapped) } }. entry = { set, swapped, done }; progress = { [id] =
{ value, target } }; hunts = { { race, class } }. ]]
function DoomsdayView.rows(entry, progress, hunts)
  local rows = {}
  for _, id in ipairs(entry and entry.set or {}) do
    local g = ns.Doomsday.goal(id)
    local p = progress and progress[id] or {}
    local at = entry.done and entry.done[id]
    local original = entry.swapped and entry.swapped[id]
    local target = p.target or 1
    local value = math.min(p.value or 0, target)
    rows[#rows + 1] = {
      id = id, kind = id == "hunt" and "Hunt" or (g and KIND[g.slot]) or "Goal",
      text = DoomsdayView.goalText(id, hunts), value = value, target = target, done = at ~= nil, at = at,
      fraction = at and 1 or (target > 0 and value / target or 0),
      instead = original and DoomsdayView.goalText(original) or nil,
    }
  end
  return rows
end

-- "3 of 5 done".
function DoomsdayView.doneCount(rows)
  local done = 0
  for _, r in ipairs(rows) do
    if r.done then done = done + 1 end
  end
  return done, #rows
end

--[[ "9 kills: 4 near level, 2 solo, 1 above" from scored kills (Doomsday.scoreKills), the PvP track only.
near level: -3 to +2; above: +3 or more or a skull; below: 4 or more below. nil without kills. ]]
function DoomsdayView.killSummary(scored)
  local n, near, solo, above, below = 0, 0, 0, 0, 0
  for _, s in ipairs(scored or {}) do
    if s.track == "pvp" then
      n = n + 1
      local k = s.kill
      if k.lvl == -1 then
        above = above + 1
      elseif type(k.lvl) == "number" and type(k.myLvl) == "number" then
        local diff = k.lvl - k.myLvl
        if diff >= 3 then above = above + 1 elseif diff <= -4 then below = below + 1 else near = near + 1 end
      end
      if k.solo then solo = solo + 1 end
    end
  end
  if n == 0 then return nil end
  local parts = {}
  if near > 0 then parts[#parts + 1] = near .. " near level" end
  if solo > 0 then parts[#parts + 1] = solo .. " solo" end
  if above > 0 then parts[#parts + 1] = above .. " above" end
  if below > 0 then parts[#parts + 1] = below .. " below" end
  local head = n == 1 and "1 kill" or (n .. " kills")
  return #parts > 0 and (head .. ": " .. table.concat(parts, ", ")) or head
end

--[[ The Duel slot of today for `me` (friend key): duels = Doomsday.duels(...).duels, names = { [key] = name },
friends = { key, ... } (other friends with the addon). Returns { done = { { name, won, disputed } }, open =
{ name, ... } }. ]]
function DoomsdayView.duelSlot(duels, day, me, names, friends)
  local done, met = {}, {}
  for _, d in ipairs(duels or {}) do
    if d.day == day and (d.a == me or d.b == me) then
      local other = d.a == me and d.b or d.a
      met[other] = true
      done[#done + 1] = { name = names[other] or other, won = d.winner == me, disputed = d.disputed }
    end
  end
  local open = {}
  for _, key in ipairs(friends or {}) do
    if key ~= me and not met[key] then open[#open + 1] = names[key] or key end
  end
  table.sort(done, function(a, b) return tostring(a.name) < tostring(b.name) end)
  table.sort(open, function(a, b) return tostring(a) < tostring(b) end)
  return { done = done, open = open }
end

-- "won vs Bob", "lost vs Bob", "disputed vs Bob".
function DoomsdayView.duelText(d)
  return string.format("%s vs %s", d.disputed and "disputed" or (d.won and "won" or "lost"), tostring(d.name))
end

-- What a bounty for every enemy class or race still needs: "Paladin, Priest, Hunter", or nil.
function DoomsdayView.stillNeeded(id, scored, factions)
  local lists, field, name
  if id == "b.allClasses" then
    lists, field, name = ns.Doomsday.ENEMY_CLASSES, "class", DoomsdayView.className
  elseif id == "b.allRaces" then
    lists, field, name = ns.Doomsday.ENEMY_RACES, "race", DoomsdayView.raceName
  else
    return nil
  end
  local seen = {}
  for _, s in ipairs(scored or {}) do
    if s.counted and s.track == "pvp" and s.kill[field] then seen[s.kill[field]] = true end
  end
  local best
  for _, faction in ipairs(factions or { "Horde" }) do
    local missing = {}
    for _, v in ipairs(lists[faction] or {}) do
      if not seen[v] then missing[#missing + 1] = name(v) end
    end
    if not best or #missing < #best then best = missing end
  end
  return best and #best > 0 and table.concat(best, ", ") or nil
end

-- Today's points per track: the day's goals done, today's kill points and today's Duel slot.
function DoomsdayView.todayPoints(state)
  local points = { pve = 0, pvp = 0 }
  for id in pairs(state.today and state.today.done or {}) do
    local track, p = ns.Doomsday.goalPoints(id)
    if track then points[track] = points[track] + p end
  end
  for _, s in ipairs(state.dayScored or {}) do
    if s.track == "pvp" then points.pvp = points.pvp + s.points end
  end
  for _, d in ipairs(state.duels and state.duels.done or {}) do
    if not d.disputed then
      points.pvp = points.pvp + (d.won and ns.Doomsday.POINTS.duelWin or ns.Doomsday.POINTS.duelLoss)
    end
  end
  return points
end

-- ===== Chat lines (CF-57; the board's "chat lines") =====

-- "Daily done: Finish 10 quests (+5 PvE, 2 of 3 today)".
function DoomsdayView.dailyDoneLine(text, done, total)
  return string.format("Daily done: %s (+%d PvE, %d of %d today)", text, ns.Doomsday.POINTS.daily, done, total)
end

-- "Weekly done: Run 3 dungeons (+15 PvE)".
function DoomsdayView.weeklyDoneLine(text, track)
  return string.format("Weekly done: %s (+%d %s)", text, ns.Doomsday.POINTS.weekly, track == "pvp" and "PvP" or "PvE")
end

-- "Skirmish done: Lone wolf: 3 solo kills (+5 PvP)".
function DoomsdayView.skirmishDoneLine(text)
  return string.format("Skirmish done: %s (+%d PvP)", text, ns.Doomsday.POINTS.daily)
end

-- "Hunt done: a Night Elf Druid fell to Ada Nightshade (+5 PvP)".
function DoomsdayView.huntDoneLine(hunt, charName)
  return string.format("Hunt done: %s fell to %s (+%d PvP)", DoomsdayView.huntText(hunt, true) or "the Hunt",
    tostring(charName), ns.Doomsday.POINTS.daily)
end

-- A kill worth more than 1 point: "Kill: +2 PvP · 3 levels above you, and solo (+1)". nil for 1 point or less.
function DoomsdayView.killLine(scored)
  if not scored or not scored.counted or scored.track ~= "pvp" or scored.points < 2 then return nil end
  local k = scored.kill
  local base = scored.points - (k.solo and 1 or 0)
  local why
  if k.lvl == -1 then
    why = "a skull"
  elseif type(k.lvl) == "number" and type(k.myLvl) == "number" and k.lvl - k.myLvl >= 3 then
    why = string.format("%d levels above you", k.lvl - k.myLvl)
  end
  local text = string.format("Kill: +%d PvP", base)
  if why then text = text .. " \194\183 " .. why end
  if k.solo then text = text .. (why and ", and solo (+1)" or " \194\183 solo (+1)") end
  return text
end

-- "Mira finished Doomsday first today. You're at 3 of 5."
function DoomsdayView.crownLine(name, done, total)
  return string.format("%s finished Doomsday first today. You're at %d of %d.", tostring(name), done, total)
end

-- 'Swapped for you: "Gain a level on an alt" → "Finish 10 quests"' (the game font has no arrow: "to").
function DoomsdayView.swapLine(originalText, newText, arrow)
  return string.format("Swapped for you: \"%s\" %s \"%s\"", originalText, arrow or "to", newText)
end

-- ===== The character card (CF-57) =====

--[[ The PvP line of a character: "Stone Guard, a.k.a. Mailbox Menace · 1,234 honorable kills · PvP 40 this
week", "PvP Virgin" for a character that never killed anyone, nil without PvP data (an older addon). ]]
function DoomsdayView.pvpLine(pvp, faction, weekPoints)
  if type(pvp) ~= "table" then return nil end
  if (pvp.hk or 0) == 0 and (weekPoints or 0) == 0 then
    return pvp.hk == 0 and "PvP Virgin" or nil
  end
  local parts = {}
  local rank = ns.Pvp.rankText(pvp, faction)
  if rank then parts[#parts + 1] = rank end
  if pvp.hk then parts[#parts + 1] = DoomsdayView.thousands(pvp.hk) .. " honorable kills" end
  if weekPoints and weekPoints > 0 then parts[#parts + 1] = "PvP " .. weekPoints .. " this week" end
  return #parts > 0 and table.concat(parts, " \194\183 ") or nil
end

-- 1234 -> "1,234".
function DoomsdayView.thousands(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

ns.DoomsdayView = DoomsdayView
return DoomsdayView
