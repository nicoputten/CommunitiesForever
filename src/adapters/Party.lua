-- Party: getting a friend into your group from a click (CF-27). Thin, guarded wrappers; which of these
-- work on Forever is unverified (VERIFY.md V48). Called only from chat link clicks (hardware events).
local _, ns = ...

local Party = {}

-- Asks the player `name` (the asker) to invite you. Returns true when the call exists and ran.
function Party.requestInvite(name)
  if not (C_PartyInfo and C_PartyInfo.RequestInviteFromUnit and name) then return false end
  return pcall(C_PartyInfo.RequestInviteFromUnit, name) == true
end

-- Invites a friend: by character name, else through Battle.net. Returns "name", "bnet" or nil.
function Party.invite(name, gameAccountID)
  if C_PartyInfo and C_PartyInfo.InviteUnit and name and pcall(C_PartyInfo.InviteUnit, name) then
    return "name"
  end
  if BNInviteFriend and gameAccountID and pcall(BNInviteFriend, gameAccountID) then
    return "bnet"
  end
  return nil
end

ns.Party = Party
return Party
