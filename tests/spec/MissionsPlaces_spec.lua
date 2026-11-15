local helpers = require("helpers")

describe("Missions: places (CF-73)", function()
  local ns, Places

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Places.lua", ns)
    Places = ns.Missions.Places
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Places)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/places.json")
    assert.is_true(#cases.cases > 0)
    for _, case in ipairs(cases.cases) do
      local day, week = ns.Goals.newFacts(), ns.Goals.newFacts()
      for _, obs in ipairs(case.observations) do
        ns.Goals.observe(day, obs)
        ns.Goals.observe(week, obs)
      end
      for id, expected in pairs(case.progress) do
        local f = ns.Goals.progressFacts(id:sub(1, 1) == "w" and week or day)
        local value, target, done = ns.Doomsday.progress(id, f)
        assert.are.same(expected, { value, target, done }, case.name .. ": " .. id)
      end
    end
  end)

  it("registers the progress of its 9 dailies, all in the catalogue", function()
    local dailies = { "d.sameZone", "d.online3", "d.carry", "d.chatHello", "d.roam4", "d.newZone", "d.crossSea",
                      "d.nostalgia", "d.daredevil" }
    for _, id in ipairs(dailies) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("registers the weeklies that read its data", function()
    for _, id in ipairs({ "w.chatDays5", "w.mentor3", "w.newZones3", "w.roam10" }) do
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("keeps its facts under its own key", function()
    local f = ns.Goals.newFacts()
    assert.is_nil(f.places)
    ns.Goals.observe(f, { kind = "placeChat", day = 1 })
    assert.are.equal(1, f.places.chat)
    assert.are.equal(f.places, ns.Goals.progressFacts(f).places)
  end)

  it("ignores observations with missing fields", function()
    local f = ns.Goals.newFacts()
    for _, kind in ipairs({ "placeZone", "placeFriends", "placeGroup" }) do
      ns.Goals.observe(f, { kind = kind })
    end
    for _, id in ipairs(Places.IDS) do
      assert.is_false(select(3, ns.Doomsday.progress(id, ns.Goals.progressFacts(f))), id)
    end
  end)

  it("caps the zones of a day or week, and keeps counting zones already in", function()
    local f = ns.Goals.newFacts()
    for i = 1, Places.MAX_ZONES + 10 do
      ns.Goals.observe(f, { kind = "placeZone", guid = "Player-1-A", zone = "Zone " .. i, new = true })
    end
    ns.Goals.observe(f, { kind = "placeZone", guid = "Player-1-A", zone = "Zone 1", new = false })
    local pf = ns.Goals.progressFacts(f)
    assert.are.equal(Places.MAX_ZONES, (ns.Doomsday.progress("w.roam10", pf)))
    assert.are.equal(Places.MAX_ZONES, (ns.Doomsday.progress("w.newZones3", pf)))
  end)

  describe("owners", function()
    it("maps friends' characters to their BattleTag, own ones left out", function()
      local people = { ["Ada#1001"] = { chars = { ["Player-1-F"] = {} } },
                       ["Me#1000"] = { chars = { ["Player-1-M"] = {} } } }
      local presence = { ["Player-1-P"] = { battleTag = "Bob#1002" }, ["Player-1-N"] = { battleTag = "Me#1000" } }
      assert.are.same({ ["Player-1-F"] = "Ada#1001", ["Player-1-P"] = "Bob#1002" },
        Places.owners(people, presence, "Me#1000"))
    end)

    it("prefers the synced record over presence", function()
      local people = { ["Ada#1001"] = { chars = { ["Player-1-F"] = {} } } }
      local presence = { ["Player-1-F"] = { battleTag = "Bob#1002" } }
      assert.are.equal("Ada#1001", Places.owners(people, presence, "Me#1000")["Player-1-F"])
    end)

    it("is empty on missing data", function()
      assert.are.same({}, Places.owners(nil, nil, nil))
      assert.are.same({}, Places.owners({ ["Ada#1001"] = "broken" }, { ["Player-1-P"] = "broken" }, nil))
    end)
  end)

  describe("friendsNow", function()
    local byGuid = { ["Player-1-F"] = "Ada#1001", ["Player-1-G"] = "Ada#1001", ["Player-1-P"] = "Bob#1002",
                     ["Player-1-Q"] = "Cy#1003" }

    it("counts friends in game once each, and finds one in the same zone", function()
      local members = {
        ["Player-1-F"] = { zone = "Duskwood", presence = 1 },
        ["Player-1-G"] = { zone = "Westfall", presence = 4 }, -- Ada's alt: still one friend
        ["Player-1-P"] = { zone = "Westfall", presence = 5 },
        ["Player-1-Q"] = { zone = "Westfall", presence = 3 }, -- offline
        ["Player-1-X"] = { zone = "Westfall", presence = 1 }, -- a stranger
      }
      local n, same = Places.friendsNow(members, byGuid, "Duskwood")
      assert.are.equal(2, n)
      assert.is_true(same)
      n, same = Places.friendsNow(members, byGuid, "Elwynn Forest")
      assert.are.equal(2, n)
      assert.is_false(same)
    end)

    it("never counts the app or an offline friend in the same zone", function()
      local members = { ["Player-1-P"] = { zone = "Duskwood", presence = 2 },
                        ["Player-1-Q"] = { zone = "Duskwood", presence = 3 } }
      local n, same = Places.friendsNow(members, byGuid, "Duskwood")
      assert.are.equal(0, n)
      assert.is_false(same)
    end)

    it("is never the same zone without an own zone", function()
      local members = { ["Player-1-P"] = { presence = 1 } }
      local n, same = Places.friendsNow(members, byGuid, nil)
      assert.are.equal(1, n)
      assert.is_false(same)
    end)

    it("is 0 on missing data", function()
      assert.are.equal(0, (Places.friendsNow(nil, byGuid, "Duskwood")))
      assert.are.equal(0, (Places.friendsNow({ ["Player-1-P"] = { presence = 1 } }, nil, "Duskwood")))
    end)
  end)

  describe("carry", function()
    local byGuid = { ["Player-1-F"] = "Ada#1001" }
    local members = { ["Player-1-F"] = { level = 15 }, ["Player-1-X"] = { level = 1 } }

    it("is true with a friend's community character 5 or more levels lower", function()
      assert.is_true(Places.carry({ "Player-1-F" }, members, byGuid, {}, 20))
      assert.is_false(Places.carry({ "Player-1-F" }, members, byGuid, {}, 19))
    end)

    it("never counts strangers or characters outside the community", function()
      assert.is_false(Places.carry({ "Player-1-X" }, members, byGuid, {}, 60))
      assert.is_false(Places.carry({ "Player-1-F" }, {}, byGuid, {}, 60))
    end)

    it("reads the friend's synced level when the member has none", function()
      local people = { ["Ada#1001"] = { chars = { ["Player-1-F"] = { level = 10 } } } }
      assert.is_true(Places.carry({ "Player-1-F" }, { ["Player-1-F"] = {} }, byGuid, people, 15))
      assert.is_false(Places.carry({ "Player-1-F" }, { ["Player-1-F"] = {} }, byGuid, {}, 60))
    end)

    it("takes the synced level when the member list's is behind (CF-123)", function()
      local people = { ["Ada#1001"] = { chars = { ["Player-1-F"] = { level = 17 } } } }
      assert.is_false(Places.carry({ "Player-1-F" }, members, byGuid, people, 21)) -- 17, not the roster's 15
      assert.is_true(Places.carry({ "Player-1-F" }, members, byGuid, people, 22))
    end)

    it("is false without the own level or a group", function()
      assert.is_false(Places.carry({ "Player-1-F" }, members, byGuid, {}, nil))
      assert.is_false(Places.carry(nil, members, byGuid, {}, 60))
    end)
  end)

  describe("ownMessage", function()
    local own = { ["Player-1-A"] = true }

    it("is an own message in the selected community's channel", function()
      assert.is_true(Places.ownMessage("Community:1:1", "Community:1:1", "Player-1-A", own))
    end)

    it("is not a friend's message, another channel or without a selection", function()
      assert.is_false(Places.ownMessage("Community:1:1", "Community:1:1", "Player-1-F", own))
      assert.is_false(Places.ownMessage("Community:2:1", "Community:1:1", "Player-1-A", own))
      assert.is_false(Places.ownMessage("Community:1:1", nil, "Player-1-A", own))
      assert.is_false(Places.ownMessage("Community:1:1", "Community:1:1", nil, own))
    end)
  end)

  describe("continent", function()
    it("is 0 or 1 outside instances only", function()
      assert.are.equal(0, Places.continent("none", 0))
      assert.are.equal(1, Places.continent("none", 1))
      assert.is_nil(Places.continent("party", 1))
      assert.is_nil(Places.continent("none", 369))
      assert.is_nil(Places.continent(nil, nil))
    end)
  end)

  describe("zoneRanges", function()
    it("keeps zone activities by full and short name, never dungeons", function()
      local ranges = Places.zoneRanges({
        { name = "Elwynn Forest", shortName = "Elwynn", min = 1, max = 10, difficultyID = 0, maxNumPlayers = 0 },
        { name = "Ruins of Lordaeron", shortName = "Ruins", min = 15, max = 22, difficultyID = 1, maxNumPlayers = 5 },
        { name = "Broken", min = 0, max = 0, difficultyID = 0, maxNumPlayers = 0 },
        { name = "No levels", difficultyID = 0, maxNumPlayers = 0 },
        "junk",
      })
      assert.are.same({ min = 1, max = 10 }, ranges["Elwynn Forest"])
      assert.are.same({ min = 1, max = 10 }, ranges["Elwynn"])
      assert.is_nil(ranges["Ruins of Lordaeron"])
      assert.is_nil(ranges["Broken"])
      assert.is_nil(ranges["No levels"])
    end)

    it("is empty on missing data", function()
      assert.are.same({}, Places.zoneRanges(nil))
    end)
  end)

  describe("zones seen", function()
    it("seeds the quest zones of the stored feed per character, never Other", function()
      local feed = {
        [100] = { ["Player-1-A"] = { quests = { ["Elwynn Forest"] = 3, Other = 1 } } },
        [101] = { ["Player-1-A"] = { quests = { Westfall = 1 } }, ["Player-1-B"] = { quests = { Durotar = 2 } },
                  ["Player-1-C"] = { name = "No quests" } },
      }
      assert.are.same({
        ["Player-1-A"] = { ["Elwynn Forest"] = true, Westfall = true },
        ["Player-1-B"] = { Durotar = true },
      }, Places.seedZones(feed))
      assert.are.same({}, Places.seedZones(nil))
    end)

    it("marks a zone once per character", function()
      local seen = {}
      assert.is_true(Places.markZone(seen, "Player-1-A", "Duskwood"))
      assert.is_false(Places.markZone(seen, "Player-1-A", "Duskwood"))
      assert.is_true(Places.markZone(seen, "Player-1-B", "Duskwood"))
      assert.is_false(Places.markZone(seen, "Player-1-A", nil))
      assert.is_false(Places.markZone(nil, "Player-1-A", "Duskwood"))
    end)
  end)
end)
