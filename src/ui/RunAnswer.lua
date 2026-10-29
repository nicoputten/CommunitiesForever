-- RunAnswer: the inline "Your answer" block under a run's group (CF-63b, board
-- docs/design/cf-63-2026-10/CF63Answer.dc.html). I'm in / Maybe / Can't, the character you go as (a dropdown of
-- all your characters with their fit), the roles its class can play with their slot ("Healer · open", "Damage ·
-- full"), and a note to the organiser. Every click saves at once (Planner.answer): friends online get it now,
-- the website with the next upload (a clock icon until then). A character, role or note picked before
-- answering is kept until you answer. One block, moved to the run on each draw.
local _, ns = ...

local RunAnswer = {}
local Theme, Kit = ns.Theme, ns.Kit

local DOT = " \194\183 "
local ANSWERS = { { "in", "I\226\128\153m in" }, { "maybe", "Maybe" }, { "cant", "Can\226\128\153t" } }
local FIT_COLOR = { fits = "online", over = "online", low = "warning", carry = "warning", tooLow = "warning" }
local PENDING_TIP = "Saved. Reaches the website with your next upload."
local NOTE_HINT = "Note to the organiser"
RunAnswer.FULL_TIP = "%s is full \194\183 you join as reserve." -- Nico 2026-10-30: a full role makes you reserve

local block
local picks = {} -- run id -> { guid, role, note } chosen before answering (not saved)

local function seg(parent, label, kind)
  local b = Kit.button(parent, label, nil, kind)
  b:SetHeight(28)
  return b
end

-- A role toggle: the role icon, "Healer" and a muted " · open"; gold edges when on.
local function roleToggle(parent)
  local t = CreateFrame("Button", nil, parent)
  t:SetHeight(28)
  t.bg = Theme.fill(t, "gold", "BACKGROUND")
  t.bg:SetAllPoints()
  t.edges = Kit.edges(t, "divider")
  t.icon = Kit.roleIcon(t, 16)
  t.icon:SetPoint("LEFT", 8, 0)
  t.text = Theme.text(t, "small", "text")
  t.text:SetPoint("LEFT", 30, 0)
  local hover = t:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  t:SetScript("OnEnter", function(self)
    if not (self.tooltip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function(self) if self.tooltip and GameTooltip then GameTooltip:Hide() end end)
  function t:SetChoice(choice, on)
    self.choice = choice
    self.icon:SetRole(choice.role)
    self.text:SetText(ns.PlannedRuns.ROLE_NAMES[choice.role] .. Theme.code("muted") .. DOT .. choice.state .. "|r")
    self.bg:SetAlpha(on and 0.12 or 0)
    for _, e in ipairs(self.edges) do e:SetColorTexture(Theme.color(on and "gold" or "divider")) end
    self.on = on
    self.tooltip = choice.state == "full" and string.format(RunAnswer.FULL_TIP, ns.PlannedRuns.ROLE_NAMES[choice.role])
      or nil
    self:SetWidth(30 + math.ceil(self.text:GetStringWidth() or 80) + 10)
  end
  return t
end

-- The character dropdown: class icon, name in its class colour, level, fit, an arrow.
local function charSelect(parent)
  local d = CreateFrame("Button", nil, parent)
  d:SetHeight(28)
  local bg = Theme.fill(d, "input", "BACKGROUND")
  bg:SetAllPoints()
  d.edges = Kit.edges(d, "border")
  d.portrait = Kit.portrait(d, 18)
  d.portrait:SetPoint("LEFT", 8, 0)
  d.text = Theme.text(d, "body", "text")
  d.text:SetPoint("LEFT", 32, 0)
  d.arrow = d:CreateTexture(nil, "ARTWORK")
  d.arrow:SetSize(10, 10)
  d.arrow:SetPoint("RIGHT", -10, 0)
  d.arrow:SetTexture(Theme.TEXTURES.arrow)
  d.arrow:SetVertexColor(Theme.color("gold"))
  local hover = d:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  return d
end

-- "Vesgar Bloodhoof  31  fits" with colours, for the dropdown and its menu.
local function charText(o)
  local c = o.char
  local name = Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(c.name) .. "|r"
  return name .. "  " .. Theme.code("muted") .. tostring(c.level or "?") .. "|r  "
    .. Theme.code(FIT_COLOR[o.fit.kind] or "muted") .. o.fit.label .. "|r"
end

function RunAnswer.create(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(10, 10)
  b.heading = Theme.text(b, "section", "goldLight")
  b.heading:SetPoint("TOPLEFT", 0, 0)
  b.heading:SetText("Your answer")
  b.status = Theme.text(b, "small", "textDim")
  b.status:SetPoint("LEFT", b.heading, "RIGHT", 10, 0)
  b.clock = Kit.clock(b)
  b.clock:SetPoint("LEFT", b.status, "RIGHT", 6, 0)
  b.clock.tip = PENDING_TIP
  b.answers = {}
  for _, def in ipairs(ANSWERS) do
    b.answers[def[1]] = { normal = seg(b, def[2]), primary = seg(b, def[2], "primary") }
  end
  b.select = charSelect(b)
  b.roles = { roleToggle(b), roleToggle(b), roleToggle(b) }
  b.note = Kit.input(b, { maxLetters = ns.PlannedRuns.MAX_ANSWER_NOTE,
    onCommit = function(text) if b.onNote then b.onNote(text) end end })
  b.hint = Theme.text(b.note, "body", "faint")
  b.hint:SetPoint("LEFT", 10, 0)
  b.hint:SetText(NOTE_HINT)
  b.count = Theme.text(b, "small", "muted")
  b.count:SetJustifyH("RIGHT")
  b.count:SetWidth(40)
  local function counted(self)
    local n = 0
    for _ in (self:GetText() or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    b.count:SetText(n .. "/" .. ns.PlannedRuns.MAX_ANSWER_NOTE)
    b.hint:SetShown(n == 0 and not self.focused)
  end
  b.note:SetScript("OnTextChanged", counted)
  b.note:HookScript("OnEditFocusGained", function(self) self.focused = true; counted(self) end)
  b.note:HookScript("OnEditFocusLost", function(self) self.focused = false; counted(self) end)
  b.counted = counted
  block = b
  return b
end

--[[ Draws the block for run at x, y below parent's top left, width wide. me: Planner.me(); candidates:
Dungeons.candidates; onSaved(): after a save (redraw). Returns the height used. ]]
function RunAnswer.render(parent, run, me, candidates, x, y, width, onSaved)
  local b = block or RunAnswer.create(parent)
  b:SetParent(parent)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", x, -y)
  b:SetWidth(width)
  b:Show()
  local dungeon = ns.Dungeons.get(run.dungeon)
  local mine = ns.PlannedRuns.yourAnswer(run, me)
  local you = ns.SelfInfo.read()
  local pick = picks[run.id] or {}
  picks[run.id] = pick

  -- The character: your answer's, else the one picked, else the one you are on; the best fit without them.
  local options = ns.PlannedRuns.charChoices(candidates, dungeon, you.guid)
  if #options == 0 then
    options = { { char = { own = true, guid = you.guid, name = you.name, level = you.level,
                           classFile = you.classFile }, fit = { kind = "fits", label = "fits" } } }
  end
  local want = (mine and mine.answer ~= "cant" and mine.guid) or pick.guid or you.guid
  local option = options[1]
  for _, o in ipairs(options) do
    if o.char.guid == want then option = o end
  end
  local c = option.char
  local role = (mine and mine.answer ~= "cant" and mine.role) or pick.role
  if not (role and ns.PlannedRuns.canPlay(c.classFile, role)) then
    role = ns.PlannedRuns.defaultRole(c.classFile, c.role)
  end
  local note = (mine and mine.note) or pick.note
  local roleChoices = ns.PlannedRuns.roleChoices(run, candidates, dungeon, c.classFile, me)
  local roleFull = false
  for _, rc in ipairs(roleChoices) do
    if rc.role == role then roleFull = rc.state == "full" end
  end
  local current = mine and mine.answer

  local function save(answer, newC, newRole, newNote)
    if answer == "cant" then
      ns.Planner.answer(run, "cant", nil, nil)
    else
      ns.Planner.answer(run, answer, { guid = newC.guid, name = newC.name, role = newRole }, newNote)
    end
    if onSaved then onSaved() end
  end

  -- Line 1: "Your answer", what it is, the clock while it waits for the upload.
  b.status:SetText(ns.PlannedRuns.ANSWER_STATES[ns.PlannedRuns.answerState(mine, roleFull)])
  b.clock:SetShown(mine ~= nil and mine.pending == true)

  -- Line 2: the answer, then (unless Can't) the character and the roles.
  local lx = 0
  for _, def in ipairs(ANSWERS) do
    local pair = b.answers[def[1]]
    local on = current == def[1]
    local shown, hidden = on and pair.primary or pair.normal, on and pair.normal or pair.primary
    hidden:Hide()
    shown:Show()
    shown:ClearAllPoints()
    shown:SetPoint("TOPLEFT", lx, -28)
    shown:SetScript("OnClick", function()
      if current == def[1] then return end
      save(def[1], c, role, note)
    end)
    lx = lx + (shown:GetWidth() or 70) - 1
  end
  lx = lx + 12
  local cant = current == "cant"
  b.select:SetShown(not cant)
  b.note:SetShown(not cant)
  b.count:SetShown(not cant)
  for _, t in ipairs(b.roles) do t:Hide() end
  if cant then
    b:SetHeight(64)
    return 64
  end
  b.select.text:SetText(charText(option))
  b.select.portrait:SetClass(c.classFile)
  b.select:SetWidth(32 + math.ceil(b.select.text:GetStringWidth() or 160) + 30)
  b.select:ClearAllPoints()
  b.select:SetPoint("TOPLEFT", lx, -28)
  b.select:SetScript("OnClick", function(owner)
    local items = {}
    for i, o in ipairs(options) do items[i] = { label = charText(o), enabled = true, option = o } end
    ns.ContextMenu.open(owner, { items = items }, function(item)
      local nc = item.option.char
      local nr = ns.PlannedRuns.canPlay(nc.classFile, role) and role
        or ns.PlannedRuns.defaultRole(nc.classFile, nc.role)
      if current then
        save(current, nc, nr, note)
      else
        pick.guid, pick.role = nc.guid, nr
        if onSaved then onSaved() end
      end
    end)
  end)
  lx = lx + b.select:GetWidth() + 12
  for i, rc in ipairs(roleChoices) do
    local t = b.roles[i]
    t:Show()
    t:SetChoice(rc, rc.role == role)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", lx, -28)
    t:SetScript("OnClick", function()
      if rc.role == role then return end
      if current then
        save(current, c, rc.role, note)
      else
        pick.role = rc.role
        if onSaved then onSaved() end
      end
    end)
    lx = lx + t:GetWidth() + 6
  end

  -- Line 3: the note, saved on Enter or when the box loses focus.
  b.note:ClearAllPoints()
  b.note:SetPoint("TOPLEFT", 0, -66)
  b.note:SetWidth(width - 48)
  b.count:ClearAllPoints()
  b.count:SetPoint("LEFT", b.note, "RIGHT", 8, 0)
  if not b.note.focused then b.note:SetValue(note or "") end
  b.counted(b.note)
  b.onNote = function(text)
    local clean = ns.Pending.note(text, ns.PlannedRuns.MAX_ANSWER_NOTE)
    if clean == note then return end
    if current then
      save(current, c, role, clean)
    else
      pick.note = clean
    end
  end
  b:SetHeight(100)
  return 100
end

function RunAnswer.hide() if block then block:Hide() end end

-- For the specs: the block (nil before the first draw); its shown buttons by label (the answers, the roles by
-- name, "character" for the dropdown); its texts; its tooltips.
function RunAnswer.block() return block end

function RunAnswer.buttons()
  local out = {}
  if not (block and block:IsShown()) then return out end
  for _, pair in pairs(block.answers) do
    for _, b in pairs(pair) do
      if b:IsShown() then out[b.label:GetText()] = b end
    end
  end
  for _, t in ipairs(block.roles) do
    if t:IsShown() then out[ns.PlannedRuns.ROLE_NAMES[t.choice.role]] = t end
  end
  if block.select:IsShown() then out.character = block.select end
  return out
end

function RunAnswer.texts()
  if not (block and block:IsShown()) then return {} end
  local out = { block.heading:GetText(), block.status:GetText() }
  if block.select:IsShown() then out[#out + 1] = block.select.text:GetText() end
  for _, t in ipairs(block.roles) do
    if t:IsShown() then out[#out + 1] = t.text:GetText() end
  end
  if block.count:IsShown() then out[#out + 1] = block.count:GetText() end
  return out
end

function RunAnswer.tips()
  if not (block and block:IsShown()) then return {} end
  local out = {}
  if block.clock:IsShown() then out[#out + 1] = block.clock.tip end
  for _, t in ipairs(block.roles) do
    if t:IsShown() and t.tooltip then out[#out + 1] = t.tooltip end
  end
  return out
end

ns.RunAnswer = RunAnswer
return RunAnswer
