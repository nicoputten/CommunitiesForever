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
    assert.are.same({ "b.avenge3", "b.flagged3h", "p.avenge", "p.boldQuest", "p.flag60", "p.flagHour", "p.flagUp",
                      "p.holdout", "p.homeGuard", "p.patrol", "p.revenge" }, ns.Missions.Battle.IDS)
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

  -- CF-121: Avenger (p.avenge, b.avenge3): a grouped friend's death to a player (FELL), then an own kill of that player
  -- within 10 minutes.
  describe("Avenger (CF-121)", function()
    local G, K = "Player-1-0000000A", "Player-2-0000000K"

    local function run(observations)
      local day = ns.Goals.newFacts()
      for _, obs in ipairs(observations) do ns.Goals.observe(day, obs) end
      local f = ns.Goals.progressFacts(day)
      return { ns.Doomsday.progress("p.avenge", f) }, { ns.Doomsday.progress("b.avenge3", f) }, day
    end

    local function fell(at, killer, name)
      return { kind = "battleFriendFell", killer = killer, name = name, at = at }
    end
    local function kill(at, victim, name, bg)
      return { kind = "battleVictim", guid = G, victim = victim, name = name, at = at, bg = bg }
    end

    it("avenges by the killer's GUID within 10 minutes, once per death; a battleground kill counts too", function()
      local day, week = run({ fell(1000, K, "Grim Tusk"), kill(1600, K, "Grim Tusk") })
      assert.are.same({ 1, 1, true }, day)
      assert.are.same({ 1, 3, false }, week)
      day = run({ fell(1000, K), kill(1200, K), kill(1300, K) })
      assert.are.same({ 1, 1, true }, day) -- the second kill has no death left to avenge
      assert.are.same({ 1, 1, true }, (run({ fell(1000, K), kill(1100, K, nil, true) })))
      local _, three = run({ fell(1000, K), kill(1001, K), fell(1002, K), kill(1003, K), fell(1004, K),
                             kill(1005, K) })
      assert.are.same({ 3, 3, true }, three)
    end)

    it("never avenges a kill too late, before the death, or of another player", function()
      assert.are.same({ 0, 1, false }, (run({ fell(1000, K), kill(1601, K) })))
      assert.are.same({ 0, 1, false }, (run({ kill(999, K), fell(1000, K) })))
      assert.are.same({ 0, 1, false }, (run({ fell(1000, K), kill(1100, "Player-2-OTHER") })))
      assert.are.same({ 0, 1, false },
        (run({ fell(1000, K, "Grim Tusk"), kill(1100, "Player-2-OTHER", "Grim Tusk") })))
      assert.are.same({ 0, 1, false }, (run({ fell(1000, K), kill(nil, K) }))) -- no kill time: unknown
    end)

    it("matches a killer known only by name, the whole name", function()
      assert.are.same({ 1, 1, true }, (run({ fell(1000, nil, "Grim Tusk"), kill(1100, K, "Grim Tusk") })))
      assert.are.same({ 0, 1, false }, (run({ fell(1000, nil, "Grim Tusk"), kill(1100, K, "Grim") })))
      assert.are.same({ 0, 1, false }, (run({ fell(1000, nil, "Grim Tusk"), kill(1100, K) })))
    end)

    it("drops a death without a player killer, and keeps at most 20, dropping old ones", function()
      local _, _, day = run({ fell(1000, "Creature-0-1-2-3"), fell(1000), fell(nil, K) })
      assert.is_true(day.battle == nil or #day.battle.fallen == 0)
      local many = {}
      for i = 1, 25 do many[#many + 1] = fell(1000 + i, "Player-2-" .. i) end
      _, _, day = run(many)
      assert.are.equal(20, #day.battle.fallen)
      assert.are.equal("Player-2-6", day.battle.fallen[1].killer)
      _, _, day = run({ fell(1000, K), fell(1700, "Player-2-NEW") })
      assert.are.same({ { killer = "Player-2-NEW", at = 1700 } }, day.battle.fallen)
    end)

    it("keeps revenge apart: your own killer is no friend's", function()
      local day = ns.Goals.newFacts()
      for _, obs in ipairs({ { kind = "battleDeath", guid = G, killer = K }, kill(1100, K) }) do
        ns.Goals.observe(day, obs)
      end
      assert.are.same({ 1, nil }, { day.battle.revenge, day.battle.avenge })
    end)
  end)
end)
