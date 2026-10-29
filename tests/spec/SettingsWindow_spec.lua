local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-43: the settings window in the new look; every control writes through Settings.options().
describe("settings window (CF-43)", function()
  local state, ns, addon

  local function load()
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon.db.global.settings.onboarded, addon.db.global.settings.onboardedVersion = true, ns.Onboarding.VERSION
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    addon:OnEnable()
  end

  local function settings() return addon.db.global.settings end
  local function control(key) return ns.SettingsWindow.control(key) end

  after_each(function()
    wowapi.uninstall()
  end)

  it("finds an option by key, also in the Community chat group", function()
    load()
    assert.are.equal("When friends log in", ns.Settings.option("notifications").name)
    assert.are.equal("Chat color", ns.Settings.option("color").name)
    assert.is_nil(ns.Settings.option("nope"))
  end)

  it("knows a class from its ID, and keeps a known class file", function()
    load()
    assert.are.same({ "MAGE", "Mage" }, { ns.Classes.info(nil, 8) })
    assert.are.same({ "PRIEST", "Mage" }, { ns.Classes.info("PRIEST", 8) })
    assert.are.same({ "ROGUE" }, { ns.Classes.info("ROGUE", nil) })
  end)

  it("opens with /cf settings as a 640 x 500 dialog with the version in the footer", function()
    load()
    state.slash.cf("settings")
    local window = ns.SettingsWindow.window()
    assert.is_true(window.shown)
    assert.are.same({ 640, 500 }, { window.width, window.height })
    assert.are.equal("Settings", window.titleText:GetText())
    assert.are.equal("v" .. tostring(addon.version), window.footerRightText:GetText())
    assert.is_truthy(window.footerText:GetText():find("Options", 1, true))
    window.scripts.OnKeyDown(window, "ESCAPE") -- CF-32: Esc closes it
    assert.is_false(ns.SettingsWindow.isShown())
  end)

  it("shows and writes every switch through its option", function()
    load()
    ns.Settings.open()
    local args = ns.Settings.options().args
    for _, key in ipairs({ "groupAsks", "notifications", "levelUps", "alert", "sound",
                           "keepGeneral", "openOnLogin", "ambientEffects" }) do
      local opt = args[key] or args.chat.args[key]
      local box = control(key)
      local before = box:GetChecked()
      assert.are.equal(opt.get(), before, key)
      box:RunScript("OnClick")
      assert.are.equal(not before, opt.get(), key) -- written through the option
      box:RunScript("OnClick")
    end
    assert.is_false(settings().openOnLogin) -- new keys with their defaults (rule 8)
    assert.is_true(settings().ambientEffects)
    control("minimap"):RunScript("OnClick")
    assert.is_true(settings().minimap.hide)
  end)

  it("commits the display name on Enter and fills the community choices", function()
    load()
    ns.Settings.open()
    local name = control("displayName")
    name:SetText("Nightfall")
    name:RunScript("OnEditFocusLost")
    assert.are.equal("Nightfall", addon.db.global.self.displayName)
    local community = control("community")
    assert.are.equal("Forever Friends", community.text:GetText())
    assert.are.same({ { value = "23125681", text = "Forever Friends" }, { value = "777", text = "Other Friends" } },
      community.list)
  end)

  it("resets the chat colour and opens the colour picker when there is one", function()
    load()
    ns.Settings.open()
    settings().chatColor = { r = 1, g = 0, b = 0 }
    control("resetColor"):RunScript("OnClick")
    assert.is_nil(settings().chatColor)
    local picked
    _G.ColorPickerFrame = {
      SetupColorPickerAndShow = function(_, info) picked = info end,
      GetColorRGB = function() return 0.1, 0.2, 0.3 end,
    }
    control("color"):RunScript("OnClick")
    picked.swatchFunc()
    _G.ColorPickerFrame = nil
    assert.are.same({ 0.1, 0.2, 0.3 }, control("color").color)
  end)

  it("lists your characters' roles and hides the invite link where it can't be set", function()
    load()
    ns.Settings.open()
    local rows = ns.SettingsWindow.roleRows()
    assert.is_true(#rows >= 1)
    assert.are.equal("Ves Doombringer", rows[1].name:GetText())
    assert.are.equal("Auto (no talents yet)", rows[1].select.text:GetText())
    assert.are.equal(not ns.Settings.options().args.inviteLink.hidden(), ns.SettingsWindow.window().invite.shown)
  end)

  it("plays the ambient shine only while Ambient effects are on", function()
    load()
    local playing = false
    local frame = _G.CreateFrame("Frame")
    -- Retail dry run: a group on the frame slid the whole title bar. Only the streak texture may move.
    frame.CreateAnimationGroup = function() error("the shine must not animate its frame") end
    local createTexture = frame.CreateTexture
    local owner
    frame.CreateTexture = function(self, ...)
      local texture = createTexture(self, ...)
      texture.CreateAnimationGroup = function(t)
        owner = t
        return {
          CreateAnimation = function() return { SetDuration = function() end, SetStartDelay = function() end,
                                                SetOffset = function() end } end,
          SetLooping = function() end,
          Play = function() playing = true end,
          Stop = function() playing = false end,
          IsPlaying = function() return playing end,
        }
      end
      return texture
    end
    local shine = ns.Kit.shine(frame, frame, 5)
    assert.are.equal(shine.streak, owner)
    assert.is_true(playing)
    ns.Settings.options().args.ambientEffects.set({}, false)
    shine:Refresh()
    assert.is_false(playing)
    assert.is_false(shine.streak.shown)
  end)
end)
