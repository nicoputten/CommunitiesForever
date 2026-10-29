-- PlanInline: "Plan a run" inline in a dungeon's detail (CF-63c, board docs/design/cf-63-2026-10/CF63List.dc.html
-- G and H). Chips for the next three evenings at 20:00 your time and "Other time…" (the Plan a run dialog), the
-- character you lead as (your best fit preselected, an alt when you're out of range), its roles, a note, Plan and
-- Cancel. Plan queues the run like the dialog does (Planner.plan) and asks for the reload. One box, moved to the
-- dungeon on each draw.
local _, ns = ...

local PlanInline = {}
local Theme, Kit = ns.Theme, ns.Kit

local FIT_COLOR = { fits = "online", over = "online", low = "warning", carry = "warning", tooLow = "warning" }
PlanInline.WIDTH = 300
PlanInline.HEIGHT = 196

local box
local state = {} -- { dungeon, chip, guid, role, note } while the box is open

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
PlanInline.chip = chip -- the list's filter chips look the same

local function create(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(PlanInline.WIDTH, PlanInline.HEIGHT)
  local bg = Theme.fill(b, "gold", "BACKGROUND")
  bg:SetAllPoints()
  bg:SetAlpha(0.05)
  b.edges = Kit.edges(b, "border")
  b.heading = Theme.text(b, "section", "goldLight")
  b.heading:SetPoint("TOPLEFT", 12, -10)
  b.heading:SetText("Plan a run")
  b.chips = {}
  for i = 1, 4 do b.chips[i] = chip(b) end
  b.select = CreateFrame("Button", nil, b)
  b.select:SetHeight(28)
  local sbg = Theme.fill(b.select, "input", "BACKGROUND")
  sbg:SetAllPoints()
  b.select.edges = Kit.edges(b.select, "border")
  b.select.portrait = Kit.portrait(b.select, 18)
  b.select.portrait:SetPoint("LEFT", 8, 0)
  b.select.text = Theme.text(b.select, "body", "text")
  b.select.text:SetPoint("LEFT", 32, 0)
  local arrow = b.select:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(10, 10)
  arrow:SetPoint("RIGHT", -10, 0)
  arrow:SetTexture(Theme.TEXTURES.arrow)
  arrow:SetVertexColor(Theme.color("gold"))
  b.roles = {}
  for i = 1, 3 do
    local t = chip(b)
    t.icon = Kit.roleIcon(t, 16)
    t.icon:SetPoint("LEFT", 8, 0)
    t.text:ClearAllPoints()
    t.text:SetPoint("LEFT", 30, 0)
    b.roles[i] = t
  end
  b.note = Kit.input(b, { maxLetters = ns.Pending.MAX_NOTE, onCommit = function(text) state.note = text end })
  b.hint = Theme.text(b.note, "body", "faint")
  b.hint:SetPoint("LEFT", 10, 0)
  b.hint:SetText("Note")
  b.note:SetScript("OnTextChanged", function(self) b.hint:SetShown((self:GetText() or "") == "") end)
  b.plan = Kit.button(b, "Plan", nil, "primary")
  b.plan:SetHeight(30)
  b.cancel = Kit.button(b, "Cancel", nil)
  b.cancel:SetHeight(30)
  box = b
  return b
end

-- "Ada Lovewell  23  fits" with colours.
local function charText(o)
  local c = o.char
  return Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(c.name) .. "|r  " .. Theme.code("muted")
    .. tostring(c.level or "?") .. "|r  " .. Theme.code(FIT_COLOR[o.fit.kind] or "muted") .. o.fit.label .. "|r"
end

-- Opens the box for a dungeon (the detail draws it); closes it for any other.
function PlanInline.open(dungeon) state = { dungeon = dungeon and dungeon.id } end
function PlanInline.close() state = {} end
function PlanInline.isOpen(dungeon) return dungeon ~= nil and state.dungeon == dungeon.id end

--[[ Draws the box at x, y below parent's top left for dungeon. candidates: Dungeons.candidates; selfGuid: the
character the list follows. onChange(): redraw. Returns the height. ]]
function PlanInline.render(parent, dungeon, candidates, selfGuid, x, y, onChange)
  local b = box or create(parent)
  b:SetParent(parent)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", x, -y)
  b:Show()
  local now = GetServerTime()
  local chips = date and ns.PlannedRuns.planChips(now, date, ns.Panels.localTime) or {}
  state.chip = state.chip or (chips[1] and 1)

  local cx = 12
  for i, c in ipairs(b.chips) do
    local def = chips[i]
    if i == #b.chips or def then
      local other = i == #b.chips
      c:Show()
      c:SetChip(other and "Other time\226\128\166" or def.label, not other and state.chip == i)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", cx, -36)
      c:SetScript("OnClick", function()
        if other then
          PlanInline.close()
          ns.RunDialogs.plan(dungeon)
        else
          state.chip = i
        end
        onChange()
      end)
      cx = cx + c:GetWidth() + 6
    else
      c:Hide()
    end
  end

  -- The character: the one picked, else your best fit for the dungeon (an alt when you're out of range).
  local options = ns.PlannedRuns.charChoices(candidates, dungeon, selfGuid)
  local option = options[1]
  for _, o in ipairs(options) do
    if o.char.guid == state.guid then option = o end
  end
  local c = option and option.char
  b.select:SetShown(c ~= nil)
  if c then
    b.select.text:SetText(charText(option))
    b.select.portrait:SetClass(c.classFile)
    b.select:SetWidth(math.min(PlanInline.WIDTH - 24, 32 + math.ceil(b.select.text:GetStringWidth() or 160) + 30))
    b.select:ClearAllPoints()
    b.select:SetPoint("TOPLEFT", 12, -72)
    b.select:SetScript("OnClick", function(owner)
      local items = {}
      for i, o in ipairs(options) do items[i] = { label = charText(o), enabled = true, option = o } end
      ns.ContextMenu.open(owner, { items = items }, function(item)
        state.guid, state.role = item.option.char.guid, nil
        onChange()
      end)
    end)
  end
  local role = c and ((state.role and ns.PlannedRuns.canPlay(c.classFile, state.role) and state.role)
    or ns.PlannedRuns.defaultRole(c.classFile, c.role))
  local rx = 12
  local classRoles = c and ns.PlannedRuns.rolesFor(c.classFile) or {}
  for i, t in ipairs(b.roles) do
    local r = classRoles[i]
    t:SetShown(r ~= nil)
    if r then
      t:SetChip(ns.PlannedRuns.ROLE_NAMES[r], r == role)
      t:SetWidth(t:GetWidth() + 22)
      t.icon:SetRole(r)
      t.role = r
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", rx, -108)
      t:SetScript("OnClick", function()
        state.role = r
        onChange()
      end)
      rx = rx + t:GetWidth() + 6
    end
  end

  b.note:ClearAllPoints()
  b.note:SetPoint("TOPLEFT", 12, -146)
  b.note:SetWidth(PlanInline.WIDTH - 24 - 140)
  if not (b.note.HasFocus and b.note:HasFocus()) then b.note:SetValue(state.note or "") end
  b.hint:SetShown((b.note:GetText() or "") == "")
  b.plan:ClearAllPoints()
  b.plan:SetPoint("LEFT", b.note, "RIGHT", 8, 0)
  b.cancel:ClearAllPoints()
  b.cancel:SetPoint("LEFT", b.plan, "RIGHT", 6, 0)
  local pick = state.chip and chips[state.chip]
  b.plan:SetEnabled(pick ~= nil and c ~= nil)
  b.plan:SetScript("OnClick", function()
    if not (pick and c) then return end
    local typed = b.note:GetText()
    ns.Planner.plan(dungeon.id, pick.startsAt, { guid = c.guid, name = c.name, role = role }, typed)
    PlanInline.close()
    onChange()
    ns.RunDialogs.reloadPrompt()
  end)
  b.cancel:SetScript("OnClick", function()
    PlanInline.close()
    onChange()
  end)
  return PlanInline.HEIGHT
end

function PlanInline.hide() if box then box:Hide() end end

-- For the specs: the box (nil before the first draw), its shown buttons by label (chips, roles, Plan, Cancel,
-- "character" for the dropdown).
function PlanInline.box() return box end
function PlanInline.buttons()
  local out = {}
  if not (box and box:IsShown()) then return out end
  for _, c in ipairs(box.chips) do
    if c:IsShown() then out[c.text:GetText()] = c end
  end
  for _, t in ipairs(box.roles) do
    if t:IsShown() then out[t.text:GetText()] = t end
  end
  out.Plan, out.Cancel = box.plan, box.cancel
  if box.select:IsShown() then out.character = box.select end
  return out
end
function PlanInline.texts()
  if not (box and box:IsShown()) then return {} end
  local out = { box.heading:GetText() }
  if box.select:IsShown() then out[#out + 1] = box.select.text:GetText() end
  return out
end

ns.PlanInline = PlanInline
return PlanInline
