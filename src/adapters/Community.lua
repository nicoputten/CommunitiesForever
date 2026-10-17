-- Community: C_Club wrapper (club list, members, club and member events).
local _, ns = ...

local Community = {}

-- Internal message: (event, clubId). Sent when the subscribed club list may have changed.
Community.CLUBS_CHANGED = "CF_CLUBS_CHANGED"

-- Internal message: (event, clubId). Sent when a club's member list or member data may have changed.
Community.MEMBERS_CHANGED = "CF_CLUB_MEMBERS_CHANGED"

local CLUB_EVENTS = { "INITIAL_CLUBS_LOADED", "CLUB_ADDED", "CLUB_REMOVED", "CLUB_UPDATED" }

-- VERIFY.md V17. CLUB_REMOVED is also a member change: the whole club is gone.
local MEMBER_EVENTS = {
  "CLUB_MEMBERS_UPDATED", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED",
  "CLUB_MEMBER_PRESENCE_UPDATED", "CLUB_MEMBER_UPDATED", "CLUB_REMOVED",
}

-- Enum.ClubType.Character; 1 is the value seen on Forever (API-FINDINGS.md).
function Community.characterType()
  if Enum and Enum.ClubType and Enum.ClubType.Character then
    return Enum.ClubType.Character
  end
  return 1
end

-- Subscribed clubs as { clubId, name, clubType }; empty if the API is missing.
function Community.subscribedClubs()
  local list = {}
  if not (C_Club and C_Club.GetSubscribedClubs) then
    return list
  end
  for _, info in ipairs(C_Club.GetSubscribedClubs() or {}) do
    list[#list + 1] = { clubId = info.clubId, name = info.name, clubType = info.clubType }
  end
  return list
end

-- Joins a community with an invite code (CF-21). C_Club.RedeemTicket is unverified for addons
-- (VERIFY.md V25/V26). Returns false when the function does not exist.
function Community.redeemTicket(code)
  if not (C_Club and C_Club.RedeemTicket) then return false end
  C_Club.RedeemTicket(code)
  return true
end

-- Asks the client to load member data; it arrives async via CLUB_MEMBERS_UPDATED.
function Community.focusMembers(clubId)
  if C_Club and C_Club.FocusMembers then
    C_Club.FocusMembers(clubId)
  end
end

-- Raw member infos of a club (fields as returned by C_Club.GetMemberInfo).
function Community.members(clubId)
  local list = {}
  if not (C_Club and C_Club.GetClubMembers and C_Club.GetMemberInfo) then
    return list
  end
  for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
    local info = C_Club.GetMemberInfo(clubId, memberId)
    if info then
      list[#list + 1] = info
    end
  end
  return list
end

-- One AceEvent handler per event, so club and member messages are both sent for CLUB_REMOVED.
function Community.watch(addon)
  local messagesByEvent = {}
  for _, event in ipairs(CLUB_EVENTS) do
    messagesByEvent[event] = { Community.CLUBS_CHANGED }
  end
  for _, event in ipairs(MEMBER_EVENTS) do
    messagesByEvent[event] = messagesByEvent[event] or {}
    table.insert(messagesByEvent[event], Community.MEMBERS_CHANGED)
  end

  for event, messages in pairs(messagesByEvent) do
    ns.Events.register(addon, event, function(_, clubId)
      for _, message in ipairs(messages) do
        addon:SendMessage(message, event, clubId)
      end
    end)
  end
end

ns.Community = Community
return Community
