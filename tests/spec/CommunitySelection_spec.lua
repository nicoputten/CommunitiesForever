local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("CommunitySelection", function()
  local state, ns, addon, Selection

  -- storedClubId: value in the DB before enable (as if loaded from SavedVariables)
  -- setup(state): optional, runs before OnEnable to change mock data
  local function load(storedClubId, setup)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    Selection = ns.CommunitySelection
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = storedClubId
    addon:OnEnable()
  end

  local function settings()
    return addon.db.global.settings
  end

  local function changes()
    return wowapi.sentMessages(state, Selection.CHANGED)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("lists only character communities", function()
    load(nil)
    assert.are.same({ { clubId = "23125681", name = "Forever Friends" }, { clubId = "777", name = "Other Friends" } },
      Selection.list())
  end)

  it("stores the selection and announces it", function()
    load(nil)
    Selection.select("23125681")
    assert.are.equal("23125681", settings().clubId)
    assert.are.same({ { "23125681" } }, changes())
  end)

  it("does not announce re-selecting the same community", function()
    load("23125681")
    Selection.select("23125681")
    assert.are.same({}, changes())
  end)

  it("keeps a stored community that still exists", function()
    load("23125681")
    assert.are.equal("23125681", settings().clubId)
    assert.are.same({}, state.printed)
  end)

  it("clears a stored community that no longer exists, with one notice", function()
    load("42")
    assert.is_nil(settings().clubId)
    assert.are.same({ { nil } }, changes())
    assert.are.same({ Selection.GONE_NOTICE }, state.printed)

    wowapi.fireEvent(state, "CLUB_UPDATED", "23125681")
    assert.are.equal(1, #state.printed)
  end)

  it("waits while club data is not loaded yet", function()
    load("23125681", function(s) s.clubs = {} end) -- empty list at login
    assert.are.equal("23125681", settings().clubId)

    state.clubs = { { clubId = "23125681", name = "Forever Friends", clubType = 1 } }
    wowapi.fireEvent(state, "INITIAL_CLUBS_LOADED")
    assert.are.equal("23125681", settings().clubId)
    assert.are.same({}, state.printed)
  end)

  it("clears once club data is loaded and the community is gone", function()
    load(nil)
    state.clubs = {}
    addon.db.global.settings.clubId = "23125681"
    wowapi.fireEvent(state, "INITIAL_CLUBS_LOADED")
    assert.is_nil(settings().clubId)
  end)

  it("clears on CLUB_REMOVED for the selected community, even if still listed", function()
    load("23125681", function(s) table.insert(s.clubs, { clubId = "555", name = "Third", clubType = 1 }) end)
    wowapi.fireEvent(state, "CLUB_REMOVED", "23125681")
    assert.is_nil(settings().clubId) -- two others left: no auto-select
    assert.are.same({ Selection.GONE_NOTICE }, state.printed)
  end)

  it("auto-selects the only remaining community after CLUB_REMOVED", function()
    load("23125681")
    wowapi.fireEvent(state, "CLUB_REMOVED", "23125681") -- still listed while the event fires
    assert.are.equal("777", settings().clubId)
    assert.are.same({ Selection.GONE_NOTICE, "Showing community Other Friends. Change it with /cf settings." },
      state.printed)
  end)

  describe("auto-select", function()
    local function onlyOne(s)
      s.clubs = { { clubId = "23125681", name = "Forever Friends", clubType = 1 },
                  { clubId = "999", name = "My Guild", clubType = 2 } }
    end

    it("selects the only character community when nothing is selected", function()
      load(nil, onlyOne)
      assert.are.equal("23125681", settings().clubId)
      assert.are.same({ "Showing community Forever Friends. Change it with /cf settings." }, state.printed)
      assert.are.same({ { "23125681" } }, changes())
    end)

    it("does not choose between several communities", function()
      load(nil)
      assert.is_nil(settings().clubId)
      assert.are.same({}, state.printed)
    end)

    it("selects a community you join while nothing is selected", function()
      load(nil)
      table.insert(state.clubs, { clubId = "555", name = "New One", clubType = 1 })
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      assert.are.equal("555", settings().clubId)
    end)

    it("keeps the current selection when you join another community", function()
      load("23125681")
      table.insert(state.clubs, { clubId = "555", name = "New One", clubType = 1 })
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      assert.are.equal("23125681", settings().clubId)
    end)

    it("does not select a joined guild", function()
      load(nil)
      wowapi.fireEvent(state, "CLUB_ADDED", "999")
      assert.is_nil(settings().clubId)
    end)
  end)

  it("ignores CLUB_REMOVED for another community", function()
    load("23125681")
    wowapi.fireEvent(state, "CLUB_REMOVED", "999")
    assert.are.equal("23125681", settings().clubId)
  end)

  describe("settings options", function()
    it("registers in the Blizzard settings panel", function()
      load(nil)
      assert.are.same({ "CommunitiesForever", "CommunitiesForever" }, state.blizOptions)
    end)

    it("offers character communities and writes the selection", function()
      load(nil)
      local option = state.options.args.community
      assert.are.same({ ["23125681"] = "Forever Friends", ["777"] = "Other Friends" }, option.values())
      assert.are.same({ "23125681", "777" }, option.sorting())
      option.set({}, "23125681")
      assert.are.equal("23125681", option.get())
    end)

    it("opens with /cf settings", function()
      load(nil)
      state.slash.cf("settings")
      assert.are.equal("CommunitiesForever", state.openedDialog)
    end)
  end)
end)
