local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-39: the revamp's kit (src/ui/kit) and the main window built from it.
describe("kit and window shell (CF-39)", function()
  local state, ns, addon

  local function load(prepare)
    state = wowapi.install()
    if prepare then prepare(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon.db.global.settings.onboarded, addon.db.global.settings.onboardedVersion = true, ns.Onboarding.VERSION
    addon:OnEnable()
  end

  after_each(function()
    wowapi.uninstall()
  end)

  describe("theme", function()
    it("defines every colour once, as r, g, b, a in 0..1", function()
      load()
      for name, c in pairs(ns.Theme.COLORS) do
        assert.are.equal(4, #c, name)
        for _, v in ipairs(c) do assert.is_true(v >= 0 and v <= 1, name) end
      end
      assert.has_error(function() ns.Theme.color("nope") end)
    end)

    it("uses the bundled fonts, and the game font when they fail or for other alphabets", function()
      load()
      local fs = _G.UIParent:CreateFontString()
      ns.Theme.font(fs, "tab")
      assert.are.equal(ns.Theme.FONT_FILES.display, fs.font[1])
      assert.are.equal(15, fs.font[2])
      state.fontsFail = true
      local fallback = _G.UIParent:CreateFontString()
      ns.Theme.font(fallback, "body")
      assert.are.equal(_G.GameFontHighlight, fallback.fontObject)
      state.fontsFail, state.locale = false, "ruRU"
      local russian = _G.UIParent:CreateFontString()
      ns.Theme.font(russian, "body")
      assert.is_nil(russian.font)
      assert.are.equal(_G.GameFontHighlight, russian.fontObject)
    end)

    it("points every texture and font into the addon's media folder", function()
      load()
      for _, path in pairs(ns.Theme.TEXTURES) do
        assert.is_truthy(path:find("^Interface\\AddOns\\CommunitiesForever\\media\\textures\\"), path)
      end
      for _, path in pairs(ns.Theme.FONT_FILES) do
        assert.is_truthy(path:find("^Interface\\AddOns\\CommunitiesForever\\media\\fonts\\"), path)
      end
    end)
  end)

  describe("window", function()
    it("starts at the design size, centred, once for windows saved before the revamp", function()
      load()
      local Kit = ns.Kit
      assert.are.same({ 880, 600 }, { Kit.windowGeometry({ width = 500, height = 400, top = 300, left = 20 }) })
      local w, h, top, left = Kit.windowGeometry({ width = 1000, height = 700, top = 800, left = 40,
                                                   layout = Kit.LAYOUT_VERSION })
      assert.are.same({ 1000, 700, 800, 40 }, { w, h, top, left })
      -- never smaller than the minimum
      assert.are.same({ 700, 480 }, { Kit.windowGeometry({ width = 10, height = 10, layout = Kit.LAYOUT_VERSION }) })
    end)

    it("opens with the community as title, the online count and the footer hint, at strata DIALOG", function()
      load()
      ns.MainFrame.toggle()
      local window = ns.MainFrame.window()
      assert.are.equal("Forever Friends", window.titleText.text)
      assert.are.equal("CommunitiesForever", window.subtitleText.text)
      assert.are.equal("\226\151\143 1 online", window.statusText.text) -- the mock's Battle.net friend
      assert.is_truthy(window.footerRightText.text:find("drag the title to move", 1, true)) -- CF-40: on the right
      assert.are.equal("DIALOG", window:GetFrameStrata())
      assert.are.same({ 880, 600 }, { window.width, window.height })
    end)

    it("saves position and size after moving or resizing", function()
      load()
      ns.MainFrame.toggle()
      local window = ns.MainFrame.window()
      window.width, window.height, window.top, window.left = 900, 640, 700, 120
      window.titleBar:RunScript("OnDragStop")
      local saved = addon.db.global.settings.window
      assert.are.same({ 900, 640, 700, 120, ns.Kit.LAYOUT_VERSION },
        { saved.width, saved.height, saved.top, saved.left, saved.layout })
      window.width = 950
      window.grip:RunScript("OnMouseUp")
      assert.are.equal(950, saved.width)
    end)

    it("closes from the close button and clears the search then", function()
      load()
      ns.MainFrame.toggle()
      ns.MainFrame.setFilter("mage")
      ns.MainFrame.window().closeButton:RunScript("OnClick")
      assert.is_false(ns.MainFrame.isShown())
      assert.are.equal("", ns.MainFrame.filterText())
    end)

    it("opens the settings from the gear button", function()
      load()
      ns.MainFrame.toggle()
      ns.MainFrame.window().settingsButton:RunScript("OnClick")
      assert.is_true(ns.SettingsWindow.isShown()) -- CF-43
    end)
  end)

  describe("tabs", function()
    it("switches tabs from the tab buttons and marks the active one", function()
      load()
      ns.MainFrame.toggle()
      local tabs = ns.MainFrame.tabs()
      assert.are.equal("friends", tabs.active)
      tabs.buttons.activity:RunScript("OnClick")
      assert.are.equal("activity", tabs.active)
      assert.is_true(tabs.buttons.activity.underline.shown)
      assert.is_false(tabs.buttons.friends.underline.shown)
    end)

    it("shows a badge only with a count", function()
      load()
      ns.MainFrame.toggle()
      local tabs = ns.MainFrame.tabs()
      assert.is_false(tabs.buttons.dungeons.badge.shown)
      tabs.setBadge("dungeons", 2)
      assert.is_true(tabs.buttons.dungeons.badge.shown)
      assert.are.equal("2", tabs.buttons.dungeons.badgeText.text)
      tabs.setBadge("dungeons", 0)
      assert.is_false(tabs.buttons.dungeons.badge.shown)
    end)
  end)

  describe("widgets", function()
    it("button: label, click, and 40% when disabled", function()
      load()
      local clicks = 0
      local b = ns.Kit.button(_G.UIParent, "Whisper", function() clicks = clicks + 1 end, "primary")
      assert.are.equal("Whisper", b.label.text)
      b:RunScript("OnClick")
      assert.are.equal(1, clicks)
      b:SetEnabled(false)
      assert.are.equal(0.4, b.alpha)
      assert.is_false(b.enabled)
    end)

    it("checkbox: toggles and reports, with an optional help line", function()
      load()
      local got
      local c = ns.Kit.checkbox(_G.UIParent, "Share my activity", "Levels, zones and dungeons", true,
        function(on) got = on end)
      assert.is_true(c:GetChecked())
      assert.are.equal("Levels, zones and dungeons", c.help.text)
      c:RunScript("OnClick")
      assert.is_false(c:GetChecked())
      assert.is_false(got)
    end)

    it("list row: selected shows the gold bar", function()
      load()
      local r = ns.Kit.listRow(_G.UIParent)
      assert.is_false(r.selectedBar.shown)
      r:SetSelected(true)
      assert.is_true(r.selectedBar.shown)
    end)

    it("skill bar: fill and cap fractions, clamped, and ticks", function()
      load()
      assert.are.same({ 0.5, 0.75 }, { ns.Kit.barFractions(150, 300, 225) })
      assert.are.same({ 1, 0 }, { ns.Kit.barFractions(400, 300, nil) })
      assert.are.same({ 0, 0 }, { ns.Kit.barFractions(10, 0, 5) })
      local bar = ns.Kit.skillBar(_G.UIParent)
      bar.width = 200
      bar:SetValues(97, 300, 150, { 0.25, 0.5, 0.75 })
      assert.are.equal(97 / 300 * 200, bar.fill.width)
      assert.are.equal(100, bar.cap.width)
      assert.are.equal(3, #bar.ticks)
    end)

    it("portrait: class icon, class-coloured ring, online dot", function()
      load()
      local p = ns.Kit.portrait(_G.UIParent, 32)
      p:SetClass("MAGE")
      assert.are.same(_G.CLASS_ICON_TCOORDS.MAGE, p.icon.texCoord)
      local c = _G.RAID_CLASS_COLORS.MAGE
      assert.are.same({ c.r, c.g, c.b }, p.ring.vertexColor)
      assert.is_false(p.dot.shown)
      p:SetOnline(true)
      assert.is_true(p.dot.shown)
    end)

    it("toast: shows its text and hides after 6 s", function()
      load()
      local t = ns.Kit.toast()
      t:Announce("Ironpaw's Orin Blackwell reached level 24", "PALADIN")
      assert.is_true(t.shown)
      assert.are.equal(ns.Kit.TOAST_SECONDS, state.timers[#state.timers].seconds)
      wowapi.runTimers(state)
      assert.is_false(t.shown)
    end)
  end)
end)
