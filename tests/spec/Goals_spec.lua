local helpers = require("helpers")

describe("Goals (CF-56)", function()
  local Goals, Doomsday

  before_each(function()
    local ns = helpers.coreNs()
    Doomsday = helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    Goals = helpers.loadAddonFile("src/core/Goals.lua", ns)
  end)

  local function utc(y, m, d, hour, minute)
    return Doomsday.dayNumberOf(y, m, d) * 86400 + hour * 3600 + minute * 60
  end

  describe("schedule", function()
    it("knows CET and CEST by the EU summer-time dates", function()
      assert.are.equal(3600, Goals.cetOffset(utc(2026, 3, 29, 0, 59)))
      assert.are.equal(7200, Goals.cetOffset(utc(2026, 3, 29, 1, 0)))
      assert.are.equal(7200, Goals.cetOffset(utc(2026, 10, 25, 0, 59)))
      assert.are.equal(3600, Goals.cetOffset(utc(2026, 10, 25, 1, 0)))
      assert.are.equal(3600, Goals.cetOffset(utc(2026, 11, 10, 18, 0)))
    end)

    it("takes the game clock, then the site's offset, then CET/CEST", function()
      local now = utc(2026, 11, 10, 18, 0)
      assert.are.same({ reset = 68400, offset = 7200, source = "game" }, Goals.schedule(nil, 7200, now))
      local setting = { reset = 72000, offset = 25200 }
      assert.are.same({ reset = 72000, offset = 25200, source = "site" }, Goals.schedule(setting, nil, now))
      setting = { offset = 3600, offsetUntil = now, offsetAfter = 7200 }
      assert.are.equal(7200, Goals.schedule(setting, nil, now).offset)
      assert.are.equal(3600, Goals.schedule(setting, nil, now - 1).offset)
      assert.are.same({ reset = 68400, offset = 3600, source = "cet" }, Goals.schedule({}, nil, now))
    end)

    it("cleans the setting and keeps the newer one", function()
      assert.are.same({ reset = 68400, changedAt = 5, offset = 3600, offsetUntil = 9, offsetAfter = 7200 },
        Goals.cleanSetting({ reset = 68400, changedAt = 5, offset = 3600, offsetUntil = 9, offsetAfter = 7200, x = 1 }))
      assert.are.same({ changedAt = 0 }, Goals.cleanSetting({ reset = 90000, changedAt = 0, offsetUntil = 9 }))
      assert.is_nil(Goals.cleanSetting({ reset = "19:00" }))
      assert.is_nil(Goals.cleanSetting(false))
      local a, b = { changedAt = 10 }, { changedAt = 20 }
      assert.are.equal(b, Goals.newerSetting(a, b))
      assert.are.equal(b, Goals.newerSetting(b, a))
      assert.are.equal(a, Goals.newerSetting(a, nil))
      local c = { changedAt = 20, offset = 3600, offsetUntil = 99 }
      assert.are.equal(c, Goals.newerSetting(b, c)) -- same reset, fresher offset data
    end)
  end)

  describe("facts", function()
    local function progress(id, f) return Doomsday.progress(id, Goals.progressFacts(f, {})) end

    it("adds up over two characters", function()
      local f = Goals.newFacts()
      for _ = 1, 6 do Goals.observe(f, { kind = "quest", zone = "Westfall" }) end
      for _ = 1, 4 do Goals.observe(f, { kind = "quest", zone = "Duskwood" }) end
      Goals.observe(f, { kind = "char", guid = "A", day = 1 })
      Goals.observe(f, { kind = "char", guid = "B", day = 1 })
      assert.are.same({ 10, 10, true }, { progress("d.quests10", f) })
      assert.are.same({ 2, 2, true }, { progress("d.chars2", f) })
      assert.are.same({ 2, 3, false }, { progress("d.zones3", f) })
    end)

    it("counts levels, alt levels and clean levels", function()
      local f = Goals.newFacts()
      Goals.observe(f, { kind = "level", guid = "A", count = 1 })
      Goals.observe(f, { kind = "level", guid = "B", count = 2, alt = true, clean = true })
      assert.are.same({ 3, 2, 2, 2 }, { f.levels, (progress("d.altLevel", f)), (progress("w.altLevels2", f)),
                                         (progress("d.cleanLevel", f)) })
    end)

    it("measures item level and skill from the first sight of a character", function()
      local f = Goals.newFacts()
      Goals.observe(f, { kind = "char", guid = "A", ilvl = 20, professions = { [186] = { rank = 100, max = 150 } } })
      Goals.observe(f, { kind = "char", guid = "A", ilvl = 22, professions = { [186] = { rank = 103, max = 150 } } })
      Goals.observe(f, { kind = "char", guid = "B", ilvl = 40, professions = { [185] = { rank = 74, max = 75 } } })
      Goals.observe(f, { kind = "char", guid = "B", ilvl = 40, professions = { [185] = { rank = 75, max = 75 },
                                                                              [356] = { rank = 1, max = 75 } } })
      assert.are.equal(2, f.ilvlGain)
      assert.are.equal(5, f.skill) -- 3 Mining, 1 Cooking, 1 Fishing learned
      assert.is_true(f.secondary)
      assert.is_true(f.capReached) -- Cooking 75/75
    end)

    it("marks a full clear by the dungeon's boss count", function()
      local f = Goals.newFacts()
      Goals.observe(f, { kind = "run", name = "The Deadmines", bosses = 7, friends = 2 })
      Goals.observe(f, { kind = "run", name = "Shadowfang Keep", bosses = 5 })
      Goals.observe(f, { kind = "run", name = "Scarlet Monastery Library", bosses = 2 })
      assert.are.same({ true, false }, { f.runs[1].fullClear, f.runs[2].fullClear })
      assert.is_nil(f.runs[3].fullClear) -- no count yet
      assert.are.same({ 1, 1, true }, { progress("w.fullClear", f) })
      assert.are.same({ 2, 2, true }, { progress("w.dungeonFriends2", f) })
    end)

    it("keeps kills with their character for the PvP goals, up to the cap", function()
      local f = Goals.newFacts()
      for i = 1, 5 do
        Goals.observe(f, { kind = "kill", kill = { t = i, name = "V" .. i, solo = true }, char = "A" }, 4)
      end
      assert.are.equal(4, #f.kills)
      assert.are.equal("A", f.kills[1].char)
      assert.are.same({ 4, 3, true }, { progress("p.loneWolf", f) })
    end)
  end)

  it("builds the situation from the own characters", function()
    local chars = {
      A = { level = 60, ilvl = 50, professions = { [186] = { rank = 300 }, [356] = { rank = 150 } } },
      B = { level = 24, professions = { [185] = { rank = 20 } } },
    }
    local s = Goals.situation(chars, { B = true }, false, true)
    assert.are.same({ chars = 2, below60 = 1, altBelow60 = 1, highest = 60, highestToday = 24, ilvlReadable = true,
                      hasProfession = true, hasFishing = true, hasCraftingProfession = false,
                      professionBelow300 = true, friendQuestLog = false, dungeonInRange = true }, s)
  end)

  it("marks goals done once, with the time", function()
    local entry = { set = { "a", "b" }, done = {} }
    local values = { a = true, b = false }
    local function p(id) return 0, 1, values[id] end
    assert.are.same({ "a" }, Goals.mark(entry, p, 100))
    values.b = true
    assert.are.same({ "b" }, Goals.mark(entry, p, 200))
    assert.are.same({ a = 100, b = 200 }, entry.done)
    assert.are.equal(200, entry.at)
    assert.are.same({}, Goals.mark(entry, p, 300))
  end)

  describe("sync", function()
    local function entry(at, set, done)
      return { set = set or { "d.quests10" }, swapped = {}, done = done or {}, at = at }
    end

    it("cleans received goals: ids, 5 a day, 4 a week, 7 days, 2 weeks, numbers", function()
      local days = {}
      for n = 1, 9 do days[n] = entry(n) end
      days[1] = { set = { "a", "b", "c", "d", "e", "f", "bad id!", string.rep("x", 30) },
                  swapped = { e = "d.quests10" }, done = { a = 5, b = -1, c = "x" }, at = 7 }
      local weeks = { [2966] = entry(1, { "w1", "w2", "w3", "w4", "w5" }), [1] = entry(1), [2] = entry(1) }
      local clean = Goals.clean({ days = days, weeks = weeks,
                                  streak = 3, best = -2, pool = 1, reset = 68400, evil = true })
      local n = 0
      for _ in pairs(clean.days) do n = n + 1 end
      assert.are.equal(7, n)
      if clean.days[1] then
        assert.are.same({ "a", "b", "c", "d", "e" }, clean.days[1].set)
        assert.are.same({ a = 5 }, clean.days[1].done)
      end
      local kept = 0
      for _, w in pairs(clean.weeks) do
        kept = kept + 1
        assert.is_true(#w.set <= 4)
      end
      assert.are.equal(2, kept)
      assert.are.same({ 3, nil, 1, 68400 }, { clean.streak, clean.best, clean.pool, clean.reset })
      assert.is_nil(Goals.clean(false))
    end)

    it("merges per day and week by the newer time, ignoring the future", function()
      local stored = { days = { [10] = entry(100, nil, { ["d.quests10"] = 90 }), [11] = entry(200) }, weeks = {},
                       streak = 2, best = 4 }
      local incoming = { days = { [10] = entry(50), [11] = entry(300, nil, { ["d.quests10"] = 290 }),
                                  [12] = entry(9999) }, weeks = {}, streak = 3, best = 5 }
      local merged = Goals.merge(stored, incoming, 1000)
      assert.are.equal(90, merged.days[10].done["d.quests10"])
      assert.are.equal(290, merged.days[11].done["d.quests10"])
      assert.is_nil(merged.days[12])
      assert.are.same({ 3, 5 }, { merged.streak, merged.best })
      assert.are.equal(stored, Goals.merge(stored, nil))
    end)

    it("sends the last 7 days and this and last week", function()
      local goals = { days = {}, weeks = { [9] = entry(1), [10] = entry(2), [11] = entry(3) },
                      streak = { n = 4, last = 30 }, best = 6 }
      for n = 20, 31 do goals.days[n] = entry(n) end
      local out = Goals.outgoing(goals, 30, 11, 1, 68400)
      local days = {}
      for n in pairs(out.days) do days[#days + 1] = n end
      table.sort(days)
      assert.are.same({ 24, 25, 26, 27, 28, 29, 30 }, days)
      assert.is_nil(out.weeks[9])
      assert.is_table(out.weeks[10])
      assert.are.same({ 4, 6, 1, 68400 }, { out.streak, out.best, out.pool, out.reset })
    end)
  end)
end)
