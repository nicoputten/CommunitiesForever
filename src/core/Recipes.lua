--[[ Recipes (CF-38): the own profession scan, profession links, the recipe tails on the wire and the scan throttle.
Pure Lua, no WoW globals.
Stored per character (docs/ARCHITECTURE.md "Data model"), own characters and friends' alike:
  recipes     = { [recipeID] = itemID }  learned recipes of all the character's professions; itemID 0 = no item.
                                         What the site reads.
  recipesAt   = server time of the owner's last complete scan
  recipeOrder = { recipeID, ... }        the same recipes in the order the owner learned them (the first scan's in
                                         ID order): append-only, so a friend only needs the new tail
  recipesBase = server time the owner started this order; a new base means "start over" (a recipe was unlearned)
  recipeLines = { [recipeID] = skillLineID }  own only, where GetTradeSkillLineForRecipe answers (V60c); not sent
  professions[skillLine].link      the "trade:..." part of GetTradeSkillListLink (no colour, no |H)
                        .linkType  "short" (4 colon-separated fields: read live) or "long"
                        .spec      the specialisation's English name, when known
                        .scannedAt server time of the last scan of that profession
A scan ADDS its learned recipes to the stored set (CF-102): GetAllRecipeIDs may give only the open profession's list
(its 471 IDs match Forever's Tailoring recipes), so a recipe a scan doesn't list is kept. Recipes are never unlearned
here (Nico: the unlearn edge case doesn't matter); a new order and base start only when a recipe's item changes.
Never on an empty or failed read; only the open profession's fields change.
On the wire (SYNC.md): a REQ says per character how many recipes the asker holds and of which base (Recipes.have);
the RECORD then carries only the recipes after that count (Recipes.outgoing), and the receiver appends them when its
count and base still match (Recipes.receive). ]]
local _, ns = ...

local Recipes = {}

Recipes.THROTTLE = 1        -- seconds: at most one scan per second
Recipes.MAX_LINK = 1024     -- bytes of a received link
Recipes.MAX_RECIPES = 3000  -- a received list with more is dropped
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

local function isItem(v) return v == 0 or isId(v) end

local function isTime(v) return type(v) == "number" and v == v and v >= 0 end

--[[ The learned recipe set from a read: entries = { { id, learned, itemID, line } } as the adapter read them.
Returns set ({ [id] = itemID or 0 }) and lines ({ [id] = skillLine }, nil when none was read), or nil when the read
was empty or failed (nothing learned: the list may still be loading, CF-100). ]]
function Recipes.fromScan(entries)
  if type(entries) ~= "table" then return nil end
  local set, lines, count, named = {}, {}, 0, 0
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.learned == true and isId(e.id) and set[e.id] == nil then
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

local function sortedKeys(map, skip)
  local list = {}
  for id in pairs(map) do
    if not (skip and skip[id]) then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

-- The order for a new set: the stored order with the new recipes appended (in ID order), or a new order (and base)
-- when a stored recipe is gone or makes another item. Returns order, base, changed.
local function nextOrder(char, set, now)
  local order, base = char.recipeOrder, char.recipesBase
  local keep = type(order) == "table" and isTime(base)
  if keep then
    for _, id in ipairs(order) do
      if set[id] == nil or (char.recipes and char.recipes[id] ~= set[id]) then
        keep = false
        break
      end
    end
  end
  if not keep then return sortedKeys(set), now, true end
  local inOrder = {}
  for _, id in ipairs(order) do inOrder[id] = true end
  local added = sortedKeys(set, inOrder)
  if #added == 0 then return order, base, false end
  local copy = {}
  for i, id in ipairs(order) do copy[i] = id end
  for _, id in ipairs(added) do copy[#copy + 1] = id end
  return copy, base, true
end

--[[ Applies a scan to the own character. scan = {
  entries,     -- see fromScan; nil when the recipe list was not read
  profession,  -- skill line of the open window (nil: no window open, e.g. NEW_RECIPE_LEARNED with it closed)
  link,        -- GetTradeSkillListLink() as it came
  spec,        -- the open profession's specialisation name, or nil }
Returns synced (a field friends get changed: a recipe, a link, its type, the spec) and stored (anything was
written). Another profession's fields are never touched. ]]
function Recipes.apply(char, scan, now)
  if type(char) ~= "table" or type(scan) ~= "table" then return false, false end
  local synced, stored = false, false
  local set, lines = Recipes.fromScan(scan.entries)
  if set then
    -- CF-102: keep what earlier scans (of other professions) found.
    for id, item in pairs(type(char.recipes) == "table" and char.recipes or {}) do
      if set[id] == nil and isId(id) and isItem(item) then set[id] = item end
    end
    if lines and type(char.recipeLines) == "table" then
      for id, line in pairs(char.recipeLines) do
        if lines[id] == nil and set[id] ~= nil and isId(line) then lines[id] = line end
      end
    end
    local order, base, changed = nextOrder(char, set, now)
    if changed then synced = true end
    char.recipes, char.recipeOrder, char.recipesBase, char.recipesAt = set, order, base, now
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
Recipes.CHAR_FIELDS = { "recipes", "recipesAt", "recipeLines", "recipeOrder", "recipesBase" }
Recipes.PROFESSION_FIELDS = { "link", "linkType", "spec", "scannedAt" }
-- The recipe fields of a character on the wire (SYNC.md).
Recipes.WIRE_FIELDS = { "recipesFrom", "recipeIds", "recipeItems", "recipeCount" }

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

-- True when a stored character's order and set agree (every recipe once, each in the set, same count).
local function validOrder(char)
  local order, set = char.recipeOrder, char.recipes
  if type(order) ~= "table" or type(set) ~= "table" or not isTime(char.recipesBase) then return false end
  local seen, n = {}, 0
  for _, id in ipairs(order) do
    if seen[id] or set[id] == nil then return false end
    seen[id] = true
    n = n + 1
  end
  for _ in pairs(set) do n = n - 1 end
  return n == 0
end

-- For a REQ: what the asker holds of a person's characters, { [guid] = { count, base } }, or nil when nothing.
function Recipes.have(chars)
  local have
  for guid, char in pairs(type(chars) == "table" and chars or {}) do
    if type(char) == "table" and validOrder(char) then
      have = have or {}
      have[guid] = { #char.recipeOrder, char.recipesBase }
    end
  end
  return have
end

-- A received REQ's `rc`, cleaned: { [guid] = { count, base } } with a count ≥ 0 and a numeric base.
function Recipes.cleanHave(have)
  if type(have) ~= "table" then return nil end
  local result
  for guid, h in pairs(have) do
    if type(guid) == "string" and type(h) == "table" and type(h[1]) == "number" and h[1] >= 0
        and h[1] == math.floor(h[1]) and isTime(h[2]) then
      result = result or {}
      result[guid] = { h[1], h[2] }
    end
  end
  return result
end

--[[ A character as it goes into a RECORD (own or relayed): a shallow copy without the stored recipe fields and,
when it has recipes, the wire fields: recipesFrom = the count the asker already holds (its `have`, when its base is
ours and its count not above ours; else 0 = the full list), recipeIds and recipeItems = the recipes after it,
recipeCount = all of them, recipesBase, recipesAt. ]]
function Recipes.outgoing(char, have)
  if type(char) ~= "table" then return char end
  local copy = {}
  for k, v in pairs(char) do copy[k] = v end
  copy.recipes, copy.recipeOrder, copy.recipeLines = nil, nil, nil
  for _, field in ipairs(Recipes.WIRE_FIELDS) do copy[field] = nil end
  if not validOrder(char) then
    copy.recipesBase, copy.recipesAt = nil, nil
    return copy
  end
  local order = char.recipeOrder
  local from = 0
  if type(have) == "table" and have[2] == char.recipesBase and type(have[1]) == "number" and have[1] <= #order then
    from = have[1]
  end
  local ids, items = {}, {}
  for i = from + 1, #order do
    ids[#ids + 1] = order[i]
    items[#items + 1] = char.recipes[order[i]]
  end
  copy.recipesFrom, copy.recipeIds, copy.recipeItems, copy.recipeCount = from, ids, items, #order
  return copy
end

local function carryStored(stored, incoming)
  for _, field in ipairs(Recipes.CHAR_FIELDS) do incoming[field] = nil end
  if type(stored) == "table" and validOrder(stored) then
    incoming.recipes, incoming.recipeOrder = stored.recipes, stored.recipeOrder
    incoming.recipesBase, incoming.recipesAt = stored.recipesBase, stored.recipesAt
  end
end

--[[ Turns a received (cleaned) character's wire fields into the stored ones, in place, from the stored copy:
recipesFrom 0 = the full list; a tail is appended only when the stored copy has exactly recipesFrom recipes of the
same base. Anything else (no recipe fields, a tail that doesn't fit) keeps what is stored, so a record never loses
recipes; the next REQ says the real count and gets the right tail. A stored-form character (Merge.absorb) stays. ]]
function Recipes.receive(stored, incoming)
  if type(incoming) ~= "table" then return end
  local from, ids, items = incoming.recipesFrom, incoming.recipeIds, incoming.recipeItems
  local count, base = incoming.recipeCount, incoming.recipesBase
  for _, field in ipairs(Recipes.WIRE_FIELDS) do incoming[field] = nil end
  if from == nil then
    if not validOrder(incoming) then carryStored(stored, incoming) end
    return
  end
  local set, order
  if from == 0 then
    set, order = {}, {}
  elseif type(stored) == "table" and validOrder(stored) and stored.recipesBase == base
      and #stored.recipeOrder == from then
    set, order = {}, {}
    for k, v in pairs(stored.recipes) do set[k] = v end
    for i, id in ipairs(stored.recipeOrder) do order[i] = id end
  else
    carryStored(stored, incoming)
    return
  end
  for i, id in ipairs(ids) do
    if set[id] ~= nil then
      carryStored(stored, incoming)
      return
    end
    set[id] = items[i]
    order[#order + 1] = id
  end
  if #order ~= count then
    carryStored(stored, incoming)
    return
  end
  local at = incoming.recipesAt
  incoming.recipes, incoming.recipeOrder, incoming.recipesBase = set, order, base
  incoming.recipesAt = at
end

local function cleanIdList(list, check)
  if type(list) ~= "table" then return nil end
  local n = #list
  if n > Recipes.MAX_RECIPES then return nil end
  local result = {}
  for i = 1, n do
    if not check(list[i]) then return nil end
    result[i] = list[i]
  end
  for k in pairs(list) do
    if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then return nil end
  end
  return result
end

local function cleanSet(map)
  if type(map) ~= "table" then return nil end
  local result, count = {}, 0
  for k, v in pairs(map) do
    if not (isId(k) and isItem(v)) then return nil end
    count = count + 1
    if count > Recipes.MAX_RECIPES then return nil end
    result[k] = v
  end
  return result
end

local function dropRecipes(char)
  for _, field in ipairs(Recipes.CHAR_FIELDS) do char[field] = nil end
  for _, field in ipairs(Recipes.WIRE_FIELDS) do char[field] = nil end
end

-- A received character's recipe fields, cleaned in place (escape sequences are already stripped): only valid links
-- (the type is recomputed, never trusted), numeric times, a short spec name, and recipe fields of the right shape
-- (any bad one drops them all). recipeLines is own only and never kept.
function Recipes.clean(char)
  if type(char) ~= "table" then return end
  if type(char.professions) == "table" then
    for _, p in pairs(char.professions) do
      if type(p) == "table" then
        p.link = Recipes.payload(p.link)
        p.linkType = Recipes.linkType(p.link)
        if not isTime(p.scannedAt) then p.scannedAt = nil end
        if type(p.spec) ~= "string" or p.spec == "" or #p.spec > Recipes.MAX_SPEC then p.spec = nil end
      end
    end
  end
  char.recipeLines = nil
  if char.recipesAt ~= nil and not isTime(char.recipesAt) then char.recipesAt = nil end
  if char.recipesFrom ~= nil then
    local from, count = char.recipesFrom, char.recipeCount
    local ids, items = cleanIdList(char.recipeIds, isId), cleanIdList(char.recipeItems, isItem)
    local ok = type(from) == "number" and from >= 0 and from == math.floor(from) and ids and items
      and #ids == #items and type(count) == "number" and count == from + #ids and count <= Recipes.MAX_RECIPES
      and isTime(char.recipesBase)
    if not ok then return dropRecipes(char) end
    char.recipeIds, char.recipeItems = ids, items
    char.recipes, char.recipeOrder = nil, nil
  elseif char.recipes ~= nil or char.recipeOrder ~= nil then
    char.recipes = cleanSet(char.recipes)
    char.recipeOrder = cleanIdList(char.recipeOrder, isId)
    if not validOrder(char) then dropRecipes(char) end
  else
    char.recipesBase = nil
  end
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
