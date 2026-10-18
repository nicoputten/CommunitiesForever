local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("setup wizard and Community tab prompt (CF-26)", function()
  local state, ns, addon

  local function load(prepare)
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    if prepare then prepare(addon.db.global) end
    addon:OnEnable()
  end

  local function settings() return addon.db.global.settings end
  local function guid() return state.player.guid end

  local function frameTitled(title)
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" and w.title == title then return w end
    end
  end

  local function wizard() return frameTitled("CommunitiesForever setup") end

  local function prompt()
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" and w.title == "CommunitiesForever" and w ~= nil then
        for _, child in ipairs(w.children) do
          if child.text == "Create a Community tab on this character too?" then return w end
        end
      end
    end
  end

  local function walk(widget, visit)
    for _, child in ipairs(widget.children) do
      visit(child)
      walk(child, visit)
    end
  end

  local function text(widget)
    local out = {}
    walk(widget, function(w) if w.text then out[#out + 1] = w.text end end)
    return table.concat(out, "\n")
  end

  local function find(widget, widgetType, label)
    local found
    walk(widget, function(w)
      if not found and w.type == widgetType and (w.text == label or w.label == label) then found = w end
    end)
    return assert(found, "no " .. widgetType .. " " .. label)
  end

  local function click(widget, label) find(widget, "Button", label):Fire("OnClick") end

  local function forward(times)
    for _ = 1, times or 1 do click(wizard(), "Next") end
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("opens the wizard a few seconds after the first login", function()
    load()
    assert.is_nil(wizard())
    wowapi.runTimers(state)
    assert.is_true(ns.Setup.isShown())
    local all = text(wizard())
    assert.is_truthy(all:find("Step 1 of 6", 1, true))
    assert.is_truthy(all:find("Welcome", 1, true))
    assert.is_true(find(wizard(), "Button", "Back").disabled)
  end)

  it("walks through all steps to Finish and does not open again", function()
    load()
    wowapi.runTimers(state)
    for _, title in ipairs({ "Community", "Your name", "Community chat", "Notifications and sharing", "Done" }) do
      forward()
      assert.is_truthy(text(wizard()):find(title, 1, true))
    end
    assert.is_truthy(text(wizard()):find("/cf setup", 1, true))
    click(wizard(), "Finish")
    assert.is_false(ns.Setup.isShown())
    assert.is_true(settings().onboarded)
    assert.are.equal(ns.Onboarding.VERSION, settings().onboardedVersion)
    assert.is_nil(ns.Setup.plan()) -- the character it ran on gets no prompt
  end)

  it("counts Skip and closing as done, and reopens with /cf setup", function()
    load()
    wowapi.runTimers(state)
    click(wizard(), "Skip")
    assert.is_false(ns.Setup.isShown())
    assert.is_true(settings().onboarded)
    addon:OnSlashCommand("setup")
    assert.is_true(ns.Setup.isShown())
    forward()
    click(wizard(), "Back")
    assert.is_truthy(text(wizard()):find("Step 1 of 6", 1, true))
  end)

  it("shows the community to pick, and how to join without one", function()
    load()
    wowapi.runTimers(state)
    forward()
    local dropdown = find(wizard(), "Dropdown", "Community")
    assert.are.equal("23125681", dropdown.value)
    dropdown:Fire("OnValueChanged", "777")
    assert.are.equal("777", settings().clubId)

    wowapi.uninstall()
    load(function() end)
    state.clubs = {}
    addon:OnSlashCommand("setup")
    forward()
    assert.is_truthy(text(wizard()):find("ask a friend in it for the invite link", 1, true))
  end)

  it("saves the display name when leaving the step, only when it changed", function()
    load()
    wowapi.runTimers(state)
    forward(2)
    local edit = find(wizard(), "EditBox", "Display name")
    assert.are.equal(state.player.battleTag:match("^[^#]+"), edit.text) -- prefilled with the BattleTag name part
    local version = addon.db.global.self.version
    forward()
    assert.is_nil(addon.db.global.self.displayName)
    assert.are.equal(version, addon.db.global.self.version)
    click(wizard(), "Back")
    find(wizard(), "EditBox", "Display name"):SetText("Alice")
    forward()
    assert.are.equal("Alice", addon.db.global.self.displayName)
  end)

  it("creates the Community tab from the chat step", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    local windows = #state.chatWindows
    click(wizard(), "Create a Community tab (recommended)")
    assert.are.equal(windows + 1, #state.chatWindows)
    assert.is_true(settings().chatTab[guid()])
    assert.is_truthy(text(wizard()):find("This character has a", 1, true))
  end)

  it("starts every switch at the settings defaults and writes the settings", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    local chat = { keepGeneral = "chatKeepGeneral", alert = "chatAlert", sound = "chatSound" }
    for key, default in pairs(chat) do
      local box = find(wizard(), "CheckBox", ns.Settings.options().args.chat.args[key].name)
      assert.are.equal(ns.Onboarding.DEFAULTS[default], box.value, key)
    end
    forward()
    for _, key in ipairs({ "notifications", "levelUps", "shareActivity", "minimap" }) do
      local box = find(wizard(), "CheckBox", ns.Settings.options().args[key].name)
      assert.are.equal(ns.Onboarding.DEFAULTS[key], box.value, key)
    end
    find(wizard(), "CheckBox", "Login notifications"):Fire("OnValueChanged", false)
    assert.is_false(settings().notifications)
  end)

  it("asks other characters only about the Community tab", function()
    load(function(global)
      global.settings.onboarded, global.settings.onboardedVersion = true, 1
    end)
    wowapi.runTimers(state)
    assert.is_nil(wizard())
    assert.is_true(ns.Setup.promptShown())
    click(prompt(), "Not now")
    assert.is_false(ns.Setup.promptShown())
    assert.are.same({ kind = "chatPrompt" }, ns.Setup.plan()) -- asks again next login

    ns.Setup.check()
    click(prompt(), "Don't ask again")
    assert.is_nil(ns.Setup.plan())

    settings().chatTabPrompt = nil
    ns.Setup.check()
    click(prompt(), "Create")
    assert.is_true(settings().chatTab[guid()])
    assert.is_nil(ns.Setup.plan())
  end)
end)
