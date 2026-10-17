-- Invites: the shared community invite link (CF-21).
-- Owners, leaders and moderators set it; it travels in their record; on a character that is not a
-- member, the window offers "Join <community>" with the newest invite for the selected community.
local _, ns = ...

local Invites = {}

-- Internal message, sent when the join state or the known invite changes (window refresh).
Invites.CHANGED = "CF_INVITES_CHANGED"

local JOIN_TIMEOUT = 10

local addonRef, joinState, joinTimer

local function global()
  return addonRef.db.global
end

local function setJoinState(value)
  joinState = value
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

-- nil, "joining" (waiting for the community to show up), "failed" or "unavailable".
function Invites.joinState()
  return joinState
end

function Invites.join()
  local invite = Invites.current()
  if not invite then return end
  if not ns.Community.redeemTicket(invite.code) then
    setJoinState("unavailable") -- C_Club.RedeemTicket does not exist on this client
    return
  end
  setJoinState("joining")
  if joinTimer then joinTimer:Cancel() end
  joinTimer = C_Timer.NewTimer(JOIN_TIMEOUT, function()
    joinTimer = nil
    if joinState == "joining" and not ns.CommunitySelection.active() then
      setJoinState("failed")
    end
  end)
end

function Invites.start(addon)
  addonRef = addon
  joinState, joinTimer = nil, nil
  local events = LibStub("AceEvent-3.0"):Embed({})
  -- Joined (or switched): the community is visible now, the join attempt is over.
  events:RegisterMessage(ns.CommunitySelection.CHANGED, function()
    if ns.CommunitySelection.active() and joinState then
      joinState = nil
      addonRef:SendMessage(Invites.CHANGED)
    end
  end)
end

ns.Invites = Invites
return Invites
