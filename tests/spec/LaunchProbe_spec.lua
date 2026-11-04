local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-82: the hidden launch probe inside the addon (services/LaunchProbe.lua, LaunchProbeMissions.lua).
describe("the hidden launch probe", function()
  local state, ns, addon
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "IsInGroup", "C_DeathRecap" }

  local function load(serverTime)
    state, ns, addon = helpers.client({ setup = function(s) s.serverTime = serverTime or 1794000000 end })
  end

  local function results()
    return addon.db.global.probe.results.forever
  end

  -- An enemy player as the target: Grim Tusk, a level 33 Orc Warrior.
  local function enemyTarget(race)
    _G.UnitExists = function(unit) return unit == "target" end
    _G.UnitIsPlayer = function() return true end
    _G.UnitIsEnemy = function() return true end
    _G.UnitClass = function() return "Warrior", "WARRIOR" end
    _G.IsInGroup = function() return false end
    _G.GetUnitName = function(unit) return unit == "player" and state.player.name or "Grim Tusk" end
    _G.UnitLevel = function(unit) return unit == "player" and state.player.level or 33 end
    _G.UnitRace = function(unit)
      if unit == "player" then return unpack(state.player.race) end
      return "Orc", race, 2
    end
  end

  after_each(function()
    for _, name in ipairs(stubs) do _G[name] = nil end
    wowapi.uninstall()
  end)

  it("stores its results in the saved data, per client, from the login", function()
    load()
    assert.are.equal("table", type(results()))
    assert.are.equal("pass", results().V63.status)
    assert.are.equal(1794000000, results().V63.at)
    assert.are.equal(2, addon.db.global.schemaVersion)
  end)

  it("ticks V74, V73, V76 and the Hunt from a target and the honor message, silently", function()
    load()
    local printed = #state.printed
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    state.serverTime = state.serverTime + 5
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN",
      "Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)")
    assert.are.equal("pass", results().V74.status)
    assert.are.equal("pass", results().V73.status)
    assert.are.equal("pass", results().V76.status)
    assert.are.same("Grim Tusk: Orc WARRIOR via target, 5 s before the kill", results().Hunt.detail)
    assert.is_nil(results().V73.detail:find("Grim Tusk", 1, true)) -- no names but the Hunt's and the killer's
    for i = printed + 1, #state.printed do -- the addon's own Doomsday kill line may print; the probe never does
      assert.is_nil(state.printed[i]:find("V7", 1, true))
      assert.is_nil(state.printed[i]:lower():find("probe", 1, true))
    end
  end)

  it("records a secret value as secret, without an error", function()
    load()
    enemyTarget("Orc")
    _G.issecretvalue = function(v) return v == 33 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    _G.issecretvalue = nil
    assert.are.same("fail", results().V74.status)
    assert.are.same("level secret via target", results().V74.detail)
    assert.is_nil(results().error)
  end)

  it("looks at the same player once a minute", function()
    load()
    enemyTarget(nil) -- race missing: a fail
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("fail", results().V74.status)
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("fail", results().V74.status)
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("pass", results().V74.status)
  end)

  it("names the killer from the death recap (V120)", function()
    load()
    _G.C_DeathRecap = { GetRecapEvents = function()
      return { { sourceName = "Wolf", sourceGUID = "Creature-0-1" },
               { sourceName = "Grim Tusk", sourceGUID = "Player-1-0001" } }
    end }
    wowapi.fireEvent(state, "PLAYER_DEAD")
    wowapi.runTimers(state)
    assert.are.equal("killed by player Grim Tusk", results().V120.detail)
    assert.are.equal("death recap", results().V81.detail)
  end)

  it("notes a handler error instead of showing it", function()
    load()
    _G.UnitIsPVP = function() error("boom") end
    wowapi.fireEvent(state, "PLAYER_FLAGS_CHANGED", "player")
    _G.UnitIsPVP = nil
    assert.truthy(results().error.log[1]:find("PLAYER_FLAGS_CHANGED", 1, true))
  end)

  it("registers nothing from 2026-11-18 and keeps the results", function()
    load(1794960000)
    assert.is_nil(next(results()))
    wowapi.uninstall()
    load(1794960000 - 10)
    local stored = results()
    state.serverTime = 1794960000
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(stored.V74)
    assert.are.equal("pass", stored.V63.status)
  end)

  it("answers /cf fp with a summary and the report, and keeps it out of the help", function()
    load()
    addon:OnSlashCommand("fp")
    assert.truthy(state.printed[#state.printed]:find("Probe (forever): ", 1, true))
    assert.truthy(ns.ProbeReport.text():find("V63 pass", 1, true))
    addon:OnSlashCommand("help")
    for _, line in ipairs(state.printed) do assert.is_nil(line:find("/cf fp", 1, true)) end
  end)
end)
