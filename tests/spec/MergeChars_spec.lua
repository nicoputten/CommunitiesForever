local helpers = require("helpers")

describe("per-character merge (CF-28)", function()
  local Merge
  local OWNER, RELAY = "Ann#1", "Ben#2"

  before_each(function()
    local ns = {}
    helpers.loadAddonFile("src/core/Feed.lua", ns)
    Merge = helpers.loadAddonFile("src/core/Merge.lua", ns)
  end)

  local function char(level, updatedAt, extra)
    local c = { name = "Alice Example", classFile = "MAGE", level = level, updatedAt = updatedAt }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
  end

  local function record(version, chars, extra)
    local r = { t = "RECORD", bt = OWNER, version = version, chars = chars }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end

  local QUESTS_NEW = { [101] = { title = "New quest", area = "Westfall" } }
  local QUESTS_OLD = { [99] = { title = "Old quest", area = "Elwynn" } }

  describe("characters", function()
    it("keeps a newer character, with its quests and professions, against an older copy in a newer record", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500, { quests = QUESTS_NEW, ilvl = 30,
        professions = { [186] = { name = "Mining", rank = 150, max = 150 } } }) }), 600, OWNER)
      -- A relayed record with a higher version but an older copy of G1 (and a new character G2).
      Merge.store(people, record(11, { G1 = char(18, 400, { quests = QUESTS_OLD, ilvl = 20 }),
                                       G2 = char(5, 450) }), 700, RELAY)
      local g1 = people[OWNER].chars.G1
      assert.are.equal(20, g1.level)
      assert.are.equal(30, g1.ilvl)
      assert.are.same(QUESTS_NEW, g1.quests)
      assert.are.equal(150, g1.professions[186].rank)
      assert.is_not_nil(people[OWNER].chars.G2)
      assert.are.equal(11, people[OWNER].version)
    end)

    it("takes a newer copy, also from a relay, quests included", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500, { quests = QUESTS_OLD }) }), 600, OWNER)
      Merge.store(people, record(11, { G1 = char(21, 650, { quests = QUESTS_NEW }) }), 700, RELAY)
      assert.are.equal(21, people[OWNER].chars.G1.level)
      assert.are.same(QUESTS_NEW, people[OWNER].chars.G1.quests)
    end)

    it("never lowers a level through a relay, even with a newer copy", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(30, 500) }), 600, OWNER)
      Merge.store(people, record(11, { G1 = char(28, 650, { zone = "Duskwood" }) }), 700, RELAY)
      assert.are.equal(30, people[OWNER].chars.G1.level)
      assert.are.equal("Duskwood", people[OWNER].chars.G1.zone) -- the rest of the newer copy is taken
    end)

    it("lets the owner's own record correct a level (and anything else)", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(60, 500) }), 600, RELAY) -- a wrong level via a relay
      Merge.store(people, record(11, { G1 = char(28, 450) }), 700, OWNER)
      assert.are.equal(28, people[OWNER].chars.G1.level)
    end)

    it("ignores relayed characters and removals timestamped in the future", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500), G2 = char(10, 500) }), 600, OWNER)
      Merge.store(people, record(11, { G1 = char(21, 600 + 301) }, { removed = { G2 = 99999 } }), 600, RELAY)
      assert.are.equal(20, people[OWNER].chars.G1.level)
      assert.is_not_nil(people[OWNER].chars.G2)
      Merge.store(people, record(12, { G1 = char(21, 600 + 300) }), 600, RELAY) -- within 5 minutes: fine
      assert.are.equal(21, people[OWNER].chars.G1.level)
    end)

    it("removes a character the owner's record drops; an older relayed copy does not bring it back", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500), G2 = char(10, 500) }), 600, OWNER)
      Merge.store(people, record(11, { G1 = char(20, 650) }), 700, OWNER) -- G2 deleted
      assert.is_nil(people[OWNER].chars.G2)
      assert.are.equal(700, people[OWNER].removed.G2)
      Merge.store(people, record(12, { G1 = char(20, 650), G2 = char(10, 690) }), 800, RELAY)
      assert.is_nil(people[OWNER].chars.G2)
      -- A copy newer than the removal (the character came back) is taken.
      Merge.store(people, record(13, { G1 = char(20, 650), G2 = char(11, 710) }), 900, OWNER)
      assert.are.equal(11, people[OWNER].chars.G2.level)
      assert.is_nil(people[OWNER].removed)
    end)

    it("passes removals on when relaying", function()
      local relayer, other = {}, {}
      Merge.store(relayer, record(10, { G1 = char(20, 500), G2 = char(10, 500) }), 600, OWNER)
      Merge.store(relayer, record(11, { G1 = char(20, 650) }), 700, OWNER)
      Merge.store(other, record(10, { G1 = char(20, 500), G2 = char(10, 500) }), 600, OWNER)
      Merge.store(other, Merge.relayRecord(relayer, OWNER), 800, RELAY)
      assert.is_nil(other[OWNER].chars.G2)
    end)

    it("keeps characters a relayed record does not list", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500), G2 = char(10, 500) }), 600, OWNER)
      Merge.store(people, record(11, { G1 = char(21, 650) }), 700, RELAY)
      assert.is_not_nil(people[OWNER].chars.G2)
    end)

    it("keeps display name and invite from the newest record", function()
      local people = {}
      Merge.store(people, record(10, { G1 = char(20, 500) }, { displayName = "Ann" }), 600, OWNER)
      Merge.store(people, record(9, { G1 = char(20, 400) }, { displayName = "Old Ann" }), 700, RELAY)
      assert.are.equal("Ann", people[OWNER].displayName)
    end)
  end)

  describe("activity feed", function()
    local DAY = 20744
    local function feed(entries)
      return { [DAY] = entries }
    end

    it("merges per day and character: the newer entry stays", function()
      local people = {}
      Merge.store(people, record(10, {}, { feed = feed({ G1 = { name = "A", at = 500, quests = { Westfall = 5 } } }) }),
        600, OWNER)
      local relayed = {
        [DAY] = { G1 = { name = "A", at = 400, quests = { Westfall = 2 } },
                  G2 = { name = "B", at = 450, levelFrom = 3, levelTo = 4 } },
        [DAY - 1] = { G1 = { name = "A", at = 300, quests = { Elwynn = 1 } } },
      }
      Merge.store(people, record(11, {}, { feed = relayed }), 700, RELAY)
      local f = people[OWNER].feed
      assert.are.same({ Westfall = 5 }, f[DAY].G1.quests)
      assert.are.equal(4, f[DAY].G2.levelTo)
      assert.are.same({ Elwynn = 1 }, f[DAY - 1].G1.quests)
    end)

    it("drops the feed when the owner stops sharing, also through a relay", function()
      local people = {}
      Merge.store(people, record(10, {}, { feed = feed({ G1 = { name = "A", at = 500, quests = { X = 1 } } }) }), 600,
        OWNER)
      Merge.store(people, record(11, {}, { feed = false }), 700, RELAY)
      assert.is_nil(people[OWNER].feed)
      assert.is_true(people[OWNER].feedOff)
      assert.is_false(Merge.relayRecord(people, OWNER).feed)
    end)

    it("keeps the feed when a relayed record has none (unknown)", function()
      local people = {}
      Merge.store(people, record(10, {}, { feed = feed({ G1 = { name = "A", at = 500, quests = { X = 1 } } }) }), 600,
        OWNER)
      Merge.store(people, record(11, {}), 700, RELAY)
      assert.is_not_nil(people[OWNER].feed)
    end)

    it("ignores relayed activity entries timestamped in the future", function()
      local people = {}
      Merge.store(people, record(10, {}, { feed = feed({ G1 = { name = "A", at = 500, quests = { X = 1 } } }) }), 600,
        OWNER)
      Merge.store(people, record(11, {}, { feed = feed({ G1 = { name = "A", at = 99999, quests = { X = 9 } } }) }), 700,
        RELAY)
      assert.are.same({ X = 1 }, people[OWNER].feed[DAY].G1.quests)
    end)

    it("drops old days relative to the newest day", function()
      local merged = (function()
        local ns = {}
        local Feed = helpers.loadAddonFile("src/core/Feed.lua", ns)
        return Feed.merge({ [DAY - 10] = { G1 = { at = 1 } } }, { [DAY] = { G1 = { at = 2 } } })
      end)()
      assert.is_nil(merged[DAY - 10])
      assert.is_not_nil(merged[DAY])
    end)
  end)
end)
