-- Invites: the shared community invite link (CF-21).
-- Owners, leaders and moderators set it; it travels in their record; on a character that is not a
-- member, the window explains how to join and posts the newest invite as a clickable chat link.
local _, ns = ...

local Invites = {}

-- Internal message, sent when the link was posted or the instructions are done (window refresh).
Invites.CHANGED = "CF_INVITES_CHANGED"

local addonRef, linkPosted

local function global()
  return addonRef.db.global
end

local function setLinkPosted(value)
  linkPosted = value
  addonRef:SendMessage(Invites.CHANGED)
end

-- True when this character may set the link: a member of the selected community with role
-- Owner, Leader or Moderator (role from the verified C_Club member fields).
function Invites.canSet()
  if not ns.CommunitySelection.active() then return false end
  local me = ns.MemberTracker.members()[ns.SelfInfo.read().guid]
  return me ~= nil and ns.Invite.canManage(me.role)
end

-- Sets the link from a full invite link or a code; empty text clears it. Returns true, or false
-- and a message for the user.
function Invites.set(text)
  local own = global().self
  if text == nil or text:match("^%s*$") then
    if own.invite then
      own.invite = nil
      own.version = ns.Merge.nextVersion(own.version, GetServerTime())
      ns.Sync.ownRecordChanged()
    end
    return true
  end
  local code = ns.Invite.parseCode(text)
  if not code then
    return false, "That doesn't look like a community invite link or code."
  end
  own.invite = { clubId = ns.CommunitySelection.active(), code = code, setAt = GetServerTime() }
  own.version = ns.Merge.nextVersion(own.version, GetServerTime())
  ns.Sync.ownRecordChanged()
  return true
end

-- The link this account set for the selected community (for the settings field), or "".
function Invites.ownText()
  local invite = global().self.invite
  if invite and invite.clubId == ns.CommunitySelection.selected() then return invite.code end
  return ""
end

-- Newest known invite for the selected community: { code, setAt, setBy, setByName } or nil.
function Invites.current()
  local clubId = ns.CommunitySelection.selected()
  if not clubId then return nil end
  local own = global().self
  local sources = { { battleTag = own.battleTag, displayName = own.displayName or "you", invite = own.invite } }
  for bt, person in pairs(global().people) do
    sources[#sources + 1] = { battleTag = bt, displayName = ns.Linker.displayName(bt, person.displayName),
                              invite = person.invite }
  end
  return ns.Invite.newest(sources, clubId)
end

-- True after the invite link was posted in chat (this session, until the character joins).
function Invites.linkPosted()
  return linkPosted
end

-- Posts the newest invite as a clickable link in chat with a short hint. The player clicks it
-- there; Blizzard's own window does the joining (addons may not, V26).
function Invites.postLink()
  local invite = Invites.current()
  if not invite then return end
  local name = ns.CommunitySelection.name() or "the community"
  addonRef:Print("Click the link below to join " .. name .. ", then click Join in Blizzard's window:")
  addonRef:Print(ns.Community.ticketLink(invite.code, name))
  setLinkPosted(true)
end

function Invites.start(addon)
  addonRef = addon
  linkPosted = false
  local events = LibStub("AceEvent-3.0"):Embed({})
  -- Joined (or switched): the community is visible now, the instructions are done.
  events:RegisterMessage(ns.CommunitySelection.CHANGED, function()
    if ns.CommunitySelection.active() and linkPosted then
      setLinkPosted(false)
    end
  end)
end

ns.Invites = Invites
return Invites
