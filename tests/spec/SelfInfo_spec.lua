local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("SelfInfo", function()
  local state, SelfInfo

  local function load(opts)
    state = wowapi.install(opts)
    local ns = {}
    helpers.loadAddonFile("src/adapters/Events.lua", ns)
    SelfInfo = helpers.loadAddonFile("src/adapters/SelfInfo.lua", ns)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  describe("read", function()
    it("returns the raw character values", function()
      load()
      local info = SelfInfo.read()
      assert.are.equal("Player-4619-01627852", info.guid)
      assert.are.equal("Ves Doombringer", info.name)
      assert.are.equal("PALADIN", info.classFile)
      assert.are.equal(6, info.raceID)
      assert.are.equal(11, info.level)
      assert.are.equal("Horde", info.faction)
      assert.are.equal("Classic Beta PvP", info.realm)
      assert.are.equal("Vestras#1000", info.battleTag)
    end)

    it("reads the full name even when UnitName splits first and last name (V9)", function()
      load()
      state.player.name = "Marks Man"
      assert.are.same({ "Marks", "Man" }, { _G.UnitName("player") })
      assert.are.equal("Marks Man", SelfInfo.read().name)
    end)

    it("falls back to UnitName without GetUnitName", function()
      load({ missing = { GetUnitName = true } })
      state.player.name = "Marks Man"
      assert.are.equal("Marks", SelfInfo.read().name)
    end)

    it("uses the equipped item level (2nd return)", function()
      load()
      state.player.itemLevel = { 30.5, 20.25, 10 }
      assert.are.equal(20.25, SelfInfo.read().ilvl)
    end)

    it("returns nil ilvl without error when GetAverageItemLevel is missing", function()
      load({ missing = { GetAverageItemLevel = true } })
      assert.is_nil(SelfInfo.read().ilvl)
    end)

    it("reads professions from all five slots, skipping nil holes", function()
      load()
      state.player.professionSlots = { [2] = 10, [4] = 11, [5] = 12 }
      state.player.professionInfo[11] = { "Fishing", 136245, 1, 75, 1, 0, 356, 0, -1, 0, "Fishing" }
      local professions = SelfInfo.read().professions
      assert.are.same({
        { name = "Mining", rank = 64, max = 150, skillLine = 186 },
        { name = "Fishing", rank = 1, max = 75, skillLine = 356 },
        { name = "Cooking", rank = 2, max = 75, skillLine = 185 },
      }, professions)
    end)

    it("returns no professions when there are none", function()
      load()
      state.player.professionSlots = {}
      assert.are.same({}, SelfInfo.read().professions)
    end)

    it("tolerates missing unverified unit APIs", function()
      load({ missing = { UnitRace = true, UnitLevel = true, UnitFactionGroup = true } })
      local info = SelfInfo.read()
      assert.is_nil(info.raceID)
      assert.is_nil(info.level)
      assert.is_nil(info.faction)
      assert.are.equal("Player-4619-01627852", info.guid)
    end)
  end)

  describe("watch", function()
    local addon

    before_each(function()
      load()
      addon = setmetatable({}, { __index = state.aceMixin })
    end)

    it("turns WoW events into CHANGED messages with their args", function()
      SelfInfo.watch(addon)
      wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12, 20, 0)
      wowapi.fireEvent(state, "SKILL_LINES_CHANGED")
      wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 16, true)
      wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", true, false)
      assert.are.same({
        { "level", 12, 20, 0 },
        { "skills" },
        { "equipment", 16, true },
        { "world", true, false },
      }, wowapi.sentMessages(state, SelfInfo.CHANGED))
    end)

    it("skips events the client does not know", function()
      wowapi.uninstall()
      load({ validEvents = { "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP" } })
      addon = setmetatable({}, { __index = state.aceMixin })
      SelfInfo.watch(addon)
      assert.is_function(state.events.PLAYER_LEVEL_UP)
      assert.is_nil(state.events.SKILL_LINES_CHANGED)
      assert.is_nil(state.events.PLAYER_EQUIPMENT_CHANGED)
    end)
  end)
end)
