local helpers = require("helpers")

describe("Missions: items (CF-75)", function()
  local ns, Items

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Items.lua", ns)
    Items = ns.Missions.Items
  end)

  it("loads as a mission module", function()
    assert.is_table(ns.Missions.Items)
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/items.json")
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

  local DAILIES = { "d.gather10", "d.newRecipe", "d.craftGreen", "d.cook5", "d.cook15", "d.cookKinds3", "d.eatOwn",
                    "d.cookRecipe", "d.bandage3", "d.bandage10", "d.bandageKinds2", "d.bandageUp", "d.bandageUse3",
                    "d.bandageFriend", "d.coins10", "d.equipNew", "d.wellFed", "d.buffFriend", "d.tidyBags",
                    "d.potion", "d.scrolls10" }
  local WEEKLIES = { "w.blueGear", "w.gather50", "w.recipes3", "w.cook30", "w.cookKinds5", "w.bandages20",
                     "w.potions5" }

  it("registers the progress of its 21 dailies and 7 weeklies, all in the catalogue", function()
    local all = {}
    for _, id in ipairs(DAILIES) do all[#all + 1] = id end
    for _, id in ipairs(WEEKLIES) do all[#all + 1] = id end
    for _, id in ipairs(all) do
      assert.is_table(ns.Doomsday.goal(id), id)
      assert.is_number((ns.Doomsday.progress(id, {})), id)
    end
    table.sort(all)
    assert.are.same(all, Items.IDS)
  end)

  it("leaves the goals that still wait for a check unregistered", function()
    for _, id in ipairs({ "d.treasure", "d.fishKinds3", "d.campfire", "d.campfireBuff", "d.jump100" }) do
      assert.is_nil(ns.Doomsday.progress(id, {}), id)
    end
  end)

  it("puts nothing in the draw (no since: the pool-3 story does that)", function()
    for _, id in ipairs(Items.IDS) do
      assert.is_nil(ns.Doomsday.goal(id).since, id)
    end
  end)

  it("keeps its facts under its own key", function()
    local f = ns.Goals.newFacts()
    assert.is_nil(f.items)
    ns.Goals.observe(f, { kind = "itemCoins", guid = "Player-1-A" })
    assert.are.equal(1, f.items.coins)
    assert.are.equal(f.items, ns.Goals.progressFacts(f).items)
  end)

  it("ignores observations with missing fields", function()
    local f = ns.Goals.newFacts()
    for _, kind in ipairs({ "itemCreated", "itemLooted", "itemUsed", "itemRecipe", "itemEquip", "itemAura",
                            "itemBags" }) do
      ns.Goals.observe(f, { kind = kind })
    end
    for _, id in ipairs(Items.IDS) do
      if id ~= "d.newRecipe" and id ~= "w.recipes3" then
        assert.is_false(select(3, ns.Doomsday.progress(id, ns.Goals.progressFacts(f))), id)
      end
    end
    -- A recipe without an ID is no recipe either.
    assert.are.equal(0, (ns.Doomsday.progress("d.newRecipe", ns.Goals.progressFacts(f))))
  end)

  it("caps the dishes and the looted items of a day or week", function()
    local f = ns.Goals.newFacts()
    for i = 1, Items.MAX_SET + 10 do
      ns.Goals.observe(f, { kind = "itemCreated", id = i, class = 0, subclass = 5 })
    end
    for i = 1, Items.MAX_LOOTED + 10 do
      ns.Goals.observe(f, { kind = "itemLooted", guid = "Player-1-A", id = i })
    end
    local p = ns.Goals.progressFacts(f)
    assert.are.equal(Items.MAX_SET, (ns.Doomsday.progress("w.cookKinds5", p)))
    assert.are.equal(Items.MAX_SET + 10, (ns.Doomsday.progress("w.cook30", p)))
    local looted = 0
    for _ in pairs(f.items.looted) do looted = looted + 1 end
    assert.are.equal(Items.MAX_LOOTED, looted)
  end)

  describe("usedItem", function()
    local bread = { id = 4540, class = 0, subclass = 5 }
    local roast = { id = 1000101, class = 0, subclass = 5 }
    local pattern = { id = 1004001, class = 9, subclass = 2 }
    local recipe = { id = 1004002, class = 9, subclass = 5 }

    it("takes the candidate whose count dropped", function()
      assert.are.equal(roast, Items.usedItem({ bread, roast }, { [4540] = 5, [1000101] = 2 },
        { [4540] = 5, [1000101] = 1 }))
      assert.are.equal(roast, Items.usedItem({ bread, roast }, { [4540] = 5, [1000101] = 1 }, { [4540] = 5 }))
    end)

    it("takes the only candidate when no count dropped", function()
      assert.are.equal(bread, Items.usedItem({ bread }, { [4540] = 5 }, { [4540] = 5 }))
    end)

    it("gives the shared class without an id when the candidates can't be told apart", function()
      assert.are.same({ class = 0, subclass = 5 }, Items.usedItem({ bread, roast }, {}, {}))
      assert.are.same({ class = 0, subclass = 5 },
        Items.usedItem({ bread, roast }, { [4540] = 2, [1000101] = 2 }, { [4540] = 1, [1000101] = 1 }))
    end)

    it("is nil when candidates of different classes can't be told apart", function()
      assert.is_nil(Items.usedItem({ pattern, recipe }, {}, {}))
      assert.are.equal(recipe, Items.usedItem({ pattern, recipe }, { [1004002] = 1 }, {}))
    end)

    it("is nil on missing data", function()
      assert.is_nil(Items.usedItem(nil, {}, {}))
      assert.is_nil(Items.usedItem({}, {}, {}))
      assert.are.equal(bread, Items.usedItem({ bread }, nil, nil))
    end)
  end)

  describe("names", function()
    it("knows a unit by its full name and UnitName's returns, never splitting", function()
      assert.are.same({ "Ves Doombringer", "Ves Doombringer" }, Items.nameForms("Ves Doombringer", "Ves Doombringer"))
      assert.are.same({ "Marks Man", "Marks", "Marks Man", "Marks-Man" }, Items.nameForms("Marks Man", "Marks", "Man"))
      assert.are.same({}, Items.nameForms(nil, nil, nil))
      assert.are.same({ "Ada" }, Items.nameForms(nil, "Ada", ""))
    end)

    it("matches a target name whole", function()
      local forms = Items.nameForms("Marks Man", "Marks", "Man")
      assert.is_true(Items.sameName("Marks Man", forms))
      assert.is_false(Items.sameName("Man", forms))
      assert.is_false(Items.sameName("", forms))
      assert.is_false(Items.sameName("Marks Man", nil))
    end)

    it("a cast without a target is on the own character", function()
      local forms = Items.nameForms("Ves Doombringer", "Ves Doombringer")
      assert.is_true(Items.onSelf(nil, forms))
      assert.is_true(Items.onSelf("", forms))
      assert.is_true(Items.onSelf("Ves Doombringer", forms))
      assert.is_false(Items.onSelf("Ada Lovelace", forms))
    end)
  end)

  describe("markWorn", function()
    it("seeds a character's first sight with what it wears, nothing new", function()
      local worn = {}
      assert.is_false(Items.markWorn(worn, "Player-1-A", nil, { 11, 12 }))
      assert.are.same({ ["Player-1-A"] = { [11] = true, [12] = true } }, worn)
      assert.is_false(Items.markWorn(worn, "Player-1-B", 21, { 21, 22 }))
      assert.are.same({ [21] = true, [22] = true }, worn["Player-1-B"])
    end)

    it("an item never worn is new once", function()
      local worn = { ["Player-1-A"] = { [11] = true } }
      assert.is_false(Items.markWorn(worn, "Player-1-A", 11, {}))
      assert.is_true(Items.markWorn(worn, "Player-1-A", 13, {}))
      assert.is_false(Items.markWorn(worn, "Player-1-A", 13, {}))
      assert.is_false(Items.markWorn(worn, "Player-1-A", nil, { 14 })) -- a later seed adds nothing
      assert.is_nil(worn["Player-1-A"][14])
    end)

    it("keeps at most MAX_WORN items per character", function()
      local set = {}
      for i = 1, Items.MAX_WORN do set[i] = true end
      local worn = { ["Player-1-A"] = set }
      assert.is_false(Items.markWorn(worn, "Player-1-A", Items.MAX_WORN + 1, {}))
      assert.is_nil(set[Items.MAX_WORN + 1])
    end)

    it("is false on missing data", function()
      assert.is_false(Items.markWorn(nil, "Player-1-A", 1, {}))
      assert.is_false(Items.markWorn({}, nil, 1, {}))
    end)
  end)

  it("tells Well Fed by its name", function()
    assert.is_true(Items.isWellFed("Well Fed"))
    assert.is_false(Items.isWellFed("Food"))
    assert.is_false(Items.isWellFed(nil))
  end)

  it("tells own coin loot by the game's formats", function()
    local formats = { "You loot %s", "Your share of the loot is %s." }
    assert.is_true(Items.coinMessage("You loot 12 Copper", formats))
    assert.is_true(Items.coinMessage("Your share of the loot is 1 Silver, 3 Copper.", formats))
    assert.is_false(Items.coinMessage("Ada loots 12 Copper", formats))
    assert.is_false(Items.coinMessage(nil, formats))
    assert.is_false(Items.coinMessage("You loot 12 Copper", nil))
  end)
end)

describe("ItemEvents (CF-75)", function()
  local wowapi = require("mocks.wowapi")
  local state, ns, addon
  local bags, classes, spells
  local STUBS = { "C_Container", "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT" }

  before_each(function()
    bags = { { itemID = 1000101, stackCount = 2, quality = 1 }, { itemID = 1005001, stackCount = 1, quality = 0 } }
    classes = { [1000101] = { 0, 5 }, [1005001] = { 15, 0 }, [1000301] = { 0, 7 } }
    spells = { [1000101] = 1100433 }
    state = wowapi.install()
    _G.C_Container = {
      GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
      GetContainerItemInfo = function(bag, slot) return bag == 0 and bags[slot] or nil end,
    }
    _G.YOU_LOOT_MONEY = "You loot %s"
    _G.LOOT_MONEY_SPLIT = "Your share of the loot is %s."
    _G.C_Item.GetItemInfoInstant = function(id)
      local c = classes[id] or {}
      return id, "Type", "Subtype", "", 0, c[1], c[2]
    end
    _G.C_Item.GetItemSpell = function(id) return spells[id] and "Food" or nil, spells[id] end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    wowapi.runTimers(state) -- the first bag and gear read
  end)

  after_each(function()
    for _, name in ipairs(STUBS) do _G[name] = nil end
  end)

  local function today()
    local d = addon.db.global.self.doomsday.days
    return d[ns.DoomsdayTracker.today()].items
  end

  it("counts a dish cooked and then eaten, coins and a tidy bag", function()
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:1000101::::|h[Roast]|h|r.")
    assert.are.equal(1, today().cooked)
    assert.is_true(today().cookKinds[1000101])
    wowapi.fireEvent(state, "UNIT_SPELLCAST_SENT", "player", "", "Cast-1", 1100433)
    wowapi.fireEvent(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1100433)
    bags[1].stackCount = 1
    bags[2] = nil -- the grey item sold
    wowapi.fireEvent(state, "BAG_UPDATE_DELAYED")
    assert.is_true(today().eatOwn)
    assert.is_true(today().tidy)
    wowapi.fireEvent(state, "CHAT_MSG_MONEY", "You loot 12 Copper")
    wowapi.fireEvent(state, "CHAT_MSG_MONEY", "Your share of the loot is 3 Copper.")
    assert.are.equal(2, today().coins)
  end)

  it("ignores casts that use no bag item and other units' casts", function()
    wowapi.fireEvent(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 1234567)
    wowapi.fireEvent(state, "UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-3", 1100433)
    bags[1].stackCount = 1
    wowapi.fireEvent(state, "BAG_UPDATE_DELAYED")
    assert.is_false(today().eatOwn)
  end)

  it("marks gear put on later as new, once, and a looted find worn that day", function()
    local guid = ns.SelfInfo.guid()
    assert.are.same({}, addon.db.global.self.doomsday.worn[guid]) -- seeded (nothing worn in the mock)
    local slots = {}
    _G.GetInventoryItemID = function(_, slot) return slots[slot] end
    state.items[1003003] = { quality = 3 }
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:1003003::::|h[Blade]|h|r.")
    slots[16] = 1003003
    wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 16, true)
    local week = addon.db.global.self.doomsday.weeks[ns.Doomsday.week(ns.DoomsdayTracker.today())].items
    assert.is_true(week.blueGear)
    assert.is_true(today().equipNew)
    assert.is_true(addon.db.global.self.doomsday.worn[guid][1003003])
    _G.GetInventoryItemID = nil
  end)
end)
