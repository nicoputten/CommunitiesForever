local helpers = require("helpers")

describe("Merge", function()
  local Merge

  before_each(function()
    Merge = helpers.loadAddonFile("src/core/Merge.lua", {})
  end)

  describe("nextVersion", function()
    it("uses server time when it is ahead", function()
      assert.are.equal(5000, Merge.nextVersion(10, 5000))
    end)

    it("increments when the previous version is at or ahead of server time", function()
      assert.are.equal(5001, Merge.nextVersion(5000, 5000))
      assert.are.equal(9001, Merge.nextVersion(9000, 5000))
    end)

    it("treats a missing previous version as 0", function()
      assert.are.equal(1, Merge.nextVersion(nil, 0))
      assert.are.equal(5000, Merge.nextVersion(nil, 5000))
    end)
  end)
end)
