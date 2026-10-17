local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("MainFrame", function()
  local state, ns, addon

  local function load(storedClubId)
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = storedClubId
    addon:OnEnable()
  end

  local function widgets(widgetType)
    local list = {}
    for _, w in ipairs(state.guiWidgets) do
      if w.type == widgetType then list[#list + 1] = w end
    end
    return list
  end

  local function frame() return widgets("Frame")[1] end
  local function scroll() return widgets("ScrollFrame")[1] end

  local function texts()
    local list = {}
    for _, child in ipairs(scroll().children) do list[#list + 1] = child.text end
    return list
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("opens with /cf and closes with /cf", function()
    load("23125681")
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal("CommunitiesForever", frame().title)
    state.slash.cf("")
    assert.is_false(ns.MainFrame.isShown())
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal(1, #widgets("Frame")) -- reused, not recreated
  end)

  it("stores position and size in settings.window", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.equal(addon.db.global.settings.window, frame().status)
  end)

  it("renders people with class-colored two-line character rows", function()
    load("23125681")
    ns.MainFrame.toggle()
    local t = texts()
    assert.are.equal("People", t[1])
    assert.matches("Sjaakovich %(Sjaakovich#2232%) %- on Garraka Doombringer", t[2])
    assert.matches("|cff40c7ebGarraka Doombringer|r  Lvl 11", t[3], 1, true) -- MAGE color via classID
    assert.matches("Vestras %(Vestras#2858%) %- you", t[4])
    assert.matches("\n", t[5], 1, true) -- own char has professions: second line
    assert.are.equal("2 people, 0 unlinked", frame().statusText)
  end)

  it("shows the empty state without a community", function()
    load(nil)
    ns.MainFrame.toggle()
    assert.are.same({ "Select a community in settings (/cf settings)." }, texts())
  end)

  it("collapses and expands a person on header click, and remembers it", function()
    load("23125681")
    ns.MainFrame.toggle()
    local header = scroll().children[2]
    header:Fire("OnClick")
    assert.is_true(addon.db.global.settings.collapsed["Sjaakovich#2232"])
    assert.matches("^%+ ", texts()[2])
    assert.matches("^Vestras", texts()[3]:gsub("^%- |T[^|]+|t ", ""))

    scroll().children[2]:Fire("OnClick")
    assert.is_nil(addon.db.global.settings.collapsed["Sjaakovich#2232"])
    assert.matches("^%- ", texts()[2])
  end)

  it("refreshes while shown when data changes, debounced", function()
    load("23125681")
    ns.MainFrame.toggle()
    state.friends[1].gameAccounts[1].isOnline = false
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
    wowapi.runTimers(state) -- presence refresh, then window refresh
    wowapi.runTimers(state)
    assert.matches("Sjaakovich#2232%) %- offline", texts()[4])
  end)

  it("does not render while hidden", function()
    load("23125681")
    ns.MainFrame.toggle()
    ns.MainFrame.toggle()
    local before = #state.guiWidgets
    ns.CommunitySelection.select(nil)
    wowapi.runTimers(state)
    assert.are.equal(before, #state.guiWidgets)
  end)

  describe("minimap button", function()
    it("registers a launcher: left-click toggles, right-click opens settings", function()
      load("23125681")
      local launcher = state.ldbObjects.CommunitiesForever
      assert.are.equal("launcher", launcher.type)
      launcher.OnClick(nil, "LeftButton")
      assert.is_true(ns.MainFrame.isShown())
      launcher.OnClick(nil, "RightButton")
      assert.are.equal("CommunitiesForever", state.openedDialog)
    end)

    it("shows the online friend count in the tooltip", function()
      load("23125681")
      local lines = {}
      state.ldbObjects.CommunitiesForever.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
      assert.are.equal("1 friend(s) online in Forever", lines[2])
    end)

    it("can be hidden and shown from settings", function()
      load("23125681")
      local option = state.options.args.minimap
      assert.is_true(option.get())
      option.set({}, false)
      assert.is_true(addon.db.global.settings.minimap.hide)
      assert.is_false(state.minimapIcon.shown)
      option.set({}, true)
      assert.is_nil(addon.db.global.settings.minimap.hide)
      assert.is_true(state.minimapIcon.shown)
    end)
  end)
end)
