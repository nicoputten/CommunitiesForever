-- SettingsWindow: the settings in the revamp's look (CF-43; design docs/design/revamp-2026-10/settings-setup.html).
-- A fixed 640 x 500 dialog with two columns of sections. Every control reads and writes through the option of
-- the same key in Settings.options() (one source of truth, CF-26); this file only lays them out. Built once,
-- refreshed from the options each time it opens.
local _, ns = ...

local SettingsWindow = {}
local Theme, Kit = ns.Theme, ns.Kit

local WIDTH, HEIGHT = 640, 500
local PAD, GAP = 22, 26
local COLUMN = math.floor((WIDTH - 2 * PAD - GAP) / 2)

local window, scroll
local controls = {}    -- option key -> control (checkbox, input, select)
local refreshers = {}  -- functions that show the current values
local rolePool, roleRows

local function option(key) return ns.Settings.option(key) end

local function label(parent, x, y, text, role, colorName)
  local fs = Theme.text(parent, role or "label", colorName or "faint")
  fs:SetPoint("TOPLEFT", x, -y)
  fs:SetText(text)
  return fs
end

-- A switch bound to an option; returns its height.
local function toggle(parent, key, x, y)
  local opt = option(key)
  local box = Kit.checkbox(parent, opt.name, opt.help, opt.get(), function(value) opt.set({}, value) end)
  box:SetPoint("TOPLEFT", x, -y)
  box:Fit(COLUMN) -- CF-61: the help wraps inside its column
  controls[key] = box
  refreshers[#refreshers + 1] = function() box:SetChecked(option(key).get()) end
  return box:GetHeight() + 6
end

local function section(parent, x, y, title)
  label(parent, x, y, title, "section", "goldLight")
  return y + 26
end

local function chatColor()
  local c = ns.Chat.color(ns.db.global.settings)
  return c.r, c.g, c.b
end

local function build()
  window = Kit.dialog({ title = "Settings", width = WIDTH, height = HEIGHT })
  window.footerText:SetText("Also under Options \194\187 AddOns")
  scroll = Kit.scrollArea(window.content)
  scroll:SetAllPoints(window.content)
  local body = scroll.child
  local left, right = PAD, PAD + COLUMN + GAP

  -- Display name and community.
  local y = 16
  label(body, left, y, "DISPLAY NAME")
  label(body, right, y, "COMMUNITY")
  local name = Kit.input(body, { width = COLUMN, maxLetters = 24, onCommit = function(text)
    option("displayName").set({}, text)
  end })
  name:SetPoint("TOPLEFT", left, -(y + 18))
  controls.displayName = name
  refreshers[#refreshers + 1] = function() name:SetValue(option("displayName").get()) end
  local community = Kit.select(body, function(clubId) option("community").set({}, clubId) end)
  community:SetPoint("TOPLEFT", right, -(y + 18))
  community:SetWidth(COLUMN)
  controls.community = community
  refreshers[#refreshers + 1] = function()
    local opt = option("community")
    local values, list = opt.values(), {}
    for _, clubId in ipairs(opt.sorting()) do list[#list + 1] = { value = clubId, text = values[clubId] } end
    community:SetChoices("Community", list, opt.get())
  end
  y = y + 76

  -- Sharing | Notifications.
  local ly, ry = section(body, left, y, "Sharing"), section(body, right, y, "Notifications")
  ly = ly + toggle(body, "groupAsks", left, ly)
  ry = ry + toggle(body, "notifications", right, ry)
  ry = ry + toggle(body, "levelUps", right, ry)
  ry = ry + toggle(body, "levelUpToast", right, ry) -- CF-44
  ly = ly + toggle(body, "doomsdayChat", left, ly) -- CF-57
  y = math.max(ly, ry) + 12

  -- CF-48: Planned runs: the notes and chime | the chat lines per kind.
  ly, ry = section(body, left, y, "Planned runs"), section(body, right, y, "Run chat lines")
  ly = ly + toggle(body, "runToasts", left, ly)
  ly = ly + toggle(body, "runSound", left, ly)
  for _, line in ipairs(ns.Settings.RUN_LINES) do
    ry = ry + toggle(body, "runLine_" .. line.kind, right, ry)
  end
  y = math.max(ly, ry) + 12

  -- Community chat | Interface.
  ly, ry = section(body, left, y, "Community chat"), section(body, right, y, "Interface")
  local swatch = Kit.swatch(body, function(self)
    local r, g, b = chatColor()
    ns.Panels.pickColor(r, g, b, function(nr, ng, nb)
      option("color").set({}, nr, ng, nb)
      self:SetColor(nr, ng, nb)
    end)
  end)
  swatch:SetPoint("TOPLEFT", left, -(ly + 2))
  controls.color = swatch
  refreshers[#refreshers + 1] = function() swatch:SetColor(chatColor()) end
  label(body, left + 28, ly + 4, option("color").name, "body", "text")
  local reset = Kit.button(body, option("resetColor").name, function()
    option("resetColor").func()
    swatch:SetColor(chatColor())
  end, "ghost")
  reset:SetPoint("TOPLEFT", left + COLUMN - 70, -ly)
  controls.resetColor = reset
  ly = ly + 32
  ly = ly + toggle(body, "alert", left, ly)
  ly = ly + toggle(body, "sound", left, ly)
  ly = ly + toggle(body, "keepGeneral", left, ly)
  local createTab = Kit.button(body, option("createTab").name, function() option("createTab").func() end)
  createTab:SetPoint("TOPLEFT", left, -(ly + 2))
  controls.createTab = createTab
  ly = ly + 36
  ry = ry + toggle(body, "minimap", right, ry)
  ry = ry + toggle(body, "openOnLogin", right, ry)
  ry = ry + toggle(body, "ambientEffects", right, ry)
  y = math.max(ly, ry) + 12

  -- CF-21: the invite link friends see on characters outside the community (to share, not to join: V26).
  local invite = CreateFrame("Frame", nil, body)
  invite:SetPoint("TOPLEFT", left, -y)
  invite:SetSize(WIDTH - 2 * PAD, 74)
  label(invite, 0, 0, "COMMUNITY INVITE LINK")
  local link = Kit.input(invite, { width = WIDTH - 2 * PAD, onCommit = function(text)
    local opt = option("inviteLink")
    opt.set({}, text)
    invite.field:SetValue(opt.get())
  end })
  link:SetPoint("TOPLEFT", 0, -18)
  invite.field = link
  label(invite, 0, 52, "Friends on characters outside the community see how to join with it. Empty: not shared.",
    "tiny", "faint")
  controls.inviteLink = link
  window.invite = invite

  -- CF-18: the role of each of your characters (Auto from talents, or set).
  window.rolesTop = y
  window.rolesTitle = label(body, left, y, "Roles of your characters", "section", "goldLight")
  rolePool = Kit.pool(function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(WIDTH - 2 * PAD, 30)
    r.name = Theme.text(r, "body", "text")
    r.name:SetPoint("LEFT")
    r.select = Kit.select(r, function(value) r.option.set({}, value) end)
    r.select:SetPoint("LEFT", COLUMN + GAP, 0)
    r.select:SetWidth(COLUMN)
    return r
  end)

  window.version = window.footerRightText
  Kit.release(rolePool)
end

-- The invite field shows only where it can be set; the roles follow your characters.
local function layoutLower()
  local body = scroll.child
  local y = window.rolesTop
  if not option("inviteLink").hidden() then
    window.invite:Show()
    window.invite:ClearAllPoints()
    window.invite:SetPoint("TOPLEFT", PAD, -y)
    window.invite.field:SetValue(option("inviteLink").get())
    y = y + 84
  else
    window.invite:Hide()
  end
  window.rolesTitle:ClearAllPoints()
  window.rolesTitle:SetPoint("TOPLEFT", PAD, -y)
  y = y + 28
  Kit.release(rolePool)
  roleRows = {}
  local roles = ns.Settings.rolesGroup().args
  local keys = {}
  for key in pairs(roles) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return (roles[a].order or 0) < (roles[b].order or 0) end)
  for _, key in ipairs(keys) do
    local opt = roles[key]
    local r = Kit.take(rolePool, body)
    r:SetPoint("TOPLEFT", PAD, -y)
    r.option = opt
    if opt.type == "select" then
      r.name:SetText(opt.name)
      r.select:Show()
      local list = {}
      for _, value in ipairs(opt.sorting) do list[#list + 1] = { value = value, text = opt.values[value] } end
      r.select:SetChoices(opt.name, list, opt.get())
    else
      r.name:SetText(opt.name) -- "No characters stored yet."
      r.select:Hide()
    end
    roleRows[#roleRows + 1] = r
    y = y + 34
  end
  body:SetHeight(y + 16)
  scroll:Update()
end

function SettingsWindow.open()
  if not window then build() end
  for _, refresh in ipairs(refreshers) do refresh() end
  layoutLower()
  window.footerRightText:SetText(ns.Version.label(ns.version))
  window:Show()
  if window.Raise then window:Raise() end
  if not window.escape then window.escape = ns.Keys.closeOnEscape(window, function() window:Hide() end) end
end

function SettingsWindow.isShown()
  return window ~= nil and window:IsShown()
end

-- For the specs: the window and its controls by option key, the role rows.
function SettingsWindow.window() return window end
function SettingsWindow.control(key) return controls[key] end
function SettingsWindow.roleRows() return roleRows or {} end

ns.SettingsWindow = SettingsWindow
return SettingsWindow
