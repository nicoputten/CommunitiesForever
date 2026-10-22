local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-32: keybinding and Esc closes the window and the setup.
describe("keybinding and Esc (CF-32)", function()
  local state, ns, addon

  local function load()
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon.db.global.settings.onboarded, addon.db.global.settings.onboardedVersion = true, ns.Onboarding.VERSION
    addon:OnEnable()
  end

  local function windowFrame()
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" and w.title == "CommunitiesForever" then return w end
    end
  end

  local function press(widget, key)
    widget.frame.scripts.OnKeyDown(widget.frame, key)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("names the binding and toggles the window from it", function()
    load()
    assert.are.equal("CommunitiesForever", _G.BINDING_HEADER_COMMUNITIESFOREVER)
    assert.are.equal("Open or close the window", _G.BINDING_NAME_COMMUNITIESFOREVER_TOGGLE)
    _G.CommunitiesForever:ToggleWindow()
    assert.is_true(ns.MainFrame.isShown())
    _G.CommunitiesForever:ToggleWindow()
    assert.is_false(ns.MainFrame.isShown())
  end)

  it("closes the window on Esc without passing it on, and passes other keys on", function()
    load()
    ns.MainFrame.toggle()
    local w = windowFrame()
    assert.is_true(w.frame.keyboard)
    press(w, "W")
    assert.is_true(w.frame.propagate)
    assert.is_true(ns.MainFrame.isShown())
    press(w, "ESCAPE")
    assert.is_false(w.frame.propagate) -- the game menu does not open as well
    assert.is_false(ns.MainFrame.isShown())
    wowapi.runTimers(state)
    assert.is_true(w.frame.propagate) -- keys pass on again for the next show
  end)

  it("changes nothing in combat and sets Esc up on the next show", function()
    load()
    state.inCombat = true
    ns.MainFrame.toggle()
    local w = windowFrame()
    assert.is_nil(w.frame.keyboard)
    ns.MainFrame.toggle()
    state.inCombat = false
    ns.MainFrame.toggle()
    assert.is_true(w.frame.keyboard)
    state.inCombat = true
    press(w, "ESCAPE") -- in combat: falls through to the game menu, window stays
    assert.is_true(ns.MainFrame.isShown())
  end)

  it("closes the setup on Esc", function()
    load()
    addon:OnSlashCommand("setup")
    local wizard
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" and w.title == "CommunitiesForever setup" then wizard = w end
    end
    press(wizard, "ESCAPE")
    assert.is_false(ns.Setup.isShown())
  end)
end)
