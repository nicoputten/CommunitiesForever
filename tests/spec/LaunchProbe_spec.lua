local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-82: the hidden launch probe inside the addon (services/LaunchProbe.lua, LaunchProbeMissions.lua).
describe("the hidden launch probe", function()
  local state, ns, addon
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "IsInGroup", "C_DeathRecap", "C_PvP",
                  "UnitFactionGroup", "IsFishingLoot", "GetPVPThisWeekStats", "DoEmote", "hooksecurefunc",
                  "C_TradeSkillUI", "SetItemRef", "ProfessionsFrame", "UnitIsDead" }

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

  -- CF-116: V142, a player of a race beyond Vanilla's eight (the Skyborne): the race's token, ID and name only.
  it("records a race beyond the eight, enemy or friendly, without the player's name, silently", function()
    load()
    local printed = #state.printed
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V142) -- a known race: nothing
    assert.is_nil(results().V73) -- answered (CF-116): the honor message isn't watched any more
    _G.UnitRace = function() return "High Order Skyborne", "SkyborneHigh", 90 end
    _G.UnitIsEnemy = function() return false end
    state.unitGuids = { mouseover = "Player-4619-0A1B2C3E" }
    wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
    _G.UnitExists = function(unit) return unit == "mouseover" end
    wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
    local r = results().V142
    assert.are.equal("pass", r.status)
    assert.are.equal("UnitRace token and id: SkyborneHigh 90", r.detail)
    assert.are.equal("SkyborneHigh, id 90, name High Order Skyborne, friendly via mouseover", r.log[1])
    assert.is_nil(r.detail:find("Grim", 1, true))
    _G.UnitRace = function() return "Windshaper Skyborne", "SkyborneWind", 91 end
    _G.UnitIsEnemy = function() return true end
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "UPDATE_MOUSEOVER_UNIT")
    r = results().V142
    assert.are.equal("pass", r.status) -- the pass lists every race seen; one log line each
    assert.are.equal("UnitRace token and id: SkyborneHigh 90, SkyborneWind 91", r.detail)
    assert.are.equal("SkyborneWind, id 91, name Windshaper Skyborne, enemy via mouseover", r.log[2])
    assert.are.equal(2, #r.log)
    for _, line in ipairs(r.log) do assert.is_nil(line:find("Grim", 1, true)) end
    for i = printed + 1, #state.printed do
      assert.is_nil(state.printed[i]:lower():find("probe", 1, true))
    end
  end)

  it("leaves a secret race token out of V142, without an error", function()
    load()
    enemyTarget("SkyborneHigh")
    _G.issecretvalue = function(v) return v == "SkyborneHigh" or v == 90 end
    finally(function() _G.issecretvalue = nil end)
    _G.UnitRace = function() return "High Order Skyborne", "SkyborneHigh", 90 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V142)
    assert.is_nil(results().error)
  end)

  it("ticks the Hunt from the target at a counted kill when the honor message names nobody (CF-110)", function()
    load()
    enemyTarget("Orc")
    local dead = false
    _G.UnitIsDead = function() return dead end
    state.unitGuids = { target = "Player-4619-0A1B2C3D" }
    state.pvp = { hk = 10 }
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    state.serverTime, dead = state.serverTime + 2, true
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.are.equal("pass", results().Hunt.status)
    assert.are.equal("Grim Tusk: Orc WARRIOR via target at the kill", results().Hunt.detail)
  end)

  it("gives the Hunt an info line at a counted kill without a fitting victim (CF-110)", function()
    load()
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.are.equal("info", results().Hunt.status)
  end)

  it("looks at the same player once a minute (V142)", function()
    load()
    enemyTarget("Orc")
    state.unitGuids = { target = "Player-4619-0A1B2C3D" }
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    _G.UnitRace = function() return "High Order Skyborne", "SkyborneHigh", 90 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(results().V142)
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.are.equal("pass", results().V142.status)
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

  it("checks only buying at the auction house (V101, CF-113)", function()
    load()
    -- posting is answered: AUCTION_HOUSE_AUCTION_CREATED is no longer registered; a stored post pass gives way
    results().V101 = { status = "pass", detail = "posted: AUCTION_HOUSE_AUCTION_CREATED", at = 1, build = "70862" }
    wowapi.fireEvent(state, "AUCTION_HOUSE_PURCHASE_COMPLETED")
    assert.are.equal("pass", results().V101.status)
    assert.are.equal("bought: AUCTION_HOUSE_PURCHASE_COMPLETED", results().V101.detail)
  end)

  it("notes a handler error instead of showing it", function()
    load()
    ns.LaunchProbe.recipes.clicked("trade:Player-1-000C:3908:197") -- V60b waits for the window (CF-105)
    _G.C_TradeSkillUI = setmetatable({}, { __index = function() error("boom") end })
    wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
    _G.C_TradeSkillUI = nil
    assert.truthy(results().error.log[1]:find("TRADE_SKILL_SHOW", 1, true))
  end)

  it("registers nothing from 2026-11-18 and keeps the results", function()
    load(1794960000)
    assert.is_nil(next(results()))
    wowapi.uninstall()
    load(1794960000 - 10)
    local stored = results()
    state.serverTime = 1794960000
    _G.UnitExists = function(unit) return unit == "target" end
    _G.UnitIsPlayer = function() return true end
    _G.UnitRace = function() return "High Order Skyborne", "SkyborneHigh", 90 end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    assert.is_nil(stored.V142)
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
    for _, id in ipairs({ "V55", "V63", "V71", "V77", "V78", "V79", "V81", "V83", "V85", "V86", "V87" }) do
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
    assert.truthy(text:find("V142 open", 1, true))
  end)

  it("keeps looking at zone types after friendly passed (V123)", function()
    load()
    local zone = "friendly"
    _G.C_PvP = { GetZonePVPInfo = function() return zone end }
    wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
    assert.are.equal("pass", results().V123.status)
    assert.truthy(results().V123.detail:find("friendly", 1, true))
    zone = "hostile"
    wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
    assert.truthy(results().V123.detail:find("hostile", 1, true))
    zone = "friendly"
    wowapi.fireEvent(state, "ZONE_CHANGED_NEW_AREA")
    assert.truthy(results().V123.detail:find("hostile", 1, true)) -- friendly again changes nothing
    assert.are.equal(2, #results().V123.log) -- friendly, hostile (none at login: GetZonePVPInfo was missing)
  end)

  it("passes V108 on an emote at an enemy-faction player alone (the whisper part is answered)", function()
    _G.DoEmote = function() end
    _G.hooksecurefunc = function(name, fn)
      local original = _G[name]
      _G[name] = function(...)
        original(...)
        fn(...)
      end
    end
    load()
    _G.UnitIsPlayer = function() return true end
    _G.UnitFactionGroup = function(unit) return unit == "player" and "Horde" or "Alliance" end
    _G.DoEmote("FLEX", "target")
    assert.are.equal("pass", results().V108.status)
    assert.are.equal("emote FLEX on an enemy-faction player", results().V108.detail)
  end)

  -- CF-98: the recipe checks (services/LaunchProbeRecipes.lua); since CF-105 only V60b.
  describe("recipes", function()
    local linked, recipeIDs

    -- Tailoring with three recipes, two learned; Bolt of Silk Cloth (item 4305) from each way.
    local function tailoring()
      linked, recipeIDs = false, { 3839, 3840, 3841 }
      _G.C_TradeSkillUI = {
        GetAllRecipeIDs = function() return recipeIDs end,
        GetRecipeInfo = function(id)
          return { recipeID = id, name = "Bolt of Silk Cloth", learned = id ~= 3841, relativeDifficulty = 1,
                   numSkillUps = 1, numAvailable = 3, categoryID = 1100 }
        end,
        GetRecipeOutputItemData = function() return { itemID = 4305 } end,
        GetRecipeItemLink = function() return "|cffffffff|Hitem:4305::::::::60:::::|h[Bolt of Silk Cloth]|h|r" end,
        GetRecipeSchematic = function()
          return { outputItemID = 4305, name = "Bolt of Silk Cloth",
                   reagentSlotSchematics = { { quantityRequired = 4, reagents = { { itemID = 4306 } } } } }
        end,
        GetBaseProfessionInfo = function() return { professionID = 197, professionName = "Tailoring" } end,
        GetChildProfessionInfo = function() return { professionID = 2540 } end,
        GetTradeSkillListLink = function() return "|cffffd000|Htrade:Player-1-000A:3908:197|h[Tailoring]|h|r" end,
        IsTradeSkillLinked = function() return linked, linked and "Ada Stormwind" or nil end,
        OpenTradeSkill = function() end,
        GetTradeSkillLineForRecipe = function(id) return 2540, "Tailoring", id == 3839 and 197 or 185 end,
        GetRecipeCooldown = function() return nil end,
        GetRecipeSourceText = function() return "Trainer: Tailoring" end,
      }
    end

    local function withLinks()
      _G.SetItemRef = function() end
      _G.hooksecurefunc = function(name, fn)
        local original = _G[name]
        _G[name] = function(...)
          original(...)
          fn(...)
        end
      end
    end

    it("no longer reads the own profession window (V60 and V60c answered, CF-105)", function()
      tailoring()
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE")
      assert.is_nil(results().V60)
      assert.is_nil(results().V60c)
    end)

    it("passes V60b when a friend's link opens Blizzard's view while they are offline, without their GUID", function()
      tailoring()
      withLinks()
      load()
      addon.db.global.people["Ada#1001"] = { chars = { ["Player-4619-000B"] = { name = "Ada Stormwind" } } }
      _G.SetItemRef("trade:Player-4619-000B:3908:197", "[Tailoring]", "LeftButton")
      linked = true
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      local r = results().V60b
      assert.are.equal("pass", r.status)
      assert.are.equal("link of a friend offline opened Blizzard's view (IsTradeSkillLinked true, 3 recipes)", r.detail)
      assert.are.same({ "link of a friend offline clicked" }, r.log)
      wowapi.runTimers(state)
      assert.are.equal("pass", results().V60b.status)
    end)

    it("keeps V60b info for the own link, and notes a click that opened nothing", function()
      tailoring()
      withLinks()
      load()
      _G.SetItemRef("item:4305", "[Bolt of Silk Cloth]", "LeftButton") -- not a profession link
      assert.is_nil(results().V60b)
      _G.SetItemRef("trade:" .. state.player.guid .. ":3908:197", "[Tailoring]", "LeftButton")
      linked = true
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.equal("info", results().V60b.status)
      assert.truthy(results().V60b.detail:find("link of yours opened", 1, true))
      linked = false
      _G.SetItemRef("trade:Player-4619-000C:3908:197", "[Tailoring]", "LeftButton")
      wowapi.runTimers(state)
      assert.are.equal("info", results().V60b.status)
      assert.are.equal("link of someone else clicked, no linked window within 5 s", results().V60b.detail)
      local log = results().V60b.log
      assert.are.equal("seen: events none; IsTradeSkillLinked false; frame none shown", log[#log])
    end)

    -- CF-109: build 70862 said "no linked window" for links that opened.
    it("sees a window that opened inside SetItemRef, before the post-hook", function()
      tailoring()
      withLinks()
      _G.SetItemRef = function() linked = true end -- Blizzard opens it at once; the probe hooks this at load
      load()
      addon.db.global.people["Ada#1001"] = { chars = { ["Player-4619-000B"] = { name = "Ada Stormwind" } } }
      _G.SetItemRef("trade:Player-4619-000B:3908:197", "[Tailoring]", "LeftButton")
      assert.are.equal("pass", results().V60b.status)
      assert.truthy(results().V60b.detail:find("a friend offline opened", 1, true))
    end)

    it("sees a link that turns linked after the events, by looking once a second", function()
      tailoring()
      withLinks()
      load()
      addon.db.global.people["Ada#1001"] = { chars = { ["Player-4619-000B"] = { name = "Ada Stormwind" } } }
      _G.SetItemRef("trade:Player-4619-000B:3908:197", "[Tailoring]", "LeftButton")
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW") -- not linked yet
      assert.is_nil(results().V60b.status)
      linked = true
      wowapi.runTimers(state)
      assert.are.equal("pass", results().V60b.status)
    end)

    it("counts the own window as opened for the own link, also unlinked (frame or event)", function()
      tailoring()
      withLinks()
      load()
      _G.SetItemRef("trade:" .. state.player.guid .. ":3908:197", "[Tailoring]", "LeftButton")
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE")
      assert.are.equal("info", results().V60b.status)
      assert.are.equal("link of yours opened Blizzard's window (TRADE_SKILL_LIST_UPDATE, IsTradeSkillLinked false)",
        results().V60b.detail)
      wowapi.runTimers(state)
      _G.ProfessionsFrame = { IsShown = function() return true end }
      _G.SetItemRef("trade:" .. state.player.guid .. ":3908:197", "[Tailoring]", "LeftButton")
      assert.truthy(results().V60b.detail:find("(ProfessionsFrame, IsTradeSkillLinked false)", 1, true))
    end)

    it("notes what it saw when a friend's link opened nothing, and the other server", function()
      tailoring()
      withLinks()
      load()
      addon.db.global.people["Ada#1001"] = { chars = { ["Player-4619-000B"] = { name = "Ada Stormwind" } } }
      _G.SetItemRef("trade:Player-4619-000B:3908:197", "[Tailoring]", "LeftButton")
      wowapi.fireEvent(state, "TRADE_SKILL_DATA_SOURCE_CHANGED")
      wowapi.runTimers(state)
      assert.are.equal("fail", results().V60b.status)
      assert.are.equal("link of a friend offline clicked, no linked window within 5 s", results().V60b.detail)
      local log = results().V60b.log
      assert.are.equal("seen: events TRADE_SKILL_DATA_SOURCE_CHANGED; IsTradeSkillLinked false; frame none shown",
        log[#log])
      addon.db.global.people["Ada#1001"].chars["Player-6940-000D"] = { name = "Ada Stormwind" }
      _G.SetItemRef("trade:Player-6940-000D:3908:197", "[Tailoring]", "LeftButton")
      wowapi.runTimers(state)
      local r = results().V60b
      assert.are.equal("fail", r.status) -- a later info is kept apart, the fail stays
      assert.are.equal("link of a friend offline, other server clicked", r.log[#r.log - 1])
      assert.are.equal("link of a friend offline, other server clicked, no linked window within 5 s", r.later)
    end)

    it("counts only V60b of the recipe checks in /cf fp (CF-105, CF-109)", function()
      load()
      assert.are.equal(10, #ns.Probe.IDS)
      addon:OnSlashCommand("fp")
      local text = ns.ProbeReport.text()
      assert.is_nil(text:find("V60 ", 1, true))
      assert.is_nil(text:find("V60c", 1, true))
      assert.truthy(text:find("V60b open", 1, true))
    end)
  end)
end)
