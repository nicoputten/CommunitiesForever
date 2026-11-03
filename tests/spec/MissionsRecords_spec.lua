local helpers = require("helpers")

describe("Missions: records (CF-72)", function()
  local ns, Records

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Records.lua", ns)
    Records = ns.Missions.Records
  end)

  -- JSON object keys are strings: skill lines are numbers in the game's data.
  local function fromJson(obs)
    local copy = {}
    for k, v in pairs(obs) do copy[k] = v end
    if type(obs.professions) == "table" then
      copy.professions = {}
      for line, rank in pairs(obs.professions) do copy.professions[tonumber(line) or line] = rank end
    end
    return copy
  end

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Records)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/records.json")
    assert.is_true(#cases.cases > 0)
    for _, case in ipairs(cases.cases) do
      local day, week = ns.Goals.newFacts(), ns.Goals.newFacts()
      for _, obs in ipairs(case.observations) do
        ns.Goals.observe(day, fromJson(obs))
        ns.Goals.observe(week, fromJson(obs))
      end
      for id, expected in pairs(case.progress) do
        local f = ns.Goals.progressFacts(id:sub(1, 1) == "w" and week or day)
        local value, target, done = ns.Doomsday.progress(id, f)
        assert.are.same(expected, { value, target, done }, case.name .. ": " .. id)
      end
    end
  end)

  it("registers the progress of its 13 dailies, all in the catalogue", function()
    local dailies = { "d.levels2", "d.lowbie", "d.dingDungeon", "d.dingFriend", "d.dungeons2", "d.speedRun",
                      "d.newDungeon", "d.chars3", "d.switchUp", "d.dustOff", "d.cookSkill5", "d.fishSkill5",
                      "d.aidSkill5" }
    for _, id in ipairs(dailies) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("registers the weeklies that read its data", function()
    for _, id in ipairs({ "w.levels5", "w.levelDays3", "w.dungeons5", "w.bosses15", "w.newDungeons2", "w.days7" }) do
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("keeps its facts under its own key", function()
    local f = ns.Goals.newFacts()
    assert.is_nil(f.records)
    ns.Goals.observe(f, { kind = "recordDing", level = 5, day = 1 })
    assert.are.equal(1, f.records.lowbie)
    assert.are.equal(f.records, ns.Goals.progressFacts(f).records)
  end)

  it("ignores observations with missing fields", function()
    local f = ns.Goals.newFacts()
    for _, kind in ipairs({ "recordDing", "recordBoss", "recordSkills", "recordLogin" }) do
      ns.Goals.observe(f, { kind = kind })
    end
    for _, id in ipairs(Records.IDS) do
      assert.is_false(select(3, ns.Doomsday.progress(id, ns.Goals.progressFacts(f))), id)
    end
  end)

  it("caps the new dungeons of a day or week", function()
    local f = ns.Goals.newFacts()
    for i = 1, Records.MAX_NEW + 10 do
      ns.Goals.observe(f, { kind = "recordBoss", guid = "Player-1-A", name = "Dungeon " .. i, bosses = 1, new = true })
    end
    assert.are.equal(Records.MAX_NEW, (ns.Doomsday.progress("w.newDungeons2", ns.Goals.progressFacts(f))))
  end)

  describe("friendGrouped", function()
    local people = { ["Ada#1001"] = { chars = { ["Player-1-F"] = {} } },
                     ["Me#1000"] = { chars = { ["Player-1-M"] = {} } } }
    local members = { ["Player-1-F"] = {}, ["Player-1-M"] = {}, ["Player-1-P"] = {} }

    it("finds a friend's community character", function()
      assert.is_true(Records.friendGrouped({ "Player-1-X", "Player-1-F" }, members, people, {}, "Me#1000"))
    end)

    it("needs the character in the community", function()
      assert.is_false(Records.friendGrouped({ "Player-1-F" }, {}, people, {}, "Me#1000"))
    end)

    it("does not count own characters or strangers", function()
      assert.is_false(Records.friendGrouped({ "Player-1-M", "Player-1-X" }, members, people, {}, "Me#1000"))
    end)

    it("knows a friend from presence alone", function()
      local presence = { ["Player-1-P"] = { battleTag = "Bob#1002" } }
      assert.is_true(Records.friendGrouped({ "Player-1-P" }, members, {}, presence, "Me#1000"))
      presence["Player-1-P"].battleTag = "Me#1000"
      assert.is_false(Records.friendGrouped({ "Player-1-P" }, members, {}, presence, "Me#1000"))
    end)

    it("is false on missing data", function()
      assert.is_false(Records.friendGrouped(nil, members, people, nil, "Me#1000"))
      assert.is_false(Records.friendGrouped({ "Player-1-F" }, nil, people, nil, "Me#1000"))
      assert.is_false(Records.friendGrouped({ "Player-1-F" }, members, nil, nil, nil))
    end)
  end)

  describe("dungeons seen", function()
    it("seeds the party runs of the stored feed per character", function()
      local feed = {
        [100] = { ["Player-1-A"] = { runs = { { name = "Dungeon A", kind = "party", bosses = 2 },
                                              { name = "Raid R", kind = "raid", bosses = 1 },
                                              { name = "Field F", kind = "pvp" } } } },
        [101] = { ["Player-1-B"] = { runs = { { name = "Dungeon B", kind = "party", bosses = 1 } } },
                  ["Player-1-C"] = { quests = { Zone = 2 } } },
      }
      assert.are.same({ ["Player-1-A"] = { ["Dungeon A"] = true }, ["Player-1-B"] = { ["Dungeon B"] = true } },
        Records.seedDungeons(feed))
      assert.are.same({}, Records.seedDungeons(nil))
      assert.are.same({}, Records.seedDungeons({ [1] = "junk", [2] = { g = { runs = { "junk" } } } }))
    end)

    it("marks a dungeon new once per character", function()
      local seen = { ["Player-1-A"] = { ["Dungeon A"] = true } }
      assert.is_false(Records.markDungeon(seen, "Player-1-A", "Dungeon A"))
      assert.is_true(Records.markDungeon(seen, "Player-1-A", "Dungeon B"))
      assert.is_false(Records.markDungeon(seen, "Player-1-A", "Dungeon B"))
      assert.is_true(Records.markDungeon(seen, "Player-1-B", "Dungeon A"))
      assert.is_false(Records.markDungeon(nil, "Player-1-A", "Dungeon C"))
      assert.is_false(Records.markDungeon(seen, "Player-1-A", nil))
    end)
  end)

  describe("logins", function()
    it("seeds the other characters from lastPlayed, the current one stays unknown", function()
      local last = {}
      local chars = { ["Player-1-A"] = { lastPlayed = 500 }, ["Player-1-B"] = { lastPlayed = 300 },
                      ["Player-1-C"] = {} }
      assert.is_nil(Records.login(last, chars, "Player-1-A", 1000))
      assert.are.same({ ["Player-1-A"] = 1000, ["Player-1-B"] = 300 }, last)
      assert.are.equal(300, Records.login(last, chars, "Player-1-B", 2000))
      assert.are.equal(1000, Records.login(last, chars, "Player-1-A", 3000))
    end)

    it("a logout moves the last time played", function()
      local last = { ["Player-1-A"] = 1000 }
      Records.played(last, "Player-1-A", 1500)
      assert.are.equal(1500, Records.login(last, {}, "Player-1-A", 9000))
      Records.played(nil, "Player-1-A", 1500) -- no table yet: nothing
    end)

    it("is nil on missing data", function()
      assert.is_nil(Records.login(nil, {}, "Player-1-A", 1))
      assert.is_nil(Records.login({}, nil, nil, 1))
    end)
  end)
end)
