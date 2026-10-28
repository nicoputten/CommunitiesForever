local helpers = require("helpers")

describe("Chat (CF-25)", function()
  local Chat
  local CHANNEL = "Community:1:1"

  before_each(function()
    Chat = helpers.loadAddonFile("src/core/Chat.lua", helpers.coreNs())
  end)

  it("uses purple unless another valid color is set", function()
    assert.are.same({ r = 0.75, g = 0.5, b = 1 }, Chat.color({}))
    assert.are.same({ r = 0.1, g = 0.2, b = 0.3 }, Chat.color({ chatColor = { r = 0.1, g = 0.2, b = 0.3 } }))
    assert.are.same(Chat.DEFAULT_COLOR, Chat.color({ chatColor = { r = 2, g = 0, b = 0 } }))
    assert.are.same(Chat.DEFAULT_COLOR, Chat.color(nil))
  end)

  it("alerts for others' messages in the selected community only", function()
    local state = { channel = CHANNEL, ownGuids = { ["G-ME"] = true }, enabled = true }
    assert.is_true(Chat.shouldAlert({ channel = CHANNEL, senderGuid = "G-FRIEND" }, state))
    assert.is_false(Chat.shouldAlert({ channel = CHANNEL, senderGuid = "G-ME" }, state))
    assert.is_false(Chat.shouldAlert({ channel = "Community:2:1", senderGuid = "G-FRIEND" }, state))
    state.enabled = false
    assert.is_false(Chat.shouldAlert({ channel = CHANNEL, senderGuid = "G-FRIEND" }, state))
  end)

  it("flashes the windows that show the channel, except the selected one", function()
    local windows = { { index = 1, hasChannel = true }, { index = 2, hasChannel = false },
                      { index = 3, hasChannel = true } }
    assert.are.same({ 3 }, Chat.flashTargets(windows, 1))
    assert.are.same({ 1, 3 }, Chat.flashTargets(windows, nil))
  end)

  it("names and finds the Community tab", function()
    assert.are.equal("Community", Chat.tabName(nil))
    assert.are.equal("Alice's Friends", Chat.tabName("Alice's Friends"))
    assert.are.equal("A very long comm", Chat.tabName("A very long community name"))
    assert.are.equal(3, Chat.findTab({ { index = 1, name = "General" }, { index = 3, name = "Community" } },
      "Community"))
    assert.is_nil(Chat.findTab({ { index = 1, name = "General" } }, "Community"))
  end)

  describe("syncChannel (CF-31)", function()
    it("is the same short name for the same community, whatever the case or spaces", function()
      local name = Chat.syncChannel("Test Friends")
      assert.is_truthy(name:match("^cf%x%x%x%x%x%x%x%x$"))
      assert.are.equal(name, Chat.syncChannel("  test FRIENDS "))
      assert.are_not.equal(name, Chat.syncChannel("Other Friends"))
      assert.is_falsy(name:lower():find("friends", 1, true)) -- the community name does not show
    end)

    it("has none without a name", function()
      assert.is_nil(Chat.syncChannel(nil))
      assert.is_nil(Chat.syncChannel("   "))
    end)
  end)
end)
