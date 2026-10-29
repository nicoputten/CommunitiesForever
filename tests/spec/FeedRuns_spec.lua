local helpers = require("helpers")

describe("Feed runs (CF-23)", function()
  local Feed
  local TODAY = 20744
  local TIMES = "\195\151"
  local ME = { guid = "G-ME", name = "Ann Example", classFile = "MAGE" }
  local FRIEND = { guid = "G-FR", name = "Ben Example", classFile = "PRIEST" }
  local THIRD = { guid = "G-TH", name = "Cid Example", classFile = "ROGUE" }

  before_each(function()
    Feed = helpers.loadAddonFile("src/core/Feed.lua", helpers.coreNs())
  end)

  local function run(name, kind, extra)
    local event = { kind = "run", instance = kind, name = name, with = {} }
    for k, v in pairs(extra or {}) do event[k] = v end
    return event
  end

  local function feedOf(char, events, at)
    local feed = {}
    for _, event in ipairs(events) do Feed.add(feed, TODAY, char, event, at or 100) end
    return feed
  end

  local function person(tag, name, char, feed, isSelf)
    return { battleTag = tag, displayName = name, isSelf = isSelf or false, chars = { { guid = char.guid } },
             feed = feed }
  end

  local function lines(people, members)
    local days = Feed.days(people, TODAY, members)
    return days[1] and days[1].lines or {}
  end

  describe("own lines", function()
    it("show runs first, with x2 for a second run", function()
      local entry = feedOf(ME, { run("Deadmines", "party", { bosses = 2 }), run("Deadmines", "party", { bosses = 5 }),
                                 { kind = "level", from = 17, to = 18 } })[TODAY][ME.guid]
      assert.are.same({ "ran Deadmines " .. TIMES .. "2", "17 to 18" }, Feed.parts(entry))
    end)

    it("word raids with bosses and battlegrounds with wins", function()
      local entry = feedOf(ME, {
        run("Molten Core", "raid", { bosses = 4 }),
        run("Warsong Gulch", "pvp", { won = true }), run("Arathi Basin", "pvp", { won = false }),
        run("Warsong Gulch", "pvp", { won = true }),
        run("Shadowfang Keep", "party", { bosses = 1 }),
      })[TODAY][ME.guid]
      assert.are.same({ "raided Molten Core (4 bosses)", "ran Shadowfang Keep", "3 battlegrounds (2 won)" },
        Feed.parts(entry))
    end)

    it("word a single battleground and unknown winners", function()
      local won = feedOf(ME, { run("Warsong Gulch", "pvp", { won = true }) })[TODAY][ME.guid]
      assert.are.same({ "1 battleground (won)" }, Feed.parts(won))
      local lost = feedOf(ME, { run("Warsong Gulch", "pvp", { won = false }) })[TODAY][ME.guid]
      assert.are.same({ "1 battleground (lost)" }, Feed.parts(lost))
      local unknown = feedOf(ME, { run("Warsong Gulch", "pvp"), run("Warsong Gulch", "pvp") })[TODAY][ME.guid]
      assert.are.same({ "2 battlegrounds" }, Feed.parts(unknown))
      local boss = feedOf(ME, { run("Molten Core", "raid", { bosses = 1 }) })[TODAY][ME.guid]
      assert.are.same({ "raided Molten Core (1 boss)" }, Feed.parts(boss))
    end)
  end)

  describe("playing together", function()
    it("makes one shared line from two records and leaves it out of the own lines", function()
      local mine = feedOf(ME, { run("Deadmines", "party", { bosses = 3, with = { FRIEND.guid } }),
                                run("Deadmines", "party", { bosses = 2, with = { FRIEND.guid } }),
                                { kind = "level", from = 17, to = 18 } }, 200)
      local theirs = feedOf(FRIEND, { run("Deadmines", "party", { bosses = 3, with = { ME.guid } }),
                                      run("Deadmines", "party", { bosses = 2, with = { ME.guid } }) }, 300)
      local result = lines({ person("Me#1", "Ann", ME, mine, true), person("Fr#2", "Ben", FRIEND, theirs) })
      assert.are.equal(2, #result)
      local shared = result[1]
      assert.is_true(shared.shared)
      assert.are.equal("Ann and Ben", shared.title)
      assert.are.same({ "ran Deadmines " .. TIMES .. "2" }, shared.parts) -- the same runs, not 4
      assert.are.equal(300, shared.at)
      -- CF-41: who and on which character, for the overlapping portraits (you first).
      assert.are.same({ "Ann", "Ben" }, shared.names)
      assert.are.same({ { name = ME.name, classFile = ME.classFile }, { name = FRIEND.name,
                                                                        classFile = FRIEND.classFile } }, shared.chars)
      assert.are.same({ { kind = "run", text = "ran Deadmines " .. TIMES .. "2" } }, shared.pieces)
      assert.is_true(shared.hasRuns)
      assert.are.same({ "17 to 18" }, result[2].parts) -- own line without the runs
      -- Ben's line had only the runs, so it is gone.
    end)

    it("makes a shared line from one record when the companion has no addon", function()
      local mine = feedOf(ME, { run("Warsong Gulch", "pvp", { won = true, with = { FRIEND.guid, THIRD.guid } }) })
      local result = lines({ person("Me#1", "Ann", ME, mine, true), person("Fr#2", "Ben", FRIEND, nil),
                             person("Th#3", "Cid", THIRD, nil) })
      assert.are.equal(1, #result)
      assert.are.equal("Ann, Ben and Cid", result[1].title)
      assert.are.same({ "1 battleground (won)" }, result[1].parts)
    end)

    it("names community members without a linked person and leaves strangers out", function()
      local mine = feedOf(ME, { run("Deadmines", "party", { bosses = 1, with = { "G-MEMBER", "G-STRANGER" } }) })
      local result = lines({ person("Me#1", "Ann", ME, mine, true) }, { ["G-MEMBER"] = "Dee Example" })
      assert.are.equal(1, #result)
      assert.is_nil(result[1].shared)
      assert.are.same({ "ran Deadmines with Dee Example" }, result[1].parts)
    end)

    it("keeps separate shared lines per group of people", function()
      local mine = feedOf(ME, { run("Deadmines", "party", { bosses = 1, with = { FRIEND.guid } }),
                                run("Molten Core", "raid", { bosses = 2, with = { FRIEND.guid, THIRD.guid } }) })
      local result = lines({ person("Me#1", "Ann", ME, mine, true), person("Fr#2", "Ben", FRIEND, nil),
                             person("Th#3", "Cid", THIRD, nil) })
      local titles = {}
      for _, line in ipairs(result) do titles[line.title] = line.parts[1] end
      assert.are.same({ ["Ann and Ben"] = "ran Deadmines", ["Ann, Ben and Cid"] = "raided Molten Core (2 bosses)" },
        titles)
    end)
  end)

  it("cleans received runs", function()
    local clean = Feed.clean({ [TODAY] = { ["G-1"] = { name = "X", runs = {
      { name = "|cffff0000Deadmines", kind = "party", bosses = 99, won = "yes", with = { "G-2", 5, "G-3" } },
      { name = "Nowhere", kind = "arena" },
      "junk",
    } } } })
    assert.are.same({ { name = "cffff0000Deadmines", kind = "party", bosses = 40, with = { "G-2", "G-3" } } },
      clean[TODAY]["G-1"].runs)
  end)
end)
