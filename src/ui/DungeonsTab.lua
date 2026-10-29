-- DungeonsTab: the Dungeons tab in the revamp's look (CF-42; design docs/design/runs-2026-10/dungeons-runs.html;
-- the planner itself is CF-24, planned runs CF-46). Left: the planned runs (from the website through the
-- uploader, or a friend's addon), then the dungeons in range of the character you are on. Right: a run with
-- its five slots, who answered where, who is close in level and the link to edit it on the website; or a
-- dungeon with its suggested group, your alternatives, asking who's up for it (CF-27), the others in range
-- and its quests. Native frames from the kit, drawn from pools.
local _, ns = ...

local DungeonsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20
local ROW = 28 -- CF-63c: one line per dungeon
local SLOT_HEIGHT = 100
-- CF-47: waiting for the next save and upload (CF-63: the tooltip of a clock icon)
local PENDING = "Saved. Reaches the website with your next upload." -- CF-63 board CF63Answer
local SOURCE_WORDS = { site = "planned on the website", discord = "planned on Discord", game = "planned in game" }
local DOT = " \194\183 "
local ASK_TIP = "Whispers online friends who fit; can post on Discord too. Waits until combat ends." -- CF-61
-- CF-62 (board AG02Dungeons): sizes and the explanations that live in tooltips.
local LIST_WIDTH = 290
local RUN_ROW = 50
local GROUP_ROW = 36
local ONLINE_ROW = 30
local LINK_WIDTH = 236 -- CF-63: Edit or cancel / On the website
local ROLE_LABEL = { tank = "Tank", heal = "Healer", dps = "Damage" }
local ROSTER_TIP = "Online members whose current character fits %s." -- CF-63 board CF63RunDetail
local SUGGEST_TIP = "Friends\226\128\153 and your characters whose level fits, online or not." -- CF-63c
local RUNS_TIP = "Runs from the website. Type /reload after an upload for newer."
local LINK_TIP = "Copy with Ctrl+C. Edit or cancel happens on the website."
local INVITE_TIP = "Invite all invites everyone who is in and online."
local RANGE_TIP = "Ranges are typical levels; the list follows the character you're on."
local root, list, detail
local helpers -- from MainFrame: settings(), render(), print(text)
local entries = {} -- row value -> overview entry, or { run = run } for "run:<id>"
local rows = {}    -- visible list rows: { value, frame }
local pools
local linkBox -- the run's website link to copy
local ticking -- CF-63: the minute ticker runs
local askForRun, memberMenu, openSlotMenu -- CF-63b, defined with renderRun
-- CF-63c (board CF63List): the filter chip ("all" again when the window closes), the character "In range for"
-- follows (nil: the one you are on; not saved, so back to it at each login) and Show all dungeons.
local filter, rangeGuid, showAll = "all", nil, false
local rangeOptions = {} -- your characters for the In range dropdown (from the last draw)

-- ===== Helpers =====

local function status()
  local s = helpers.settings()
  s.dungeonTree = s.dungeonTree or {} -- the keys the AceGUI tree used (rule 8): selected
  return s.dungeonTree
end

local function now() return GetServerTime() end

local function colored(text, colorName) return Theme.code(colorName) .. tostring(text) .. "|r" end

local function classColored(c, text)
  return Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(text or c.name) .. "|r"
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- "17–24" with the bundled font; the game font has no en dash.
local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

-- Local times need the game's date (V63); without it, nothing is shown rather than a wrong time.
local function when(at)
  if not date then return "" end
  return ns.PlannedRuns.whenText(at, now(), date)
end

local function clock(at)
  if not date then return "" end
  return ns.PlannedRuns.clock(at, date)
end

local function dungeonOf(run) return ns.Dungeons.get(run.dungeon) end

local function dungeonName(run) return ns.Dungeons.runName(run) end -- CF-63: never the raw id

-- The BattleTag's name part (before "#"), as display names fall back to (ARCHITECTURE "Data model").
local function tagName(battleTag)
  return type(battleTag) == "string" and battleTag:match("^([^#]+)") or nil
end

-- A person on a run as the addon knows them: "you", their display name, or what the site sent.
local function personName(p, candidates, me)
  if not p then return nil end
  if (p.guid and me.guids[p.guid]) or (p.battleTag and p.battleTag == me.battleTag) then return "you" end
  for _, c in ipairs(candidates) do
    if p.guid and c.guid == p.guid then return c.displayName or c.name end
  end
  return tagName(p.battleTag) or p.name
end

local function organiserText(run, candidates, me)
  if ns.PlannedRuns.isOrganiser(run, me) then return "you organise" end
  return personName(run.organiser, candidates, me) or ""
end

local function countsText(run)
  local yes, maybe = ns.PlannedRuns.counts(run)
  local text = yes .. " in"
  if maybe > 0 then text = text .. DOT .. maybe .. " maybe" end
  return text
end

-- Every dungeon's area IDs, to read QuestieDB once for all of them.
local function allAreaIds()
  local ids = {}
  for _, d in ipairs(ns.Dungeons.LIST) do
    for _, id in ipairs(d.areaIds) do ids[#ids + 1] = id end
  end
  return ids
end

-- The dungeon's quests for your character in the suggested group (CF-24 feedback): QuestieDB when it
-- is installed, else what people in range have in their logs. Completed quests are known only for
-- the character you are on.
local function questInfo(entry)
  local own
  for _, c in ipairs(ns.Dungeons.suggest(entry)) do
    if c.own then own = c end
  end
  local me = ns.SelfInfo.read()
  local data = ns.QuestieData.dungeonQuests(allAreaIds())
  local completed
  if data and own and own.guid == me.guid then
    local ids = {}
    for _, areaId in ipairs(entry.dungeon.areaIds) do
      for _, q in ipairs(data[areaId] or {}) do ids[#ids + 1] = q.id end
    end
    completed = ns.QuestieData.completed(ids)
  end
  return ns.Dungeons.quests(entry.dungeon, data, { char = own, candidates = entry.candidates,
    factionMask = data and ns.QuestieData.factionMask(me.faction), completed = completed })
end

-- ===== Factories =====

local function listRow(parent)
  local r = Kit.listRow(parent)
  r:SetHeight(ROW)
  r.name = Theme.text(r, "body", "text")
  r.name:SetPoint("LEFT", 12, 0)
  r.right = Theme.text(r, "small", "muted")
  r.right:SetPoint("RIGHT", -12, 0)
  r.meta = Theme.text(r, "tiny", "muted") -- unused since CF-63c (board CF63List: one line per dungeon)
  r.meta:Hide()
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- CF-63c: a filter chip: a thin border, gold when on (was PlanInline's, which CF-64 removed).
local function chip(parent)
  local c = CreateFrame("Button", nil, parent)
  c:SetHeight(28)
  c.bg = Theme.fill(c, "gold", "BACKGROUND")
  c.bg:SetAllPoints()
  c.edges = Kit.edges(c, "divider")
  c.text = Theme.text(c, "small", "textDim")
  c.text:SetPoint("CENTER")
  local hover = c:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  function c:SetChip(label, on)
    self.text:SetText(label)
    self.text:SetTextColor(Theme.color(on and "goldPale" or "textDim"))
    self.bg:SetAlpha(on and 0.14 or 0)
    for _, e in ipairs(self.edges) do e:SetColorTexture(Theme.color(on and "gold" or "divider")) end
    self.on = on
    self:SetWidth(math.ceil(self.text:GetStringWidth() or 60) + 20)
  end
  return c
end

-- CF-63c: a check box with its label (Show all dungeons).
local function checkRow(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.box = CreateFrame("Frame", nil, b)
  b.box:SetSize(13, 13)
  b.box:SetPoint("LEFT", 0, 0)
  local bg = Theme.fill(b.box, "input", "BACKGROUND")
  bg:SetAllPoints()
  b.box.edges = Kit.edges(b.box, "border")
  b.check = b.box:CreateTexture(nil, "ARTWORK")
  b.check:SetPoint("TOPLEFT", 1, -1)
  b.check:SetPoint("BOTTOMRIGHT", -1, 1)
  b.check:SetTexture(Theme.TEXTURES.check)
  b.check:SetVertexColor(Theme.color("gold"))
  b.text = Theme.text(b, "small", "textDim")
  b.text:SetPoint("LEFT", 19, 0)
  function b:SetCheck(label, on)
    self.text:SetText(label)
    self.checked = on and true or false
    self.check:SetShown(self.checked)
    self:SetWidth(19 + math.ceil(self.text:GetStringWidth() or 100))
  end
  return b
end

-- CF-62: a run row (50 px): the short name and the time; five role pips, "2 in · 1 maybe", the organiser.
local function runRow(parent)
  local r = Kit.listRow(parent)
  r:SetHeight(RUN_ROW)
  r.name = Theme.text(r, "group", "goldLight")
  r.name:SetPoint("TOPLEFT", 12, -8)
  r.right = Theme.text(r, "small", "textDim")
  r.right:SetPoint("TOPRIGHT", -12, -9)
  r.pips = {}
  for i = 1, 5 do
    local p = r:CreateTexture(nil, "ARTWORK")
    p:SetSize(14, 6)
    p:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 17, 12)
    r.pips[i] = p
  end
  r.meta = Theme.text(r, "tiny", "muted")
  r.meta:SetPoint("BOTTOMLEFT", 12 + 5 * 17 + 6, 9)
  r.who = Theme.text(r, "tiny", "muted")
  r.who:SetPoint("BOTTOMRIGHT", -12, 9)
  r:SetScript("OnEnter", function(self) -- CF-63: the full name when the row shows a short one
    if not (self.fullName and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.fullName, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(self) if self.fullName and GameTooltip then GameTooltip:Hide() end end)
  r.clock = Kit.clock(r) -- CF-63: waits for the next upload
  r.clock:SetPoint("LEFT", r.meta, "RIGHT", 6, 0)
  r.clock.tip = PENDING
  r.clock:Hide()
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- CF-62: a run's group row (CF-63 board CF63RunDetail: 36 px): role icon, class icon, the full name,
-- "level · friend", then "online" and the status, right-aligned in a 64 px column.
local STATUS_WIDTH = 64
local function groupRow(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetHeight(GROUP_ROW)
  g.bg = Theme.fill(g, "white", "BACKGROUND")
  g.bg:SetAllPoints()
  g.edges = Kit.edges(g, "divider")
  g.role = Kit.roleIcon(g, 20)
  g.role:SetPoint("LEFT", 10, 0)
  g.portrait = Kit.portrait(g, 22)
  g.portrait:SetPoint("LEFT", 36, 0)
  g.name = Theme.text(g, "body", "text")
  g.name:SetPoint("LEFT", 66, 0)
  g.info = Theme.text(g, "small", "muted")
  g.info:SetPoint("LEFT", g.name, "RIGHT", 8, 0)
  g.status = Theme.text(g, "small", "muted")
  g.status:SetPoint("RIGHT", -10, 0)
  g.status:SetJustifyH("RIGHT")
  g.online = Theme.text(g, "small", "online")
  g.online:SetPoint("RIGHT", g.status, "LEFT", -8, 0)
  for _, fs in ipairs({ g.name, g.info, g.status, g.online }) do
    if fs.SetWordWrap then fs:SetWordWrap(false) end -- CF-63: cut with "...", never a second line
  end
  g:EnableMouse(true)
  -- CF-63b: the hover tooltip, its first line the name (tipLines), or one text (tip).
  g:SetScript("OnEnter", function(self)
    if not GameTooltip or not (self.tip or self.tipLines) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.tipLines then
      GameTooltip:SetText(self.tipLines[1], nil, nil, nil, nil, true)
      for i = 2, #self.tipLines do GameTooltip:AddLine(self.tipLines[i], Theme.color("textDim")) end
    else
      GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self) if (self.tip or self.tipLines) and GameTooltip then GameTooltip:Hide() end end)
  g:SetScript("OnMouseUp", function(self, mouse)
    if self.menu and (mouse == "RightButton" or self.menuOnClick) then self.menu(self) end
  end)
  return g
end

-- CF-63: your own row has gold edges and a gold tint (board CF63RunDetail); the others the divider.
local function rowEdges(g, mine)
  for _, t in ipairs(g.edges) do
    t:SetColorTexture(Theme.color(mine and "gold" or "divider", mine and 0.7 or nil))
  end
end

-- CF-63: a group row's texts never run into each other: the status column is at least 64 px, "online" sits left of
-- it, the name gets what is left after a short info; what doesn't fit is cut ("...").
local function natural(fs)
  local t = fs:GetText()
  if not t or t == "" then return 0 end
  return math.ceil(fs:GetStringWidth() or 0) + 1
end

local function fitGroupRow(g, width)
  for _, fs in ipairs({ g.name, g.info, g.status, g.online }) do fs:SetWidth(0) end
  local statusW = math.max(STATUS_WIDTH, math.min(natural(g.status), math.floor(width * 0.4)))
  g.status:SetWidth(statusW)
  local onlineW = natural(g.online)
  local room = width - 66 - 10 - statusW - 12 - (onlineW > 0 and (onlineW + 8) or 0)
  local infoW = natural(g.info)
  local nameW = math.min(natural(g.name), math.max(80, room - math.min(infoW, 120) - 8))
  g.name:SetWidth(math.max(1, nameW))
  g.info:SetWidth(math.max(1, math.min(infoW, room - nameW - 8)))
end

-- CF-62: a row of "Online now, fits" (CF-63 board CF63RunDetail: one 30 px line): class icon, name, "level ·
-- friend", Whisper, and Invite from 15 minutes before the start.
local function onlineRow(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetHeight(ONLINE_ROW)
  o.line = Theme.fill(o, "divider", "BORDER")
  o.line:SetPoint("BOTTOMLEFT")
  o.line:SetPoint("BOTTOMRIGHT")
  o.line:SetHeight(1)
  o.portrait = Kit.portrait(o, 18)
  o.portrait:SetPoint("LEFT", 0, 0)
  o.name = Theme.text(o, "body", "text")
  o.name:SetPoint("LEFT", 26, 0)
  o.info = Theme.text(o, "small", "muted")
  o.info:SetPoint("LEFT", o.name, "RIGHT", 8, 0)
  o.invite = Kit.button(o, "Invite", nil)
  o.invite:SetPoint("RIGHT", 0, 0)
  if o.invite.SetMotionScriptsWhileDisabled then o.invite:SetMotionScriptsWhileDisabled(true) end
  o.button = Kit.button(o, "", nil)
  o.button:SetPoint("RIGHT", 0, 0)
  if o.button.SetMotionScriptsWhileDisabled then o.button:SetMotionScriptsWhileDisabled(true) end
  return o
end

-- A slot of a group: portrait (or "?" / "+" / an initial), name and level, role and who, a state line.
local function slotFrame(parent)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(SLOT_HEIGHT)
  local bg = s:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(Theme.color("white", 0.03))
  s.edges = Kit.edges(s, "divider")
  s.portrait = Kit.portrait(s, 26)
  s.portrait:SetPoint("TOP", 0, -9)
  s.mark = Theme.text(s, "body", "faint")
  s.mark:SetPoint("CENTER", s.portrait)
  s.name = Theme.text(s, "small", "text")
  s.name:SetPoint("TOP", s.portrait, "BOTTOM", 0, -5)
  s.info = Theme.text(s, "tiny", "textDim")
  s.info:SetPoint("TOP", s.name, "BOTTOM", 0, -3)
  s.status = Theme.text(s, "tiny", "muted")
  s.status:SetPoint("TOP", s.info, "BOTTOM", 0, -3)
  return s
end

local function questRow(parent)
  local q = CreateFrame("Frame", nil, parent)
  q:SetHeight(24)
  q.check = q:CreateTexture(nil, "ARTWORK")
  q.check:SetSize(12, 12)
  q.check:SetPoint("LEFT", 2, 0)
  q.check:SetTexture(Theme.TEXTURES.check)
  q.check:SetVertexColor(Theme.color("online"))
  q.name = Theme.text(q, "small", "text")
  q.name:SetPoint("LEFT", 22, 0)
  q.name:SetJustifyH("LEFT")
  q.who = Theme.text(q, "tiny", "muted")
  q.who:SetPoint("RIGHT")
  local sep = q:CreateTexture(nil, "BORDER")
  sep:SetPoint("BOTTOMLEFT")
  sep:SetPoint("BOTTOMRIGHT")
  sep:SetHeight(1)
  sep:SetColorTexture(Theme.color("white", 0.05))
  return q
end

local function button(parent) return Kit.button(parent, "", nil) end
local function primary(parent) return Kit.button(parent, "", nil, "primary") end

-- ===== Drawing =====

local placeText = Kit.placeText

local function section(parent, x, y, width, text, note, noteColor)
  return Kit.section(pools.section, pools.small, parent, x, y, width, text, note, noteColor)
end

-- CF-63c: the In range dropdown: your characters "Name (level)"; picking one makes the list follow it.
local function rangeMenu(owner)
  local items = {}
  for i, c in ipairs(rangeOptions) do
    items[i] = { label = string.format("%s (%s)", tostring(c.name), tostring(c.level or "?")), enabled = true,
                 char = c }
  end
  ns.ContextMenu.open(owner, { items = items }, function(item)
    rangeGuid = item.char.guid
    status().selected = nil
    helpers.render()
  end)
end

-- rangeChar: the character "In range for" follows ({ guid, name, level }).
local function renderList(runs, overview, me, candidates, rangeChar)
  Kit.release(pools.rows)
  Kit.release(pools.listText)
  Kit.release(pools.runRows)
  Kit.release(pools.listTitle)
  Kit.release(pools.listButtons)
  Kit.release(pools.listInfos)
  Kit.release(pools.chips)
  Kit.release(pools.checks)
  Kit.release(pools.selects)
  rows = {}
  local parent = list.child
  local width = math.max(200, (list:GetWidth() or 0) - 6)
  local y = 4
  local selected = status().selected

  local function row(value, name, right, dim)
    local r = Kit.take(pools.rows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = value
    r.name:SetText(name)
    r.name:SetTextColor(Theme.color(value == selected and "goldLight" or (dim and "muted" or "text")))
    r.right:SetText(right or "")
    r:SetSelected(value == selected)
    rows[#rows + 1] = { value = value, frame = r }
    y = y + ROW
  end

  -- CF-62: "Dungeons" with Ask now…; CF-63c: the filter chips; the runs grouped Tonight, Tomorrow, This week,
  -- Later; role pips per row.
  placeText(pools.listTitle, parent, 12, y + 6, width - 24, "Dungeons", "goldLight") -- CF-62 (board AG05)
  local ask = Kit.take(pools.listButtons, parent)
  ask:SetLabel("Ask now\226\128\166")
  ask:SetEnabled(DungeonsTab.canAsk())
  ask:SetPoint("TOPRIGHT", parent, "TOPLEFT", width - 8, -(y + 4))
  ask:SetScript("OnClick", function() DungeonsTab.askNow() end)
  ask.tooltip = ASK_TIP
  y = y + 36
  local cx = 12
  for _, def in ipairs(ns.PlannedRuns.FILTERS) do
    local c = Kit.take(pools.chips, parent)
    c:SetChip(def.text, filter == def.value)
    c:SetHeight(24)
    c.value = def.value
    if cx + c:GetWidth() > width - 8 then
      cx = 12
      y = y + 29
    end
    c:SetPoint("TOPLEFT", cx, -y)
    c:SetScript("OnClick", function()
      filter = def.value
      helpers.render()
    end)
    cx = cx + c:GetWidth() + 5
  end
  y = y + 30
  local shown = ns.PlannedRuns.filterRuns(runs, filter, { me = me, candidates = candidates, dungeonOf = dungeonOf,
                                                           level = rangeChar.level })
  if #shown > 0 then
    placeText(pools.listText, parent, 14, y + 6, width - 24, "Planned", "textDim")
    y = y + 22
  end
  local lastBucket
  for _, run in ipairs(shown) do
    local bucket = date and ns.PlannedRuns.bucket(run.startsAt, now(), date) or ""
    if bucket ~= lastBucket then
      placeText(pools.listText, parent, 12, y + 8, width - 24, bucket, "faint")
      y = y + 26
      lastBucket = bucket
    end
    local r = Kit.take(pools.runRows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = "run:" .. run.id
    local full = dungeonName(run)
    r.name:SetText(ns.PlannedRuns.shortName(full))
    r.fullName = ns.PlannedRuns.shortName(full) ~= full and full or nil
    r.right:SetText(date and ns.PlannedRuns.rowTime(run.startsAt, now(), date) or "")
    local pipSlots = ns.PlannedRuns.slots(run, candidates, dungeonOf(run))
    for k, p in ipairs(r.pips) do
      local slot = pipSlots[k]
      if slot and slot.answer then
        p:SetColorTexture(Theme.color(slot.role or "dps"))
      else
        p:SetColorTexture(Theme.color("track"))
      end
    end
    r.meta:SetText(countsText(run))
    r.clock:SetShown(run.pending == true)
    local organiser = organiserText(run, candidates, me)
    r.who:SetText(organiser)
    r.who:SetTextColor(Theme.color(organiser == "you organise" and "goldLight" or "muted"))
    r:SetSelected(r.value == selected)
    rows[#rows + 1] = { value = r.value, frame = r }
    y = y + RUN_ROW
  end
  if #runs == 0 then
    placeText(pools.listText, parent, 12, y + 2, width - 24, "No runs planned", "text")
    placeText(pools.listText, parent, 12, y + 18, width - 24, "Plan one on the website, or ask who is up for "
      .. "something right now.", "muted")
    y = y + 40
  elseif #shown == 0 then
    placeText(pools.listText, parent, 14, y + 4, width - 24, "No runs here", "muted") -- CF-63c: a chip hides all
    y = y + 24
  end

  -- CF-63c (board CF63List): "In range for" with a dropdown of your characters, Show all dungeons; one line per
  -- dungeon, "17–24 · 3 fit"; with Show all, the others under "Other dungeons".
  y = y + 8
  local label = placeText(pools.listText, parent, 12, y + 6, 90, "In range for", "faint")
  local lw = label.text.GetStringWidth and label.text:GetStringWidth() or 70
  -- CF-64: a dropdown with a texture arrow (the fonts have no down-pointing triangle).
  local pick = Kit.take(pools.selects, parent)
  local choices = {}
  for i, c in ipairs(rangeOptions) do
    choices[i] = { value = c.guid, text = string.format("%s (%s)", tostring(c.name), tostring(c.level or "?")) }
  end
  if #choices == 0 then
    choices[1] = { value = rangeChar.guid,
                   text = string.format("%s (%s)", tostring(rangeChar.name), tostring(rangeChar.level or "?")) }
  end
  pick:SetChoices(nil, choices, rangeChar.guid)
  pick:SetHeight(24)
  pick:SetWidth(math.min(width - lw - 30, math.ceil(pick.text:GetStringWidth() or 120) + 40))
  pick:SetPoint("TOPLEFT", 12 + lw + 6, -(y + 1))
  pick.tooltip = RANGE_TIP
  y = y + 30
  local all = Kit.take(pools.checks, parent)
  all:SetCheck("Show all dungeons", showAll)
  all:SetPoint("TOPLEFT", 12, -y)
  all:SetScript("OnClick", function()
    showAll = not showAll
    helpers.render()
  end)
  y = y + 26
  local inRange, others = {}, {}
  for _, entry in ipairs(overview) do
    if entry.fits then inRange[#inRange + 1] = entry else others[#others + 1] = entry end
  end
  if #inRange == 0 then
    placeText(pools.listText, parent, 14, y + 4, width - 24, "No dungeon fits yet", "textDim")
    y = y + 26
  end
  for _, entry in ipairs(inRange) do
    row(entry.dungeon.id, entry.dungeon.name, range(entry.dungeon) .. DOT .. entry.people .. " fit")
  end
  if showAll and #others > 0 then
    placeText(pools.listText, parent, 14, y + 8, width - 24, "Other dungeons", "textDim")
    y = y + 26
    for _, entry in ipairs(others) do
      row(entry.dungeon.id, entry.dungeon.name, range(entry.dungeon) .. DOT .. entry.people .. " fit", true)
    end
  end
  -- CF-62: how old the runs are, one muted line at the bottom of the list.
  local data = ns.Planner.data()
  if data and date then
    local at = when(data.updatedAt):gsub("^Today ", "")
    local footer = placeText(pools.listText, parent, 12, y + 10, width - 40, "Runs from " .. at, "faint")
    local fw = footer.text.GetStringWidth and footer.text:GetStringWidth() or 120
    local info = Kit.take(pools.listInfos, parent)
    info:SetPoint("TOPLEFT", 12 + fw + 6, -(y + 9))
    info.tip = RUNS_TIP -- CF-63 board CF63RunDetail
    y = y + 34
  end
  y = y + 12
  parent:SetHeight(y)
  list:Update()
end

-- CF-27: ask friends who's up for it now, or how your ask stands.
local function askBlock(parent, entry, y, width)
  local ask = ns.GroupAsks.current()
  if ask and ask.dungeon.id == entry.dungeon.id then
    local s = ns.GroupAsk.summary(ask)
    local parts = {}
    if #s.join > 0 then parts[#parts + 1] = colored("joining: " .. table.concat(s.join, ", "), "onlineText") end
    if #s.later > 0 then parts[#parts + 1] = "later: " .. table.concat(s.later, ", ") end
    if #s.no > 0 then parts[#parts + 1] = colored("not now: " .. table.concat(s.no, ", "), "muted") end
    if #s.waiting > 0 then parts[#parts + 1] = colored("waiting: " .. table.concat(s.waiting, ", "), "muted") end
    placeText(pools.small, parent, PAD, y + 4, width, "Asked who's up for it" .. DOT .. table.concat(parts, DOT),
      "text")
    return y + 26
  end
  local ok, wait = ns.GroupAsks.canAsk()
  if not ok then
    placeText(pools.small, parent, PAD, y + 4, width, string.format("You can ask again in %d min.",
      math.ceil(wait / 60)), "muted")
    return y + 26
  end
  local b = Kit.take(pools.primary, parent)
  b:SetLabel("Ask now")
  b:SetEnabled(true)
  b:SetScript("OnClick", function() ns.RunDialogs.askNow(entry.dungeon) end) -- CF-47
  b:SetPoint("TOPLEFT", PAD, -y)
  b.tooltip = ASK_TIP -- CF-61: was a note next to the button
  return y + 36
end

local function clearDetail()
  for _, name in ipairs({ "name", "section", "small", "tiny", "slots", "quests", "buttons", "primary", "groupRows",
                          "onlineRows", "infos", "links", "clocks", "dividers" }) do
    Kit.release(pools[name])
  end
  linkBox:Hide()
  if ns.RunAnswer then ns.RunAnswer.hide() end
end

-- CF-62: who is online in the community and fits the run's range, not in its group (MemberTracker, re-drawn on
-- CLUB_MEMBER_PRESENCE_UPDATED and CLUB_MEMBER_UPDATED through MemberTracker.UPDATED).
local function onlineFits(dungeon, excluded, candidates)
  local friendOf = {}
  for _, c in ipairs(candidates) do
    if c.guid then friendOf[c.guid] = c.own and "you" or c.displayName end
  end
  local out = {}
  if not dungeon then return out end
  local myGuid = ns.SelfInfo.read().guid
  for guid, m in pairs(ns.MemberTracker.members()) do
    local online = m.presence and m.presence ~= 0 and m.presence ~= 3 -- Offline (0) and Away-offline (3) aside
    if online and guid ~= myGuid and not excluded[guid] and type(m.level) == "number"
        and m.level >= dungeon.min and m.level <= dungeon.max then
      -- CF-64: Classes.info returns the class file itself (it was read as a table, so no icon showed).
      local file = ns.Classes.info(nil, m.classID)
      out[#out + 1] = { guid = guid, name = m.name, level = m.level, zone = m.zone, friend = friendOf[guid],
                        classFile = file }
    end
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return out
end

-- CF-64: a character's class file for its icon: the candidate's, else its synced record's, else the community
-- roster's classID; nil when unknown (then no icon, not an empty ring).
local function classFor(guid, c)
  local file = c and (c.classFile or (c.classID and (ns.Classes.info(nil, c.classID))))
  if file or not guid then return file end
  local global = ns.db and ns.db.global
  local own = global and global.self and global.self.chars and global.self.chars[guid]
  if own and (own.classFile or own.classID) then return own.classFile or (ns.Classes.info(nil, own.classID)) end
  for _, person in pairs(global and global.people or {}) do
    local rec = type(person) == "table" and type(person.chars) == "table" and person.chars[guid]
    if type(rec) == "table" and (rec.classFile or rec.classID) then
      return rec.classFile or (ns.Classes.info(nil, rec.classID))
    end
  end
  local m = ns.MemberTracker.members()[guid]
  return m and m.classID and (ns.Classes.info(nil, m.classID)) or nil
end

-- Shows the class icon, or hides it when the class is unknown.
local function setPortrait(portrait, file, online)
  if file then
    portrait:Show()
    portrait:SetClass(file)
    portrait:SetOnline(online)
  else
    portrait:Hide()
  end
end

local function whisper(name)
  if ChatFrame_SendTell then
    pcall(ChatFrame_SendTell, name)
  elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
    pcall(ChatFrameUtil.OpenChat, "/w " .. name .. " ")
  end
end

-- CF-63: fills "Online now, fits" at x, y (width): its heading with an ⓘ, then a row per member, Whisper, and
-- Invite from 15 minutes before the start (open). Returns the new y.
local function onlineList(parent, x, y, width, fits, dungeon, open)
  local heading = placeText(pools.section, parent, x, y, width, "Online now, fits", "goldLight")
  local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 120
  local info = Kit.take(pools.infos, parent)
  info:SetPoint("TOPLEFT", x + hw + 6, -(y + 3))
  info.tip = dungeon and string.format(ROSTER_TIP, range(dungeon)) or nil
  y = y + 26
  if #fits == 0 then
    placeText(pools.small, parent, x, y + 4, width, "Nobody else online fits", "muted")
    return y + 26
  end
  local combat = InCombatLockdown and InCombatLockdown()
  for _, f in ipairs(fits) do
    local o = Kit.take(pools.onlineRows, parent)
    o:SetPoint("TOPLEFT", x, -y)
    o:SetWidth(width)
    o.portrait:SetClass(f.classFile)
    o.portrait:SetOnline(true)
    o.name:SetText(f.classFile and classColored(f, f.name) or tostring(f.name))
    o.info:SetText(f.level .. DOT .. tostring(f.friend or "community"))
    o.button:SetLabel("Whisper")
    o.button:SetEnabled(true)
    o.button.tooltip = nil
    o.button:SetScript("OnClick", function() whisper(f.name) end)
    o.button:ClearAllPoints()
    if open then
      o.invite:Show()
      o.invite:SetEnabled(not combat)
      o.invite.tooltip = combat and "Not in combat" or nil
      o.invite:SetScript("OnClick", function()
        if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(f.name) end
      end)
      o.button:SetPoint("RIGHT", o.invite, "LEFT", -6, 0)
    else
      o.invite:Hide()
      o.button:SetPoint("RIGHT", 0, 0)
    end
    y = y + ONLINE_ROW
  end
  return y + 4
end

-- CF-63b: "Invite" from 15 minutes before the start, "Invite · from 20:15" before.
local function inviteLabel(run, open)
  if open then return "Invite" end
  return "Invite" .. DOT .. "from " .. clock(run.startsAt - ns.PlannedRuns.INVITE_LEAD)
end

-- CF-63b (board CF63Group E): asks friends now for the run's dungeon with the note "For SM: Graveyard 20:30 · need
-- Healer"; the Ask dialog opens with it filled in (you can add Discord there).
askForRun = function(run, role)
  local dungeon = dungeonOf(run)
  if not dungeon then return end
  local note = date and ns.PlannedRuns.askNote(run, dungeonName(run), role, now(), date) or nil
  ns.RunDialogs.askNow(dungeon, note)
end

-- CF-63b (board CF63Group D): a member's right-click menu: Whisper, Invite, Show in Friends.
memberMenu = function(owner, run, a, c, who, open)
  local combat = InCombatLockdown and InCombatLockdown()
  local path
  if c and c.key and c.guid then
    local group = c.key == "self" and ns.Format.SELF or c.key:find("^member:") and ns.Format.UNLINKED or c.key
    path = ns.Format.path(group, c.guid)
  end
  local items = {
    { label = "Whisper", enabled = who ~= nil, action = "whisper" },
    { label = inviteLabel(run, open), enabled = open and not combat and who ~= nil, action = "invite" },
    { label = "Show in Friends", enabled = path ~= nil, action = "friends" },
  }
  ns.ContextMenu.open(owner, { title = (c and c.name) or a.name or who, items = items }, function(item)
    if item.action == "whisper" then
      ns.ContextMenu.whisper(who)
    elseif item.action == "invite" then
      if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(who) end
    elseif item.action == "friends" then
      ns.MainFrame.selectTab("friends")
      ns.FriendsTab.select(path)
    end
  end)
end

-- CF-63b (board CF63Group E): an open slot's menu: Whisper <the first who fits> with the prefilled text, Ask now for
-- this run, Invite.
openSlotMenu = function(owner, run, role, fits, open)
  local first = fits[1]
  local combat = InCombatLockdown and InCombatLockdown()
  local items = {
    { label = first and ("Whisper " .. first.name) or "Whisper", enabled = first ~= nil, action = "whisper" },
    { label = "Ask now for this run", enabled = dungeonOf(run) ~= nil, action = "ask" },
    { label = inviteLabel(run, open), enabled = first ~= nil and open and not combat, action = "invite" },
  }
  ns.ContextMenu.open(owner, { title = ROLE_LABEL[role] .. DOT .. "open", items = items }, function(item)
    if item.action == "whisper" then
      local text = date and ns.PlannedRuns.whisperText(run, dungeonName(run), role, now(), date) or ""
      ns.ContextMenu.whisperText(first.name, text)
    elseif item.action == "ask" then
      askForRun(run, role)
    elseif item.action == "invite" then
      if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(first.name) end
    end
  end)
end

-- A 1 px divider across the detail at y.
local function divider(parent, y, width)
  local d = Kit.take(pools.dividers, parent)
  d:SetPoint("TOPLEFT", PAD, -y)
  d:SetSize(width, 1)
  return y + 1
end

-- One run (CF-46; CF-62 board AG02Dungeons A to C; CF-63 board CF63RunDetail): the header, the group at full
-- width, your answer (or the organiser's start), then Online now, fits beside Edit or cancel / On the website.
local function renderRun(run, me, candidates)
  local parent = detail.child
  local width = math.max(560, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD - 6
  local dungeon = dungeonOf(run)
  local open = ns.PlannedRuns.inviteOpen(run, now())
  -- Header: the full name; "level 26–36 · <zone>"; the countdown line.
  placeText(pools.name, parent, PAD, y, width, dungeonName(run), "heading")
  y = y + 34
  if dungeon then
    local sub = "level " .. range(dungeon)
    if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. DOT .. ns.Dungeons.ZONES[dungeon.id] end
    placeText(pools.small, parent, PAD, y, width, sub, "muted")
    y = y + 18
  end
  local sub = {}
  local countdown = ns.PlannedRuns.countdown(run.startsAt, now())
  local lead
  if countdown == "Starting now" then
    lead = colored(countdown, "warning") .. DOT .. clock(run.startsAt)
  else
    lead = when(run.startsAt) .. DOT .. countdown
  end
  if SOURCE_WORDS[run.source] then sub[#sub + 1] = SOURCE_WORDS[run.source] end
  if run.state == "full" then sub[#sub + 1] = "full" end
  if run.note then sub[#sub + 1] = "note: \226\128\156" .. run.note .. "\226\128\157" end
  local leadText = placeText(pools.small, parent, PAD, y, width - 24,
    lead .. (#sub > 0 and (DOT .. table.concat(sub, DOT)) or ""), "textDim")
  local mineNow = ns.PlannedRuns.yourAnswer(run, me)
  if run.pending or (mineNow and mineNow.pending) then
    -- CF-63: a clock after the line, its tooltip says when it reaches the website.
    local lw = leadText.text.GetStringWidth and leadText.text:GetStringWidth() or 200
    local clockIcon = Kit.take(pools.clocks, parent)
    clockIcon:SetPoint("TOPLEFT", PAD + math.min(lw, width - 24) + 8, -(y + 1))
    clockIcon.tip = PENDING
  end
  y = y + 28

  -- Group: five full-width rows.
  local slotList = ns.PlannedRuns.slots(run, candidates, dungeon)
  local openCount, inGroup = 0, {}
  for _, slot in ipairs(slotList) do
    if not slot.answer then openCount = openCount + 1 end
    if slot.answer and slot.answer.guid then inGroup[slot.answer.guid] = true end
  end
  for _, a in ipairs(run.answers or {}) do
    if a.guid then inGroup[a.guid] = true end
  end
  local fits = onlineFits(dungeon, inGroup, candidates)
  local yes, maybe = ns.PlannedRuns.counts(run)
  local counts = yes .. " in" .. (maybe > 0 and (DOT .. maybe .. " maybe") or "") ..
    (openCount > 0 and (DOT .. openCount .. " open") or "")
  local groupTop = y
  y = section(parent, PAD, y, width, "Group", counts)
  -- CF-64: one "Ask now for this run" for the run (was on every open slot), at the right of the header.
  local needed = ns.PlannedRuns.neededRole(run, candidates, dungeon)
  if needed and dungeon then
    local ask = Kit.take(pools.buttons, parent)
    ask:SetLabel("Ask now for this run")
    ask:SetEnabled(true)
    ask:SetHeight(24)
    ask:SetScript("OnClick", function() askForRun(run, needed) end)
    ask:SetPoint("TOPRIGHT", parent, "TOPLEFT", PAD + width, -(groupTop - 2))
  end
  local organiser = run.organiser
  local ctx = open and ns.RunAlerts.context() or nil
  local states = {}
  if ctx then
    for _, st in ipairs(ns.RunStart.states(run, ns.Planner.me(), ctx)) do
      states[st.answer] = st
    end
  end
  local fitNames = {}
  for i, f in ipairs(fits) do
    if i > 8 then break end
    fitNames[#fitNames + 1] = f.name .. " " .. f.level
  end
  for _, slot in ipairs(slotList) do
    local g = Kit.take(pools.groupRows, parent)
    g:SetPoint("TOPLEFT", PAD, -y)
    g:SetWidth(width)
    g.tip, g.tipLines, g.menu, g.menuOnClick = nil, nil, nil, nil
    g.online:SetText("")
    local a, c = slot.answer, slot.char
    local mine = a and personName(a, candidates, me) == "you"
    rowEdges(g, mine)
    if a then
      g.bg:SetColorTexture(Theme.color(mine and "gold" or "white", mine and 0.07 or 0.03))
      g.role:SetRole(a.role or (c and c.role) or slot.role)
      local file = classFor(a.guid, c)
      setPortrait(g.portrait, file, c and c.online)
      local name = (c and c.name) or a.name or tagName(a.battleTag) or "?"
      g.name:SetText(file and classColored({ classFile = file }, name) or name)
      local level = c and c.level
      g.info:SetText((level and (level .. DOT) or "") .. tostring(personName(a, candidates, me) or ""))
      local st = states[a]
      -- "online": near the start from presence, else what the community roster says of the character.
      local online
      if st then
        online = st.state == "ready" or st.state == "other" or st.state == "grouped"
      else
        online = c and c.online
      end
      if online and not mine then g.online:SetText("online") end
      local state, color
      if organiser and ((a.guid and a.guid == organiser.guid) or (a.battleTag and a.battleTag == organiser.battleTag))
      then
        state, color = "organiser", "online"
      elseif mine then
        state, color = "you", "goldLight"
      elseif slot.maybe then
        state, color = "maybe", "warning"
      elseif open and st and st.state == "offline" then
        state, color = "offline", "muted"
      elseif a.source == "discord" then
        state, color = "Discord", "swap"
      end
      -- CF-49: how the level fits when it isn't "fits": a carry in the warning colour, others muted.
      local fit = not state and ns.PlannedRuns.fitOf(a, c, dungeon)
      if fit and fit.label ~= "fits" then state, color = fit.label, fit.kind == "carry" and "warning" or "muted" end
      g.status:SetText(state or "")
      g.status:SetTextColor(Theme.color(color or "muted"))
      -- CF-63b (board CF63Group C, D): the hover tooltip and the right-click menu.
      local presence = st and st.presence or (online and c and { name = c.name }) or nil
      g.tipLines = ns.PlannedRuns.memberLines(a, c, dungeon, presence, now(), date)
      if not mine then
        local who = (presence and presence.name) or name
        g.menu = function(owner) memberMenu(owner, run, a, c, who, open) end
      end
    else
      g.bg:SetColorTexture(Theme.color("white", 0.015))
      g.role:SetRole(slot.role, true)
      g.portrait:Hide()
      g.name:SetText(colored(ROLE_LABEL[slot.role] .. DOT .. (slot.missing and "nobody fits" or "open"),
        slot.missing and "warning" or "muted"))
      g.info:SetText("")
      g.status:SetText("")
      if not slot.missing then
        -- CF-63b (board CF63Group E): a click opens Whisper / Ask now for this run / Invite.
        g.menu, g.menuOnClick = function(owner) openSlotMenu(owner, run, slot.role, fits, open) end, true
        if #fits > 0 then g.tip = table.concat(fitNames, "\n") end
      end
    end
    fitGroupRow(g, width)
    y = y + GROUP_ROW + 5
  end
  local reserves = {}
  for _, a in ipairs(ns.PlannedRuns.reserves(run)) do
    local who = a.name or tagName(a.battleTag) or "?"
    local parts = {}
    if a.role then parts[#parts + 1] = ROLE_LABEL[a.role] end
    local friend = personName(a, candidates, me)
    if friend and friend ~= who then parts[#parts + 1] = friend end
    reserves[#reserves + 1] = who .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "")
  end
  if #reserves > 0 then
    placeText(pools.small, parent, PAD, y + 2, width, "Reserve: " .. table.concat(reserves, ", "), "muted")
    y = y + 22
  end

  -- Your answer (or the organiser's start), between two dividers.
  y = divider(parent, y + 6, width) + 12
  local isOrganiser = ns.PlannedRuns.isOrganiser(run, me)
  local data = ns.Planner.data()
  if isOrganiser then
    y = section(parent, PAD, y, width, open and "Start" or ("At " .. clock(run.startsAt)))
    local ready = {}
    if ctx then ready = ns.RunStart.readyToInvite(ns.RunStart.states(run, ns.Planner.me(), ctx)) end
    local b = Kit.take(pools.primary, parent)
    b:SetLabel(open and ("Invite all" .. DOT .. #ready .. " online")
      or ("Invite all" .. DOT .. "opens " .. clock(run.startsAt - ns.PlannedRuns.INVITE_LEAD)))
    b:SetEnabled(open and #ready > 0)
    b:SetHeight(32)
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b.tooltip = INVITE_TIP -- also while disabled
    b:SetScript("OnClick", function() ns.RunAlerts.inviteReady(run) end)
    b:SetPoint("TOPLEFT", PAD, -y)
    local bx = PAD + (b:GetWidth() or 180) + 10
    if open and ctx then
      for _, st in ipairs(ns.RunStart.states(run, ns.Planner.me(), ctx)) do
        if st.state == "other" then
          local w = Kit.take(pools.buttons, parent)
          w:SetLabel("Whisper " .. tostring(personName(st.answer, candidates, me)))
          w:SetEnabled(true)
          w:SetScript("OnClick", function() ns.RunAlerts.whisperSwitch(run, st) end)
          w:SetPoint("TOPLEFT", bx, -(y + 3))
          break
        end
      end
    end
    y = y + 40
    if not open and data and data.reminderMinutes and date then
      placeText(pools.small, parent, PAD, y, width,
        "Reminder at " .. clock(run.startsAt - data.reminderMinutes * 60), "textDim")
      y = y + 20
    elseif open and ctx then
      local offline = {}
      for _, st in ipairs(ns.RunStart.missing(ns.RunStart.states(run, ns.Planner.me(), ctx))) do
        local who = st.answer.name or personName(st.answer, candidates, me) or "?"
        offline[#offline + 1] = who .. (st.answer.answer == "maybe" and " (maybe)" or "")
      end
      if #offline > 0 then
        placeText(pools.small, parent, PAD, y, width, table.concat(offline, ", ") ..
          (#offline == 1 and " is offline." or " are offline."), "textDim")
        y = y + 20
      end
    end
  elseif not run.pending then
    -- CF-63b (board CF63Answer): answering inline, every click saves.
    y = y + ns.RunAnswer.render(parent, run, me, candidates, PAD, y, width, function() helpers.render() end)
  end

  -- One row: Online now, fits (left); Edit or cancel or On the website (right, 236 px).
  y = divider(parent, y + 6, width) + 12
  local leftWidth = width - LINK_WIDTH - 24
  local rightX = PAD + leftWidth + 24
  local ly = onlineList(parent, PAD, y, leftWidth, fits, dungeon, open)
  local heading = placeText(pools.section, parent, rightX, y, LINK_WIDTH,
    isOrganiser and "Edit or cancel" or "On the website", "goldLight")
  local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 120
  local info = Kit.take(pools.infos, parent)
  info:SetPoint("TOPLEFT", rightX + hw + 6, -(y + 3))
  info.tip = LINK_TIP
  local ry = y + 26
  if run.url then
    linkBox:ClearAllPoints()
    linkBox:SetParent(parent)
    linkBox:SetPoint("TOPLEFT", rightX, -ry)
    linkBox:SetWidth(LINK_WIDTH - 16)
    linkBox:SetText(run.url)
    linkBox:Show()
    ry = ry + 34
  end
  parent:SetHeight(math.max(ly, ry) + PAD)
  detail:Update()
end

-- CF-62 (board D): no runs and no dungeon in range: what's going on, Ask now… and Copy website link.
local function renderEmpty(messageText)
  local parent = detail.child
  local width = math.max(420, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD + 60
  placeText(pools.name, parent, PAD, y, width, "Nothing planned yet", "heading", "CENTER")
  y = y + 40
  local body = messageText or "Plan a run on the website and it shows up here after your next upload, or use Ask "
    .. "now to see who is up for a dungeon right now."
  placeText(pools.small, parent, PAD, y, width, body, "textDim", "CENTER")
  y = y + 44
  local site = ns.RunsFile.site()
  local ask = Kit.take(pools.primary, parent)
  ask:SetLabel("Ask now\226\128\166")
  ask:SetEnabled(DungeonsTab.canAsk())
  ask:SetScript("OnClick", function() DungeonsTab.askNow() end)
  local copy
  if site then
    copy = Kit.take(pools.buttons, parent)
    copy:SetLabel("Copy website link")
    copy:SetEnabled(true)
    copy:SetScript("OnClick", function()
      linkBox:ClearAllPoints()
      linkBox:SetParent(parent)
      linkBox:SetPoint("TOP", parent, "TOPLEFT", PAD + width / 2, -(y + 44))
      linkBox:SetWidth(260)
      linkBox:SetText(site)
      linkBox:Show()
      if linkBox.SetFocus then linkBox:SetFocus() end
      if linkBox.HighlightText then linkBox:HighlightText() end
    end)
  end
  local total = (ask:GetWidth() or 100) + (copy and ((copy:GetWidth() or 140) + 10) or 0)
  ask:SetPoint("TOPLEFT", PAD + math.floor((width - total) / 2), -y)
  if copy then copy:SetPoint("LEFT", ask, "RIGHT", 10, 0) end
  parent:SetHeight(y + 120)
  detail:Update()
end

-- CF-63c (board CF63List I): no dungeon fits the character the list follows: the first one, and Show all dungeons
-- or Pick another character.
local function renderNoFit()
  local parent = detail.child
  local width = math.max(420, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD + 80
  placeText(pools.name, parent, PAD, y, width, "No dungeon fits yet", "heading", "CENTER")
  y = y + 36
  local first = ns.Dungeons.first()
  if first then
    placeText(pools.small, parent, PAD, y, width, string.format("First one: %s at level %d", first.name, first.min),
      "textDim", "CENTER")
  end
  y = y + 30
  local all = Kit.take(pools.buttons, parent)
  all:SetLabel("Show all dungeons")
  all:SetEnabled(true)
  all:SetScript("OnClick", function()
    showAll = true
    helpers.render()
  end)
  local other = Kit.take(pools.buttons, parent)
  other:SetLabel("Pick another character")
  other:SetEnabled(#rangeOptions > 1)
  other:SetScript("OnClick", rangeMenu)
  local total = (all:GetWidth() or 140) + 10 + (other:GetWidth() or 160)
  all:SetPoint("TOPLEFT", PAD + math.floor((width - total) / 2), -y)
  other:SetPoint("LEFT", all, "RIGHT", 10, 0)
  parent:SetHeight(y + 80)
  detail:Update()
end

-- A dungeon (CF-62, board AG05; CF-63c board CF63List F to H): title, range and zone; for a dungeon out of range
-- how your characters fit; the suggested group as rows; Online now, fits; the quests; Ask now.
local function renderDetail(entry, messageText, runs, candidates, rangeChar)
  if not entry then return renderEmpty(messageText) end
  local parent = detail.child
  local width = math.max(560, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD - 6
  local dungeon = entry.dungeon
  placeText(pools.name, parent, PAD, y, width - 200, dungeon.name, "heading")
  -- A planned run for this dungeon: "1 run planned · Fri 20:00 ›" selects it.
  local planned = {}
  for _, run in ipairs(runs) do
    if run.dungeon == dungeon.id then planned[#planned + 1] = run end
  end
  if #planned > 0 then
    local b = Kit.take(pools.buttons, parent)
    b:SetLabel(plural(#planned, "run") .. " planned" .. DOT .. (date and ns.PlannedRuns.rowTime(planned[1].startsAt,
      now(), date) or "") .. " \226\128\186")
    b:SetEnabled(true)
    b:SetScript("OnClick", function() DungeonsTab.select("run:" .. planned[1].id) end)
    b:SetPoint("TOPRIGHT", parent, "TOPLEFT", PAD + width, -y)
  end
  y = y + 34
  local sub = "level " .. range(dungeon)
  if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. DOT .. ns.Dungeons.ZONES[dungeon.id] end
  placeText(pools.small, parent, PAD, y, width, sub, "muted")
  y = y + 18
  local options = ns.PlannedRuns.charChoices(candidates, dungeon, rangeChar.guid)
  if not entry.fits then
    -- "Ada Lovewell 23: too low · Bo Example 58: fits" (your best alt, when one fits).
    local own = rangeChar.level and ns.PlannedRuns.levelFit(rangeChar.level, dungeon.min, dungeon.max)
    local parts = { string.format("%s %s: %s", tostring(rangeChar.name), tostring(rangeChar.level or "?"),
      colored(own and own.kind == "tooLow" and "too low" or (own and own.label or "?"), "warning")) }
    local alt = options[1]
    if alt and alt.char.guid ~= rangeChar.guid and alt.fit.kind == "fits" then
      parts[2] = string.format("%s %s: %s", tostring(alt.char.name), tostring(alt.char.level),
        colored("fits", "online"))
    end
    placeText(pools.small, parent, PAD, y + 4, width, table.concat(parts, DOT), "muted")
    y = y + 24
  end
  y = y + 10

  -- Suggested group: the same rows as a run's group, full width.
  local heading = placeText(pools.section, parent, PAD, y, width, "Suggested group", "goldLight")
  local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 120
  local gi = Kit.take(pools.infos, parent)
  gi:SetPoint("TOPLEFT", PAD + hw + 6, -(y + 3))
  gi.tip = SUGGEST_TIP
  y = y + Kit.SECTION_HEIGHT
  local group = ns.Dungeons.suggest(entry)
  local inGroup = {}
  for _, c in ipairs(group) do
    if c.guid then inGroup[c.guid] = true end
  end
  local fits = onlineFits(dungeon, inGroup, candidates)
  for _, slot in ipairs(ns.Dungeons.slots(group, entry.selfGuid)) do
    local g = Kit.take(pools.groupRows, parent)
    g:SetPoint("TOPLEFT", PAD, -y)
    g:SetWidth(width)
    g.tip, g.tipLines, g.menu, g.menuOnClick = nil, nil, nil, nil
    g.online:SetText("")
    local c = slot.char
    rowEdges(g, false)
    if c then
      g.bg:SetColorTexture(Theme.color("white", 0.03))
      g.role:SetRole(c.role or slot.role)
      local file = classFor(c.guid, c)
      setPortrait(g.portrait, file, c.online)
      g.name:SetText(file and classColored({ classFile = file }, c.name) or tostring(c.name))
      g.info:SetText(tostring(c.level) .. DOT .. (c.own and "you" or tostring(c.displayName or "member")))
      if c.online then g.online:SetText("online") end
      g.status:SetText("")
    else
      g.bg:SetColorTexture(Theme.color("white", 0.015))
      g.role:SetRole(slot.role, true)
      g.portrait:Hide()
      g.name:SetText(colored(ROLE_LABEL[slot.role] .. DOT .. (slot.missing and "nobody fits" or "open"),
        slot.missing and "warning" or "muted"))
      g.info:SetText("")
      g.status:SetText("")
    end
    fitGroupRow(g, width)
    y = y + GROUP_ROW + 5
  end

  -- Online now, fits.
  y = divider(parent, y + 6, width) + 12
  y = onlineList(parent, PAD, y, width, fits, dungeon, false) + 6

  -- Quests: QuestieDB for this dungeon and your faction; else what people in range have in their logs.
  local info = questInfo(entry)
  local done = 0
  for _, q in ipairs(info.quests) do
    if q.state == "done" then done = done + 1 end
  end
  local note
  if not info.complete then
    note = "needs Questie"
  else
    note = string.format("%d of %d in your log", info.have, info.total) .. (done > 0 and (DOT .. done .. " done") or "")
  end
  y = section(parent, PAD, y, width, "Quests", note)
  if info.complete then -- CF-62: without QuestieDB the heading says "needs Questie" and the list is hidden
    for _, q in ipairs(info.quests) do
      local r = Kit.take(pools.quests, parent)
      r:SetPoint("TOPLEFT", PAD, -y)
      r:SetWidth(width)
      r.name:SetWidth(width - 22 - 180)
      local name = tostring(q.name or ("Quest " .. q.id))
      if q.state == "have" then
        r.check:Show()
        r.name:SetText(name)
        r.name:SetTextColor(Theme.color("text"))
      elseif q.state == "done" then
        r.check:Hide()
        r.name:SetText(name)
        r.name:SetTextColor(Theme.color("faint"))
      else
        r.check:Hide()
        r.name:SetText(colored("!", "goldLight") .. "  " .. name)
        r.name:SetTextColor(Theme.color(q.state == "later" and "muted" or "text"))
      end
      local who
      if q.state == "done" then
        who = "done"
      elseif q.state == "later" then
        who = "from level " .. tostring(q.requiredLevel)
      elseif #q.holders > 0 then
        who = table.concat(q.holders, ", ") .. (#q.holders == 1 and " has it" or " have it") .. (q.state == "have"
          and " too" or "")
      elseif type(q.level) == "number" and q.level > 0 then
        who = "level " .. q.level
      end
      r.who:SetText(who or "")
      y = y + 24
    end
  end

  -- Ask now (CF-64: planning for later happens on the website or with the bot's /plan, Nico 2026-10-31). An ask is
  -- always possible: friends in game get it when any are online, Discord always (through the uploader).
  y = y + 12
  local ask = ns.GroupAsks.current()
  if ask and ask.dungeon.id == dungeon.id then
    y = askBlock(parent, entry, y, width)
  else
    local okAsk, wait = ns.GroupAsks.canAsk()
    local a = Kit.take(pools.primary, parent)
    a:SetLabel("Ask now")
    a:SetEnabled(okAsk == true)
    a.tooltip = okAsk and ASK_TIP or string.format("You can ask again in %d min.", math.ceil((wait or 0) / 60))
    if a.SetMotionScriptsWhileDisabled then a:SetMotionScriptsWhileDisabled(true) end
    a:SetScript("OnClick", function() ns.RunDialogs.askNow(dungeon) end)
    a:SetPoint("TOPLEFT", PAD, -y)
    y = y + 40
  end
  parent:SetHeight(y + PAD)
  detail:Update()
end

-- ===== Public =====

function DungeonsTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  local column = CreateFrame("Frame", nil, root)
  column:SetPoint("TOPLEFT")
  column:SetPoint("BOTTOMLEFT")
  column:SetWidth(LIST_WIDTH) -- CF-62
  local columnBg = Theme.fill(column, "list", "BACKGROUND")
  columnBg:SetAllPoints()
  local columnLine = Theme.fill(column, "divider", "BORDER")
  columnLine:SetPoint("TOPRIGHT")
  columnLine:SetPoint("BOTTOMRIGHT")
  columnLine:SetWidth(1)
  list = Kit.scrollArea(column)
  list:SetPoint("TOPLEFT", 0, -4)
  list:SetPoint("BOTTOMRIGHT", 0, 4)

  detail = Kit.scrollArea(root)
  detail:SetPoint("TOPLEFT", column, "TOPRIGHT", 0, 0)
  detail:SetPoint("BOTTOMRIGHT")

  -- The run's link to copy: selected when clicked, so Ctrl+C copies it. Typing does not change it.
  linkBox = CreateFrame("EditBox", nil, detail.child)
  linkBox:SetHeight(28)
  linkBox:SetAutoFocus(false)
  linkBox:SetTextInsets(10, 10, 0, 0)
  Theme.font(linkBox, "small")
  linkBox:SetTextColor(Theme.color("text"))
  local boxBg = Theme.fill(linkBox, "input", "BACKGROUND")
  boxBg:SetAllPoints()
  linkBox.edges = Kit.edges(linkBox, "border")
  linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  linkBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self.link then self:SetText(self.link) end
  end)
  local setText = linkBox.SetText
  function linkBox:SetText(text)
    self.link = text
    setText(self, text)
  end
  linkBox:Hide()

  pools = {
    rows = Kit.pool(listRow), listText = Kit.pool(Kit.textHolder("tiny")),
    name = Kit.pool(Kit.textHolder("name")), section = Kit.pool(Kit.textHolder("section")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    slots = Kit.pool(slotFrame), quests = Kit.pool(questRow), buttons = Kit.pool(button),
    primary = Kit.pool(primary),
    -- CF-62
    runRows = Kit.pool(runRow), listTitle = Kit.pool(Kit.textHolder("section")), listButtons = Kit.pool(button),
    groupRows = Kit.pool(groupRow), onlineRows = Kit.pool(onlineRow), infos = Kit.pool(Kit.info),
    listInfos = Kit.pool(Kit.info), clocks = Kit.pool(Kit.clock), -- CF-63
    chips = Kit.pool(chip), checks = Kit.pool(checkRow),
    selects = Kit.pool(function(p) -- CF-64: the In range dropdown
      return Kit.select(p, function(guid)
        rangeGuid = guid
        status().selected = nil
        helpers.render()
      end)
    end),
    dividers = Kit.pool(function(p)
      local f = CreateFrame("Frame", nil, p)
      local t = Theme.fill(f, "divider", "BORDER")
      t:SetAllPoints()
      return f
    end),
    links = Kit.pool(function(p)
      local b = CreateFrame("Button", nil, p)
      b:SetSize(60, 18)
      b.text = Theme.text(b, "small", "goldLight")
      b.text:SetPoint("LEFT")
      return b
    end),
  }
  return root
end

-- Shown: the game's dungeons and level ranges (V46).
function DungeonsTab.show()
  if not root then return end
  root:Show()
  if not ticking then
    ticking = ns.Timer.every(60, function()
      if root and root:IsShown() and helpers then helpers.render() end
    end)
  end
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
end

function DungeonsTab.hide() if root then root:Hide() end end

-- CF-63c: the window closed: the chips start at All next time, and no plan box is open.
function DungeonsTab.closed()
  filter = "all"
end

function DungeonsTab.select(value)
  status().selected = value
  helpers.render()
end

-- CF-48: selects a row without drawing (the window draws when it opens on the tab).
function DungeonsTab.selectQuietly(value)
  if helpers then status().selected = value end
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
function DungeonsTab.render(view, messageText)
  if not root then return end
  entries = {}
  clearDetail()
  local me = ns.SelfInfo.read()
  if messageText then
    renderList({}, {}, me, {}, { guid = me.guid, name = me.name, level = me.level })
    renderDetail(nil, messageText, {}, {})
    return
  end

  local who = ns.Planner.me()
  local runs = ns.Planner.upcoming()
  local candidates = ns.Dungeons.candidates(view)
  -- CF-63c: the character "In range for" follows: the one picked this session, else the one you are on.
  rangeOptions = {}
  local rangeChar
  for _, c in ipairs(candidates) do
    if c.own then
      rangeOptions[#rangeOptions + 1] = c
      if c.guid == (rangeGuid or me.guid) then rangeChar = c end
    end
  end
  table.sort(rangeOptions, function(a, b) return (a.level or 0) > (b.level or 0) end)
  rangeChar = rangeChar or { guid = me.guid, name = me.name, level = me.level }
  local include
  if showAll then
    include = {}
    for _, d in ipairs(ns.Dungeons.LIST) do include[d.id] = true end
  end
  local overview = ns.Dungeons.overview(candidates, rangeChar.guid, include)
  local order = {}
  for _, run in ipairs(runs) do
    entries["run:" .. run.id] = { run = run }
    order[#order + 1] = "run:" .. run.id
  end
  local anyFits = false
  for _, entry in ipairs(overview) do
    entries[entry.dungeon.id] = entry
    order[#order + 1] = entry.dungeon.id
    anyFits = anyFits or entry.fits
  end

  local st = status()
  if not st.selected or not entries[st.selected] then
    -- CF-62: the next run you're in (or organise), else the first dungeon in range.
    local first
    for _, run in ipairs(runs) do
      local mine = ns.PlannedRuns.yourAnswer(run, who)
      if not first and (ns.PlannedRuns.isOrganiser(run, who) or (mine and mine.answer ~= "cant")) then
        first = "run:" .. run.id
      end
    end
    if not first then
      for _, value in ipairs(order) do
        if not first and entries[value].dungeon and entries[value].fits then first = value end
      end
    end
    -- No dungeon fits (CF-63c board I): the first run only when there is no character to pick and nothing to show.
    st.selected = first or ((anyFits or #runs == 0) and order[1] or nil)
  end
  me.guids, me.battleTag = who.guids, who.battleTag
  renderList(runs, overview, me, candidates, rangeChar)
  if not st.selected then
    if #runs > 0 then
      renderNoFit()
    else
      renderDetail(nil, ns.Dungeons.emptyText(me.name, me.level, ns.CommunitySelection.active() ~= nil), runs,
        candidates, rangeChar)
    end
    return
  end
  local entry = entries[st.selected]
  if entry.run then
    renderRun(entry.run, me, candidates)
  else
    renderDetail(entry, nil, runs, candidates, rangeChar)
  end
end

-- CF-62: whether Ask now… has a dungeon to ask for (CF-64: any dungeon the game knows; an ask is always possible).
function DungeonsTab.canAsk()
  return #ns.Dungeons.LIST > 0
end

-- CF-62: "Ask now…" on the list: the selected run's dungeon, else the selected or first dungeon in range.
function DungeonsTab.askNow()
  local selected = entries[status().selected]
  local dungeon = selected and (selected.run and dungeonOf(selected.run) or selected.dungeon)
  if not dungeon then
    for _, e in pairs(entries) do
      if e.dungeon and e.fits then dungeon = e.dungeon break end
    end
  end
  dungeon = dungeon or ns.Dungeons.first() -- CF-64: an ask is always possible
  if dungeon then ns.RunDialogs.askNow(dungeon) end
end

function DungeonsTab.reset()
  root, entries, rows = nil, {}, {}
end

-- For the specs: the list rows, the card's texts (in pool order), its buttons by label, the link box.
function DungeonsTab.rows() return rows end
function DungeonsTab.linkBox() return linkBox end

function DungeonsTab.texts()
  local out = {}
  for _, name in ipairs({ "listTitle", "listText", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "rows", "runRows", "slots", "groupRows", "onlineRows", "quests" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "name", "right", "meta", "info", "online", "status", "mark", "who", "level" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
    end
  end
  for _, t in ipairs(ns.RunAnswer and ns.RunAnswer.texts() or {}) do out[#out + 1] = t end -- CF-63b
  return out
end

function DungeonsTab.buttons()
  local out = ns.RunAnswer and ns.RunAnswer.buttons() or {} -- CF-63b
  for i = 1, pools and pools.selects.used or 0 do out["select:" .. i] = pools.selects.items[i] end -- CF-64
  for i = 1, pools and pools.chips.used or 0 do out["chip:" .. pools.chips.items[i].value] = pools.chips.items[i] end
  for i = 1, pools and pools.checks.used or 0 do
    out[pools.checks.items[i].text:GetText()] = pools.checks.items[i]
  end
  for _, name in ipairs({ "buttons", "primary", "listButtons" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  for i = 1, pools and pools.links.used or 0 do out[pools.links.items[i].text:GetText()] = pools.links.items[i] end
  for i = 1, pools and pools.onlineRows.used or 0 do
    local b = pools.onlineRows.items[i].button
    out[b.label:GetText() .. ":" .. i] = b
  end
  return out
end

function DungeonsTab.questRows()
  local out = {}
  for i = 1, pools and pools.quests.used or 0 do out[i] = pools.quests.items[i] end
  return out
end

function DungeonsTab.groupRows()
  local out = {}
  for i = 1, pools and pools.groupRows.used or 0 do out[i] = pools.groupRows.items[i] end
  return out
end

function DungeonsTab.tips()
  local out = {}
  for _, name in ipairs({ "infos", "listInfos", "clocks" }) do
    for i = 1, pools and pools[name].used or 0 do out[#out + 1] = pools[name].items[i].tip end
  end
  for _, name in ipairs({ "primary", "buttons", "groupRows", "listButtons", "selects" }) do
    for i = 1, pools and pools[name].used or 0 do
      local t = pools[name].items[i].tooltip or pools[name].items[i].tip
      if t then out[#out + 1] = t end
    end
  end
  for _, t in ipairs(ns.RunAnswer and ns.RunAnswer.tips() or {}) do out[#out + 1] = t end -- CF-63b
  return out
end

function DungeonsTab.slots()
  local out = {}
  for i = 1, pools and pools.slots.used or 0 do out[i] = pools.slots.items[i] end
  return out
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
