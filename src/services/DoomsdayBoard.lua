-- DoomsdayBoard: the Doomsday tab's Board, Ladder and Feats (CF-57b; split from DoomsdayTracker in CF-59). Gathers
-- everyone's synced goals, feeds and characters for DoomsdayView, and remembers the own characters' feats with when
-- they were first seen (self.feats, local). The own goals and facts stay DoomsdayTracker's.
local _, ns = ...

local DoomsdayBoard = {}

local addonRef, events

local function global() return addonRef.db.global end
local function own() return global().self end
local function store() return ns.DoomsdayTracker.store() end
local function nameOf(bt) return ns.DoomsdayTracker.nameOf(bt) end
local function duelInput() return ns.DoomsdayTracker.duelInput() end
local function communityNames() return ns.DoomsdayTracker.communityNames() end


-- Every person's data for the Board and the Ladder: { key, name, isSelf, goals, feed, chars }.
local function everyone()
  local list = { { key = own().battleTag or "self", name = nameOf(own().battleTag or "self"), isSelf = true,
                   goals = (function()
                     local _, goals = store()
                     return { days = goals.days, weeks = goals.weeks, streak = goals.streak and goals.streak.n }
                   end)(), feed = own().feed, chars = own().chars } }
  for bt, person in pairs(global().people or {}) do
    if bt ~= own().battleTag and not tostring(bt):match("^aid:") then
      list[#list + 1] = { key = bt, name = nameOf(bt), goals = person.goals, feed = person.feed, chars = person.chars,
                          version = person.version }
    end
  end
  return list
end

