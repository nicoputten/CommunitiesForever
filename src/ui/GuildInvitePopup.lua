-- GuildInvitePopup: "Invite Bram Lovewell (Ada's alt)?" with one button (CF-84). Shown on a member's client when
-- the game wants a click for a guild invite: the button's click is the hardware event. One at a time: a newer
-- request replaces the line.
local _, ns = ...

local GuildInvitePopup = {}
local Theme, Kit = ns.Theme, ns.Kit

GuildInvitePopup.TITLE = "Guild invite"
GuildInvitePopup.BUTTON = "Invite"

local popup

local function build()
  popup = Kit.dialog({ title = GuildInvitePopup.TITLE, width = 360, height = 150 })
  popup.line = Theme.text(popup.content, "body", "text")
  popup.line:SetPoint("TOPLEFT", 20, -18)
  popup.line:SetPoint("TOPRIGHT", -20, -18)
  popup.line:SetJustifyH("LEFT")
  popup.button = Kit.button(popup.content, GuildInvitePopup.BUTTON, function()
    if popup.name then ns.Guild.invite(popup.name) end
    popup:Hide()
  end, "primary")
  popup.button:SetPoint("BOTTOMRIGHT", -20, 14)
end

-- target: the name to invite exactly as the game reported it (V131); name: how to show it (default target).
function GuildInvitePopup.show(target, friend, name)
  if not popup then build() end
  popup.name = target
  popup.line:SetText(ns.GuildInvite.popupText(name or target, friend))
  popup:Show()
end

-- For the specs: the popup frame (nil until shown once).
function GuildInvitePopup.frame() return popup end

ns.GuildInvitePopup = GuildInvitePopup
return GuildInvitePopup
