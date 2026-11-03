local helpers = require("helpers")

describe("Missions: items (CF-75)", function()
  local ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Items.lua", ns)
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Items)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/items.json")
    assert.is_table(cases.cases)
  end)
end)
