local helpers = require("helpers")

-- CF-106: loot of a dungeon's bosses, "Usable by", and the loot file's shape.
describe("Dungeon loot (CF-106)", function()
  local DungeonLoot

  before_each(function()
    local ns = helpers.coreNs()
    DungeonLoot = helpers.loadAddonFile("src/core/DungeonLoot.lua", ns)
  end)

  describe("usable: golden cases (tests/fixtures/loot-usable-cases.json)", function()
    local data = helpers.readJson("tests/fixtures/loot-usable-cases.json")
    it("has the file's class IDs", function()
      local ns = helpers.coreNs()
      local loot = helpers.loadAddonFile("src/core/DungeonLoot.lua", ns)
      for class, id in pairs(data.classIds) do assert.are.equal(id, loot.CLASS_IDS[class]) end
    end)
    for i, c in ipairs(data.cases) do
      it(string.format("%d: %s %d/%d%s%s is %s", i, c.class, c.cls, c.sub,
        c.classes and (" classes " .. c.classes) or "", c.quest and " (quest)" or "", tostring(c.usable)), function()
        assert.are.equal(c.usable, DungeonLoot.usable(c.class, { cls = c.cls, sub = c.sub, classes = c.classes,
                                                                quest = c.quest }))
      end)
    end
  end)

  it("lets an unknown class use everything", function()
    assert.is_true(DungeonLoot.usable(nil, { cls = 4, sub = 4 }))
  end)

  it("names the type of a drop as the board does", function()
    assert.are.equal("Two-Hand \194\183 Mace", DungeonLoot.typeText({ cls = 2, sub = 5 }, "INVTYPE_2HWEAPON"))
    assert.are.equal("One-Hand \194\183 Sword", DungeonLoot.typeText({ cls = 2, sub = 7 }, "INVTYPE_WEAPON"))
    assert.are.equal("Dagger", DungeonLoot.typeText({ cls = 2, sub = 15 }, "INVTYPE_WEAPON"))
    assert.are.equal("Staff", DungeonLoot.typeText({ cls = 2, sub = 10 }, "INVTYPE_2HWEAPON"))
    assert.are.equal("Leather \194\183 Legs", DungeonLoot.typeText({ cls = 4, sub = 2 }, "INVTYPE_LEGS"))
    assert.are.equal("Finger", DungeonLoot.typeText({ cls = 4, sub = 0 }, "INVTYPE_FINGER"))
    assert.are.equal("Back", DungeonLoot.typeText({ cls = 4, sub = 1 }, "INVTYPE_CLOAK"))
    assert.are.equal("Quest item", DungeonLoot.typeText({ cls = 12, sub = 0, quest = 214 }, nil))
    assert.are.equal("Recipe \194\183 Cooking", DungeonLoot.typeText({ cls = 9, sub = 5 }, nil))
    assert.are.equal("One-Hand \194\183 Axe", DungeonLoot.typeText({ cls = 2, sub = 0 }, "INVTYPE_WEAPON"))
    assert.are.equal("Two-Hand \194\183 Axe", DungeonLoot.typeText({ cls = 2, sub = 1 }, nil)) -- not cached yet
  end)

  local function boss(n)
    local drops = {}
    for i = 1, n do drops[i] = { item = 100 + i, chance = 50 - i, cls = 4, sub = i % 2 == 0 and 4 or 1 } end
    return { name = "Edwin VanCleef", drops = drops }
  end

  it("shows 6 drops, highest chance first, and how many more", function()
    local rows, more = DungeonLoot.rows(boss(8), "MAGE", false, false)
    assert.are.equal(6, #rows)
    assert.are.equal(2, more)
    assert.are.equal(101, rows[1].drop.item)
    assert.is_false(rows[2].usable) -- plate for a mage: dimmed
    local all, none = DungeonLoot.rows(boss(8), "MAGE", false, true)
    assert.are.same({ 8, 0 }, { #all, none })
  end)

  it("hides what the class can't use with the switch, counting more after it", function()
    local rows, more = DungeonLoot.rows(boss(8), "MAGE", true, false)
    assert.are.same({ 4, 0 }, { #rows, more })
    for _, r in ipairs(rows) do assert.is_true(r.usable) end
  end)

  it("writes the chance", function()
    assert.are.equal("36%", DungeonLoot.chanceText(36))
    assert.are.equal("4%", DungeonLoot.chanceText(3.6))
    assert.are.equal("<1%", DungeonLoot.chanceText(0.4))
    assert.are.equal("", DungeonLoot.chanceText(nil))
  end)

  it("reads the loot file's bosses and skips broken entries", function()
    local data = { dungeons = { dm = {
      { id = 1, name = "Rhahk'Zor", drops = { { item = 5187, chance = 77 }, { chance = 3 }, "x" } },
      "broken",
      { id = 6, name = "Edwin VanCleef", final = true },
      { id = 7, name = "Cookie", optional = true, drops = {} },
    } } }
    local bosses = DungeonLoot.bosses(data, "dm")
    assert.are.equal(3, #bosses)
    assert.are.equal(1, #bosses[1].drops)
    assert.is_true(bosses[2].final)
    assert.is_true(bosses[3].optional)
    assert.are.same({}, DungeonLoot.bosses(data, "wc"))
    assert.are.same({}, DungeonLoot.bosses(nil, "dm"))
  end)

  it("says nobody knows a recipe and who could learn it", function()
    local drop = { item = 728, cls = 9, sub = 5, recipe = 2795 }
    local chars = {
      { name = "Lia", professions = { [185] = { name = "Cooking", rank = 150 } } },
      { name = "Ves", professions = { [185] = { name = "Cooking", rank = 75 } } },
      { name = "Bo" },
    }
    local s = DungeonLoot.recipeState(drop, chars)
    assert.is_false(s.known)
    assert.are.same({ "Lia (Cooking 150)", "Ves (Cooking 75)" }, s.canLearn)
    chars[3].recipes = { [2795] = 0 }
    assert.is_true(DungeonLoot.recipeState(drop, chars).known)
  end)

  it("finds when the final boss last died", function()
    local bosses = { { id = 1 }, { id = 6, final = true } }
    local kills = { { guid = "a", encounterID = 6, at = 100 }, { guid = "b", encounterID = 6, at = 300 },
                    { guid = "c", encounterID = 1, at = 900 } }
    assert.are.equal(300, DungeonLoot.lastCleared(bosses, kills).at)
    assert.is_nil(DungeonLoot.lastCleared({ { id = 1 } }, kills))
  end)

  it("ships a loot file in the contract's shape", function()
    local ns = {}
    helpers.loadAddonFile("Data/Loot.lua", ns)
    assert.is_table(ns.LootData)
    assert.is_string(ns.LootData.build)
    for id, bosses in pairs(ns.LootData.dungeons) do
      assert.is_string(id)
      local finals = 0
      for _, b in ipairs(bosses) do
        assert.is_number(b.id)
        assert.is_string(b.name)
        if b.final then finals = finals + 1 end
        for _, d in ipairs(b.drops) do
          assert.is_number(d.item)
          assert.is_number(d.chance)
          assert.is_number(d.cls)
          assert.is_number(d.sub)
        end
      end
      assert.are.equal(1, finals, id .. " has one final boss")
    end
  end)
end)
