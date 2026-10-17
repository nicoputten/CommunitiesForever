-- Describe: stable, human-readable text for records (used by /cf self for testing).
-- Pure Lua, no WoW globals.
local _, ns = ...

local Describe = {}

local function sortedKeys(t, less)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, less)
  return keys
end

local function age(updatedAt, now)
  if not updatedAt then return "never" end
  return string.format("%ds ago", math.max(0, now - updatedAt))
end

-- Lines describing the own record: header, then per character (sorted by name)
-- a summary line and a professions line (sorted by skillLine).
function Describe.selfRecord(record, now)
  local chars = record.chars or {}
  local guids = sortedKeys(chars, function(a, b)
    return (chars[a].name or a) < (chars[b].name or b)
  end)

  local lines = {
    string.format("BattleTag %s, version %s, %d character(s)",
      tostring(record.battleTag), tostring(record.version), #guids),
  }

  for _, guid in ipairs(guids) do
    local c = chars[guid]
    lines[#lines + 1] = string.format("%s: %s level %s, ilvl %s, race %s, %s, %s, updated %s (%s)",
      tostring(c.name), tostring(c.classFile), tostring(c.level), tostring(c.ilvl), tostring(c.raceID),
      tostring(c.faction), tostring(c.realm), age(c.updatedAt, now), tostring(c.updatedAt))

    local profs = {}
    local professions = c.professions or {}
    for _, skillLine in ipairs(sortedKeys(professions)) do
      local p = professions[skillLine]
      profs[#profs + 1] = string.format("%s %s/%s [%d]", tostring(p.name), tostring(p.rank), tostring(p.max), skillLine)
    end
    lines[#lines + 1] = "  " .. (#profs > 0 and table.concat(profs, ", ") or "no professions")
  end
  return lines
end

ns.Describe = Describe
return Describe
