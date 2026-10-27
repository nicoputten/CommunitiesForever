-- DungeonsTab: the Dungeons tab in the revamp's look (CF-42; design docs/design/revamp-2026-10/dungeons.html;
-- the planner itself is CF-24). Left: runs planned in the calendar for the next days, then the dungeons in
-- range of the character you are on. Right: the chosen dungeon with its suggested group as five slots, your
-- alternatives, asking who's up for it (CF-27), the others in range, its quests, and the event title to copy
-- into a community event (addons cannot create one, V34). Native frames from the kit, drawn from pools.
local _, ns = ...

local DungeonsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20
local ROW = 44
local SLOT_HEIGHT = 86
local SLOT_GAP = 8
local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }
local SIGNED = { [1] = true, [3] = true, [6] = true } -- your inviteStatus counts as going (as Dungeons.signUps)
local NOTE = "Ranges are typical levels; the list follows the character you're on."
local ASK_NOTE = "Sends a chat line to friends with the addon"

local root, list, detail
local helpers -- from MainFrame: settings(), render(), print(text)
local entries = {} -- row value -> overview entry
local rows = {}    -- visible list rows: { value, frame }
local pools
local titleBox -- the event title to copy

-- ===== Helpers =====

local function status()
  local s = helpers.settings()
  s.dungeonTree = s.dungeonTree or {} -- the keys the AceGUI tree used (rule 8): selected
  return s.dungeonTree
end

local function hex(r, g, b)
  local function byte(v) return math.floor((v or 0) * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x", byte(r), byte(g), byte(b))
end

local function colored(text, colorName) return hex(Theme.color(colorName)) .. tostring(text) .. "|r" end

local function classColored(c, text)
  return hex(Kit.classColor(c.classFile)) .. tostring(text or c.name) .. "|r"
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- "17–24" with the bundled font; the game font has no en dash.
local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

-- "3 signed up · +1 tentative", or nil when the sign-ups are not known (V43).
local function signUpText(event)
  local signed, tentative = ns.Planner.signUpsOf(event)
  if not signed then return nil end
  local text = signed .. " signed up"
  if tentative and tentative > 0 then text = text .. " \194\183 +" .. tentative .. " tentative" end
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
  r.planBg = r:CreateTexture(nil, "BACKGROUND", nil, -1)
  r.planBg:SetAllPoints()
  r.planBg:SetColorTexture(0.498, 0.851, 0.604, 0.06)
  r.name = Theme.text(r, "group", "goldLight")
  r.name:SetPoint("TOPLEFT", 12, -7)
  r.right = Theme.text(r, "tiny", "muted")
  r.right:SetPoint("TOPRIGHT", -12, -8)
  r.meta = Theme.text(r, "tiny", "muted")
  r.meta:SetPoint("BOTTOMLEFT", 12, 7)
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- A slot of the suggested group: portrait (or "?" / "+"), name and level, role and who.
local function slotFrame(parent)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(SLOT_HEIGHT)
  local bg = s:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 0.03)
  s.edges = Kit.edges(s, "divider")
  s.portrait = Kit.portrait(s, 26)
  s.portrait:SetPoint("TOP", 0, -9)
  s.mark = Theme.text(s, "body", "faint")
  s.mark:SetPoint("CENTER", s.portrait)
  s.name = Theme.text(s, "small", "text")
  s.name:SetPoint("TOP", s.portrait, "BOTTOM", 0, -5)
  s.info = Theme.text(s, "tiny", "textDim")
  s.info:SetPoint("TOP", s.name, "BOTTOM", 0, -3)
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
  sep:SetColorTexture(1, 1, 1, 0.05)
  return q
end

local function button(parent) return Kit.button(parent, "", nil) end
local function primary(parent) return Kit.button(parent, "", nil, "primary") end

-- ===== Drawing =====

