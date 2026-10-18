local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("own display name (CF-04)", function()
  local state, ns, addon

  local function load()
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
  end

  local function option()
    return ns.Settings.options().args.displayName
  end

  local function me()
    for _, p in ipairs(ns.ViewModel.build(addon).people) do
      if p.isSelf then return p end
    end
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("defaults to the BattleTag name part", function()
    load()
    assert.are.equal("", option().get())
    assert.are.equal("Vestras", me().displayName)
  end)

  it("stores a cleaned name, bumps the version and sends it", function()
    load()
    local before = addon.db.global.self.version
    state.serverTime = 5000
    option().set({}, "  Nico  ")
    assert.are.equal("Nico", addon.db.global.self.displayName)
    assert.are.equal("Nico", option().get())
    assert.is_true(addon.db.global.self.version > before)
    assert.are.equal("Nico", me().displayName)
    assert.are.equal("Nico", ns.Merge.outgoingRecord(addon.db.global.self).displayName)
  end)

  it("says HELLO to friends after the debounce", function()
    load()
    for _ = 1, 50 do
      if #state.timers == 0 then break end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
    state.bnSent = {}
    state.serverTime = 5000
    option().set({}, "Nico")
    for _ = 1, 50 do
      if #state.timers == 0 then break end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
    assert.is_true(#state.bnSent > 0)
  end)

  it("does not bump the version when nothing changes, and clears with empty text", function()
    load()
    option().set({}, "Nico")
    local version = addon.db.global.self.version
    option().set({}, "Nico ")
    assert.are.equal(version, addon.db.global.self.version)
    option().set({}, "")
    assert.is_nil(addon.db.global.self.displayName)
    assert.are.equal("Vestras", me().displayName)
  end)
end)
