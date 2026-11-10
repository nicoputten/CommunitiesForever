-- Celebrations: the rules of the celebration banners (CF-67; boards docs/design/celebrations-2026-11/). Pure Lua,
-- no WoW globals. Which moment makes a banner (goals done, the day complete, feats, friends' big moments), its weight
-- (small, medium, big: sound, size, time on screen), its edge and texts; folding several into one; the queue that
-- waits through combat; and the keys that keep a moment from showing twice. Requires ns.Doomsday and
-- ns.DoomsdayView.
local _, ns = ...

local Celebrations = {}

Celebrations.WEIGHT = { small = 1, medium = 2, big = 3 }
Celebrations.SECONDS = { small = 4, medium = 5, big = 6 }  -- on screen, by weight (CB08)
Celebrations.GATHER = 3          -- seconds: what arrives within them becomes one banner (CB05)
Celebrations.AFTER_BUSY = 2      -- seconds after combat, an encounter or a battleground (CB08)
Celebrations.LOGIN_QUIET = 10    -- seconds after login: feats found then are known, not new
Celebrations.FRIEND_SECONDS = 4  -- a friend's line on screen (CB06)
Celebrations.FRIEND_STACK = 3    -- friends' lines at once
Celebrations.FRIEND_WAITING = 6  -- friends' lines waiting at most
Celebrations.FRIEND_MAX_AGE = 900 -- a friend's moment older than this (seconds) is not shown
Celebrations.SMALL_SCREEN = 1600 -- below this screen width (pixels) the banner draws at SMALL_SCALE (CB07)
Celebrations.SMALL_SCALE = 0.85

local DOT = " \194\183 "
local D = function() return ns.Doomsday end

-- Feat kinds that are PvP (crossed swords on the medallion).
-- CF-118: the Hunt feats (kind "hunt") too.
local PVP_FEATS = { honorKills = true, pvpRank = true, duelWins = true, deaths100 = true, bgFirstWin = true,
                    hunt = true }

local function plural(n, one, many) return n == 1 and ("+1 " .. one) or ("+" .. n .. " " .. many) end

-- The number after the last ":" of a feat key ("pvpRank:6" -> 6).
local function step(key) return tonumber(tostring(key):match(":(%d+)$")) end

-- The banner scale for a screen width in pixels (nil: unknown, full size).
function Celebrations.scale(screenWidth)
  if type(screenWidth) == "number" and screenWidth > 0 and screenWidth < Celebrations.SMALL_SCREEN then
    return Celebrations.SMALL_SCALE
  end
  return 1
end

-- "Week 44": the calendar week (Sunday first, as the Doomsday week) of the week's start. nil when unknown.
function Celebrations.weekLabel(weekStartAt, dateFn)
  local n = weekStartAt and dateFn and tonumber(dateFn("%U", weekStartAt))
  return n and ("Week " .. n) or nil
end

-- "PvE 15 · PvP 10 · <flame> 6 days": today's points per track, never added, and the streak. flame: an inline icon
-- (or "").
function Celebrations.dayLine(points, streak, flame)
  local text = string.format("PvE %d%sPvP %d", points and points.pve or 0, DOT, points and points.pvp or 0)
  if type(streak) == "number" and streak > 0 then
    local icon = flame and flame ~= "" and (flame .. " ") or ""
    text = text .. DOT .. icon .. streak .. (streak == 1 and " day" or " days")
  end
  return text
end

-- ===== Your goals =====

-- A goal's title on the banner: a Skirmish's name before its colon ("Lone wolf"), else the goal's text.
local function goalTitle(id, hunts)
  local text = ns.DoomsdayView.goalText(id, hunts)
  local g = D().goal(id)
  if g and g.slot == "skirmish" then return text:match("^(.-):") or text end
  return text
end

--[[ The moments of goals just done. input = { newly = { id }, weekly = { id } (Goals.mark), today = { set, done },
thisWeek = { set, done }, dayLabel ("Wed evening"), weekLabel ("Week 44"), duelDone, hunts, crownMine, points =
{ pve, pvp } (today), streak }. Returns { moment } in order: the dailies, the day complete, the weeklies. The day is
complete when this batch crossed you out (all three PvE dailies); the daily that finished it is part of that moment.
moment = { key, kind, weight, edge, icon, kicker, title, line, points, crown, streak, view }. ]]
function Celebrations.goalMoments(input)
  local Doomsday = D()
  local today = input.today or {}
  local list, dailies = {}, {}
  local finishing
  if Doomsday.crossedOut(today.set, today.done) then
    local at = Doomsday.finishedAt(today.set, today.done)
    for _, id in ipairs(input.newly or {}) do
      local g = Doomsday.goal(id)
      if not finishing and g and g.slot == "daily" and today.done and today.done[id] == at then finishing = id end
    end
  end
  local rows = ns.DoomsdayView.rows(today, nil, input.hunts)
  local duelDone = input.duelDone
  if ns.DoomsdayView.hasDuelRow(today) then duelDone = nil end -- CF-118: the Duel slot is a row from pool version 6
  local done, total = ns.DoomsdayView.doneCount(rows, duelDone)
  for _, id in ipairs(input.newly or {}) do
    local g = Doomsday.goal(id)
    if id ~= finishing and (id == "hunt" or g) then
      local pvp = id == "hunt" or (g and g.slot ~= "daily")
      local count = string.format("%d of %d", done, total)
      dailies[#dailies + 1] = {
        key = "daily:" .. id, kind = "daily", weight = "small", edge = pvp and "pvp" or "pve", icon = "goal",
        kicker = "Daily goal" .. DOT .. (pvp and "PvP" or "PvE"), title = goalTitle(id, input.hunts),
        line = input.dayLabel and (input.dayLabel .. DOT .. count) or count,
        points = "+" .. (Doomsday.pointsFor(id, Doomsday.entryPool(today)) or Doomsday.POINTS.daily), view = "today",
      }
    end
  end
  for _, m in ipairs(dailies) do list[#list + 1] = m end
  if finishing then
    list[#list + 1] = {
      key = "day", kind = "day", weight = "medium", edge = "day", icon = "emblem", kicker = "Day complete",
      title = input.dayLabel or "Today", dayPoints = input.points or { pve = 0, pvp = 0 }, streak = input.streak,
      line = Celebrations.dayLine(input.points, input.streak, ""), crown = input.crownMine == true, view = "today",
    }
  end
  local week = input.thisWeek or {}
  local weekDone, weekTotal = 0, #(week.set or {})
  for _, id in ipairs(week.set or {}) do
    if week.done and week.done[id] then weekDone = weekDone + 1 end
  end
  for _, id in ipairs(input.weekly or {}) do
    local g = Doomsday.goal(id)
    if g then
      local bounty = g.slot == "bounty"
      local line = input.weekLabel
      if not bounty then
        local count = string.format("%d of %d", weekDone, weekTotal)
        line = line and (line .. DOT .. count) or count
      end
      list[#list + 1] = {
        key = "week:" .. id, kind = bounty and "bounty" or "weekly", weight = "medium",
        edge = bounty and "bounty" or "weekly", icon = bounty and "swords" or "hourglass",
        kicker = bounty and "Bounty" or "Weekly goal", title = g.text, line = line or "",
        points = "+" .. (Doomsday.pointsFor(id, Doomsday.entryPool(week)) or Doomsday.POINTS.weekly), view = "week",
      }
    end
  end
  return list
end

-- ===== Feats =====

--[[ Whether a feat is special (big, CB04): PvP rank 6 or higher, level 60, the first epic, a mount or an epic mount,
1,000 honorable kills or more. feat = { key, kind } (Feats.derive). ]]
function Celebrations.special(feat)
  local kind = feat and feat.kind
  if kind == "maxLevel" or kind == "firstEpic" or kind == "mount" or kind == "epicMount" then return true end
  if kind == "pvpRank" then return (step(feat.key) or 0) >= 6 end
  if kind == "honorKills" then return (step(feat.key) or 0) >= 1000 end
  return false
end

-- Whether nobody else holds a feat key: others = { { feat, ... } } (the derived feats of every other character).
function Celebrations.firstInGroup(key, others)
  for _, list in ipairs(others or {}) do
    for _, f in ipairs(list) do
      if f.key == key then return false end
    end
  end
  return true
end

--[[ The moment of a feat of your own: feat = { key, kind, title, detail } (Feats.derive), charName, first (nobody in
the group had it). Big when special or first; the first epic takes the violet edge. ]]
function Celebrations.featMoment(feat, charName, first)
  local name = tostring(charName or "")
  local line = name
  if feat.kind == "pvpRank" then
    line = name .. DOT .. "rank " .. tostring(step(feat.key) or "?")
  elseif feat.kind == "firstEpic" then
    line = name .. DOT .. "first epic"
  end
  local icon = feat.kind == "pvpRank" and "rank" or feat.kind == "firstEpic" and "epic"
    or PVP_FEATS[feat.kind] and "swords" or "emblem"
  return {
    key = "feat:" .. tostring(feat.key), kind = "feat",
    weight = (first or Celebrations.special(feat)) and "big" or "medium",
    edge = feat.kind == "firstEpic" and "epic" or "day", icon = icon, kicker = "Feat unlocked",
    title = tostring(feat.title or ""), line = line, badge = first and "First in the group" or nil, view = "feats",
  }
end

-- ===== Folding (CB05) =====

--[[ One banner from several moments (in the order they arrived): the heaviest, ties to the latest, with the rest as
one grey line in the order day complete, goals, weeklies, feats, crown ("Day complete · +3 goals · crown"; nil when
nothing is folded). Returns a copy of the winner with `folded`, or nil for an empty list. ]]
function Celebrations.fold(moments)
  local winner, wi
  for i, m in ipairs(moments or {}) do
    if not winner or Celebrations.WEIGHT[m.weight] >= Celebrations.WEIGHT[winner.weight] then winner, wi = m, i end
  end
  if not winner then return nil end
  local day, goals, weeklies, feats, crown = false, 0, 0, 0, false
  for i, m in ipairs(moments) do
    if i ~= wi then
      if m.kind == "day" then
        day = true
        crown = crown or m.crown
      elseif m.kind == "daily" then
        goals = goals + 1
      elseif m.kind == "weekly" or m.kind == "bounty" then
        weeklies = weeklies + 1
      elseif m.kind == "feat" then
        feats = feats + 1
      end
    end
  end
  local parts = {}
  if day then parts[#parts + 1] = "Day complete" end
  if goals > 0 then parts[#parts + 1] = plural(goals, "goal", "goals") end
  if weeklies > 0 then parts[#parts + 1] = plural(weeklies, "weekly", "weeklies") end
  if feats > 0 then parts[#parts + 1] = plural(feats, "feat", "feats") end
  if crown then parts[#parts + 1] = "crown" end
  local banner = {}
  for k, v in pairs(winner) do banner[k] = v end
  banner.folded = #parts > 0 and table.concat(parts, DOT) or nil
  return banner
end

-- ===== Waiting =====

function Celebrations.newQueue() return { pending = {}, readyAt = nil, wasBusy = false } end

-- Adds moments; the first starts the gather window.
function Celebrations.push(q, moments, now)
  for _, m in ipairs(moments or {}) do q.pending[#q.pending + 1] = m end
  if #q.pending > 0 and not q.readyAt then q.readyAt = now + Celebrations.GATHER end
end

--[[ The banner due now, folded, or nil: nothing waits, the window is still open, or you are busy (combat, an
encounter, a battleground). After being busy it waits AFTER_BUSY more. The caller asks only while no banner shows. ]]
function Celebrations.take(q, now, busy)
  if #q.pending == 0 then return nil end
  if busy then
    q.wasBusy = true
    return nil
  end
  if q.wasBusy then
    q.wasBusy = false
    q.readyAt = math.max(q.readyAt or 0, now + Celebrations.AFTER_BUSY)
  end
  if now < (q.readyAt or now) then return nil end
  local banner = Celebrations.fold(q.pending)
  q.pending, q.readyAt = {}, nil
  return banner
end

-- Seconds until take() could give a banner (for the caller's timer); nil when nothing waits.
function Celebrations.waitFor(q, now)
  if #q.pending == 0 then return nil end
  return math.max(0, (q.readyAt or now) - now)
end

-- ===== Remembered keys (no doubles after /reload) =====

-- Marks key in set; true when it was new.
function Celebrations.once(set, key)
  if set[key] then return false end
  set[key] = true
  return true
end

--[[ Forgets day and week keys of the past: "<day>:..." and "d<day>:..." before day - 2, "w<week>:..." before
week - 1. Other keys (feats) stay. ]]
function Celebrations.prune(set, day, week)
  for key in pairs(set) do
    local d = tonumber(tostring(key):match("^d(%d+):"))
    local w = tonumber(tostring(key):match("^w(%d+):"))
    if (d and day and d < day - 2) or (w and week and w < week - 1) then set[key] = nil end
  end
end

-- The remembered key of a moment of yours: dailies and the day by day number, weeklies by week number.
function Celebrations.ownKey(moment, day, week, guid)
  if moment.kind == "weekly" or moment.kind == "bounty" then return "w" .. tostring(week) .. ":" .. moment.key end
  if moment.kind == "feat" then return tostring(guid) .. ":" .. moment.key end
  return "d" .. tostring(day) .. ":" .. moment.key
end

-- ===== Friends' moments (CB06) =====

-- What a friend's special feat says after their name: "is now a Stone Guard", "looted Robe of Volatile Power".
function Celebrations.friendFeatText(feat)
  local kind = feat.kind
  if kind == "pvpRank" then return "is now a " .. tostring(feat.title) end
  if kind == "firstEpic" then return "looted " .. tostring(feat.title) end
  if kind == "maxLevel" then return "reached level " .. tostring(feat.title):gsub("^Level ", "") end
  if kind == "mount" then return "got a mount" end
  if kind == "epicMount" then return "got an epic mount" end
  if kind == "honorKills" then return "reached " .. tostring(feat.title) end
  return tostring(feat.title)
end

-- The character a friend most likely plays: the newest updatedAt, then the highest level.
local function currentChar(chars)
  local best
  for guid, c in pairs(chars or {}) do
    if type(c) == "table" then
      local better = not best
        or (c.updatedAt or 0) > (best.c.updatedAt or 0)
        or ((c.updatedAt or 0) == (best.c.updatedAt or 0) and (c.level or 0) > (best.c.level or 0))
        or ((c.updatedAt or 0) == (best.c.updatedAt or 0) and (c.level or 0) == (best.c.level or 0)
            and tostring(guid) < tostring(best.guid))
      if better then best = { guid = guid, c = c } end
    end
  end
  return best and best.c
end

-- A friend's feed entries of one character, oldest day first (Feats.derive input).
local function entriesOf(feed, guid)
  local days = {}
  for day in pairs(type(feed) == "table" and feed or {}) do
    if type(day) == "number" then days[#days + 1] = day end
  end
  table.sort(days)
  local list = {}
  for _, day in ipairs(days) do
    local e = type(feed[day]) == "table" and feed[day][guid]
    if type(e) == "table" then list[#list + 1] = e end
  end
  return list
end

--[[ Friends' big moments since the last call: a day complete, a weekly, a special feat. known = { [friend] = { keys =
{ [key] = true }, chars = { [guid] = true } } } (in place, remembered between sessions); people = { [friend] = {
displayName, chars, feed, goals } } (friends only, not you); ctx = { day, week, now, since (your login), derive =
Feats.derive }. Everything is remembered; a line comes only for a friend and character seen before, for a moment
after `since` and at most FRIEND_MAX_AGE old. Returns { { key, friend, name, charName, classFile, text, edge, at,
view } } oldest first. ]]
function Celebrations.friendMoments(known, people, ctx)
  local Doomsday = D()
  local lines = {}
  local friends = {}
  for friend in pairs(people or {}) do friends[#friends + 1] = friend end
  table.sort(friends, function(a, b) return tostring(a) < tostring(b) end)
  local function fresh(at)
    return type(at) == "number" and at >= (ctx.since or 0) and ctx.now - at <= Celebrations.FRIEND_MAX_AGE
  end
  for _, friend in ipairs(friends) do
    local p = people[friend]
    local firstTime = known[friend] == nil
    local k = known[friend] or { keys = {}, chars = {} }
    known[friend] = k
    k.keys, k.chars = k.keys or {}, k.chars or {}
    local name = type(p.displayName) == "string" and p.displayName or tostring(friend):match("^([^#]+)") or "?"
    local function add(key, at, text, edge, c)
      if not Celebrations.once(k.keys, key) or firstTime or not fresh(at) then return end
      lines[#lines + 1] = { key = key, friend = friend, name = name, charName = c and c.name,
                            classFile = c and c.classFile, text = text, edge = edge, at = at,
                            view = "board" }
    end
    local goals = type(p.goals) == "table" and p.goals or {}
    local now = currentChar(p.chars)
    local e = type(goals.days) == "table" and goals.days[ctx.day]
    if type(e) == "table" and Doomsday.crossedOut(e.set, e.done) then
      add("d" .. ctx.day .. ":day", Doomsday.finishedAt(e.set, e.done), "completed the day", "day", now)
    end
    local w = type(goals.weeks) == "table" and goals.weeks[ctx.week]
    if type(w) == "table" and type(w.done) == "table" then
      local ids = {}
      for id in pairs(w.done) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do
        local g = Doomsday.goal(id)
        add("w" .. ctx.week .. ":" .. tostring(id), w.done[id], "finished a weekly",
          g and g.slot == "bounty" and "bounty" or "weekly", now)
      end
    end
    local guids = {}
    for guid in pairs(type(p.chars) == "table" and p.chars or {}) do guids[#guids + 1] = guid end
    table.sort(guids)
    for _, guid in ipairs(guids) do
      local c = p.chars[guid]
      if type(c) == "table" and ctx.derive then
        local seen = k.chars[guid]
        k.chars[guid] = true
        for _, f in ipairs(ctx.derive(c, entriesOf(p.feed, guid))) do
          local key = tostring(guid) .. ":" .. f.key
          if not seen then
            k.keys[key] = true
          elseif Celebrations.special(f) then
            add(key, c.updatedAt, Celebrations.friendFeatText(f), f.kind == "firstEpic" and "epic" or "day", c)
          end
        end
      end
    end
    Celebrations.prune(k.keys, ctx.day, ctx.week)
  end
  table.sort(lines, function(a, b) return (a.at or 0) < (b.at or 0) end)
  return lines
end

-- Adds friends' lines to the waiting list (oldest dropped past FRIEND_WAITING).
function Celebrations.pushFriends(waiting, lines)
  for _, l in ipairs(lines or {}) do waiting[#waiting + 1] = l end
  while #waiting > Celebrations.FRIEND_WAITING do table.remove(waiting, 1) end
end

-- The sample banner of the settings' Preview: a medium day complete (CB09).
function Celebrations.preview(dayLabel)
  return {
    key = "preview", kind = "day", weight = "medium", edge = "day", icon = "emblem", kicker = "Day complete",
    title = dayLabel or "Today", dayPoints = { pve = 15, pvp = 10 }, streak = 6,
    line = Celebrations.dayLine({ pve = 15, pvp = 10 }, 6, ""), view = "today",
  }
end

ns.Celebrations = Celebrations
return Celebrations
