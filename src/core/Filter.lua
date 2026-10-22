-- Filter: the smart filter of the Friends tab (CF-36). Pure Lua.
-- Every term must match something of a character:
--   a word        name, owner's display name, class, role (tank/healer/dps), profession or zone (part of a
--                 word is enough, any case)
--   word number   a profession at least at that rank ("tailoring 150"); for a word that is no profession of
--                 the character: the word matches and the level is exactly that number ("mage 20")
--   number        exactly that level
--   a-b           a level from a to b ("20-30")
local _, ns = ...

local Filter = {}

-- Class files by class ID, for community members known without a record (only the community list).
local CLASS_BY_ID = { "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman", "mage",
                      "warlock", "monk", "druid" }
-- Role words match from their start only ("mage" must not find "damage").
local ROLE_WORDS = { tank = { "tank" }, heal = { "healer" }, dps = { "dps", "damage" } }

-- Terms from the search text; {} for an empty text.
function Filter.parse(text)
  local terms = {}
  for token in tostring(text or ""):lower():gmatch("[^%s,]+") do
    local from, to = token:match("^(%d+)%-(%d+)$")
    if from then
      local a, b = tonumber(from), tonumber(to)
      terms[#terms + 1] = { min = math.min(a, b), max = math.max(a, b) }
    elseif token:match("^%d+$") then
      local last = terms[#terms]
      if last and last.text and not last.number then
        last.number = tonumber(token)
      else
        terms[#terms + 1] = { level = tonumber(token) }
      end
    else
      terms[#terms + 1] = { text = token }
    end
  end
  return terms
end

local function contains(value, text)
  return type(value) == "string" and value:lower():find(text, 1, true) ~= nil
end

local function textMatches(row, ownerName, text)
  if contains(row.name, text) or contains(ownerName, text) or contains(row.zone, text)
     or contains(row.lastZone, text) then
    return true
  end
  local class = row.classFile or CLASS_BY_ID[row.classID or 0]
  if contains(class, text) then return true end
  local role = row.roleOverride or row.role
  for _, word in ipairs(ROLE_WORDS[role] or {}) do
    if word:sub(1, #text) == text then return true end
  end
  for _, profession in pairs(row.professions or {}) do
    if contains(profession.name, text) then return true end
  end
  return false
end

local function professionAtLeast(row, text, rank)
  for _, profession in pairs(row.professions or {}) do
    if contains(profession.name, text) and (profession.rank or 0) >= rank then return true end
  end
  return false
end

local function termMatches(row, ownerName, term)
  if term.min then
    return row.level ~= nil and row.level >= term.min and row.level <= term.max
  end
  if term.level then return row.level == term.level end
  if term.number then
    return professionAtLeast(row, term.text, term.number)
      or (textMatches(row, ownerName, term.text) and row.level == term.number)
  end
  return textMatches(row, ownerName, term.text)
end

function Filter.matches(row, ownerName, terms)
  for _, term in ipairs(terms) do
    if not termMatches(row, ownerName, term) then return false end
  end
  return true
end

--[[ The view with only matching characters (people without one are left out). Returns view, shown, total
(characters). With no terms the view is returned as it is. ]]
function Filter.apply(view, terms)
  local total = #(view.unlinked or {})
  for _, person in ipairs(view.people or {}) do total = total + #person.chars end
  if #terms == 0 then return view, total, total end

  local shown, people, unlinked = 0, {}, {}
  for _, person in ipairs(view.people or {}) do
    local chars = {}
    for _, row in ipairs(person.chars) do
      if Filter.matches(row, person.displayName, terms) then chars[#chars + 1] = row end
    end
    if #chars > 0 then
      local copy = {}
      for k, v in pairs(person) do copy[k] = v end
      copy.chars = chars
      people[#people + 1] = copy
      shown = shown + #chars
    end
  end
  for _, row in ipairs(view.unlinked or {}) do
    if Filter.matches(row, nil, terms) then unlinked[#unlinked + 1] = row end
  end
  shown = shown + #unlinked
  local filtered = {}
  for k, v in pairs(view) do filtered[k] = v end
  filtered.people, filtered.unlinked = people, unlinked
  return filtered, shown, total
end

ns.Filter = Filter
return Filter
