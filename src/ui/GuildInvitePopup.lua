-- GuildInvitePopup: "Invite Bram Lovewell (Ada's alt)?" on a member's client when an alt asks for a guild invite
-- (CF-84, CF-87). On Forever an addon cannot send a guild invite in any way: not the invite functions, not a secure
-- macro button ("Macro script disabled"), not /ginvite in a chat input the addon opened or filled (tainted, so
-- forbidden). Only a /ginvite the player types or pastes runs (API-FINDINGS.md "Guild invites"). So the popup is a
-- copy box: "/ginvite <name>" selected in our own edit box (never a chat frame); the member copies it and pastes it
-- into chat. Minimal look with the Kit; the designer's board comes later. One popup at a time: a newer request
-- replaces it.
local _, ns = ...

local GuildInvitePopup = {}
local Kit = ns.Kit
local Theme = ns.Theme

GuildInvitePopup.TITLE = "Guild invite"
GuildInvitePopup.HINT = "Ctrl+C, Enter. Then Enter, Ctrl+V, Enter."
GuildInvitePopup.TOOLTIP = "Addons can't send guild invites. Copy this line (Ctrl+C), close this window (Enter), "
  .. "then open chat (Enter), paste (Ctrl+V) and send it (Enter)."

local popup

-- The command, selected in the box with the keyboard focus, so Ctrl+C copies it at once.
local function selectCommand()
  local box = popup.box
  box:SetText(popup.command or "")
  box:SetFocus()
  box:HighlightText()
end

local function close()
  popup:Hide()
end

local function build()
  popup = Kit.dialog({ title = GuildInvitePopup.TITLE, width = 360, height = 170, onClose = function()
    if popup.box then popup.box:ClearFocus() end
    local onClose = popup.onClose
    popup.onClose = nil
    if onClose then onClose() end
  end })
  popup.line = Theme.text(popup.content, "body", "text")
  popup.line:SetPoint("TOPLEFT", 20, -18)
  popup.line:SetPoint("TOPRIGHT", -20, -18)
  popup.line:SetJustifyH("LEFT")
  -- Read-only in effect: typing restores the command, a click selects it all again.
  local box = Kit.input(popup.content, {})
  box:SetPoint("TOPLEFT", popup.line, "BOTTOMLEFT", 0, -10)
  box:SetPoint("TOPRIGHT", popup.line, "BOTTOMRIGHT", 0, -10)
  box:SetScript("OnEditFocusLost", nil)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= popup.command then selectCommand() end
  end)
  box:SetScript("OnEnterPressed", close)
  box:SetScript("OnEscapePressed", close)
  box:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(GuildInvitePopup.TOOLTIP, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  popup.box = box
  popup.hint = Theme.text(popup.content, "small", "textDim")
  popup.hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  popup.hint:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -8)
  popup.hint:SetJustifyH("LEFT")
  popup.hint:SetText(GuildInvitePopup.HINT)
end

-- target: the name to invite exactly as the game reported it (V131); friend: whose alt (or nil); name: how to show
-- it (default target); onClose(): when the window closes (Enter, Esc or X), or a newer request replaces it.
-- Returns false (nothing shown) for a name that can't make a one-line command.
function GuildInvitePopup.show(target, friend, name, onClose)
  local command = ns.GuildInvite.inviteCommand(target)
  if not command then return false end
  if not popup then build() end
  if popup:IsShown() then popup:Hide() end -- the older request's onClose runs
  popup.command, popup.onClose = command, onClose
  popup.line:SetText(ns.GuildInvite.popupText(name or target, friend))
  popup:Show()
  selectCommand()
  return true
end

-- For the specs: the popup frame (nil until shown once).
function GuildInvitePopup.frame() return popup end

ns.GuildInvitePopup = GuildInvitePopup
return GuildInvitePopup
