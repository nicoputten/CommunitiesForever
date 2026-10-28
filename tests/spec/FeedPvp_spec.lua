local helpers = require("helpers")

describe("Feed: kills, deaths and duels (CF-52)", function()
  local Feed, Merge
  local TODAY = 20744
  local ADA = { guid = "G-A", name = "Ada Example", classFile = "ROGUE" }

  before_each(function()
    local ns = {}
    Feed = helpers.loadAddonFile("src/core/Feed.lua", ns)
    helpers.loadAddonFile("src/core/Pvp.lua", ns)
    Merge = helpers.loadAddonFile("src/core/Merge.lua", ns)
  end)

  it("adds kills by zone, deaths and duels to the day's entry", function()
    local feed = {}
    Feed.add(feed, TODAY, ADA, { kind = "kills", zone = "Ashenvale", count = 2 }, 10)
    Feed.add(feed, TODAY, ADA, { kind = "kills", zone = "Ashenvale" }, 11)
    Feed.add(feed, TODAY, ADA, { kind = "kills", count = 1 }, 12)
    Feed.add(feed, TODAY, ADA, { kind = "death", t = 13, zone = "Ashenvale", cause = "player" }, 13)
    Feed.add(feed, TODAY, ADA, { kind = "duel", t = 14, won = true, vs = "Bob Example" }, 14)
    local entry = feed[TODAY][ADA.guid]
    assert.are.same({ Ashenvale = 3, Other = 1 }, entry.kills)
    assert.are.same({ { t = 13, zone = "Ashenvale", cause = "player" } }, entry.deaths)
    assert.are.same({ { t = 14, won = true, vs = "Bob Example" } }, entry.duels)
    assert.are.equal(14, entry.at)
  end)

  it("caps deaths and duels at 50 per day and character", function()
    local feed = {}
    for i = 1, 60 do
      Feed.add(feed, TODAY, ADA, { kind = "death", t = i, cause = "fall" }, i)
      Feed.add(feed, TODAY, ADA, { kind = "duel", t = i, won = false, vs = "Bob Example" }, i)
    end
    assert.are.equal(50, #feed[TODAY][ADA.guid].deaths)
    assert.are.equal(50, #feed[TODAY][ADA.guid].duels)
  end)

  it("cleans received kills, deaths and duels", function()
    local deaths, duels = {}, {}
    for i = 1, 60 do
      deaths[i] = { t = i, zone = "Duskwood", cause = "fall" }
      duels[i] = { t = i, won = true, vs = "Bob Example" }
    end
    deaths[1] = { t = 1, zone = "Dusk|cwood", cause = "boredom", extra = 1 }
    deaths[2] = { zone = "no time" }
    duels[1] = { t = 1, won = "yes", vs = "Bob Example" }
    duels[2] = { t = 2, won = true }
    local clean = Feed.clean({ [TODAY] = { ["G-A"] = { at = 5, kills = { Ashenvale = 3.5, ["Ha|ck"] = -2, x = "y" },
                                                          deaths = deaths, duels = duels } } })
    local entry = clean[TODAY]["G-A"]
    assert.are.same({ Ashenvale = 3, Hack = 0 }, entry.kills)
    assert.are.same({ t = 1, zone = "Duskcwood", cause = "other" }, entry.deaths[1])
    assert.are.equal(3, entry.deaths[2].t)
    assert.are.equal(50, #entry.deaths)
    assert.are.equal(3, entry.duels[1].t)
    assert.are.equal(50, #entry.duels)
    local none = Feed.clean({ [TODAY] = { ["G-A"] = { at = 5, kills = "x", deaths = 3, duels = { "x" } } } })
    assert.is_nil(none[TODAY]["G-A"].kills)
    assert.is_nil(none[TODAY]["G-A"].deaths)
    assert.is_nil(none[TODAY]["G-A"].duels)
  end)

  it("adds raw kills up to 100 a day, and cleans received ones (CF-55b)", function()
    local feed = {}
    for i = 1, 105 do Feed.add(feed, TODAY, ADA, { kind = "pvpKill", kill = { t = i, name = "V" .. i } }, i) end
    assert.are.equal(100, #feed[TODAY][ADA.guid].pvpKills)
    local kills = {
      { t = 1, zone = "Ashenvale", name = "Grim Tusk", lvl = -1, myLvl = 30, class = "WARLOCK", race = "NightElf",
        rank = 4, solo = true, bg = false, extra = "x" },
      { t = 2, lvl = 0, myLvl = 0, class = "warlock", race = "Night Elf", rank = 30, solo = "yes" },
      { t = 3, lvl = 61.5, class = "|cffWARLOCK", name = "Bad|Name" },
      { zone = "no time" },
    }
    local clean = Feed.clean({ [TODAY] = { ["G-A"] = { at = 1, pvpKills = kills } } })[TODAY]["G-A"].pvpKills
    assert.are.same({ t = 1, zone = "Ashenvale", name = "Grim Tusk", lvl = -1, myLvl = 30, class = "WARLOCK",
                      race = "NightElf", rank = 4, solo = true }, clean[1])
    assert.are.same({ t = 2, rank = 14 }, clean[2])
    assert.are.same({ t = 3, name = "BadName" }, clean[3])
    assert.are.equal(3, #clean)
  end)

  it("sends a week with 100 raw kills on each of 7 days in under 8 KB (CF-55b: the cap stays at 100)", function()
    local ns = {}
    helpers.loadAddonFile("src/core/Protocol.lua", ns)
    local codec = ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
    local classes = { "WARRIOR", "MAGE", "ROGUE", "PRIEST", "HUNTER", "WARLOCK", "DRUID", "PALADIN" }
    local races, zones = { "Human", "Dwarf", "NightElf", "Gnome" }, { "Ashenvale", "Hillsbrad Foothills", "Desolace" }
    local feed = {}
    for d = 1, 7 do
      local kills = {}
      for i = 1, 100 do
        kills[i] = { t = 1793210000 + d * 86400 + i * 97, zone = zones[i % 3 + 1],
                     name = "Enemy" .. (i * 7919 % 211) .. " Lastname" .. d, lvl = 20 + i % 40, myLvl = 40,
                     class = classes[i % 8 + 1], race = races[i % 4 + 1], rank = i % 6, solo = i % 2 == 0 or nil }
      end
      feed[TODAY - 7 + d] = { ["G-A"] = { name = "Ada Example", classFile = "ROGUE", at = 1, pvpKills = kills } }
    end
    local encoded = codec:encode({ t = "RECORD", bt = "Ada#1001", version = 1, chars = {}, feed = feed })
    assert.is_true(#encoded < 8000, "encoded " .. #encoded .. " bytes")
  end)

  it("keeps the stored entry when a relayed copy has the same time (an older client drops new fields)", function()
    local stored = { [TODAY] = { ["G-A"] = { at = 5, kills = { Ashenvale = 3 } } } }
    local relayed = { [TODAY] = { ["G-A"] = { at = 5 } } }
    assert.are.same({ Ashenvale = 3 }, Feed.merge(stored, relayed)[TODAY]["G-A"].kills)
    local newer = { [TODAY] = { ["G-A"] = { at = 6 } } }
    assert.is_nil(Feed.merge(stored, newer)[TODAY]["G-A"].kills)
  end)

  it("stores a received character's PvP data cleaned, and an older record without it as before", function()
    local people = {}
    Merge.store(people, { bt = "Ada#1001", version = 10, chars = {
      ["G-A"] = { name = "Ada Example", level = 30, updatedAt = 5,
                  pvp = { hk = 12, rank = 2, rankName = "Gr|unt", bogus = true } },
      ["G-B"] = { name = "Ada Alt", level = 5, updatedAt = 5 },
    } }, 100, "Ada#1001")
    assert.are.same({ hk = 12, rank = 2, rankName = "Grunt" }, people["Ada#1001"].chars["G-A"].pvp)
    assert.is_nil(people["Ada#1001"].chars["G-B"].pvp)
  end)
end)
