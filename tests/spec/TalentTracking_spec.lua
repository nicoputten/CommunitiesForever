local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("talents and role in the window (CF-18)", function()
  local state, ns, addon

  local VES = "Player-4619-01627852"

  -- Arms build: 17 points left, Fury and Protection columns empty.
  local function armsBuild()
    return {
      { posX = 1020, ranks = 2 }, { posX = 1620, ranks = 6 }, { posX = 2220, ranks = 9 }, { posX = 2820, ranks = 0 },
      { posX = 5020, ranks = 0 }, { posX = 5620, ranks = 0 }, { posX = 6220, ranks = 0 }, { posX = 6820, ranks = 0 },
      { posX = 9080, ranks = 0 }, { posX = 9680, ranks = 0 }, { posX = 10280, ranks = 0 }, { posX = 10880, ranks = 0 },
    }
  end

  local function load()
    state = wowapi.install()
    state.player.classFile = "WARRIOR"
    state.talentNodes = armsBuild()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function me()
    return addon.db.global.self.chars[VES]
  end

  local function roleOption()
    local roles = ns.Settings.options().args.roles.args
    for _, option in pairs(roles) do
      if option.name == "Ves Doombringer" then return option end
    end
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("stores the point split, main tree and guessed role on login", function()
    load()
    assert.are.same({ { name = "Arms", points = 17 }, { name = "Fury", points = 0 },
                      { name = "Protection", points = 0 } }, me().talents)
    assert.are.equal(1, me().mainTree)
    assert.are.equal("dps", me().autoRole)
    assert.are.equal("dps", me().role)
  end)

  it("updates after spending talent points, debounced", function()
    load()
    local before = addon.db.global.self.version
    state.serverTime = 2000
    state.talentNodes[9].ranks = 20 -- Protection
    wowapi.fireEvent(state, "TRAIT_CONFIG_UPDATED", 9038911)
    assert.are.equal(17, me().talents[1].points) -- not yet
    settle()
    assert.are.equal(20, me().talents[3].points)
    assert.are.equal("tank", me().role)
    assert.is_true(addon.db.global.self.version > before)
  end)

  it("keeps the talents when they cannot be read for a moment", function()
    load()
    state.talentNodes = nil
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, true)
    assert.are.equal(17, me().talents[1].points)
  end)

  it("lets the player override the role per character in settings", function()
    load()
    local option = roleOption()
    assert.are.equal("Auto (DPS)", option.values.auto)
    assert.are.equal("auto", option.get())
    local before = addon.db.global.self.version
    state.serverTime = 3000
    option.set({}, "tank")
    assert.are.equal("tank", me().role)
    assert.are.equal("tank", me().roleOverride)
    assert.is_true(addon.db.global.self.version > before)

    -- A later talent refresh keeps the override.
    state.talentNodes[2].ranks = 7
    wowapi.fireEvent(state, "CHARACTER_POINTS_CHANGED")
    settle()
    assert.are.equal("tank", me().role)

    roleOption().set({}, "auto")
    assert.is_nil(me().roleOverride)
    assert.are.equal("dps", me().role)
  end)

  it("sends talents and role with the record", function()
    load()
    roleOption().set({}, "heal")
    local record = ns.Merge.outgoingRecord(addon.db.global.self)
    assert.are.equal("heal", record.chars[VES].role)
    assert.are.equal(17, record.chars[VES].talents[1].points)
  end)

  it("shows role and split on the character card", function()
    load()
    roleOption().set({}, "tank")
    ns.MainFrame.toggle()
    ns.FriendsTab.select("Vestras#1000\001" .. VES) -- CF-40: the native card
    local all = "\n" .. table.concat(ns.FriendsTab.cardTexts(), "\n") .. "\n"
    assert.is_truthy(all:find("\nTank\n", 1, true)) -- the role tile
    assert.is_truthy(all:find("\nset by player\n", 1, true))
    assert.is_truthy(all:find("\n17 / 0 / 0\n", 1, true)) -- classic notation next to the Talents header
    -- One bar per tree, in order (CF-40).
    local Arms, Fury = all:find("\nArms\n", 1, true), all:find("\nFury\n", 1, true)
    assert.is_truthy(Arms and Fury and Arms < Fury and all:find("\nProtection\n", 1, true))
  end)
end)
