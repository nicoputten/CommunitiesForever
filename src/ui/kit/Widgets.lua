-- Kit widgets (CF-39): Button, IconButton, Checkbox, ListRow, SkillBar, Portrait and Toast on native frames,
-- styled by Theme. The window shell uses Button and IconButton; the screen stories (CF-40 to CF-44) use the rest.
local _, ns = ...

local Kit = ns.Kit or {}
local Theme = ns.Theme

-- 1 px lines around a frame (gold borders, button edges). Returns the four textures.
function Kit.edges(frame, colorName, layer, inset)
  inset = inset or 0
  local lines = {}
  for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = Theme.fill(frame, colorName, layer or "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT", inset, side == "TOP" and -inset or inset)
      t:SetPoint(side .. "RIGHT", -inset, side == "TOP" and -inset or inset)
      t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side, side == "LEFT" and inset or -inset, -inset)
      t:SetPoint("BOTTOM" .. side, side == "LEFT" and inset or -inset, inset)
      t:SetWidth(1)
    end
    lines[i] = t
  end
  return lines
end

-- Button with the gold look. kind: "normal", "primary" or "ghost". onClick(button).
function Kit.button(parent, text, onClick, kind)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(Theme.SIZES.button)
  b.kind = kind or "normal"
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  if b.kind == "primary" then
    bg:SetColorTexture(Theme.color("gold"))
  elseif b.kind == "normal" then
    bg:SetColorTexture(0.831, 0.686, 0.416, 0.12)
  else
    bg:SetColorTexture(0, 0, 0, 0)
  end
  b.edges = Kit.edges(b, b.kind == "ghost" and "divider" or "border")
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.06)
  b.label = Theme.text(b, "button", b.kind == "primary" and "outline" or "goldPale")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
  function b:SetLabel(label)
    self.label:SetText(label)
    local width = self.label.GetStringWidth and self.label:GetStringWidth() or 0
    self:SetWidth(math.max(60, width + 24))
  end
  -- Disabled at 40% (the design's :disabled).
  local setEnabled = b.SetEnabled
  function b:SetEnabled(on)
    if setEnabled then setEnabled(self, on) end
    self.enabled = on and true or false
    self:SetAlpha(on and 1 or 0.4)
  end
  b.enabled = true
  b:SetLabel(text or "")
  return b
end

-- Square icon button (title bar: settings, close). texture: a Theme.TEXTURES key.
function Kit.iconButton(parent, texture, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(Theme.SIZES.iconButton, Theme.SIZES.iconButton)
  b.edges = Kit.edges(b, "titleLine")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(12, 12)
  icon:SetPoint("CENTER")
  icon:SetTexture(Theme.TEXTURES[texture])
  icon:SetVertexColor(Theme.color("goldLight"))
  b.icon = icon
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.06)
  b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
  return b
end

-- Checkbox with a label and an optional second line. onChange(checked).
function Kit.checkbox(parent, label, help, checked, onChange)
  local c = CreateFrame("Button", nil, parent)
  c:SetHeight(help and 34 or 22)
  local box = c:CreateTexture(nil, "ARTWORK")
  box:SetSize(16, 16)
  box:SetPoint("TOPLEFT", 0, -2)
  local mark = c:CreateTexture(nil, "OVERLAY")
  mark:SetSize(14, 14)
  mark:SetPoint("CENTER", box)
  mark:SetTexture(Theme.TEXTURES.check)
  mark:SetVertexColor(Theme.color("outline"))
  c.text = Theme.text(c, "body", "text")
  c.text:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 1)
  c.text:SetText(label)
  if help then
    c.help = Theme.text(c, "tiny", "faint")
    c.help:SetPoint("TOPLEFT", c.text, "BOTTOMLEFT", 0, -2)
    c.help:SetText(help)
  end
  function c:SetChecked(on)
    self.checked = on and true or false
    if self.checked then
      box:SetColorTexture(Theme.color("gold"))
      mark:Show()
    else
      box:SetColorTexture(Theme.color("track"))
      mark:Hide()
    end
  end
  function c:GetChecked() return self.checked end
  c:SetScript("OnClick", function(self)
    self:SetChecked(not self.checked)
    if onChange then onChange(self.checked) end
  end)
  c:SetChecked(checked)
  return c
end

