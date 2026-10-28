local helpers = require("helpers")

describe("Invite", function()
  local Invite

  before_each(function()
    Invite = helpers.loadAddonFile("src/core/Invite.lua", helpers.coreNs())
  end)

  describe("parseCode", function()
    it("takes the code from a full invite link", function()
      assert.are.equal("AbC123xyz", Invite.parseCode("https://blizzard.com/invite/AbC123xyz"))
      assert.are.equal("AbC123xyz", Invite.parseCode("  https://blizzard.com/invite/AbC123xyz  "))
    end)

    it("accepts a bare code", function()
      assert.are.equal("AbC123xyz", Invite.parseCode("AbC123xyz"))
      assert.are.equal("AbC123xyz", Invite.parseCode(" AbC123xyz "))
    end)

    it("rejects text that is not a link or code", function()
      assert.is_nil(Invite.parseCode("hello world"))
      assert.is_nil(Invite.parseCode("abc"))
      assert.is_nil(Invite.parseCode(""))
      assert.is_nil(Invite.parseCode(nil))
      assert.is_nil(Invite.parseCode("https://blizzard.com/invite/"))
    end)
  end)

  it("lets owners, leaders and moderators manage the link", function()
    assert.is_true(Invite.canManage(1))
    assert.is_true(Invite.canManage(2))
    assert.is_true(Invite.canManage(3))
    assert.is_false(Invite.canManage(4))
    assert.is_false(Invite.canManage(nil))
  end)

  describe("newest", function()
    it("picks the newest invite for the community", function()
      local best = Invite.newest({
        { battleTag = "A#1", displayName = "Anna", invite = { clubId = "C", code = "old1", setAt = 10 } },
        { battleTag = "B#2", displayName = "Bram", invite = { clubId = "C", code = "new1", setAt = 20 } },
        { battleTag = "D#3", displayName = "Dirk", invite = { clubId = "X", code = "other", setAt = 99 } },
        { battleTag = "E#4", displayName = "Eva" },
      }, "C")
      assert.are.same({ code = "new1", setAt = 20, setBy = "B#2", setByName = "Bram" }, best)
    end)

    it("returns nil without an invite for the community", function()
      assert.is_nil(Invite.newest({ { battleTag = "A#1", invite = { clubId = "X", code = "c1", setAt = 1 } } }, "C"))
      assert.is_nil(Invite.newest({ { battleTag = "A#1", invite = { clubId = "C", code = 5, setAt = 1 } } }, "C"))
    end)
  end)
end)
