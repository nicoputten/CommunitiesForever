-- GuildInvitePopup: the member's "Guild invite" window (CF-84, CF-87, CF-88; boards GI01Window, GI02Screen).
-- On Forever an addon cannot send a guild invite in any way (API-FINDINGS.md "Guild invites"): the window shows
-- "/ginvite <name>" in its own copy box (never a chat frame) and four key caps, Ctrl+C › Enter › Ctrl+V › Enter,
-- that light only on their own events:
--   1 Ctrl+C: the copy box's OnKeyDown with C while Ctrl is down;
--   2 Enter:  the copy box's OnEnterPressed: it lets go of the focus. The window stays, and nothing opens or fills the
--             chat input (V135: a chat input touched by addon code makes /ginvite forbidden). The player's own Enter
--             then opens chat; that key has no cap of its own;
--   3 Ctrl+V: a chat input's text becomes the command (a post-hook, PASTE_HOOK, V137);
--   4 Enter:  the game's "You have invited <name>" (the service calls sent()).
-- The copy box takes the focus only when that can't eat a keypress (core/GuildInvite.focusDecision); else it arrives
-- unfocused with a mouse cap first and "Click here, then Ctrl+C" in the box, and one click on the box or the window
-- focuses it. Until then it checks again every 0.3 s and takes the focus once the player has been free (standing
-- still, out of combat, not typing) for two checks in a row (CF-93). /cf sync debug prints the decisions as [guild]
-- lines. Nothing here is secure: no combat handling needed.
local _, ns = ...

local GuildInvitePopup = {}
local Kit = ns.Kit
local Theme = ns.Theme

-- The strings of GI01Window, verbatim.
GuildInvitePopup.TITLE = "Guild invite"
GuildInvitePopup.KEYS_TOOLTIP = "Copy · open chat · paste · send"
GuildInvitePopup.CTRL, GuildInvitePopup.C, GuildInvitePopup.V, GuildInvitePopup.ENTER = "Ctrl", "C", "V", "Enter"
-- CF-93: in the box while it isn't focused and nothing is copied yet.
GuildInvitePopup.HINT = "Click here, then Ctrl+C"

-- CF-88: the Ctrl+V step's chat input hook (V137). Off: that cap stays unlit and step 4 still lands.
local PASTE_HOOK = true

local TOP_OFFSET = -262       -- GI02Screen: under the red error lines and the run reminder, above the action bars
local TITLE_HEIGHT, PAD, GAP, BOX_HEIGHT, CAP_HEIGHT = 30, 12, 10, 32, 22
local CHECK_AT, FADE_FROM, FADE_TO = 0.15, 0.9, 1.2 -- seconds after "sent"
local FLASH_SECONDS = 0.4                            -- the gold edge when a request replaces another
local RETRY_SECONDS, RETRY_CALM = 0.3, 2             -- CF-93: focus again after 2 free checks in a row
local MOUSE_ATLAS = "newplayertutorial-icon-mouse-leftbutton" -- unverified (V136); a cursor texture without it
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
-- Keys the focused box lets through; any other one releases the focus (that key is lost once). Shift and Alt alone
-- don't (CF-93: a stray modifier must not cost the focus before Ctrl+C).
local ALLOWED_KEYS = { LCTRL = true, RCTRL = true, CTRL = true, C = true, ENTER = true, ESCAPE = true,
                       LSHIFT = true, RSHIFT = true, SHIFT = true, LALT = true, RALT = true, ALT = true }

local popup

-- ===== Key caps =====

local CAP_LOOK = {
  upcoming = { edge = "capEdge", fill = "capFill", text = "capText", plus = "keySep" },
  next = { edge = "gold", fill = "capFill", text = "heading", plus = "capDoneEdge" },
  done = { edge = "capDoneEdge", fill = "capDoneFill", text = "goldPale", plus = "capDoneEdge" },
}

