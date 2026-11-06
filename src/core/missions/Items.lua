-- Missions: items, crafting, cooking, First Aid and care (CF-75).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Items are told apart by item class and subclass (C_Item.GetItemInfoInstant, V105), never by Vanilla item or
-- spell IDs: Forever has new IDs (some above 1,000,000).
-- Facts of a day or week under facts.items = { cooked, cookKinds = { [itemID] = true }, bandages,
-- bandageKinds = { [itemID] = true }, fine, recipes = { [recipeID] = true }, cookRecipe (bool), gathered, coins,
-- looted = { [guid|itemID] = true }, equipNew (bool), blueGear (bool), eatOwn (bool), bandagesUsed,
-- bandageFriend (bool), potions, scrolls, wellFed (bool), buffFriend (bool), hadJunk = { [guid] = true },
-- tidy (bool) }.
-- Local stored data (ItemEvents): self.doomsday.worn = { [guid] = { [itemID] = true } }, the items each character
-- has worn. Optional, nil = unknown (rule 8).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local Items = {}

-- Blizzard's item classes and subclasses (Enum.ItemClass, Enum.ItemConsumableSubclass, ...).
Items.CONSUMABLE, Items.TRADE_GOODS, Items.RECIPE = 0, 7, 9
Items.POTION, Items.SCROLL, Items.FOOD, Items.BANDAGE = 1, 4, 5, 7 -- consumable subclasses
Items.LEATHER, Items.METAL_STONE, Items.HERB = 6, 7, 9             -- trade goods subclasses
Items.COOKING_RECIPE = 5                                           -- recipe subclass
Items.COOKING = 185                                                -- skill line
Items.UNCOMMON, Items.RARE = 2, 3                                  -- item quality (Enum.ItemQuality)
Items.MAX_SET = 50   -- item and recipe IDs kept per day or week (a cap, as Goals' lists)
Items.MAX_LOOTED = 200
Items.MAX_WORN = 1000 -- items kept per character in self.doomsday.worn

local function factsOf(f)
  local r = f.items
  if type(r) ~= "table" then
    r = { cooked = 0, cookKinds = {}, bandages = 0, bandageKinds = {}, fine = 0, recipes = {}, cookRecipe = false,
          gathered = 0, coins = 0, looted = {}, equipNew = false, blueGear = false, eatOwn = false,
          bandagesUsed = 0, bandageFriend = false, potions = 0, scrolls = 0, wellFed = false, buffFriend = false,
          hadJunk = {}, tidy = false }
    f.items = r
  end
  return r
end

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function add(set, key, max)
  if key == nil or set[key] or count(set) >= max then return end
  set[key] = true
end

local function amount(obs)
  return type(obs.count) == "number" and obs.count > 0 and obs.count or 1
end

local function is(obs, class, subclass)
  return obs.class == class and obs.subclass == subclass
end

-- ===== Helpers for ItemEvents (the decisions stay here) =====

--[[ Which bag item a cast used. candidates = { { id, class, subclass } } (the bag items whose use casts that spell,
C_Item.GetItemSpell), before and after = { [itemID] = count in the bags } around the cast. The one whose count
dropped; else the only candidate; else, when all agree on class and subclass, that class without an id. Nil when
it can't be told. ]]
function Items.usedItem(candidates, before, after)
  if type(candidates) ~= "table" or #candidates == 0 then return nil end
  before, after = type(before) == "table" and before or {}, type(after) == "table" and after or {}
  local dropped
  for _, c in ipairs(candidates) do
    if type(c) == "table" and (after[c.id] or 0) < (before[c.id] or 0) then
      if dropped then
        dropped = nil
        break
      end
      dropped = c
    end
  end
  if dropped then return dropped end
  if #candidates == 1 then return candidates[1] end
  local first = candidates[1]
  for _, c in ipairs(candidates) do
    if type(c) ~= "table" or c.class ~= first.class or c.subclass ~= first.subclass then return nil end
  end
  return { class = first.class, subclass = first.subclass }
end

--[[ The names a unit may go by (rule 4: names are compared whole, never split): GetUnitName(unit, true) (full),
and UnitName's two returns (name, second), which on Forever hold first and last name on some characters (V9) and
name and realm on others. ]]
function Items.nameForms(full, name, second)
  local forms = {}
  local function put(v) if type(v) == "string" and v ~= "" then forms[#forms + 1] = v end end
  put(full)
  put(name)
  if type(name) == "string" and type(second) == "string" and second ~= "" then
    put(name .. " " .. second)
    put(name .. "-" .. second)
  end
  return forms
end

-- Whether a cast's target name (UNIT_SPELLCAST_SENT) is one of a unit's names (Items.nameForms).
function Items.sameName(target, forms)
  if type(target) ~= "string" or target == "" then return false end
  for _, form in ipairs(type(forms) == "table" and forms or {}) do
    if form == target then return true end
  end
  return false
end

-- Whether a cast's target is the own character: no target, or one of its names (ownForms, Items.nameForms).
function Items.onSelf(target, ownForms)
  if target == nil or target == "" then return true end
  return Items.sameName(target, ownForms)
end

--[[ Adds an item a character put on to its worn set (worn = self.doomsday.worn, in place). True when the character
never wore it before. A character seen for the first time is seeded with what it wears (equipped = { itemID, ... })
and nothing counts as new for it. ]]
function Items.markWorn(worn, guid, id, equipped)
  if type(worn) ~= "table" or type(guid) ~= "string" then return false end
  local set = worn[guid]
  if type(set) ~= "table" then
    set = {}
    worn[guid] = set
    for _, e in ipairs(type(equipped) == "table" and equipped or {}) do
      if count(set) < Items.MAX_WORN then set[e] = true end
    end
    if id ~= nil then set[id] = true end
    return false
  end
  if id == nil or set[id] then return false end
  if count(set) >= Items.MAX_WORN then return false end
  set[id] = true
  return true
end

--[[ Whether created food is conjured, not cooked (Nico, 2026-11-06: conjured food never counts as cooked). In
Vanilla only mages conjure food and water, and the item looks like cooked food (consumable, food and drink), so
food a mage creates counts only when the cast that made it is a Cooking recipe (its skill line or parent is
Cooking, C_TradeSkillUI, unverified on Forever: unreadable means conjured). Other classes' food is cooked. ]]
Items.CONJURER = "MAGE"
function Items.conjured(obs)
  if type(obs) ~= "table" or obs.class ~= Items.CONSUMABLE or obs.subclass ~= Items.FOOD then return false end
  if obs.classFile ~= Items.CONJURER then return false end
  return obs.castSkillLine ~= Items.COOKING and obs.castParentSkillLine ~= Items.COOKING
end

-- Whether an aura is Well Fed, by its name: Forever's food buffs have new spell IDs (English client, rule 6).
Items.WELL_FED = "Well Fed"
function Items.isWellFed(auraName)
  return auraName == Items.WELL_FED
end

-- Whether a money message (CHAT_MSG_MONEY) is own loot: it matches one of the game's formats (YOU_LOOT_MONEY,
-- LOOT_MONEY_SPLIT; V109). Needs ns.GameText.
function Items.coinMessage(text, formats)
  if type(text) ~= "string" then return false end
  for _, format in pairs(type(formats) == "table" and formats or {}) do
    if ns.GameText.parse(text, format) then return true end
  end
  return false
end

-- ===== Observations =====

--[[ itemCreated: an item the current character created (LOOT_ITEM_CREATED_SELF, V105).
  { guid, id, count, class, subclass, quality, classFile (UnitClassBase), castSkillLine, castParentSkillLine (the
  profession of the cast that made it, read for a mage only) }. Conjured food is never cooked (Items.conjured). ]]
ns.Goals.registerKind("itemCreated", function(f, obs)
  local r = factsOf(f)
  local n = amount(obs)
  if Items.conjured(obs) then
    return
  elseif is(obs, Items.CONSUMABLE, Items.FOOD) then
    r.cooked = r.cooked + n
    add(r.cookKinds, obs.id, Items.MAX_SET)
  elseif is(obs, Items.CONSUMABLE, Items.BANDAGE) then
    r.bandages = r.bandages + n
    add(r.bandageKinds, obs.id, Items.MAX_SET)
  end
  if type(obs.quality) == "number" and obs.quality >= Items.UNCOMMON then r.fine = r.fine + 1 end
end)

--[[ itemLooted: an item the current character looted or received (LOOT_ITEM_SELF, LOOT_ITEM_PUSHED_SELF, V83).
  { guid, id, count, class, subclass, node (bool: the open loot had a GameObject source, V106), creature (bool: a
  Creature source) }. Herbs, metal and stone from a node, leather from a node or a body, count as gathered. ]]
ns.Goals.registerKind("itemLooted", function(f, obs)
  local r = factsOf(f)
  if type(obs.guid) == "string" and obs.id ~= nil and count(r.looted) < Items.MAX_LOOTED then
    r.looted[obs.guid .. "|" .. tostring(obs.id)] = true
  end
  if obs.class ~= Items.TRADE_GOODS then return end
  local sub = obs.subclass
  if ((sub == Items.HERB or sub == Items.METAL_STONE) and obs.node == true)
      or (sub == Items.LEATHER and (obs.node == true or obs.creature == true)) then
    r.gathered = r.gathered + amount(obs)
  end
end)

--[[ itemUsed: a bag item the current character used (its spell's UNIT_SPELLCAST_SUCCEEDED, V95, V116;
Items.usedItem). { guid, id (nil: not told), class, subclass, self (bool: cast on the own character,
Items.onSelf), friend (bool: the target is a friend's community character) } ]]
ns.Goals.registerKind("itemUsed", function(f, obs)
  local r = factsOf(f)
  if is(obs, Items.CONSUMABLE, Items.FOOD) then
    if obs.id ~= nil and r.cookKinds[obs.id] then r.eatOwn = true end
  elseif is(obs, Items.CONSUMABLE, Items.BANDAGE) then
    r.bandagesUsed = r.bandagesUsed + 1
    if obs.friend == true then r.bandageFriend = true end
  elseif is(obs, Items.CONSUMABLE, Items.POTION) then
    r.potions = r.potions + 1
  elseif is(obs, Items.CONSUMABLE, Items.SCROLL) then
    if obs.self == true then r.scrolls = r.scrolls + 1 end
  end
end)

--[[ itemRecipe: a recipe learned (NEW_RECIPE_LEARNED, V104). { guid, id (recipe ID), skillLine, parentSkillLine
(its profession, when readable), outputClass, outputSubclass (the item it makes, when readable), recipeSubclass
(the subclass of a recipe item used just before, when there was one) }. A cooking recipe: Cooking's skill line,
food or drink made, or a cooking recipe item read. ]]
ns.Goals.registerKind("itemRecipe", function(f, obs)
  local r = factsOf(f)
  add(r.recipes, obs.id, Items.MAX_SET)
  if obs.skillLine == Items.COOKING or obs.parentSkillLine == Items.COOKING
      or (obs.outputClass == Items.CONSUMABLE and obs.outputSubclass == Items.FOOD)
      or obs.recipeSubclass == Items.COOKING_RECIPE then
    r.cookRecipe = true
  end
end)

-- itemCoins: a money loot message (YOU_LOOT_MONEY or LOOT_MONEY_SPLIT, V109). { guid }
ns.Goals.registerKind("itemCoins", function(f)
  local r = factsOf(f)
  r.coins = r.coins + 1
end)

--[[ itemEquip: an item the current character put on (PLAYER_EQUIPMENT_CHANGED, GetInventoryItemID, V113).
  { guid, id, quality, new (bool: never worn by this character before, Items.markWorn) } ]]
ns.Goals.registerKind("itemEquip", function(f, obs)
  local r = factsOf(f)
  if type(obs.guid) == "string" and obs.id ~= nil and r.looted[obs.guid .. "|" .. tostring(obs.id)] then
    r.equipNew = true
  end
  if obs.new == true and type(obs.quality) == "number" and obs.quality >= Items.RARE then r.blueGear = true end
end)

--[[ itemAura: an aura seen out of combat (UNIT_AURA, C_UnitAuras.GetAuraDataByIndex, V110).
  { guid, wellFed (bool: Well Fed on the current character, Items.isWellFed), friend (bool: an own aura on a
  friend's community character) } ]]
ns.Goals.registerKind("itemAura", function(f, obs)
  local r = factsOf(f)
  if obs.wellFed == true then r.wellFed = true end
  if obs.friend == true then r.buffFriend = true end
end)

--[[ itemBags: the poor (grey) items in the current character's bags (C_Container.GetContainerItemInfo quality,
V112). { guid, junk (count) }. A character seen with junk that then has none tidied up. ]]
ns.Goals.registerKind("itemBags", function(f, obs)
  if type(obs.guid) ~= "string" or type(obs.junk) ~= "number" then return end
  local r = factsOf(f)
  if obs.junk > 0 then
    r.hadJunk[obs.guid] = true
  elseif r.hadJunk[obs.guid] then
    r.tidy = true
  end
end)

-- ===== Progress =====

local function items(f) return type(f.items) == "table" and f.items or {} end
local function bool(value) return value and 1 or 0 end
local function num(f, key) return items(f)[key] or 0 end
local function size(f, key) return count(items(f)[key]) end

local PROGRESS = {
  ["d.gather10"] = function(f) return num(f, "gathered"), 10 end,
  ["d.newRecipe"] = function(f) return size(f, "recipes"), 1 end,
  ["d.craftGreen"] = function(f) return num(f, "fine"), 1 end,
  ["d.cook5"] = function(f) return num(f, "cooked"), 5 end,
  ["d.cook15"] = function(f) return num(f, "cooked"), 15 end,
  ["d.cookKinds3"] = function(f) return size(f, "cookKinds"), 3 end,
  ["d.eatOwn"] = function(f) return bool(items(f).eatOwn), 1 end,
  ["d.cookRecipe"] = function(f) return bool(items(f).cookRecipe), 1 end,
  ["d.bandage3"] = function(f) return num(f, "bandages"), 3 end,
  ["d.bandage10"] = function(f) return num(f, "bandages"), 10 end,
  ["d.bandageKinds2"] = function(f) return size(f, "bandageKinds"), 2 end,
  ["d.bandageUp"] = function(f) return num(f, "bandagesUsed"), 1 end,
  ["d.bandageUse3"] = function(f) return num(f, "bandagesUsed"), 3 end,
  ["d.bandageFriend"] = function(f) return bool(items(f).bandageFriend), 1 end,
  ["d.coins10"] = function(f) return num(f, "coins"), 10 end,
  ["d.equipNew"] = function(f) return bool(items(f).equipNew), 1 end,
  ["d.wellFed"] = function(f) return bool(items(f).wellFed), 1 end,
  ["d.buffFriend"] = function(f) return bool(items(f).buffFriend), 1 end,
  ["d.tidyBags"] = function(f) return bool(items(f).tidy), 1 end,
  ["d.potion"] = function(f) return num(f, "potions"), 1 end,
  ["d.scrolls10"] = function(f) return num(f, "scrolls"), 10 end,

  ["w.blueGear"] = function(f) return bool(items(f).blueGear), 1 end,
  ["w.gather50"] = function(f) return num(f, "gathered"), 50 end,
  ["w.recipes3"] = function(f) return size(f, "recipes"), 3 end,
  ["w.cook30"] = function(f) return num(f, "cooked"), 30 end,
  ["w.cookKinds5"] = function(f) return size(f, "cookKinds"), 5 end,
  ["w.bandages20"] = function(f) return num(f, "bandages"), 20 end,
  ["w.potions5"] = function(f) return num(f, "potions"), 5 end,
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
Items.IDS = {}
for id in pairs(PROGRESS) do Items.IDS[#Items.IDS + 1] = id end
table.sort(Items.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.Items = Items
return Items
