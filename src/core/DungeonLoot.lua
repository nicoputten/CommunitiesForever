-- DungeonLoot: bosses and loot of a dungeon from the shipped loot file (ns.LootData, Data\Loot.lua, CF-106), and who
-- can use a drop. Pure Lua, no WoW globals. The rule "the class can ever use it" is shared with the site
-- (tests/fixtures/loot-usable-cases.json).
local _, ns = ...

local DungeonLoot = {}

DungeonLoot.SHOWN = 6        -- drops per boss before "N more"
DungeonLoot.ARMOR, DungeonLoot.WEAPON = 4, 2
DungeonLoot.RECIPE, DungeonLoot.QUEST = 9, 12

-- Class IDs (ChrClasses) by class file: the AllowableClass mask has bit (id - 1).
DungeonLoot.CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8,
                          WARLOCK = 9, DRUID = 11 }

--[[ Armor subclasses (Enum.ItemArmorSubclass) a class wears by level 60: 0 misc (rings, necks, trinkets), 1 cloth,
2 leather, 3 mail (hunter, shaman from 40), 4 plate (warrior, paladin from 40), 6 shield, 7 libram, 8 idol, 9 totem.
Source: warcraft.wiki.gg, the class pages and "Class proficiencies" (see the fixture). ]]
local ALL_ARMOR = { [0] = true, [1] = true }
DungeonLoot.ARMOR_BY_CLASS = {
  WARRIOR = { 2, 3, 4, 6 }, PALADIN = { 2, 3, 4, 6, 7 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3, 6, 9 },
  ROGUE = { 2 }, DRUID = { 2, 8 }, PRIEST = {}, MAGE = {}, WARLOCK = {},
}

--[[ Weapon subclasses (Enum.ItemWeaponSubclass) a class can learn in Classic: 0 one-hand axe, 1 two-hand axe, 2 bow,
3 gun, 4 one-hand mace, 5 two-hand mace, 6 polearm, 7 one-hand sword, 8 two-hand sword, 10 staff, 13 fist weapon,
15 dagger, 16 thrown, 18 crossbow, 19 wand. Everyone: 14 miscellaneous, 20 fishing pole. ]]
local ALL_WEAPONS = { [14] = true, [20] = true }
DungeonLoot.WEAPONS_BY_CLASS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
  PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 },
  ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
  PRIEST = { 4, 10, 15, 19 },
  SHAMAN = { 0, 1, 4, 5, 10, 13, 15 },
  MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 },
  DRUID = { 4, 5, 10, 13, 15 },
}

local function has(list, value)
  for _, v in ipairs(list or {}) do
    if v == value then return true end
  end
  return false
end

-- True when bit (id - 1) is set in mask (doubles, no bit library).
local function maskHas(mask, id)
  return math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end

