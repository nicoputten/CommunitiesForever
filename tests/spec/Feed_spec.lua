local helpers = require("helpers")

describe("Feed (CF-22)", function()
  local Feed
  local TODAY = 20744 -- 2026-10-18, a Sunday
  local ALICE = { guid = "G-A", name = "Alice Example", classFile = "MAGE" }
  local ALT = { guid = "G-B", name = "Bob Example", classFile = "WARRIOR" }

  before_each(function()
    Feed = helpers.loadAddonFile("src/core/Feed.lua", {})
  end)

  local function prof(name, rank, max) return { name = name, rank = rank, max = max } end

  describe("days", function()
    it("numbers days and labels them", function()
      assert.are.equal(0, Feed.dayNumber(1970, 1, 1))
      assert.are.equal(TODAY, Feed.dayNumber(2026, 10, 18))
      assert.are.equal(Feed.dayNumber(2026, 3, 1) - 1, Feed.dayNumber(2026, 2, 28))
      assert.are.equal("Today", Feed.dayLabel(TODAY, TODAY))
      assert.are.equal("Yesterday", Feed.dayLabel(TODAY - 1, TODAY))
      assert.are.equal("Friday", Feed.dayLabel(TODAY - 2, TODAY))
    end)
  end)

  describe("changes", function()
    it("finds level-ups", function()
      assert.are.same({ { kind = "level", from = 5, to = 6 } }, Feed.changes({ level = 5 }, { level = 6 }))
      assert.are.same({}, Feed.changes(nil, { level = 6 }))
      assert.are.same({}, Feed.changes({ level = 6 }, { level = 6 }))
    end)

    it("finds new profession ranks only, not skill points", function()
      local before = { professions = { [186] = prof("Mining", 140, 150) } }
      assert.are.same({}, Feed.changes(before, { professions = { [186] = prof("Mining", 150, 150) } }))
      assert.are.same({ { kind = "rank", name = "Mining", rank = "Expert" } },
        Feed.changes(before, { professions = { [186] = prof("Mining", 150, 225) } }))
    end)

    it("finds learned professions, but not several appearing at once from none", function()
      local mining = { [186] = prof("Mining", 1, 75) }
      assert.are.same({ { kind = "learned", name = "Mining" } }, Feed.changes({ professions = {} },
        { professions = mining }))
      assert.are.same({ { kind = "learned", name = "Herbalism" } }, Feed.changes({ professions = mining },
        { professions = { [186] = mining[186], [182] = prof("Herbalism", 1, 75) } }))
      assert.are.same({}, Feed.changes({ professions = {} },
        { professions = { [186] = mining[186], [185] = prof("Cooking", 50, 75) } }))
    end)
  end)

  describe("add, trim and parts", function()
    it("aggregates a day per character", function()
      local feed = {}
      Feed.add(feed, TODAY, ALICE, { kind = "level", from = 5, to = 6 }, 100)
      Feed.add(feed, TODAY, ALICE, { kind = "level", from = 6, to = 8 }, 200)
      Feed.add(feed, TODAY, ALICE, { kind = "quest", zone = "Westfall" }, 210)
      Feed.add(feed, TODAY, ALICE, { kind = "quest", zone = "Westfall" }, 220)
      Feed.add(feed, TODAY, ALICE, { kind = "rank", name = "Mining", rank = "Journeyman" }, 230)
      Feed.add(feed, TODAY, ALICE, { kind = "learned", name = "Alchemy" }, 240)
      assert.are.same({ name = "Alice Example", classFile = "MAGE", at = 240, levelFrom = 5, levelTo = 8,
                        quests = { Westfall = 2 }, ranks = { Mining = "Journeyman" }, learned = { Alchemy = true } },
        feed[TODAY]["G-A"])
      assert.are.same({ "5 \226\134\146 8", "Mining reached Journeyman", "learned Alchemy",
                        "questing in Westfall (2)" }, Feed.parts(feed[TODAY]["G-A"]))
    end)

    it("replaces the range with the highest milestone", function()
      assert.are.same({ "reached 40" }, Feed.parts({ levelFrom = 38, levelTo = 41 }))
      assert.are.same({ "reached 60!" }, Feed.parts({ levelFrom = 59, levelTo = 60 }))
      assert.are.same({ "reached 20" }, Feed.parts({ levelFrom = 9, levelTo = 21 }))
      assert.are.same({ "10 \226\134\146 11" }, Feed.parts({ levelFrom = 10, levelTo = 11 }))
    end)

    it("words the questing zones for one, two and more zones", function()
      assert.are.same({ "questing in Westfall (9)" }, Feed.parts({ quests = { Westfall = 9 } }))
      assert.are.same({ "questing in Westfall and Redridge Mountains (12)" },
        Feed.parts({ quests = { Westfall = 9, ["Redridge Mountains"] = 3 } }))
      assert.are.same({ "questing in Westfall, Duskwood +1 zone (15)" },
        Feed.parts({ quests = { Westfall = 9, Duskwood = 4, Elwynn = 2 } }))
      assert.are.same({ "questing in Westfall, Duskwood +2 zones (16)" },
        Feed.parts({ quests = { Westfall = 9, Duskwood = 4, Elwynn = 2, Darkshire = 1 } }))
    end)

    it("keeps 7 days", function()
      local feed = { [TODAY] = {}, [TODAY - 6] = {}, [TODAY - 7] = {}, bad = {} }
      assert.is_true(Feed.trim(feed, TODAY))
      assert.is_truthy(feed[TODAY - 6])
      assert.is_nil(feed[TODAY - 7])
      assert.is_nil(feed.bad)
      assert.is_false(Feed.trim(feed, TODAY))
    end)
  end)

  describe("clean", function()
    it("keeps the expected fields and strips escapes", function()
      local cleaned = Feed.clean({ [TODAY] = { ["G-A"] = { name = "|cffff0000Alice|r", classFile = "MAGE", at = 5,
        levelFrom = 1, levelTo = 2, quests = { ["West|Tfall"] = 3, Bad = "x" }, ranks = { Mining = "Expert" },
        learned = { Alchemy = true, Nope = "yes" }, extra = "dropped" } }, nope = {} })
      assert.are.same({ [TODAY] = { ["G-A"] = { name = "cffff0000Alicer", classFile = "MAGE", at = 5,
        levelFrom = 1, levelTo = 2, quests = { WestTfall = 3 }, ranks = { Mining = "Expert" },
        learned = { Alchemy = true } } } }, cleaned)
      assert.is_nil(Feed.clean("x"))
      assert.is_nil(Feed.clean({}))
    end)
  end)

  describe("lines per person per day", function()
    local function person(name, feed, isSelf)
      return { displayName = name, battleTag = name .. "#1", isSelf = isSelf, feed = feed }
    end

    it("shows one line per person per day, with at most 3 parts and other characters", function()
      local feed = {}
      Feed.add(feed, TODAY, ALICE, { kind = "level", from = 5, to = 8 }, 100)
      Feed.add(feed, TODAY, ALICE, { kind = "rank", name = "Mining", rank = "Expert" }, 110)
      Feed.add(feed, TODAY, ALICE, { kind = "learned", name = "Alchemy" }, 120)
      Feed.add(feed, TODAY, ALICE, { kind = "quest", zone = "Westfall" }, 130)
      Feed.add(feed, TODAY, ALT, { kind = "quest", zone = "Durotar" }, 300)
      local days = Feed.days({ person("Alice", feed) }, TODAY)
      assert.are.equal(1, #days)
      assert.are.equal("Today", days[1].label)
      local line = days[1].lines[1]
      assert.are.equal("Alice", line.displayName)
      assert.are.same({ name = "Alice Example", classFile = "MAGE" }, line.char)
      assert.are.same({ "5 \226\134\146 8", "Mining reached Expert", "learned Alchemy" }, line.shown)
      assert.are.equal(1, line.more)
      assert.are.equal(1, line.extraChars)
      assert.are.same({ "questing in Durotar (1)" }, line.others[1].parts)
      assert.are.equal(300, line.at)
    end)

    it("sorts days newest first and people by latest activity, and drops old or empty days", function()
      local a, b = {}, {}
      Feed.add(a, TODAY, ALICE, { kind = "quest", zone = "Westfall" }, 100)
      Feed.add(a, TODAY - 1, ALICE, { kind = "quest", zone = "Westfall" }, 50)
      Feed.add(b, TODAY, ALT, { kind = "quest", zone = "Durotar" }, 200)
      a[TODAY - 9] = { x = { name = "Old", quests = { Elwynn = 1 } } }
      b[TODAY - 2] = { y = { name = "Nothing" } }
      local days = Feed.days({ person("Alice", a), person("Bob", b, true) }, TODAY)
      assert.are.same({ "Today", "Yesterday" }, { days[1].label, days[2].label })
      assert.are.same({ "Bob", "Alice" }, { days[1].lines[1].displayName, days[1].lines[2].displayName })
      assert.is_true(days[1].lines[1].isSelf)
    end)
  end)
end)
