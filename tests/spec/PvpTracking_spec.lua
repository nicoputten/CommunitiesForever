local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("PvP, duels and deaths (CF-52)", function()
  local state, ns, addon, myGuid
  local TODAY = 20744 -- mock realm date 2026-10-18
  local ME = "Ves Doombringer" -- the mock player

  local function load(opts, pvp)
    state = wowapi.install(opts)
    state.pvp = pvp
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    myGuid = state.player.guid
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function char() return addon.db.global.self.chars[myGuid] end
  local function entry() return addon.db.global.self.feed[TODAY][myGuid] end

  -- The combat log event of damage to the player: subevent, source GUID and flags, environmental type.
  local function damage(subevent, sourceGuid, sourceFlags, environment)
    state.combatEvent = { 1000.5, subevent, false, sourceGuid, "Someone", sourceFlags, 0, myGuid, ME, 0x511, 0,
                          environment }
    wowapi.fireEvent(state, "COMBAT_LOG_EVENT_UNFILTERED")
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("stores the counters and rank at login, and counts new kills by zone", function()
    load(nil, { hk = 100, rankID = 7, rankNumber = 3, rankName = "Sergeant", weekKills = 4, weekHonor = 90 })
    assert.are.same({ hk = 100, rank = 3, rankName = "Sergeant", weekKills = 4, weekHonor = 90 }, char().pvp)
    assert.is_nil(entry().kills) -- the first read only sets the base
    state.zone = "Ashenvale"
    state.pvp.hk, state.pvp.weekKills = 102, 6
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    state.pvp.hk = 103
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "Grim Tusk dies, honorable kill Rank: Scout "
      .. "(Estimated Honor Points: 12)")
    assert.are.same({ Ashenvale = 3 }, entry().kills)
    assert.are.equal(103, char().pvp.hk)
    assert.are.equal(6, char().pvp.weekKills)
  end)

  it("bumps the version right away for a new rank, and after 60 s for kills", function()
    load(nil, { hk = 100, rankID = 7, rankNumber = 3, rankName = "Sergeant" })
    settle()
    local version = addon.db.global.self.version
    state.serverTime = 2000
    state.pvp.hk = 101
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.are.equal(version, addon.db.global.self.version)
    assert.are.equal(2000, char().updatedAt)
    settle()
    assert.is_true(addon.db.global.self.version > version)
    version = addon.db.global.self.version
    state.serverTime = 3000
    state.pvp.rankNumber, state.pvp.rankName = 4, "Senior Sergeant"
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.is_true(addon.db.global.self.version > version)
  end)

  it("counts honor messages of kills when the counters are not readable", function()
    load()
    assert.is_nil(char().pvp)
    state.zone = "Hillsbrad Foothills"
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "Grim Tusk dies, honorable kill Rank: Scout "
      .. "(Estimated Honor Points: 12)")
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 50 honor points.")
    assert.are.same({ ["Hillsbrad Foothills"] = 1 }, entry().kills)
  end)

  it("records duels of your character with the opponent's full name, and counts them", function()
    load()
    state.serverTime = 1500
    wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", ME .. " has defeated Garraka Doombringer in a duel")
    wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", ME .. " has fled from Garraka Doombringer in a duel")
    wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", "Garraka Doombringer has defeated Someone Else in a duel")
    assert.are.same({ { t = 1500, won = true, vs = "Garraka Doombringer" },
                      { t = 1500, won = false, vs = "Garraka Doombringer" } }, entry().duels)
    assert.are.same({ 1, 1 }, { char().pvp.duelsWon, char().pvp.duelsLost })
  end)

  it("records deaths with their cause from the combat log", function()
    load()
    state.zone = "Thousand Needles"
    state.serverTime = 1100
    damage("ENVIRONMENTAL_DAMAGE", nil, 0, "Falling")
    wowapi.fireEvent(state, "PLAYER_DEAD")
    state.serverTime = 1200
    damage("SPELL_DAMAGE", "Player-1-X", 0x0548)
    wowapi.fireEvent(state, "PLAYER_DEAD")
    state.serverTime = 1300
    damage("SWING_DAMAGE", "Creature-0-1", 0x0a48)
    state.combatEvent = { 1, "SWING_DAMAGE", false, "Player-1-X", "Someone", 0x0548, 0, "Player-9-OTHER" }
    wowapi.fireEvent(state, "COMBAT_LOG_EVENT_UNFILTERED") -- damage to someone else
    wowapi.fireEvent(state, "PLAYER_DEAD")
    state.serverTime = 1400
    wowapi.fireEvent(state, "PLAYER_DEAD") -- the last damage was used for the previous death
    local causes = {}
    for i, d in ipairs(entry().deaths) do causes[i] = d.cause end
    assert.are.same({ "fall", "player", "creature", "other" }, causes)
    assert.are.same({ t = 1100, zone = "Thousand Needles", cause = "fall" }, entry().deaths[1])
    assert.are.equal(4, char().pvp.deaths)
  end)

  it("falls back to mirror timers without the combat log, and takes the death statistic", function()
    load({ missing = { CombatLogGetCurrentEventInfo = true } }, { deaths = 41 })
    assert.is_false(ns.PvpTracker.combatLog)
    assert.are.equal(41, char().pvp.deaths)
    wowapi.fireEvent(state, "MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, false, "Breath")
    state.pvp.deaths = 42
    wowapi.fireEvent(state, "PLAYER_DEAD")
    wowapi.fireEvent(state, "MIRROR_TIMER_START", "EXHAUSTION", 60000, 60000, -1, false, "Fatigue")
    wowapi.fireEvent(state, "MIRROR_TIMER_STOP", "EXHAUSTION")
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_DEAD") -- the timer stopped a minute ago
    assert.are.equal("drown", entry().deaths[1].cause)
    assert.are.equal("other", entry().deaths[2].cause)
    assert.are.equal(43, char().pvp.deaths) -- the statistic lagged behind the second death
  end)

  it("uses the death recap when the combat log gave nothing", function()
    load({ missing = { CombatLogGetCurrentEventInfo = true } })
    _G.C_DeathRecap = { GetRecapEvents = function()
      return { { timestamp = 2, event = "SWING_DAMAGE", sourceGUID = "Player-1-X" },
               { timestamp = 1, event = "ENVIRONMENTAL_DAMAGE", environmentalType = "Lava" } }
    end }
    wowapi.fireEvent(state, "PLAYER_DEAD")
    _G.C_DeathRecap = nil
    assert.are.equal("player", entry().deaths[1].cause)
  end)

  it("keeps the PvP data when the snapshot changes, and shows it in /cf self", function()
    load(nil, { hk = 5, rankID = 6, rankNumber = 2, rankName = "Grunt", weekKills = 1, weekHonor = 10 })
    wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
    assert.are.equal(12, char().level)
    assert.are.equal(5, char().pvp.hk)
    state.slash.cf("self")
    local found
    for _, line in ipairs(state.printed) do
      if line:find("PvP: 5 honorable kills, Grunt a.k.a. Accidental Flagger", 1, true) then found = true end
    end
    assert.is_true(found)
  end)

  it("sends the PvP data with the own record", function()
    load(nil, { hk = 5, rankID = 6, rankNumber = 2, rankName = "Grunt" })
    local record = ns.Merge.outgoingRecord(addon.db.global.self, true)
    assert.are.equal(5, record.chars[myGuid].pvp.hk)
  end)

  describe("raw kills (CF-55b)", function()
    local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "IsInGroup" }
    local HONOR = "Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)"

    -- An enemy player as the target: Grim Tusk, a level 33 Orc Warrior.
    local function enemyTarget()
      _G.UnitExists = function(unit) return unit == "target" end
      _G.UnitIsPlayer = function() return true end
      _G.UnitIsEnemy = function() return true end
      _G.UnitClass = function() return "Warrior", "WARRIOR" end
      _G.IsInGroup = function() return false end
      _G.GetUnitName = function(unit) return unit == "player" and ME or "Grim Tusk" end
      _G.UnitLevel = function(unit) return unit == "player" and state.player.level or 33 end
      _G.UnitRace = function(unit)
        if unit == "player" then return unpack(state.player.race) end
        return "Orc", "Orc", 2
      end
    end

    after_each(function()
      for _, name in ipairs(stubs) do _G[name] = nil end
    end)

    it("records a kill from the honor message with what was seen of the victim", function()
      load(nil, { hk = 10 })
      enemyTarget()
      state.zone = "Ashenvale"
      state.serverTime = 1500
      wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
      state.pvp.hk = 11
      wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", HONOR)
      wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
      for _ = 1, 5 do
        state.time = state.time + 5
        wowapi.runTimers(state)
      end
      assert.are.same({ { t = 1500, zone = "Ashenvale", name = "Grim Tusk", lvl = 33, myLvl = 11, class = "WARRIOR",
                          race = "Orc", solo = true } }, entry().pvpKills)
      assert.are.same({ Ashenvale = 1 }, entry().kills)
    end)

    it("adds kills the counter shows without an honor message, without a victim", function()
      load(nil, { hk = 10 })
      state.zone = "Ashenvale"
      state.pvp.hk = 12
      wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
      state.time = state.time + 1
      wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", HONOR) -- one of the two arrives a moment later
      for _ = 1, 5 do
        state.time = state.time + 5
        wowapi.runTimers(state)
      end
      assert.are.equal(2, #entry().pvpKills)
      assert.are.equal("Grim Tusk", entry().pvpKills[1].name)
      assert.is_nil(entry().pvpKills[2].name)
      assert.are.equal(11, entry().pvpKills[2].myLvl)
    end)

    it("marks battleground kills", function()
      load()
      state.instance = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
      wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", HONOR)
      assert.is_true(entry().pvpKills[1].bg)
      assert.is_nil(entry().pvpKills[1].solo) -- IsInGroup unknown
    end)
  end)
end)
