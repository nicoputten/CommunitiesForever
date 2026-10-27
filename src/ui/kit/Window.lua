-- Kit window and tabs (CF-39): the revamp's window shell on native frames. Panel, gold border with corner
-- diamonds and a soft shadow, title bar (shield, title, subtitle, status text, settings and close), a tab
-- row, a content area and a footer line. Moves by its title, resizes from the corner, remembers both.
local _, ns = ...

local Kit = ns.Kit or {}
local Theme = ns.Theme

-- The design size, applied once to every window saved before the revamp (decided: reset to 880 x 600).
Kit.LAYOUT_VERSION = 2

-- Size and position from a status table { width, height, top, left, layout } (the keys AceGUI used, so a
-- saved window keeps working, rule 8). Returns width, height, top, left (top/left nil: centred).
function Kit.windowGeometry(status)
  local S = Theme.SIZES
  if status.layout ~= Kit.LAYOUT_VERSION then
    return S.windowWidth, S.windowHeight, nil, nil
  end
  local width = math.max(S.minWidth, tonumber(status.width) or S.windowWidth)
  local height = math.max(S.minHeight, tonumber(status.height) or S.windowHeight)
  return width, height, tonumber(status.top), tonumber(status.left)
end

local function save(frame)
  local status = frame.status
  status.width, status.height = frame:GetWidth(), frame:GetHeight()
  status.top, status.left = frame:GetTop(), frame:GetLeft()
  status.layout = Kit.LAYOUT_VERSION
end

local function corner(frame, point)
  local d = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  d:SetSize(16, 16)
  d:SetTexture(Theme.TEXTURES.diamond)
  d:SetPoint("CENTER", frame, point)
  return d
end

--[[ opts = { title, subtitle, status (saved table), onClose(), onSettings(), onResize(window) }.
Returns the frame with .content (the area between tab row and footer), .tabBar, .titleText,
.subtitleText, .statusText, .footerText. ]]
function Kit.window(opts)
  local S = Theme.SIZES
  local f = CreateFrame("Frame", nil, UIParent)
  f.status = opts.status or {}
  f:SetFrameStrata("DIALOG") -- one below Blizzard's menus (CF-37)
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(S.minWidth, S.minHeight) end -- unverified, V61

  local width, height, top, left = Kit.windowGeometry(f.status)
  f:SetSize(width, height)
  f:ClearAllPoints()
  if top and left then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top) else f:SetPoint("CENTER") end

  -- Panel, soft shadow behind it, gold border with a dark line inside, corner diamonds.
  local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  shadow:SetTexture(Theme.TEXTURES.shadow)
  shadow:SetPoint("TOPLEFT", -16, 16)
  shadow:SetPoint("BOTTOMRIGHT", 16, -24)
  local bg = Theme.fill(f, "panel", "BACKGROUND")
  bg:SetAllPoints()
  f.border = Kit.edges(f, "border", "BORDER")
  f.innerLine = Kit.edges(f, "outline", "BORDER", 1)
  f.corners = { corner(f, "TOPLEFT"), corner(f, "TOPRIGHT"), corner(f, "BOTTOMLEFT"), corner(f, "BOTTOMRIGHT") }

  -- Title bar: drag to move.
  local title = CreateFrame("Frame", nil, f)
  title:SetPoint("TOPLEFT", 1, -1)
  title:SetPoint("TOPRIGHT", -1, -1)
  title:SetHeight(S.titleBar)
  title:EnableMouse(true)
  title:RegisterForDrag("LeftButton")
  title:SetScript("OnDragStart", function() f:StartMoving() end)
  title:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    save(f)
  end)
  local glow = title:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 1, 1, 1)
  if glow.SetGradient and CreateColor then -- unverified, V61
    glow:SetGradient("VERTICAL", CreateColor(0.831, 0.686, 0.416, 0), CreateColor(0.831, 0.686, 0.416, 0.10))
  else
    glow:SetColorTexture(0.831, 0.686, 0.416, 0.05)
  end
  local titleLine = Theme.fill(title, "titleLine", "BORDER")
  titleLine:SetPoint("BOTTOMLEFT")
  titleLine:SetPoint("BOTTOMRIGHT")
  titleLine:SetHeight(1)
  local shield = title:CreateTexture(nil, "ARTWORK")
  shield:SetSize(20, 20)
  shield:SetPoint("LEFT", 16, 0)
  shield:SetTexture(Theme.TEXTURES.shield)
  f.titleText = Theme.text(title, "windowTitle", "goldPale")
  f.titleText:SetPoint("LEFT", shield, "RIGHT", 10, 0)
  f.titleText:SetText(opts.title or "")
  f.subtitleText = Theme.text(title, "tiny", "faint")
  f.subtitleText:SetPoint("LEFT", f.titleText, "RIGHT", 10, -1)
  f.subtitleText:SetText(opts.subtitle or "")
  f.closeButton = Kit.iconButton(title, "close", function() f:Hide() end)
  f.closeButton:SetPoint("RIGHT", -10, 0)
  f.settingsButton = Kit.iconButton(title, "gear", function() if opts.onSettings then opts.onSettings() end end)
  f.settingsButton:SetPoint("RIGHT", f.closeButton, "LEFT", -6, 0)
  f.statusText = Theme.text(title, "small", "onlineText")
  f.statusText:SetPoint("RIGHT", f.settingsButton, "LEFT", -10, 0)
  f.titleBar = title
  -- CF-43: a slow shimmer across the title (Ambient effects).
  f.shimmer = Kit.shine(title, f.titleText, 9)

  -- Tab row.
  local tabBar = CreateFrame("Frame", nil, f)
  tabBar:SetPoint("TOPLEFT", title, "BOTTOMLEFT")
  tabBar:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT")
  tabBar:SetHeight(S.tabBar)
  local tabLine = Theme.fill(tabBar, "divider", "BORDER")
  tabLine:SetPoint("BOTTOMLEFT")
  tabLine:SetPoint("BOTTOMRIGHT")
  tabLine:SetHeight(1)
  f.tabBar = tabBar

  -- Footer line.
  local footer = CreateFrame("Frame", nil, f)
  footer:SetPoint("BOTTOMLEFT", 1, 1)
  footer:SetPoint("BOTTOMRIGHT", -1, 1)
  footer:SetHeight(S.footer)
  local footerLine = Theme.fill(footer, "divider", "BORDER")
  footerLine:SetPoint("TOPLEFT")
  footerLine:SetPoint("TOPRIGHT")
  footerLine:SetHeight(1)
  f.footerText = Theme.text(footer, "tiny", "faint")
  f.footerText:SetPoint("LEFT", 14, 0)
  f.footerRightText = Theme.text(footer, "tiny", "faint")
  f.footerRightText:SetPoint("RIGHT", -24, 0)
  f.footer = footer

  -- Content between the tab row and the footer.
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT")
  content:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")
  f.content = content

  -- Resize grip in the bottom-right corner.
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    save(f)
  end)
  f.grip = grip

  f:SetScript("OnSizeChanged", function() if opts.onResize then opts.onResize(f) end end)
  f:SetScript("OnHide", function() if opts.onClose then opts.onClose() end end)
  return f
