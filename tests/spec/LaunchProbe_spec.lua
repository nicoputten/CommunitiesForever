local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-82: the hidden launch probe inside the addon (services/LaunchProbe.lua, LaunchProbeMissions.lua).
describe("the hidden launch probe", function()
  local state, ns, addon
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "IsInGroup", "C_DeathRecap", "C_PvP",
                  "UnitFactionGroup", "IsFishingLoot", "GetPVPThisWeekStats", "DoEmote", "hooksecurefunc",
                  "C_TradeSkillUI", "SetItemRef", "ProfessionsFrame", "UnitIsDead", "GetRealZoneText" }

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
    assert.are.equal("info", results().V82.status) -- no riding skill in the mock
    assert.are.equal(1794000000, results().V82.at)
    assert.are.equal(ns.Store.SCHEMA_VERSION, addon.db.global.schemaVersion)
  end)

  -- CF-120: V74, an enemy player with a skull: UnitLevel -1, or a level 10 or more above yours; no names.
  it("records a skull's UnitLevel -1 without a name, silently (V74)", function()
    load()
    local printed = #state.printed
    enemyTarget("Orc")
    _G.UnitLevel = function(unit) return unit == "player" and 20 or 25 end
    state.unitGuids = { target = "Player-4619-0A1B2C3D" }
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V74) -- an ordinary level: nothing
    assert.is_nil(results().V73) -- answered (CF-116): the honor message isn't watched any more
    _G.UnitLevel = function(unit) return unit == "player" and 20 or -1 end
    _G.UnitExists = function(unit) return unit == "mouseover" end
    state.unitGuids = { mouseover = "Player-4619-0A1B2C3E" }
    wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
    local r = results().V74
    assert.are.equal("pass", r.status)
    assert.are.equal("skull: UnitLevel -1 via mouseover", r.detail)
    assert.is_nil(r.detail:find("Grim", 1, true))
    for i = printed + 1, #state.printed do
      assert.is_nil(state.printed[i]:lower():find("probe", 1, true))
    end
  end)

  it("passes V74 on a readable level 10 or more above yours, and ignores friendly players", function()
    load()
    enemyTarget("Orc")
    _G.UnitIsEnemy = function() return false end
    _G.UnitLevel = function(unit) return unit == "player" and 20 or -1 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V74) -- not an enemy
    _G.UnitIsEnemy = function() return true end
    _G.UnitLevel = function(unit) return unit == "player" and 20 or 31 end
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("pass", results().V74.status)
    assert.are.equal("10+ levels above: UnitLevel 31 at own 20 (not -1) via target", results().V74.detail)
  end)

  it("notes a secret enemy level in V74 as info, without an error", function()
    load()
    enemyTarget("Orc")
    _G.issecretvalue = function(v) return v == 33 end
    finally(function() _G.issecretvalue = nil end)
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("info", results().V74.status)
    assert.are.equal("enemy player's UnitLevel secret via target", results().V74.detail)
    assert.is_nil(results().error)
  end)

  it("ticks the Hunt from the target at a counted kill when the honor message names nobody (CF-110)", function()
    load()
    enemyTarget("Orc")
    local dead = false
    _G.UnitIsDead = function() return dead end
    state.unitGuids = { target = "Player-4619-0A1B2C3D" }
    state.pvp = { hk = 10 }
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED") -- the counter's base
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    state.serverTime = state.serverTime + 2
    state.pvp.hk = 11
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.is_nil(results().Hunt) -- CF-117: picked at the re-check, not at the rise
    dead = true
    wowapi.runTimers(state)
    assert.are.equal("pass", results().Hunt.status)
    assert.are.equal("Orc WARRIOR via target, dead after the delay, 1 candidate", results().Hunt.detail)
    assert.are.equal("UnitIsDead exists, target dead true", results().Hunt.log[1]) -- CF-120: no health (V143)
  end)

  it("gives the Hunt an info line at a counted kill without a fitting victim (CF-110)", function()
    load()
    state.pvp = { hk = 10 }
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED") -- the counter's base
    state.pvp.hk = 11
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    wowapi.runTimers(state)
    assert.are.equal("info", results().Hunt.status)
    assert.truthy(results().Hunt.detail:find("no victim", 1, true))
  end)

  it("looks at the same player once a minute (V74)", function()
    load()
    enemyTarget("Orc")
    _G.UnitLevel = function(unit) return unit == "player" and 30 or 33 end
    state.unitGuids = { target = "Player-4619-0A1B2C3D" }
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    _G.UnitLevel = function(unit) return unit == "player" and 30 or -1 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V74)
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("pass", results().V74.status)
  end)

  it("no longer runs the answered death recap check (V120, CF-113)", function()
    load()
    _G.C_DeathRecap = { GetRecapEvents = function()
      return { { sourceName = "Grim Tusk", sourceGUID = "Player-1-0001" } }
    end }
    wowapi.fireEvent(state, "PLAYER_DEAD")
    wowapi.runTimers(state)
    assert.is_nil(results().V120)
    assert.is_nil(results().V81) -- answered at launch (CF-96)
  end)

  -- CF-120: V85, the items you put in a trade: only the item ID.
  it("records the item put in a trade (V85)", function()
    load()
    _G.GetTradePlayerItemLink = function() return nil end
    finally(function() _G.GetTradePlayerItemLink = nil end)
    wowapi.fireEvent(state, "TRADE_PLAYER_ITEM_CHANGED", 1)
    assert.are.equal("info", results().V85.status)
    assert.are.equal("TRADE_PLAYER_ITEM_CHANGED slot 1, GetTradePlayerItemLink missing", results().V85.detail)
    _G.GetTradePlayerItemLink = function() return "|cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r" end
    wowapi.fireEvent(state, "TRADE_PLAYER_ITEM_CHANGED", 1)
    assert.are.equal("pass", results().V85.status)
    assert.are.equal("TRADE_PLAYER_ITEM_CHANGED slot 1: item 2589", results().V85.detail)
  end)

  -- CF-120: V101, V108, V60b and V142 are answered; their stored results stay.
  it("no longer runs V101, V108, V60b and V142, and keeps their stored results", function()
    load()
    results().V101 = { status = "pass", detail = "bought: AUCTION_HOUSE_PURCHASE_COMPLETED", at = 1, build = "70888" }
    enemyTarget("Orc")
    _G.UnitRace = function() return "Windshaper Skyborne", "Skyborne", 96 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V142)
    assert.is_nil(ns.LaunchProbe.recipes)
    assert.are.same({ status = "pass", detail = "bought: AUCTION_HOUSE_PURCHASE_COMPLETED", at = 1, build = "70888" },
      results().V101)
    assert.are.same({ "V82", "V35b", "V74", "Hunt", "V85", "V122", "V123",
                      "V8", "V79", "V96", "V99", "V100", "V106", "V118", "V119" }, ns.Probe.IDS)
    addon:OnSlashCommand("fp")
    local text = ns.ProbeReport.text()
    for _, id in ipairs({ "V101", "V108", "V60b", "V142" }) do assert.is_nil(text:find(id, 1, true), id) end
  end)

  it("notes a handler error instead of showing it", function()
    load()
    _G.UnitName = function() return state.player.name end
    _G.GetNumBattlefieldScores = function() return 1 end
    _G.GetBattlefieldScore = function() error("boom") end
    finally(function() _G.GetNumBattlefieldScores, _G.GetBattlefieldScore = nil, nil end)
    wowapi.fireEvent(state, "UPDATE_BATTLEFIELD_SCORE")
    assert.truthy(results().error.log[1]:find("UPDATE_BATTLEFIELD_SCORE", 1, true))
  end)

  it("registers nothing from 2026-11-18 and keeps the results", function()
    load(1794960000)
    assert.is_nil(next(results()))
    wowapi.uninstall()
    load(1794960000 - 10)
    local stored = results()
    state.serverTime = 1794960000
    enemyTarget("Orc")
    _G.UnitLevel = function(unit) return unit == "player" and state.player.level or -1 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(stored.V74)
    assert.are.equal("info", stored.V82.status)
  end)

  it("answers /cf fp with a summary and the report, and keeps it out of the help", function()
    load()
    addon:OnSlashCommand("fp")
    assert.truthy(state.printed[#state.printed]:find("Probe (forever): ", 1, true))
    assert.truthy(ns.ProbeReport.text():find("V82 info", 1, true))
    addon:OnSlashCommand("help")
    for _, line in ipairs(state.printed) do assert.is_nil(line:find("/cf fp", 1, true)) end
  end)

  -- CF-96: the checks the launch results answered no longer run; their stored results stay as they are.
  it("no longer runs the checks answered at launch, and keeps their stored results", function()
    load()
    results().V84 = { status = "pass", detail = "IsFishingLoot true, 1 items", at = 1, build = "70790" }
    _G.IsFishingLoot = function() return true end
    wowapi.fireEvent(state, "LOOT_OPENED")
    wowapi.fireEvent(state, "PLAYER_DEAD")
    wowapi.fireEvent(state, "UI_INFO_MESSAGE", 0, "Trade complete.")
    for _, id in ipairs({ "V55", "V63", "V71", "V77", "V78", "V81", "V83", "V86", "V87" }) do
      assert.is_nil(results()[id], id)
    end
    assert.are.same({ status = "pass", detail = "IsFishingLoot true, 1 items", at = 1, build = "70790" },
      results().V84)
  end)

  -- CF-116: V73 (the honor message names no victim) and V80 (the duel lines) are answered and gone.
  it("no longer runs V73 and V80, and keeps their stored results", function()
    load()
    results().V73 = { status = "fail", detail = "no honor format matched", at = 1, build = "70862" }
    _G.COMBATLOG_HONORGAIN = "%s dies (Honorable Kill: %s). You gain %d Honor."
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "Grim Tusk dies (Honorable Kill: Grunt). You gain 12 Honor.")
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", state.player.name .. " has defeated Grim Tusk in a duel")
    assert.are.same({ status = "fail", detail = "no honor format matched", at = 1, build = "70862" }, results().V73)
    assert.is_nil(results().V80)
    addon:OnSlashCommand("fp")
    local text = ns.ProbeReport.text()
    assert.is_nil(text:find("V73", 1, true))
    assert.is_nil(text:find("V80", 1, true))
    assert.truthy(text:find("V74 open", 1, true))
  end)

  -- CF-120: V123 reads the type at every zone change and again 2 s later, and counts zones per type.
  it("reads the zone's PvP type at every zone change and counts zones per type (V123)", function()
    local zone, kind = "Durotar", nil
    _G.C_PvP = { GetZonePVPInfo = function() return kind end }
    load()
    results().V123 = nil -- the login's own read (the mock's zone)
    ns.LaunchProbe.zoneReset()
    _G.GetRealZoneText = function() return zone end
    wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
    assert.are.equal("info", results().V123.status)
    assert.are.equal("zones per type: none 1", results().V123.detail)
    assert.truthy(results().V123.log[#results().V123.log]:find("Durotar: missing, flagged", 1, true))
    zone, kind = "Orgrimmar", "friendly"
    wowapi.fireEvent(state, "ZONE_CHANGED")
    assert.are.equal("zones per type: friendly 1, none 1", results().V123.detail)
    zone, kind = "Ashenvale", nil
    wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
    kind = "contested" -- the type catches up after the event
    wowapi.runTimers(state)
    assert.are.equal("pass", results().V123.status)
    assert.are.equal("zones per type: contested 1, friendly 1, none 2", results().V123.detail)
    wowapi.fireEvent(state, "ZONE_CHANGED_INDOORS") -- the same zone and type again: nothing new
    assert.are.equal("zones per type: contested 1, friendly 1, none 2", results().V123.detail)
  end)

  -- CF-120 (Nico): checks that never answered try other ways (services/LaunchProbeWorld.lua).
  describe("other ways for the unanswered checks (CF-120)", function()
    local saved = {}
    local names = { "GetPVPRankInfo", "GetBindLocation", "GetMerchantItemLink", "CanMerchantRepair",
                    "GetRepairAllCost", "GetInboxHeaderInfo", "GetInboxNumItems", "TakeInboxItem", "GetLootSourceInfo",
                    "GetLootSlotLink", "JumpOrAscendStart", "C_UnitAuras", "C_Spell", "GetSpellInfo" }
    before_each(function()
      for _, n in ipairs(names) do saved[n] = _G[n] end
    end)
    after_each(function()
      for _, n in ipairs(names) do _G[n] = saved[n] end
    end)

    -- hooksecurefunc(name, fn) or hooksecurefunc(table, key, fn), as the game's.
    local function hooks()
      _G.hooksecurefunc = function(owner, key, fn)
        if type(owner) == "string" then owner, key, fn = _G, owner, key end
        local original = owner[key]
        owner[key] = function(...)
          local r = { original(...) }
          fn(...)
          return unpack(r)
        end
      end
    end

    it("reads the clubIds and whether GetPVPRankInfo exists at login (V8, V79)", function()
      load() -- the mock's clubs
      assert.are.equal("clubs: type 1 id 23125681, type 2 id 999, type 1 id 777", results().V8.detail)
      assert.are.equal("info", results().V8.status)
      assert.are.equal("pass", results().V79.status) -- the mock has it
      assert.truthy(results().V79.detail:find("GetPVPRankInfo exists", 1, true))
    end)

    it("sees the hearthstone's place by the event, the ConfirmBinder hook or a change since login (V96)", function()
      local place = "Orgrimmar"
      _G.GetBindLocation = function() return place end
      _G.ConfirmBinder = function() place = "Crossroads" end
      hooks()
      load()
      assert.is_nil(results().V96)
      _G.ConfirmBinder()
      wowapi.runTimers(state)
      assert.are.same({ "pass", "ConfirmBinder: GetBindLocation readable" },
        { results().V96.status, results().V96.detail })
      assert.are.equal("ConfirmBinder: GetBindLocation Crossroads", results().V96.log[1])
      results().V96 = nil
      wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
      assert.are.equal("GetBindLocation changed since login, seen at a zone change", results().V96.detail)
      _G.ConfirmBinder = nil
    end)

    it("reads the merchant's first item and the repair cost (V99)", function()
      load()
      _G.GetMerchantItemLink = function() return nil end
      _G.CanMerchantRepair = function() return true end
      _G.GetRepairAllCost = function() return 1250, true end
      wowapi.fireEvent(state, "MERCHANT_SHOW")
      assert.are.equal("info", results().V99.status)
      _G.GetMerchantItemLink = function() return "|cffffffff|Hitem:159::::::::20:::::|h[Water]|h|r" end
      wowapi.fireEvent(state, "MERCHANT_UPDATE")
      assert.are.same({ "pass", "MERCHANT_UPDATE: GetMerchantItemLink(1) item 159, CanMerchantRepair true, "
        .. "GetRepairAllCost 1250, true" }, { results().V99.status, results().V99.detail })
    end)

    it("tells whether a mail's sender is readable when taking from it, never the name (V100)", function()
      _G.GetInboxHeaderInfo = function() return nil, nil, "Ada Lovelace", "Hi" end
      _G.TakeInboxItem = function() end
      hooks()
      load()
      _G.TakeInboxItem(1, 1)
      assert.are.same({ "pass", "TakeInboxItem: sender readable" }, { results().V100.status, results().V100.detail })
      assert.is_nil(results().V100.detail:find("Ada", 1, true))
      _G.TakeInboxItem = nil
    end)

    it("reads fishing loot's source, also when only a Fishing cast tells it was fishing (V106)", function()
      load()
      _G.GetLootSourceInfo = function() return "GameObject-0-1-2-3-35591-0000" end
      _G.GetLootSlotLink = function() return "|cffffffff|Hitem:6303::::::::20:::::|h[Raw Slitherskin Mackerel]|h|r" end
      wowapi.fireEvent(state, "LOOT_OPENED")
      assert.is_nil(results().V106) -- not fishing
      wowapi.fireEvent(state, "UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", 7620)
      wowapi.fireEvent(state, "LOOT_READY")
      assert.are.same({ "pass", "LOOT_READY (a Fishing cast): source GameObject, item 6303" },
        { results().V106.status, results().V106.detail })
    end)

    it("counts jumps from a JumpOrAscendStart post-hook (V118)", function()
      _G.JumpOrAscendStart = function() end
      hooks()
      load()
      for _ = 1, 3 do _G.JumpOrAscendStart() end
      assert.are.same({ "pass", "JumpOrAscendStart post-hook ran 3 times" },
        { results().V118.status, results().V118.detail })
      _G.JumpOrAscendStart = nil
    end)

    it("notes the campfire's spell and a new aura while it burns (V119)", function()
      local list = {}
      _G.C_UnitAuras = { GetAuraDataByIndex = function(_, i) return list[i] end }
      _G.C_Spell = { GetSpellInfo = function(id) return { name = id == 818 and "Basic Campfire" or "Other" } end }
      load()
      wowapi.fireEvent(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 818)
      assert.are.same({ "info", "campfire lit: spell 818 Basic Campfire" },
        { results().V119.status, results().V119.detail })
      list[1] = { name = "Cozy Fire", spellId = 7353, applications = 1, points = { 5 } }
      wowapi.fireEvent(state, "UNIT_AURA", "player")
      assert.are.same({ "pass", "campfire lit; new aura Cozy Fire 7353 stacks 1 points 5" },
        { results().V119.status, results().V119.detail })
      list[1].applications = 2
      wowapi.fireEvent(state, "UNIT_AURA", "player")
      assert.are.equal("aura near the campfire: Cozy Fire 7353 stacks 2 points 5",
        results().V119.log[#results().V119.log])
    end)
  end)
end)
