local helpers = require("helpers")

describe("Missions: battle (CF-81)", function()
  local ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Battle.lua", ns)
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Battle)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/battle.json")
    assert.is_true(#cases.cases > 0)
    for _, case in ipairs(cases.cases) do
      local day = ns.Goals.newFacts()
      for _, obs in ipairs(case.observations) do ns.Goals.observe(day, obs) end
      for id, expected in pairs(case.progress) do
        local value, target, done = ns.Doomsday.progress(id, ns.Goals.progressFacts(day))
        assert.are.same(expected, { value, target, done }, case.name .. ": " .. id)
      end
    end
  end)

  it("registers p.homeGuard only (CF-99), which is in the catalogue", function()
    assert.are.same({ "p.homeGuard" }, ns.Missions.Battle.IDS)
    assert.is_table(ns.Doomsday.goal("p.homeGuard"))
  end)

  it("keeps at most MAX_ZONES zones, and a kept zone takes its latest type", function()
    local day = ns.Goals.newFacts()
    for i = 1, ns.Missions.Battle.MAX_ZONES + 5 do
      ns.Goals.observe(day, { kind = "battleZone", zone = "Zone " .. i, pvpType = "contested" })
    end
    ns.Goals.observe(day, { kind = "battleZone", zone = "Zone 1", pvpType = "friendly" })
    local n = 0
    for _ in pairs(day.battle.zones) do n = n + 1 end
    assert.are.equal(ns.Missions.Battle.MAX_ZONES, n)
    assert.are.equal("friendly", day.battle.zones["Zone 1"])
    assert.is_nil(day.battle.zones["Zone 55"])
  end)
end)
