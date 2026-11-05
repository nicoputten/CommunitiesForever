-- GuildInvitePopup: "Invite Bram Lovewell (Ada's alt)?" on a member's client when an alt asks for a guild invite
-- (CF-84, CF-87). Addons may not invite into a guild, not even inside a click (ADDON_ACTION_FORBIDDEN, V126), so the
-- invite runs as the game's own /ginvite command:
--   secure: the Invite button is a SecureActionButtonTemplate macro button with "/ginvite <name>" (V134);
--   chat:   "Put in chat" opens the chat input with "/ginvite <name>", the member presses Enter (V135).
-- GuildInvitePopup.METHODS picks which of the two show. Secure attributes can only be set out of combat: in combat
-- the Invite button is taken off the popup (before the lockdown starts, so the popup stays free to show and hide)
-- and comes back when combat ends. One popup at a time: a newer request replaces the line.
local _, ns = ...

local GuildInvitePopup = {}
local Kit = ns.Kit
local Theme = ns.Theme

GuildInvitePopup.TITLE = "Guild invite"
GuildInvitePopup.BUTTON = "Invite"
GuildInvitePopup.CHAT_BUTTON = "Put in chat"
GuildInvitePopup.CHAT_TOOLTIP = "Puts /ginvite with the name in the chat input. Press Enter to send the invite."
GuildInvitePopup.COMBAT = "You're in combat: the Invite button comes back when combat ends."

-- CF-87: which ways to invite the popup offers (switch one off here; the other keeps working on its own).
GuildInvitePopup.METHODS = { secure = true, chat = true }

local popup

local function command()
  return popup and ns.GuildInvite.inviteCommand(popup.target)
end

local function invited(how)
  return function()
    local onInvite = popup.onInvite
    popup:Hide()
    if onInvite then onInvite(how) end
  end
end

-- The secure Invite button off the popup: hidden and parented away, so the popup itself never counts as protected.
-- Only out of combat (no-op in it).
local function detachSecure()
  local b = popup and popup.invite
  if not b or ns.Guild.inCombat() then return end
  b:Hide()
  b:ClearAllPoints()
  b:SetParent(UIParent)
  b.attached = false
end

-- The secure Invite button on the popup with the current name, out of combat; in combat the line says why it's gone.
local function attachSecure()
  popup.note:SetText("")
  if not GuildInvitePopup.METHODS.secure then return end
  local text = command()
  if ns.Guild.inCombat() then
    popup.note:SetText(GuildInvitePopup.COMBAT)
    return
  end
  if not text then
    detachSecure()
    return
  end
  local b = popup.invite
  if not b then
    b = Kit.button(popup.content, GuildInvitePopup.BUTTON, invited("secure"), "primary", "SecureActionButtonTemplate")
    -- Down and up: the secure handler acts on the one the ActionButtonUseKeyDown setting names.
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    popup.invite = b
  end
  b:SetParent(popup.content)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMRIGHT", -20, 14)
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", text)
  b.attached = true
  b:Show()
end

local function build()
  popup = Kit.dialog({ title = GuildInvitePopup.TITLE, width = 360, height = 150 })
  popup.line = Theme.text(popup.content, "body", "text")
  popup.line:SetPoint("TOPLEFT", 20, -18)
  popup.line:SetPoint("TOPRIGHT", -20, -18)
  popup.line:SetJustifyH("LEFT")
  popup.note = Theme.text(popup.content, "small", "textDim")
  popup.note:SetPoint("TOPLEFT", popup.line, "BOTTOMLEFT", 0, -8)
  popup.note:SetPoint("TOPRIGHT", popup.line, "BOTTOMRIGHT", 0, -8)
  popup.note:SetJustifyH("LEFT")
  local chatClicked = invited("chat")
  popup.chat = Kit.button(popup.content, GuildInvitePopup.CHAT_BUTTON, function()
    local text = command()
    if text then ns.Guild.putInChat(text) end
    chatClicked()
  end, "normal")
  popup.chat.tooltip = GuildInvitePopup.CHAT_TOOLTIP
  popup.chat:SetPoint("BOTTOMLEFT", 20, 14)
end

-- target: the name to invite exactly as the game reported it (V131); friend: whose alt (or nil); name: how to show
-- it (default target); onInvite(how): after a click on Invite ("secure") or Put in chat ("chat").
function GuildInvitePopup.show(target, friend, name, onInvite)
  if not popup then build() end
  popup.target, popup.onInvite = target, onInvite
  popup.line:SetText(ns.GuildInvite.popupText(name or target, friend))
  popup.chat:SetShown(GuildInvitePopup.METHODS.chat and command() ~= nil)
  popup:Show()
  attachSecure()
end

-- PLAYER_REGEN_DISABLED (before the lockdown): take the secure button off while that is still allowed.
function GuildInvitePopup.combatStarted()
  if not (popup and popup.invite and popup.invite.attached) then return end
  detachSecure()
  if popup:IsShown() and GuildInvitePopup.METHODS.secure then popup.note:SetText(GuildInvitePopup.COMBAT) end
end

-- PLAYER_REGEN_ENABLED: the button comes back on a popup still open.
function GuildInvitePopup.combatEnded()
  if popup and popup:IsShown() then attachSecure() end
end

-- For the specs: the popup frame (nil until shown once).
function GuildInvitePopup.frame() return popup end

ns.GuildInvitePopup = GuildInvitePopup
return GuildInvitePopup
