local helpers = require("helpers")

describe("Pvp (CF-52)", function()
  local Pvp
  local FORMATS = { knockout = "%1$s has defeated %2$s in a duel", retreat = "%2$s has fled from %1$s in a duel" }
  local ME = "Ada Example"

  before_each(function()
    Pvp = helpers.loadAddonFile("src/core/Pvp.lua", {})
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

  describe("format strings", function()
    it("turns positional and plain arguments into a pattern", function()
      local args = Pvp.parse("Bob Example has fled from Ada Example in a duel", FORMATS.retreat)
      assert.are.same({ "Ada Example", "Bob Example" }, args)
      args = Pvp.parse("Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)",
        "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)")
      assert.are.same({ "Grim Tusk", "Grunt", "12" }, args)
      assert.is_nil(Pvp.parse("You have been awarded 50 honor points.", "%s dies, honorable kill Rank: %s"))
      assert.is_nil(Pvp.parse("anything", "no arguments"))
      assert.is_nil(Pvp.parse("anything", nil))
    end)

    it("escapes magic characters of the format string", function()
      assert.are.same({ "x" }, Pvp.parse("(100%) x.", "(100%%) %s."))
      assert.is_nil(Pvp.parse("(100%) xy", "(100%%) %s."))
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

  it("names the rank with our title", function()
    assert.are.equal("Stone Guard a.k.a. Mailbox Menace", Pvp.rankText({ rank = 6, rankName = "Stone Guard" }))
    assert.are.equal("rank 0 a.k.a. Conscientious Objector", Pvp.rankText({ rank = 0 }))
    assert.are.equal("rank 14 a.k.a. Grass: Untouched", Pvp.rankText({ rank = 14 }))
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
