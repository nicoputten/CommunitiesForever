local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("MainFrame", function()
  local state, ns, addon

  local SJAAK = "Sjaakovich#2232"
  local GARRAKA = "Player-4619-01789956"

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
  local function tree() return widgets("TreeGroup")[1] end

  -- Texts of all labels in the detail pane (recursing into groups).
  local function detailTexts()
    local texts = {}
    local function walk(widget)
      for _, child in ipairs(widget.children) do
        if child.text then texts[#texts + 1] = child.text end
        if child.title then texts[#texts + 1] = "[" .. child.title .. "]" end
        walk(child)
      end
    end
    walk(tree())
    return texts
  end

  local function hasText(pattern)
    for _, text in ipairs(detailTexts()) do
      if text:find(pattern, 1, true) then return true end
    end
    return false
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("opens with /cf and closes with /cf, reusing the window", function()
    load("23125681")
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal("CommunitiesForever", frame().title)
    state.slash.cf("")
    assert.is_false(ns.MainFrame.isShown())
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal(1, #widgets("Frame"))
  end)

  it("stores window and tree state in settings", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.equal(addon.db.global.settings.window, frame().status)
    assert.are.equal(addon.db.global.settings.tree, tree().status)
    assert.is_true(tree().treeResizable)
  end)

  it("builds the tree: people with online icon and class-colored characters", function()
    load("23125681")
    ns.MainFrame.toggle()
    local nodes = tree().tree
    assert.are.equal(SJAAK, nodes[1].value)
    assert.are.equal("Sjaakovich", nodes[1].text)
    assert.are.equal("Interface\\COMMON\\Indicator-Green", nodes[1].icon)
    assert.are.equal(GARRAKA, nodes[1].children[1].value)
    assert.matches("|cff40c7ebGarraka Doombringer|r", nodes[1].children[1].text, 1, true)
    assert.are.equal("Vestras (you)", nodes[2].text)
    assert.are.equal("2 people, 0 unlinked", frame().statusText)
  end)

  it("expands new people once, then leaves expansion to the user", function()
    load("23125681")
    ns.MainFrame.toggle()
    local groups = addon.db.global.settings.tree.groups
    assert.is_true(groups[SJAAK])
    groups[SJAAK] = false -- user collapsed it
    ns.MainFrame.render()
    assert.is_false(groups[SJAAK])
  end)

  it("selects the first person and shows the person card", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.equal(SJAAK, addon.db.global.settings.tree.selected)
    assert.is_true(hasText("Sjaakovich"))
    assert.is_true(hasText("Online on |cff40c7ebGarraka Doombringer|r"))
    assert.is_true(hasText("Characters"))
  end)

  it("shows the character card with class, owner, stats and professions", function()
    load("23125681")
    ns.MainFrame.toggle()
    tree():SelectByPath("Vestras#2858", "Player-4619-01627852")
    assert.is_true(hasText("|cfff58cbaVes Doombringer|r"))
    assert.is_true(hasText("Paladin  -  Vestras  -  Online in Durotar"))
    assert.is_true(hasText("[Level]"))
    assert.is_true(hasText("[Item level]"))
    assert.is_true(hasText("[Last seen]"))
    assert.is_true(hasText("Mining  |cffa0a0a064 / 150|r"))
    assert.is_true(hasText("Interface\\Buttons\\WHITE8X8")) -- progress bar
  end)

  it("opens a character from the person card list", function()
    load("23125681")
    ns.MainFrame.toggle()
    local entry
    local function find(widget)
      for _, child in ipairs(widget.children) do
        if child.type == "InteractiveLabel" then entry = entry or child end
        find(child)
      end
    end
    find(tree())
    entry:Fire("OnClick")
    assert.are.equal(SJAAK .. "\001" .. GARRAKA, addon.db.global.settings.tree.selected)
    assert.is_true(hasText("[Level]"))
  end)

  it("keeps the selection across refreshes and falls back when it disappears", function()
    load("23125681")
    ns.MainFrame.toggle()
    tree():SelectByPath(SJAAK, GARRAKA)
    ns.MainFrame.render()
    assert.are.equal(SJAAK .. "\001" .. GARRAKA, addon.db.global.settings.tree.selected)

    table.remove(state.friends, 1) -- Sjaak is no longer a friend: Garraka becomes Unlinked
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    wowapi.runTimers(state)
    assert.are.equal("Vestras#2858", addon.db.global.settings.tree.selected)
  end)

  it("shows the empty state without a community", function()
    load(nil)
    ns.MainFrame.toggle()
    assert.are.same({}, tree().tree)
    assert.are.same({ "Select a community in settings (/cf settings)." }, detailTexts())
  end)

  it("hints when no friend is linked yet", function()
    load("23125681")
    table.remove(state.friends, 1)
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    ns.MainFrame.toggle()
    assert.is_true(hasText("No linked friends yet."))
  end)

  it("refreshes while shown when data changes, debounced", function()
    load("23125681")
    ns.MainFrame.toggle()
    state.friends[1].gameAccounts[1].isOnline = false
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
    wowapi.runTimers(state) -- presence refresh, then window refresh
    wowapi.runTimers(state)
    local sjaak
    for _, node in ipairs(tree().tree) do
      if node.value == SJAAK then sjaak = node end
    end
    assert.are.equal("Interface\\COMMON\\Indicator-Gray", sjaak.icon)
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
