local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Dungeons tab (CF-24)", function()
  local state, ns, addon
  local CLUB = "23125681"

  local function load(level)
    state = wowapi.install()
    state.player.level = level or 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = level or 20 end
    for _, f in ipairs(state.friends) do
      for _, g in ipairs(f.gameAccounts) do g.characterLevel = level or 20 end
    end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
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
  end)

  it("lists the dungeons in range of the character you are on and suggests a group for the first", function()
    load(20)
    open()
    assert.are.same({ "dm", "wc" }, values()) -- both 2 people; then by level, then name
    local all = text()
    assert.is_truthy(all:find("\nIN RANGE FOR VES DOOMBRINGER (20)\n", 1, true))
    assert.is_truthy(all:find("\nThe Deadmines\n", 1, true))
    assert.is_truthy(all:find("\nlevels 17" .. DASH .. "26 \194\183 Westfall\n", 1, true)) -- CF-42: the zone
    assert.is_truthy(all:find("\n17" .. DASH .. "24\n", 1, true)) -- the range in the list
    assert.is_truthy(all:find("\n1 friend\n", 1, true))
    assert.is_truthy(all:find("\nSuggested group\n", 1, true))
    assert.is_falsy(all:find("Also in range", 1, true)) -- nobody else
    assert.is_truthy(all:find("\nRanges are typical levels; the list follows the character you're on.\n", 1, true))
    assert.is_true(row("dm").selected)
    -- Five slots: you in one of them, outlined gold; nobody tanks or heals.
    local slots = ns.DungeonsTab.slots()
    assert.are.equal(5, #slots)
    assert.is_truthy(all:find("\nDPS \194\183 you \194\183 online\n", 1, true))
    assert.is_truthy(all:find("\nnobody in range\n", 1, true))
    assert.is_truthy(all:find("\nopen\n", 1, true))
    assert.are.equal("The Deadmines", ns.DungeonsTab.titleBox():GetText()) -- the title to copy
    assert.is_truthy(ns.DungeonsTab.buttons()["Ask who's up for it"])
    assert.is_truthy(all:find("\nSends a chat line to friends with the addon\n", 1, true))
    -- The footer: sync state and when group asks wait.
    assert.are.equal("Group asks wait until combat ends", ns.MainFrame.window().footerRightText.text)
  end)

  it("names your other characters in range as alternatives", function()
    load(20)
    addon.db.global.self.chars["Player-1-ALT"] = { guid = "Player-1-ALT", name = "Alt Example", level = 22,
                                                   classFile = "ROGUE" }
    state.clubMembers[CLUB][3] = { memberId = 3, guid = "Player-1-ALT", name = "Alt Example", classID = 4,
                                   level = 22, presence = 3, clubType = 1 }
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    open()
    assert.is_truthy(text():find("\nAlternatives for you: Alt Example 22\n", 1, true))
    assert.is_falsy(text():find("Also in range", 1, true))
  end)

  it("puts runs planned in the next 3 days on top, with sign-ups, and counts them on the tab", function()
    load(20)
    open()
    state.calendarEvents[0] = {
      [20] = { { title = "Deadmines run", calendarType = "COMMUNITY_EVENT", inviteStatus = 6,
                 startTime = { year = 2026, month = 10, monthDay = 20, weekday = 3, hour = 20, minute = 0 } } },
      [24] = { { title = "Wailing Caverns", calendarType = "COMMUNITY_EVENT",
                 startTime = { year = 2026, month = 10, monthDay = 24, weekday = 7, hour = 19, minute = 0 } } },
    }
    state.calendarInvites["0:20:1"] = { 6, 6, 3, 8, 2 }
    wowapi.fireEvent(state, "CALENDAR_UPDATE_EVENT_LIST")
    assert.are.same({ { 0, 20, 1 } }, state.calendarOpenedEvents) -- only the planned run is opened
    wowapi.fireEvent(state, "CALENDAR_OPEN_EVENT", "COMMUNITY_EVENT")
    settle()
    assert.are.same({ "planned:1", "dm", "wc" }, values())
    assert.are.equal("Tue 20:00", row("planned:1").right:GetText())
    assert.are.equal("3 going \194\183 you", row("planned:1").meta:GetText())
    assert.are.equal(1, ns.MainFrame.tabs().buttons.dungeons.badgeCount) -- CF-39: the badge on the tab
    select("planned:1")
    assert.is_truthy(text():find("Tue 20 Oct, 20:00 \194\183 Deadmines run \194\183 3 signed up \194\183 +1 tentative"
      .. " \194\183 you signed up", 1, true))
    select("wc") -- 6 days ahead: in the detail, not planned in the list
    assert.is_truthy(text():find("Sat 24 Oct, 19:00 \194\183 Wailing Caverns", 1, true))
  end)

  it("lists a planned run for a dungeon out of range, greyed", function()
    load(20)
    open()
    state.calendarEvents[0] = { [19] = { { title = "Stratholme", calendarType = "COMMUNITY_EVENT",
      startTime = { year = 2026, month = 10, monthDay = 19, weekday = 2, hour = 20, minute = 0 } } } }
    wowapi.fireEvent(state, "CALENDAR_UPDATE_EVENT_LIST")
    settle() -- no CALENDAR_OPEN_EVENT: the sign-ups time out
    local planned = row("planned:1")
    assert.are.equal("Stratholme", planned.name:GetText())
    assert.are.same({ ns.Theme.color("muted") }, planned.name.textColor)
    assert.are.equal("Mon 20:00", planned.right:GetText())
    select("planned:1")
    assert.is_truthy(text():find("\nVes Doombringer is not in range.\n", 1, true))
    assert.is_nil(ns.DungeonsTab.buttons()["Ask who's up for it"]) -- only for dungeons in range
  end)

  it("lists the Group Finder's dungeons, also Forever's new ones (V46)", function()
    load(28)
    state.lfgActivities[1981] = { fullName = "Excavation Site: Wetlands", shortName = "Excavation Site: Wetlands",
      minLevelSuggestion = 26, maxLevelSuggestion = 33, maxNumPlayers = 5, difficultyID = 1, isPvpActivity = false }
    state.lfgActivities[858] = { fullName = "Wetlands", minLevelSuggestion = 18, maxLevelSuggestion = 34,
      maxNumPlayers = 0, difficultyID = 0 } -- a zone: left out
    open()
    local list = values()
    assert.is_truthy(row("lfg1981"))
    for _, value in ipairs(list) do assert.are_not.equal("dm", value) end -- only what the Group Finder offers
    assert.is_falsy(text():find("\nWetlands\n", 1, true))
    select("lfg1981")
    assert.is_truthy(text():find("\nlevels 26" .. DASH .. "33\n", 1, true)) -- no zone known
    assert.is_truthy(text():find("No quests known for this dungeon yet.", 1, true))
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

    it("shows have/total in the list and the quests with checks in the detail", function()
      load(20)
      installQuestieDB()
      state.questLog = { { isHeader = true, title = "The Deadmines" },
                         { questID = 203, title = "Collecting Memories" } }
      wowapi.fireEvent(state, "QUEST_LOG_UPDATE")
      open()
      assert.is_truthy(row("dm").meta:GetText():find("1 / 2 quests", 1, true))
      local all = text()
      assert.is_truthy(all:find("\n1 / 2 in your log\n", 1, true))
      assert.is_truthy(all:find("\nCollecting Memories\n", 1, true))
      assert.is_truthy(all:find("\nRed Silk Bandanas\n", 1, true) and all:find("\nlevel 17\n", 1, true))
      local checks = 0
      for _, q in ipairs(ns.DungeonsTab.questRows()) do
        if q.check.shown then checks = checks + 1 end
      end
      assert.are.equal(1, checks) -- only the quest in your log
      assert.is_falsy(all:find("Underground Assault", 1, true)) -- Alliance
      assert.is_falsy(all:find("A Warrior's Task", 1, true))
      assert.is_falsy(all:find("Install QuestieDB", 1, true))
    end)

    it("leaves out completed quests and says how many", function()
      load(20)
      installQuestieDB()
      _G.C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 201 end
      open()
      local all = text()
      assert.is_truthy(all:find("\n0 / 1 in your log\n", 1, true))
      assert.is_truthy(all:find("1 quest already done on this character.", 1, true))
    end)

    it("ignores an incompatible QuestieDB and says how to see every quest", function()
      load(20)
      installQuestieDB(2)
      open()
      assert.is_truthy(text():find("Install QuestieDB (it comes with Questie)", 1, true))
    end)
  end)

  it("opens Blizzard's calendar, or says how when it can't", function()
    load(20)
    open()
    ns.DungeonsTab.buttons()["Open calendar"]:RunScript("OnClick")
    assert.is_true(state.calendarToggled)
    _G.ToggleCalendar = nil
    state.printed = {}
    ns.DungeonsTab.buttons()["Open calendar"]:RunScript("OnClick")
    assert.is_truthy(state.printed[1]:find("date button next to the minimap", 1, true))
  end)

  it("keeps the title to copy when typed over", function()
    load(20)
    open()
    local box = ns.DungeonsTab.titleBox()
    box.text = "oops" -- typed: the game changes the text without SetText
    box:RunScript("OnTextChanged", true)
    assert.are.equal("The Deadmines", box:GetText())
  end)

  it("remembers the selected dungeon", function()
    load(20)
    open()
    select("wc")
    ns.MainFrame.selectTab("friends")
    ns.MainFrame.selectTab("dungeons")
    assert.are.equal("wc", addon.db.global.settings.dungeonTree.selected)
    assert.is_truthy(text():find("\nlevels 17" .. DASH .. "24 \194\183 The Barrens\n", 1, true))
  end)

  it("explains when the character you are on is in no dungeon's level range", function()
    load(11)
    open()
    assert.is_truthy(text():find("Ves Doombringer is not in a dungeon's level range yet", 1, true))
  end)
end)
