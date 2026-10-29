local helpers = require("helpers")

describe("Loot and Play (CF-53)", function()
  local Loot, Play, Feed
  local TODAY = 20744
  local ADA = { guid = "G-A", name = "Ada Example", classFile = "ROGUE" }
  local FORMATS = {
    looted = "You receive loot: %s.", lootedMultiple = "You receive loot: %sx%d.",
    pushed = "You receive item: %s.", pushedMultiple = "You receive item: %sx%d.",
    created = "You create: %s.", createdMultiple = "You create: %sx%d.",
  }

  local function link(id, name, color)
    return string.format("|cff%s|Hitem:%d::::::::60:::::|h[%s]|h|r", color or "ffffff", id, name)
  end

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    Feed = helpers.loadAddonFile("src/core/Feed.lua", ns)
    Loot = helpers.loadAddonFile("src/core/Loot.lua", ns)
    Play = helpers.loadAddonFile("src/core/Play.lua", ns)
  end)

  describe("loot messages", function()
    it("reads looted items, quest rewards and created items with their count", function()
      assert.are.same({ source = "looted", id = 2589, name = "Linen Cloth", count = 3, color = "ffffff" },
        Loot.parse("You receive loot: " .. link(2589, "Linen Cloth") .. "x3.", FORMATS))
      assert.are.same({ source = "looted", id = 19970, name = "Arcanite Fishing Pole", count = 1, color = "0070dd" },
        Loot.parse("You receive item: " .. link(19970, "Arcanite Fishing Pole", "0070dd") .. ".", FORMATS))
      assert.are.same({ source = "created", id = 14342, name = "Mooncloth", count = 1, color = "ffffff" },
        Loot.parse("You create: " .. link(14342, "Mooncloth") .. ".", FORMATS))
    end)

    it("ignores other players' loot and other messages", function()
      assert.is_nil(Loot.parse("Bob Example receives loot: " .. link(2589, "Linen Cloth") .. ".", FORMATS))
      assert.is_nil(Loot.parse("You receive loot: nothing.", FORMATS))
      assert.is_nil(Loot.parse("You receive loot: " .. link(2589, "Linen Cloth") .. ".", {}))
      assert.is_nil(Loot.parse(nil, FORMATS))
    end)

    it("counts blues, lists epics with slot and level, and the watch list", function()
      local blue = { source = "looted", id = 1, count = 2 }
      assert.are.same({ { kind = "rare", count = 2 } }, Loot.events(blue, 3, "INVTYPE_HEAD", 30))
      local epic = { source = "looted", id = 12784, name = "Arcanite Reaper", count = 1 }
      assert.are.same(
        { { kind = "epic", id = 12784, name = "Arcanite Reaper", slot = "INVTYPE_2HWEAPON", level = 60 } },
        Loot.events(epic, 4, "INVTYPE_2HWEAPON", 60)) -- looted, not created: not notable
      assert.are.same({ { kind = "epic", id = 9, slot = nil, level = 40 } },
        Loot.events({ source = "looted", id = 9, color = "a335ee", count = 1 }, nil, "", 40))
      local created = { source = "created", id = 12784, name = "Arcanite Reaper", count = 1 }
      assert.are.same({ { kind = "notable", id = 12784, count = 1 } }, Loot.events(created, 4, "INVTYPE_2HWEAPON", 60))
      local fish = { source = "looted", id = 19807, count = 2 }
      assert.are.same({ { kind = "notable", id = 19807, count = 2 } }, Loot.events(fish, 1, "", 40))
      assert.are.same({}, Loot.events({ source = "looted", id = 5, count = 1 }, 2, "", 40))
      assert.are.same({}, Loot.events(nil))
    end)

    it("splits a money change into gained and spent", function()
      assert.are.same({ kind = "gold", gained = 50, spent = 0 }, Loot.gold(100, 150))
      assert.are.same({ kind = "gold", gained = 0, spent = 30 }, Loot.gold(100, 70))
      assert.is_nil(Loot.gold(nil, 70))
      assert.is_nil(Loot.gold(70, 70))
    end)
  end)

  describe("feed", function()
    it("adds loot, notable items, gold, sessions and groups", function()
      local feed = {}
      Feed.add(feed, TODAY, ADA, { kind = "rare", count = 2 }, 1)
      Feed.add(feed, TODAY, ADA, { kind = "epic", id = 9, name = "Big Sword", slot = "INVTYPE_WEAPON", level = 40 }, 2)
      Feed.add(feed, TODAY, ADA, { kind = "notable", id = 14342, count = 1 }, 3)
      Feed.add(feed, TODAY, ADA, { kind = "notable", id = 14342, count = 2 }, 3)
      Feed.add(feed, TODAY, ADA, { kind = "gold", gained = 50, spent = 0 }, 4)
      Feed.add(feed, TODAY, ADA, { kind = "gold", gained = 0, spent = 20 }, 5)
      Feed.add(feed, TODAY, ADA, { kind = "session", from = 6 }, 6)
      Feed.add(feed, TODAY, ADA, { kind = "group", guid = "G-B" }, 7)
      local e = feed[TODAY]["G-A"]
      assert.are.same({ rare = 2, epic = { { id = 9, name = "Big Sword", slot = "INVTYPE_WEAPON", level = 40 } } },
        e.loot)
      assert.are.same({ [14342] = 3 }, e.notable)
      assert.are.same({ gained = 50, spent = 20 }, e.gold)
      assert.are.same({ { from = 6, to = 6 } }, e.sessions)
      assert.are.same({ ["G-B"] = true }, e.groups)
    end)

    it("cleans received loot, notable items, gold, sessions and groups", function()
      local clean = Feed.clean({ [TODAY] = { ["G-A"] = { at = 1,
        loot = { rare = 2.5, epic = { { id = 9, name = "Big| Sword", slot = "INVTYPE_WEAPON", level = 40 },
                                      { id = "x" }, { id = 10, slot = "BAD" } } },
        notable = { [14342] = 2, ["14342"] = 1, [0.5] = 1, [12784] = -1 },
        gold = { gained = 5, spent = "x" },
        sessions = { { from = 10, to = 20 }, { from = 30, to = 20 }, { from = 40 } },
        groups = { ["G-B"] = true, ["G-C"] = "yes" },
      } } })[TODAY]["G-A"]
      assert.are.same({ rare = 2, epic = { { id = 9, name = "Big Sword", slot = "INVTYPE_WEAPON", level = 40 },
                                           { id = 10 } } }, clean.loot)
      assert.are.same({ [14342] = 2, [12784] = 0 }, clean.notable)
      assert.is_nil(clean.gold)
      assert.are.same({ { from = 10, to = 20 } }, clean.sessions)
      assert.are.same({ ["G-B"] = true }, clean.groups)
    end)
  end)

  describe("sessions", function()
    it("continues the last session within 5 minutes, also across feed days", function()
      local feed = {}
      Feed.add(feed, TODAY - 1, ADA, { kind = "session", from = 1000 }, 1000)
      local session, entry = Play.last(feed, "G-A")
      Play.touch(session, entry, 4000)
      assert.are.same({ from = 1000, to = 4000 }, feed[TODAY - 1]["G-A"].sessions[1])
      assert.is_table(Play.resume(feed, "G-A", 4200))
      assert.are.equal(4200, feed[TODAY - 1]["G-A"].sessions[1].to)
      assert.are.equal(4200, feed[TODAY - 1]["G-A"].at)
      assert.is_nil(Play.resume(feed, "G-A", 4200 + Play.CONTINUE + 1))
      assert.is_nil(Play.resume(feed, "G-B", 4200))
    end)

    it("never moves a session's end backwards", function()
      local session = { from = 10, to = 50 }
      Play.touch(session, nil, 40)
      assert.are.equal(50, session.to)
    end)
  end)
end)
