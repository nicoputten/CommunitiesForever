-- DoomsdayTab: the Doomsday tab (CF-57; board docs/design/doomsday-2026-10/DD07AddonToday). Chips on top (Today,
-- Week, and from CF-57b Board, Ladder and Feats (board DD08AddonBoard)). CF-61: each view's header says when it
-- resets; no notes about the rules or the site in the tab.
-- Native kit frames; the model is DoomsdayTracker (state, board, ladder, feats) and DoomsdayView, this file only
-- draws it.
local _, ns = ...

local DoomsdayTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 24
local KIND_WIDTH = 70
local RIGHT_WIDTH = 90
local ROW_HEIGHT = 40

DoomsdayTab.VIEWS = { { value = "today", text = "Today" }, { value = "week", text = "Week" },
                      { value = "board", text = "Board" }, { value = "ladder", text = "Ladder" },
                      { value = "feats", text = "Feats" } }

local root, chipsBar, scroll, chips
local helpers -- from MainFrame: settings(), render()
local current = "today"
local pools
local expanded = {} -- CF-57b: Ladder rows showing their characters (track:key), while the window is open

local placeText = Kit.placeText
local function gold(text) return Theme.code("goldLight") .. tostring(text) .. "|r" end
local function dim(text) return Theme.code("textDim") .. tostring(text) .. "|r" end

local dayStartAt -- CF-61: the start of the shown day (Today, Board); nil in the week's views

-- "10:42" in your own clock; "Wed 00:04" after midnight or in the week's views (CF-61).
local function clock(at)
  if not at or not date then return "" end
  return ns.DoomsdayView.timeText(at, dayStartAt, date)
end

local function check() return Theme.bundledFonts() and "\226\156\147" or "done" end

-- "New goals Thu 19:00 · in 4 h 28 m" (Today, Board; CF-62 adds the time) and "Week resets Sun 19:00 · in 3 d 5 h"
-- (Week, Ladder).
local function newGoals(state)
  local at = date and state.dayStart and ns.DoomsdayView.timeText(state.dayStart + ns.Doomsday.DAY, nil, date) or ""
  return string.format("New goals %s%sin %s", at, at ~= "" and " \194\183 " or "",
    ns.DoomsdayView.until_(state.resetsIn))
end
local function weekResets(state)
  local resetAt = date and date("%a %H:%M", ns.Doomsday.dayStart(ns.Doomsday.weekStart(state.week + 1),
    ns.DoomsdayTracker.schedule().offset, state.reset)) or ""
  return string.format("Week resets %s \194\183 in %s", resetAt, ns.DoomsdayView.until_(state.weekResetsIn))
end

-- ===== Factories =====

