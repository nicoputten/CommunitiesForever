local helpers = require("helpers")

describe("Describe", function()
  local Describe

  before_each(function()
    Describe = helpers.loadAddonFile("src/core/Describe.lua", {})
  end)

  describe("selfRecord", function()
    it("prints header, characters sorted by name, professions sorted by skillLine", function()
      local record = {
        battleTag = "Vestras#2858",
        version = 5000,
        chars = {
          ["Player-1-B"] = { name = "Zed Alt", classFile = "MAGE", level = 5, raceID = 5, faction = "Horde",
                             realm = "R", updatedAt = 4000, professions = {} },
          ["Player-1-A"] = { name = "Ves Doombringer", classFile = "PALADIN", level = 11, ilvl = 1, raceID = 6,
                             faction = "Horde", realm = "Classic Beta PvP", updatedAt = 4990,
                             professions = {
                               [186] = { name = "Mining", rank = 64, max = 150 },
                               [129] = { name = "First Aid", rank = 1, max = 75 },
                             } },
        },
      }
      assert.are.same({
        "BattleTag Vestras#2858, version 5000, 2 character(s)",
        "Ves Doombringer: PALADIN level 11, ilvl 1, race 6, Horde, Classic Beta PvP, updated 10s ago (4990)",
        "  First Aid 1/75 [129], Mining 64/150 [186]",
        "Zed Alt: MAGE level 5, ilvl nil, race 5, Horde, R, updated 1000s ago (4000)",
        "  no professions",
      }, Describe.selfRecord(record, 5000))
    end)

    it("handles an empty record", function()
      assert.are.same({ "BattleTag nil, version 0, 0 character(s)" },
        Describe.selfRecord({ version = 0, chars = {} }, 5000))
    end)

    it("prints never for a missing updatedAt", function()
      local lines = Describe.selfRecord({ version = 1, chars = { g = { name = "X" } } }, 5000)
      assert.matches("updated never (nil)", lines[2], 1, true)
    end)
  end)
end)
