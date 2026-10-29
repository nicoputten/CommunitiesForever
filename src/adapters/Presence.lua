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

-- A game account by its ID (C_BattleNet.GetGameAccountInfoByID, unverified on Forever: VERIFY.md V87), or nil.
function Presence.gameAccountInfo(gameAccountID)
  if not (C_BattleNet and C_BattleNet.GetGameAccountInfoByID) then return nil end
  local ok, info = pcall(C_BattleNet.GetGameAccountInfoByID, gameAccountID)
  return ok and type(info) == "table" and info or nil
end

-- The BattleTag of the Battle.net account a character belongs to (C_BattleNet.GetAccountInfoByGUID, unverified:
-- V87), or nil.
function Presence.battleTagForGuid(guid)
  if not (guid and C_BattleNet and C_BattleNet.GetAccountInfoByGUID) then return nil end
  local ok, info = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
  local bt = ok and type(info) == "table" and info.battleTag
  return type(bt) == "string" and bt or nil
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