-- A progress bar: a faint track and a gold fill.
local function bar(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetHeight(4)
  b.track = Theme.fill(b, "divider", "BACKGROUND")
  b.track:SetAllPoints()
  b.fill = Theme.fill(b, "gold", "ARTWORK")
  b.fill:SetPoint("TOPLEFT")
  b.fill:SetPoint("BOTTOMLEFT")
  function b:SetFraction(f, width)
    self:SetWidth(width)
    self.fill:SetWidth(math.max(1, width * math.max(0, math.min(1, f or 0))))
  end
  return b
end

local function line(parent)
  local l = CreateFrame("Frame", nil, parent)
  l:SetHeight(1)
  l.fill = Theme.fill(l, "divider", "BORDER")
  l.fill:SetAllPoints()
  return l
end

-- A hover area with a tooltip ("Instead of: ..."), guarded.
local function hoverArea(parent)
  local h = CreateFrame("Frame", nil, parent)
  h:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.tip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return h
end

-- ===== Drawing =====

local function header(parent, text, y, width, right, rightColor)
  placeText(pools.day, parent, PAD, y + 12, width - 2 * PAD, text, "goldLight")
  if right then placeText(pools.small, parent, PAD, y + 15, width - 2 * PAD, right, rightColor or "faint", "RIGHT") end
  local sep = Kit.take(pools.lines, parent)
  sep:SetPoint("TOPLEFT", PAD, -(y + 36))
  sep:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
  return 42
end

-- One goal row: kind, text (with the swap mark), the progress bar or the check with its time.
local function goalRow(parent, row, y, width)
  local textX = PAD + KIND_WIDTH
  local textWidth = width - textX - RIGHT_WIDTH - PAD
  placeText(pools.tiny, parent, PAD, y + 8, KIND_WIDTH - 8, row.kind:upper(), "faint")
  local text = row.done and (Theme.code("textDim") .. row.text .. "|r") or row.text
  if row.instead then text = text .. dim("  (swapped)") end
  placeText(pools.body, parent, textX, y + 6, textWidth, text, row.done and "textDim" or "text")
  if row.instead then
    local h = Kit.take(pools.hovers, parent)
    h:SetPoint("TOPLEFT", textX, -(y + 4))
    h:SetSize(textWidth, 20)
    h.tip = "Instead of: " .. row.instead
  end
  if row.done then
    placeText(pools.small, parent, width - PAD - RIGHT_WIDTH, y + 8, RIGHT_WIDTH,
      gold(check() .. " " .. clock(row.at)), "goldLight", "RIGHT")
  else
    placeText(pools.small, parent, width - PAD - RIGHT_WIDTH, y + 8, RIGHT_WIDTH,
      string.format("%d/%d", row.value, row.target), "muted", "RIGHT")
    local b = Kit.take(pools.bars, parent)
    b:SetPoint("TOPLEFT", textX, -(y + 28))
    b:SetFraction(row.fraction, textWidth)
  end
  return ROW_HEIGHT
end

local function textLine(parent, text, y, width, color, pool)
  placeText(pool or pools.small, parent, PAD, y, width - 2 * PAD, text, color or "textDim")
  return 22
end

-- ===== Today (CF-62, board AG03Tabs) =====

local SIDE_WIDTH = 270  -- "Friends today"
local BAR_WIDTH = 140
local TRACK = { daily = "pve", weekly = "pve", skirmish = "pvp", bounty = "pvp" }
local SWAP_TIP = "Swapped (the blue corner): your character can't do the original goal (hover for it). Goals are "
  .. "suggestions; skip any."
local FRIENDS_TIP = "Live for friends online with the addon; others after their upload."
local DUEL_TIP = "Win +3 \194\183 loss +1 \194\183 first duel per friend"

local function trackOf(id)
  if id == "hunt" then return "pvp" end
  local g = ns.Doomsday.goal(id)
  return g and TRACK[g.slot] or "pve"
end

local function colored(name, text) return Theme.code(name) .. tostring(text) .. "|r" end

-- CF-63: the goal box (Kit.goalBox), on Today and the Board, with its tooltip (box.tip) on hover.
local function goalBox(parent)
  local b = Kit.goalBox(parent)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) if self.tip and GameTooltip then GameTooltip:Hide() end end)
  return b
end

