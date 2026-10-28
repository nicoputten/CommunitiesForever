-- FriendsTab: the Friends tab in the revamp's look (CF-40; design docs/design/revamp-2026-10/friends.html).
-- Native frames from the kit: on the left the search box and the list (a header per person with a fold arrow,
-- character rows), on the right the card of the selected person or character. Both scroll (Kit.scrollArea).
-- Selection and folded groups stay in settings.tree (the keys the AceGUI tree used, rule 8). Frames come from
-- pools and are reused on every render: WoW frames cannot be destroyed.
local _, ns = ...

local FriendsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20                -- card padding
local LIST_PAD = 10           -- list padding
local INDENT = 22             -- character rows under their person
local ADDON_ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local LINE = { name = 28, body = 17, small = 16, tiny = 14, section = 22, group = 20 }

local root, list, detail, search, searchHint, countText
local helpers -- from MainFrame: settings(), classInfo(classFile, classID), rightClickMenu(frame, path),
              -- menuItem(item), filterText(), setFilter(text), render(), showAllQuests, joinInfo(), filterHint
local view, nodes
local rows = {}  -- visible list rows: { kind = "group" | "char", path, frame }

-- ===== Pools (Kit.pool) =====

local pool, take, release, textFactory = Kit.pool, Kit.take, Kit.release, Kit.textHolder

local listPools, cardPools

local placeText = Kit.placeText

-- ===== Helpers =====

local function classColor(classFile, classID)
  local file = helpers.classInfo(classFile, classID)
  return { Kit.classColor(file) }, file
end

local function className(classFile, classID)
  local _, name = helpers.classInfo(classFile, classID)
  return name
end

local function status() return helpers.settings().tree end

-- ===== List =====

local function groupFactory(parent)
  local h = CreateFrame("Button", nil, parent)
  h:SetHeight(26)
  h.arrow = CreateFrame("Button", nil, h)
  h.arrow:SetSize(18, 18)
  h.arrow:SetPoint("LEFT", 6, 0)
  h.arrowIcon = h.arrow:CreateTexture(nil, "ARTWORK")
  h.arrowIcon:SetSize(10, 10)
  h.arrowIcon:SetPoint("CENTER")
  h.arrowIcon:SetTexture(Theme.TEXTURES.arrow)
  h.arrowIcon:SetVertexColor(Theme.color("muted"))
  h.dot = h:CreateTexture(nil, "ARTWORK")
  h.dot:SetSize(7, 7)
  h.dot:SetPoint("LEFT", h.arrow, "RIGHT", 2, 0)
  h.dot:SetTexture(Theme.TEXTURES.circle)
  h.name = Theme.text(h, "group", "goldLight")
  h.name:SetPoint("LEFT", h.dot, "RIGHT", 7, 0)
  h.mark = h:CreateTexture(nil, "ARTWORK")
  h.mark:SetSize(12, 12)
  h.mark:SetPoint("LEFT", h.name, "RIGHT", 5, 0)
  h.mark:SetTexture(ADDON_ICON)
  h.count = Theme.text(h, "small", "faint")
  h.count:SetPoint("RIGHT", -10, 0)
  local hover = h:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  h.selectedBg = Theme.fill(h, "selected", "BACKGROUND")
  h.selectedBg:SetAllPoints()
  return h
end

local function charFactory(parent)
  local r = Kit.listRow(parent)
  r.portrait = Kit.portrait(r, Theme.SIZES.portraitSmall)
  r.portrait:SetPoint("LEFT", INDENT, 0)
  r.name = Theme.text(r, "body", "text")
  r.name:SetPoint("LEFT", r.portrait, "RIGHT", 8, 0)
  r.level = Theme.text(r, "small", "muted")
  r.level:SetPoint("RIGHT", -10, 0)
  r.questIcon = r:CreateTexture(nil, "ARTWORK")
  r.questIcon:SetSize(11, 11)
  r.questIcon:SetTexture(Theme.TEXTURES.quest)
  r.questIcon:SetVertexColor(Theme.color("goldLight"))
  r.questCount = Theme.text(r, "tiny", "goldLight")
  r.questCount:SetPoint("RIGHT", r.level, "LEFT", -6, 0)
  r.questIcon:SetPoint("RIGHT", r.questCount, "LEFT", -2, 0)
  r:SetScript("OnClick", function(self) FriendsTab.select(self.path) end)
  helpers.rightClickMenu(r, function() return r.path end) -- CF-37, reads the row's current path
  return r
