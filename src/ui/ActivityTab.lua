-- ActivityTab: the Activity tab in the revamp's look (CF-41; design docs/design/revamp-2026-10/activity.html).
-- Native frames from the kit: filter chips on top, then per day a header and one entry per person (or per
-- group that played together): portrait, who and on which character, what they did as a row of chips, pills
-- and text, and the time on the right. The feed model is Feed.days / Feed.filter; this file only draws it.
local _, ns = ...

local ActivityTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 24              -- side padding, as the design
local AVATAR = 44           -- the portrait column
local ROW_GAP = 6           -- between the pieces of a line
local ROW_HEIGHT = 20       -- one row of pieces
local TIME_WIDTH = 48
local NOTE = "Activity is shared only by friends who turned on \"Share my activity\"."

local root, chipsBar, scroll, chips
local helpers -- from MainFrame: settings(), render()
local filter = "all"   -- the active chip, while the window is open
local expanded = {}    -- day:key -> true: the other characters shown, until /reload
local pools

-- ===== Helpers =====

local function gold(text) return Theme.code("goldLight") .. tostring(text) .. "|r" end
local function dim(text) return Theme.code("textDim") .. tostring(text) .. "|r" end

local function charText(char)
  return Theme.rgbCode(Kit.classColor(char and char.classFile)) .. tostring(char and char.name or "?") .. "|r"
end

-- "20:40": the local time of the entry's last change. `date` is the game's (unverified, V63).
local function clock(at)
  if not at or at <= 0 or not date then return "" end
  return date("%H:%M", at)
end

-- "22 → 24" with the bundled font; the game font has no arrow.
local function levelText(piece)
  local arrow = Theme.bundledFonts() and " \226\134\146 " or " - "
  return tostring(piece.from) .. arrow .. tostring(piece.to)
end

-- Community members by GUID (CF-23), so companions without a linked person show by name.
local function members(view)
  local list = {}
  for _, row in ipairs(view.unlinked or {}) do
    if row.guid and row.name then list[row.guid] = row.name end
  end
  return list
end

-- ===== Factories =====

-- Filter chip: a rounded-looking pill with a thin border; the active one gold.
local function filterChip(parent, def)
  local c = CreateFrame("Button", nil, parent)
  c:SetHeight(24)
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetAllPoints()
  c.edges = Kit.edges(c, "divider")
  c.text = Theme.text(c, "small", "textDim")
  c.text:SetPoint("CENTER")
  c.text:SetText(def.text)
  c.value = def.value
  c:SetWidth(math.max(44, (c.text.GetStringWidth and c.text:GetStringWidth() or 40) + 22))
  local hover = c:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  function c:SetActive(on)
    self.active = on and true or false
    if self.active then
      self.bg:SetColorTexture(Theme.color("gold", 0.16))
      for _, e in ipairs(self.edges) do e:SetColorTexture(Theme.color("gold")) end
      self.text:SetTextColor(Theme.color("heading"))
    else
      self.bg:SetColorTexture(0, 0, 0, 0)
      for _, e in ipairs(self.edges) do e:SetColorTexture(Theme.color("divider")) end
      self.text:SetTextColor(Theme.color("textDim"))
    end
  end
  c:SetScript("OnClick", function(self) ActivityTab.setFilter(self.value) end)
  return c
end

-- The LEVEL UP chip: gold with dark text, and a slow shine while Ambient effects are on (CF-43).
local function levelChip(parent)
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(18)
  local bg = Theme.fill(c, "goldPale", "BACKGROUND")
  bg:SetAllPoints()
  c.text = Theme.text(c, "chip", "outline")
  c.text:SetPoint("CENTER")
  c.shine = Kit.shine(c, c, 2.1)
  return c
end

