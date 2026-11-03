local helpers = require("helpers")

describe("Missions: records (CF-72)", function()
  local ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Records.lua", ns)
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Records)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/records.json")
    assert.is_table(cases.cases)
  end)
end)
