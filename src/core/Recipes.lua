--[[ Recipes (CF-38): the own profession scan, profession links and the scan throttle. Pure Lua, no WoW globals.
Stored per character (docs/ARCHITECTURE.md "Data model"):
  chars[guid].recipes     = { [recipeID] = itemID }   learned recipes of ALL professions (GetAllRecipeIDs gives every
                                                      profession at once on Forever, V60); itemID 0 = no item
  chars[guid].recipesAt   = server time of the last complete scan
  chars[guid].recipeLines = { [recipeID] = skillLineID }  only where GetTradeSkillLineForRecipe answers (V60c)
  chars[guid].professions[skillLine].link      the "trade:..." hyperlink of GetTradeSkillListLink (no colour, no |H)
                                    .linkType  "short" (4 colon-separated fields: read live) or "long"
                                    .spec      the specialisation's English name, when known
                                    .scannedAt server time of the last scan of that profession
A scan replaces the recipe set (it is complete), never on an empty or failed read, and only touches the open
profession's fields. ]]
local _, ns = ...

local Recipes = {}

-- Asked Nico (CF-38): does the learned recipe set travel in the RECORD? Until then it stays local (the uploader
-- sends it from the SavedVariables); a received set is still cleaned and kept.
Recipes.IN_RECORD = false

Recipes.THROTTLE = 1        -- seconds: at most one scan per second
Recipes.MAX_LINK = 1024     -- bytes of a received link
Recipes.MAX_RECIPES = 3000  -- a received set with more is dropped
Recipes.MAX_SPEC = 40

-- Gathering professions and Fishing: skill only, no link (Mining, Herbalism, Skinning, Fishing).
Recipes.NO_LINK = { [186] = true, [182] = true, [393] = true, [356] = true }

-- Blizzard's colour for profession links.
Recipes.LINK_COLOR = "ffffd000"

-- The "trade:..." part of a profession link: from a full link (|H...|h) or a bare one. nil for anything else.
function Recipes.payload(link)
  if type(link) ~= "string" then return nil end
  local trade = link:match("|H(trade:[^|]*)|h") or link:match("^trade:[^|%[%]%s]*$")
  if not trade or #trade <= #"trade:" or #trade > Recipes.MAX_LINK then return nil end
  return trade
end

-- "short" when the trade part has 4 colon-separated fields (trade:<guid>:<spell>:<line>, read live when clicked),
-- else "long" (it carries the recipes). nil without a link.
function Recipes.linkType(link)
  local trade = Recipes.payload(link)
  if not trade then return nil end
  local _, colons = trade:gsub(":", ":")
  return colons + 1 == 4 and "short" or "long"
end

-- The clickable link text for chat: |cffffd000|Htrade:...|h[Tailoring]|h|r.
function Recipes.chatLink(link, name)
  local trade = Recipes.payload(link)
  if not trade then return nil end
  return string.format("|c%s|H%s|h[%s]|h|r", Recipes.LINK_COLOR, trade, tostring(name or "Profession"))
end

local function isId(v)
  return type(v) == "number" and v > 0 and v == math.floor(v) and v < 2 ^ 31
end

--[[ The learned recipe set from a read: entries = { { id, learned, itemID, line } } as the adapter read them.
Returns set ({ [id] = itemID or 0 }) and lines ({ [id] = skillLine }, nil when none was read), or nil when the read
was empty or failed (nothing learned: the list may still be loading, CF-100). ]]
function Recipes.fromScan(entries)
  if type(entries) ~= "table" then return nil end
  local set, lines, count, named = {}, {}, 0, 0
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.learned == true and isId(e.id) then
      set[e.id] = isId(e.itemID) and e.itemID or 0
      count = count + 1
      if isId(e.line) then
        lines[e.id] = e.line
        named = named + 1
      end
    end
  end
  if count == 0 then return nil end
  return set, named > 0 and lines or nil
end

local function sameSet(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if b[k] ~= v then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

--[[ Applies a scan to the own character. scan = {
  entries,     -- see fromScan; nil when the recipe list was not read
  profession,  -- skill line of the open window (nil: no window open, e.g. NEW_RECIPE_LEARNED with it closed)
  link,        -- GetTradeSkillListLink() as it came
  spec,        -- the open profession's specialisation name, or nil }
Returns synced (a field friends see changed: link, linkType, spec, and the set when IN_RECORD) and stored (anything
was written). Another profession's fields are never touched. ]]
function Recipes.apply(char, scan, now)
  if type(char) ~= "table" or type(scan) ~= "table" then return false, false end
  local synced, stored = false, false
  local set, lines = Recipes.fromScan(scan.entries)
  if set then
    if Recipes.IN_RECORD and not sameSet(char.recipes, set) then synced = true end
    char.recipes, char.recipesAt = set, now
    if lines then char.recipeLines = lines end
    stored = true
  end
  local line = scan.profession
  local p = isId(line) and type(char.professions) == "table" and char.professions[line]
  if type(p) == "table" and not Recipes.NO_LINK[line] then
    local trade = Recipes.payload(scan.link)
    if trade then
      local kind = Recipes.linkType(trade)
      if p.link ~= trade or p.linkType ~= kind then synced = true end
      p.link, p.linkType = trade, kind
    end
    if type(scan.spec) == "string" and scan.spec ~= "" and p.spec ~= scan.spec then
      p.spec = scan.spec
      synced = true
    end
    if trade or set then
      p.scannedAt = now
      stored = true
    end
  end
  return synced, stored or synced
end

-- Fields a snapshot refresh does not read; Snapshot keeps them from the stored character.
Recipes.CHAR_FIELDS = { "recipes", "recipesAt", "recipeLines" }
Recipes.PROFESSION_FIELDS = { "link", "linkType", "spec", "scannedAt" }

-- Copies the scan fields of `previous` into the freshly built `char` (same skill lines only).
function Recipes.carry(previous, char)
  if type(previous) ~= "table" or type(char) ~= "table" then return end
  for _, field in ipairs(Recipes.CHAR_FIELDS) do
    if char[field] == nil then char[field] = previous[field] end
  end
  for line, p in pairs(char.professions or {}) do
    local old = type(previous.professions) == "table" and previous.professions[line]
    if type(old) == "table" then
      for _, field in ipairs(Recipes.PROFESSION_FIELDS) do
        if p[field] == nil then p[field] = old[field] end
      end
    end
  end
end

-- The character as it goes into the own RECORD: without the recipe set unless IN_RECORD (a shallow copy).
function Recipes.outgoing(char)
  if Recipes.IN_RECORD or type(char) ~= "table" or (char.recipes == nil and char.recipeLines == nil) then
    return char
  end
  local copy = {}
  for k, v in pairs(char) do copy[k] = v end
  copy.recipes, copy.recipesAt, copy.recipeLines = nil, nil, nil
  return copy
end

local function cleanIdMap(map)
  if type(map) ~= "table" then return nil end
  local result, count = {}, 0
  for k, v in pairs(map) do
    if not (isId(k) and (isId(v) or (v == 0))) then return nil end
    count = count + 1
    if count > Recipes.MAX_RECIPES then return nil end
    result[k] = v
  end
  return result
end

-- A received character's recipe fields, cleaned in place (escape sequences are already stripped): only valid links
-- (the type is recomputed, never trusted), numeric times, a short spec name, numeric recipe maps.
function Recipes.clean(char)
  if type(char) ~= "table" then return end
  if type(char.professions) == "table" then
    for _, p in pairs(char.professions) do
      if type(p) == "table" then
        p.link = Recipes.payload(p.link)
        p.linkType = Recipes.linkType(p.link)
        if type(p.scannedAt) ~= "number" or p.scannedAt ~= p.scannedAt then p.scannedAt = nil end
        if type(p.spec) ~= "string" or p.spec == "" or #p.spec > Recipes.MAX_SPEC then p.spec = nil end
      end
    end
  end
  if char.recipes ~= nil then char.recipes = cleanIdMap(char.recipes) end
  if char.recipeLines ~= nil then
    local lines = cleanIdMap(char.recipeLines)
    for _, line in pairs(lines or {}) do
      if line == 0 then
        lines = nil
        break
      end
    end
    char.recipeLines = lines
  end
  if type(char.recipesAt) ~= "number" or char.recipesAt ~= char.recipesAt then char.recipesAt = nil end
end

--[[ The scan throttle: at most one scan per `interval` seconds, and an event inside it gets one later scan (an event
may never follow the list loading, CF-100). state = {} kept by the caller.
Returns 0 to scan now, a delay in seconds to scan later (call Recipes.ran when it runs), or nil when a later scan is
already planned. ]]
function Recipes.throttle(state, now, interval)
  if state.pending then return nil end
  local wait = state.lastAt and (state.lastAt + interval - now) or 0
  if wait <= 0 then
    state.lastAt = now
    return 0
  end
  state.pending = true
  return wait
end

function Recipes.ran(state, now)
  state.pending = nil
  state.lastAt = now
end

-- The Friends tab's link cell of a profession (RC07), or nil (gathering, Fishing, no skill line).
-- owner: whose character ("Mira"), name: the profession's name.
-- { state = "link", text = "[Tailoring]", link, chatLink, tip = { title, lines } }
-- { state = "notScanned", text = "not scanned", tip = { title, lines } }
function Recipes.cell(skillLine, p, owner)
  if not isId(skillLine) or Recipes.NO_LINK[skillLine] or type(p) ~= "table" then return nil end
  local name = tostring(p.name or "Profession")
  owner = tostring(owner or "They")
  local trade = Recipes.payload(p.link)
  if not trade then
    return { state = "notScanned", text = "not scanned",
             tip = { lines = { string.format("Opens once %s opens %s in game", owner, name) } } }
  end
  return { state = "link", text = "[" .. name .. "]", link = trade, chatLink = Recipes.chatLink(trade, name),
           tip = { title = string.format("%s\226\128\153s %s", owner, name),
                   lines = { "Click: open in game", "Shift-click: link in chat" } } }
end

ns.Recipes = Recipes
return Recipes