--[[ True when the class can ever use the drop (Nico 2026-11-07): class-only items by their AllowableClass mask
(nil, 0 or -1: every class), the armor types the class reaches by 60, shields, and weapon types it can learn. No
level, no trained skills. Quest items and anything not armor or a weapon are usable. An unknown class (nil) can use
everything. drop = { cls, sub, classes, quest } (the loot file's fields). ]]
function DungeonLoot.usable(classFile, drop)
  if type(drop) ~= "table" or not DungeonLoot.CLASS_IDS[classFile] then return true end
  if drop.quest or drop.cls == DungeonLoot.QUEST then return true end
  local mask = drop.classes
  if type(mask) == "number" and mask > 0 and not maskHas(mask, DungeonLoot.CLASS_IDS[classFile]) then return false end
  if drop.cls == DungeonLoot.ARMOR then
    return ALL_ARMOR[drop.sub] == true or has(DungeonLoot.ARMOR_BY_CLASS[classFile], drop.sub)
  elseif drop.cls == DungeonLoot.WEAPON then
    return ALL_WEAPONS[drop.sub] == true or has(DungeonLoot.WEAPONS_BY_CLASS[classFile], drop.sub)
  end
  return true
end

-- ===== The type line of a loot row ("Two-Hand · Mace", "Leather · Legs", "Quest item", "Recipe · Cooking") =====

local DOT = " \194\183 "
local SLOTS = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_BODY = "Shirt",
  INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs",
  INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger",
  INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_HOLDABLE = "Held In Off-hand",
  INVTYPE_TABARD = "Tabard", INVTYPE_SHIELD = "Shield", INVTYPE_WEAPON = "One-Hand", INVTYPE_2HWEAPON = "Two-Hand",
  INVTYPE_WEAPONMAINHAND = "Main Hand", INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_RANGED = "Ranged",
  INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Ranged", INVTYPE_RELIC = "Relic",
}
local ARMOR_TYPES = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate" }
local OTHER_ARMOR = { [6] = "Shield", [7] = "Libram", [8] = "Idol", [9] = "Totem" }
-- Weapons named with their hand (One-Hand · Sword) and those named alone (Dagger, Staff).
local HANDED = { [0] = "Axe", [1] = "Axe", [4] = "Mace", [5] = "Mace", [7] = "Sword", [8] = "Sword",
                 [13] = "Fist Weapon" }
local ALONE = { [2] = "Bow", [3] = "Gun", [6] = "Polearm", [10] = "Staff", [14] = "Miscellaneous", [15] = "Dagger",
                [16] = "Thrown", [18] = "Crossbow", [19] = "Wand", [20] = "Fishing Pole" }
local RECIPES = { [0] = "Book", [1] = "Leatherworking", [2] = "Tailoring", [3] = "Engineering", [4] = "Blacksmithing",
                  [5] = "Cooking", [6] = "Alchemy", [7] = "First Aid", [8] = "Enchanting", [9] = "Fishing" }
local CLASSES = { [0] = "Consumable", [1] = "Container", [5] = "Reagent", [6] = "Projectile", [7] = "Trade Goods",
                  [11] = "Quiver", [13] = "Key", [15] = "Miscellaneous" }

-- The grey type text of a drop; equipLoc: the game's INVTYPE_* (C_Item.GetItemInfoInstant), nil when unknown.
function DungeonLoot.typeText(drop, equipLoc)
  if type(drop) ~= "table" then return "" end
  local slot = SLOTS[equipLoc or ""]
  if drop.quest or drop.cls == DungeonLoot.QUEST then return "Quest item" end
  if drop.cls == DungeonLoot.RECIPE then
    return RECIPES[drop.sub] and ("Recipe" .. DOT .. RECIPES[drop.sub]) or "Recipe"
  end
  if drop.cls == DungeonLoot.WEAPON then
    if ALONE[drop.sub] then return ALONE[drop.sub] end
    local name = HANDED[drop.sub] or "Weapon"
    local hand = slot or ((drop.sub == 1 or drop.sub == 5 or drop.sub == 8) and "Two-Hand") or nil
    return hand and (hand .. DOT .. name) or name
  end
  if drop.cls == DungeonLoot.ARMOR then
    if OTHER_ARMOR[drop.sub] then return OTHER_ARMOR[drop.sub] end
    if equipLoc == "INVTYPE_CLOAK" then return "Back" end
    local armor = ARMOR_TYPES[drop.sub]
    if armor and slot then return armor .. DOT .. slot end
    return armor or slot or "Armor"
  end
  return CLASSES[drop.cls] or ""
end

-- ===== The loot file =====

--[[ A dungeon's bosses from the loot file (data = ns.LootData), in DungeonEncounter order:
  { { id, name, final, optional, drops = { drop } } }; {} without data for the dungeon. Broken entries are left out
(the file is generated, but a hand-edited copy must not break the tab). ]]
function DungeonLoot.bosses(data, dungeonId)
  local list = type(data) == "table" and type(data.dungeons) == "table" and data.dungeons[dungeonId]
  local out = {}
  for _, b in ipairs(type(list) == "table" and list or {}) do
    if type(b) == "table" and type(b.name) == "string" then
      local drops = {}
      for _, d in ipairs(type(b.drops) == "table" and b.drops or {}) do
        if type(d) == "table" and type(d.item) == "number" then drops[#drops + 1] = d end
      end
      out[#out + 1] = { id = b.id, name = b.name, final = b.final == true, optional = b.optional == true,
                        drops = drops }
    end
  end
  return out
end

--[[ CF-106: the bosses of a dungeon (a Dungeons entry): its own, or for an id older versions planned (Dungeons.LEGACY:
"strat", "dme") every wing's in wing order, each boss with `wing` = the wing's id, each wing's final boss final (so the
run counts as cleared when any wing's final boss dies). ]]
function DungeonLoot.bossesFor(data, dungeon)
  if type(dungeon) ~= "table" then return {} end
  if type(dungeon.wings) ~= "table" then return DungeonLoot.bosses(data, dungeon.id) end
  local out = {}
  for _, wing in ipairs(dungeon.wings) do
    for _, b in ipairs(DungeonLoot.bosses(data, wing)) do
      b.wing = wing
      out[#out + 1] = b
    end
  end
  return out
end

--[[ A boss's loot rows: highest chance first (then item ID), each { drop, usable }; usableOnly hides what the class
can't use (quest drops always stay). At most SHOWN unless open; more = how many are left out (after the switch).
Returns rows, more. ]]
function DungeonLoot.rows(boss, classFile, usableOnly, open)
  local all = {}
  for _, d in ipairs(type(boss) == "table" and boss.drops or {}) do
    local ok = DungeonLoot.usable(classFile, d)
    if ok or not usableOnly then all[#all + 1] = { drop = d, usable = ok } end
  end
  table.sort(all, function(a, b)
    local ca, cb = tonumber(a.drop.chance) or 0, tonumber(b.drop.chance) or 0
    if ca ~= cb then return ca > cb end
    return a.drop.item < b.drop.item
  end)
  if open or #all <= DungeonLoot.SHOWN then return all, 0 end
  local rows = {}
  for i = 1, DungeonLoot.SHOWN do rows[i] = all[i] end
  return rows, #all - DungeonLoot.SHOWN
end

-- "36%", "4%", "<1%", "0.5%" for a chance in percent.
function DungeonLoot.chanceText(chance)
  if type(chance) ~= "number" then return "" end
  if chance >= 1 then return string.format("%d%%", math.floor(chance + 0.5)) end
  if chance > 0 then return "<1%" end
  return ""
end

-- Recipe subclass -> the profession's skill line (the parent line, as CF-105 found on Forever: Cooking 185).
DungeonLoot.RECIPE_LINES = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185, [6] = 171, [7] = 129, [8] = 333,
                             [9] = 356 }

-- Profession names by skill line, for "Requires Cooking (75)".
DungeonLoot.LINE_NAMES = { [165] = "Leatherworking", [197] = "Tailoring", [202] = "Engineering",
                           [164] = "Blacksmithing", [185] = "Cooking", [171] = "Alchemy", [129] = "First Aid", [333] = "Enchanting",
                           [356] = "Fishing" }

--[[ A recipe drop among the group's characters (board DL03 C): chars = { { name, recipes = { [recipeID] = itemID },
professions = { [skillLineID] = { name, rank } } } }. The drop's profession is its `line` (the loot file, Nico
2026-11-07), else the one of its recipe subclass; `skill` is the rank it needs. Returns { known = true } when someone
learned it, else { known = false, canLearn = { "Lia (Cooking 150)", ... }, requires = "Requires Cooking (75)" or nil }:
who has the profession at that rank or more (any rank without `skill`). ]]
function DungeonLoot.recipeState(drop, chars)
  local line = (drop and type(drop.line) == "number" and drop.line) or DungeonLoot.RECIPE_LINES[drop and drop.sub]
  local skill = drop and type(drop.skill) == "number" and drop.skill or nil
  local canLearn = {}
  for _, c in ipairs(chars or {}) do
    if drop.recipe and type(c.recipes) == "table" and c.recipes[drop.recipe] ~= nil then return { known = true } end
    local p = line and type(c.professions) == "table" and c.professions[line]
    if type(p) == "table" and (not skill or (type(p.rank) == "number" and p.rank >= skill)) then
      canLearn[#canLearn + 1] = string.format("%s (%s %s)", tostring(c.name),
        tostring(p.name or DungeonLoot.LINE_NAMES[line] or RECIPES[drop.sub]), tostring(p.rank or "?"))
    end
  end
  table.sort(canLearn)
  local requires
  local profession = DungeonLoot.LINE_NAMES[line] or RECIPES[drop.sub]
  if skill and profession then requires = string.format("Requires %s (%d)", profession, skill) end
  return { known = false, canLearn = canLearn, requires = requires }
end

--[[ When a dungeon was last cleared (its final boss died) in the kill log: kills = { { guid, encounterID, at,
group = { guid, ... } } }. Returns the newest such kill or nil. ]]
function DungeonLoot.lastCleared(bosses, kills)
  local final
  for _, b in ipairs(bosses or {}) do
    if b.final then final = b.id end
  end
  if final == nil then return nil end
  local best
  for _, k in ipairs(kills or {}) do
    if k.encounterID == final and type(k.at) == "number" and (not best or k.at > best.at) then best = k end
  end
  return best
end

ns.DungeonLoot = DungeonLoot
return DungeonLoot
