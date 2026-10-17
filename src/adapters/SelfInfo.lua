-- SelfInfo: reads the logged-in character from the WoW API and reports changes.
-- Thin wrapper: returns raw values, building and comparing is core/Snapshot.lua.
local _, ns = ...

local SelfInfo = {}

-- Internal message: (reason, ...event args). Reasons: "world", "level", "skills", "equipment".
SelfInfo.CHANGED = "CF_SELF_CHANGED"

local EVENT_REASONS = {
  PLAYER_ENTERING_WORLD = "world",
  PLAYER_LEVEL_UP = "level",                 -- arg 1 is the new level (VERIFY.md V12)
  SKILL_LINES_CHANGED = "skills",            -- VERIFY.md V12
  PLAYER_EQUIPMENT_CHANGED = "equipment",    -- VERIFY.md V12
}

-- prof1, prof2, archaeology, fishing, cooking, with nil holes (API-FINDINGS.md).
local PROFESSION_SLOTS = 5

local function readProfessions()
  local list = {}
  if not (GetProfessions and GetProfessionInfo) then
    return list
  end
  local slots = { GetProfessions() }
  for k = 1, PROFESSION_SLOTS do
    local index = slots[k]
    if index then
      local name, _, rank, max, _, _, skillLine = GetProfessionInfo(index)
      list[#list + 1] = { name = name, rank = rank, max = max, skillLine = skillLine }
    end
  end
  return list
end

-- Equipped average item level (2nd return), nil if the API is missing.
local function readItemLevel()
  if not GetAverageItemLevel then
    return nil
  end
  local _, equipped = GetAverageItemLevel()
  return equipped
end

-- UnitRace and UnitLevel/UnitFactionGroup are unverified on Forever (VERIFY.md V11).
function SelfInfo.read()
  local raceID
  if UnitRace then
    raceID = select(3, UnitRace("player"))
  end

  return {
    guid = UnitGUID("player"),
    name = UnitName("player"),
    classFile = UnitClassBase("player"),
    raceID = raceID,
    level = UnitLevel and UnitLevel("player") or nil,
    faction = UnitFactionGroup and (UnitFactionGroup("player")) or nil,
    realm = GetRealmName(),
    ilvl = readItemLevel(),
    professions = readProfessions(),
    battleTag = (select(2, BNGetInfo())),
  }
end

-- Translates WoW events into SelfInfo.CHANGED messages on the addon object.
function SelfInfo.watch(addon)
  for event, reason in pairs(EVENT_REASONS) do
    ns.Events.register(addon, event, function(_, ...)
      addon:SendMessage(SelfInfo.CHANGED, reason, ...)
    end)
  end
end

ns.SelfInfo = SelfInfo
return SelfInfo
