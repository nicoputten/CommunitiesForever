local helpers = require("helpers")

describe("Missions: fights (CF-80)", function()
  local ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Fights.lua", ns)
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Fights)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/fights.json")
    assert.is_table(cases.cases)
  end)

  -- CF-118: the PvP dailies of pool version 6.
  describe("pool version 6 (CF-118)", function()
    local T = 1794333600 -- 19:00 realm time (CET, offset 3600): a reset
    local SCHEDULE = { offset = 3600, reset = 68400 }

    -- Facts of one day from kills ({ kill fields..., extra = {...}, char }) and other observations.
    local function facts(kills, observations, ctx)
      local f = ns.Goals.newFacts()
      for i, k in ipairs(kills or {}) do
        local kill = {}
        for key, v in pairs(k) do
          if key ~= "extra" and key ~= "char" then kill[key] = v end
        end
        kill.t = kill.t or (T + i)
        kill.name = kill.name or ("Victim " .. i)
        ns.Goals.observe(f, { kind = "kill", kill = kill, char = k.char or "Player-1", extra = k.extra })
      end
      for _, obs in ipairs(observations or {}) do ns.Goals.observe(f, obs) end
      ctx = ctx or {}
      ctx.schedule = ctx.schedule or SCHEDULE
      if ctx.zone then f.zone = ctx.zone end
      return ns.Goals.progressFacts(f, ctx)
    end

    local function done(id, ...)
      local _, _, d = ns.Doomsday.progress(id, facts(...))
      return d
    end

    it("registers a progress for every easy PvP mission of pool version 6, none for the check ones", function()
      helpers.loadAddonFile("src/core/missions/Battle.lua", ns)
      local empty = ns.Goals.progressFacts(ns.Goals.newFacts())
      for _, slot in ipairs({ "skirmish", "duel" }) do
        for _, id in ipairs(ns.Doomsday.pool(slot, 6)) do
          assert.is_number((ns.Doomsday.progress(id, empty)), id)
        end
      end
      for _, g in ipairs(ns.Doomsday.GOALS) do
        if g.check then assert.is_nil((ns.Doomsday.progress(g.id, empty)), g.id) end
      end
    end)

    it("counts honorable kills and their levels", function()
      local three = { {}, {}, {} }
      assert.is_true(done("p.hk3", three))
      assert.is_false(done("p.hk3", { {}, {} }))
      assert.is_false(done("p.kills10", three))
      assert.is_true(done("p.upLevel", { { lvl = 21, myLvl = 20 } }))
      assert.is_true(done("p.upLevel", { { lvl = -1, myLvl = 20 } })) -- a skull
      assert.is_false(done("p.upLevel", { { lvl = 20, myLvl = 20 } }))
      assert.is_true(done("p.punchUp5", { { lvl = 25, myLvl = 20 } }))
      assert.is_false(done("p.punchUp5", { { lvl = 24, myLvl = 20 } }))
      assert.is_true(done("p.fairFight", { { lvl = 20, myLvl = 20 } }))
      assert.is_false(done("p.fairFight", { { myLvl = 20 } })) -- level unknown
    end)

    it("knows the victims' classes and races, by token or id", function()
      assert.is_true(done("p.mirror", { { class = "MAGE", extra = { myClass = "MAGE" } } }))
      assert.is_false(done("p.mirror", { { class = "ROGUE", extra = { myClass = "MAGE" } } }))
      assert.is_true(done("p.races3", { { race = "Orc" }, { raceId = 6 }, { race = "Troll" } }))
      assert.is_false(done("p.races3", { { race = "Orc" }, { race = "Orc" }, { raceId = 8 } }))
      assert.is_true(done("p.healerDown", { { classId = 7 } }))
      assert.is_true(done("p.healerDown", { { class = "PRIEST" } }))
      assert.is_false(done("p.healerDown", { { class = "MAGE", classId = 8 } }))
    end)

    it("finds 2 kills of one character within 30 seconds", function()
      assert.is_true(done("p.double30", { { t = T }, { t = T + 30 } }))
      assert.is_false(done("p.double30", { { t = T }, { t = T + 31 } }))
      assert.is_false(done("p.double30", { { t = T, char = "Player-1" }, { t = T + 5, char = "Player-2" } }))
    end)

    it("knows today's quarry in part and the rare targets of the schedule", function()
      local ctx = function() return { hunts = { { race = 4, class = 11 } }, rareTargets = { ["95:3"] = true } } end
      assert.is_true(done("p.closeEnough", { { race = "NightElf", class = "PRIEST" } }, nil, ctx()))
      assert.is_false(done("p.closeEnough", { { race = "Human", class = "DRUID" } }, nil, ctx()))
      assert.is_true(done("p.halfHunt", { { raceId = 7, classId = 11 } }, nil, ctx()))
      assert.is_true(done("p.rareQuarry", { { raceId = 95, classId = 3 } }, nil, ctx()))
      assert.is_false(done("p.rareQuarry", { { raceId = 95, classId = 4 } }, nil, ctx()))
      assert.is_false(done("p.rareQuarry", { { raceId = 95, classId = 3 } }))
      assert.are.equal("4:11", ns.Missions.Fights.targetKey({ race = "NightElf", class = "DRUID" }))
      assert.is_nil(ns.Missions.Fights.targetKey({ race = "Unknown", class = "DRUID" }))
    end)

    it("knows contested and enemy land, roaming and the zone of the day", function()
      assert.is_true(done("p.contestedHk", { { zone = "Stranglethorn Vale" } }))
      assert.is_false(done("p.contestedHk", { { zone = "Durotar" } }))
      assert.is_true(done("p.enemyLand", { { zone = "Durotar", extra = { myFaction = "Alliance" } } }))
      assert.is_false(done("p.enemyLand", { { zone = "Durotar", extra = { myFaction = "Horde" } } }))
      assert.is_false(done("p.enemyLand", { { zone = "Ashenvale", extra = { myFaction = "Alliance" } } }))
      assert.is_true(done("p.zones3", { { zone = "A" }, { zone = "B" }, { zone = "C" } }))
      assert.is_false(done("p.zones3", { { zone = "A" }, { zone = "B" }, { zone = "B" } }))
      assert.is_true(done("p.zoneDay", { { zone = "Ashenvale" } }, nil, { zone = "Ashenvale" }))
      assert.is_false(done("p.zoneDay", { { zone = "Ashenvale" } }, nil, { zone = "Felwood" }))
    end)

    it("knows an enemy capital or town entered, by the character's faction", function()
      local function visit(obs) return done("p.tourist", nil, { obs }), done("p.raidParty", nil, { obs }) end
      local function place(faction, zone, subzone)
        return { kind = "fightPlace", faction = faction, zone = zone, subzone = subzone }
      end
      assert.are.same({ true, false }, { visit(place("Horde", "Stormwind City", "Trade District")) })
      assert.are.same({ false, false }, { visit(place("Alliance", "Stormwind City")) })
      assert.are.same({ false, true }, { visit(place("Alliance", "The Barrens", "The Crossroads")) })
      assert.are.same({ false, false }, { visit(place(nil, "Orgrimmar", "The Crossroads")) })
    end)

    it("knows friends in the group at the kill, and their own HKs that day", function()
      local duo = { { extra = { friends = { "Ada#1001" } } } }
      assert.is_true(done("p.duoKill", duo))
      assert.is_false(done("p.duoKill", { { extra = { friends = {} } } }))
      assert.is_false(done("p.trioKills", duo))
      assert.is_true(done("p.trioKills", { { extra = { friends = { "Ada#1001", "Bob#1002" } } } }))
      local trio = { { extra = { friends = { "Ada#1001", "Bob#1002" } } } }
      assert.is_true(done("p.sharedGlory", trio, nil, { friendKills = { ["Ada#1001"] = true, ["Bob#1002"] = true } }))
      assert.is_false(done("p.sharedGlory", trio, nil, { friendKills = { ["Ada#1001"] = true } }))
      assert.is_false(done("p.sharedGlory", { {} }, nil, { friendKills = { ["Ada#1001"] = true } }))
    end)

    it("knows the realm hour, the character's level and the time since login", function()
      -- T is 19:00 realm time; 12 h later is 07:00, 5 h later 00:00, 10 h later 05:00.
      assert.is_false(done("p.earlyBlood", { { t = T } }))
      assert.is_true(done("p.earlyBlood", { { t = T + 12 * 3600 } }))
      assert.is_true(done("p.midnightRaid", { { t = T + 5 * 3600 } }))
      assert.is_false(done("p.midnightRaid", { { t = T + 10 * 3600 } }))
      assert.is_true(done("p.youngBlood", { { myLvl = 29 } }))
      assert.is_false(done("p.youngBlood", { { myLvl = 30 } }))
      assert.is_true(done("p.hotStart", { { extra = { sinceLogin = 600 } } }))
      assert.is_false(done("p.hotStart", { { extra = { sinceLogin = 601 } } }))
      assert.is_true(done("p.twoBlades", { { char = "Player-1" }, { char = "Player-2" } }))
      assert.is_false(done("p.twoBlades", { { char = "Player-1" }, { char = "Player-1" } }))
    end)

    it("knows the Duel slot's missions from the duels of the day", function()
      local function duel(fields)
        local obs = { kind = "fightDuel", t = T, won = true }
        for k, v in pairs(fields or {}) do obs[k] = v end
        return obs
      end
      assert.is_true(done("p.duelFirst", nil, { duel({ won = false, friend = "Ada#1001" }) }))
      assert.is_false(done("p.duelFirst", nil, { duel() }))
      assert.is_true(done("p.duelWin", nil, { duel() }))
      assert.is_false(done("p.duelWin", nil, { duel({ won = false }) }))
      assert.is_false(done("p.duel3", nil, { duel(), duel(), duel({ won = false }) }))
      assert.is_true(done("p.duel3", nil, { duel(), duel(), duel() }))
      assert.is_true(done("p.spar", nil, { duel({ won = false, friend = "Ada#1001" }) }))
      assert.is_true(done("p.duelUp", nil, { duel({ lvl = 21, myLvl = 20 }) }))
      assert.is_false(done("p.duelUp", nil, { duel({ lvl = 21 }) }))
      assert.is_true(done("p.styles3", nil, { duel({ class = "MAGE" }), duel({ class = "ROGUE", won = false }),
                                              duel({ class = "DRUID" }) }))
      assert.is_false(done("p.styles3", nil, { duel({ class = "MAGE" }), duel({ class = "MAGE" }), duel() }))
      assert.is_true(done("p.cityDuel", nil, { duel({ zone = "Orgrimmar" }) }))
      assert.is_false(done("p.cityDuel", nil, { duel({ zone = "Orgrimmar", won = false }) }))
      assert.is_true(done("p.bothWays", { {} }, { duel() }))
      assert.is_false(done("p.bothWays", nil, { duel() }))
      assert.is_false(done("p.duelWin", nil, { { kind = "fightDuel", t = T } })) -- no result: no duel
    end)
  end)
end)
