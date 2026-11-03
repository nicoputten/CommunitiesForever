local helpers = require("helpers")

describe("Missions: world (CF-76)", function()
  local ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/World.lua", ns)
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.World)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/world.json")
    assert.is_table(cases.cases)
  end)
end)
