-- DungeonsTab: the Dungeons tab (CF-106, boards DL02 and DL03; design docs/design/dungeons-2026-11/; the planner is
-- CF-24, the quests CF-19 and AG05). Left: every dungeon, grouped Fits you, Higher and Lower for the character you
-- are on (Dungeons.grouped: from 2 below a dungeon's minimum to its maximum), wings indented under their dungeon, a
-- tag on dungeons with a planned run. Right: the dungeon with when it was last cleared, its planned run, Ask now and
-- Plan a run…, then Bosses & loot from the shipped loot file (Data\Loot.lua, DungeonLoot) and its quests. The runs
-- themselves are in the Runs tab (RunsTab). Native frames from the kit, drawn from pools.
local _, ns = ...

local DungeonsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20
local ROW = 28
local LOOT_ROW = 26
local BOSS_HEAD = 32
local LIST_WIDTH = 290
local DOT = " \194\183 "
local DIM = 0.45 -- CF-106: loot your class can't use
local ASK_TIP = "Whispers online friends who fit; can post on Discord too. Waits until combat ends." -- CF-61
local DATA_TIP = "Drops and chances from Classic 1.12; Forever may differ."
local PLAN_TIP = "Runs are planned on the website or with the bot\226\128\153s /plan. Copy the link with Ctrl+C."
local TAG_TIP = "A run is planned here. Click to open it in the Runs tab."
-- Item quality colours (the game's; blue as the board shows it on the dark panel).
local QUALITY = { [0] = "9D9D9D", [1] = "FFFFFF", [2] = "1EFF00", [3] = "4DA3FF", [4] = "A335EE", [5] = "FF8000",
                  [6] = "E6CC80" }
local QUALITY_EDGE = { [3] = "0070DD" }

local root, list, detail
local helpers -- from MainFrame: settings(), render(), print(text), global()
local rows = {}     -- visible list rows: { value, frame }
local pools
local linkBox
local expanded = {} -- CF-106: dungeon id -> true when its "N more" rows are open (until /reload)
local events

-- ===== Helpers =====

local function status()
  local s = helpers.settings()
  s.dungeonTree = s.dungeonTree or {} -- the keys the AceGUI tree used (rule 8): selected
  return s.dungeonTree
end

local function global() return helpers.global and helpers.global() or nil end

local function now() return GetServerTime() end

local function colored(text, colorName) return Theme.code(colorName) .. tostring(text) .. "|r" end

local function hexCode(hex) return "|cff" .. hex end

local function classColored(classFile, text)
  if not classFile then return tostring(text) end
  return Theme.rgbCode(Kit.classColor(classFile)) .. tostring(text) .. "|r"
end

-- "17–24" with the bundled font; the game font has no en dash.
local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

local function natural(fs)
  local t = fs:GetText()
  if not t or t == "" then return 0 end
  return math.ceil(fs:GetStringWidth() or 0) + 1
end

-- CF-106: "Usable by <character>" is remembered per character (settings.usableOnly, a new key: nil in older data).
local function usableOnly(guid)
  local s = helpers.settings()
  return guid ~= nil and type(s.usableOnly) == "table" and s.usableOnly[guid] == true
end

local function setUsableOnly(guid, on)
  local s = helpers.settings()
  if type(s.usableOnly) ~= "table" then s.usableOnly = {} end
  s.usableOnly[guid] = on and true or nil
end

-- Every dungeon's area IDs, to read QuestieDB once for all of them.
local function allAreaIds()
  local ids = {}
  for _, d in ipairs(ns.Dungeons.LIST) do
    for _, id in ipairs(d.areaIds) do ids[#ids + 1] = id end
  end
  return ids
end

-- The dungeon's quests for the character you are on (CF-24 feedback): QuestieDB when it is installed, else what
-- people in range have in their logs. Completed quests are known only for the character you are on.
local function questInfo(entry, me)
  local own
  for _, c in ipairs(entry.candidates) do
    if c.own and c.guid == me.guid then own = c end
  end
  own = own or { guid = me.guid, name = me.name, level = me.level, own = true }
  local data = ns.QuestieData.dungeonQuests(allAreaIds())
  local completed
  if data then
    local ids = {}
    for _, areaId in ipairs(entry.dungeon.areaIds) do
      for _, q in ipairs(data[areaId] or {}) do ids[#ids + 1] = q.id end
    end
    completed = ns.QuestieData.completed(ids)
  end
  return ns.Dungeons.quests(entry.dungeon, data, { char = own, candidates = entry.candidates,
    factionMask = data and ns.QuestieData.factionMask(me.faction), completed = completed })
end

-- Characters with their recipes and professions (own and friends'), for "Nobody knows it" (board DL03 C).
local function recipeChars()
  local out = {}
  local g = global()
  if not g then return out end
  for _, c in pairs(g.self and g.self.chars or {}) do
    if type(c) == "table" then out[#out + 1] = { name = c.name, recipes = c.recipes, professions = c.professions } end
  end
  for battleTag, person in pairs(g.people or {}) do
    local name = type(person) == "table" and (person.displayName or battleTag:match("^([^#]+)")) or nil
    for _, c in pairs(type(person) == "table" and type(person.chars) == "table" and person.chars or {}) do
      if type(c) == "table" then out[#out + 1] = { name = name, recipes = c.recipes, professions = c.professions } end
    end
  end
  return out
end

-- The quest a quest-only drop needs, by name: your log or a friend's, else the game (guarded), else nil.
local function questName(id, candidates)
  for _, c in ipairs(candidates or {}) do
    local q = type(c.quests) == "table" and c.quests[id]
    if type(q) == "table" and q.title then return q.title end
  end
  return ns.ItemInfo.questTitle(id)
end

-- ===== Factories =====

-- A dungeon row: name, a run tag (gold) and the range on the right; wings indented.
local function listRow(parent)
  local r = Kit.listRow(parent)
  r:SetHeight(ROW)
  r.name = Theme.text(r, "body", "text")
  r.name:SetPoint("LEFT", 12, 0)
  r.name:SetJustifyH("LEFT")
  if r.name.SetWordWrap then r.name:SetWordWrap(false) end
  r.right = Theme.text(r, "small", "muted")
  r.right:SetPoint("RIGHT", -14, 0)
  r.tag = CreateFrame("Button", nil, r)
  r.tag:SetHeight(15)
  r.tag.bg = Theme.fill(r.tag, "gold", "BACKGROUND")
  r.tag.bg:SetAllPoints()
  r.tag.text = Theme.text(r.tag, "tiny", "outline")
  r.tag.text:SetPoint("CENTER")
  r.tag:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
  r.tag:SetScript("OnClick", function(self) if self.runId then ns.MainFrame.showRun(self.runId) end end)
  r.tag:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TAG_TIP, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r.tag:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- A check box with its label (Usable by <character>).
local function checkRow(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(18)
  b.box = CreateFrame("Frame", nil, b)
  b.box:SetSize(14, 14)
  b.box:SetPoint("LEFT", 0, 0)
  local bg = Theme.fill(b.box, "input", "BACKGROUND")
  bg:SetAllPoints()
  b.box.edges = Kit.edges(b.box, "questTag")
  b.check = b.box:CreateTexture(nil, "ARTWORK")
  b.check:SetPoint("TOPLEFT", 1, -1)
  b.check:SetPoint("BOTTOMRIGHT", -1, 1)
  b.check:SetTexture(Theme.TEXTURES.check)
  b.check:SetVertexColor(Theme.color("gold"))
  b.text = Theme.text(b, "body", "text")
  b.text:SetPoint("LEFT", 20, 0)
  function b:SetCheck(label, on)
    self.text:SetText(label)
    self.checked = on and true or false
    self.check:SetShown(self.checked)
    self:SetWidth(20 + math.ceil(self.text:GetStringWidth() or 100))
  end
  return b
end

-- A boss header: the order number in grey, the name in gold, "optional" after an optional boss, a line below.
local function bossHead(parent)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(BOSS_HEAD)
  h.order = Theme.text(h, "label", "keySep")
  h.order:SetPoint("BOTTOMLEFT", 0, 7)
  h.name = Theme.text(h, "section", "goldLight")
  h.name:SetPoint("BOTTOMLEFT", 18, 5)
  h.line = Theme.fill(h, "giLine", "BORDER")
  h.line:SetPoint("BOTTOMLEFT")
  h.line:SetPoint("BOTTOMRIGHT")
  h.line:SetHeight(1)
  return h
end

-- A small tag after an item's name: "Quest" (gold edge) or "Nobody knows it" (green), with a tooltip.
local function tag(parent, edge, color)
  local t = CreateFrame("Frame", nil, parent)
  t:SetHeight(14)
  t.edges = Kit.edges(t, edge)
  t.text = Theme.text(t, "badge", color)
  t.text:SetPoint("CENTER")
  t:EnableMouse(true)
  t:SetScript("OnEnter", function(self)
    if not (self.tipLines and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tipLines[1], nil, nil, nil, nil, true)
    for i = 2, #self.tipLines do GameTooltip:AddLine(self.tipLines[i], Theme.color("textDim")) end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  function t:SetTag(text)
    self.text:SetText(text)
    self:SetWidth(math.ceil(self.text:GetStringWidth() or 40) + 10)
  end
  return t
end

-- A loot row (board DL02): icon with a quality border, the name in its quality colour, a tag, the type in grey,
-- the chance on the right. Hover: the game's item tooltip; Shift-click: the item link into chat.
local function lootRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(LOOT_ROW)
  r.iconFrame = CreateFrame("Frame", nil, r)
  r.iconFrame:SetSize(22, 22)
  r.iconFrame:SetPoint("LEFT", 0, 0)
  r.iconBg = Theme.fill(r.iconFrame, "track", "BACKGROUND")
  r.iconBg:SetAllPoints()
  r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("TOPLEFT", 1, -1)
  r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  r.iconFrame.edges = Kit.edges(r.iconFrame, "white", "OVERLAY")
  r.name = Theme.text(r, "body", "text")
  r.name:SetPoint("LEFT", 30, 0)
  r.name:SetJustifyH("LEFT")
  r.tag = tag(r, "questTag", "goldLight")
  r.type = Theme.text(r, "tiny", "muted")
  r.type:SetJustifyH("LEFT")
  r.chance = Theme.text(r, "small", "textDim")
  r.chance:SetPoint("RIGHT", 0, 0)
  r.chance:SetJustifyH("RIGHT")
  for _, fs in ipairs({ r.name, r.type }) do
    if fs.SetWordWrap then fs:SetWordWrap(false) end
  end
  local hover = r:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  r:SetScript("OnEnter", function(self) if self.item then ns.ItemInfo.tooltip(self, self.item) end end)
  r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  r:SetScript("OnClick", function(self)
    if self.link and ns.ItemInfo.shift() then ns.TradeSkill.insert(self.link) end
  end)
  return r
end

-- "N more" with a down arrow: opens the rest of a dungeon's loot in place (grey-gold). The arrow is a texture
-- (CF-64: the fonts have no down-pointing triangle).
local function moreRow(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(LOOT_ROW)
  b.text = Theme.text(b, "small", "gold")
  b.text:SetPoint("LEFT", 30, 0)
  b.text:SetAlpha(0.8)
  b.arrow = b:CreateTexture(nil, "ARTWORK")
  b.arrow:SetSize(9, 9)
  b.arrow:SetPoint("LEFT", b.text, "RIGHT", 5, 0)
  b.arrow:SetTexture(Theme.TEXTURES.arrow)
  b.arrow:SetVertexColor(Theme.color("gold", 0.8))
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  return b
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
  q.who:SetJustifyH("RIGHT")
  for _, fs in ipairs({ q.name, q.who }) do
    if fs.SetWordWrap then fs:SetWordWrap(false) end -- CF-95: cut with "...", never a second line
  end
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

-- A text that wraps (pooled texts are reused, so each placement says how it breaks).
local function placeText(pool, parent, x, y, width, text, color, justify)
  local holder = Kit.placeText(pool, parent, x, y, width, text, color, justify)
  if holder.text.SetWordWrap then holder.text:SetWordWrap(true) end
  return holder
end

-- CF-95: one line, cut with "..." where it doesn't fit.
local function line(pool, parent, x, y, width, text, color, justify)
  local holder = Kit.placeText(pool, parent, x, y, math.max(1, width), text, color, justify)
  if holder.text.SetWordWrap then holder.text:SetWordWrap(false) end
  return holder
end

-- A section title and a note after it, both on one line within width.
local function section(parent, x, y, width, text, note, noteColor)
  local h = line(pools.section, parent, x, y, width, text, "goldLight")
  if note then
    local w = math.min(width, h.text.GetStringWidth and h.text:GetStringWidth() or 100)
    line(pools.small, parent, x + w + 10, y + 3, width - w - 10, note, noteColor or "muted")
  end
  return y + Kit.SECTION_HEIGHT
end

-- CF-95: the width the detail is laid out at, never below 300.
local MIN_WIDTH = 300
local function detailWidth()
  local shown = detail and detail:GetWidth()
  if shown and shown > 0 then return math.max(MIN_WIDTH, shown - 6 - 2 * PAD) end
  return 560 - 2 * PAD
end

-- The tag of a dungeon's next run: "Today", "Tomorrow", else the weekday ("Sat").
local function runTag(run)
  if not date then return "" end
  local group = ns.RunProgress.dayGroup(run.startsAt, now(), date)
  if group ~= "Later" then return group end
  return (ns.PlannedRuns.rowTime(run.startsAt, now(), date):match("^(%a+)")) or group
end

-- CF-106 (board DL02, DL03 A): Dungeons; per group its header (Fits you with the character you are on), a row per
-- dungeon, wings indented under their dungeon's name; "Nothing fits yet · first at 13" when nothing fits.
local function renderList(groups, nextRun, me, bare)
  for _, name in ipairs({ "rows", "listText", "listTitle", "listGroups", "listParents", "listPortraits" }) do
    Kit.recycle(pools[name])
  end
  rows = {}
  local parent = list.child
  local width = math.max(200, (list:GetWidth() or 0) - 6)
  local y = 4
  local selected = status().selected
  placeText(pools.listTitle, parent, 14, y + 8, width - 28, "Dungeons", "goldLight")
  y = y + 36
  if bare then
    parent:SetHeight(y)
    list:Update()
    return
  end
  for _, g in ipairs(groups) do
    local head = line(pools.listGroups, parent, 14, y + 10, width - 28, g.text, "gold")
    head.text:SetWidth(math.max(1, natural(head.text)))
    if g.key == "fits" then
      local who = line(pools.listText, parent, 14, y + 10, width - 28,
        string.format("%s %s", tostring(me.name or "?"), tostring(me.level or "?")), "muted", "RIGHT")
      local p = Kit.take(pools.listPortraits, parent)
      p:SetClass(me.classFile)
      local ww = math.min(width - 28, natural(who.text))
      p:SetPoint("TOPRIGHT", parent, "TOPLEFT", width - 14 - ww - 4, -(y + 9))
    end
    y = y + 28
    if #g.items == 0 then
      local first = ns.Dungeons.first()
      line(pools.listText, parent, 14, y + 4, width - 28, "Nothing fits yet" .. (first and (DOT .. "first at "
        .. first.min) or ""), "muted")
      y = y + 24
    end
    for _, item in ipairs(g.items) do
      if item.parent then
        line(pools.listParents, parent, 15, y + 8, width - 30, item.parent, "textDim")
        y = y + 24
      else
        local d = item.dungeon
        local r = Kit.take(pools.rows, parent)
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("RIGHT", parent, "RIGHT")
        r.value = d.id
        r.name:ClearAllPoints()
        r.name:SetPoint("LEFT", item.wing and 26 or 12, 0)
        r.name:SetText(item.wing or d.name)
        r.name:SetTextColor(Theme.color(d.id == selected and "goldLight" or "text"))
        r.right:SetText(range(d))
        local run = nextRun[d.id]
        if run then
          r.tag:Show()
          r.tag.runId = run.id
          r.tag.text:SetText(runTag(run))
          r.tag:SetWidth(math.ceil(r.tag.text:GetStringWidth() or 30) + 10)
        else
          r.tag:Hide()
          r.tag.runId = nil
        end
        local room = width - (item.wing and 26 or 12) - 14 - natural(r.right) - 8 -
          (run and ((r.tag:GetWidth() or 40) + 8) or 0)
        r.name:SetWidth(math.max(1, math.min(natural(r.name), room)))
        r:SetSelected(d.id == selected)
        rows[#rows + 1] = { value = d.id, frame = r, tag = run and r.tag or nil }
        y = y + ROW
      end
    end
  end
  parent:SetHeight(y + 12)
  list:Update()
end

-- CF-27: how your ask for this dungeon stands (CF-65: next to Ask now, which stays).
local function askStatus(parent, y, width)
  local ask = ns.GroupAsks.current()
  local s = ns.GroupAsk.summary(ask)
  local parts = {}
  if #s.join > 0 then parts[#parts + 1] = colored("joining: " .. table.concat(s.join, ", "), "onlineText") end
  if #s.later > 0 then parts[#parts + 1] = "later: " .. table.concat(s.later, ", ") end
  if #s.no > 0 then parts[#parts + 1] = colored("not now: " .. table.concat(s.no, ", "), "muted") end
  if #s.waiting > 0 then parts[#parts + 1] = colored("waiting: " .. table.concat(s.waiting, ", "), "muted") end
  line(pools.small, parent, PAD, y + 4, width, "Asked who's up for it" .. (#parts > 0 and (DOT ..
    table.concat(parts, DOT)) or ""), "text")
  return y + 26
end

-- CF-65: a redraw takes the pooled frames again without hiding them first, and hides only what it didn't use.
local linkPlaced
local function clearDetail()
  for _, name in ipairs({ "name", "section", "small", "tiny", "quests", "buttons", "primary", "infos", "checks",
                          "bossHeads", "loot", "more", "dividers" }) do
    Kit.recycle(pools[name])
  end
  linkPlaced = false
end

local function sweep()
  for _, p in pairs(pools) do Kit.sweep(p) end
  if not linkPlaced then linkBox:Hide() end
end

local function divider(parent, y, width)
  local d = Kit.take(pools.dividers, parent)
  d:SetPoint("TOPLEFT", PAD, -y)
  d:SetSize(width, 1)
  return y + 1
end

-- "Last cleared by Grom, Mira · Tue": the friends in the group whose kill log has the final boss's last death.
local function clearedText(bosses, kills, candidates)
  local k = ns.DungeonLoot.lastCleared(bosses, kills)
  if not k then return nil end
  local byGuid = {}
  for _, c in ipairs(candidates) do byGuid[c.guid] = c end
  local names, seen = {}, {}
  local guids = { k.guid }
  for _, g in ipairs(k.with or {}) do guids[#guids + 1] = g end
  for _, g in ipairs(guids) do
    local c = byGuid[g]
    local who = c and (c.own and "you" or c.displayName or c.name)
    if who and not seen[who] then
      seen[who] = true
      names[#names + 1] = classColored(c.classFile, who)
    end
  end
  local when = date and ns.PlannedRuns.pastText(k.at, now(), date):gsub(" %d%d:%d%d$", "") or nil
  if #names == 0 then return "Last cleared" .. (when and (DOT .. when) or "") end
  return "Last cleared by " .. table.concat(names, ", ") .. (when and (DOT .. when) or "")
end

-- The buttons of a dungeon (board DL02): its next run ("Today 20:00 · 5 in ›", opens it in Runs), Ask now and Plan a
-- run…, in a row that wraps at the width. Returns the new y.
local function actions(parent, y, width, dungeon, run)
  local btns = {}
  if run then
    local b = Kit.take(pools.buttons, parent)
    local yes = ns.PlannedRuns.counts(run)
    b:SetLabel((date and ns.PlannedRuns.whenText(run.startsAt, now(), date) or "") .. DOT .. yes .. " in \226\128\186")
    b:SetEnabled(true)
    b.tooltip = nil
    b:SetScript("OnClick", function() ns.MainFrame.showRun(run.id) end)
    btns[#btns + 1] = b
  end
  local ask = Kit.take(pools.buttons, parent)
  ask:SetLabel("Ask now")
  ask:SetEnabled(true) -- CF-65: never gated here; the dialog says when you can ask again
  ask.tooltip = ASK_TIP
  ask:SetScript("OnClick", function() ns.RunDialogs.ask({ dungeon = dungeon }) end)
  btns[#btns + 1] = ask
  local plan = Kit.take(pools.primary, parent)
  plan:SetLabel("Plan a run\226\128\166")
  plan:SetEnabled(true)
  plan.tooltip = PLAN_TIP
  local linkY
  plan:SetScript("OnClick", function()
    -- CF-64: planning happens on the website: its link to copy (or the bot's /plan).
    local site = ns.RunsFile.site()
    if not site then
      helpers.print("Plan runs on the website or with the bot\226\128\153s /plan on Discord.")
      return
    end
    linkBox:ClearAllPoints()
    linkBox:SetParent(parent)
    linkBox:SetPoint("TOPLEFT", PAD, -linkY)
    linkBox:SetWidth(math.min(320, width))
    linkBox:SetText(site)
    linkBox:Show()
    if linkBox.SetFocus then linkBox:SetFocus() end
    if linkBox.HighlightText then linkBox:HighlightText() end
  end)
  btns[#btns + 1] = plan
  local x = PAD
  for _, b in ipairs(btns) do
    b:SetHeight(26)
    local w = b:GetWidth() or 80
    if x > PAD and x + w > PAD + width then
      x = PAD
      y = y + 32
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", x, -y)
    x = x + w + 8
  end
  linkY = y + 34
  return y + 34
end

-- One loot row at y.
local function drawLoot(parent, y, width, row, candidates, chars)
  local d = row.drop
  local info = ns.ItemInfo.get(d.item)
  local r = Kit.take(pools.loot, parent)
  r:SetPoint("TOPLEFT", PAD, -y)
  r:SetWidth(width)
  r.item, r.link = d.item, info.link
  r:SetAlpha(row.usable and 1 or DIM)
  local quality = info.quality or 1
  local hex = QUALITY[quality] or QUALITY[1]
  local edge = QUALITY_EDGE[quality] or hex
  local er, eg, eb = tonumber(edge:sub(1, 2), 16) / 255, tonumber(edge:sub(3, 4), 16) / 255,
    tonumber(edge:sub(5, 6), 16) / 255
  for _, e in ipairs(r.iconFrame.edges) do e:SetColorTexture(er, eg, eb, 1) end
  if info.icon then r.icon:SetTexture(info.icon) r.icon:Show() else r.icon:Hide() end
  r.name:SetText(hexCode(hex) .. tostring(info.name or ("Item " .. d.item)) .. "|r")
  r.chance:SetText(ns.DungeonLoot.chanceText(d.chance))
  -- The tag: Quest (a quest-only drop) or Nobody knows it (a recipe nobody in the group learned).
  local tagText, tipLines
  if d.quest then
    tagText = "Quest"
    local q = questName(d.quest, candidates)
    tipLines = { "Quest Item", q and ("Drops while you have " .. q .. ".") or "Drops only while you have its quest." }
  elseif d.recipe or d.cls == ns.DungeonLoot.RECIPE then
    local st = ns.DungeonLoot.recipeState(d, chars)
    if not st.known then
      tagText = "Nobody knows it"
      tipLines = { tostring(info.name or "Recipe") }
      if st.requires then tipLines[#tipLines + 1] = st.requires end
      tipLines[#tipLines + 1] = "Nobody knows it"
      if #st.canLearn > 0 then tipLines[#tipLines + 1] = "Can learn: " .. table.concat(st.canLearn, ", ") end
    end
  end
  local chanceW = 44
  local typeText = ns.DungeonLoot.typeText(d, info.equipLoc)
  r.type:SetText(typeText)
  r.name:SetWidth(0)
  r.type:SetWidth(0)
  local room = width - 30 - chanceW
  local nameW = math.min(natural(r.name), math.max(60, room - 40))
  r.name:SetWidth(math.max(1, nameW))
  local x = 30 + nameW + 6
  if tagText then
    r.tag:Show()
    local learn = tagText ~= "Quest"
    for _, e in ipairs(r.tag.edges) do e:SetColorTexture(Theme.color(learn and "learnTag" or "questTag")) end
    r.tag.text:SetTextColor(Theme.color(learn and "online" or "goldLight"))
    r.tag:SetTag(tagText)
    r.tag.tipLines = tipLines
    r.tag:ClearAllPoints()
    r.tag:SetPoint("LEFT", x, 0)
    x = x + (r.tag:GetWidth() or 40) + 6
  else
    r.tag:Hide()
    r.tag.tipLines = nil
  end
  r.type:ClearAllPoints()
  r.type:SetPoint("LEFT", x, 0)
  r.type:SetWidth(math.max(1, math.min(natural(r.type), 30 + room - x)))
  r.usable, r.drop = row.usable, d
  return y + LOOT_ROW
end

--[[ CF-106 (boards DL02, DL03 B, C, F): Bosses & loot with "Classic data ⓘ" and "Usable by <character>"; per boss
its header and up to 6 drops, "N more" opening the rest in place (counted after the switch). Returns the new y. ]]
local function lootSection(parent, y, width, dungeon, me, candidates)
  local title = line(pools.section, parent, PAD, y, width, "Bosses & loot", "goldLight")
  local check = Kit.take(pools.checks, parent)
  local on = usableOnly(me.guid)
  check:SetCheck("Usable by " .. tostring(me.name or "you"), on)
  check:ClearAllPoints()
  check:SetPoint("TOPRIGHT", parent, "TOPLEFT", PAD + width, -(y + 1))
  check:SetScript("OnClick", function()
    setUsableOnly(me.guid, not usableOnly(me.guid))
    helpers.render()
  end)
  local info = Kit.take(pools.infos, parent)
  info.tip = DATA_TIP
  info:ClearAllPoints()
  info:SetPoint("RIGHT", check, "LEFT", -14, 0)
  local data = line(pools.small, parent, PAD, y + 3, width, "Classic data", "muted")
  local dw = natural(data.text)
  local dataX = PAD + width - (check:GetWidth() or 120) - 14 - 14 - 6 - dw
  data:ClearAllPoints()
  data:SetPoint("TOPLEFT", math.max(PAD + natural(title.text) + 10, dataX), -(y + 3))
  data.text:SetWidth(math.max(1, dw))
  y = y + Kit.SECTION_HEIGHT + 2
  local bosses = ns.DungeonLoot.bosses(ns.LootData, dungeon.id)
  if #bosses == 0 then
    line(pools.small, parent, PAD, y + 4, width, "No boss data for this dungeon yet.", "muted")
    return y + 28, bosses
  end
  local chars = recipeChars()
  for i, b in ipairs(bosses) do
    local h = Kit.take(pools.bossHeads, parent)
    h:SetPoint("TOPLEFT", PAD, -y)
    h:SetWidth(width)
    h.order:SetText(tostring(i))
    h.name:SetText(tostring(b.name) .. (b.optional and colored("  optional", "keySep") or ""))
    y = y + BOSS_HEAD
    local shown, more = ns.DungeonLoot.rows(b, me.classFile, on, expanded[dungeon.id])
    for _, row in ipairs(shown) do y = drawLoot(parent, y, width, row, candidates, chars) end
    if #shown == 0 then
      line(pools.small, parent, PAD + 30, y + 6, width - 30, #b.drops == 0 and "No drops known" or
        "Nothing usable by " .. tostring(me.name or "you"), "keySep")
      y = y + LOOT_ROW
    end
    if more > 0 then
      local m = Kit.take(pools.more, parent)
      m:SetPoint("TOPLEFT", PAD, -y)
      m:SetWidth(width)
      m.text:SetText(more .. " more")
      m:SetScript("OnClick", function()
        expanded[dungeon.id] = true
        helpers.render()
      end)
      y = y + LOOT_ROW
    end
  end
  return y + 8, bosses
end

-- The quests (CF-62, AG05): QuestieDB for this dungeon and your faction; else what people in range have in their logs.
local function questSection(parent, y, width, entry, me)
  local info = questInfo(entry, me)
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
  if not info.complete then return y end -- CF-62: without QuestieDB the list is hidden
  for _, q in ipairs(info.quests) do
    local r = Kit.take(pools.quests, parent)
    r:SetPoint("TOPLEFT", PAD, -y)
    r:SetWidth(width)
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
    r.who:SetWidth(0)
    r.name:SetWidth(0)
    local whoW = math.min(natural(r.who), math.floor(width * 0.45))
    r.who:SetWidth(math.max(1, whoW))
    r.name:SetWidth(math.max(1, width - 22 - (whoW > 0 and (whoW + 8) or 0)))
    y = y + 24
  end
  return y
end

-- CF-106 (board DL02): a dungeon: the header (name; "level 17–26 · Westfall · fits"), Last cleared, its planned run,
-- Ask now and Plan a run…, then Bosses & loot and Quests.
local function renderDetail(entry, me, candidates, run, kills)
  local parent = detail.child
  local width = detailWidth()
  local y = PAD - 6
  local dungeon = entry.dungeon
  line(pools.name, parent, PAD, y, width, dungeon.title or dungeon.name, "heading")
  y = y + 34
  local sub = "level " .. range(dungeon)
  if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. DOT .. ns.Dungeons.ZONES[dungeon.id] end
  local fit = type(me.level) == "number" and ns.PlannedRuns.levelFit(me.level, dungeon.min, dungeon.max)
  if fit then sub = sub .. DOT .. colored(fit.label, fit.kind == "fits" and "online" or "warning") end
  line(pools.small, parent, PAD, y, width, sub, "muted")
  y = y + 22
  local bosses = ns.DungeonLoot.bosses(ns.LootData, dungeon.id)
  local cleared = clearedText(bosses, kills, candidates)
  if cleared then
    line(pools.small, parent, PAD, y + 2, width, cleared, "textDim")
    y = y + 22
  end
  y = y + 4
  local ask = ns.GroupAsks.current()
  if ask and ask.dungeon and ask.dungeon.id == dungeon.id then y = askStatus(parent, y, width) end
  y = actions(parent, y, width, dungeon, run)
  y = divider(parent, y + 4, width) + 12
  y = lootSection(parent, y, width, dungeon, me, candidates)
  y = divider(parent, y + 4, width) + 12
  y = questSection(parent, y, width, entry, me)
  parent:SetHeight(y + PAD + 40)
  detail:Update()
end

-- The window's empty state (no community etc.): its text in the middle.
local function renderEmpty(messageText)
  local parent = detail.child
  local width = detailWidth()
  local y = PAD + 60
  placeText(pools.small, parent, PAD, y, width, messageText or "", "textDim", "CENTER")
  parent:SetHeight(y + 80)
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
  column:SetWidth(LIST_WIDTH)
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

  -- The website's link to copy (Plan a run…): selected when clicked, so Ctrl+C copies it. Typing does not change it.
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
    rows = Kit.pool(listRow), listText = Kit.pool(Kit.textHolder("small")),
    listTitle = Kit.pool(Kit.textHolder("section")), listGroups = Kit.pool(Kit.textHolder("label")),
    listParents = Kit.pool(Kit.textHolder("small")),
    listPortraits = Kit.pool(function(p) return Kit.portrait(p, 14) end),
    name = Kit.pool(Kit.textHolder("name")), section = Kit.pool(Kit.textHolder("section")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    quests = Kit.pool(questRow), buttons = Kit.pool(button), primary = Kit.pool(primary),
    infos = Kit.pool(Kit.info), checks = Kit.pool(checkRow),
    bossHeads = Kit.pool(bossHead), loot = Kit.pool(lootRow), more = Kit.pool(moreRow),
    dividers = Kit.pool(function(p)
      local f = CreateFrame("Frame", nil, p)
      local t = Theme.fill(f, "divider", "BORDER")
      t:SetAllPoints()
      return f
    end),
  }
  -- CF-106: item names arrive later (V83): redraw once the game has loaded them.
  if not events then
    events = LibStub("AceEvent-3.0"):Embed({})
    local redraw = ns.Timer.debounce(0.3, function()
      if root and root:IsShown() and helpers then helpers.render() end
    end)
    ns.ItemInfo.watch(events, redraw)
  end
  return root
end

-- Shown: the game's dungeons and level ranges (V46).
function DungeonsTab.show()
  if not root then return end
  root:Show()
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
end

function DungeonsTab.hide() if root then root:Hide() end end

function DungeonsTab.closed() end

function DungeonsTab.select(value)
  status().selected = value
  helpers.render()
end

-- CF-48: selects a dungeon without drawing (the window draws when it opens on the tab); false: the first that fits.
function DungeonsTab.selectQuietly(value)
  if helpers then status().selected = value or nil end
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
local function draw(view, messageText)
  clearDetail()
  local me = ns.SelfInfo.read()
  if messageText then
    renderList({}, {}, me, true)
    renderEmpty(messageText)
    return
  end
  local candidates = ns.Dungeons.candidates(view)
  local include = {}
  for _, d in ipairs(ns.Dungeons.LIST) do include[d.id] = true end
  local entries = {}
  for _, e in ipairs(ns.Dungeons.overview(candidates, me.guid, include)) do entries[e.dungeon.id] = e end
  local groups = ns.Dungeons.grouped(me.level)
  local kills = ns.KillLog.all()
  -- The next run of each dungeon (its tag and button); runs the Runs tab lists.
  local nextRun = {}
  for _, item in ipairs(ns.RunsTab.runs(kills)) do
    local d = ns.Dungeons.get(item.run.dungeon)
    -- CF-106: an older run for a whole instance ("strat", "dme") tags each of its wings.
    for _, id in ipairs(d and d.wings or { item.run.dungeon }) do
      if not nextRun[id] then nextRun[id] = item.run end
    end
  end
  local st = status()
  if not (st.selected and entries[st.selected]) then
    local first = groups[1] and groups[1].items
    st.selected = nil
    for _, item in ipairs(first or {}) do
      if not st.selected and item.dungeon then st.selected = item.dungeon.id end
    end
    for _, g in ipairs(groups) do
      for _, item in ipairs(g.items) do
        if not st.selected and item.dungeon then st.selected = item.dungeon.id end
      end
    end
  end
  renderList(groups, nextRun, me)
  local entry = st.selected and entries[st.selected]
  if entry then
    renderDetail(entry, me, candidates, nextRun[entry.dungeon.id], kills)
  else
    renderEmpty(ns.Dungeons.emptyText(me.name, me.level, ns.CommunitySelection.active() ~= nil))
  end
end

function DungeonsTab.render(view, messageText)
  if not root then return end
  draw(view, messageText)
  sweep() -- CF-65: hide only what this draw didn't use
end

function DungeonsTab.reset()
  root, rows, expanded = nil, {}, {}
end

-- For the specs: the list rows, the texts (in pool order), the buttons by label, loot rows, tips.
function DungeonsTab.rows() return rows end
function DungeonsTab.linkBox() return linkBox end
function DungeonsTab.detailArea() return detail end

function DungeonsTab.detailTexts()
  local out = {}
  for _, name in ipairs({ "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i] end
  end
  return out
end

function DungeonsTab.texts()
  local out = {}
  for _, name in ipairs({ "listTitle", "listGroups", "listText", "listParents", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "rows", "bossHeads", "loot", "more", "quests" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "order", "name", "right", "type", "chance", "who", "text" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
      if item.tag and item.tag.IsShown and item.tag:IsShown() and item.tag.text:GetText() then
        out[#out + 1] = item.tag.text:GetText()
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
  for i = 1, pools and pools.checks.used or 0 do out[pools.checks.items[i].text:GetText()] = pools.checks.items[i] end
  for i = 1, pools and pools.more.used or 0 do out[pools.more.items[i].text:GetText()] = pools.more.items[i] end
  return out
end

local function used(name)
  local out = {}
  for i = 1, pools and pools[name].used or 0 do out[i] = pools[name].items[i] end
  return out
end

function DungeonsTab.questRows() return used("quests") end
function DungeonsTab.lootRows() return used("loot") end

function DungeonsTab.tips()
  local out = {}
  for _, name in ipairs({ "infos", "primary", "buttons" }) do
    for i = 1, pools and pools[name].used or 0 do
      local t = pools[name].items[i].tooltip or pools[name].items[i].tip
      if t then out[#out + 1] = t end
    end
  end
  for i = 1, pools and pools.loot.used or 0 do
    local t = pools.loot.items[i].tag
    if t:IsShown() and t.tipLines then out[#out + 1] = table.concat(t.tipLines, "\n") end
  end
  return out
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
