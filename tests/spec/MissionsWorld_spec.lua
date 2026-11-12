local helpers = require("helpers")

describe("Missions: world (CF-76)", function()
  local ns, World

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/missions/World.lua", ns)
    World = ns.Missions.World
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.World)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/world.json")
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

  local DAILIES = { "d.kills30", "d.elite", "d.rareMob", "d.bigFoe", "d.streak20", "d.duoHunt", "d.weaponSkill",
                    "d.flight", "d.newFlight", "d.hearth", "d.ride", "d.swim", "d.places10", "d.whisper",
                    "d.groupPic", "d.mailFriend", "d.vendorBuy", "d.vendorSale", "d.repair", "d.trainer", "d.bank",
                    "d.summoned", "d.auctionPost", "d.auctionBuy" }
  local WEEKLIES = { "w.kills200", "w.elites10", "w.weapon25", "w.flightPaths3" }

  it("registers the progress of its 24 dailies, all in the catalogue", function()
    assert.are.equal(24, #DAILIES)
    for _, id in ipairs(DAILIES) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("registers the weeklies that read its data", function()
    for _, id in ipairs(WEEKLIES) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
    assert.are.equal(#DAILIES + #WEEKLIES, #World.IDS)
  end)

  it("leaves the missions that still wait, and CF-75's, unregistered", function()
    for _, id in ipairs({ "d.bind", "d.mailbox", "d.restock",
                          "d.wave", "d.bandageUp", "d.coins10" }) do
      assert.is_nil(ns.Doomsday.progress(id, {}), id)
    end
  end)

  it("puts its missions in pool version 3 (CF-99), d.summoned and d.auctionPost in 4 (CF-104)", function()
    local four = { ["d.summoned"] = true, ["d.auctionPost"] = true }
    for _, id in ipairs(World.IDS) do
      assert.are.equal(id == "d.auctionBuy" and 6 or four[id] and 4 or 3, ns.Doomsday.goal(id).since, id)
    end
  end)

  it("keeps its facts under its own key", function()
    local f = ns.Goals.newFacts()
    assert.is_nil(f.world)
    ns.Goals.observe(f, { kind = "worldAction", action = "bank" })
    assert.are.equal(1, f.world.bank)
    assert.are.equal(f.world, ns.Goals.progressFacts(f).world)
  end)

  it("ignores observations with missing fields", function()
    local f = ns.Goals.newFacts()
    for _, kind in ipairs({ "worldDeath", "worldMove", "worldPlace", "worldAction" }) do
      ns.Goals.observe(f, { kind = kind })
    end
    for _, id in ipairs(World.IDS) do
      assert.is_false(select(3, ns.Doomsday.progress(id, ns.Goals.progressFacts(f))), id)
    end
  end)

  it("caps the places of a day", function()
    local f = ns.Goals.newFacts()
    for i = 1, World.MAX_PLACES + 10 do
      ns.Goals.observe(f, { kind = "worldPlace", zone = "Elwynn Forest", subzone = "Place " .. i })
    end
    assert.are.equal(World.MAX_PLACES, (ns.Doomsday.progress("d.places10", ns.Goals.progressFacts(f))))
  end)

  describe("classifications", function()
    it("knows the game's elite and rare strings", function()
      assert.is_true(World.isElite("elite"))
      assert.is_true(World.isElite("rareelite"))
      assert.is_true(World.isElite("worldboss"))
      assert.is_false(World.isElite("rare"))
      assert.is_false(World.isElite("normal"))
      assert.is_false(World.isElite(nil))
      assert.is_true(World.isRare("rare"))
      assert.is_true(World.isRare("rareelite"))
      assert.is_false(World.isRare("elite"))
      assert.is_false(World.isRare("trivial"))
    end)

    it("finds a big foe by level or skull", function()
      assert.is_true(World.isBigFoe(23, 20))
      assert.is_false(World.isBigFoe(22, 20))
      assert.is_true(World.isBigFoe(-1, 60))
      assert.is_false(World.isBigFoe(nil, 20))
      assert.is_false(World.isBigFoe(25, nil))
    end)
  end)

  describe("victim", function()
    local function prefix(format)
      local p = ns.GameText.pattern((format:gsub("%.$", "")))
      return p:sub(1, -2)
    end
    local FORMAT = "%s dies, you gain %d experience."

    it("reads the creature's name, also with bonus text after the message", function()
      local p = prefix(FORMAT)
      assert.are.equal("Defias Thug", World.victim("Defias Thug dies, you gain 45 experience.", p))
      assert.are.equal("Kobold Vermin",
        World.victim("Kobold Vermin dies, you gain 30 experience. (+15 exp Rested bonus)", p))
      assert.are.equal("Murloc", World.victim("Murloc dies, you gain 12 experience. (-4 exp Group bonus)", p))
    end)

    it("is nil for other messages and missing input", function()
      local p = prefix(FORMAT)
      assert.is_nil(World.victim("You gain 300 experience.", p))
      assert.is_nil(World.victim(nil, p))
      assert.is_nil(World.victim("Murloc dies, you gain 12 experience.", nil))
    end)
  end)

  describe("weaponSkill", function()
    local SKILL = "Your skill in %s has increased to %d."

    it("counts weapon and defense skills, not professions", function()
      local professions = World.professionNames({
        ["Player-1-A"] = { professions = { [185] = { name = "Cooking" }, [186] = { name = "Mining" } } },
        ["Player-1-B"] = { professions = { [129] = { name = "First Aid" } } },
      })
      assert.are.same({ Cooking = true, Mining = true, ["First Aid"] = true }, professions)
      local function skill(message) return World.weaponSkill(ns.GameText.parse(message, SKILL), professions) end
      assert.are.equal("Swords", skill("Your skill in Swords has increased to 42."))
      assert.are.equal("Defense", skill("Your skill in Defense has increased to 100."))
      assert.is_nil(skill("Your skill in Cooking has increased to 75."))
      assert.is_nil(skill("Your skill in First Aid has increased to 20."))
      assert.is_nil(skill("You gain 300 experience."))
    end)

    it("is nil-safe", function()
      assert.is_nil(World.weaponSkill(nil, nil))
      assert.are.equal("Maces", World.weaponSkill({ "Maces", "12" }, nil))
      assert.are.same({}, World.professionNames(nil))
      assert.are.same({}, World.professionNames({ ["Player-1-A"] = "broken", ["Player-1-B"] = { professions = 3 } }))
    end)
  end)

  describe("isFriendTarget", function()
    local people = {
      ["Ada#1001"] = { chars = { ["Player-1-F"] = { name = "Ves Doombringer", realm = "Classic Beta PvP" } } },
      ["Me#1000"] = { chars = { ["Player-1-M"] = { name = "Own Alt", realm = "Classic Beta PvP" } } },
    }

    it("matches a friend's character by GUID", function()
      assert.is_true(World.isFriendTarget(nil, "Player-1-F", { ["Player-1-F"] = "Ada#1001" }, people, "Me#1000"))
      assert.is_false(World.isFriendTarget(nil, "Player-1-M", { ["Player-1-M"] = "Me#1000" }, people, "Me#1000"))
    end)

    it("matches the whole name, with or without the realm, in any case", function()
      assert.is_true(World.isFriendTarget("Ves Doombringer", nil, nil, people, "Me#1000"))
      assert.is_true(World.isFriendTarget("ves doombringer", nil, nil, people, "Me#1000"))
      assert.is_true(World.isFriendTarget("Ves Doombringer-Classic Beta PvP", nil, nil, people, "Me#1000"))
      assert.is_true(World.isFriendTarget("Ves Doombringer-ClassicBetaPvP", nil, nil, people, "Me#1000"))
    end)

    it("never matches part of a name, an own alt or a stranger", function()
      assert.is_false(World.isFriendTarget("Ves", nil, nil, people, "Me#1000"))
      assert.is_false(World.isFriendTarget("Own Alt", nil, nil, people, "Me#1000"))
      assert.is_false(World.isFriendTarget("Someone Else", "Player-1-X", {}, people, "Me#1000"))
    end)

    it("is nil-safe", function()
      assert.is_false(World.isFriendTarget(nil, nil, nil, nil, nil))
      assert.is_false(World.isFriendTarget("", nil, nil, people, "Me#1000"))
      assert.is_false(World.isFriendTarget("Ves Doombringer", nil, nil, { ["Ada#1001"] = "broken" }, nil))
      assert.is_false(World.isFriendTarget("Ves Doombringer", nil, nil,
        { ["Ada#1001"] = { chars = { ["Player-1-F"] = "broken" } } }, nil))
    end)
  end)

  describe("isFriendTag", function()
    it("is a friend who syncs, never the own BattleTag", function()
      local people = { ["Ada#1001"] = {}, ["Me#1000"] = {} }
      assert.is_true(World.isFriendTag("Ada#1001", people, "Me#1000"))
      assert.is_false(World.isFriendTag("Me#1000", people, "Me#1000"))
      assert.is_false(World.isFriendTag("Bob#1002", people, "Me#1000"))
      assert.is_false(World.isFriendTag(nil, people, "Me#1000"))
      assert.is_false(World.isFriendTag("Ada#1001", nil, "Me#1000"))
    end)
  end)

  describe("isHearth", function()
    it("matches the hearthstone's spells only", function()
      local spells = { [8690] = true, [1008690] = true }
      assert.is_true(World.isHearth(8690, spells))
      assert.is_true(World.isHearth(1008690, spells))
      assert.is_false(World.isHearth(133, spells))
      assert.is_false(World.isHearth(nil, spells))
      assert.is_false(World.isHearth(8690, nil))
    end)
  end)
end)