-- A 28 px list row with hover and selected states (gold left bar).
function Kit.listRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(Theme.SIZES.row)
  local hover = r:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(Theme.color("hover"))
  r.selectedBg = Theme.fill(r, "selected", "BACKGROUND")
  r.selectedBg:SetAllPoints()
  r.selectedBar = Theme.fill(r, "gold", "ARTWORK")
  r.selectedBar:SetPoint("TOPLEFT")
  r.selectedBar:SetPoint("BOTTOMLEFT")
  r.selectedBar:SetWidth(3)
  function r:SetSelected(on)
    self.selected = on and true or false
    if self.selected then
      self.selectedBg:Show()
      self.selectedBar:Show()
    else
      self.selectedBg:Hide()
      self.selectedBar:Hide()
    end
  end
  r:SetSelected(false)
  return r
end

-- Fractions for a skill bar: fill = value / max, cap = cap / max (0..1, clamped). Pure, for the specs too.
function Kit.barFractions(value, max, cap)
  local function clamp(x) return math.max(0, math.min(1, x)) end
  if not max or max <= 0 then return 0, 0 end
  return clamp((value or 0) / max), clamp((cap or 0) / max)
end

-- Skill bar: track, cap shading, fill and tick lines (fractions 0..1). The fill follows the bar's width.
function Kit.skillBar(parent, height)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(height or 7)
  local track = Theme.fill(bar, "track", "BACKGROUND")
  track:SetAllPoints()
  local cap = bar:CreateTexture(nil, "BORDER")
  cap:SetColorTexture(0.831, 0.686, 0.416, 0.16)
  cap:SetPoint("TOPLEFT")
  cap:SetPoint("BOTTOMLEFT")
  local fill = Theme.fill(bar, "gold", "ARTWORK")
  fill:SetPoint("TOPLEFT")
  fill:SetPoint("BOTTOMLEFT")
  bar.cap, bar.fill, bar.ticks = cap, fill, {}
  local function layout(self)
    local width = self:GetWidth() or 0
    self.fill:SetWidth(math.max(0.001, width * (self.fillFraction or 0)))
    self.cap:SetWidth(math.max(0.001, width * (self.capFraction or 0)))
    for i, t in ipairs(self.ticks) do
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", width * (self.tickFractions[i] or 0), 0)
      t:SetPoint("BOTTOMLEFT", width * (self.tickFractions[i] or 0), 0)
    end
  end
  -- value, max: the fill; cap: shaded up to here; ticks: fractions; color: { r, g, b } or nil (gold).
  function bar:SetValues(value, max, cap_, ticks, color)
    self.fillFraction, self.capFraction = Kit.barFractions(value, max, cap_)
    self.tickFractions = ticks or {}
    for i = #self.ticks + 1, #self.tickFractions do
      local t = self:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(0.027, 0.047, 0.082, 0.9)
      t:SetWidth(1)
      self.ticks[i] = t
    end
    for i, t in ipairs(self.ticks) do
      if i <= #self.tickFractions then t:Show() else t:Hide() end
    end
    if color then self.fill:SetColorTexture(color[1], color[2], color[3], 1)
    else self.fill:SetColorTexture(Theme.color("gold")) end
    layout(self)
  end
  bar:SetScript("OnSizeChanged", layout)
  return bar
end

-- Class colour for a class file, from C_ClassColor (unverified, V61) or RAID_CLASS_COLORS.
function Kit.classColor(classFile)
  if classFile and C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c then return c.r, c.g, c.b end
  end
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return c.r, c.g, c.b end
  return Theme.color("muted")
end

-- Round class portrait: the class icon in a circle mask, a class-coloured ring, an optional online dot.
-- Class icons from the round class atlas texture with CLASS_ICON_TCOORDS; the mask from CreateMaskTexture
-- (both unverified, V61).
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

