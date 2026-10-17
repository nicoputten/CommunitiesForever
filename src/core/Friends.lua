-- Friends: Battle.net presence snapshot, change detection and presence links.
-- Pure Lua, no WoW globals.
local _, ns = ...

local Friends = {}

-- Builds a snapshot from raw friend accounts:
--   accounts = { { battleTag, gameAccounts = { { clientProgram, wowProjectID, isOnline,
--                  gameAccountID, playerGuid, characterName, className, characterLevel, ... } } } }
-- Only online game accounts with clientProgram == wowClient and wowProjectID == projectID count.
-- Returns {
--   friends      = { [battleTag] = true },                  -- every current BNet friend
--   gameAccounts = { [gameAccountID] = battleTag },         -- Forever game accounts online now
--   characters   = { [guid] = battleTag },                  -- every Forever character online now
--   online       = { [battleTag] = char },                  -- current character per friend
-- }, char = { guid, name, className, level, gameAccountID }.
-- A friend with several Forever game accounts online: the lowest gameAccountID is current.
function Friends.snapshot(accounts, wowClient, projectID)
  local snap = { friends = {}, gameAccounts = {}, characters = {}, online = {} }
  for _, account in ipairs(accounts or {}) do
    local bt = account.battleTag
    if bt then
      snap.friends[bt] = true
      for _, ga in ipairs(account.gameAccounts or {}) do
        if ga.isOnline and ga.clientProgram == wowClient and ga.wowProjectID == projectID
            and ga.gameAccountID and ga.playerGuid then
          snap.gameAccounts[ga.gameAccountID] = bt
          snap.characters[ga.playerGuid] = bt
          local current = snap.online[bt]
          if not current or ga.gameAccountID < current.gameAccountID then
            snap.online[bt] = {
              guid = ga.playerGuid,
              name = ga.characterName,
              className = ga.className,
              level = ga.characterLevel,
              gameAccountID = ga.gameAccountID,
            }
          end
        end
      end
    end
  end
  return snap
end

-- Changes between two snapshots, sorted by battleTag:
--   { kind = "online",   battleTag, guid }
--   { kind = "switched", battleTag, guid, previousGuid }
--   { kind = "offline",  battleTag, previousGuid }
-- With previous == nil (first snapshot after login) there are no changes: that is the baseline.
function Friends.changes(previous, current)
  local result = {}
  if not previous then
    return result
  end

  local tags = {}
  for bt in pairs(previous.online) do tags[bt] = true end
  for bt in pairs(current.online) do tags[bt] = true end
  local sorted = {}
  for bt in pairs(tags) do sorted[#sorted + 1] = bt end
  table.sort(sorted)

  for _, bt in ipairs(sorted) do
    local before, now = previous.online[bt], current.online[bt]
    if not before and now then
      result[#result + 1] = { kind = "online", battleTag = bt, guid = now.guid }
    elseif before and not now then
      result[#result + 1] = { kind = "offline", battleTag = bt, previousGuid = before.guid }
    elseif before.guid ~= now.guid then
      result[#result + 1] = { kind = "switched", battleTag = bt, guid = now.guid, previousGuid = before.guid }
    end
  end
  return result
end

-- Writes presence[guid] = { battleTag, lastSeen } for every Forever character online in the snapshot.
-- A GUID seen under a different BattleTag is reassigned (latest observation wins).
function Friends.recordPresence(presence, snap, now)
  for guid, bt in pairs(snap.characters) do
    presence[guid] = { battleTag = bt, lastSeen = now }
  end
end

ns.Friends = Friends
return Friends
