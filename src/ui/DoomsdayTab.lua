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

-- "10:42" in your own clock.
local function clock(at)
  if not at or not date then return "" end
  return date("%H:%M", at)
end

local function check() return Theme.bundledFonts() and "\226\156\147" or "done" end

-- CF-61: "New goals in 5 h 58 m" (Today, Board) and "Week resets Sun 19:00 · in 3 d 5 h" (Week, Ladder).
local function newGoals(state) return "New goals in " .. ns.DoomsdayView.until_(state.resetsIn) end
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

local function header(parent, text, y, width, right)
  placeText(pools.day, parent, PAD, y + 12, width - 2 * PAD, text, "goldLight")
  if right then placeText(pools.small, parent, PAD, y + 15, width - 2 * PAD, right, "faint", "RIGHT") end
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

local function today(parent, state, width)
  local rows = ns.DoomsdayView.rows(state.today, state.progress, state.hunts)
  local done, total = ns.DoomsdayView.doneCount(rows)
  local points = ns.DoomsdayView.todayPoints(state)
  local y = 0
  if total > 0 and done == total then
    y = y + header(parent, "Doomsday done. Go touch grass.", y, width, newGoals(state))
    y = y + textLine(parent, string.format("All %d goals \194\183 PvE %d \194\183 PvP %d \194\183 streak %d", total,
      points.pve, points.pvp, state.streak), y + 4, width, "goldLight")
  else
    local title = string.format("Today \194\183 %s \194\183 %d of %d done", state.label, done, total)
    y = y + header(parent, title, y, width, newGoals(state))
  end
  for _, row in ipairs(rows) do y = y + goalRow(parent, row, y, width) end
  -- The Duel slot: not a goal (never counts for crossing out or the streak).
  placeText(pools.tiny, parent, PAD, y + 8, KIND_WIDTH - 8, "DUEL", "faint")
  placeText(pools.body, parent, PAD + KIND_WIDTH, y + 6, width - 2 * PAD - KIND_WIDTH, "First duel with each friend",
    "text")
  local parts = {}
  for _, d in ipairs(state.duels.done) do parts[#parts + 1] = ns.DoomsdayView.duelText(d) end
  local duelText = #parts > 0 and table.concat(parts, " \194\183 ") or "no duel yet"
  if #state.duels.open > 0 then
    duelText = duelText .. dim("  \194\183 open: " .. table.concat(state.duels.open, ", "))
  end
  placeText(pools.small, parent, PAD + KIND_WIDTH, y + 26, width - 2 * PAD - KIND_WIDTH, duelText, "muted")
  y = y + 48
  y = y + 8
  y = y + textLine(parent, gold(string.format("PvE %d", points.pve)) .. dim("  \194\183  ")
    .. gold(string.format("PvP %d", points.pvp)), y, width, "goldLight", pools.body)
  local kills = ns.DoomsdayView.killSummary(state.dayScored)
  if kills then y = y + textLine(parent, kills, y, width) end
  y = y + textLine(parent, string.format("Streak %d %s \194\183 best %d", state.streak,
    state.streak == 1 and "day" or "days", state.best), y, width)
  if state.crown then
    y = y + textLine(parent, gold(state.crown.mine and "You" or state.crown.name)
      .. dim(" finished all dailies first, " .. clock(state.crown.at)), y, width)
  end
  return y + 12
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

-- CF-61: a goal on the Board: a gold check when done, an empty box when not (the details are in the tooltip).
local function box() return Theme.bundledFonts() and "\226\150\161" or "o" end

local function cellTip(cell, isSelf)
  local lines = { ns.DoomsdayView.goalText(cell.id) }
  if cell.done then
    lines[#lines + 1] = "Done at " .. clock(cell.at)
  elseif isSelf and cell.target then
    lines[#lines + 1] = string.format("%d/%d", cell.value or 0, cell.target)
  else
    lines[#lines + 1] = "Not done yet"
  end
  if cell.instead then lines[#lines + 1] = "Instead of: " .. cell.instead end
  return table.concat(lines, "\n")
end

local function hover(parent, x, y, w, tip)
  local h = Kit.take(pools.hovers, parent)
  h:SetPoint("TOPLEFT", x, -(y + 2))
  h:SetSize(w, 20)
  h.tip = tip
end

-- CF-61c (Nico, 2026-10-29; board DD08AddonBoard): the friend's name, struck through with the finish time when all
-- three PvE dailies are done, and the crown; a check or a box per goal with a dot for a swap; one points column.
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
        local mark = cell.done and gold(check()) or dim(box())
        if cell.instead then mark = mark .. dim(" \194\183") end -- the swap
        placeText(pools.small, parent, colX(i), y + 6, colWidth - 6, mark, "muted")
        hover(parent, colX(i), y, colWidth - 6, cellTip(cell, row.isSelf))
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
    local rank = best and ns.Pvp.rankText(best.pvp, best.faction)
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
  for i = 1, pools and pools.hovers.used or 0 do out[#out + 1] = pools.hovers.items[i].tip end
  return out
end

function DoomsdayTab.chips() return chips end
function DoomsdayTab.reset()
  current = "today"
  expanded = {}
end

ns.DoomsdayTab = DoomsdayTab
return DoomsdayTab
