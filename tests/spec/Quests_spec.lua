local helpers = require("helpers")

describe("Quests (CF-19)", function()
  local Quests

  before_each(function()
    Quests = helpers.loadAddonFile("src/core/Quests.lua", {})
  end)

  describe("fromLog", function()
    it("returns nil when the log is not readable", function()
      assert.is_nil(Quests.fromLog(nil))
    end)

    it("keys quests by ID with the area from the header above them", function()
      local quests = Quests.fromLog({
        { isHeader = true, title = "Durotar" },
        { questID = 101, title = "Quest A" },
        { questID = 102, title = "Quest B", isHidden = true },
        { isHeader = true, title = "Crafting" },
        { questID = 103, title = "Quest C" },
        { questID = 0, title = "No ID" },
      })
      assert.are.same({
        [101] = { title = "Quest A", area = "Durotar", dungeon = false },
        [103] = { title = "Quest C", area = "Crafting", dungeon = false },
      }, quests)
    end)

    it("marks dungeon quests by tag (Dungeon 81, Raid 62) or by a dungeon area name", function()
      local quests = Quests.fromLog({
        { isHeader = true, title = "The Barrens" },
        { questID = 1, title = "Tagged dungeon", tagID = 81 },
        { questID = 2, title = "Tagged raid", tagID = 62 },
        { questID = 3, title = "Elite group", tagID = 1 },
        { isHeader = true, title = "Blackfathom Deeps" },
        { questID = 4, title = "Untagged" },
      })
      assert.is_true(quests[1].dungeon)
      assert.is_true(quests[2].dungeon)
      assert.is_false(quests[3].dungeon)
      assert.is_true(quests[4].dungeon)
    end)

    it("treats an empty log as unreadable unless allowed (turn-in or abandon)", function()
      assert.is_nil(Quests.fromLog({}))
      assert.is_nil(Quests.fromLog({ { isHeader = true, title = "Durotar" } }))
      assert.are.same({}, Quests.fromLog({}, true))
    end)

    it("keeps quests before the first header without an area", function()
      assert.are.same({ [5] = { title = "Loose", dungeon = false } },
        Quests.fromLog({ { questID = 5, title = "Loose" } }))
    end)
  end)

  describe("shared", function()
    local friend = {
      [1] = { title = "Kill boars", area = "Durotar", dungeon = false },
      [2] = { title = "Into the deeps", area = "Blackfathom Deeps", dungeon = true },
      [3] = { title = "Bring ore", area = "Durotar", dungeon = false },
      [4] = { title = "Only theirs", area = "Durotar", dungeon = false },
    }
    local own = {
      { name = "Alice Example", classFile = "MAGE", quests = { [1] = {}, [2] = {} } },
      { name = "Bob Example", classFile = "WARRIOR", quests = { [1] = {}, [3] = {} } },
      { name = "No Data", classFile = "ROGUE" },
    }

    it("matches by quest ID and groups by area, dungeon areas first", function()
      local areas, total = Quests.shared(friend, own)
      assert.are.equal(3, total)
      assert.are.same({
        { area = "Blackfathom Deeps", dungeon = true, quests = {
          { questID = 2, title = "Into the deeps", ownChars = { { name = "Alice Example", classFile = "MAGE" } } },
        } },
        { area = "Durotar", dungeon = false, quests = {
          { questID = 3, title = "Bring ore", ownChars = { { name = "Bob Example", classFile = "WARRIOR" } } },
          { questID = 1, title = "Kill boars", ownChars = { { name = "Alice Example", classFile = "MAGE" },
                                                            { name = "Bob Example", classFile = "WARRIOR" } } },
        } },
      }, areas)
    end)

    it("handles missing quest data", function()
      local areas, total = Quests.shared(nil, own)
      assert.are.same({}, areas)
      assert.are.equal(0, total)
    end)

    it("puts quests without an area under Other", function()
      local areas = Quests.shared({ [9] = { title = "Loose" } }, { { name = "A", quests = { [9] = {} } } })
      assert.are.equal("Other", areas[1].area)
    end)

    it("merges all of a friend's characters, listing theirs per quest", function()
      local areas, total = Quests.sharedAcross({
        { name = "Carol Example", classFile = "PRIEST", quests = { [1] = friend[1] } },
        { name = "Ann Example", classFile = "ROGUE", quests = { [1] = friend[1], [4] = friend[4] } },
      }, own)
      assert.are.equal(1, total) -- quest 4 is only theirs
      local quest = areas[1].quests[1]
      assert.are.equal(1, quest.questID)
      assert.are.same({ { name = "Ann Example", classFile = "ROGUE" },
                        { name = "Carol Example", classFile = "PRIEST" } }, quest.theirChars)
      assert.are.equal(2, #quest.ownChars)
    end)
  end)
end)