end

local function folded(value)
  local groups = status().groups or {}
  return groups[value] == false
end

local function renderList(selected)
  release(listPools.groups)
  release(listPools.chars)
  rows = {}
  local parent = list.child
  local y = 2
  for _, node in ipairs(nodes) do
    local h = take(listPools.groups, parent)
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetPoint("RIGHT", parent, "RIGHT")
    h.path = node.value
    h.name:SetText(node.text)
    h.count:SetText(tostring(node.count or #node.children))
    if node.unlinked then h.dot:Hide() else
      h.dot:Show()
      h.dot:SetVertexColor(Theme.color(node.online and "online" or "faint"))
    end
    if node.usesAddon and not node.isSelf then h.mark:Show() else h.mark:Hide() end
    if node.value == selected then h.selectedBg:Show() else h.selectedBg:Hide() end
    local isFolded = folded(node.value)
    if h.arrowIcon.SetRotation then h.arrowIcon:SetRotation(isFolded and math.pi / 2 or 0) end
    h.arrow:SetScript("OnClick", function() FriendsTab.toggle(node.value) end)
    h:SetScript("OnClick", function()
      if node.unlinked then FriendsTab.toggle(node.value) else FriendsTab.select(node.value) end
    end)
    if not node.unlinked then helpers.rightClickMenu(h, function() return h.path end) end
    rows[#rows + 1] = { kind = "group", path = node.value, frame = h, node = node }
    y = y + 26
    if not isFolded then
      for _, c in ipairs(node.children) do
        local r = take(listPools.chars, parent)
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("RIGHT", parent, "RIGHT")
        r.path = node.value .. "\001" .. c.value
        local rgb, file = classColor(c.classFile, c.classID)
        r.portrait:SetClass(file)
        r.portrait:SetOnline(c.online)
        r.name:SetText(ns.Format.truncate(c.name, 24))
        r.name:SetTextColor(rgb[1], rgb[2], rgb[3], 1)
        r.level:SetText(tostring(c.level or "?"))
        if c.shared and c.shared > 0 then
          r.questIcon:Show()
          r.questCount:Show()
          r.questCount:SetText(tostring(c.shared))
        else
          r.questIcon:Hide()
          r.questCount:Hide()
        end
        r:SetSelected(r.path == selected)
        rows[#rows + 1] = { kind = "char", path = r.path, frame = r, node = c }
        y = y + Theme.SIZES.row
      end
    end
    y = y + 4
  end
  parent:SetHeight(y)
  list:Update()
end

-- ===== Card =====

local function buttonFactory(parent) return Kit.button(parent, "", nil) end
local function barFactory(parent) return Kit.skillBar(parent) end
local function portraitFactory(parent) return Kit.portrait(parent, Theme.SIZES.portraitLarge) end

local function tileFactory(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetHeight(60)
  local bg = t:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(Theme.color("white", 0.03))
  t.edges = Kit.edges(t, "divider")
  t.label = Theme.text(t, "label", "faint")
  t.label:SetPoint("TOPLEFT", 12, -8)
  t.value = Theme.text(t, "number", "heading")
  t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
  t.note = Theme.text(t, "tiny", "muted")
  t.note:SetPoint("BOTTOMLEFT", 12, 8)
  t.bar = Kit.skillBar(t, 4)
  t.bar:SetPoint("BOTTOMLEFT", 12, 9)
  t.bar:SetPoint("BOTTOMRIGHT", -12, 9)
  return t
end

-- A clickable line of text ("Show all 14 ->", a character on a person card).
local function linkFactory(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.text = Theme.text(b, "small", "gold")
  b.text:SetPoint("LEFT")
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  return b
end

local function cardWidth()
  return math.max(300, (detail:GetWidth() or 0) - 2 * PAD - 6)
end

local function section(parent, x, y, width, text, note)
  return Kit.section(cardPools.section, cardPools.small, parent, x, y, width, text, note)
end

-- Professions and talents side by side (the design's 1.25 : 1 columns).
local function skillColumns(parent, d, y, width)
  local left = math.floor(width * 0.55)
  local right = width - left - 22
  local rx = PAD + left + 22
  local ly = section(parent, PAD, y, left, "Professions")
  if #d.professions == 0 then
    placeText(cardPools.small, parent, PAD, ly, left, "No professions known.", "muted")
    ly = ly + LINE.small
  end
  for _, group in ipairs(d.professions) do
    local secondary = group.title == "Secondary"
    for _, p in ipairs(group.list) do
      placeText(cardPools.small, parent, PAD, ly, 104, tostring(p.name), secondary and "textDim" or "text")
      local bar = take(cardPools.bars, parent)
      bar:SetPoint("TOPLEFT", PAD + 112, -(ly + 5))
      bar:SetWidth(math.max(40, left - 112 - 66))
      local spec = ns.Card.skillBar(p, secondary)
      local color = spec.muted and { Theme.color("muted") } or nil
      bar:SetValues(spec.fill * ns.Card.SKILL_SCALE, ns.Card.SKILL_SCALE, spec.cap * ns.Card.SKILL_SCALE,
        spec.ticks, color)
      placeText(cardPools.small, parent, PAD + left - 58, ly, 58,
        string.format("%s / %s", tostring(p.rank), tostring(p.max)), "textDim")
      ly = ly + 19
    end
  end

  local talents = d.talents
  local ry = section(parent, rx, y, right, "Talents", talents and talents.numbers or nil)
  if not d.talentBars then
    placeText(cardPools.small, parent, rx, ry, right, "No talent data yet. It appears after this character logs in "
      .. "with the addon.", "muted")
    ry = ry + 2 * LINE.small
  else
    for _, tree in ipairs(d.talentBars) do
      placeText(cardPools.small, parent, rx, ry, 84, tree.name, tree.main and "goldPale" or "faint")
      local bar = take(cardPools.bars, parent)
      bar:SetPoint("TOPLEFT", rx + 88, -(ry + 5))
      bar:SetWidth(math.max(30, right - 88 - 30))
      bar:SetValues(tree.fraction * 100, 100, 0, {}, nil)
      placeText(cardPools.small, parent, rx + right - 24, ry, 24, tostring(tree.points),
        tree.main and "text" or "faint")
      ry = ry + 19
    end
  end
  return math.max(ly, ry)
end

local function sharedQuests(parent, shared, y, width, path)
  if not shared then return y end
  y = section(parent, PAD, y + 6, width, "Quests you share",
    shared.total > 0 and string.format("%d \194\183 grouped by where they are", shared.total) or nil)
  if shared.total == 0 then
    placeText(cardPools.small, parent, PAD, y, width, "No shared quests.", "muted")
    return y + LINE.small
  end
  for _, area in ipairs(shared.areas) do
    local title = placeText(cardPools.group, parent, PAD, y + 2, width, tostring(area.area), "goldLight")
    if area.dungeon then
      local tag = placeText(cardPools.tiny, parent, PAD, y + 4, 80, "DUNGEON", "dungeonTag")
      local w = title.text.GetStringWidth and title.text:GetStringWidth() or 120
      tag:ClearAllPoints()
      tag:SetPoint("TOPLEFT", PAD + w + 8, -(y + 5))
    end
    y = y + LINE.group + 2
    for _, quest in ipairs(area.quests) do
      local who
      local faint = Theme.code("faint")
      if quest.theirChars then
        local theirs, mine = {}, {}
        for _, c in ipairs(quest.theirChars) do theirs[#theirs + 1] = tostring(c.name) end
        for _, c in ipairs(quest.ownChars or {}) do mine[#mine + 1] = tostring(c.name) end
        who = string.format("%s \194\183 them|r %s %s\194\183 you|r %s", faint, table.concat(theirs, ", "), faint,
          table.concat(mine, ", "))
      else
        local mine = {}
        for _, c in ipairs(quest.ownChars or {}) do mine[#mine + 1] = tostring(c.name) end
        who = string.format("%s \194\183 you on|r %s", faint, table.concat(mine, ", "))
      end
      placeText(cardPools.small, parent, PAD + 12, y, width - 12, tostring(quest.title) .. who, "textDim")
      y = y + LINE.small + 2
    end
  end
  if shared.expandable and path then
    local link = take(cardPools.links, parent)
    link:SetPoint("TOPLEFT", PAD, -(y + 2))
    link.text:SetText(shared.showAll and "Show fewer" or string.format("Show all %d \226\134\146", shared.total))
    link:SetWidth(200)
    link:SetScript("OnClick", function()
      helpers.showAllQuests[path] = not helpers.showAllQuests[path] or nil
      helpers.render()
    end)
    y = y + 22
  end
  return y
end

-- Header of a character card: portrait, name, class and where they are, Whisper and Invite.
local function characterHeader(parent, d, y, width, path)
  local rgb, file = classColor(d.classFile, d.classID)
  local p = take(cardPools.portraits, parent)
  p:SetPoint("TOPLEFT", PAD, -y)
  p:SetClass(file)
  p:SetOnline(d.online)
  placeText(cardPools.name, parent, PAD + 66, y + 2, width - 66 - 170, d.name, rgb)
  local cls = className(d.classFile, d.classID)
  placeText(cardPools.small, parent, PAD + 66, y + 32, width - 66, (cls and (cls .. " \194\183 ") or "") .. d.subtitle,
    "textDim")
  -- Whisper and Invite: the right-click menu's actions (CF-37); disabled offline and on your own characters.
  local menu = ns.Format.contextMenu(view, path)
  local items = menu and menu.items or { { label = ns.Format.MENU_WHISPER }, { label = ns.Format.MENU_INVITE } }
  local right = PAD + width
  for i = #items, 1, -1 do
    local item = items[i]
    local b = take(cardPools.buttons, parent)
    b:SetLabel(item.label == ns.Format.MENU_INVITE and "Invite" or "Whisper")
    b:SetScript("OnClick", function() helpers.menuItem(item) end)
    b:SetEnabled(item.enabled == true)
    b:SetPoint("TOPRIGHT", parent, "TOPLEFT", right, -(y + 12))
    right = right - (b:GetWidth() or 70) - 8
  end
  return y + 52 + 14
end

local function tiles(parent, d, y, width)
  local gap = 10
  local w = math.floor((width - 2 * gap) / 3)
  for i, tile in ipairs(d.tiles) do
    local t = take(cardPools.tiles, parent)
    t:SetPoint("TOPLEFT", PAD + (i - 1) * (w + gap), -y)
    t:SetWidth(w)
    t.label:SetText(tile.label:upper())
    t.value:SetText(tile.value)
    if tile.fraction then
      t.bar:Show()
      local rgb = classColor(d.classFile, d.classID)
      t.bar:SetValues(tile.fraction * 100, 100, 0, {}, rgb)
      t.note:Hide()
    else
      t.bar:Hide()
      t.note:SetText(tile.note or "")
      t.note:Show()
    end
  end
  return y + 60 + 16
end

local renderCard = {}

function renderCard.message(parent, d, width)
  placeText(cardPools.body, parent, PAD, PAD, width, d.text, "textDim")
  local y = PAD + 2 * LINE.body
  local join = helpers.joinInfo and helpers.joinInfo()
  if join then
    placeText(cardPools.section, parent, PAD, y, width, join.title, "goldLight")
    y = y + LINE.section
    for _, line in ipairs(join.lines) do
      placeText(cardPools.small, parent, PAD, y, width, line, "textDim")
      y = y + LINE.small + 2
    end
    local b = take(cardPools.buttons, parent)
    b:SetLabel(join.button)
    b:SetEnabled(true)
    b:SetScript("OnClick", join.onClick)
    b:SetPoint("TOPLEFT", PAD, -(y + 6))
    y = y + 40
  end
  return y
end

function renderCard.character(parent, d, width, path)
  local y = characterHeader(parent, d, PAD - 4, width, path)
  y = tiles(parent, d, y, width)
  if d.pvp then -- CF-57
    placeText(cardPools.small, parent, PAD, y - 4, width - 2 * PAD, d.pvp, "goldLight")
    y = y + 22
  end
  y = skillColumns(parent, d, y, width) + 14
  return sharedQuests(parent, d.sharedQuests, y, width, path)
end

-- A person's characters, one clickable line each (CF-40: also right-click).
local function characterLines(parent, characters, groupValue, y, width)
  for _, c in ipairs(characters) do
    local line = take(cardPools.charLines, parent)
    line:SetPoint("TOPLEFT", PAD, -y)
    line:SetWidth(width)
    local rgb, file = classColor(c.classFile, c.classID)
    line.portrait:SetClass(file)
    line.portrait:SetOnline(c.seen == "Now")
    line.name:SetText(tostring(c.name))
    line.name:SetTextColor(rgb[1], rgb[2], rgb[3], 1)
    local parts = { "Level " .. tostring(c.level or "?") }
    if c.role then parts[#parts + 1] = ns.Card.ROLE_NAMES[c.role] or c.role end
    parts[#parts + 1] = c.seen == "Now" and "online" or ((c.own and "played " or "seen ") .. tostring(c.seen))
    if c.outside then parts[#parts + 1] = "not in community" end
    line.info:SetText(table.concat(parts, " \194\183 "))
    line.path = groupValue .. "\001" .. c.guid
    y = y + Theme.SIZES.row
  end
  return y
end

local function charLineFactory(parent)
  local r = Kit.listRow(parent)
  r.portrait = Kit.portrait(r, Theme.SIZES.portraitSmall)
  r.portrait:SetPoint("LEFT", 4, 0)
  r.name = Theme.text(r, "body", "text")
  r.name:SetPoint("LEFT", r.portrait, "RIGHT", 8, 0)
  r.info = Theme.text(r, "small", "muted")
  r.info:SetPoint("LEFT", r.name, "RIGHT", 10, 0)
  r:SetScript("OnClick", function(self) FriendsTab.select(self.path) end)
  helpers.rightClickMenu(r, function() return r.path end)
  return r
end

function renderCard.person(parent, d, width, path)
  local y = PAD - 4
  placeText(cardPools.name, parent, PAD, y, width, d.title, "heading")
  y = y + LINE.name + 4
  local sub = {}
  if d.battleTag then sub[#sub + 1] = d.battleTag end
  if d.source then sub[#sub + 1] = d.source end
  if #sub > 0 then
    placeText(cardPools.small, parent, PAD, y, width, table.concat(sub, " \194\183 "), "faint")
    y = y + LINE.small + 2
  end
  if d.addon then
    placeText(cardPools.small, parent, PAD, y, width, d.addon, "faint")
    y = y + LINE.small + 2
  end
  local statusLine = d.status
  if d.current and d.online then
    statusLine = "Online on " .. tostring(d.current.name)
      .. ((d.current.visible == false or d.current.outside) and " (not in community)" or "")
  end
  placeText(cardPools.body, parent, PAD, y + 4, width, statusLine, d.online and "onlineText" or "textDim")
  y = section(parent, PAD, y + LINE.body + 14, width, "Characters")
  y = characterLines(parent, d.characters, path, y, width) + 10
  return sharedQuests(parent, d.sharedQuests, y, width, path)
end

function renderCard.unlinked(parent, d, width, path)
  local y = PAD - 4
  placeText(cardPools.name, parent, PAD, y, width, "Unlinked", "heading")
  y = y + LINE.name + 4
  placeText(cardPools.small, parent, PAD, y, width, "Community members not linked to one of your Battle.net friends.",
    "faint")
  y = section(parent, PAD, y + LINE.small + 12, width, "Characters")
  return characterLines(parent, d.characters, path, y, width)
end

local function renderDetail(d, path)
  for _, p in pairs(cardPools) do release(p) end
  local parent = detail.child
  local width = cardWidth()
  local height = renderCard[d.kind](parent, d, width, path)
  local hint = d.kind ~= "message" and ns.Format.friendsHint(view)
  if hint then
    placeText(cardPools.small, parent, PAD, height + 14, width, hint, "faint")
    height = height + 14 + 2 * LINE.small
  end
  parent:SetHeight(height + PAD)
  detail:Update()
end

-- ===== Public =====

function FriendsTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  -- List column.
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

  -- Search box (CF-36) with its grey placeholder and the count.
  search = CreateFrame("EditBox", nil, column)
  search:SetPoint("TOPLEFT", LIST_PAD, -LIST_PAD)
  search:SetPoint("TOPRIGHT", -LIST_PAD, -LIST_PAD)
  search:SetHeight(28)
  search:SetAutoFocus(false)
  search:SetTextInsets(24, 8, 0, 0)
  Theme.font(search, "small")
  search:SetTextColor(Theme.color("text"))
  local searchBg = Theme.fill(search, "input", "BACKGROUND")
  searchBg:SetAllPoints()
  search.edges = Kit.edges(search, "divider")
  searchHint = Theme.text(search, "small", "faint")
  searchHint:SetPoint("LEFT", 24, 0)
  searchHint:SetText(h.filterHint)
  countText = Theme.text(column, "tiny", "faint")
  countText:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -4)
  local function updateHint(self)
    local empty = (self:GetText() or "") == ""
    if empty and not (self.HasFocus and self:HasFocus()) then searchHint:Show() else searchHint:Hide() end
  end
  search:SetScript("OnTextChanged", function(self, userInput)
    updateHint(self)
    if userInput then helpers.setFilter(self:GetText() or "") end
  end)
  search:SetScript("OnEditFocusGained", updateHint)
  search:SetScript("OnEditFocusLost", updateHint)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  list = Kit.scrollArea(column)
  list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -LIST_PAD, -20)
  list:SetPoint("BOTTOMRIGHT", 0, 4)

  -- Card.
  detail = Kit.scrollArea(root)
  detail:SetPoint("TOPLEFT", column, "TOPRIGHT", 0, 0)
  detail:SetPoint("BOTTOMRIGHT")

  listPools = { groups = pool(groupFactory), chars = pool(charFactory) }
  cardPools = {
    name = pool(textFactory("name")), section = pool(textFactory("section")), group = pool(textFactory("group")),
    body = pool(textFactory("body")), small = pool(textFactory("small")), tiny = pool(textFactory("tiny")),
    buttons = pool(buttonFactory), bars = pool(barFactory), tiles = pool(tileFactory),
    portraits = pool(portraitFactory), links = pool(linkFactory), charLines = pool(charLineFactory),
  }
  return root
end

function FriendsTab.show() if root then root:Show() end end
function FriendsTab.hide() if root then root:Hide() end end

--[[ Draws the tab. v: the view model; empty: the window's empty-state text (no community etc.) or nil. The
filter (CF-36) narrows the list; the card always shows the whole person. ]]
function FriendsTab.render(v, empty)
  if not root then return end
  view = v
  local text = helpers.filterText()
  if search:GetText() ~= text then search:SetText(text) end
  if empty then
    nodes = {}
    renderList(nil)
    countText:SetText("")
    renderDetail({ kind = "message", text = empty }, nil)
    return
  end
  local terms = ns.Filter.parse(text)
  local shownView, shown, total = ns.Filter.apply(view, terms)
  nodes = ns.Format.tree(shownView)
  local st = status()
  st.groups = st.groups or {}
  if #terms > 0 then
    for _, node in ipairs(nodes) do st.groups[node.value] = true end -- matches show unfolded
  end
  countText:SetText(#terms > 0 and string.format("%d of %d", shown, total) or "")

  local selected = st.selected
  if not selected or ns.Card.detail(shownView, selected, GetServerTime()).kind == "message" then
    selected = nodes[1] and nodes[1].value
  end
  st.selected = selected
  renderList(selected)
  if #terms > 0 and #nodes == 0 then
    renderDetail({ kind = "message", text = string.format("No character matches \"%s\".", text) }, nil)
    return
  end
  renderDetail(ns.Card.detail(view, selected, GetServerTime(), selected and helpers.showAllQuests[selected]),
    selected)
end

function FriendsTab.select(path)
  status().selected = path
  helpers.render()
end

-- Folds or unfolds a person (false in settings.tree.groups = folded, like the AceGUI tree).
function FriendsTab.toggle(value)
  local st = status()
  st.groups = st.groups or {}
  st.groups[value] = folded(value)
  helpers.render()
end

-- For the specs: the visible list rows, the search box, and the card's visible texts and buttons.
function FriendsTab.rows() return rows end
function FriendsTab.searchBox() return search end
function FriendsTab.countText() return countText and countText:GetText() or "" end

local TEXT_POOLS = { "name", "body", "small", "section", "group", "tiny", "tiles", "charLines", "links", "buttons" }

function FriendsTab.cardTexts()
  local out = {}
  for _, poolName in ipairs(cardPools and TEXT_POOLS or {}) do
    local p = cardPools[poolName]
    for i = 1, p.used do
      local item = p.items[i]
      for _, key in ipairs({ "text", "name", "info", "label", "value", "note" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
    end
  end
  return out
end

function FriendsTab.cardButtons()
  local out = {}
  for i = 1, cardPools and cardPools.buttons.used or 0 do
    local b = cardPools.buttons.items[i]
    out[b.label:GetText()] = b
  end
  return out
end

function FriendsTab.cardLines()
  local out = {}
  for i = 1, cardPools and cardPools.charLines.used or 0 do out[i] = cardPools.charLines.items[i] end
  return out
end

ns.FriendsTab = FriendsTab
return FriendsTab
