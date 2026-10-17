-- Community: C_Club wrapper. CF-05 covers the club list; members follow in CF-06.
local _, ns = ...

local Community = {}

-- Internal message: (event, clubId). Sent when the subscribed club list may have changed.
Community.CLUBS_CHANGED = "CF_CLUBS_CHANGED"

local CLUB_EVENTS = { "INITIAL_CLUBS_LOADED", "CLUB_ADDED", "CLUB_REMOVED", "CLUB_UPDATED" } -- VERIFY.md V15

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

function Community.watch(addon)
  for _, event in ipairs(CLUB_EVENTS) do
    ns.Events.register(addon, event, function(_, clubId)
      addon:SendMessage(Community.CLUBS_CHANGED, event, clubId)
    end)
  end
end

ns.Community = Community
return Community
