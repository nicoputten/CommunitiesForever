local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Dungeons tab (CF-24; CF-106 boards DL02, DL03)", function()
  local state, ns, addon
  local CLUB = "23125681"
  local NOW = 1793120000
  local VES, GARRAKA = "Player-4619-01627852", "Player-4619-01789956"

  -- runs: CF_RUNS as Data\Runs.lua would set it (CF-46); stored: global.plannedRuns from an earlier session.
  local function load(level, runs, stored)
    state = wowapi.install()
    state.serverTime = NOW
    state.player.level = level or 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = level or 20 end
    for _, f in ipairs(state.friends) do
      for _, g in ipairs(f.gameAccounts) do g.characterLevel = level or 20 end
    end
    ns = helpers.loadAddon()
    _G.CF_RUNS = runs
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.plannedRuns = stored
    addon.db.global.settings.clubId = CLUB
    -- No setup wizard or Community tab prompt in the way (CF-26).
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    addon:OnEnable()
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  -- CF-42: the native tab. Its texts without colour codes, one per line.
  local function text()
    local list = {}
    for i, t in ipairs(ns.DungeonsTab.texts()) do
      list[i] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  local function values()
    local list = {}
    for i, r in ipairs(ns.DungeonsTab.rows()) do list[i] = r.value end
    return list
  end

  local function row(value)
    for _, r in ipairs(ns.DungeonsTab.rows()) do
      if r.value == value then return r.frame end
    end
  end

  local function select(value) row(value):RunScript("OnClick") end

  local function open()
    settle()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
  end

  local DASH = "\226\128\147"

  after_each(function()
    wowapi.uninstall()
    _G.CF_RUNS = nil
  end)

  -- CF-46: a run of the Deadmines in 2 h 40 min that Ves organises; Garraka (Sjaak) is in, someone on Discord
  -- maybe; and one of Wailing Caverns tomorrow by someone else.
  local function sampleRuns(updatedAt)
    return {
      updatedAt = updatedAt or NOW - 600,
      reminderMinutes = 30,
      runs = {
        { id = "r1", dungeon = "dm", startsAt = NOW + 9600, state = "open", source = "site",
          note = "Bring water", url = "https://example.com/runs/r1",
          organiser = { battleTag = "Vestras#1000", guid = VES, name = "Ves Doombringer" },
          answers = {
            { guid = VES, name = "Ves Doombringer", answer = "in", role = "dps", source = "site" },
            { guid = GARRAKA, name = "Garraka Doombringer", answer = "in", role = "heal", source = "game" },
            { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "maybe", source = "discord" },
          } },
        { id = "r2", dungeon = "wc", startsAt = NOW + 26 * 3600, source = "discord",
          organiser = { battleTag = "Ada#1001", name = "Ada Lovewell" },
          answers = { { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "in", role = "tank",
                        source = "discord" },
                      { battleTag = "Bo#2002", name = "Bo Example", answer = "in", source = "discord" } } },
      },
    }
  end

  local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

  local function lootRow(name)
    for _, r in ipairs(ns.DungeonsTab.lootRows()) do
      if plain(r.name:GetText() or "") == name then return r end
    end
  end

  -- CF-106 (board DL02): every dungeon, grouped for the character you are on; no picker, no checkbox.
  it("lists every dungeon grouped Fits you, Higher and Lower, wings under their dungeon", function()
    load(20)
    open()
    local all = text()
    assert.is_truthy(all:find("\nDungeons\n", 1, true))
    assert.is_truthy(all:find("\nFits you\n", 1, true))
    assert.is_truthy(all:find("\nHigher\n", 1, true))
    assert.is_truthy(all:find("\nLower\n", 1, true)) -- Ragefire Chasm (13-18) is below 20
    assert.is_truthy(all:find("\nVes Doombringer 20\n", 1, true))
    local list = values()
    assert.are.same({ "wc", "dm", "sfk" }, { list[1], list[2], list[3] }) -- 20 fits 22-30 (2 below)
    assert.are.equal(#ns.Dungeons.LIST, #list) -- always every dungeon
    assert.are.equal("rfc", list[#list])
    -- Scarlet Monastery's wings, indented under its name.
    assert.is_truthy(all:find("\nScarlet Monastery\n", 1, true))
    assert.are.equal("Graveyard", row("smgy").name:GetText())
    assert.are.equal(26, row("smgy").name.points[1][2])
    assert.are.equal("26" .. DASH .. "36", row("smgy").right:GetText())
    assert.is_nil(ns.DungeonsTab.buttons()["Show all dungeons"])
    assert.is_nil(ns.DungeonsTab.buttons()["select:1"])
    assert.is_falsy(all:find("In range for", 1, true))
    assert.is_true(row("wc").selected) -- the first that fits
  end)

  it("says nothing fits yet and lists the rest under Higher (board DL03 A)", function()
    load(6)
    open()
    local all = text()
    assert.is_truthy(all:find("\nFits you\n", 1, true))
    assert.is_truthy(all:find("\nNothing fits yet \194\183 first at 13\n", 1, true))
    assert.are.equal("rfc", values()[1])
    assert.is_true(row("rfc").selected)
    assert.is_falsy(all:find("\nLower\n", 1, true))
  end)

  it("tags dungeons with a planned run; the tag and the planned run's button open it in Runs", function()
    load(20, sampleRuns())
    open()
    local dm = row("dm")
    assert.is_true(dm.tag.shown)
    assert.are.equal("r1", dm.tag.runId)
    assert.are.equal(ns.RunProgress.dayGroup(NOW + 9600, NOW, os.date), dm.tag.text:GetText())
    assert.is_false(row("sfk").tag.shown)
    select("dm")
    local jump
    for label, b in pairs(ns.DungeonsTab.buttons()) do
      if label:find(" \194\183 2 in \226\128\186$") then jump = b end
    end
    assert.is_not_nil(jump)
    jump:RunScript("OnClick")
    assert.are.equal("runs", ns.MainFrame.tabs().active)
    assert.are.equal("run:r1", addon.db.global.settings.runsTab.selected)
    ns.MainFrame.selectTab("dungeons")
    row("wc").tag:RunScript("OnClick")
    assert.are.equal("run:r2", addon.db.global.settings.runsTab.selected)
  end)

  it("shows a dungeon: header, Ask now, Plan a run…, Bosses & loot and Quests (board DL02)", function()
    load(20, { updatedAt = NOW - 600, site = "https://wow.example.org", runs = {} })
    open()
    select("dm")
    local all = text()
    assert.is_truthy(all:find("\nThe Deadmines\n", 1, true))
    assert.is_truthy(all:find("\nlevel 17" .. DASH .. "26 \194\183 Westfall \194\183 fits\n", 1, true))
    assert.is_truthy(all:find("\nBosses & loot\n", 1, true))
    assert.is_truthy(all:find("\nClassic data\n", 1, true))
    assert.is_truthy(all:find("\nQuests\n", 1, true))
    local tips = table.concat(ns.DungeonsTab.tips(), "\n")
    assert.is_truthy(tips:find("Drops and chances from Classic 1.12; Forever may differ.", 1, true))
    local buttons = ns.DungeonsTab.buttons()
    assert.is_truthy(buttons["Ask now"].tooltip:find("Whispers online friends who fit", 1, true))
    buttons["Ask now"]:RunScript("OnClick")
    assert.is_truthy(table.concat(ns.RunDialogs.texts(), "\n"):find("The Deadmines", 1, true))
    ns.RunDialogs.frame():Hide()
    -- Plan a run…: planning happens on the website (CF-64): its link to copy.
    assert.are.equal("primary", buttons["Plan a run\226\128\166"].kind)
    buttons["Plan a run\226\128\166"]:RunScript("OnClick")
    assert.are.equal("https://wow.example.org", ns.DungeonsTab.linkBox():GetText())
    assert.is_true(ns.DungeonsTab.linkBox().shown)
    -- Bosses in DungeonEncounter order, with their number; Cookie optional.
    assert.is_truthy(all:find("\n1\nRhahk'Zor\n", 1, true))
    assert.is_truthy(all:find("\n7\nCookie  optional\n", 1, true))
    -- A level 20 paladin can't use a dagger: dimmed to 45 %; a mace is fine.
    assert.are.equal(0.45, lootRow("Item 5195").alpha)
    assert.are.equal(1, lootRow("Item 5187").alpha)
    assert.are.equal("77%", lootRow("Item 5187").chance:GetText())
    assert.are.equal("Two-Hand \194\183 Mace", lootRow("Item 5187").type:GetText())
  end)

  it("shows 6 drops per boss and opens the rest in place until /reload (board DL03 F)", function()
    load(20)
    open()
    select("dm")
    assert.is_nil(lootRow("Item 7997")) -- Edwin's 8th drop
    local more = ns.DungeonsTab.buttons()["2 more"]
    assert.is_table(more)
    more:RunScript("OnClick")
    assert.is_table(lootRow("Item 7997"))
    assert.is_nil(ns.DungeonsTab.buttons()["2 more"])
    select("wc")
    select("dm")
    assert.is_table(lootRow("Item 7997")) -- stays open for this dungeon
    ns.MainFrame.start(addon) -- a /reload
    ns.DungeonsTab.reset()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
    assert.is_nil(lootRow("Item 7997"))
  end)

  it("hides what your class can't use with Usable by, remembered per character (board DL03 B)", function()
    load(20)
    open()
    select("dm")
    local check = ns.DungeonsTab.buttons()["Usable by Ves Doombringer"]
    assert.is_false(check.checked)
    check:RunScript("OnClick")
    assert.is_true(addon.db.global.settings.usableOnly[VES])
    assert.is_true(ns.DungeonsTab.buttons()["Usable by Ves Doombringer"].checked)
    assert.is_nil(lootRow("Item 5195")) -- the dagger
    assert.is_nil(lootRow("Item 5201")) -- Greenskin's staff
    assert.is_truthy(text():find("\nNothing usable by Ves Doombringer\n", 1, true))
    assert.is_table(lootRow("Item 1875")) -- a quest drop always stays
    -- Another character has its own switch.
    addon.db.global.settings.usableOnly = { ["Player-1-OTHER"] = true }
    ns.MainFrame.render()
    assert.is_table(lootRow("Item 5195"))
  end)

  it("tags quest drops and recipes nobody knows, with who could learn them (board DL03 C)", function()
    load(20)
    addon.db.global.self.chars[VES].professions = { [185] = { name = "Cooking", rank = 75 } }
    open()
    select("dm")
    local badge = lootRow("Item 1875")
    assert.are.equal("Quest", badge.tag.text:GetText())
    assert.is_true(badge.tag.shown)
    assert.are.equal("Quest item", badge.type:GetText())
    local recipe = lootRow("Item 728")
    assert.are.equal("Nobody knows it", recipe.tag.text:GetText())
    assert.are.equal("Recipe \194\183 Cooking", recipe.type:GetText())
    local tip = table.concat(recipe.tag.tipLines, "\n")
    assert.is_truthy(tip:find("Requires Cooking (75)
Nobody knows it
Can learn: Ves Doombringer (Cooking 75)", 1,
      true))
    addon.db.global.self.chars[VES].professions[185].rank = 74 -- below the required skill
    ns.MainFrame.render()
    assert.is_falsy(table.concat(lootRow("Item 728").tag.tipLines, "\n"):find("Can learn", 1, true))
    addon.db.global.self.chars[VES].professions[185].rank = 75
    -- Learned: no tag.
    addon.db.global.self.chars[VES].recipes = { [2795] = 0 }
    ns.MainFrame.render()
    assert.is_false(lootRow("Item 728").tag.shown)
  end)

  it("names items as the game has them, shows its tooltip on hover and links on Shift-click", function()
    load(20)
    local cruel = "|cnIQ3:|Hitem:5191::::::::20:::::|h[Cruel Barb]|h|r"
    _G.C_Item.GetItemInfo = function(id)
      if id == 5191 then return "Cruel Barb", cruel, 3, 24, 19, "Weapon", "Swords", 1, "INVTYPE_WEAPON", 135321 end
    end
    local shownItem
    _G.GameTooltip = { SetOwner = function() end, Show = function() end, Hide = function() end,
                       SetItemByID = function(_, id) shownItem = id end }
    local inserted
    _G.ChatEdit_InsertLink = function(link) inserted = link return true end
    open()
    select("dm")
    local r = lootRow("Cruel Barb")
    assert.is_table(r)
    assert.is_truthy(r.name:GetText():find("|cff4DA3FF", 1, true)) -- blue
    assert.are.equal("One-Hand \194\183 Sword", r.type:GetText())
    r:RunScript("OnEnter")
    assert.are.equal(5191, shownItem)
    r:RunScript("OnClick")
    assert.is_nil(inserted) -- a plain click links nothing
    _G.IsShiftKeyDown = function() return true end
    r:RunScript("OnClick")
    assert.are.equal(cruel, inserted)
    _G.GameTooltip, _G.IsShiftKeyDown, _G.ChatEdit_InsertLink = nil, nil, nil
  end)

  it("says who last cleared it: the final boss's last death in a kill log", function()
    load(20)
    open()
    addon.db.global.self.feed = { [20760] = { [VES] = { runs = { { name = "The Deadmines", kind = "party",
      bosses = 6, bossKills = { [90006] = NOW - 2 * 86400 }, with = { GARRAKA } } } } } }
    ns.MainFrame.render()
    select("dm")
    assert.is_truthy(text():find("\nLast cleared by you, Solvar \194\183 " .. os.date("%a", NOW - 2 * 86400) .. "\n",
      1, true))
    select("wc")
    assert.is_falsy(text():find("Last cleared", 1, true))
  end)

  it("lists the Group Finder's dungeons, also Forever's new ones without boss data (V46)", function()
    load(28)
    state.lfgActivities[1981] = { fullName = "Excavation Site: Wetlands", shortName = "Excavation Site: Wetlands",
      minLevelSuggestion = 26, maxLevelSuggestion = 33, maxNumPlayers = 5, difficultyID = 1, isPvpActivity = false }
    state.lfgActivities[858] = { fullName = "Wetlands", minLevelSuggestion = 18, maxLevelSuggestion = 34,
      maxNumPlayers = 0, difficultyID = 0 } -- a zone: left out
    open()
    assert.is_truthy(row("lfg1981"))
    assert.is_truthy(row("dm")) -- CF-63: it offers none of the known ones here, so the static list stays
    assert.is_falsy(text():find("\nWetlands\n", 1, true))
    select("lfg1981")
    local all = text()
    assert.is_truthy(all:find("\nlevel 26" .. DASH .. "33 \194\183 fits\n", 1, true)) -- no zone known
    assert.is_truthy(all:find("\nNo boss data for this dungeon yet.\n", 1, true))
    assert.is_truthy(all:find("\nneeds Questie\n", 1, true)) -- CF-62: no QuestieDB here
  end)

  it("remembers the selected dungeon", function()
    load(20)
    open()
    select("dm")
    ns.MainFrame.selectTab("friends")
    ns.MainFrame.selectTab("dungeons")
    assert.are.equal("dm", addon.db.global.settings.dungeonTree.selected)
    assert.is_truthy(text():find("\nlevel 17" .. DASH .. "26 \194\183 Westfall \194\183 fits\n", 1, true))
  end)

  it("lays a dungeon out at the window's 700 px minimum", function()
    load(20, sampleRuns())
    open()
    local width = 700 - 290 - 2
    local W = width - 6 - 40
    ns.DungeonsTab.detailArea():SetWidth(width)
    select("dm")
    for _, h in ipairs(ns.DungeonsTab.detailTexts()) do
      local t = h.text:GetText() or ""
      if t ~= "" then
        local x = h.points[1][2]
        assert.is_true(x >= 20 and x + (h.text.width or 0) <= 20 + W + 1, t .. " at " .. x)
      end
    end
    for _, r in ipairs(ns.DungeonsTab.lootRows()) do
      assert.are.equal(W, r.width)
      assert.is_true(30 + r.name.width <= W - 44, plain(r.name:GetText()))
    end
    for label, b in pairs(ns.DungeonsTab.buttons()) do
      if b.points and b.points[1] and b.points[1][1] == "TOPLEFT" and type(b.points[1][2]) == "number" then
        assert.is_true(b.points[1][2] + b.width <= 20 + W, label)
      end
    end
  end)

  it("says why there's no dungeon: outside the community, too low or past every range (CF-61)", function()
    load(20)
    local D = ns.Dungeons
    assert.are.equal("Seqari isn't in the community yet. Join it from the Friends tab with a friend's invite link.",
      D.emptyText("Seqari", 57, false))
    assert.are.equal("Seqari is not in a dungeon's level range yet. The first one, Ragefire Chasm, starts at "
      .. "level 13.", D.emptyText("Seqari", 9, true))
    assert.are.equal("No dungeon fits level 75.", D.emptyText("Seqari", 75, true))
  end)

  -- CF-85: the window's empty state. Passive (no community): the text only, and the list no parts drawn from empty
  -- data.
  it("shows only the explainer while passive", function()
    state = wowapi.install()
    state.clubs = {}
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon:OnEnable()
    assert.is_true(ns.CommunitySelection.passive())
    open()
    assert.is_truthy(text():find(ns.Format.PASSIVE_TEXT, 1, true))
    assert.is_nil(ns.DungeonsTab.buttons()["Ask now"])
    assert.is_falsy(text():find("Fits you", 1, true))
    assert.is_truthy(text():find("\nDungeons\n", 1, true)) -- the list's title stays
    ns.MainFrame.selectTab("runs")
    assert.is_truthy(table.concat(ns.RunsTab.texts(), "\n"):find(ns.Format.PASSIVE_TEXT, 1, true))
    assert.is_nil(ns.RunsTab.buttons()["Ask now\226\128\166"])
  end)

  describe("quests (QuestieDB)", function()
    local QUESTS = {
      [201] = { name = "Red Silk Bandanas", zoneOrSort = 1581, questLevel = 17, requiredLevel = 14, requiredRaces = 0,
                requiredClasses = 0 },
      [202] = { name = "Underground Assault", zoneOrSort = 1581, questLevel = 20, requiredLevel = 15,
                requiredRaces = 77, requiredClasses = 0 }, -- Alliance only
      [203] = { name = "Collecting Memories", zoneOrSort = 1581, questLevel = 18, requiredLevel = 13,
                requiredRaces = 0, requiredClasses = 0 },
      [204] = { name = "A Warrior's Task", zoneOrSort = 1581, questLevel = 20, requiredLevel = 15,
                requiredRaces = 0, requiredClasses = 1 }, -- class quest: left out
      [301] = { name = "Elsewhere", zoneOrSort = 40, questLevel = 10, requiredLevel = 5, requiredRaces = 0,
                requiredClasses = 0 },
    }

    local function installQuestieDB(contract)
      _G.LibQuestieDB = {
        RequireContract = function(v) return v <= (contract or 4), "contract" end,
        Enum = { factionRaceMasks = { Horde = 690, Alliance = 77 } },
      }
      _G.QuestDB = {
        GetAllIds = function() return { 201, 202, 203, 204, 301 } end,
        Get = function(id, key) return QUESTS[id] and QUESTS[id][key] end,
      }
    end

    after_each(function()
      _G.LibQuestieDB, _G.QuestDB = nil, nil
    end)

    it("shows have/total and the quests with checks in the detail", function()
      load(20)
      installQuestieDB()
      state.questLog = { { isHeader = true, title = "The Deadmines" },
                         { questID = 203, title = "Collecting Memories" } }
      wowapi.fireEvent(state, "QUEST_LOG_UPDATE")
      open()
      select("dm")
      local all = text()
      assert.is_truthy(all:find("\n1 of 2 in your log\n", 1, true))
      assert.is_truthy(all:find("\nCollecting Memories\n", 1, true))
      assert.is_truthy(all:find("!  Red Silk Bandanas\n", 1, true) and all:find("\nlevel 17\n", 1, true))
      local checks = 0
      for _, q in ipairs(ns.DungeonsTab.questRows()) do
        if q.check.shown then checks = checks + 1 end
      end
      assert.are.equal(1, checks) -- only the quest in your log
      assert.is_falsy(all:find("Underground Assault", 1, true)) -- Alliance
      assert.is_falsy(all:find("A Warrior's Task", 1, true))
      assert.is_falsy(all:find("needs Questie", 1, true))
    end)

    it("leaves out completed quests and says how many", function()
      load(20)
      installQuestieDB()
      _G.C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 201 end
      open()
      select("dm")
      local all = text()
      assert.is_truthy(all:find("\n0 of 1 in your log \194\183 1 done\n", 1, true))
      assert.is_truthy(all:find("\nRed Silk Bandanas\ndone\n", 1, true))
    end)

    it("ignores an incompatible QuestieDB and says how to see every quest", function()
      load(20)
      installQuestieDB(2)
      open()
      assert.is_truthy(text():find("\nneeds Questie\n", 1, true)) -- CF-62
    end)
  end)
end)
