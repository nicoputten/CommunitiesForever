local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-82: the hidden launch probe inside the addon (services/LaunchProbe.lua, LaunchProbeMissions.lua).
describe("the hidden launch probe", function()
  local state, ns, addon
  local stubs = { "UnitExists", "UnitIsPlayer", "UnitIsEnemy", "UnitClass", "IsInGroup", "C_DeathRecap", "C_PvP",
                  "UnitFactionGroup", "IsFishingLoot", "GetPVPThisWeekStats", "DoEmote", "hooksecurefunc",
                  "C_TradeSkillUI", "SetItemRef" }

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
    assert.are.equal(2, addon.db.global.schemaVersion)
  end)

  it("ticks V73 and the Hunt from a target and the honor message, silently", function()
    load()
    local printed = #state.printed
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    state.serverTime = state.serverTime + 5
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN",
      "Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)")
    assert.is_nil(results().V74) -- answered at launch (CF-96); the target still feeds the Hunt
    assert.are.equal("pass", results().V73.status)
    assert.are.same("Grim Tusk: Orc WARRIOR via target, 5 s before the kill", results().Hunt.detail)
    assert.is_nil(results().V73.detail:find("Grim Tusk", 1, true)) -- no names but the Hunt's and the killer's
    for i = printed + 1, #state.printed do -- the addon's own Doomsday kill line may print; the probe never does
      assert.is_nil(state.printed[i]:find("V7", 1, true))
      assert.is_nil(state.printed[i]:lower():find("probe", 1, true))
    end
  end)

  local function honorKill()
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN",
      "Grim Tusk dies, honorable kill Rank: Grunt (Estimated Honor Points: 12)")
  end

  it("leaves a secret race out of the Hunt, without an error", function()
    load()
    enemyTarget("Orc")
    _G.issecretvalue = function(v) return v == "Orc" end
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    _G.issecretvalue = nil
    honorKill()
    assert.are.equal("info", results().Hunt.status)
    assert.is_nil(results().error)
  end)

  it("looks at the same player once a minute", function()
    load()
    enemyTarget(nil) -- race missing: not usable for the Hunt
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    honorKill()
    assert.are.equal("info", results().Hunt.status)
    state.serverTime = state.serverTime + 60
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    honorKill()
    assert.are.equal("pass", results().Hunt.status)
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
    assert.is_nil(results().V81) -- answered at launch (CF-96)
  end)

  it("notes a handler error instead of showing it", function()
    load()
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
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    honorKill()
    assert.is_nil(stored.V73)
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

  it("passes V73 from the honor message variant without a rank, naming the global (CF-101)", function()
    load()
    _G.COMBATLOG_HONORGAIN = "%s dies (Honorable Kill: %s). You gain %d Honor."
    _G.COMBATLOG_HONORGAIN_NO_RANK = "%s dies (Honorable Kill). You gain %d Honor."
    finally(function() _G.COMBATLOG_HONORGAIN_NO_RANK = nil end)
    enemyTarget("Orc")
    wowapi.fireEvent(state, "PLAYER_TARGET_CHANGED")
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "Grim Tusk dies (Honorable Kill). You gain 12 Honor.")
    assert.are.equal("pass", results().V73.status)
    assert.are.equal("victim from the honor message via COMBATLOG_HONORGAIN_NO_RANK (second argument 12)",
      results().V73.detail)
    assert.are.equal("pass", results().Hunt.status)
  end)

  it("keeps the shape of an honor message no format matched, without the name (CF-101)", function()
    load()
    _G.COMBATLOG_HONORGAIN = "%s dies (Honorable Kill: %s). You gain %d Honor."
    wowapi.fireEvent(state, "CHAT_MSG_COMBAT_HONOR_GAIN", "Grim Tusk dies. You gain 12.5 Honor.")
    local r = results().V73
    assert.are.equal("fail", r.status)
    assert.are.equal("no honor format matched: x x dies. You gain 12.5 Honor.", r.detail)
    assert.truthy(r.log[#r.log - 1]:find("globals: ", 1, true) or r.log[#r.log]:find("globals: ", 1, true))
    for _, line in ipairs(r.log) do assert.is_nil(line:find("Grim", 1, true)) end
  end)

  it("notes PLAYER_PVP_KILLS_CHANGED under V73 (V79's open part)", function()
    load()
    _G.GetPVPThisWeekStats = function() return 2, 0 end
    wowapi.fireEvent(state, "PLAYER_PVP_KILLS_CHANGED")
    assert.are.equal("PLAYER_PVP_KILLS_CHANGED, week 2, 0", results().V73.log[1])
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

  -- CF-98: the recipe checks V60 and V60b (services/LaunchProbeRecipes.lua).
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

    it("reads the own profession window: counts and IDs only (V60)", function()
      tailoring()
      load()
      local printed = #state.printed
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      local r = results().V60
      assert.are.equal("pass", r.status)
      assert.are.equal("base 197, child 2540; 3 recipes, 2 learned; item from output/link/schematic; list link yes",
        r.detail)
      assert.are.same({ "recipe 3839: output 4305, link 4305, schematic 4305",
                        "recipe 3840: output 4305, link 4305, schematic 4305" }, r.log)
      assert.is_nil(r.detail:find("Bolt", 1, true))
      assert.is_nil(r.detail:find("Tailoring", 1, true))
      assert.are.equal(printed, #state.printed) -- silent
    end)

    it("waits for the list to load, scanning at most every 10 s (V60)", function()
      tailoring()
      recipeIDs = {}
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.equal("info", results().V60.status)
      recipeIDs = { 3839 }
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE")
      assert.are.equal("info", results().V60.status) -- throttled
      state.serverTime = state.serverTime + 10
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE")
      assert.are.equal("pass", results().V60.status)
    end)

    it("scans again after a throttled event, as no event may follow it (V60)", function()
      tailoring()
      recipeIDs = {}
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.equal("info", results().V60.status)
      recipeIDs = { 3839 }
      local timers = #state.timers
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE") -- the list loaded, but throttled; nothing fires after it
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE") -- one later scan only
      assert.are.equal(timers + 1, #state.timers)
      assert.are.equal("info", results().V60.status)
      state.serverTime = state.serverTime + 10
      wowapi.runTimers(state)
      assert.are.equal("pass", results().V60.status)
    end)

    it("tells each learned recipe's profession and one recipe's details, no names (V60c, CF-101)", function()
      tailoring()
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      local r = results().V60c
      assert.are.equal("pass", r.status)
      assert.are.equal("lines 2540/185:1 2540/197:1; colour yes, skill-ups yes, can make yes; reagents yes; "
        .. "source yes", r.detail)
      assert.are.same({ "recipe 3839: difficulty 1, skill-ups 1, can make 3, category 1100",
                        "recipe 3839: 1 reagent slots, first 4x item 4306; cooldown missing; source text 18 chars",
                        "list link: 4 fields, 28 chars" }, r.log)
      for _, line in ipairs(r.log) do assert.is_nil(line:find("Player-", 1, true)) end
      for _, line in ipairs(r.log) do assert.is_nil(line:find("Trainer", 1, true)) end
    end)

    it("fails V60c without the recipe's profession, and keeps scanning for it after V60 passed", function()
      tailoring()
      _G.C_TradeSkillUI.GetTradeSkillLineForRecipe = nil
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.equal("pass", results().V60.status)
      assert.are.equal("fail", results().V60c.status)
      assert.truthy(results().V60c.detail:find("^lines none;"))
      _G.C_TradeSkillUI.GetTradeSkillLineForRecipe = function() return 2540, "Tailoring", 197 end
      state.serverTime = state.serverTime + 10
      wowapi.fireEvent(state, "TRADE_SKILL_LIST_UPDATE")
      assert.are.equal("pass", results().V60c.status)
      assert.are.equal("pass", results().V60.status)
    end)

    it("fails without C_TradeSkillUI, and names missing functions (V60)", function()
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.same("fail", results().V60.status)
      assert.are.same("C_TradeSkillUI missing", results().V60.detail)
      wowapi.uninstall()
      tailoring()
      _G.C_TradeSkillUI.GetRecipeSchematic = nil
      _G.C_TradeSkillUI.GetRecipeItemLink = nil
      load()
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      assert.are.equal("pass", results().V60.status)
      assert.truthy(results().V60.detail:find("item from output;", 1, true))
      assert.are.equal("missing: GetRecipeItemLink, GetRecipeSchematic", results().V60.log[1])
    end)

    it("passes V60b when a friend's link opens Blizzard's view while they are offline, without their GUID", function()
      tailoring()
      withLinks()
      load()
      addon.db.global.people["Ada#1001"] = { chars = { ["Player-1-000B"] = { name = "Ada Stormwind" } } }
      _G.SetItemRef("trade:Player-1-000B:3908:197", "[Tailoring]", "LeftButton")
      linked = true
      wowapi.fireEvent(state, "TRADE_SKILL_SHOW")
      local r = results().V60b
      assert.are.equal("pass", r.status)
      assert.are.equal("link of a friend offline opened Blizzard's view (IsTradeSkillLinked true, 3 recipes)", r.detail)
      assert.are.same({ "link of a friend offline clicked" }, r.log)
      assert.is_nil(results().V60) -- someone else's recipes are not V60's
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
      _G.SetItemRef("trade:Player-1-000C:3908:197", "[Tailoring]", "LeftButton")
      wowapi.runTimers(state)
      assert.are.equal("info", results().V60b.status)
      assert.are.equal("link of someone else clicked, no linked window within 5 s", results().V60b.detail)
    end)

    it("counts V60 and V60b in /cf fp", function()
      load()
      assert.are.equal(15, #ns.Probe.IDS)
      addon:OnSlashCommand("fp")
      local text = ns.ProbeReport.text()
      assert.truthy(text:find("V60 open", 1, true))
      assert.truthy(text:find("V60b open", 1, true))
    end)
  end)
end)
