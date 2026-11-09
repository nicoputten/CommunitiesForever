local helpers = require("helpers")

describe("Reach (CF-112)", function()
  local Reach
  local FORMAT = "No player named '%s' is currently playing."

  before_each(function()
    Reach = helpers.loadAddonFile("src/core/Reach.lua", helpers.coreNs())
  end)

  describe("names", function()
    it("compares without case and without a -Realm suffix", function()
      assert.is_true(Reach.sameName("Dee Example", "dee example"))
      assert.is_true(Reach.sameName("Dee Example", "Dee Example-ClassicBetaPvP"))
      assert.is_true(Reach.sameName("Dee Example-Other", "Dee Example-ClassicBetaPvP"))
      assert.is_false(Reach.sameName("Dee Example", "Dee Examples"))
      assert.is_false(Reach.sameName(nil, nil))
      assert.is_false(Reach.sameName("", ""))
      assert.is_nil(Reach.key(42))
    end)
  end)

  describe("the game's \"No player named\" line", function()
    it("gives the name, as the game wrote it", function()
      assert.are.equal("Dee Example", Reach.notFoundName(FORMAT, "No player named 'Dee Example' is currently playing."))
      assert.are.equal("Dee Example-ClassicBetaPvP",
        Reach.notFoundName(FORMAT, "No player named 'Dee Example-ClassicBetaPvP' is currently playing."))
    end)

    it("reads a name with characters that are magic in Lua patterns", function()
      assert.are.equal("Zoë (Al%t)", Reach.notFoundName(FORMAT, "No player named 'Zoë (Al%t)' is currently playing."))
    end)

    it("falls back to the English text with other quotes, none, or no period", function()
      assert.are.equal("Dee Example", Reach.notFoundName(nil, "No player named 'Dee Example' is currently playing."))
      assert.are.equal("Dee Example", Reach.notFoundName("Kein Spieler '%s'.",
        'No player named "Dee Example" is currently playing.'))
      assert.are.equal("Dee Example", Reach.notFoundName(FORMAT, "No player named Dee Example is currently playing"))
    end)

    it("ignores other lines and non-strings", function()
      assert.is_nil(Reach.notFoundName(FORMAT, "You are now away."))
      assert.is_nil(Reach.notFoundName(FORMAT, "No player named '' is currently playing."))
      assert.is_nil(Reach.notFoundName(FORMAT, nil))
      assert.is_nil(Reach.notFoundName(FORMAT, ""))
    end)
  end)

  describe("matching a failure to our whisper", function()
    it("finds the name we whispered within the window, also when the line adds a realm", function()
      local whispered = { ["Dee Example"] = 100, ["Bo Example"] = 105 }
      assert.are.equal("Dee Example", Reach.matchFailure(whispered, "Dee Example-ClassicBetaPvP", 101))
      assert.are.equal("Dee Example", Reach.matchFailure(whispered, "dee example", 100 + Reach.FAILED_WINDOW))
      assert.is_nil(Reach.matchFailure(whispered, "Dee Example", 101 + Reach.FAILED_WINDOW))
      assert.is_nil(Reach.matchFailure(whispered, "Someone Else", 101)) -- a whisper the player typed
    end)

    it("takes the latest of two forms of the same name", function()
      local whispered = { ["Dee Example"] = 100, ["Dee Example-ClassicBetaPvP"] = 103 }
      assert.are.equal("Dee Example-ClassicBetaPvP", Reach.matchFailure(whispered, "Dee Example", 104))
    end)

    it("prunes old whispers", function()
      local whispered = { a = 1, b = 50, c = "x" }
      Reach.prune(whispered, 50)
      assert.are.same({ b = 50 }, whispered)
    end)
  end)

  describe("who may be whispered", function()
    local reach
    before_each(function() reach = Reach.new() end)

    it("is unknown without any source, and only allowed then when the caller says so", function()
      assert.are.equal("unknown", reach:status("Dee Example", nil, 10))
      assert.is_false((reach:mayWhisper("Dee Example", nil, 10)))
      assert.is_true((reach:mayWhisper("Dee Example", nil, 10, true)))
      assert.are.equal("unknown", reach:status(nil, nil, 10))
    end)

    it("follows the community presence", function()
      reach:presence("Dee Example", true, 10)
      assert.are.equal("online", reach:status("Dee Example", nil, 11))
      reach:presence("Dee Example", false, 20)
      assert.are.equal("offline", reach:status("Dee Example", nil, 21))
      assert.is_false((reach:mayWhisper("Dee Example", nil, 21, true)))
    end)

    it("lets Battle.net decide when it knows: on this character, or on another one", function()
      reach:presence("Dee Example", true, 10)
      assert.are.equal("offline", reach:status("Dee Example", false, 11))
      reach:presence("Dee Example", false, 12)
      assert.are.equal("online", reach:status("Dee Example", true, 13))
    end)

    it("takes the fresher of a message heard and the presence", function()
      reach:presence("Dee Example", false, 10)
      reach:heard("Dee Example", 20) -- they logged in, the community list has not caught up
      assert.are.equal("online", reach:status("Dee Example", nil, 21))
      reach:presence("Dee Example", true, 22)
      reach:presence("Dee Example", false, 30) -- then they logged out
      assert.are.equal("offline", reach:status("Dee Example", nil, 31))
      reach:heard("Bo Example", 40)
      assert.are.equal("online", reach:status("Bo Example", nil, 40 + Reach.HEARD_FRESH))
      assert.are.equal("unknown", reach:status("Bo Example", nil, 41 + Reach.HEARD_FRESH))
    end)

    it("blocks a name after a failed whisper, whatever presence and Battle.net say, until heard again", function()
      reach:presence("Dee Example", true, 10)
      reach:failed("Dee Example", 11)
      assert.are.equal("failed", reach:status("Dee Example", nil, 12))
      assert.are.equal("failed", reach:status("dee example-ClassicBetaPvP", true, 12))
      assert.is_false((reach:mayWhisper("Dee Example", nil, 12, true)))
      reach:presence("Dee Example", true, 20) -- still online on the stale list: no change
      assert.are.equal("failed", reach:status("Dee Example", nil, 1000))
      assert.are.same({ ["dee example"] = 11 }, reach:blocked())
      reach:heard("Dee Example-ClassicBetaPvP", 1001)
      assert.are.equal("online", reach:status("Dee Example", nil, 1002))
      assert.are.same({}, reach:blocked())
    end)

    it("lifts a block when the presence goes offline and then online again", function()
      reach:presence("Dee Example", true, 10)
      reach:failed("Dee Example", 11)
      reach:presence("Dee Example", false, 12)
      assert.are.equal("failed", reach:status("Dee Example", nil, 13))
      reach:presence("Dee Example", true, 50)
      assert.are.equal("online", reach:status("Dee Example", nil, 51))
    end)

    it("orders names to ask: online first, then unknown, without offline or blocked ones", function()
      local statuses = { a = "unknown", b = "online", c = "offline", d = "failed", e = "online", f = "unknown" }
      assert.are.same({ "b", "e", "a", "f" },
        Reach.order({ "a", "b", "c", "d", "e", "f" }, function(name) return statuses[name] end))
      assert.are.same({}, Reach.order(nil, function() return "online" end))
    end)
  end)
end)
