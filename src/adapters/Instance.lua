-- Instance: dungeon, raid and battleground info and events (CF-23). Thin, guarded wrappers.
-- The events are verified to register on Forever (V35); what they pass inside instances is not yet
-- (VERIFY.md V35), so every call is guarded and every value checked by the caller.
local _, ns = ...

local Instance = {}

-- Internal message: Instance.EVENT, event, ... (the WoW event name and its arguments).
Instance.EVENT = "CF_INSTANCE_EVENT"

Instance.EVENTS = {
  "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
  "ENCOUNTER_END", "BOSS_KILL", "GROUP_ROSTER_UPDATE",
  "PVP_MATCH_COMPLETE", "UPDATE_BATTLEFIELD_STATUS",
}

-- A value that is readable: Midnight can hand addons secret values (issecretvalue exists, V37).
local function readable(value)
  if value == nil then return false end
  if issecretvalue and issecretvalue(value) then return false end
  return true
end

-- { name, type, instanceID } of where the player is. GetInstanceInfo verified outside instances only
-- (type "none"); inside "party", "raid" or "pvp" is expected (V35).
function Instance.info()
  if not GetInstanceInfo then return nil end
  local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
  if not readable(name) or not readable(instanceType) then return nil end
  return { name = name, type = instanceType, instanceID = readable(instanceID) and instanceID or nil }
end

-- CF-46: true while Midnight's addon message restrictions may apply: an encounter in progress, a Mythic+
-- keystone or a PvP match. C_ChatInfo.InChatMessagingLockdown and IsEncounterInProgress are unverified on
-- Forever (VERIFY.md V70): without them only battlegrounds and arenas count (GetInstanceInfo, verified).
function Instance.messagingRestricted()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and locked == true then return true end
  end
  if IsEncounterInProgress then
    local ok, busy = pcall(IsEncounterInProgress)
    if ok and busy == true then return true end
  end
  local info = Instance.info()
  return info ~= nil and (info.type == "pvp" or info.type == "arena")
end

-- GUIDs of the other group members (party1-4 or raid1-40). IsInRaid, GetNumGroupMembers and UnitGUID
-- on group units are unverified on Forever (V35); secret GUIDs are skipped.
function Instance.groupGuids()
  local guids = {}
  if not (UnitGUID and GetNumGroupMembers) then return guids end
  local count = GetNumGroupMembers() or 0
  local raid = IsInRaid and IsInRaid()
  local units = raid and count or math.min(count, 5) - 1
  for i = 1, units do
    local guid = UnitGUID((raid and "raid" or "party") .. i)
    if readable(guid) and type(guid) == "string" then guids[#guids + 1] = guid end
  end
  return guids
end

-- Winner team index of the current battleground once it ended, else nil (unverified, V35).
function Instance.winner()
  if not GetBattlefieldWinner then return nil end
  local winner = GetBattlefieldWinner()
  return readable(winner) and winner or nil
end

-- The player's team index in a battleground (unverified, V35); nil when unknown.
function Instance.team()
  if not GetBattlefieldArenaFaction then return nil end
  local team = GetBattlefieldArenaFaction()
  return readable(team) and team or nil
end

-- Forwards the instance events as Instance.EVENT messages (own AceEvent object: AceEvent keeps one
-- handler per object and event, and SelfInfo already handles PLAYER_ENTERING_WORLD on the addon).
function Instance.watch(addon)
  local events = LibStub("AceEvent-3.0"):Embed({})
  for _, event in ipairs(Instance.EVENTS) do
    ns.Events.register(events, event, function(_, ...)
      addon:SendMessage(Instance.EVENT, event, ...)
    end)
  end
end

ns.Instance = Instance
return Instance