end

--[[ CF-43: a fixed-size dialog in the same look (settings, setup): the window without tabs, settings button,
resize grip or saved size. opts = { title, width, height, onClose() }. Content fills title bar to footer. ]]
function Kit.dialog(opts)
  local f = Kit.window({ title = opts.title, status = {}, onClose = opts.onClose })
  f:SetSize(opts.width, opts.height)
  f:SetResizable(false)
  f.grip:Hide()
  f.settingsButton:Hide()
  f.tabBar:Hide()
  f.tabBar:SetHeight(1)
  f.content:ClearAllPoints()
  f.content:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT")
  f.content:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT")
  return f
end

--[[ Tabs in a tab row: defs = { { value, text } }, onSelect(value). Returns an object with
select(value), setBadge(value, count) and buttons[value]. The active tab is pale gold with a gold
underline; a badge shows a count ("Dungeons (1)" in the design). ]]
function Kit.tabs(parent, defs, onSelect)
  local tabs = { buttons = {} }
  local previous
  for _, def in ipairs(defs) do
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(Theme.SIZES.tabBar)
    b.value = def.value
    b.text = Theme.text(b, "tab", "muted")
    b.text:SetPoint("LEFT", 14, 0)
    b.text:SetText(def.text)
    b.underline = Theme.fill(b, "gold", "ARTWORK")
    b.underline:SetPoint("BOTTOMLEFT")
    b.underline:SetPoint("BOTTOMRIGHT")
    b.underline:SetHeight(2)
    b.activeBg = b:CreateTexture(nil, "BACKGROUND")
    b.activeBg:SetAllPoints()
    b.activeBg:SetColorTexture(0.831, 0.686, 0.416, 0.08)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(16, 16)
    b.badge:SetPoint("LEFT", b.text, "RIGHT", 6, 0)
    local badgeBg = b.badge:CreateTexture(nil, "ARTWORK")
    badgeBg:SetAllPoints()
    badgeBg:SetTexture(Theme.TEXTURES.circle)
    badgeBg:SetVertexColor(Theme.color("gold"))
    b.badgeText = Theme.text(b.badge, "badge", "outline")
    b.badgeText:SetPoint("CENTER")
    b.badge:Hide()
    local width = b.text.GetStringWidth and b.text:GetStringWidth() or 60
    b:SetWidth(width + 28)
    if previous then b:SetPoint("LEFT", previous, "RIGHT", 4, 0) else b:SetPoint("LEFT", 12, 0) end
    b:SetScript("OnClick", function() if onSelect then onSelect(def.value) end end)
    tabs.buttons[def.value] = b
    previous = b
  end

  function tabs.select(value)
    tabs.active = value
    for v, b in pairs(tabs.buttons) do
      local on = v == value
      b.text:SetTextColor(Theme.color(on and "goldPale" or "muted"))
      if on then b.underline:Show() b.activeBg:Show() else b.underline:Hide() b.activeBg:Hide() end
    end
  end

  function tabs.setBadge(value, count)
    local b = tabs.buttons[value]
    if not b then return end
    b.badgeCount = count
    if count and count > 0 then
      b.badgeText:SetText(tostring(count))
      b.badge:Show()
      local width = b.text.GetStringWidth and b.text:GetStringWidth() or 60
      b:SetWidth(width + 50)
    else
      b.badge:Hide()
    end
  end

  return tabs
end

ns.Kit = Kit
return Kit
