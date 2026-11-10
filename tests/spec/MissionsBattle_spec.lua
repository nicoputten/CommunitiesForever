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
    assert.are.same({ "b.flagged3h", "p.boldQuest", "p.flag60", "p.flagHour", "p.flagUp", "p.holdout", "p.homeGuard",
                      "p.patrol", "p.revenge" }, ns.Missions.Battle.IDS)
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

  -- CF-118: the flag missions of pool version 6.
  describe("pool version 6 (CF-118)", function()
    local G = "Player-1-0000000A"

    local function progress(id, observations, extra)
      local day = ns.Goals.newFacts()
      for _, obs in ipairs(observations) do ns.Goals.observe(day, obs) end
      for k, v in pairs(extra or {}) do day[k] = v end
      local f = ns.Goals.progressFacts(day, { zone = day.zone })
      return { ns.Doomsday.progress(id, f) }
    end

    local function flag(seconds, fields)
      local obs = { kind = "battleFlag", guid = G, seconds = seconds }
      for k, v in pairs(fields or {}) do obs[k] = v end
      return obs
    end

    it("counts an hour flagged; a death doesn't end it, the flag dropping does", function()
      local hour = {}
      for _ = 1, 10 do hour[#hour + 1] = flag(360) end
      table.insert(hour, 5, { kind = "battleDeath", guid = G })
      assert.are.same({ 60, 60, true }, progress("p.flag60", hour))
      local dropped = { flag(600), flag(600), flag(600, { on = false }), flag(600), flag(600) }
      assert.are.same({ 30, 60, false }, progress("p.flag60", dropped))
    end)

    it("counts the minutes flagged in contested zones, with a quest handed in in one", function()
      local twenty = { flag(600, { zone = "Ashenvale" }), flag(600, { zone = "Desolace" }) }
      assert.are.same({ 19, 20, false }, progress("p.boldQuest", twenty))
      twenty[#twenty + 1] = { kind = "quest", zone = "Ashenvale" }
      assert.are.same({ 20, 20, true }, progress("p.boldQuest", twenty))
      assert.are.same({ 10, 20, false }, progress("p.boldQuest", { flag(600, { zone = "Durotar" }),
        flag(600, { zone = "Ashenvale" }), { kind = "quest", zone = "Ashenvale" } }))
    end)

    it("counts the minutes flagged in the zone of the day and with 2 friends in the group", function()
      assert.are.same({ 10, 10, true }, progress("p.holdout", { flag(600, { zone = "Felwood" }) },
        { zone = "Felwood" }))
      assert.are.same({ 0, 10, false }, progress("p.holdout", { flag(600, { zone = "Azshara" }) },
        { zone = "Felwood" }))
      assert.are.same({ 10, 20, false },
        progress("p.patrol", { flag(600, { friends = 2 }), flag(600, { friends = 1 }) }))
      assert.are.same({ 20, 20, true },
        progress("p.patrol", { flag(600, { friends = 2 }), flag(600, { friends = 3 }) }))
    end)
  end)
end)
