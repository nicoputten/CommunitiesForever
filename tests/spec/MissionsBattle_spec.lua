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

  it("registers p.homeGuard (CF-99) and the pool-4 PvP missions (CF-104), all in the catalogue", function()
    assert.are.same({ "b.flagged3h", "p.flagHour", "p.flagUp", "p.homeGuard", "p.revenge" }, ns.Missions.Battle.IDS)
    for _, id in ipairs(ns.Missions.Battle.IDS) do assert.is_table(ns.Doomsday.goal(id), id) end
    assert.are.same({ 3, 4 }, { ns.Doomsday.goal("p.homeGuard").since, ns.Doomsday.goal("p.homeGuard").retired })
    for _, id in ipairs({ "b.flagged3h", "p.flagHour", "p.flagUp", "p.revenge" }) do
      assert.are.equal(4, ns.Doomsday.goal(id).since, id)
    end
  end)

  it("tells a player's GUID", function()
    assert.is_true(ns.Missions.Battle.isPlayerGuid("Player-1-0000000A"))
    for _, v in ipairs({ "Creature-0-1-2-3-4-5", "", "player", 5 }) do
      assert.is_false(ns.Missions.Battle.isPlayerGuid(v), tostring(v))
    end
    assert.is_false(ns.Missions.Battle.isPlayerGuid(nil))
  end)

  it("reads facts of an earlier version that have only the zones (CF-104)", function()
    local day = ns.Goals.newFacts()
    day.battle = { zones = { Orgrimmar = "friendly" } }
    ns.Goals.observe(day, { kind = "battleFlag", guid = "Player-1-A", seconds = 600 })
    assert.are.same({ 10, 10, true }, { ns.Doomsday.progress("p.flagUp", ns.Goals.progressFacts(day)) })
    assert.are.equal("friendly", day.battle.zones.Orgrimmar)
    local old = ns.Goals.newFacts()
    old.battle = { zones = {} }
    for _, id in ipairs(ns.Missions.Battle.IDS) do
      assert.is_number((ns.Doomsday.progress(id, ns.Goals.progressFacts(old))), id)
    end
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
