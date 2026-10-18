local helpers = require("helpers")

describe("Runs (CF-23)", function()
  local Runs
  local DEADMINES = { name = "Deadmines", type = "party", instanceID = 36 }
  local MC = { name = "Molten Core", type = "raid", instanceID = 409 }
  local WSG = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }

  before_each(function()
    Runs = helpers.loadAddonFile("src/core/Runs.lua", {})
  end)

  it("starts runs only in dungeons, raids and battlegrounds", function()
    assert.are.equal("party", Runs.start(DEADMINES, 100, 5).kind)
    assert.are.equal("raid", Runs.start(MC, 100, 5).kind)
    assert.are.equal("pvp", Runs.start(WSG, 100, 5).kind)
    assert.is_nil(Runs.start({ name = "Kalimdor", type = "none", instanceID = 1 }, 100, 5))
    assert.is_nil(Runs.start(nil, 100, 5))
    assert.are.equal(5, Runs.start(DEADMINES, 100, 5).day)
  end)

  it("knows when the character is still in the same instance", function()
    local run = Runs.start(DEADMINES, 100, 5)
    assert.is_true(Runs.same(run, DEADMINES))
    assert.is_false(Runs.same(run, MC))
    assert.is_false(Runs.same(run, { name = "Kalimdor", type = "none", instanceID = 1 }))
    assert.is_true(Runs.same(run, { name = "Deadmines", type = "party" })) -- no instanceID: by name
  end)

  describe("dungeons and raids", function()
    it("count after 10 minutes and one boss", function()
      local run = Runs.start(DEADMINES, 1000, 5)
      assert.is_true(Runs.boss(run, 1001, 1200))
      Runs.touch(run, 1600)
      local event = Runs.finish(run)
      assert.are.same({ kind = "run", instance = "party", name = "Deadmines", bosses = 1, with = {} }, event)
    end)

    it("do not count under 10 minutes", function()
      local run = Runs.start(DEADMINES, 1000, 5)
      Runs.boss(run, 1001, 1200)
      Runs.touch(run, 1599)
      local event, reason = Runs.finish(run)
      assert.is_nil(event)
      assert.are.equal("9 min inside, needs 10", reason)
    end)

    it("do not count without a boss", function()
      local run = Runs.start(MC, 1000, 5)
      Runs.touch(run, 5000)
      local event, reason = Runs.finish(run)
      assert.is_nil(event)
      assert.are.equal("no boss killed", reason)
    end)

    it("count each boss once (ENCOUNTER_END and BOSS_KILL both report it)", function()
      local run = Runs.start(MC, 1000, 5)
      assert.is_true(Runs.boss(run, 663, 1100))
      assert.is_false(Runs.boss(run, 663, 1101))
      assert.is_true(Runs.boss(run, 664, 2000))
      assert.is_false(Runs.boss(run, nil, 2000))
      Runs.touch(run, 3000)
      assert.are.equal(2, Runs.finish(run).bosses)
    end)
  end)

  describe("battlegrounds", function()
    it("count when the match ended, won or lost by team", function()
      local run = Runs.start(WSG, 1000, 5)
      assert.is_nil((Runs.finish(run)))
      assert.is_true(Runs.matchEnded(run, 0, Runs.teamOf("Horde"), 1500))
      assert.is_false(Runs.matchEnded(run, 1, 0, 1501)) -- once
      assert.are.same({ kind = "run", instance = "pvp", name = "Warsong Gulch", won = true, with = {} },
        Runs.finish(run))

      local lost = Runs.start(WSG, 2000, 5)
      Runs.matchEnded(lost, 1, Runs.teamOf("Horde"), 2300)
      assert.is_false(Runs.finish(lost).won)
    end)

    it("leave won unknown when the winner or team is unknown", function()
      local run = Runs.start(WSG, 1000, 5)
      Runs.matchEnded(run, nil, 0, 1500)
      local event = Runs.finish(run)
      assert.is_not_nil(event)
      assert.is_nil(event.won)
    end)

    it("do not count when left before the end", function()
      local _, reason = Runs.finish(Runs.start(WSG, 1000, 5))
      assert.are.equal("left before the match ended", reason)
    end)
  end)

  it("keeps only companions that are community members, without yourself", function()
    local run = Runs.start(DEADMINES, 1000, 5)
    local members = { ["G-ME"] = true, ["G-ALICE"] = true, ["G-BOB"] = true }
    assert.are.equal(2, Runs.companions(run, { "G-ME", "G-ALICE", "G-STRANGER", "G-BOB" }, members, "G-ME"))
    assert.are.equal(0, Runs.companions(run, { "G-ALICE" }, members, "G-ME"))
    Runs.boss(run, 1, 2000)
    assert.are.same({ "G-ALICE", "G-BOB" }, Runs.finish(run).with)
  end)

  it("caps companions at a full raid", function()
    local run = Runs.start(MC, 1000, 5)
    local guids, members = {}, {}
    for i = 1, 50 do
      guids[i] = "G-" .. i
      members[guids[i]] = true
    end
    assert.are.equal(Runs.MAX_COMPANIONS, Runs.companions(run, guids, members, "G-ME"))
  end)
end)