function Kit.portrait(parent, size)
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(size, size)
  local icon = p:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", -1, 1)
  if p.CreateMaskTexture then
    local mask = p:CreateMaskTexture()
    mask:SetTexture(Theme.TEXTURES.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
  end
  local ring = p:CreateTexture(nil, "OVERLAY")
  ring:SetAllPoints()
  ring:SetTexture(Theme.TEXTURES.ring)
  local dot = p:CreateTexture(nil, "OVERLAY", nil, 2)
  dot:SetSize(math.max(6, size / 4), math.max(6, size / 4))
  dot:SetPoint("BOTTOMRIGHT", 1, -1)
  dot:SetTexture(Theme.TEXTURES.circle)
  dot:SetVertexColor(Theme.color("online"))
  p.icon, p.ring, p.dot = icon, ring, dot
  function p:SetClass(classFile)
    self.classFile = classFile
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
      self.icon:SetTexture(CLASS_ICONS)
      self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
      self.icon:SetColorTexture(Theme.color("track"))
    end
    self.ring:SetVertexColor(Kit.classColor(classFile))
  end
  function p:SetOnline(on)
    self.online = on and true or false
    if self.online then self.dot:Show() else self.dot:Hide() end
  end
  p:SetOnline(false)
  return p
end

-- Toast: a pill at the top of the screen that fades out (the level-up announcement, CF-44).
Kit.TOAST_SECONDS = 6

function Kit.toast(parent)
  local t = CreateFrame("Frame", nil, parent or UIParent)
  t:SetHeight(48)
  t:SetFrameStrata("DIALOG")
  local bg = Theme.fill(t, "panel", "BACKGROUND")
  bg:SetAllPoints()
  t.edges = Kit.edges(t, "border")
  t.portrait = Kit.portrait(t, Theme.SIZES.portraitMedium - 4)
  t.portrait:SetPoint("LEFT", 10, 0)
  t.text = Theme.text(t, "body", "text")
  t.text:SetPoint("LEFT", t.portrait, "RIGHT", 10, 0)
  t:Hide()
  -- Shows text (and a class portrait) for Kit.TOAST_SECONDS, then hides.
  function t:Announce(text, classFile)
    self.text:SetText(text)
    self.portrait:SetClass(classFile)
    local width = self.text.GetStringWidth and self.text:GetStringWidth() or 200
    self:SetWidth(width + 70)
    self:SetAlpha(1)
    self:Show()
    if self.timer then self.timer:Cancel() end
    self.timer = C_Timer.NewTimer(Kit.TOAST_SECONDS, function()
      self.timer = nil
      self:Hide()
    end)
  end
  return t
end

--[[ Scroll area (CF-40): a ScrollFrame with a child frame for the content, scrolled by the mouse wheel, and a
thin gold thumb on the right while the content is taller than the area. Plain ScrollFrame API, no templates
(decided over ScrollBox, which is unverified). area.child is where content goes; call area:Update() after
changing the child's height. ]]
Kit.SCROLL_STEP = 40

function Kit.scrollArea(parent)
  local area = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, area)
  child:SetSize(1, 1)
  area:SetScrollChild(child)
  area.child = child
  local thumb = Theme.fill(area, "gold", "OVERLAY")
  thumb:SetWidth(3)
  thumb:SetAlpha(0.6)
  area.thumb = thumb
  area.offset = 0

  local function range(self)
    return math.max(0, (self.child:GetHeight() or 0) - (self:GetHeight() or 0))
  end

  function area:SetOffset(offset)
    self.offset = math.max(0, math.min(range(self), offset or 0))
    self:SetVerticalScroll(self.offset)
    self:Update()
  end

  -- Child width follows the area; the thumb shows the visible part.
  function area:Update()
    local height, total = self:GetHeight() or 0, self.child:GetHeight() or 0
    self.child:SetWidth(math.max(1, (self:GetWidth() or 0) - 6))
    if total <= height or height <= 0 then
      self.thumb:Hide()
      return
    end
    self.thumb:Show()
    local size = math.max(20, height * height / total)
    local top = (height - size) * (self.offset / math.max(1, total - height))
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOPRIGHT", -1, -top)
    self.thumb:SetHeight(size)
  end

  area:EnableMouseWheel(true)
  area:SetScript("OnMouseWheel", function(self, delta) self:SetOffset(self.offset - delta * Kit.SCROLL_STEP) end)
  area:SetScript("OnSizeChanged", function(self) self:Update() end)
  return area
end

--[[ Pools (CF-40, shared by the tabs since CF-41): frames are reused on every render, since WoW frames cannot
be destroyed. Kit.take gives the next free item (made by factory(parent) when needed), shown and without
anchors; Kit.release hides all items of a pool. ]]
function Kit.pool(factory)
  return { items = {}, used = 0, factory = factory }
end

function Kit.take(p, parent)
  p.used = p.used + 1
  local item = p.items[p.used]
  if not item then
    item = p.factory(parent)
    p.items[p.used] = item
  end
  item:Show()
  item:ClearAllPoints()
  return item
end

function Kit.release(p)
  for i = 1, #p.items do p.items[i]:Hide() end
  p.used = 0
end

-- A factory for pooled texts: a tiny frame holding one FontString (holder.text) in a text role.
function Kit.textHolder(role)
  return function(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(1, 1)
    holder.text = Theme.text(holder, role, "text")
    holder.text:SetPoint("TOPLEFT")
    holder.text:SetJustifyH("LEFT")
    return holder
  end
end

ns.Kit = Kit
return Kit
