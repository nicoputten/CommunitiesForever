-- Presence: C_BattleNet friend accounts and BNet events. Returns raw data only.
local _, ns = ...

local Presence = {}

-- Internal message: (event). Sent when friend presence may have changed.
Presence.CHANGED = "CF_PRESENCE_CHANGED"

local EVENTS = { -- VERIFY.md V19
  "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED",
}

-- BNET_CLIENT_WOW is unverified (VERIFY.md V19); "WoW" is the clientProgram seen on Forever.
function Presence.wowClient()
  return BNET_CLIENT_WOW or "WoW"
end

function Presence.projectID()
  return WOW_PROJECT_ID
end

-- All friends with all their game accounts:
-- { { battleTag, gameAccounts = { <C_BattleNet game account info> } } }
function Presence.friendAccounts()
  local accounts = {}
  local numFriends = BNGetNumFriends() or 0
  for i = 1, numFriends do
    local info = C_BattleNet.GetFriendAccountInfo(i)
    if info then
      local gameAccounts = {}
      for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
        local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if ga then
          gameAccounts[#gameAccounts + 1] = ga
        end
      end
      accounts[#accounts + 1] = { battleTag = info.battleTag, gameAccounts = gameAccounts }
    end
  end
  return accounts
end

function Presence.watch(addon)
  for _, event in ipairs(EVENTS) do
    ns.Events.register(addon, event, function()
      addon:SendMessage(Presence.CHANGED, event)
    end)
  end
end

ns.Presence = Presence
return Presence