-- A zone pill: faint background, small light text.
local function pill(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetHeight(18)
  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(Theme.color("white", 0.05))
  p.text = Theme.text(p, "tiny", "textDim")
  p.text:SetPoint("CENTER")
  return p
end

local function line(parent)
  local l = CreateFrame("Frame", nil, parent)
  l:SetHeight(1)
  l.fill = Theme.fill(l, "divider", "BORDER")
  l.fill:SetAllPoints()
  return l
end

local function link(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.text = Theme.text(b, "small", "gold")
  b.text:SetPoint("LEFT")
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  return b
end

local function portrait(parent) return Kit.portrait(parent, Theme.SIZES.portraitMedium) end

-- ===== Drawing =====

local placeText = Kit.placeText

local function textWidth(fs)
  return fs.GetStringWidth and fs:GetStringWidth() or 0
end

--[[ Lays the pieces of one character's day out left to right, wrapping into rows: a level change as the
LEVEL UP chip, questing as "questing in" + zone pills + "+N zones" + "· N quests done", the rest as text.
Returns the height used. ]]
local function flow(parent, pieces, x0, y0, width)
  local items = {}
  for i, piece in ipairs(pieces) do
    if i > 1 then items[#items + 1] = { kind = "text", text = "\194\183", color = "faint" } end
    if piece.kind == "level" then
      items[#items + 1] = { kind = "chip", text = levelText(piece) }
    elseif piece.kind == "questing" then
      items[#items + 1] = { kind = "text", text = "questing in" }
      for _, zone in ipairs(piece.zones) do items[#items + 1] = { kind = "pill", text = zone } end
      if piece.moreZones > 0 then
        items[#items + 1] = { kind = "pill", text = string.format("+%d %s", piece.moreZones,
          piece.moreZones == 1 and "zone" or "zones") }
      end
      items[#items + 1] = { kind = "text", text = string.format("\194\183 %d %s done", piece.quests,
        piece.quests == 1 and "quest" or "quests") }
    else
      items[#items + 1] = { kind = "text", text = piece.text }
    end
  end
  local x, y = 0, 0
  for _, item in ipairs(items) do
    local frame, w
    if item.kind == "chip" or item.kind == "pill" then
      frame = Kit.take(item.kind == "chip" and pools.chips or pools.pills, parent)
      frame.text:SetText(item.text)
      w = textWidth(frame.text) + 14
      frame:SetWidth(w)
      if frame.shine then frame.shine:Refresh() end
    else
      frame = Kit.take(pools.small, parent)
      frame.text:SetWidth(0)
      frame.text:SetText(item.text)
      frame.text:SetTextColor(Theme.color(item.color or "muted"))
      w = textWidth(frame.text)
    end
    if x > 0 and x + w > width then
      x, y = 0, y + ROW_HEIGHT
    end
    frame:SetPoint("TOPLEFT", x0 + x, -(y0 + y + (item.kind == "text" and 2 or 0)))
    x = x + w + ROW_GAP
  end
  return #items > 0 and (y + ROW_HEIGHT) or 0
end

local function avatars(parent, chars, x, y)
  for i, char in ipairs(chars) do
    if i > 2 then break end
    local p = Kit.take(pools.portraits, parent)
    p:SetPoint("TOPLEFT", x + (i - 1) * 14, -y)
    p:SetClass(char.classFile)
    p:SetOnline(false)
  end
end

-- One entry. Returns its height.
local function entry(parent, dayValue, l, y, width)
  local key = dayValue .. ":" .. tostring(l.key or l.battleTag or "self")
  local textX = PAD + AVATAR + 12
  local textWidthMax = width - textX - TIME_WIDTH - PAD
  avatars(parent, l.shared and l.chars or { l.char }, PAD, y + 10)

  local who
  if l.shared then
    local names = {}
    for i, name in ipairs(l.names or { l.title }) do names[i] = gold(name) end
    who = (#names == 2 and table.concat(names, dim(" and ")) or table.concat(names, dim(", "))) .. dim(" together")
  else
    who = gold(l.displayName) .. dim(" on ") .. charText(l.char)
    if l.extraChars > 0 then
      who = who .. dim(string.format(" and %d more %s", l.extraChars, l.extraChars == 1 and "character" or
        "characters"))
    end
  end
  placeText(pools.body, parent, textX, y + 10, textWidthMax, who, "textDim")
  placeText(pools.tiny, parent, width - PAD - TIME_WIDTH, y + 12, TIME_WIDTH, clock(l.at), "faint", "RIGHT")
  local h = 10 + 19
  h = h + flow(parent, l.pieces or {}, textX, y + h, textWidthMax)

  if l.extraChars > 0 then
    if expanded[key] then
      for _, other in ipairs(l.others) do
        placeText(pools.small, parent, textX, y + h + 2, textWidthMax, dim("on ") .. charText(other.char), "textDim")
        h = h + 19
        h = h + flow(parent, other.pieces or {}, textX + 14, y + h, textWidthMax - 14)
      end
    end
    local hidden = 0
    for _, other in ipairs(l.others) do hidden = hidden + #(other.pieces or other.parts or {}) end
    local b = Kit.take(pools.links, parent)
    b:SetPoint("TOPLEFT", textX, -(y + h + 2))
    b.text:SetText(expanded[key] and "Show less" or string.format("Show all (%d)", hidden))
    b:SetWidth(textWidth(b.text) + 8)
    b:SetScript("OnClick", function()
      expanded[key] = not expanded[key] or nil
      helpers.render()
    end)
    h = h + 22
  end
  h = math.max(h + 10, 52)
  local sep = Kit.take(pools.lines, parent)
  sep:SetPoint("TOPLEFT", PAD, -(y + h - 1))
  sep:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
  sep.fill:SetColorTexture(Theme.color("white", 0.05))
  return h
end

local function dayHeader(parent, label, y, width)
  placeText(pools.day, parent, PAD, y + 14, width - 2 * PAD, label, "goldLight")
  local sep = Kit.take(pools.lines, parent)
  sep:SetPoint("TOPLEFT", PAD, -(y + 38))
  sep:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
  sep.fill:SetColorTexture(Theme.color("divider"))
  return 40
end

local lastRender = {} -- for the specs: the days drawn

-- ===== Public =====

function ActivityTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  chipsBar = CreateFrame("Frame", nil, root)
  chipsBar:SetPoint("TOPLEFT", PAD, -14)
  chipsBar:SetPoint("TOPRIGHT", -PAD, -14)
  chipsBar:SetHeight(24)
  chips = {}
  local previous
  for _, def in ipairs(ns.Feed.FILTERS) do
    local c = filterChip(chipsBar, def)
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
    chips = Kit.pool(levelChip), pills = Kit.pool(pill), lines = Kit.pool(line), links = Kit.pool(link),
    portraits = Kit.pool(portrait),
  }
  return root
end

function ActivityTab.show() if root then root:Show() end end
function ActivityTab.hide() if root then root:Hide() end end

-- The window was closed: the chips start at All next time.
function ActivityTab.reset()
  filter = "all"
end

function ActivityTab.setFilter(value)
  filter = value
  helpers.render()
end

function ActivityTab.filter() return filter end

-- Draws the tab. view: the view model; empty: the window's empty-state text or nil.
function ActivityTab.render(view, empty)
  if not root then return end
  for value, c in pairs(chips) do c:SetActive(value == filter) end
  for _, p in pairs(pools) do Kit.release(p) end
  local parent = scroll.child
  local width = math.max(400, scroll:GetWidth() or 0)
  local y = 0

  local all = empty and {} or ns.Feed.days(view.people, ns.FeedTracker.today(), members(view))
  local days = ns.Feed.filter(all, filter)
  lastRender = days
  if empty then
    placeText(pools.body, parent, PAD, y + 14, width - 2 * PAD, empty, "textDim")
    y = y + 40
  elseif #all == 0 then
    placeText(pools.body, parent, PAD, y + 14, width - 2 * PAD, "No activity yet. Levels, quests, professions, "
      .. "dungeons and "
      .. "battlegrounds of you and your friends show up here.", "textDim", width - 2 * PAD)
    y = y + 50
  elseif #days == 0 then
    placeText(pools.body, parent, PAD, y + 14, width - 2 * PAD, "Nothing of this kind in the last 7 days.", "textDim")
    y = y + 40
  end
  for _, day in ipairs(days) do
    y = y + dayHeader(parent, day.label, y, width)
    for _, l in ipairs(day.lines) do
      y = y + entry(parent, day.day, l, y, width)
    end
  end
  if not empty and not ns.FeedTracker.shared() then
    placeText(pools.small, parent, PAD, y + 14, width - 2 * PAD, "You don't share your activity: friends don't "
      .. "see your lines "
      .. "(/cf settings).", "faint", width - 2 * PAD)
    y = y + 34
  end
  parent:SetHeight(y + 10)
  scroll:Update()
end

ActivityTab.NOTE = NOTE

-- For the specs: the drawn days, the chips, and every visible text in the feed (grouped by kind).
function ActivityTab.days() return lastRender end
function ActivityTab.chips() return chips end

local TEXT_POOLS = { "day", "body", "small", "tiny", "chips", "pills", "links" }

function ActivityTab.texts()
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

function ActivityTab.links()
  local out = {}
  for i = 1, pools and pools.links.used or 0 do out[i] = pools.links.items[i] end
  return out
end

ns.ActivityTab = ActivityTab
return ActivityTab
