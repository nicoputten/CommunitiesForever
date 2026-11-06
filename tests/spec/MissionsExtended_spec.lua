local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Missions: extended (CF-74)", function()
  local ns, Extended

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Extended.lua", ns)
    Extended = ns.Missions.Extended
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Extended)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/extended.json")
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

  it("registers the progress of its dailies, all in the catalogue", function()
    local dailies = { "d.fish50", "d.fishZones", "d.fishFriend", "d.fishNight", "d.nightOwl", "d.session1h",
                      "d.deathless", "d.cleanRun", "d.profit", "d.green5", "d.reward", "d.craft5", "d.feedFriend",
                      "d.discover1", "d.discover3" }
    for _, id in ipairs(dailies) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("registers the weeklies that read its data, all in the catalogue", function()
    for _, id in ipairs({ "w.cleanRuns2", "w.fish100", "w.fishZones4", "w.dayAndNight", "w.deathless3h",
                          "w.friendDays3", "w.trades3" }) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
  end)

  it("leaves the goals that still wait for a check out of the pool", function()
    for _, id in ipairs({ "w.craftTrade", "p.punchUp5", "p.punchDown5" }) do
      local found = false
      for _, own in ipairs(Extended.IDS) do found = found or own == id end
      assert.is_false(found, id)
    end
    -- CF-99: the rest joined pool version 3; these three wait for their in-game check (VERIFY.md CF-74).
    local waiting = { ["d.reward"] = true, ["d.fishFriend"] = true, ["d.feedFriend"] = true }
    for _, id in ipairs(Extended.IDS) do
      assert.are.equal(not waiting[id] and 3 or nil, ns.Doomsday.goal(id).since, id)
    end
  end)

  it("keeps its facts under its own key", function()
    local f = ns.Goals.newFacts()
    assert.is_nil(f.extended)
    ns.Goals.observe(f, { kind = "extClock", hour = 23 })
    assert.is_true(f.extended.night)
    assert.are.equal(f.extended, ns.Goals.progressFacts(f).extended)
  end)

  it("ignores observations with missing fields", function()
    local f = ns.Goals.newFacts()
    for _, kind in ipairs({ "extFish", "extClock", "extAlive", "extBoss", "extMoney", "extLoot", "extReward",
                            "extTrade", "extGroup" }) do
      ns.Goals.observe(f, { kind = kind })
    end
    for _, id in ipairs(Extended.IDS) do
      if id ~= "d.craft5" then -- a created item without a count is one item
        assert.is_false(select(3, ns.Doomsday.progress(id, ns.Goals.progressFacts(f))), id)
      end
    end
  end)

  it("caps the zones, runs and friends of a day or week", function()
    local f = ns.Goals.newFacts()
    for i = 1, Extended.MAX_KEYS + 10 do
      ns.Goals.observe(f, { kind = "extFish", zone = "Zone " .. i })
      ns.Goals.observe(f, { kind = "extTrade", friend = "Friend#" .. i })
    end
    local pf = ns.Goals.progressFacts(f)
    assert.are.equal(Extended.MAX_KEYS, (ns.Doomsday.progress("w.fishZones4", pf)))
    assert.are.equal(Extended.MAX_KEYS, (ns.Doomsday.progress("w.trades3", pf)))
  end)

  describe("helpers", function()
    it("knows the night owl's and the fishing night's hours", function()
      assert.is_true(Extended.isNight(23))
      assert.is_true(Extended.isNight(0))
      assert.is_true(Extended.isNight(2))
      assert.is_false(Extended.isNight(3))
      assert.is_false(Extended.isNight(22))
      assert.is_false(Extended.isNight(nil))
      assert.is_true(Extended.isFishNight(21))
      assert.is_true(Extended.isFishNight(4))
      assert.is_false(Extended.isFishNight(5))
      assert.is_false(Extended.isFishNight(20))
    end)

    it("reads an item's quality from the game, the link or its colour", function()
      assert.are.equal(3, Extended.quality({ color = "1eff00" }, 3))
      assert.are.equal(2, Extended.quality({ linkQuality = 2 }, nil))
      assert.are.equal(2, Extended.quality({ color = "1eff00" }, nil))
      assert.are.equal(1, Extended.quality({ color = "ffffff" }, nil))
      assert.is_nil(Extended.quality({ color = "123456" }, nil))
      assert.is_nil(Extended.quality(nil, nil))
    end)

    it("ties an item to a quest handed in within seconds, either order", function()
      assert.is_true(Extended.isReward(1000, 1000))
      assert.is_true(Extended.isReward(1005, 1000))
      assert.is_true(Extended.isReward(995, 1000))
      assert.is_false(Extended.isReward(1006, 1000))
      assert.is_false(Extended.isReward(1000, nil))
    end)

    it("finds friends' community characters in the group, and whether one is here", function()
      local members = { ["Player-1-F"] = { zone = "Westfall" }, ["Player-1-G"] = {}, ["Player-1-M"] = {} }
      local byGuid = { ["Player-1-F"] = "Ada#1001", ["Player-1-G"] = "Bob#1002", ["Player-1-X"] = "Cy#1003" }
      local friends, here = Extended.friendsInGroup({ "Player-1-F", "Player-1-X", "Player-1-M" }, members, byGuid,
        "Westfall")
      assert.are.same({ ["Ada#1001"] = true }, friends)
      assert.is_true(here)
      friends, here = Extended.friendsInGroup({ "Player-1-F" }, members, byGuid, "Duskwood")
      assert.are.same({ ["Ada#1001"] = true }, friends)
      assert.is_false(here)
      friends, here = Extended.friendsInGroup({ "Player-1-G" }, members, byGuid, "Duskwood")
      assert.are.same({ ["Bob#1002"] = true }, friends)
      assert.is_true(here) -- the friend's zone unknown: grouped is near enough
      friends, here = Extended.friendsInGroup(nil, members, byGuid, "Duskwood")
      assert.are.same({}, friends)
      assert.is_false(here)
    end)

    it("continues the session's start money after a /reload, starts anew otherwise", function()
      local first = Extended.sessionMoney(nil, "Player-1-A", 5000, 1000)
      assert.are.same({ guid = "Player-1-A", money = 5000, at = 1000 }, first)
      first.at = 2000 -- logout
      assert.are.same({ guid = "Player-1-A", money = 5000, at = 2100 },
        Extended.sessionMoney(first, "Player-1-A", 7000, 2100))
      assert.are.same({ guid = "Player-1-A", money = 7000, at = 2400 },
        Extended.sessionMoney(first, "Player-1-A", 7000, 2400))
      assert.are.same({ guid = "Player-1-B", money = 100, at = 2100 },
        Extended.sessionMoney(first, "Player-1-B", 100, 2100))
      assert.is_nil(Extended.sessionMoney(first, "Player-1-A", nil, 2100))
      assert.is_nil(Extended.sessionMoney(first, nil, 100, 2100))
    end)

    it("knows food and the own dishes given in a trade", function()
      assert.is_true(Extended.isFood(0, 5))
      assert.is_false(Extended.isFood(0, 7))
      assert.is_false(Extended.isFood(nil, nil))
      local cooked = {}
      Extended.markCooked(cooked, 2680)
      Extended.markCooked(cooked, "junk")
      Extended.markCooked(nil, 2680)
      assert.are.same({ [2680] = true }, cooked)
      assert.is_true(Extended.gaveCooked({ 117, 2680 }, cooked))
      assert.is_false(Extended.gaveCooked({ 117 }, cooked))
      assert.is_false(Extended.gaveCooked(nil, cooked))
      assert.is_false(Extended.gaveCooked({ 2680 }, nil))
    end)
  end)
end)

