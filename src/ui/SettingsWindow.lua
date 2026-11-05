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
local switches = {}    -- CF-67: the switches' refreshers (a switch may grey out another)
local rolePool, roleRows

local function option(key) return ns.Settings.option(key) end

local function label(parent, x, y, text, role, colorName)
  local fs = Theme.text(parent, role or "label", colorName or "faint")
  fs:SetPoint("TOPLEFT", x, -y)
  fs:SetText(text)
  return fs
end

-- A switch bound to an option; returns its height.
-- CF-67: a tooltip on a control from its option's `tip`.
local function tip(control, text)
  if not text then return end
  control:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function toggle(parent, key, x, y)
  local opt = option(key)
  local box = Kit.checkbox(parent, opt.name, opt.help, opt.get(), function(value)
    opt.set({}, value)
    for _, refresh in ipairs(switches) do refresh() end -- CF-67: a switch may grey out another
  end)
  box:SetPoint("TOPLEFT", x, -y)
  box:Fit(COLUMN) -- CF-61: the help wraps inside its column
  tip(box, opt.tip)
  controls[key] = box
  local function refresh()
    local o = option(key)
    box:SetChecked(o.get())
    box:SetEnabled(not (o.disabled and o.disabled()))
  end
  refreshers[#refreshers + 1] = refresh
  switches[#switches + 1] = refresh
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
  local colorLabel = label(body, left + 28, ly + 4, option("color").name, "body", "text")
  local reset = Kit.button(body, option("resetColor").name, function()
    option("resetColor").func()
    swatch:SetColor(chatColor())
  end, "ghost")
  reset:SetPoint("TOPLEFT", left + COLUMN - 70, -ly)
  controls.resetColor = reset
  local chatTop = ly
  ly = ly + 32
  ly = ly + toggle(body, "alert", left, ly)
  ly = ly + toggle(body, "sound", left, ly)
  ly = ly + toggle(body, "keepGeneral", left, ly)
  local createTab = Kit.button(body, option("createTab").name, function() option("createTab").func() end)
  createTab:SetPoint("TOPLEFT", left, -(ly + 2))
  controls.createTab = createTab
  -- CF-86: with the guild picked only the tab button shows, right under the section title. The column on the
  -- right is longer either way, so nothing below moves.
  local tabY = ly
  refreshers[#refreshers + 1] = function()
    local guild = option("alert").hidden()
    for _, c in ipairs({ swatch, colorLabel, reset, controls.alert, controls.sound, controls.keepGeneral }) do
      if guild then c:Hide() else c:Show() end
    end
    createTab:ClearAllPoints()
    createTab:SetPoint("TOPLEFT", left, -((guild and chatTop or tabY) + 2))
  end
  ly = ly + 36
  ry = ry + toggle(body, "minimap", right, ry)
  ry = ry + toggle(body, "openOnLogin", right, ry)
  ry = ry + toggle(body, "ambientEffects", right, ry)
  -- CF-67: Celebrations (board CB09), under Interface.
  ry = section(body, right, ry + 12, "Celebrations")
  ry = ry + toggle(body, "celebrations", right, ry)
  ry = ry + toggle(body, "celebrationSounds", right, ry)
  ry = ry + toggle(body, "celebrationFriends", right, ry)
  local preview = Kit.button(body, option("celebrationPreview").name, function()
    option("celebrationPreview").func()
  end)
  preview:SetPoint("TOPLEFT", right, -(ry + 2))
  tip(preview, option("celebrationPreview").tip)
  controls.celebrationPreview = preview
  ry = ry + 36
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

  -- CF-84: the guild code, masked (EditBox:SetPassword, V130) and emptied after each commit: it is never shown.
  local guild = CreateFrame("Frame", nil, body)
  guild:SetSize(WIDTH - 2 * PAD, 74)
  label(guild, 0, 0, "GUILD CODE")
  local function commitCode(text)
    if text ~= "" then option("guildCode").set({}, text) end
    guild.field:SetValue("")
    guild.status:SetText(option("guildCode").status())
  end
  local code = Kit.input(guild, { width = WIDTH - 2 * PAD, maxLetters = ns.GuildInvite.CODE_MAX,
                                  onCommit = commitCode })
  code:SetPoint("TOPLEFT", 0, -18)
  guild.masked = code.SetPassword ~= nil
  if guild.masked then code:SetPassword(true) else code:Hide() end
  guild.field = code
  guild.status = label(guild, 0, 52, "", "tiny", "faint")
  controls.guildCode = code
  window.guild = guild

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

-- The invite field shows only where it can be set, the guild code only with the guild picked (CF-84); the roles
-- follow your characters.
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
  if not option("guildCode").hidden() then
    window.guild:Show()
    window.guild:ClearAllPoints()
    window.guild:SetPoint("TOPLEFT", PAD, -y)
    window.guild.field:SetValue("")
    window.guild.status:SetText(window.guild.masked and option("guildCode").status()
      or ns.Settings.GUILD_CODE_NO_MASK)
    y = y + 84
  else
    window.guild:Hide()
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
