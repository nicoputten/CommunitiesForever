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

  it("keeps a selection this character cannot see, marked not active", function()
    load("42") -- not in this character's list
    assert.are.equal("42", settings().clubId)
    assert.is_nil(Selection.active())
    assert.are.same({}, state.printed)
  end)

  it("treats a selection as active while club data is not loaded yet", function()
    load("23125681", function(s) s.clubs = {} end) -- empty list at login
    assert.are.equal("23125681", Selection.active())

    state.clubs = { { clubId = "23125681", name = "Forever Friends", clubType = 1 } }
    wowapi.fireEvent(state, "INITIAL_CLUBS_LOADED")
    assert.are.equal("23125681", Selection.active())
    assert.are.same({}, state.printed)
  end)

  it("marks it not active once club data is loaded and the community is not listed", function()
    load("23125681", function(s) s.clubs = {} end)
    wowapi.fireEvent(state, "INITIAL_CLUBS_LOADED")
    assert.are.equal("23125681", settings().clubId)
    assert.is_nil(Selection.active())
    assert.are.same({ { "23125681" } }, changes()) -- availability change announced
  end)

  it("keeps the selection on CLUB_REMOVED but marks it not active, even if still listed", function()
    load("23125681")
    wowapi.fireEvent(state, "CLUB_REMOVED", "23125681")
    assert.are.equal("23125681", settings().clubId)
    assert.is_nil(Selection.active())
    assert.are.same({}, state.printed)
  end)

  it("remembers the community name for characters that cannot see it", function()
    load("23125681")
    assert.are.equal("Forever Friends", Selection.name())
    state.clubs = { { clubId = "777", name = "Other Friends", clubType = 1 } } -- an alt outside it
    wowapi.fireEvent(state, "CLUB_UPDATED", "777")
    assert.is_nil(Selection.active())
    assert.are.equal("Forever Friends", Selection.name())
  end)

  it("becomes active again when the character joins the community", function()
    load("23125681")
    wowapi.fireEvent(state, "CLUB_REMOVED", "23125681")
    wowapi.fireEvent(state, "CLUB_ADDED", "23125681")
    assert.are.equal("23125681", Selection.active())
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
