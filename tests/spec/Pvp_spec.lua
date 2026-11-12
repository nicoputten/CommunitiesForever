local helpers = require("helpers")

describe("Pvp (CF-52)", function()
  local Pvp
  local FORMATS = { knockout = "%1$s has defeated %2$s in a duel", retreat = "%2$s has fled from %1$s in a duel" }
  local ME = "Ada Example"

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    Pvp = helpers.loadAddonFile("src/core/Pvp.lua", ns)
  end)

  describe("death cause", function()
    it("names environmental damage", function()
      for env, cause in pairs({ Falling = "fall", FIRE = "fire", Lava = "lava", Drowning = "drown",
                                Fatigue = "fatigue", Slime = "other", Unknown = "other" }) do
        assert.are.same({ kind = cause, at = 5 }, Pvp.damage("ENVIRONMENTAL_DAMAGE", env, nil, nil, 5))
      end
    end)

    it("tells players (and their pets) from creatures by the source flags, else the GUID", function()
      assert.are.equal("player", Pvp.damage("SPELL_DAMAGE", nil, 0x0548, nil, 1).kind)    -- hostile player
      assert.are.equal("player", Pvp.damage("SWING_DAMAGE", nil, 0x1148, nil, 1).kind)    -- a player's pet
      assert.are.equal("creature", Pvp.damage("RANGE_DAMAGE", nil, 0x0a48, nil, 1).kind)  -- an NPC
      assert.are.equal("player", Pvp.damage("SWING_DAMAGE", nil, nil, "Player-1-AB", 1).kind)
      assert.are.equal("creature", Pvp.damage("SWING_DAMAGE", nil, nil, "Creature-0-1", 1).kind)
      assert.is_nil(Pvp.damage("SPELL_HEAL", nil, 0x0548, nil, 1))
      assert.is_nil(Pvp.damage(nil))
    end)

    it("takes the last damage within the window, then a mirror timer, else other", function()
      assert.are.equal("fall", Pvp.deathCause({ kind = "fall", at = 95 }, {}, 100))
      assert.are.equal("other", Pvp.deathCause({ kind = "fall", at = 80 }, {}, 100))
      assert.are.equal("drown", Pvp.deathCause(nil, { BREATH = { startedAt = 40 } }, 100))
      assert.are.equal("fatigue", Pvp.deathCause(nil, { EXHAUSTION = { startedAt = 40, stoppedAt = 98 } }, 100))
      assert.are.equal("other", Pvp.deathCause(nil, { BREATH = { startedAt = 40, stoppedAt = 60 } }, 100))
      assert.are.equal("other", Pvp.deathCause(nil, { FEIGNDEATH = { startedAt = 99 } }, 100))
      assert.are.equal("creature", Pvp.deathCause({ kind = "creature", at = 99 }, { BREATH = { startedAt = 1 } }, 100))
      assert.are.equal("other", Pvp.deathCause(nil, nil, 100))
    end)
  end)

  describe("duels", function()
    it("reads a win and a loss by knockout or retreat, with the opponent's full name", function()
      assert.are.same({ won = true, vs = "Bob Example" },
        Pvp.duel("Ada Example has defeated Bob Example in a duel", FORMATS, ME))
      assert.are.same({ won = false, vs = "Bob Example" },
        Pvp.duel("Bob Example has defeated Ada Example in a duel", FORMATS, ME))
      assert.are.same({ won = false, vs = "Bob Example" },
        Pvp.duel("Ada Example has fled from Bob Example in a duel", FORMATS, ME))
      assert.are.same({ won = true, vs = "Bob Example" },
        Pvp.duel("Bob Example has fled from Ada Example in a duel", FORMATS, ME))
    end)

    it("ignores other people's duels and other messages", function()
      assert.is_nil(Pvp.duel("Bob Example has defeated Cy Example in a duel", FORMATS, ME))
      assert.is_nil(Pvp.duel("Ada Example has come online.", FORMATS, ME))
      assert.is_nil(Pvp.duel("Ada Example has defeated Bob Example in a duel", {}, ME))
      assert.is_nil(Pvp.duel("Ada Example has defeated Bob Example in a duel", FORMATS, nil))
    end)
  end)

  describe("counters", function()
    it("builds the PvP data, keeping stored values the game does not give", function()
      local stored = { hk = 10, rank = 2, rankName = "Grunt", weekKills = 3, weekHonor = 40, deaths = 7,
                       duelsWon = 1, duelsLost = 2 }
      assert.are.same({ hk = 12, rank = 2, rankName = "Grunt", weekKills = 5, weekHonor = 60, deaths = 7,
                        duelsWon = 1, duelsLost = 2 },
        Pvp.build({ hk = 12, rank = 2, rankName = "Grunt", weekKills = 5, weekHonor = 60 }, stored))
      assert.are.same(stored, Pvp.build({}, stored))
      assert.is_nil(Pvp.build({}, nil))
    end)

    it("takes the game's death statistic when higher, caps the rank, drops a name for rank 0", function()
      assert.are.equal(30, Pvp.build({ deaths = 30 }, { deaths = 7 }).deaths)
      assert.are.equal(7, Pvp.build({ deaths = 3 }, { deaths = 7 }).deaths)
      assert.are.same({ rank = 14 }, Pvp.build({ rank = 20 }))
      assert.are.same({ rank = 0 }, Pvp.build({ rank = 0, rankName = "Nothing" }))
      assert.is_nil(Pvp.build({ hk = -1, weekHonor = 0 / 0 }))
    end)

    it("counts new kills between two lifetime counts", function()
      assert.are.equal(2, Pvp.newKills(10, 12))
      assert.are.equal(0, Pvp.newKills(nil, 12))
      assert.are.equal(0, Pvp.newKills(12, 10))
      assert.are.equal(Pvp.MAX_KILLS_PER_CHANGE, Pvp.newKills(0, 500))
    end)

    it("counts deaths and duels", function()
      local pvp = {}
      Pvp.count(pvp, { kind = "death" })
      Pvp.count(pvp, { kind = "death" }, 1) -- the statistic has not counted this one yet
      assert.are.equal(2, pvp.deaths)
      Pvp.count(pvp, { kind = "death" }, 40) -- the addon came later
      assert.are.equal(40, pvp.deaths)
      Pvp.count(pvp, { kind = "duel", won = true })
      Pvp.count(pvp, { kind = "duel", won = false })
      Pvp.count(pvp, { kind = "duel", won = false })
      assert.are.same({ 1, 2 }, { pvp.duelsWon, pvp.duelsLost })
    end)
  end)

  describe("raw kills (CF-55b)", function()
    local HONOR = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"

    it("remembers enemy players for 10 minutes, at most 200", function()
      local cache = {}
      Pvp.remember(cache, "Grim Tusk", { lvl = 30, class = "WARRIOR", race = "Orc", rank = 2, extra = 1 }, 100)
      assert.are.same({ lvl = 30, class = "WARRIOR", race = "Orc", rank = 2, at = 100 },
        Pvp.recall(cache, "Grim Tusk", 700))
      assert.is_nil(Pvp.recall(cache, "Grim Tusk", 701))
      assert.is_nil(Pvp.recall(cache, nil, 100))
      for i = 1, 205 do Pvp.remember(cache, "P" .. i, {}, 200 + i) end
      local size = 0
      for _ in pairs(cache) do size = size + 1 end
      assert.are.equal(200, size)
      assert.is_nil(cache["Grim Tusk"]) -- the oldest went first
      Pvp.remember(cache, nil, {}, 1)
      Pvp.remember(cache, "", {}, 1)
      assert.is_nil(cache[""])
    end)

    it("reads the victim and rank of an honor message", function()
      local ranks = { Grunt = 2, ["Senior Sergeant"] = 4 }
      assert.are.same({ "Grim Tusk", 2 },
        { Pvp.victim("Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)", HONOR, ranks) })
      assert.are.same({ "Grim Tusk" },
        { Pvp.victim("Grim Tusk dies, honorable kill Rank: None (Estimated Honor Points: 12)", HONOR, ranks) })
      assert.is_nil(Pvp.victim("You have been awarded 50 honor points.", HONOR, ranks))
      assert.is_nil(Pvp.victim("Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)", nil, ranks))
    end)

    it("tries each honor format in order, the variant without a rank gives no rank (CF-101)", function()
      local ranks = { Grunt = 2 }
      local forever = { "%s dies (Honorable Kill: %s). You gain %d Honor.",
                        "%s dies (Honorable Kill). You gain %d Honor." }
      assert.are.same({ "Ann Example" },
        { Pvp.victim("Ann Example dies (Honorable Kill). You gain 12 Honor.", forever, ranks) })
      assert.are.same({ "Grim Tusk", 2 },
        { Pvp.victim("Grim Tusk dies (Honorable Kill: Grunt). You gain 12 Honor.", forever, ranks) })
      local args, format = Pvp.honorArgs("Grim Tusk dies (Honorable Kill). You gain 12 Honor.", forever)
      assert.are.same({ "Grim Tusk", "12" }, args)
      assert.are.equal(forever[2], format)
      assert.is_nil(Pvp.honorArgs("You have been awarded 50 honor points.", forever))
      assert.is_nil(Pvp.honorArgs("Grim Tusk dies (Honorable Kill). You gain 12 Honor.", {}))
    end)

    it("builds a kill entry from the kill and what was seen of the victim", function()
      assert.are.same({ t = 5, zone = "Ashenvale", name = "Grim Tusk", lvl = -1, myLvl = 30, class = "ROGUE",
                        race = "Troll", rank = 3, solo = true },
        Pvp.killEntry({ t = 5, zone = "Ashenvale", name = "Grim Tusk", myLvl = 30, solo = true, bg = false },
          { lvl = -1, class = "ROGUE", race = "Troll", rank = 3 }))
      assert.are.equal(1, Pvp.killEntry({ rank = 1 }, { rank = 3 }).rank) -- the honor message wins
      assert.are.same({ t = 5, bg = true }, Pvp.killEntry({ t = 5, bg = true }))
    end)
  end)

  describe("the victim at the kill (CF-110)", function()
    local function look(guid, source, dead, extra)
      local l = { guid = guid, name = "Name " .. guid, enemy = true, dead = dead, lvl = 30, class = "ROGUE",
                  race = "Troll", source = source }
      for k, v in pairs(extra or {}) do l[k] = v end
      return l
    end

    local function seen(alive, guids, at)
      for _, guid in ipairs(guids) do Pvp.seeAlive(alive, look(guid, "target", false), at) end
    end

    it("picks the target that is dead now and was seen alive just before", function()
      local alive = {}
      seen(alive, { "Player-1-A" }, 100)
      assert.are.same({ { name = "Name Player-1-A", lvl = 30, class = "ROGUE", race = "Troll", source = "target",
                          guid = "Player-1-A", path = "dead" } },
        Pvp.pickVictims({ look("Player-1-A", "target", true) }, alive, 104, 1))
    end)

    it("prefers target over mouseover over nameplate, then the one seen alive last", function()
      local alive = {}
      seen(alive, { "N1", "N2", "M" }, 100)
      seen(alive, { "T" }, 99)
      local looks = { look("N1", "nameplate", true), look("M", "mouseover", true), look("T", "target", true),
                      look("N2", "nameplate", true) }
      Pvp.seeAlive(alive, look("N2", "nameplate", false), 101)
      local picked = Pvp.pickVictims(looks, alive, 103, 4)
      assert.are.same({ "target", "mouseover", "nameplate", "nameplate" },
        { picked[1].source, picked[2].source, picked[3].source, picked[4].source })
      assert.are.same({ "Name T", "Name M", "Name N2", "Name N1" },
        { picked[1].name, picked[2].name, picked[3].name, picked[4].name })
      assert.are.equal(1, #Pvp.pickVictims(looks, alive, 103)) -- one kill by default
      assert.are.equal("Name T", Pvp.pickVictims(looks, alive, 103, 2)[1].name)
    end)

    it("takes one player once, under their best source", function()
      local alive = {}
      seen(alive, { "A" }, 100)
      local picked = Pvp.pickVictims({ look("A", "nameplate", true), look("A", "target", true) }, alive, 101, 3)
      assert.are.equal(1, #picked)
      assert.are.equal("target", picked[1].source)
    end)

    it("picks nobody without a fitting player: none, alive, stale, never seen alive, unknown death", function()
      local alive = {}
      seen(alive, { "A", "B" }, 100)
      assert.are.same({}, Pvp.pickVictims({}, alive, 101, 1))
      assert.are.same({}, Pvp.pickVictims({ look("A", "target", false) }, alive, 101, 1))  -- still alive
      assert.are.same({}, Pvp.pickVictims({ look("A", "target", true) }, alive, 106, 1))   -- stale: 6 s
      assert.are.equal(1, #Pvp.pickVictims({ look("A", "target", true) }, alive, 105, 1))  -- 5 s still counts
      assert.are.same({}, Pvp.pickVictims({ look("C", "target", true) }, alive, 101, 1))   -- never seen alive
      assert.are.same({}, Pvp.pickVictims({ look("A", "target", nil) }, alive, 101, 1))    -- UnitIsDead unknown
      assert.are.same({}, Pvp.pickVictims({ look("A", "focus", true) }, alive, 101, 1))    -- not a victim source
      assert.are.same({}, Pvp.pickVictims(nil, alive, 101, 1))
      assert.are.same({}, Pvp.pickVictims({ look("A", "target", true) }, nil, 101, 1))
    end)

    it("ignores a friendly player", function()
      local alive = {}
      Pvp.seeAlive(alive, look("F", "target", false, { enemy = false }), 100)
      assert.is_nil(alive.F)
      seen(alive, { "F" }, 100)
      assert.are.same({}, Pvp.pickVictims({ look("F", "target", true, { enemy = false }) }, alive, 101, 1))
      assert.are.same({}, Pvp.pickVictims({ look("F", "target", true, { enemy = 1 }) }, alive, 101, 1))
    end)

    it("ignores secret values (nil from the adapter): no GUID, no death; a hidden field stays empty", function()
      local alive = {}
      Pvp.seeAlive(alive, look("A", "target", false, { guid = false }), 100)
      Pvp.seeAlive(alive, { name = "No Guid", enemy = true, dead = false }, 100)
      assert.is_nil(next(alive))
      seen(alive, { "A" }, 100)
      assert.are.same({}, Pvp.pickVictims({ { name = "Name A", enemy = true, dead = true, source = "target" } },
        alive, 101, 1))
      local picked = Pvp.pickVictims({ look("A", "target", true, { class = false, race = nil, lvl = "30" }) },
        alive, 101, 1)[1]
      assert.are.equal("ROGUE", picked.class) -- from when it was seen alive
      assert.are.equal("Troll", picked.race)
      assert.are.equal(30, picked.lvl)
      local bare = {}
      Pvp.seeAlive(bare, { guid = "B", enemy = true, dead = false }, 100)
      assert.are.same({ source = "target", guid = "B", path = "dead" }, Pvp.pickVictims({ { guid = "B", enemy = true,
        dead = true,
        source = "target", name = "" } }, bare, 101, 1)[1])
    end)

    it("keeps a skull's level -1 and remembers at most 200 players", function()
      local alive = {}
      Pvp.seeAlive(alive, look("S", "target", false, { lvl = -1 }), 100)
      assert.are.equal(-1, Pvp.pickVictims({ look("S", "target", true, { lvl = -1 }) }, alive, 100, 1)[1].lvl)
      for i = 1, 205 do Pvp.seeAlive(alive, look("P" .. i, "nameplate", false), 200 + i) end
      local size = 0
      for _ in pairs(alive) do size = size + 1 end
      assert.are.equal(200, size)
      assert.is_nil(alive.S)
    end)
  end)

  -- CF-117: the victim is often not dead yet at the counter rise (bug 13), so the rise remembers the candidates and a
  -- re-check Pvp.RECHECK_DELAY later picks.
  describe("the victim after a re-check (CF-117)", function()
    local function look(guid, source, dead, extra)
      local l = { guid = guid, name = "Name " .. guid, enemy = true, dead = dead, lvl = 30, class = "ROGUE",
                  race = "Troll", source = source }
      for k, v in pairs(extra or {}) do l[k] = v end
      return l
    end

    it("picks a target alive at the rise and dead by the re-check: dead after the delay", function()
      local alive = {}
      local pending = Pvp.killCandidates({ look("A", "target", false) }, alive, 100)
      assert.are.same({}, Pvp.resolveVictims(pending, 1)) -- not dead yet: nothing at once
      Pvp.observe(pending, { look("A", "target", true) }, 101, true)
      local picked = Pvp.resolveVictims(pending, 1)
      assert.are.same({ { name = "Name A", lvl = 30, class = "ROGUE", race = "Troll", source = "target", guid = "A",
                          path = "later" } }, picked)
    end)

    it("keeps a death seen between the rise and the re-check (the ticker), wherever the player is then", function()
      local pending = Pvp.killCandidates({ look("A", "target", false) }, {}, 100)
      Pvp.observe(pending, { look("A", "unit", true) }, 100.5)        -- a unit event saw them die
      Pvp.observe(pending, {}, 101, true)                             -- target gone by the re-check
      assert.are.equal("later", Pvp.resolveVictims(pending, 1)[1].path)
    end)

    it("picks one already dead at the rise first: dead at once", function()
      local alive = {}
      Pvp.seeAlive(alive, look("A", "target", false), 98)
      local pending = Pvp.killCandidates({ look("A", "target", true), look("B", "nameplate", false) }, alive, 100)
      Pvp.observe(pending, { look("B", "nameplate", true) }, 101, true)
      local picked = Pvp.resolveVictims(pending, 2)
      assert.are.same({ "A", "B" }, { picked[1].guid, picked[2].guid })
      assert.are.same({ "dead", "later" }, { picked[1].path, picked[2].path })
    end)

    -- CF-120: no low health fallback (an enemy player's health is secret on Forever, V143).
    it("never picks a candidate who isn't seen dead, even one last seen at very low health", function()
      local alive = {}
      Pvp.seeAlive(alive, look("A", "target", false, { health = 0.08 }), 98)
      local pending = Pvp.killCandidates({ look("A", "target", nil) }, alive, 100) -- UnitIsDead unknown at the rise
      Pvp.observe(pending, {}, 101, true)
      assert.are.same({}, Pvp.resolveVictims(pending, 1))
      assert.is_nil(Pvp.LOW_HEALTH)
    end)

    it("prefers target over mouseover over nameplate among the dead", function()
      local pending = Pvp.killCandidates({ look("N", "nameplate", false), look("T", "target", false),
                                           look("M", "mouseover", false) }, {}, 100)
      Pvp.observe(pending, { look("N", "nameplate", true), look("M", "mouseover", true), look("T", "target", true) })
      local picked = Pvp.resolveVictims(pending, 3)
      assert.are.same({ "T", "M", "N" }, { picked[1].guid, picked[2].guid, picked[3].guid })
      assert.are.same({ "later", "later", "later" }, { picked[1].path, picked[2].path, picked[3].path })
      assert.are.equal(1, #Pvp.resolveVictims(pending)) -- one kill by default
    end)

    it("drops stale and friendly players and those never seen alive", function()
      local alive = {}
      Pvp.seeAlive(alive, look("Stale", "target", false, { health = 0.05 }), 90)
      local looks = { look("Stale", "target", true), look("Never", "mouseover", true),
                      look("F", "nameplate", false, { enemy = false, health = 0.05 }) }
      local pending = Pvp.killCandidates(looks, alive, 100)
      assert.are.same({}, pending.list)
      Pvp.observe(pending, { look("F", "nameplate", true, { enemy = false }) }, 101, true)
      assert.are.same({}, Pvp.resolveVictims(pending, 3))
    end)

    it("ignores secret values (nil from the adapter): no GUID, no death", function()
      local pending = Pvp.killCandidates({ look("A", "target", false, { guid = false }),
                                           look("B", "target", false) }, {}, 100)
      assert.are.equal(1, #pending.list)
      Pvp.observe(pending, { look("B", "target", nil), { enemy = true, dead = true, source = "target" } }, 101, true)
      assert.are.same({}, Pvp.resolveVictims(pending, 1))
      assert.are.same({}, Pvp.resolveVictims(nil, 1))
      assert.are.same({}, Pvp.killCandidates(nil, {}, 100).list)
      Pvp.observe(nil, {}, 101, true) -- no error
    end)
  end)

  it("names the rank with our title", function()
    assert.are.equal("Stone Guard, a.k.a. Mailbox Menace", Pvp.rankText({ rank = 6, rankName = "Stone Guard" }))
    assert.are.equal("rank 0, a.k.a. Conscientious Objector", Pvp.rankText({ rank = 0 }))
    -- CF-61: Conscientious Objector only for a PvP Virgin; else "No rank yet Â· N kills".
    assert.are.equal("No rank yet \194\183 1 kill", Pvp.rankText({ rank = 0, hk = 1 }))
    assert.are.equal("No rank yet \194\183 1,234 kills", Pvp.rankText({ rank = 0, hk = 1234 }))
    assert.are.equal("No rank yet \194\183 0 kills", Pvp.rankText({ rank = 0, duelsWon = 1 }))
    -- Another character has the points:
    assert.are.equal("No rank yet \194\183 0 kills", Pvp.rankText({ rank = 0 }, nil, false))
    assert.is_true(Pvp.virgin({ hk = 0 }))
    assert.is_false(Pvp.virgin({ hk = 0, duelsLost = 2 }))
    -- CF-78: a finished battleground is a real fight too.
    assert.is_false(Pvp.virgin({ hk = 0 }, 1))
    assert.is_true(Pvp.virgin({ hk = 0 }, 0))
    assert.is_false(Pvp.virgin(nil, 1))
    assert.are.equal("rank 14, a.k.a. Grass: Untouched", Pvp.rankText({ rank = 14 }))
    assert.are.equal("Knight, a.k.a. Mailbox Menace", Pvp.rankText({ rank = 6 }, "Alliance"))
    assert.are.equal("High Warlord, a.k.a. Grass: Untouched", Pvp.rankText({ rank = 14 }, "Horde"))
    assert.is_nil(Pvp.rankText({ hk = 3 }))
    assert.is_nil(Pvp.rankText(nil))
    for rank = 0, 14 do assert.is_string(Pvp.TITLES[rank]) end
  end)

  it("cleans received PvP data", function()
    assert.are.same({ hk = 5, rank = 3, rankName = "Sergeant", deaths = 2 },
      Pvp.clean({ hk = 5.7, rank = 3, rankName = "Ser|geant", deaths = 2, evil = "x", duelsWon = "1" }))
    assert.are.same({ weekHonor = 10000000 }, Pvp.clean({ rank = 99, weekHonor = 1e12 }))
    assert.is_nil(Pvp.clean({ hk = -3 }))
    assert.is_nil(Pvp.clean("nope"))
  end)
end)