-- CF-63 (board CF63DoomBoard): a goal's tooltip: the goal; "Swapped for you · original: …"; "6/10", "Not done yet"
-- or "done Thu 00:14", whose it is (a friend's name first) and when the goals reset.
local function goalTip(text, instead, done, at, progress, whose)
  local lines = { text }
  if instead then
    lines[#lines + 1] = string.format("Swapped for %s \194\183 original: %s", whose or "you", instead)
  end
  local state = done and ("done " .. clock(at)) or progress or "Not done yet"
  if whose then state = whose .. " \194\183 " .. state end
  local resets = ns.DoomsdayTracker.state().dayStart
  if resets and date then
    state = state .. " \194\183 resets " .. ns.DoomsdayView.timeText(resets + ns.Doomsday.DAY, nil, date)
  end
  lines[#lines + 1] = state
  return table.concat(lines, "\n")
end

-- A box with a 1 px border (the stat boxes, the mini board's goal boxes).
local function frameBox(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.fill = Theme.fill(b, "track", "BACKGROUND")
  b.fill:SetAllPoints()
  b.edges = Kit.edges(b, "divider")
  return b
end

local function boxAt(parent, x, y, w, h, fillColor, fillAlpha)
  local b = Kit.take(pools.frames, parent)
  b:SetPoint("TOPLEFT", x, -y)
  b:SetSize(w, h)
  b.fill:SetColorTexture(Theme.color(fillColor or "track", fillAlpha))
  return b
end

local function infoAt(parent, x, y, tip)
  local f = Kit.take(pools.infos, parent)
  f:SetPoint("TOPLEFT", x, -y)
  f.tip = tip
  return f
end

local function textWidth(holder, fallback)
  local fs = holder and holder.text
  local w = fs and fs.GetStringWidth and fs:GetStringWidth()
  return type(w) == "number" and w > 0 and w or fallback
end

-- One 40 px goal row: goal box, kind, title (struck through when done), "swapped", progress, points.
local function todayRow(parent, r, y, width)
  local track = r.track
  local cb = Kit.take(pools.checks, parent)
  cb:SetPoint("TOPLEFT", PAD + 1, -(y + 12))
  cb:SetGoal(r.done, r.instead ~= nil)
  cb.tip = goalTip(r.text, r.instead, r.done, r.at, (r.target or 1) > 1 and string.format("%d/%d", r.value or 0,
    r.target) or nil)
  placeText(pools.tiny, parent, PAD + 28, y + 13, 62, r.kind, track)
  local titleX = PAD + 92
  local right = PAD + width - 2 * PAD -- the left column's right edge
  local titleWidth = right - titleX - BAR_WIDTH - 90
  local t = placeText(pools.body, parent, titleX, y + 11, titleWidth, r.text, r.done and "muted" or "text")
  local tw = math.min(titleWidth, textWidth(t, titleWidth))
  if r.done then
    local strike = Kit.take(pools.lines, parent)
    strike:SetPoint("TOPLEFT", titleX, -(y + 19))
    strike:SetWidth(tw)
  end
  if r.instead then
    -- CF-63 (Nico, 2026-10-30): the word "swapped" stays next to the box's blue corner.
    placeText(pools.small, parent, titleX + tw + 8, y + 13, 90, "swapped", "swap")
    local h = Kit.take(pools.hovers, parent)
    h:SetPoint("TOPLEFT", titleX, -(y + 8))
    h:SetSize(tw + 96, 22)
    h.tip = cb.tip
  end
  if r.tip then
    local h = Kit.take(pools.hovers, parent)
    h:SetPoint("TOPLEFT", titleX, -(y + 8))
    h:SetSize(right - titleX, 22)
    h.tip = r.tip
  end
  -- Progress: "done" / "not yet" for one-step goals, else a 140 px bar next to "1/10".
  local px = right - 40 - BAR_WIDTH - 44
  if (r.target or 1) <= 1 then
    placeText(pools.small, parent, px, y + 13, BAR_WIDTH + 40, r.done and "done" or "not yet",
      r.done and "pve" or "muted", "RIGHT")
  else
    local b = Kit.take(pools.bars, parent)
    b:SetPoint("TOPLEFT", px, -(y + 18))
    b:SetFraction(r.fraction, BAR_WIDTH)
    placeText(pools.small, parent, px + BAR_WIDTH + 6, y + 13, 40, string.format("%d/%d", r.value or 0, r.target),
      "muted")
  end
  if r.points and r.points ~= "" then
    placeText(pools.small, parent, right - 36, y + 13, 36, r.points, track, "RIGHT")
  end
  return ROW_HEIGHT
end

-- The three stat boxes: Today and This week (PvE green · PvP red), Streak.
local function statBoxes(parent, state, points, y, width, killTip)
  local gap = 10
  local w = math.floor((width - 2 * gap) / 3)
  local function stat(i, title, value, tip)
    local x = PAD + (i - 1) * (w + gap)
    boxAt(parent, x, y, w, 52)
    placeText(pools.tiny, parent, x + 10, y + 8, w - 20, title, "faint")
    placeText(pools.body, parent, x + 10, y + 26, w - 20, value, "text")
    if tip then
      local h = Kit.take(pools.hovers, parent)
      h:SetPoint("TOPLEFT", x, -y)
      h:SetSize(w, 52)
      h.tip = tip
    end
  end
  local function pts(p)
    return colored("pve", "PvE " .. (p.pve or 0)) .. dim("  \194\183  ") .. colored("pvp", "PvP " .. (p.pvp or 0))
  end
  stat(1, "Today", pts(points), killTip)
  stat(2, "This week", pts(state.points))
  stat(3, "Streak", colored("warning", string.format("%d %s", state.streak, state.streak == 1 and "day" or "days"))
    .. dim("  best " .. state.best))
  return 52
end

-- "Friends today": one row per friend with Doomsday data, you as "You"; a box per goal of the day.
local function friendsToday(parent, x, y, width)
  local b = ns.DoomsdayBoard.board()
  local title = placeText(pools.body, parent, x, y, width, "Friends today", "goldLight")
  infoAt(parent, x + math.min(width - 16, textWidth(title, 90)) + 6, y + 1, FRIENDS_TIP)
  placeText(pools.tiny, parent, x, y + 2, width, "PvE \194\183 PvP", "faint", "RIGHT")
  y = y + 26
  for _, row in ipairs(b and b.rows or {}) do
    if row.status == "ok" then
      local name = row.isSelf and "You" or tostring(row.name)
      local fs = placeText(pools.small, parent, x, y + 2, 80, name, row.isSelf and "goldLight" or "text")
      local nw = math.min(80, textWidth(fs, 60))
      if row.crossed then
        local strike = Kit.take(pools.lines, parent)
        strike:SetPoint("TOPLEFT", x, -(y + 9))
        strike:SetWidth(nw)
      end
      if row.crown then placeText(pools.tiny, parent, x + nw + 3, y + 3, 40, "crown", "goldLight") end
      local bx = x + 112
      local pvpShown = false
      for i, cell in ipairs(row.cells) do
        local track = trackOf(cell.id)
        if track == "pvp" and row.virgin then
          if not pvpShown then placeText(pools.tiny, parent, bx + (i - 1) * 15, y + 3, 70, "PvP Virgin", "faint") end
          pvpShown = true
        else
          boxAt(parent, bx + (i - 1) * 15, y + 3, 12, 12, cell.done and track or "track")
        end
      end
      placeText(pools.small, parent, x, y + 2, width, string.format("%d \194\183 %d", row.today.pve or 0,
        row.today.pvp or 0), "muted", "RIGHT")
      y = y + 22
    end
  end
  return y
end

local function today(parent, state, width)
  local goals = ns.DoomsdayView.rows(state.today, state.progress, state.hunts)
  local duelDone = #state.duels.done > 0
  local done, total = ns.DoomsdayView.doneCount(goals, duelDone) -- CF-61: the Duel slot counts
  local points = ns.DoomsdayView.todayPoints(state)
  local leftWidth = width - SIDE_WIDTH - 24
  local title = total > 0 and done == total and "Doomsday done. Go touch grass."
    or string.format("Today \194\183 %s \194\183 %d of %d done", state.label, done, total)
  local y = header(parent, title, 0, width, newGoals(state), "warning")
  -- The ⓘ after the title holds what "swapped" means.
  local titleHolder = pools.day.items[pools.day.used]
  infoAt(parent, PAD + math.min(leftWidth - 20, textWidth(titleHolder, 300)) + 8, 16, SWAP_TIP)
  local top = y
  for _, g in ipairs(goals) do
    local track, p = ns.Doomsday.goalPoints(g.id)
    g.track = g.id == "hunt" and "pvp" or track or trackOf(g.id)
    g.points = p and ("+" .. p) or ""
    y = y + todayRow(parent, g, y, leftWidth)
  end
  -- The Duel slot: done after the first duel; points earned today; details on hover.
  local duelPoints, parts = 0, {}
  for _, d in ipairs(state.duels.done) do
    parts[#parts + 1] = ns.DoomsdayView.duelText(d)
    if not d.disputed then
      duelPoints = duelPoints + (d.won and ns.Doomsday.POINTS.duelWin or ns.Doomsday.POINTS.duelLoss)
    end
  end
  local tip = DUEL_TIP
  if #parts > 0 then tip = table.concat(parts, "\n") .. "\n" .. tip end
  if #state.duels.open > 0 then tip = tip .. "\nOpen: " .. table.concat(state.duels.open, ", ") end
  local friends = #state.duels.done + #state.duels.open
  y = y + todayRow(parent, { kind = "Duel", track = "pvp", text = "First duel with each friend", done = duelDone,
    value = #state.duels.done, target = math.max(friends, 1),
    fraction = friends > 0 and #state.duels.done / friends or 0,
    points = duelPoints > 0 and ("+" .. duelPoints) or "", tip = tip }, y, leftWidth)
  y = y + 12
  y = y + statBoxes(parent, state, points, y, leftWidth - 2 * PAD, ns.DoomsdayView.killSummary(state.dayScored))
  local side = friendsToday(parent, width - PAD - SIDE_WIDTH, top + 8, SIDE_WIDTH)
  return math.max(y, side) + 16
end

local function week(parent, state, width)
  local rows = ns.DoomsdayView.rows(state.thisWeek, state.weekProgress)
  local y = header(parent, "This week", 0, width, weekResets(state))
  for _, row in ipairs(rows) do
    y = y + goalRow(parent, row, y, width)
    local needed = not row.done and ns.DoomsdayView.stillNeeded(row.id, state.weekScored, state.factions)
    if needed then
      placeText(pools.small, parent, PAD + KIND_WIDTH, y - 6, width - 2 * PAD - KIND_WIDTH,
        "Still needed for the bounty: " .. needed, "muted")
      y = y + 18
    end
  end
  y = y + 8
  y = y + textLine(parent, dim("This week  ") .. gold(string.format("PvE %d", state.points.pve)) .. dim("  \194\183  ")
    .. gold(string.format("PvP %d", state.points.pvp)), y, width, "goldLight", pools.body)
  y = y + textLine(parent, "PER CHARACTER", y + 6, width, "faint", pools.tiny) + 4
  for _, c in ipairs(state.chars) do
    local name = Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(c.name) .. "|r"
    y = y + textLine(parent, name .. dim(string.format("  %s \194\183 PvP %d", tostring(c.level or "?"), c.pvp)), y,
      width, "text")
  end
  y = y + textLine(parent, string.format("Streak %d %s \194\183 best %d", state.streak,
    state.streak == 1 and "day" or "days", state.best), y + 6, width)
  return y + 12
end

-- ===== Board, Ladder, Feats (CF-57b) =====

local NAME_WIDTH = 170
local POINTS_WIDTH = 110

local function points(p) return string.format("PvE %d \194\183 PvP %d", p.pve or 0, p.pvp or 0) end

-- CF-63: a goal on the Board: the goal box, its details in the tooltip.
local function cellTip(cell, row)
  local progress = row.isSelf and cell.target and string.format("%d/%d", cell.value or 0, cell.target) or nil
  return goalTip(ns.DoomsdayView.goalText(cell.id), cell.instead, cell.done, cell.at, progress,
    not row.isSelf and row.name or nil)
end

local function hover(parent, x, y, w, tip)
  local h = Kit.take(pools.hovers, parent)
  h:SetPoint("TOPLEFT", x, -(y + 2))
  h:SetSize(w, 20)
  h.tip = tip
end

-- CF-61c (Nico, 2026-10-29; board DD08AddonBoard): the friend's name, struck through with the finish time when all
-- three PvE dailies are done, and the crown; a goal box per goal (CF-63: a blue corner for a swap); one points column.
-- The streak, progress, times and swaps are in the tooltips.
local function board(parent, width)
  local b = ns.DoomsdayBoard.board()
  local y = header(parent, "Today \194\183 " .. b.label, 0, width, newGoals(ns.DoomsdayTracker.state()))
  local cols = math.max(1, #b.columns)
  local colWidth = math.floor((width - 2 * PAD - NAME_WIDTH - POINTS_WIDTH) / cols)
  local function colX(i) return PAD + NAME_WIDTH + (i - 1) * colWidth end
  -- Column labels.
  placeText(pools.tiny, parent, PAD, y + 4, NAME_WIDTH, "FRIEND", "faint")
  for i, c in ipairs(b.columns) do
    placeText(pools.tiny, parent, colX(i), y + 4, colWidth - 6, c.short:upper(), "faint")
  end
  placeText(pools.tiny, parent, colX(cols + 1), y + 4, POINTS_WIDTH, "POINTS", "faint")
  y = y + 24
  for _, row in ipairs(b.rows) do
    local name = row.isSelf and (row.name .. " (you)") or row.name
    local fs = placeText(pools.body, parent, PAD, y + 4, NAME_WIDTH - 6, name, row.isSelf and "goldLight" or "text")
    local nameWidth = math.min(NAME_WIDTH - 6, fs and fs.text and fs.text.GetStringWidth and fs.text:GetStringWidth()
      or 60)
    local after = (row.finishedAt and clock(row.finishedAt) or "") .. (row.crown and "  crown" or "")
    if after ~= "" then
      placeText(pools.small, parent, PAD + nameWidth + 6, y + 6, NAME_WIDTH - nameWidth - 6, gold(after), "goldLight")
    end
    if row.crossed then
      local strike = Kit.take(pools.lines, parent)
      strike:SetPoint("TOPLEFT", PAD, -(y + 12))
      strike:SetWidth(nameWidth)
    end
    local tip = string.format("Streak %d %s", row.streak or 0, (row.streak or 0) == 1 and "day" or "days")
    if row.crossed then tip = tip .. "\nAll three PvE dailies done at " .. clock(row.finishedAt) end
    hover(parent, PAD, y, NAME_WIDTH - 6, tip)
    if row.status ~= "ok" then
      placeText(pools.small, parent, colX(1), y + 6, colWidth * cols, "no Doomsday data yet", "faint")
    else
      for i, cell in ipairs(row.cells) do
        -- CF-63 (board CF63DoomBoard): the 15 px box, centred in its column, no text characters.
        local gb = Kit.take(pools.checks, parent)
        gb:SetPoint("TOPLEFT", colX(i) + math.floor((colWidth - 6 - Kit.GOAL_BOX) / 2), -(y + 6))
        gb:SetGoal(cell.done, cell.instead ~= nil)
        gb.tip = cellTip(cell, row)
      end
    end
    placeText(pools.small, parent, colX(cols + 1), y + 6, POINTS_WIDTH, points(row.today), "muted")
    y = y + 28
  end
  return y + 12
end

local function ladderSection(parent, width, y, title, track, rows, ladder)
  y = y + textLine(parent, title, y + 6, width, "goldLight", pools.day) + 6
  if #rows == 0 then return y + textLine(parent, "Nobody yet.", y, width, "faint") end
  for _, r in ipairs(rows) do
    local person = ladder.people[r.friend] or {}
    local move = ns.DoomsdayView.moveText(r.move, Theme.bundledFonts())
    local key = track .. ":" .. tostring(r.friend)
    local b = Kit.take(pools.rows, parent)
    b:SetPoint("TOPLEFT", PAD, -y)
    b:SetSize(width - 2 * PAD, 24)
    b:SetScript("OnClick", function()
      expanded[key] = not expanded[key] or nil
      if helpers then helpers.render() end
    end)
    placeText(pools.body, parent, PAD, y + 4, 30, tostring(r.rank), "faint")
    placeText(pools.body, parent, PAD + 30, y + 4, 200, tostring(person.name or r.friend)
      .. (person.isSelf and dim(" (you)") or ""), person.isSelf and "goldLight" or "text")
    placeText(pools.body, parent, PAD + 240, y + 4, 60, tostring(r.points), "goldLight", "RIGHT")
    placeText(pools.small, parent, PAD + 310, y + 6, 60, move, "muted")
    y = y + 26
    if expanded[key] then
      for guid, c in pairs(person.chars or {}) do
        if track == "pvp" and person.perChar and person.perChar[guid] or track == "pve" then
          local name = Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(c.name) .. "|r"
          local value = track == "pvp" and string.format("  PvP %d", person.perChar[guid] or 0)
            or string.format("  level %s", tostring(c.level or "?"))
          y = y + textLine(parent, "    " .. name .. dim(value), y, width, "text")
        end
      end
    end
  end
  return y
end

local function ladder(parent, width)
  local l = ns.DoomsdayBoard.ladder()
  local state = ns.DoomsdayTracker.state()
  local y = header(parent, "This week", 0, width, weekResets(state))
  y = ladderSection(parent, width, y, "PvE", "pve", l.pve, l)
  y = ladderSection(parent, width, y + 8, "PvP", "pvp", l.pvp, l)
  for _, key in ipairs(l.virgins) do
    local person = l.people[key] or {}
    y = y + textLine(parent, tostring(person.name or key) .. dim("  PvP Virgin \194\183 not ranked"), y, width, "muted")
  end
  -- Your PvP this week: rank and title, kills, duels, battlegrounds.
  local me = l.me
  if me then
    y = y + textLine(parent, "YOUR PVP", y + 10, width, "faint", pools.tiny) + 8
    local best
    for _, c in pairs(me.chars or {}) do
      if c.pvp and c.pvp.rank and (not best or c.pvp.rank > best.pvp.rank) then best = c end
    end
    local virgin = false
    for _, key in ipairs(l.virgins) do virgin = virgin or key == me.key end
    local rank = best and ns.Pvp.rankText(best.pvp, best.faction, virgin)
    if rank then y = y + textLine(parent, rank, y, width, "goldLight") end
    local zone = ns.DoomsdayView.topZone(me.killsByZone)
    local kills = string.format("%d kills this week", me.kills) .. (zone and (" \194\183 most in " .. zone) or "")
    y = y + textLine(parent, kills, y, width)
    y = y + textLine(parent, string.format("Duels %d\226\128\147%d", me.duels.won, me.duels.lost), y, width)
    local names = {}
    for name in pairs(me.bg) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local bg = me.bg[name]
      local text = string.format("%s %d\226\128\147%d \194\183 %d points", name, bg.won, bg.lost, bg.points)
      y = y + textLine(parent, text, y, width)
    end
  end
  return y + 12
end

local function feats(parent, width)
  local y = header(parent, "Feats \194\183 your characters", 0, width)
  for _, c in ipairs(ns.DoomsdayBoard.feats()) do
    local name = Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(c.name) .. "|r"
    local earned, earlier = ns.Feats.split(c.feats)
    local count = string.format("  \194\183 %d %s", #earned, #earned == 1 and "feat" or "feats")
    y = y + textLine(parent, name .. dim(count), y + 6, width, "text", pools.body) + 4
    -- CF-61: only feats earned while the addon watched; what the character already had folds into one line.
    for _, f in ipairs(earned) do
      local when = date and date("%d %b", f.at) or ""
      local detail = string.format("  \194\183 %s%s", f.detail and (f.detail .. " \194\183 ") or "", when)
      y = y + textLine(parent, gold(f.title) .. dim(detail), y, width, "text")
    end
    if #earlier > 0 then
      local titles, tips = {}, {}
      for _, f in ipairs(earlier) do
        titles[#titles + 1] = f.title
        tips[#tips + 1] = f.title .. (f.detail and (" \194\183 " .. f.detail) or "")
      end
      placeText(pools.small, parent, PAD, y, width - 2 * PAD, dim("Already had: " .. table.concat(titles, ", ")),
        "textDim")
      hover(parent, PAD, y - 2, width - 2 * PAD, table.concat(tips, "\n"))
      y = y + 22
    end
    local nextTitle, progress = ns.Feats.nextKills(c.pvp and c.pvp.hk)
    if nextTitle and (c.pvp and c.pvp.hk or 0) > 0 then
      y = y + textLine(parent, nextTitle .. "  \194\183 " .. progress, y, width, "faint")
    end
    y = y + 8
  end
  return y + 12
end

-- ===== Public =====

function DoomsdayTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)
  chipsBar = CreateFrame("Frame", nil, root)
  chipsBar:SetPoint("TOPLEFT", PAD, -14)
  chipsBar:SetPoint("TOPRIGHT", -PAD, -14)
  chipsBar:SetHeight(24)
  chips = {}
  local previous
  for _, def in ipairs(DoomsdayTab.VIEWS) do
    local c = Kit.chip(chipsBar, def, DoomsdayTab.select, 54)
    if previous then c:SetPoint("LEFT", previous, "RIGHT", 6, 0) else c:SetPoint("LEFT") end
    chips[def.value] = c
    previous = c
  end
  scroll = Kit.scrollArea(root)
  scroll:SetPoint("TOPLEFT", chipsBar, "BOTTOMLEFT", -PAD, -4)
  scroll:SetPoint("BOTTOMRIGHT", 0, 4)
  pools = {
    day = Kit.pool(Kit.textHolder("day")), body = Kit.pool(Kit.textHolder("body")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    lines = Kit.pool(line), bars = Kit.pool(bar), hovers = Kit.pool(hoverArea),
    checks = Kit.pool(goalBox), frames = Kit.pool(frameBox), infos = Kit.pool(Kit.info), -- CF-62
    rows = Kit.pool(function(p) return CreateFrame("Button", nil, p) end), -- CF-57b: Ladder rows to expand
  }
  return root
end

function DoomsdayTab.show() if root then root:Show() end end
function DoomsdayTab.hide() if root then root:Hide() end end

function DoomsdayTab.select(value)
  current = value
  if helpers then helpers.render() end
end

function DoomsdayTab.current() return current end

-- Draws the tab. empty: the window's empty-state text or nil.
function DoomsdayTab.render(_, empty)
  if not root then return end
  for value, c in pairs(chips) do c:SetActive(value == current) end
  for _, p in pairs(pools) do Kit.release(p) end
  local parent = scroll.child
  local width = math.max(400, scroll:GetWidth() or 0)
  local state = not empty and ns.DoomsdayTracker.state() or nil
  dayStartAt = state and (current == "today" or current == "board") and state.dayStart or nil
  local y
  if empty then
    placeText(pools.body, parent, PAD, 14, width - 2 * PAD, empty, "textDim")
    y = 40
  elseif not state then
    placeText(pools.body, parent, PAD, 14, width - 2 * PAD, "Doomsday is not ready yet.", "textDim")
    y = 40
  elseif current == "week" then
    y = week(parent, state, width)
  elseif current == "board" then
    y = board(parent, width)
  elseif current == "ladder" then
    y = ladder(parent, width)
  elseif current == "feats" then
    y = feats(parent, width)
  else
    y = today(parent, state, width)
  end
  parent:SetHeight(y + 10)
  scroll:Update()
end

-- For the specs: every visible text, the chips.
local TEXT_POOLS = { "day", "body", "small", "tiny" }

function DoomsdayTab.texts()
  local out = {}
  for _, name in ipairs(pools and TEXT_POOLS or {}) do
    local p = pools[name]
    for i = 1, p.used do
      local text = p.items[i].text and p.items[i].text:GetText()
      if text and text ~= "" then out[#out + 1] = text end
    end
  end
  return out
end

-- For the specs: the hover tooltips on the current view.
function DoomsdayTab.tips()
  local out = {}
  for _, name in ipairs({ "hovers", "infos", "checks" }) do -- CF-62: the ⓘ icons too; CF-63: the goal boxes
    for i = 1, pools and pools[name].used or 0 do out[#out + 1] = pools[name].items[i].tip end
  end
  return out
end

-- CF-63, for the specs: the goal boxes shown (Today and the Board), in order.
function DoomsdayTab.goalBoxes()
  local out = {}
  for i = 1, pools and pools.checks.used or 0 do out[i] = pools.checks.items[i] end
  return out
end

function DoomsdayTab.chips() return chips end
function DoomsdayTab.reset()
  current = "today"
  expanded = {}
end

ns.DoomsdayTab = DoomsdayTab
return DoomsdayTab