-- Scores of everyone for a day and week, with duel points added.
local function scores(day, week, schedule)
  local community = communityNames()
  local duels, owner = duelInput()
  local result = ns.Doomsday.duels(duels, owner, schedule)
  local dayDuels, weekDuels = {}, {}
  for _, d in ipairs(result.duels) do
    if not d.disputed and d.winner then
      local loser = d.winner == d.a and d.b or d.a
      local sides = { { d.winner, ns.Doomsday.POINTS.duelWin, true }, { loser, ns.Doomsday.POINTS.duelLoss } }
      for _, entry in ipairs(sides) do
        local key, p, won = entry[1], entry[2], entry[3]
        if ns.Doomsday.week(d.day) == week then
          weekDuels[key] = weekDuels[key] or { points = 0, won = 0, lost = 0 }
          weekDuels[key].points = weekDuels[key].points + p
          if won then weekDuels[key].won = weekDuels[key].won + 1 else weekDuels[key].lost = weekDuels[key].lost + 1 end
        end
        if d.day == day then dayDuels[key] = (dayDuels[key] or 0) + p end
      end
    end
  end
  local list = {}
  for _, p in ipairs(everyone()) do
    local s = ns.DoomsdayView.score({ goals = p.goals, feed = p.feed, chars = p.chars, schedule = schedule,
                                      community = community, day = day, week = week })
    s.today.pvp = s.today.pvp + (dayDuels[p.key] or 0)
    s.week.pvp = s.week.pvp + (weekDuels[p.key] and weekDuels[p.key].points or 0)
    s.duels = weekDuels[p.key] or { points = 0, won = 0, lost = 0 }
    if s.week.pvp > 0 or s.today.pvp > 0 then s.killedEver = true end -- CF-61: any PvP point ends the Virgin
    s.key, s.name, s.isSelf, s.chars, s.hasGoals = p.key, p.name, p.isSelf, p.chars, type(p.goals) == "table"
    list[#list + 1] = s
  end
  return list
end

--[[ The Board: every friend's goals today. { day, columns = { { id, short } }, rows = { { key, name, isSelf,
status = "ok"|"noData", cells = { { id, done, at, value, target, instead } }, crossed, finishedAt, crown, streak, today,
week } },
crown = key } (sorted: you first, then crossed out, then by name). ]]
function DoomsdayBoard.board()
  if not addonRef then return nil end
  local today, schedule = ns.DoomsdayTracker.today()
  local week = ns.Doomsday.week(today)
  local mine = ns.DoomsdayTracker.state()
  local columns = {}
  for _, id in ipairs(mine.today.set) do columns[#columns + 1] = { id = id, short = ns.DoomsdayView.short(id) } end
  local list = scores(today, week, schedule)
  local crownList, rows = {}, {}
  for _, s in ipairs(list) do
    local entry = s.isSelf and mine.today or s.day
    local row = { key = s.key, name = s.name, isSelf = s.isSelf, status = entry and "ok" or "noData", cells = {},
                  streak = s.isSelf and mine.streak or s.streak, today = s.today, week = s.week }
    if entry then
      for i, id in ipairs(entry.set or {}) do
        local p = s.isSelf and mine.progress[id] or {}
        row.cells[i] = { id = id, done = entry.done and entry.done[id] ~= nil, at = entry.done and entry.done[id],
                         value = p.value, target = p.target,
                         instead = entry.swapped and entry.swapped[id] and ns.DoomsdayView.goalText(entry.swapped[id]) }
      end
      row.crossed = ns.Doomsday.crossedOut(entry.set, entry.done)
      row.finishedAt = row.crossed and ns.Doomsday.finishedAt(entry.set, entry.done) or nil -- CF-61
      crownList[#crownList + 1] = { friend = s.key, set = entry.set, done = entry.done }
    end
    rows[#rows + 1] = row
  end
  local crown = ns.Doomsday.crown(crownList)
  for _, row in ipairs(rows) do row.crown = row.key == crown end
  table.sort(rows, function(a, b)
    if a.isSelf ~= b.isSelf then return a.isSelf == true end
    if (a.status == "ok") ~= (b.status == "ok") then return a.status == "ok" end
    return tostring(a.name) < tostring(b.name)
  end)
  return { day = today, label = mine.label, columns = columns, rows = rows, crown = crown }
end

--[[ The Ladder: this week, one ranking per track (Doomsday.ladder) with movement against last week from the data
at hand, the split per character, and your PvP details. ]]
function DoomsdayBoard.ladder()
  if not addonRef then return nil end
  local today, schedule = ns.DoomsdayTracker.today()
  local week = ns.Doomsday.week(today)
  local function rows(list)
    local friends = {}
    for _, s in ipairs(list) do
      if s.hasGoals or s.isSelf then
        friends[#friends + 1] = { friend = s.key, name = s.name, pve = s.week.pve, pvp = s.week.pvp, goals = s.goals,
                                  kills = s.kills, killedEver = s.killedEver }
      end
    end
    return friends
  end
  local now = scores(today, week, schedule)
  local before = ns.Doomsday.ladder(rows(scores(today - 7, week - 1, schedule)))
  local previous = { pve = {}, pvp = {} }
  for _, track in ipairs({ "pve", "pvp" }) do
    for _, r in ipairs(before[track]) do previous[track][r.friend] = r.rank end
  end
  local ladder = ns.Doomsday.ladder(rows(now), previous)
  local byKey = {}
  for _, s in ipairs(now) do byKey[s.key] = s end
  ladder.people = byKey
  ladder.me = byKey[own().battleTag or "self"]
  ladder.week = week
  return ladder
end

-- Your characters' feats for the tab: { { guid, name, classFile, feats = Feats.list, hk, rank } } (highest first).
function DoomsdayBoard.feats()
  if not addonRef then return nil end
  local list = {}
  for guid, c in pairs(own().chars or {}) do
    list[#list + 1] = { guid = guid, name = c.name, classFile = c.classFile, level = c.level, pvp = c.pvp,
                        feats = ns.Feats.list(own().feats and own().feats[guid]) }
  end
  table.sort(list, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

-- Remembers the feats of the own characters (first seen times, local). Returns { { guid, key } } new now.
local function rememberFeats()
  own().feats = own().feats or {}
  local new = {}
  for guid, c in pairs(own().chars or {}) do
    local entries = {}
    local days = {}
    for day in pairs(own().feed or {}) do days[#days + 1] = day end
    table.sort(days)
    for _, day in ipairs(days) do
      local e = own().feed[day][guid]
      if e then entries[#entries + 1] = e end
    end
    own().feats[guid] = own().feats[guid] or {}
    for _, key in ipairs(ns.Feats.remember(own().feats[guid], ns.Feats.derive(c, entries), GetServerTime())) do
      new[#new + 1] = { guid = guid, key = key }
    end
  end
  return new
end
DoomsdayBoard.rememberFeats = rememberFeats


function DoomsdayBoard.start(addon)
  addonRef = addon
  events = events or LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.SelfTracker.UPDATED, function() rememberFeats() end)
  events:RegisterMessage(ns.FeedTracker.CHANGED, function() rememberFeats() end) -- epics, watch list
  rememberFeats() -- the first sight marks what was there as "Earlier"
end

ns.DoomsdayBoard = DoomsdayBoard
return DoomsdayBoard
