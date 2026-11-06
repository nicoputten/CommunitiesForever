local net = require("net")
local wowapi = require("mocks.wowapi")

-- CF-38: learned recipes travel to friends, and after the first full list only the new ones (end to end, tests/net).
describe("recipes between friends (CF-38)", function()
  local world, recipes

  local A_GUID, B_GUID, C_GUID = "Player-1-0000A001", "Player-1-0000B001", "Player-1-0000C001"

  local function people(withC)
    world:person({ key = "A", name = "Ada Example", guid = A_GUID, battleTag = "Ada#1001", classFile = "MAGE",
                   classID = 8, level = 20, gameAccountID = 101, friends = { "B" } })
    world:person({ key = "B", name = "Bob Example", guid = B_GUID, battleTag = "Bob#2002", classFile = "ROGUE",
                   classID = 4, level = 22, gameAccountID = 102, friends = withC and { "A", "C" } or { "A" } })
    if withC then
      world:person({ key = "C", name = "Cy Example", guid = C_GUID, battleTag = "Cy#3003", classFile = "PRIEST",
                     classID = 5, level = 18, gameAccountID = 103, friends = { "B" } })
    end
  end

  -- Ada's profession window (Cooking) with the recipes in `recipes`.
  local function tradeSkillUI()
    return {
      IsTradeSkillLinked = function() return false end,
      GetAllRecipeIDs = function()
        local ids = {}
        for id in pairs(recipes) do ids[#ids + 1] = id end
        return ids
      end,
      GetRecipeInfo = function(id) return { recipeID = id, learned = recipes[id] ~= nil } end,
      GetRecipeOutputItemData = function(id) return { itemID = recipes[id] } end,
      GetBaseProfessionInfo = function() return { professionID = 185 } end,
      GetTradeSkillListLink = function() return "|cffffd000|Htrade:" .. A_GUID .. ":2550:185|h[Cooking]|h|r" end,
    }
  end

  local function adaFires(event, ...)
    local args = { ... }
    world:with("A", function(c)
      c.globals.C_TradeSkillUI = c.globals.C_TradeSkillUI or tradeSkillUI()
      wowapi.activate(c.globals)
      wowapi.fireEvent(c.state, event, unpack(args))
    end)
  end

  local function adaAt(key)
    for _, person in pairs(world.clients[key].addon.db.global.people) do
      if person.chars and person.chars[A_GUID] then return person.chars[A_GUID] end
    end
  end

  -- The recipesFrom of each RECORD Ada sent with her character, in order.
  local function fromsSentBy(key)
    local froms = {}
    for _, s in ipairs(world:sentBy(key)) do
      local char = s.message.t == "RECORD" and s.message.chars and s.message.chars[A_GUID]
      if char and char.recipesFrom then froms[#froms + 1] = char.recipesFrom end
    end
    return froms
  end

  before_each(function()
    world = net.new()
    recipes = { [2538] = 2679, [2540] = 2681, [7421] = 0 }
  end)

  after_each(function()
    world:shutdown()
  end)

  it("sends the full list once, then only the recipes learned since", function()
    people(false)
    world:login("A")
    world:login("B")
    world:settle()
    adaFires("TRADE_SKILL_SHOW")
    world:settle()
    local atBob = adaAt("B")
    assert.same({ [2538] = 2679, [2540] = 2681, [7421] = 0 }, atBob.recipes)
    assert.equals("trade:" .. A_GUID .. ":2550:185", atBob.professions[185].link)

    recipes[2541] = 2684
    adaFires("NEW_RECIPE_LEARNED", 2541)
    world:settle()
    atBob = adaAt("B")
    assert.same({ [2538] = 2679, [2540] = 2681, [7421] = 0, [2541] = 2684 }, atBob.recipes)
    assert.same({ 2538, 2540, 7421, 2541 }, atBob.recipeOrder)
    local froms = fromsSentBy("A")
    assert.equals(3, froms[#froms]) -- only the new one went
    assert.equals(0, froms[1])
  end)

  it("brings the recipes to a friend's friend through the relay, also as a tail", function()
    people(true)
    world:login("A")
    world:login("B")
    world:login("C")
    world:settle()
    adaFires("TRADE_SKILL_SHOW")
    world:settle()
    assert.same({ [2538] = 2679, [2540] = 2681, [7421] = 0 }, adaAt("C").recipes)
    recipes[2541] = 2684
    adaFires("NEW_RECIPE_LEARNED", 2541)
    world:settle()
    assert.same({ 2538, 2540, 7421, 2541 }, adaAt("C").recipeOrder)
    local froms = fromsSentBy("B")
    assert.equals(3, froms[#froms]) -- Bob relayed only the new one
  end)
end)