-- One cap: 22 px tall, 1 px edges and a 3 px bottom edge. label: text, or nil for the mouse icon.
local function cap(parent, label)
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(CAP_HEIGHT)
  c.fill = c:CreateTexture(nil, "BACKGROUND")
  c.fill:SetAllPoints()
  c.edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = c:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT")
      t:SetPoint(side .. "RIGHT")
      t:SetHeight(side == "BOTTOM" and 3 or 1)
    else
      t:SetPoint("TOP" .. side)
      t:SetPoint("BOTTOM" .. side)
      t:SetWidth(1)
    end
    c.edges[#c.edges + 1] = t
  end
  if label then
    c.label = Theme.text(c, "chip", "capText")
    c.label:SetPoint("CENTER", 0, 1)
    c.label:SetText(label)
    local width = c.label.GetStringWidth and c.label:GetStringWidth() or 0
    c:SetWidth(math.max(24, width + 12))
  else
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(12, 14)
    c.icon:SetPoint("CENTER", 0, 1)
    if not (c.icon.SetAtlas and c.icon:SetAtlas(MOUSE_ATLAS)) then c.icon:SetTexture("Interface\\CURSOR\\Point") end
    c:SetWidth(24)
  end
  return c
end

local function paintCap(c, state)
  local look = CAP_LOOK[state] or CAP_LOOK.upcoming
  c.fill:SetColorTexture(Theme.color(look.fill))
  for _, t in ipairs(c.edges) do t:SetColorTexture(Theme.color(look.edge)) end
  if c.label then c.label:SetTextColor(Theme.color(look.text)) end
  c.state = state
end

-- A group of caps joined by "+": { frame, caps, pluses }.
local function group(parent, labels)
  local g = { caps = {}, pluses = {} }
  g.frame = CreateFrame("Frame", nil, parent)
  g.frame:SetHeight(CAP_HEIGHT)
  local width, previous = 0, nil
  for i, label in ipairs(labels) do
    if i > 1 then
      local plus = Theme.text(g.frame, "tiny", "keySep")
      plus:SetText("+")
      plus:SetPoint("LEFT", previous, "RIGHT", 3, 0)
      g.pluses[#g.pluses + 1] = plus
      width = width + 3 + 7 + 3
      previous = plus
    end
    local c = cap(g.frame, label)
    if previous then c:SetPoint("LEFT", previous, "RIGHT", 3, 0) else c:SetPoint("LEFT") end
    width = width + c:GetWidth()
    g.caps[#g.caps + 1] = c
    previous = c
  end
  g.frame:SetWidth(width)
  return g
end

local function paintGroup(g, state)
  for _, c in ipairs(g.caps) do paintCap(c, state) end
  local look = CAP_LOOK[state] or CAP_LOOK.upcoming
  for _, plus in ipairs(g.pluses) do plus:SetTextColor(Theme.color(look.plus)) end
  g.state = state
end

-- The row: [mouse] › [Ctrl]+[C] › [Enter] › [Ctrl]+[V] › [Enter], the mouse cap only for an unfocused start.
local function layoutKeys()
  local previous
  local items = {}
  if popup.needsClick then items[#items + 1] = popup.mouse end
  for _, g in ipairs(popup.steps) do items[#items + 1] = g end
  popup.mouse.frame:SetShown(popup.needsClick)
  for _, sep in ipairs(popup.seps) do sep:Hide() end
  local sepIndex = 0
  for i, item in ipairs(items) do
    item.frame:ClearAllPoints()
    if i == 1 then
      item.frame:SetPoint("LEFT")
    else
      sepIndex = sepIndex + 1
      local sep = popup.seps[sepIndex]
      sep:ClearAllPoints()
      sep:SetPoint("LEFT", previous.frame, "RIGHT", 6, 0)
      sep:Show()
      item.frame:SetPoint("LEFT", sep, "RIGHT", 6, 0)
    end
    previous = item
  end
end

local function paintKeys()
  local states = ns.GuildInvite.capStates(popup.progress)
  if popup.needsClick then
    paintGroup(popup.mouse, popup.clicked and "done" or "next")
    if not popup.clicked and popup.progress == 0 then states[1] = "upcoming" end
  end
  for i, g in ipairs(popup.steps) do paintGroup(g, states[i]) end
end

-- ===== The copy box =====

-- CF-93: a [guild] debug line (/cf sync debug).
local function trace(text)
  if ns.GuildInvites and ns.GuildInvites.trace then ns.GuildInvites.trace(text) end
end

-- May the box take the focus now? when ("arrival", "retry"): also print the decision and why.
local function decide(when)
  local ctx = ns.Guild.focusContext(popup.box)
  local ok = ns.GuildInvite.focusDecision(ctx)
  if when then trace(ns.GuildInvite.focusText(ctx, when)) end
  return ok
end

local function hintWidth()
  local width = popup.hint.GetStringWidth and popup.hint:GetStringWidth() or 0
  return (width and width > 0) and width or 140
end

local function paintBox()
  local box = popup.box
  local focused = box:HasFocus()
  for _, t in ipairs(box.edges) do t:SetColorTexture(Theme.color(focused and "capDoneEdge" or "capEdge")) end
  box:SetTextColor(Theme.color((popup.needsClick and not popup.clicked) and "muted" or "heading"))
  -- CF-93: "Click here, then Ctrl+C" while unfocused and nothing copied yet; the command keeps clear of it.
  local hint = not focused and (popup.progress or 0) == 0 and not popup.fading
  popup.hint:SetShown(hint)
  box:SetTextInsets(8, hint and (hintWidth() + 16) or 8, 0, 0)
end

local function focusBox()
  local box = popup.box
  box:SetText(popup.command or "")
  box:SetFocus()
  box:HighlightText()
  paintBox()
end

-- A click on the box or the window body always focuses and selects. Taking the focus moves it off a chat input
-- without touching that input (V135).
local function clickFocus()
  if not (popup and popup:IsShown()) or popup.fading then return end
  if not popup.box:HasFocus() then trace("invite window focus on click: yes") end
  popup.clicked = true
  focusBox()
  paintKeys()
end

-- A step's event: light it (and the ones before it).
local function step(n)
  if not (popup and popup:IsShown()) or popup.fading then return end
  popup.progress = ns.GuildInvite.advance(popup.progress, n)
  paintKeys()
end

local function onPaste(text)
  if popup and ns.GuildInvite.isPasted(text, popup.command) then step(ns.GuildInvite.STEP_PASTE) end
end

-- ===== The window =====

local function stopFade()
  popup.fading, popup.fadeAt = false, nil
  popup:SetScript("OnUpdate", nil)
  popup:SetAlpha(1)
  popup.veil:Hide()
  popup.check:Hide()
  if popup.checkTimer then popup.checkTimer:Cancel() end
  popup.checkTimer = nil
end

local function close() popup:Hide() end

-- ===== CF-93: focus again once the player is free =====

local function stopRetry()
  if popup.retryTimer then popup.retryTimer:Cancel() end
  popup.retryTimer, popup.calm = nil, 0
end

-- Unfocused since arrival, never clicked, nothing copied: a focus the player let go of is never taken back.
local function waiting()
  return popup:IsShown() and not popup.fading and popup.needsClick and not popup.clicked
    and (popup.progress or 0) == 0 and not popup.box:HasFocus()
end

local function retry()
  popup.retryTimer = nil
  if not waiting() then return end
  popup.calm = decide() and (popup.calm or 0) + 1 or 0
  if popup.calm >= RETRY_CALM then
    decide("retry")
    popup.needsClick, popup.calm = false, 0
    layoutKeys()
    focusBox()
    paintKeys()
    return
  end
  popup.retryTimer = C_Timer.NewTimer(RETRY_SECONDS, retry)
end

local function startRetry()
  stopRetry()
  if waiting() then popup.retryTimer = C_Timer.NewTimer(RETRY_SECONDS, retry) end
end

local function build()
  popup = CreateFrame("Frame", nil, UIParent)
  popup:SetFrameStrata("DIALOG")
  popup:SetToplevel(true)
  popup:SetClampedToScreen(true)
  popup:EnableMouse(true)
  popup:SetScript("OnMouseDown", clickFocus) -- CF-93: a click anywhere on the body focuses the box
  popup:SetPoint("TOP", UIParent, "TOP", 0, TOP_OFFSET)
  popup:Hide()
  local bg = Theme.fill(popup, "panel", "BACKGROUND")
  bg:SetAllPoints()
  popup.border = Kit.edges(popup, "goalEdge", "BORDER")
  popup.flash = Kit.edges(popup, "goldLight", "OVERLAY")
  for _, t in ipairs(popup.flash) do t:Hide() end

  -- Title bar: shield, "Guild invite", X.
  local bar = CreateFrame("Frame", nil, popup)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(TITLE_HEIGHT - 1)
  local glow = bar:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints()
  glow:SetColorTexture(Theme.color("giTitleBottom"))
  if glow.SetGradient and CreateColor then -- unverified, V61
    glow:SetColorTexture(1, 1, 1, 1)
    glow:SetGradient("VERTICAL", CreateColor(Theme.color("giTitleBottom")), CreateColor(Theme.color("giTitleTop")))
  end
  local line = Theme.fill(bar, "giLine", "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  local shield = bar:CreateTexture(nil, "ARTWORK")
  shield:SetSize(16, 16)
  shield:SetPoint("LEFT", 10, 0)
  shield:SetTexture(Theme.TEXTURES.shield)
  popup.title = Theme.text(bar, "section", "goldLight")
  popup.title:SetPoint("LEFT", shield, "RIGHT", 8, 0)
  popup.title:SetText(GuildInvitePopup.TITLE)
  popup.closeButton = Kit.iconButton(bar, "close", close)
  popup.closeButton:SetSize(22, 22)
  popup.closeButton:SetPoint("RIGHT", -6, 0)

  -- "Invite <Name> (<Owner>'s alt)?", at most two lines.
  popup.who = Theme.text(popup, "body", "text")
  popup.who:SetPoint("TOPLEFT", PAD, -(TITLE_HEIGHT + PAD))
  popup.who:SetJustifyH("LEFT")
  if popup.who.SetMaxLines then popup.who:SetMaxLines(2) end

  -- The copy box: read-only in effect, its own (never a chat frame).
  local box = CreateFrame("EditBox", nil, popup)
  box:SetHeight(BOX_HEIGHT)
  box:SetAutoFocus(false)
  box:SetTextInsets(8, 8, 0, 0)
  Theme.font(box, "body")
  local fill = Theme.fill(box, "giCopy", "BACKGROUND")
  fill:SetAllPoints()
  box.edges = Kit.edges(box, "capEdge", "BORDER")
  box:SetPoint("TOPLEFT", popup.who, "BOTTOMLEFT", 0, -GAP)
  box:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
  box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
    paintBox()
  end)
  box:SetScript("OnEditFocusLost", function() paintBox() end)
  box:SetScript("OnMouseDown", clickFocus)
  -- The click's own cursor placement can drop the selection: select again when the button comes up.
  box:SetScript("OnMouseUp", function(self) if self:HasFocus() then self:HighlightText() end end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= popup.command then
      self:SetText(popup.command or "")
      self:HighlightText()
    end
  end)
  box:SetScript("OnKeyDown", function(self, key)
    if key == "C" and ns.Guild.controlDown() then
      step(ns.GuildInvite.STEP_COPY)
    elseif not ALLOWED_KEYS[key] then
      trace("invite window: " .. tostring(key) .. " let go of the focus")
      self:ClearFocus()
    end
  end)
  box:SetScript("OnEnterPressed", function(self)
    step(ns.GuildInvite.STEP_CLOSE)
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", close)
  popup.box = box
  popup.hint = Theme.text(box, "small", "goldLight")
  popup.hint:SetPoint("RIGHT", box, "RIGHT", -8, 0)
  popup.hint:SetText(GuildInvitePopup.HINT)
  popup.hint:Hide()
  -- Measures the command's width (the window grows with it).
  popup.measure = popup:CreateFontString(nil, "OVERLAY")
  Theme.font(popup.measure, "body")
  popup.measure:Hide()

  -- The key caps, with the tooltip on the row.
  local row = CreateFrame("Frame", nil, popup)
  row:SetHeight(CAP_HEIGHT)
  row:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -GAP)
  row:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
  row:EnableMouse(true)
  row:SetScript("OnMouseDown", clickFocus)
  row:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(GuildInvitePopup.KEYS_TOOLTIP, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  local P = GuildInvitePopup
  popup.mouse = group(row, { false })
  popup.steps = { group(row, { P.CTRL, P.C }), group(row, { P.ENTER }), group(row, { P.CTRL, P.V }),
                  group(row, { P.ENTER }) }
  popup.seps = {}
  for i = 1, 4 do
    local sep = Theme.text(row, "small", "keySep")
    sep:SetText("›")
    popup.seps[i] = sep
  end
  popup.row = row

  -- "Sent": a veil over the body and a green check.
  popup.veil = Theme.fill(popup, "giVeil", "OVERLAY")
  popup.veil:SetPoint("TOPLEFT", 1, -TITLE_HEIGHT)
  popup.veil:SetPoint("BOTTOMRIGHT", -1, 1)
  popup.veil:Hide()
  popup.check = popup:CreateTexture(nil, "OVERLAY", nil, 2)
  popup.check:SetSize(44, 44)
  popup.check:SetPoint("CENTER", popup.veil, "CENTER")
  popup.check:SetTexture(CHECK_TEXTURE)
  popup.check:Hide()

  popup:SetScript("OnHide", function()
    stopRetry()
    popup.box:ClearFocus()
    stopFade()
    local onClose = popup.onClose
    popup.onClose = nil
    if onClose then onClose() end
  end)
  if PASTE_HOOK then ns.Guild.watchChatInput(onPaste) end
end

-- Size: 400 px wide, growing with the command up to 520; height from the name line (one or two lines).
local function layout()
  popup.measure:SetText(popup.command)
  local textWidth = popup.measure.GetStringWidth and popup.measure:GetStringWidth() or 0
  if popup.needsClick then textWidth = (textWidth or 0) + hintWidth() + 8 end -- CF-93: room for the hint
  local width = ns.GuildInvite.windowWidth(textWidth)
  popup.who:SetWidth(width - 2 * PAD)
  local whoHeight = popup.who.GetStringHeight and popup.who:GetStringHeight() or 0
  if not whoHeight or whoHeight <= 0 then whoHeight = 18 end
  popup:SetSize(width, TITLE_HEIGHT + PAD + whoHeight + GAP + BOX_HEIGHT + GAP + CAP_HEIGHT + PAD)
end

local function flash()
  for _, t in ipairs(popup.flash) do t:Show() end
  if popup.flashTimer then popup.flashTimer:Cancel() end
  popup.flashTimer = C_Timer.NewTimer(FLASH_SECONDS, function()
    popup.flashTimer = nil
    for _, t in ipairs(popup.flash) do t:Hide() end
  end)
end

--[[ Shows a request, or replaces the one shown in place (name and command change, the keys reset, a gold edge for
400 ms; no queue). opts = { target (the name exactly as the game reported it, V131), name (shown; default target),
friend (the owner's display name or nil), classFile (the name's colour, or nil: white), onClose() }. Returns false
(nothing shown) for a name that can't make a one-line command. ]]
function GuildInvitePopup.show(opts)
  local command = ns.GuildInvite.inviteCommand(opts and opts.target)
  if not command then return false end
  if not popup then build() end
  local replacing = popup:IsShown()
  if replacing then
    local onClose = popup.onClose
    popup.onClose = nil
    if onClose then onClose() end
    stopFade()
  end
  popup.target, popup.command, popup.onClose = opts.target, command, opts.onClose
  popup.progress, popup.clicked = 0, false
  local r, g, b = 1, 1, 1
  if opts.classFile then r, g, b = Kit.classColor(opts.classFile) end
  local name = Theme.rgbCode(r, g, b) .. tostring(opts.name or opts.target) .. "|r"
  popup.who:SetText(ns.GuildInvite.popupText(name, opts.friend))
  popup.box:SetText(command)
  popup.needsClick = not decide("arrival")
  layout()
  popup:Show()
  if not replacing then
    ns.Sounds.play("IG_MAINMENU_OPEN")
    if ns.Keys then ns.Keys.closeOnEscape(popup, close) end
  else
    flash()
  end
  if popup.needsClick then popup.box:ClearFocus() else focusBox() end
  layoutKeys()
  paintKeys()
  paintBox()
  startRetry()
  return true
end

-- The request on screen (its target name), or nil.
function GuildInvitePopup.current()
  if popup and popup:IsShown() and not popup.fading then return popup.target end
  return nil
end

-- The invite went out ("You have invited ..."): all keys lit, a check after 150 ms, faded out by 1.2 s.
function GuildInvitePopup.sent()
  if not (popup and popup:IsShown()) or popup.fading then return end
  popup.progress = ns.GuildInvite.STEPS
  paintKeys()
  stopRetry()
  popup.box:ClearFocus()
  popup.fading, popup.fadeAt = true, 0
  paintBox()
  popup.checkTimer = C_Timer.NewTimer(CHECK_AT, function()
    popup.checkTimer = nil
    popup.veil:Show()
    popup.check:Show()
  end)
  popup:SetScript("OnUpdate", function(self, elapsed)
    self.fadeAt = (self.fadeAt or 0) + (elapsed or 0)
    if self.fadeAt >= FADE_TO then
      self:Hide()
    elseif self.fadeAt > FADE_FROM then
      self:SetAlpha(1 - (self.fadeAt - FADE_FROM) / (FADE_TO - FADE_FROM))
    end
  end)
end

-- The invite was refused: the window goes at once, no fade.
function GuildInvitePopup.refused()
  if popup and popup:IsShown() then popup:Hide() end
end

-- One chat line in the addon's look (GI01/GI03): the shield and the text in gold.
function GuildInvitePopup.chatLine(text)
  return "|T" .. Theme.TEXTURES.shield .. ":13:13|t " .. Theme.code("goldLight") .. tostring(text) .. "|r"
end

-- For the specs: the window (nil until shown once), and a step's event.
function GuildInvitePopup.frame() return popup end
GuildInvitePopup.step = step

ns.GuildInvitePopup = GuildInvitePopup
return GuildInvitePopup
