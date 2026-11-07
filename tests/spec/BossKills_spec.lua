local helpers = require("helpers")

describe("BossKills (CF-103)", function()
  local BossKills, Feed, Store
  local NOW = 1794500000
  local DAY = 20768
  local A, B, C = "Player-1-AAAA", "Player-1-BBBB", "Player-1-CCCC"

  before_each(function()
    local ns = helpers.coreNs()
    Feed = helpers.loadAddonFile("src/core/Feed.lua", ns)
    BossKills = helpers.loadAddonFile("src/core/BossKills.lua", ns)
    Store = helpers.loadAddonFile("src/core/Store.lua", ns)
  end)

  describe("cleanLive", function()
    it("takes a KILL message's fields", function()
      local kill = BossKills.cleanLive({ t = "KILL", guid = A, instance = 36, name = "Dead|mines", encounter = 1001,
                                         at = NOW - 10.5, extra = 1 }, NOW, 300)
      assert.are.same({ guid = A, instance = 36, name = "Deadmines", encounter = 1001, at = NOW - 11 }, kill)
    end)

    it("needs a character, an encounter and a time that is neither in the future nor days old", function()
      assert.is_nil(BossKills.cleanLive({ encounter = 1001, at = NOW }, NOW, 300))
      assert.is_nil(BossKills.cleanLive({ guid = A, encounter = 1.5, at = NOW }, NOW, 300))
      assert.is_nil(BossKills.cleanLive({ guid = A, encounter = -1, at = NOW }, NOW, 300))
      assert.is_nil(BossKills.cleanLive({ guid = A, encounter = 1001, at = NOW + 301 }, NOW, 300))
      assert.is_nil(BossKills.cleanLive({ guid = A, encounter = 1001, at = NOW - 3 * 86400 }, NOW, 300))
      assert.is_nil(BossKills.cleanLive({ guid = A, encounter = 1001, at = 0 / 0 }, NOW, 300))
      assert.is_nil(BossKills.cleanLive("x", NOW, 300))
      local kill = BossKills.cleanLive({ guid = A, encounter = 1001, at = NOW + 300, instance = "x" }, NOW, 300)
      assert.are.same({ guid = A, encounter = 1001, at = NOW + 300 }, kill)
    end)
  end)

  describe("the live store", function()
    it("keeps the earliest time per boss", function()
      local store = {}
      assert.is_true(BossKills.addLive(store, { guid = A, encounter = 1001, at = NOW }))
      assert.is_false(BossKills.addLive(store, { guid = A, encounter = 1001, at = NOW + 5 }))
      assert.is_true(BossKills.addLive(store, { guid = A, encounter = 1001, at = NOW - 5 }))
      assert.is_true(BossKills.addLive(store, { guid = A, encounter = 1002, at = NOW }))
      assert.are.same({ [A] = { [1001] = NOW - 5, [1002] = NOW } }, store)
    end)

    it("is limited per character", function()
      local store = {}
      for i = 1, BossKills.MAX_PER_CHAR + 5 do BossKills.addLive(store, { guid = A, encounter = i, at = NOW }) end
      local n = 0
      for _ in pairs(store[A]) do n = n + 1 end
      assert.are.equal(BossKills.MAX_PER_CHAR, n)
    end)

    it("drops kills older than two days", function()
      local store = { [A] = { [1001] = NOW - 3 * 86400, [1002] = NOW - 60 }, [B] = { [1001] = NOW - 3 * 86400 },
                      [C] = "x" }
      BossKills.trimLive(store, NOW)
      assert.are.same({ [A] = { [1002] = NOW - 60 } }, store)
    end)
  end)

  it("reads own runs in progress, leaving kills without a time out", function()
    local runs = { [A] = { bosses = { [1001] = NOW, [1002] = true } }, [B] = { bosses = { [1003] = true } } }
    assert.are.same({ [A] = { [1001] = NOW } }, BossKills.fromRuns(runs))
    assert.are.same({}, BossKills.fromRuns(nil))
  end)

  describe("collect", function()
    local function record(guid, kills)
      return { feed = { [DAY] = { [guid] = { at = NOW, runs = {
        { name = "Deadmines", kind = "party", bosses = 2, bossKills = kills },
        { name = "Ragefire Chasm", kind = "party", bosses = 3 }, -- an older client: a count only
      } } } } }
    end

    it("joins records and live kills: the earliest time per boss and per character", function()
      local records = { ["Ada#1001"] = record(A, { [1001] = NOW - 600, [1002] = NOW - 300 }),
                        self = record(B, { [1001] = NOW - 500 }) }
      local live = { { [C] = { [1001] = NOW - 700, [1003] = NOW - 100 } }, { [A] = { [1002] = NOW - 400 } } }
      local kills = BossKills.collect(records, live, { A, B, C }, { 1001, 1002, 1003 })
      assert.are.same({
        [1001] = { at = NOW - 700, by = { [A] = NOW - 600, [B] = NOW - 500, [C] = NOW - 700 } },
        [1002] = { at = NOW - 400, by = { [A] = NOW - 400 } },
        [1003] = { at = NOW - 100, by = { [C] = NOW - 100 } },
      }, kills)
    end)

    it("keeps to the characters, the encounters and the time window", function()
      local records = { record(A, { [1001] = NOW - 600, [1002] = NOW - 300, [9999] = NOW - 300 }),
                        record(B, { [1001] = NOW - 500 }) }
      local kills = BossKills.collect(records, nil, { [A] = true }, { [1001] = true, [1002] = true },
        NOW - 599, NOW - 300)
      assert.are.same({ [1002] = { at = NOW - 300, by = { [A] = NOW - 300 } } }, kills)
    end)

    it("is empty without kills, and survives broken data", function()
      assert.are.same({}, BossKills.collect(nil, nil, { A }, { 1001 }))
      assert.are.same({}, BossKills.collect({ { feed = { [DAY] = { [A] = { runs = { "x", { bossKills = "y" } } } } } },
                                              "z" }, { "w" }, { A }, { 1001 }))
    end)
  end)

  describe("feed", function()
    local function entry(at, kills)
      return { at = at, runs = { { name = "Deadmines", kind = "party", bosses = 2, bossKills = kills, with = {} } } }
    end

    it("cleans received kill times, dropping future ones", function()
      local clean = Feed.clean({ [DAY] = { [A] = { at = 1, runs = { { name = "Deadmines", kind = "party", bosses = 3,
        bossKills = { [1001] = NOW - 10.2, [1002] = NOW + 301, [1003] = "x", [-4] = NOW, x = NOW, [1.5] = NOW },
      } } } } }, NOW + 300)
      assert.are.same({ [1001] = NOW - 11 }, clean[DAY][A].runs[1].bossKills)
      local none = Feed.clean({ [DAY] = { [A] = { at = 1, runs = { { name = "Deadmines", kind = "party",
        bossKills = { [1002] = NOW + 301 } } } } } }, NOW + 300)
      assert.is_nil(none[DAY][A].runs[1].bossKills)
    end)

    it("joins kill times of two copies of an entry, the earliest per boss", function()
      local stored = { [DAY] = { [A] = entry(NOW, { [1001] = NOW - 100 }) } }
      local incoming = { [DAY] = { [A] = entry(NOW + 10, { [1001] = NOW - 200, [1002] = NOW - 50 }) } }
      local merged = Feed.merge(stored, incoming)
      assert.are.same({ [1001] = NOW - 200, [1002] = NOW - 50 }, merged[DAY][A].runs[1].bossKills)
      assert.are.equal(NOW + 10, merged[DAY][A].at)
      assert.are.same({ [1001] = NOW - 100 }, stored[DAY][A].runs[1].bossKills) -- not changed in place
    end)

    it("keeps kill times when an older client relays the same entry without them", function()
      local stored = { [DAY] = { [A] = entry(NOW, nil) } }
      local merged = Feed.merge(stored, { [DAY] = { [A] = entry(NOW, { [1001] = NOW - 100 }) } })
      assert.are.same({ [1001] = NOW - 100 }, merged[DAY][A].runs[1].bossKills)
      merged = Feed.merge({ [DAY] = { [A] = entry(NOW, { [1001] = NOW - 100 }) } },
        { [DAY] = { [A] = entry(NOW + 5) } })
      assert.are.same({ [1001] = NOW - 100 }, merged[DAY][A].runs[1].bossKills)
    end)

    it("does not join kills of a different run", function()
      local other = { at = NOW + 10,
                      runs = { { name = "Wailing Caverns", kind = "party", bossKills = { [2001] = NOW } } } }
      local merged = Feed.merge({ [DAY] = { [A] = entry(NOW, { [1001] = NOW - 100 }) } }, { [DAY] = { [A] = other } })
      assert.are.same({ [2001] = NOW }, merged[DAY][A].runs[1].bossKills)
    end)
  end)

  describe("Store migration 2 -> 3", function()
    it("gives old kills of a run in progress the run's last time, and starts the live store", function()
      local global = Store.init({ schemaVersion = 2, runs = {
        [A] = { name = "Deadmines", startedAt = 100, lastAt = 900, bosses = { [1001] = true, [1002] = true },
                bossCount = 2 },
        [B] = { name = "Ragefire Chasm", startedAt = 50, bosses = { [2001] = true }, bossCount = 1 },
        [C] = { name = "Odd", bosses = { [3001] = true } },
      } })
      assert.are.equal(3, global.schemaVersion)
      assert.are.same({ [1001] = 900, [1002] = 900 }, global.runs[A].bosses)
      assert.are.same({ [2001] = 50 }, global.runs[B].bosses)
      assert.are.same({ [3001] = true }, global.runs[C].bosses)
      assert.are.same({}, global.liveKills)
    end)

    it("works on data without runs", function()
      local global = Store.init({ schemaVersion = 2 })
      assert.are.same({}, global.liveKills)
      assert.is_nil(global.runs)
    end)
  end)
end)
