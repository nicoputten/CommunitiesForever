local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("The Hunt's prey hint (CF-114)", function()
  local state, ns, addon, hunt
  local PREY = "Player-4619-0000PREY"
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass" }

  -- huntOn: load with the Hunt in the draw (Doomsday.HUNT_SINCE is still nil in this pool version).
  local function load(huntOn)
    state = wowapi.install()
    ns = helpers.loadAddon()
    if huntOn then ns.Doomsday.HUNT_SINCE = 0 end
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    hunt = ns.DoomsdayTracker.huntFor("Horde")
  end

  -- An enemy player at the target and the mouseover, of race and class (default: the Hunt's).
  local function enemy(race, class, isEnemy)
    state.unitGuids = { target = PREY, mouseover = PREY }
    _G.UnitExists = function(unit) return unit == "target" or unit == "mouseover" or unit == "player" end
    _G.UnitIsPlayer = function() return true end
    _G.UnitIsEnemy = function(_, unit) return unit ~= "player" and isEnemy ~= false end
    _G.UnitClass = function() return "Someone", class or hunt.class end
    _G.GetUnitName = function(unit) return unit == "player" and "Ves Doombringer" or "Grim Tusk" end
    _G.UnitRace = function(unit)
      if unit == "player" then return unpack(state.player.race) end
      return "Someone", race or hunt.race, 1
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
    wowapi.uninstall()
  end)

  it("has no Hunt while the draw has none", function()
    load(false)
    assert.is_nil(hunt)
    enemy("Orc", "WARRIOR")
    assert.are.same({}, hover())
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.same({}, state.printed)
  end)

  describe("with the Hunt on", function()
    before_each(function() load(true) end)

    it("knows today's Hunt of a Horde character", function()
      assert.is_table(hunt)
      assert.is_string(hunt.race)
      assert.is_string(hunt.class)
    end)

    it("marks the prey's tooltip", function()
      enemy()
      assert.are.same({ "Your prey: The Hunt" }, hover())
    end)

    it("says the chat line once per player per few minutes, on target and mouseover", function()
      enemy()
      state.serverTime = 1000
      wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
      assert.are.same({ ns.DoomsdayView.preyChat(hunt) }, state.printed)
      wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
      assert.are.equal(1, #state.printed)
      state.serverTime = 1000 + ns.Doomsday.PREY_CHAT_EVERY
      wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
      assert.are.equal(2, #state.printed)
    end)

    it("skips other classes, friendly players and the battleground", function()
      enemy(hunt.race, hunt.class == "WARRIOR" and "ROGUE" or "WARRIOR")
      assert.are.same({}, hover())
      enemy(nil, nil, false)
      assert.are.same({}, hover())
      enemy()
      state.instance = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
      assert.are.same({}, hover())
      wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
      assert.are.same({}, state.printed)
    end)

    it("stops once the Hunt is done today", function()
      enemy()
      local today = ns.DoomsdayTracker.state().day
      addon.db.global.self.goals.days[today].done.hunt = 1234
      assert.are.same({}, hover())
      wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
      assert.are.same({}, state.printed)
    end)

    it("ignores a secret race instead of comparing it", function()
      enemy()
      _G.issecretvalue = function(v) return v == hunt.race end
      finally(function() _G.issecretvalue = nil end)
      assert.are.same({}, hover())
    end)
  end)
end)