local function placeText(poolName, parent, x, y, width, text, colorName)
  local holder = Kit.take(pools[poolName], parent)
  holder:SetPoint("TOPLEFT", x, -y)
  holder.text:SetWidth(width or 0)
  holder.text:SetText(text or "")
  holder.text:SetTextColor(Theme.color(colorName or "text"))
  return holder
end

local function section(parent, x, y, width, text, extra, extraColor)
  local h = placeText("section", parent, x, y, width, text, "goldLight")
  if extra then
    local w = h.text.GetStringWidth and h.text:GetStringWidth() or 100
    placeText("small", parent, x + w + 10, y + 3, width - w - 10, extra, extraColor or "muted")
  end
  return y + 24
end

local function renderList(planned, overview, me)
  Kit.release(pools.rows)
  Kit.release(pools.listText)
  rows = {}
  local parent = list.child
  local width = math.max(200, (list:GetWidth() or 0) - 6)
  local y = 4
  local selected = status().selected

  local function label(text)
    placeText("listText", parent, 12, y + 8, width - 24, text:upper(), "faint")
    y = y + 26
  end
  local function row(value, name, right, rightColor, meta, dim, plannedRow)
    local r = Kit.take(pools.rows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = value
    r.name:SetText(name)
    r.name:SetTextColor(Theme.color(dim and "muted" or "goldLight"))
    r.right:SetText(right or "")
    r.right:SetTextColor(Theme.color(rightColor or "muted"))
    r.meta:SetText(meta or "")
    if plannedRow then r.planBg:Show() else r.planBg:Hide() end
    r:SetSelected(value == selected)
    rows[#rows + 1] = { value = value, frame = r }
    y = y + ROW
  end

  if #planned > 0 then
    label("Planned")
    for i, p in ipairs(planned) do
      local entry = entries["planned:" .. i]
      local meta = {}
      if p.signed then meta[#meta + 1] = p.signed .. " going" end
      if SIGNED[p.event.inviteStatus] then meta[#meta + 1] = "you" end
      row("planned:" .. i, p.dungeon.name, ns.Dungeons.shortTime(p.event.startTime), "onlineText",
        table.concat(meta, " \194\183 "), not (entry and entry.fits), true)
    end
  end
  local inRange = {}
  for _, entry in ipairs(overview) do
    if entry.fits then inRange[#inRange + 1] = entry end
  end
  if #inRange > 0 then
    label(string.format("In range for %s (%s)", tostring(me.name), tostring(me.level or "?")))
    for _, entry in ipairs(inRange) do
      local friends = entry.people - 1
      local meta = friends > 0 and plural(friends, "friend") or "nobody else yet"
      local info = questInfo(entry)
      if info.total > 0 then
        meta = meta .. "    " .. colored(string.format("%d / %d quests", info.have, info.total),
          info.have == info.total and "onlineText" or "goldLight")
      end
      row(entry.dungeon.id, entry.dungeon.name, range(entry.dungeon), "muted", meta)
    end
  end
  local note = placeText("listText", parent, 12, y + 10, width - 24, NOTE, "faint")
  note.text:SetTextColor(Theme.color("faint"))
  y = y + 46
  parent:SetHeight(y)
  list:Update()
end

-- The five slots of the suggested group.
local function slots(parent, entry, group, y, width)
  local w = math.floor((width - 4 * SLOT_GAP) / 5)
  for i, slot in ipairs(ns.Dungeons.slots(group, entry.selfGuid)) do
    local s = Kit.take(pools.slots, parent)
    s:SetPoint("TOPLEFT", PAD + (i - 1) * (w + SLOT_GAP), -y)
    s:SetWidth(w)
    local edge = { Theme.color("divider") }
    local c = slot.char
    if c then
      s.portrait:Show()
      s.mark:SetText("")
      s.portrait:SetClass(c.classFile)
      s.portrait:SetOnline(c.online)
      s.name:SetText(classColored(c, ns.Format.truncate(c.name, 14) .. " " .. tostring(c.level)))
      local info = { ROLE_NAMES[c.role] or ROLE_NAMES[slot.role] }
      info[#info + 1] = c.own and "you" or (c.displayName or "member")
      if c.online then info[#info + 1] = "online" end
      s.info:SetText(table.concat(info, " \194\183 "))
      s.info:SetTextColor(Theme.color("textDim"))
      if slot.own then edge = { Theme.color("gold") } end
    else
      s.portrait:Hide()
      s.mark:SetText(slot.missing and "?" or "+")
      s.mark:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      s.name:SetText(ROLE_NAMES[slot.role])
      s.info:SetText(slot.missing and "nobody in range" or "open")
      s.info:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      if slot.missing then edge = { 0.878, 0.541, 0.290, 0.5 } end
    end
    for _, e in ipairs(s.edges) do e:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1) end
  end
  return y + SLOT_HEIGHT + 10
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
    placeText("small", parent, PAD, y + 4, width, "Asked who's up for it \194\183 " .. table.concat(parts,
      " \194\183 "), "text")
    return y + 26
  end
  local ok, wait = ns.GroupAsks.canAsk()
  if not ok then
    placeText("small", parent, PAD, y + 4, width, string.format("You can ask again in %d min.",
      math.ceil(wait / 60)), "muted")
    return y + 26
  end
  local b = Kit.take(pools.primary, parent)
  b:SetLabel("Ask who's up for it")
  b:SetEnabled(true)
  b:SetScript("OnClick", function() ns.GroupAsks.ask(entry.dungeon) end)
  b:SetPoint("TOPLEFT", PAD, -y)
  placeText("tiny", parent, PAD + (b:GetWidth() or 140) + 10, y + 7, width, ASK_NOTE, "faint")
  return y + 36
end

local function questColumn(parent, info, x, y, width)
  local hint = "Install QuestieDB (it comes with Questie) to see every quest for this dungeon."
  if #info.quests == 0 then
    y = section(parent, x, y, width, "Quests")
    placeText("small", parent, x, y, width, "No quests known for this dungeon yet.", "muted")
    y = y + 18
    if not info.complete then
      placeText("tiny", parent, x, y, width, hint, "faint")
      y = y + 30
    end
    return y
  end
  y = section(parent, x, y, width, "Quests", string.format("%d / %d in your log", info.have, info.total),
    info.have == info.total and "onlineText" or "goldLight")
  local done = 0
  for _, q in ipairs(info.quests) do
    if q.state == "done" then
      done = done + 1
    else
      local r = Kit.take(pools.quests, parent)
      r:SetPoint("TOPLEFT", x, -y)
      r:SetWidth(width)
      if q.state == "have" then r.check:Show() else r.check:Hide() end
      r.name:SetText(tostring(q.name or ("Quest " .. q.id)))
      r.name:SetTextColor(Theme.color(q.state == "later" and "muted" or "text"))
      r.name:SetWidth(width - 22 - 90)
      local who
      if q.state == "later" then
        who = "from level " .. tostring(q.requiredLevel)
      elseif #q.holders > 0 then
        who = table.concat(q.holders, ", ") .. (q.state == "have" and " too" or " has it")
      elseif type(q.level) == "number" and q.level > 0 then
        who = "level " .. q.level
      end
      r.who:SetText(who or "")
      y = y + 24
    end
  end
  if done > 0 then
    placeText("tiny", parent, x, y + 4, width, plural(done, "quest") .. " already done on this character.", "faint")
    y = y + 20
  end
  if not info.complete then
    placeText("tiny", parent, x, y + 4, width, "Only quests in someone's quest log. " .. hint, "faint")
    y = y + 34
  end
  return y
end

local function planColumn(parent, dungeon, x, y, width)
  y = section(parent, x, y, width, "Plan a run")
  placeText("small", parent, x, y, width, "Create a community event in the calendar with this title "
    .. "(click, Ctrl+C).", "textDim")
  y = y + 36
  titleBox:ClearAllPoints()
  titleBox:SetParent(parent)
  titleBox:SetPoint("TOPLEFT", x, -y)
  titleBox:SetWidth(math.max(80, width - 130))
  titleBox:SetText(ns.Dungeons.eventTitle(dungeon))
  titleBox:Show()
  local open = Kit.take(pools.buttons, parent)
  open:SetLabel("Open calendar")
  open:SetEnabled(true)
  open:SetScript("OnClick", function()
    if not ns.Calendar.open() then helpers.print("Open the calendar with the date button next to the minimap.") end
  end)
  open:SetPoint("TOPLEFT", x + math.max(80, width - 130) + 8, -(y + 1))
  return y + 38
end

local function renderDetail(entry, me, messageText)
  for _, name in ipairs({ "name", "section", "small", "tiny", "slots", "quests", "buttons", "primary" }) do
    Kit.release(pools[name])
  end
  titleBox:Hide()
  local parent = detail.child
  local width = math.max(420, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD - 4
  if not entry then
    placeText("small", parent, PAD, y, width, messageText or "", "textDim")
    parent:SetHeight(y + 60)
    detail:Update()
    return
  end

  local dungeon = entry.dungeon
  local title = placeText("name", parent, PAD, y, width, dungeon.name, "heading")
  local sub = "levels " .. range(dungeon)
  if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. " \194\183 " .. ns.Dungeons.ZONES[dungeon.id] end
  local tw = title.text.GetStringWidth and title.text:GetStringWidth() or 200
  placeText("small", parent, PAD + tw + 12, y + 10, width - tw - 12, sub, "muted")
  y = y + 40

  -- Planned runs of this dungeon (the next ones in the calendar).
  for _, e in ipairs(ns.Dungeons.events(ns.Planner.events(), dungeon, ns.Calendar.now())) do
    local parts = { ns.Dungeons.eventTime(e.startTime), e.title }
    parts[#parts + 1] = signUpText(e)
    parts[#parts + 1] = ns.Dungeons.signUp(e.inviteStatus)
    placeText("small", parent, PAD, y, width, table.concat(parts, " \194\183 "), "onlineText")
    y = y + 18
  end
  y = y + 4

  y = section(parent, PAD, y, width, "Suggested group")
  if not entry.fits then
    placeText("small", parent, PAD, y, width, string.format("%s is not in range.", tostring(me.name)), "muted")
    y = y + 20
  end
  local group = ns.Dungeons.suggest(entry)
  y = slots(parent, entry, group, y, width)
  local alternatives, others = ns.Dungeons.outside(entry, group)
  if #alternatives > 0 then
    local names = {}
    for i, c in ipairs(alternatives) do names[i] = classColored(c, c.name .. " " .. c.level) end
    placeText("tiny", parent, PAD, y, width, "Alternatives for you: " .. table.concat(names, ", "), "muted")
    y = y + 20
  end
  if entry.fits then y = askBlock(parent, entry, y + 2, width) end

  if #others > 0 then
    y = section(parent, PAD, y + 8, width, "Also in range")
    for _, c in ipairs(others) do
      local parts = { classColored(c, c.name .. " " .. c.level) }
      if c.role and ROLE_NAMES[c.role] then parts[#parts + 1] = ROLE_NAMES[c.role] end
      parts[#parts + 1] = c.displayName or "community member"
      if c.online then parts[#parts + 1] = "online" end
      placeText("small", parent, PAD, y, width, table.concat(parts, " \194\183 "), "textDim")
      y = y + 18
    end
  end

  local half = math.floor((width - 22) / 2)
  local top = y + 12
  local left = questColumn(parent, questInfo(entry), PAD, top, half)
  local right = planColumn(parent, dungeon, PAD + half + 22, top, half)
  parent:SetHeight(math.max(left, right) + PAD)
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
  column:SetWidth(Theme.SIZES.listWidth)
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

  -- The event title to copy: selected when clicked, so Ctrl+C copies it. Typing does not change it.
  titleBox = CreateFrame("EditBox", nil, detail.child)
  titleBox:SetHeight(28)
  titleBox:SetAutoFocus(false)
  titleBox:SetTextInsets(10, 10, 0, 0)
  Theme.font(titleBox, "small")
  titleBox:SetTextColor(Theme.color("text"))
  local boxBg = Theme.fill(titleBox, "input", "BACKGROUND")
  boxBg:SetAllPoints()
  titleBox.edges = Kit.edges(titleBox, "border")
  titleBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  titleBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  titleBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self.title then self:SetText(self.title) end
  end)
  local setText = titleBox.SetText
  function titleBox:SetText(text)
    self.title = text
    setText(self, text)
  end

  pools = {
    rows = Kit.pool(listRow), listText = Kit.pool(Kit.textHolder("tiny")),
    name = Kit.pool(Kit.textHolder("name")), section = Kit.pool(Kit.textHolder("section")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    slots = Kit.pool(slotFrame), quests = Kit.pool(questRow), buttons = Kit.pool(button),
    primary = Kit.pool(primary),
  }
  return root
end

-- Shown: the game's dungeons and level ranges (V46) and fresh calendar events (the window refreshes when
-- they arrive).
function DungeonsTab.show()
  if not root then return end
  root:Show()
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
  ns.Planner.request()
end

function DungeonsTab.hide() if root then root:Hide() end end

function DungeonsTab.select(value)
  status().selected = value
  helpers.render()
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
function DungeonsTab.render(view, messageText)
  if not root then return end
  entries = {}
  local me = ns.SelfInfo.read()
  if messageText then
    renderList({}, {}, me)
    renderDetail(nil, me, messageText)
    return
  end

  local planned = ns.Planner.planned()
  local include = {}
  for _, p in ipairs(planned) do include[p.dungeon.id] = true end
  local overview = ns.Dungeons.overview(ns.Dungeons.candidates(view), me.guid, include)
  local byId = {}
  for _, entry in ipairs(overview) do byId[entry.dungeon.id] = entry end
  local order = {}
  for i, p in ipairs(planned) do
    entries["planned:" .. i] = byId[p.dungeon.id]
    order[#order + 1] = "planned:" .. i
  end
  for _, entry in ipairs(overview) do
    if entry.fits then
      entries[entry.dungeon.id] = entry
      order[#order + 1] = entry.dungeon.id
    end
  end

  local st = status()
  if not st.selected or not entries[st.selected] then st.selected = order[1] end
  renderList(planned, overview, me)
  if not st.selected then
    renderDetail(nil, me, string.format("%s is not in a dungeon's level range yet. The first one, Ragefire "
      .. "Chasm, starts at level 13.", tostring(me.name)))
    return
  end
  renderDetail(entries[st.selected], me)
end

function DungeonsTab.reset()
  root, entries, rows = nil, {}, {}
end

-- For the specs: the list rows, the card's texts (in pool order), its buttons by label, the title box.
function DungeonsTab.rows() return rows end
function DungeonsTab.titleBox() return titleBox end

function DungeonsTab.texts()
  local out = {}
  for _, name in ipairs({ "listText", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "rows", "slots", "quests" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "name", "right", "meta", "info", "mark", "who" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
    end
  end
  return out
end

function DungeonsTab.buttons()
  local out = {}
  for _, name in ipairs({ "buttons", "primary" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  return out
end

function DungeonsTab.questRows()
  local out = {}
  for i = 1, pools and pools.quests.used or 0 do out[i] = pools.quests.items[i] end
  return out
end

function DungeonsTab.slots()
  local out = {}
  for i = 1, pools and pools.slots.used or 0 do out[i] = pools.slots.items[i] end
  return out
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