-- The adapter on the mocked client: the existing trackers' events reach the extended facts.
describe("Missions: extended events (CF-74)", function()
  local state, ns, addon
  local friendGuid = "Player-4619-01789956" -- Garraka, the friend's character

  local function load(setup)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
  end

  local function facts()
    local today = ns.DoomsdayTracker.today()
    return addon.db.global.self.doomsday.days[today].extended or {}
  end

  local stubs = {}
  local function stub(name, value)
    stubs[name] = true
    _G[name] = value
  end

  after_each(function()
    wowapi.uninstall()
    for name in pairs(stubs) do _G[name] = nil end
    stubs = {}
  end)

  it("counts fishing zones and the night from the realm clock", function()
    stub("IsFishingLoot", function() return true end)
    stub("GetNumLootItems", function() return 1 end)
    stub("GetGameTime", function() return 22, 15 end)
    load()
    state.zone = "Westfall"
    wowapi.fireEvent(state, "LOOT_OPENED")
    state.zone = "Duskwood"
    wowapi.fireEvent(state, "LOOT_OPENED")
    assert.are.same({ Westfall = true, Duskwood = true }, facts().fishZones)
    assert.are.equal(2, facts().fishNight)
    assert.are.equal(0, facts().fishFriend)
  end)

  it("counts greens, crafted items and an uncommon quest reward", function()
    load()
    state.items[1001] = { quality = 2 }
    state.items[1002] = { quality = 1 }
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:1001::::|h[Green Ring]|h|r.")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:1002::::|h[Linen Bandage]|h|rx3.")
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 9001, 500, 0)
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:1001::::|h[Green Ring]|h|r.")
    assert.are.same({ 2, 3, 1 }, { facts().green, facts().crafted, facts().reward })
    -- A green bought long after the hand-in is no reward.
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:1001::::|h[Green Ring]|h|r.")
    assert.are.same({ 3, 1 }, { facts().green, facts().reward })
  end)

  it("remembers own dishes and counts one given to a friend", function()
    stub("GetTradePlayerItemLink", function(slot)
      return slot == 1 and "|cffffffff|Hitem:2680::::|h[Spiced Wolf Meat]|h|r" or nil
    end)
    stub("ERR_TRADE_COMPLETE", "Trade complete.")
    load(function(s) s.unitGuids = { NPC = friendGuid } end)
    _G.C_Item.GetItemInfoInstant = function(id) return id, "Consumable", "Food & Drink", "", 0, 0, 5 end
    addon.db.global.people[state.friends[1].battleTag] = { version = 1, chars = {
      [friendGuid] = { name = "Garraka Doombringer", level = 11 } } }
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:2680::::|h[Spiced Wolf Meat]|h|r.")
    assert.is_true(addon.db.global.self.doomsday.cooked[2680])
    wowapi.fireEvent(state, "TRADE_SHOW")
    wowapi.fireEvent(state, "TRADE_PLAYER_ITEM_CHANGED", 1)
    wowapi.fireEvent(state, "UI_INFO_MESSAGE", 0, "Trade complete.")
    assert.are.equal(1, facts().fed)
    assert.is_true(facts().tradeFriends[state.friends[1].battleTag])
  end)

  it("sees money above the session's start", function()
    load(function(s) s.money = 5000 end)
    assert.are.equal(5000, addon.db.global.self.doomsday.sessionMoney.money)
    state.money = 4000
    wowapi.fireEvent(state, "PLAYER_MONEY")
    assert.is_false(facts().profit)
    state.money = 5200
    wowapi.fireEvent(state, "PLAYER_MONEY")
    assert.is_true(facts().profit)
  end)

  it("ticks the session and the night at login", function()
    load()
    local hour = os.date("*t").hour
    assert.are.equal(ns.Missions.Extended.isNight(hour), facts().night)
    assert.is_number(facts().sessionMax)
  end)
end)
