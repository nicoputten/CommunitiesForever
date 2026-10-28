local helpers = require("helpers")

describe("Talents (CF-18)", function()
  local Talents

  -- The real Warrior layout from V29: x positions of all 52 nodes; ranks as in Nico's Arms build.
  local function warrior(ranksByX)
    local xs = {
      6820, 5620, 5620, 5620, 6220, 6820, 5020, 6220, 5620, 6220, 5620, 6220,   -- Fury
      1620, 2220, 2220, 1620, 2220, 1620, 1020, 2220, 1620, 2820, 1620, 1020,   -- Arms
      2220, 1620, 1020, 1020, 1620,
      5020, 9680, 10280, 10280, 10280, 9080, 9680, 9680, 10280, 9080, 10280,     -- Fury/Protection
      9080, 9680, 10880, 9080, 9080, 9680, 5620, 5020, 10880, 5620, 6220, 10280,
      10880, 9680, 9080,
    }
    local nodes = {}
    for _, x in ipairs(xs) do nodes[#nodes + 1] = { posX = x, ranks = 0 } end
    for _, spend in ipairs(ranksByX or {}) do
      table.insert(nodes, { posX = spend[1], ranks = spend[2] })
    end
    return nodes
  end

  before_each(function()
    Talents = helpers.loadAddonFile("src/core/Talents.lua", helpers.coreNs())
  end)

  describe("summarize", function()
    it("splits the Warrior tree into Arms, Fury and Protection", function()
      local trees, main = Talents.summarize(warrior({ { 1620, 2 }, { 2220, 3 }, { 1620, 4 }, { 1020, 2 },
                                                     { 2220, 3 }, { 1020, 3 } }), "WARRIOR")
      assert.are.same({ { name = "Arms", points = 17 }, { name = "Fury", points = 0 },
                        { name = "Protection", points = 0 } }, trees)
      assert.are.equal(1, main)
    end)

    it("counts points in every tree and picks the one with the most", function()
      local trees, main = Talents.summarize(warrior({ { 1620, 5 }, { 6220, 10 }, { 9680, 3 } }), "WARRIOR")
      assert.are.same({ 5, 10, 3 }, { trees[1].points, trees[2].points, trees[3].points })
      assert.are.equal(2, main)
    end)

    it("gives ties to the lower tree and no main tree without points", function()
      local _, main = Talents.summarize(warrior({ { 1620, 4 }, { 9680, 4 } }), "WARRIOR")
      assert.are.equal(1, main)
      local trees, none = Talents.summarize(warrior(), "WARRIOR")
      assert.are.equal(0, trees[1].points)
      assert.is_nil(none)
    end)

    it("uses the class's Vanilla tree names, or generic names for unknown classes", function()
      local trees = Talents.summarize(warrior(), "PALADIN")
      assert.are.same({ "Holy", "Protection", "Retribution" }, { trees[1].name, trees[2].name, trees[3].name })
      local generic = Talents.summarize(warrior(), "MONK")
      assert.are.equal("Tree 1", generic[1].name)
    end)

    it("returns nothing without usable talent data", function()
      assert.is_nil(Talents.summarize(nil, "WARRIOR"))
      assert.is_nil(Talents.summarize({}, "WARRIOR"))
      assert.is_nil(Talents.summarize({ { posX = 1, ranks = 1 }, { posX = 2, ranks = 0 } }, "WARRIOR"))
    end)
  end)

  describe("roles", function()
    it("guesses the role from class and main tree", function()
      assert.are.equal("tank", Talents.autoRole("WARRIOR", 3))
      assert.are.equal("dps", Talents.autoRole("WARRIOR", 1))
      assert.are.equal("heal", Talents.autoRole("PRIEST", 1))
      assert.are.equal("heal", Talents.autoRole("PRIEST", 2))
      assert.are.equal("dps", Talents.autoRole("PRIEST", 3))
      assert.are.equal("heal", Talents.autoRole("PALADIN", 1))
      assert.are.equal("tank", Talents.autoRole("PALADIN", 2))
      assert.are.equal("heal", Talents.autoRole("DRUID", 3))
      assert.are.equal("dps", Talents.autoRole("DRUID", 2)) -- Feral: override to tank
      assert.are.equal("heal", Talents.autoRole("SHAMAN", 3))
      assert.are.equal("dps", Talents.autoRole("MAGE", 3))
      assert.is_nil(Talents.autoRole("WARRIOR", nil))
    end)

    it("lets an override win over the guess", function()
      assert.are.equal("tank", Talents.role("DRUID", 2, "tank"))
      assert.are.equal("dps", Talents.role("DRUID", 2, nil))
      assert.are.equal("dps", Talents.role("DRUID", 2, "nonsense"))
    end)
  end)
end)
