local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("SelfTracker", function()
  local state, ns, addon, SelfTracker

  local GUID = "Player-4619-01627852"

  local function load(opts)
    state = wowapi.install(opts)
    ns = {}
    for _, path in ipairs({ "src/core/Store.lua", "src/core/Merge.lua", "src/core/Snapshot.lua",
                            "src/adapters/Events.lua", "src/adapters/SelfInfo.lua",
                            "src/services/SelfTracker.lua", "src/Core.lua" }) do
      helpers.loadAddonFile(path, ns)
    end
    SelfTracker = ns.SelfTracker
    addon = state.addon
    addon:OnInitialize()
    addon:OnEnable()
  end

  local function self_()
    return addon.db.global.self
  end

  local function updates()
    return #wowapi.sentMessages(state, SelfTracker.UPDATED)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("stores the current character on enable", function()
    load()
    local char = self_().chars[GUID]
    assert.are.equal("Ves Doombringer", char.name)
    assert.are.equal(1, char.ilvl)
    assert.are.same({ name = "Mining", rank = 64, max = 150 }, char.professions[186])
    assert.are.equal(1000, self_().version)
    assert.are.equal("Vestras#2858", self_().battleTag)
    assert.are.equal(1, updates())
  end)

  it("does not bump the version for an unchanged character", function()
    load()
    state.serverTime = 2000
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, true)
    wowapi.fireEvent(state, "SKILL_LINES_CHANGED")
    assert.are.equal(1000, self_().version)
    assert.are.equal(1, updates())
  end)

  it("uses the level from PLAYER_LEVEL_UP even if UnitLevel lags", function()
    load()
    state.serverTime = 2000
    wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
    assert.are.equal(12, self_().chars[GUID].level)
    assert.are.equal(2000, self_().version)
    assert.are.equal(2, updates())
  end)

  it("updates on a profession skill change", function()
    load()
    state.serverTime = 2000
    state.player.professionInfo[10][3] = 65
    wowapi.fireEvent(state, "SKILL_LINES_CHANGED")
    assert.are.equal(65, self_().chars[GUID].professions[186].rank)
    assert.are.equal(2000, self_().version)
  end)

  it("keeps every Char field, including updatedAt, after a skill-up", function()
    load()
    state.serverTime = 2000
    state.player.professionInfo[10][3] = 65
    wowapi.fireEvent(state, "SKILL_LINES_CHANGED")
    local char = self_().chars[GUID]
    for _, field in ipairs({ "guid", "name", "classFile", "raceID", "level", "faction", "realm", "ilvl",
                             "professions", "updatedAt" }) do
      assert.is_not_nil(char[field], field)
    end
    assert.are.equal(2000, char.updatedAt)
  end)

  it("debounces equipment changes", function()
    load()
    state.serverTime = 2000
    state.player.itemLevel = { 20, 20, 20 }
    wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 1, true)
    wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 5, true)
    wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 7, true)
    assert.are.equal(1, self_().chars[GUID].ilvl) -- not yet
    assert.are.equal(3, #state.timers)
    assert.are.equal(2, state.timers[3].seconds)

    wowapi.runTimers(state)
    assert.are.equal(20, self_().chars[GUID].ilvl)
    assert.are.equal(2, updates()) -- one refresh for three events
  end)

  it("refreshes equipment immediately without C_Timer", function()
    load({ missing = { C_Timer = true } })
    state.player.itemLevel = { 20, 20, 20 }
    wowapi.fireEvent(state, "PLAYER_EQUIPMENT_CHANGED", 1, true)
    assert.are.equal(20, self_().chars[GUID].ilvl)
  end)

  it("stores ilvl nil without error when GetAverageItemLevel is missing", function()
    load({ missing = { GetAverageItemLevel = true } })
    assert.is_nil(self_().chars[GUID].ilvl)
  end)
end)
