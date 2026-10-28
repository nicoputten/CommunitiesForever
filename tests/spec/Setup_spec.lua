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

  -- CF-43: the native wizard and prompt.
  local function wizard() return ns.Setup.wizard() end
  local function text() return table.concat(ns.Setup.texts(), "\n") end
  local function button(label) return assert(ns.Setup.buttons()[label], "no button " .. label) end
  local function click(label) button(label):RunScript("OnClick") end

  -- Clicks the button in the Next spot: Next, or "Create chat tab" on the chat step without a tab.
  local function forward(times)
    for _ = 1, times or 1 do
      click(ns.Setup.buttons()["Create chat tab"] and "Create chat tab" or "Next")
    end
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("opens the wizard a few seconds after the first login", function()
    load()
    assert.is_nil(wizard())
    wowapi.runTimers(state)
    assert.is_true(ns.Setup.isShown())
    local all = text()
    assert.is_truthy(all:find("Step 1 of 6", 1, true))
    assert.is_truthy(all:find("Welcome", 1, true))
    assert.is_truthy(all:find("Who is who in your community", 1, true))
    assert.is_truthy(all:find("Dungeons", 1, true)) -- the three tiles
    assert.is_false(button("Back").enabled)
    assert.is_truthy(ns.Setup.buttons()["Skip setup"])
  end)

  it("walks through all steps to Finish and does not open again", function()
    load()
    wowapi.runTimers(state)
    for _, title in ipairs({ "Community", "Your name", "Community chat", "Notifications", "Done" }) do
      forward()
      assert.are.equal(title, wizard().titleText:GetText())
    end
    assert.is_truthy(text():find("/cf setup", 1, true))
    click("Finish")
    assert.is_false(ns.Setup.isShown())
    assert.is_true(settings().onboarded)
    assert.are.equal(ns.Onboarding.VERSION, settings().onboardedVersion)
    assert.is_nil(ns.Setup.plan()) -- the character it ran on gets no prompt
  end)

  it("counts Skip setup and closing as done, and reopens with /cf setup", function()
    load()
    wowapi.runTimers(state)
    click("Skip setup")
    assert.is_false(ns.Setup.isShown())
    assert.is_true(settings().onboarded)
    addon:OnSlashCommand("setup")
    assert.is_true(ns.Setup.isShown())
    forward()
    click("Back")
    assert.is_truthy(text():find("Step 1 of 6", 1, true))
  end)

  it("shows the community to pick, and how to join without one", function()
    load()
    wowapi.runTimers(state)
    forward()
    local select = ns.Setup.communitySelect()
    assert.is_true(select.shown)
    assert.are.equal("23125681", select.value)
    assert.are.equal("Forever Friends", select.text:GetText())
    -- Picking from the menu (ContextMenu) writes the setting.
    _G.MenuUtil = { CreateContextMenu = function(_, build)
      local root = { CreateTitle = function() end, CreateButton = function(_, label, fn)
        if label == "Other Friends" then fn() end
      end }
      build(nil, root)
    end }
    select:RunScript("OnClick")
    _G.MenuUtil = nil
    assert.are.equal("777", settings().clubId)

    wowapi.uninstall()
    load(function() end)
    state.clubs = {}
    addon:OnSlashCommand("setup")
    forward()
    assert.is_truthy(text():find("ask a friend in it for the invite link", 1, true))
    assert.is_false(ns.Setup.communitySelect().shown)
  end)

  it("saves the display name when leaving the step, only when it changed", function()
    load()
    wowapi.runTimers(state)
    forward(2)
    local edit = ns.Setup.nameField()
    assert.are.equal(state.player.battleTag:match("^[^#]+"), edit:GetText()) -- prefilled with the BattleTag name part
    local version = addon.db.global.self.version
    forward()
    assert.is_nil(addon.db.global.self.displayName)
    assert.are.equal(version, addon.db.global.self.version)
    click("Back")
    ns.Setup.nameField():SetText("Alice")
    forward()
    assert.are.equal("Alice", addon.db.global.self.displayName)
  end)

  it("creates the Community tab from the Next spot and goes on", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    local windows = #state.chatWindows
    click("Create chat tab")
    assert.are.equal(windows + 1, #state.chatWindows)
    assert.is_true(settings().chatTab[guid()])
    assert.are.equal("Notifications", wizard().titleText:GetText())
    click("Back")
    assert.is_truthy(text():find("This character has a", 1, true))
    button("Next") -- with a tab the step has Skip setup and Next again
    button("Skip setup")
  end)

  it("goes on without a tab with Not now (in place of Skip setup)", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    local windows = #state.chatWindows
    assert.is_nil(ns.Setup.buttons()["Skip setup"])
    click("Not now")
    assert.are.equal(windows, #state.chatWindows)
    assert.is_true(ns.Setup.isShown())
    assert.are.equal("Notifications", wizard().titleText:GetText())
  end)

  it("starts every switch at the settings defaults and writes the settings", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    local chat = { keepGeneral = "chatKeepGeneral", alert = "chatAlert", sound = "chatSound" }
    for key, default in pairs(chat) do
      local box = ns.Setup.checkbox(ns.Settings.options().args.chat.args[key].name)
      assert.are.equal(ns.Onboarding.DEFAULTS[default], box:GetChecked(), key)
    end
    forward()
    for _, key in ipairs({ "notifications", "levelUps", "minimap" }) do
      local box = ns.Setup.checkbox(ns.Settings.options().args[key].name)
      assert.are.equal(ns.Onboarding.DEFAULTS[key], box:GetChecked(), key)
    end
    ns.Setup.checkbox("When friends log in"):RunScript("OnClick")
    assert.is_false(settings().notifications)
  end)

  it("asks other characters once about the Community tab: one Create button, closing is no", function()
    load(function(global)
      global.settings.onboarded, global.settings.onboardedVersion = true, 1
    end)
    wowapi.runTimers(state)
    assert.is_nil(wizard())
    assert.is_true(ns.Setup.promptShown())
    assert.are.equal("Create a Community tab on this character too?", ns.Setup.prompt().texts[1]:GetText())
    ns.Setup.prompt():Hide() -- the X
    assert.is_false(ns.Setup.promptShown())
    assert.is_nil(ns.Setup.plan()) -- not asked again

    settings().chatTabPrompt = nil
    ns.Setup.check()
    ns.Setup.prompt().create:RunScript("OnClick")
    assert.is_false(ns.Setup.promptShown())
    assert.is_true(settings().chatTab[guid()])
    assert.is_nil(ns.Setup.plan())
  end)

  it("creates the tab again after it was closed", function()
    load()
    wowapi.runTimers(state)
    forward(3)
    click("Create chat tab")
    local tab = state.chatWindows[#state.chatWindows]
    tab.closed = true -- closing a chat tab keeps its name
    ns.Setup.open()
    forward(3)
    local windows = #state.chatWindows
    click("Create chat tab")
    assert.are.equal(windows + 1, #state.chatWindows)
  end)

  -- CF-43: Open on login.
  it("opens the main window after login when Open on login is on, not with the setup", function()
    load(function(global)
      global.settings.onboarded, global.settings.onboardedVersion = true, 1
      global.settings.chatTabPrompt = { [state.player.guid] = true }
      global.settings.openOnLogin = true
    end)
    wowapi.runTimers(state)
    assert.is_true(ns.MainFrame.isShown())

    wowapi.uninstall()
    load(function(global) global.settings.openOnLogin = true end) -- first login: the setup instead
    wowapi.runTimers(state)
    assert.is_true(ns.Setup.isShown())
    assert.is_false(ns.MainFrame.isShown())
  end)
end)
