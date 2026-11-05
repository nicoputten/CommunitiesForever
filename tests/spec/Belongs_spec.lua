local helpers = require("helpers")

-- CF-89: only people with a character in the selected community or guild take part.
describe("Belongs", function()
  local Belongs

  local ADA, BEN, CY = "Ada#1001", "Ben#1002", "Cy#1003"
  local ADA_MAIN, ADA_ALT = "Player-1-0000ADA1", "Player-1-0000ADA2"
  local BEN_MAIN, CY_MAIN = "Player-1-0000BEN1", "Player-1-0000CY01"
  local ROSTER = { [ADA_MAIN] = { name = "Ada Example", seenAt = 1 },
                   [BEN_MAIN] = { name = "Ben Example", seenAt = 1 } }

  before_each(function()
    Belongs = helpers.loadAddonFile("src/core/Belongs.lua", helpers.coreNs())
  end)

  describe("keys", function()
    it("is nil while the roster is not known", function()
      assert.is_nil(Belongs.keys(nil, {}, {}, {}, ADA))
      assert.is_nil(Belongs.is(nil, ADA))
    end)

    it("is only you without a community (empty roster)", function()
      local keys = Belongs.keys({}, { [CY_MAIN] = { battleTag = CY } }, { [CY] = { chars = { [CY_MAIN] = {} } } },
        { [CY_MAIN] = CY }, ADA)
      assert.are.same({ [ADA] = true }, keys)
      assert.is_false(Belongs.is(keys, CY))
    end)

    it("takes a friend in through a presence link of a member character, also while they play an alt", function()
      local keys = Belongs.keys(ROSTER, { [ADA_MAIN] = { battleTag = ADA }, [ADA_ALT] = { battleTag = ADA } }, {},
        { [ADA_ALT] = ADA })
      assert.is_true(Belongs.is(keys, ADA))
    end)

    it("takes a friend in through the member character they are on now", function()
      assert.is_true(Belongs.is(Belongs.keys(ROSTER, {}, {}, { [BEN_MAIN] = BEN }), BEN))
    end)

    it("takes a person in through their own record's characters, BattleTag or community key", function()
      local people = { [BEN] = { chars = { [BEN_MAIN] = {} } }, ["aid:aaaaaaaaaaaa"] = { chars = { [ADA_MAIN] = {} } } }
      local keys = Belongs.keys(ROSTER, {}, people, {})
      assert.is_true(Belongs.is(keys, BEN))
      assert.is_true(Belongs.is(keys, "aid:aaaaaaaaaaaa"))
    end)

    it("leaves out a friend whose characters are all outside the community", function()
      local keys = Belongs.keys(ROSTER, { [CY_MAIN] = { battleTag = CY } }, { [CY] = { chars = { [CY_MAIN] = {} } } },
        { [CY_MAIN] = CY })
      assert.is_false(Belongs.is(keys, CY))
      assert.is_false(Belongs.is(keys, nil))
    end)

    it("does not take a link to someone else's member character as yours", function()
      local keys = Belongs.keys(ROSTER, { [ADA_MAIN] = { battleTag = ADA }, [CY_MAIN] = { battleTag = CY } }, {}, {})
      assert.is_false(Belongs.is(keys, CY))
    end)

    it("copes with broken stored data", function()
      local keys = Belongs.keys(ROSTER, { [ADA_MAIN] = "x", [BEN_MAIN] = { battleTag = 5 } },
        { [CY] = "x", [BEN] = { chars = "x" } }, nil)
      assert.are.same({}, keys)
    end)
  end)

  describe("prunePresence", function()
    it("keeps member characters and the links of people who belong, drops the rest", function()
      local presence = { [ADA_MAIN] = { battleTag = ADA }, [ADA_ALT] = { battleTag = ADA },
                         [BEN_MAIN] = { battleTag = BEN }, [CY_MAIN] = { battleTag = CY }, broken = "x" }
      local removed = Belongs.prunePresence(presence, ROSTER, { [ADA] = true })
      assert.are.equal(2, removed)
      assert.are.same({ [ADA_MAIN] = { battleTag = ADA }, [ADA_ALT] = { battleTag = ADA },
                        [BEN_MAIN] = { battleTag = BEN } }, presence)
    end)

    it("does nothing while the roster is not known", function()
      local presence = { [CY_MAIN] = { battleTag = CY } }
      assert.are.equal(0, Belongs.prunePresence(presence, nil, nil))
      assert.are.equal(0, Belongs.prunePresence(presence, ROSTER, nil))
      assert.is_not_nil(presence[CY_MAIN])
    end)
  end)

  describe("prunePeople", function()
    it("keeps only people who belong", function()
      local people = { [ADA] = { version = 1 }, [CY] = { version = 2 }, ["aid:cccccccccccc"] = { version = 3 } }
      assert.are.equal(2, Belongs.prunePeople(people, { [ADA] = true }))
      assert.are.same({ [ADA] = { version = 1 } }, people)
    end)

    it("does nothing while the roster is not known", function()
      local people = { [CY] = { version = 2 } }
      assert.are.equal(0, Belongs.prunePeople(people, nil))
      assert.is_not_nil(people[CY])
    end)
  end)

  describe("roster", function()
    it("keeps name and the time seen per member, nothing else", function()
      assert.are.same({ [ADA_MAIN] = { name = "Ada Example", seenAt = 500 }, [BEN_MAIN] = { seenAt = 500 } },
        Belongs.roster({ [ADA_MAIN] = { name = "Ada Example", level = 20, zone = "Durotar", presence = 1 },
                         [BEN_MAIN] = { name = 5 }, [7] = { name = "Bad Key" } }, 500))
      assert.are.same({}, Belongs.roster(nil, 500))
    end)
  end)
end)
