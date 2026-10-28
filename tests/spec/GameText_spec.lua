local helpers = require("helpers")

describe("GameText", function()
  local GameText
  local FORMATS = { retreat = "%2$s has fled from %1$s in a duel" }

  before_each(function()
    GameText = helpers.loadAddonFile("src/core/GameText.lua", helpers.coreNs())
  end)

  describe("format strings", function()
    it("turns positional and plain arguments into a pattern", function()
      local args = GameText.parse("Bob Example has fled from Ada Example in a duel", FORMATS.retreat)
      assert.are.same({ "Ada Example", "Bob Example" }, args)
      args = GameText.parse("Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)",
        "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)")
      assert.are.same({ "Grim Tusk", "Grunt", "12" }, args)
      assert.is_nil(GameText.parse("You have been awarded 50 honor points.", "%s dies, honorable kill Rank: %s"))
      assert.is_nil(GameText.parse("anything", "no arguments"))
      assert.is_nil(GameText.parse("anything", nil))
    end)

    it("escapes magic characters of the format string", function()
      assert.are.same({ "x" }, GameText.parse("(100%) x.", "(100%%) %s."))
      assert.is_nil(GameText.parse("(100%) xy", "(100%%) %s."))
    end)
  end)

  it("reads the item ID and name of an item link", function()
    assert.are.same({ 12784, "Arcanite Reaper" },
      { GameText.item("You receive loot: |cffa335ee|Hitem:12784::::::::60:::::|h[Arcanite Reaper]|h|r.") })
    assert.is_nil(GameText.item("You receive loot: nothing"))
    assert.is_nil(GameText.item(nil))
  end)
end)
