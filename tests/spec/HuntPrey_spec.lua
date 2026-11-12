local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("The Hunt's prey hint and alerts (CF-114, CF-122)", function()
  local state, ns, addon, hunt
  local PREY = "Player-4619-0000PREY"
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "TargetFrame" }

  -- huntOn: load with the Hunt in the draw (pool version 4 draws it, CF-104); off: without it (as pools 1 to 3).
  local function load(huntOn)
    state = wowapi.install()
    ns = helpers.loadAddon()
    ns.Doomsday.HUNT_SINCE = huntOn and 0 or nil
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    hunt = ns.DoomsdayTracker.huntFor("Horde")
    -- CF-122: a target frame with its portrait (Retail layout) for the mark and the toast.
    _G.TargetFrame = _G.CreateFrame("Frame", nil, _G.UIParent)
    _G.TargetFrame.TargetFrameContainer = { Portrait = _G.CreateFrame("Frame", nil, _G.TargetFrame) }
    _G.SOUNDKIT.MAP_PING = 3175
  end

  local function target() wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED") end
  local function mouseover() wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT") end
  local function toasts() return ns.HuntToast.shown() end

  -- An enemy player at the target and the mouseover, of race and class ids (default: the Hunt's; CF-118: pool
  -- version 6's Hunt is ids, the unit gives tokens and ids).
  local function enemy(race, class, isEnemy)
    race, class = race or hunt.race, class or hunt.class
    state.unitGuids = { target = PREY, mouseover = PREY }
    _G.UnitExists = function(unit) return unit == "target" or unit == "mouseover" or unit == "player" end
    _G.UnitIsPlayer = function() return true end
    _G.UnitIsEnemy = function(_, unit) return unit ~= "player" and isEnemy ~= false end
    _G.UnitClass = function() return "Someone", ns.Doomsday.CLASS_TOKENS[class], class end
    _G.GetUnitName = function(unit) return unit == "player" and "Ves Doombringer" or "Grim Tusk" end
    _G.UnitRace = function(unit)
      if unit == "player" then return unpack(state.player.race) end
      return "Someone", ns.Doomsday.RACE_TOKENS[race], race
    end
  end

  local function texts(added)
    local list = {}
    for _, line in ipairs(added) do list[#list + 1] = line.text end
    return list
  end

  local function hover() return texts(wowapi.hoverUnit(state, PREY)) end

  after_each(function()
    for _, name in ipairs(stubs) do _G[name] = nil end
    ns.HuntToast.reset()
    ns.HuntMark.reset()
    wowapi.uninstall()
  end)

  it("has no Hunt while the draw has none", function()
    load(false)
    assert.is_nil(hunt)
    enemy(2, 1)
    assert.are.same({}, hover())
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.same({}, state.printed)
  end)

  describe("with the Hunt on", function()
    before_each(function() load(true) end)

    it("knows today's Hunt of a Horde character", function()
      assert.is_table(hunt)
      assert.is_number(hunt.race) -- CF-118: race and class ids from pool version 6
      assert.is_number(hunt.class)
    end)

    it("marks the prey's tooltip", function()
      enemy()
      assert.are.same({ "Your prey: The Hunt" }, hover())
    end)

    it("marks the target and shows the toast with its sound once (HB01 A); no chat line any more", function()
      enemy()
      state.serverTime = 1000
      target()
      assert.are.equal("open", ns.HuntMark.shown())
      assert.are.same({ { title = ns.HuntAlerts.comboText(hunt), line = "+5 PvP \194\183 keep them targeted" } },
        toasts())
      assert.are.same({ 3175 }, state.sounds)
      assert.are.same({}, state.printed)
      assert.is_true(ns.HuntToast.isShown())
      state.time = state.time + ns.HuntAlerts.TOAST_SECONDS
      wowapi.runTimers(state)
      assert.is_false(ns.HuntToast.isShown())
      assert.are.equal("open", ns.HuntMark.shown()) -- the mark stays while they are the target
    end)

    it("toasts once per enemy per 10 minutes, and the sound only the first time each day", function()
      enemy()
      state.serverTime = 1000
      target()
      mouseover()
      state.serverTime = 1000 + ns.HuntAlerts.TOAST_EVERY - 1
      mouseover()
      assert.are.equal(1, #toasts())
      state.serverTime = 1000 + ns.HuntAlerts.TOAST_EVERY
      mouseover()
      assert.are.equal(2, #toasts())
      assert.are.same({ 3175 }, state.sounds)
    end)

    it("hides the mark when the target changes to someone else", function()
      enemy()
      target()
      assert.are.equal("open", ns.HuntMark.shown())
      enemy(hunt.race, hunt.class == 1 and 4 or 1)
      target()
      assert.is_nil(ns.HuntMark.shown())
    end)

    it("skips other classes and friendly players", function()
      enemy(hunt.race, hunt.class == 1 and 4 or 1)
      assert.are.same({}, hover())
      target()
      enemy(nil, nil, false)
      assert.are.same({}, hover())
      target()
      assert.is_nil(ns.HuntMark.shown())
      assert.are.same({}, toasts())
    end)

    it("in a battleground: only the mark, no toast and no tooltip line (HB01 note 7)", function()
      enemy()
      state.instance = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
      assert.are.same({}, hover())
      target()
      assert.are.equal("open", ns.HuntMark.shown())
      assert.are.same({}, toasts())
      assert.are.same({}, state.sounds)
    end)

    it("already bagged today: the grey mark, a quiet toast without sound (HB01 A2)", function()
      enemy()
      local today = ns.DoomsdayTracker.state().day
      addon.db.global.self.goals.days[today].done.hunt = 1234
      assert.are.same({}, hover())
      target()
      assert.are.equal("bagged", ns.HuntMark.shown())
      assert.are.same({ { title = ns.HuntAlerts.comboText(hunt),
                          line = "Already bagged today \194\183 no points" } }, toasts())
      assert.are.same({}, state.sounds)
      assert.are.same({}, state.printed)
    end)

    it("does nothing with Hunt alerts off, and marks again when turned on", function()
      enemy()
      ns.Settings.options().args.huntAlerts.set({}, false)
      target()
      assert.is_nil(ns.HuntMark.shown())
      assert.are.same({}, toasts())
      assert.are.same({}, hover())
      ns.Settings.options().args.huntAlerts.set({}, true)
      assert.are.equal("open", ns.HuntMark.shown())
      ns.SettingsWindow.open()
      assert.are.equal("Hunt alerts", ns.SettingsWindow.control("huntAlerts").text:GetText())
    end)

    it("keeps the sound off with Celebration sounds off", function()
      enemy()
      addon.db.global.settings.celebrationSounds = false
      target()
      assert.are.equal(1, #toasts())
      assert.are.same({}, state.sounds)
    end)

    it("bags the quarry: the big banner and the one chat line (HB01 B, C)", function()
      local today = ns.DoomsdayTracker.state().day
      local entry = addon.db.global.self.goals.days[today]
      entry.done.hunt = state.serverTime
      addon:SendMessage(ns.DoomsdayTracker.CHANGED, { "hunt" }, {})
      local combo = ns.HuntAlerts.comboText(hunt)
      assert.are.same({ "Quarry bagged: " .. combo .. " (+5 PvP)." }, state.printed)
      state.time, state.serverTime = state.time + 5, state.serverTime + 5
      wowapi.runTimers(state)
      local b = ns.CelebrationBanner.shown()[1]
      assert.are.same({ "big", "Quarry bagged", combo, "+5 PvP", "crosshair", "First in the group" },
        { b.weight, b.kicker, b.title, b.points, b.icon, b.badge })
    end)

    it("ignores a secret race instead of comparing it", function()
      enemy()
      -- CF-118: a secret race is secret in every return (the token and the id).
      _G.issecretvalue = function(v) return v == hunt.race or v == ns.Doomsday.RACE_TOKENS[hunt.race] end
      finally(function() _G.issecretvalue = nil end)
      assert.are.same({}, hover())
    end)
  end)
end)
