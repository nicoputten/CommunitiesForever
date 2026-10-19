-- Talents: talent point split per Vanilla tree and role (CF-18). Pure Lua, no WoW globals.
-- Forever keeps a class's three Vanilla trees side by side in one C_Traits tree (V29): the trees are
-- the three columns of nodes, separated by the two largest horizontal gaps.
local _, ns = ...

local Talents = {}

-- Vanilla tree names per class, left to right (order verified for Warrior, V29).
Talents.TREE_NAMES = {
  WARRIOR = { "Arms", "Fury", "Protection" },
  PALADIN = { "Holy", "Protection", "Retribution" },
  HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
  ROGUE = { "Assassination", "Combat", "Subtlety" },
  PRIEST = { "Discipline", "Holy", "Shadow" },
  SHAMAN = { "Elemental", "Enhancement", "Restoration" },
  MAGE = { "Arcane", "Fire", "Frost" },
  WARLOCK = { "Affliction", "Demonology", "Destruction" },
  DRUID = { "Balance", "Feral Combat", "Restoration" },
}

-- Auto role per class and main tree (story CF-18); everything not listed is dps.
-- Druid Feral defaults to dps (players override it to tank).
local ROLE_BY_TREE = {
  WARRIOR = { [3] = "tank" },
  PALADIN = { [1] = "heal", [2] = "tank" },
  PRIEST = { [1] = "heal", [2] = "heal" },
  DRUID = { [3] = "heal" },
  SHAMAN = { [3] = "heal" },
}

Talents.ROLES = { "tank", "heal", "dps" }
Talents.ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }

local TREE_COUNT = 3

-- Column (1..3) per node, by splitting the distinct x positions at the two largest gaps.
-- nodes = { { posX, ranks } }. Returns a function posX -> column, or nil without enough columns.
local function columnsOf(nodes)
  local xs, seen = {}, {}
  for _, node in ipairs(nodes) do
    if type(node.posX) == "number" and not seen[node.posX] then
      seen[node.posX] = true
      xs[#xs + 1] = node.posX
    end
  end
  table.sort(xs)
  if #xs < TREE_COUNT then return nil end

  local gaps = {}
  for i = 2, #xs do
    gaps[#gaps + 1] = { size = xs[i] - xs[i - 1], at = xs[i] }
  end
  table.sort(gaps, function(a, b) return a.size > b.size end)
  local cuts = { gaps[1].at, gaps[2].at }
  table.sort(cuts)
  return function(x)
    if x < cuts[1] then return 1 end
    if x < cuts[2] then return 2 end
    return 3
  end
end

--[[ Talent summary from raw nodes (all nodes of the class tree, with ranks purchased):
  nodes = { { posX = number, ranks = number } }
Returns trees = { { name, points }, x3 } (nil without talent data) and mainTree = index of the tree
with the most points (nil when no points are spent; ties go to the lower index).
]]
function Talents.summarize(nodes, classFile)
  if type(nodes) ~= "table" or #nodes == 0 then return nil, nil end
  local column = columnsOf(nodes)
  if not column then return nil, nil end

  local names = Talents.TREE_NAMES[classFile] or { "Tree 1", "Tree 2", "Tree 3" }
  local trees = {}
  for i = 1, TREE_COUNT do trees[i] = { name = names[i], points = 0 } end
  for _, node in ipairs(nodes) do
    if type(node.posX) == "number" and type(node.ranks) == "number" and node.ranks > 0 then
      local tree = trees[column(node.posX)]
      tree.points = tree.points + node.ranks
    end
  end

  local mainTree
  for i, tree in ipairs(trees) do
    if tree.points > 0 and (not mainTree or tree.points > trees[mainTree].points) then mainTree = i end
  end
  return trees, mainTree
end

-- Role guessed from the main tree, or nil without spent points.
function Talents.autoRole(classFile, mainTree)
  if not mainTree then return nil end
  local byTree = ROLE_BY_TREE[classFile]
  return byTree and byTree[mainTree] or "dps"
end

-- Effective role: the player's override, else the auto role.
function Talents.role(classFile, mainTree, override)
  if override == "tank" or override == "heal" or override == "dps" then return override end
  return Talents.autoRole(classFile, mainTree)
end

ns.Talents = Talents
return Talents
