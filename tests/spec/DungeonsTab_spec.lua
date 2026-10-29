local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Dungeons tab (CF-24)", function()
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

  local function whenText(at) return ns.PlannedRuns.whenText(at, NOW, os.date) end

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
    assert.is_falsy(all:find("Ranges are typical levels", 1, true)) -- CF-61: no designer notes
    assert.is_truthy(all:find("\nRUNS\nNo runs planned. Plan one on the website.\n", 1, true)) -- CF-46
    assert.is_true(row("dm").selected)
    -- Five slots: you in one of them, outlined gold; nobody tanks or heals.
    local slots = ns.DungeonsTab.slots()
    assert.are.equal(5, #slots)
    assert.is_truthy(all:find("\nDPS \194\183 you \194\183 online\n", 1, true))
    assert.is_truthy(all:find("\nnobody in range\n", 1, true))
    assert.is_truthy(all:find("\nopen\n", 1, true))
    assert.is_truthy(ns.DungeonsTab.buttons()["Plan a run"]) -- CF-46: no calendar event title; CF-47: the dialog
    assert.is_nil(ns.DungeonsTab.buttons()["Open calendar"])
    assert.is_truthy(ns.DungeonsTab.buttons()["Ask now"]) -- CF-47: opens the dialog
    -- CF-61: what Ask now does is its tooltip, not a note next to it or in the footer.
    assert.is_truthy(ns.DungeonsTab.buttons()["Ask now"].tooltip:find("Whispers online friends who fit", 1, true))
    assert.is_falsy(all:find("Whispers online friends", 1, true))
    assert.are.equal("", ns.MainFrame.window().footerRightText.text)
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

  it("lists runs from the runs file on top, with who organises and the answers, and counts them (CF-46)", function()
    load(20, sampleRuns())
    open()
    assert.are.same({ "run:r1", "run:r2", "dm", "wc" }, values())
    assert.are.equal(2, ns.MainFrame.tabs().buttons.dungeons.badgeCount)
    local r1, r2 = row("run:r1"), row("run:r2")
    assert.are.equal("The Deadmines", r1.name:GetText())
    assert.are.equal(whenText(NOW + 9600), r1.right:GetText())
    assert.are.same({ ns.Theme.color("soon") }, r1.right.textColor) -- within 12 hours
    assert.is_truthy(r1.meta:GetText():find("^you organise    2 in \194\183 1 maybe$"))
    assert.is_truthy(r2.meta:GetText():find("^Ada    ", 1, false))
    -- The Wailing Caverns run has free damage slots: Ves fits.
    assert.is_truthy(r2.meta:GetText():find("Ves Doombringer fits damage", 1, true))
    local all = text()
    assert.is_truthy(all:find("\nRuns updated at " .. os.date("%H:%M", NOW - 600) .. " \194\183 /reload for newer\n",
      1, true) or all:find("\nRuns updated at " .. whenText(NOW - 600) .. " \194\183 /reload for newer\n", 1, true))
    assert.is_truthy(row("dm").meta:GetText():find("1 run", 1, true)) -- the dungeon shows its run
  end)

  it("shows each sign-up's fit and lists reserves without a slot (CF-49)", function()
    local data = sampleRuns()
    local answers = data.runs[1].answers
    answers[#answers + 1] = { name = "Cy Example", answer = "in", role = "dps", fit = "carry \194\183 +12",
                              source = "site" }
    answers[#answers + 1] = { name = "Bo Stone", answer = "maybe", role = "heal", reserve = true, source = "site" }
    load(20, data)
    open()
    local all = text()
    assert.is_truthy(all:find("\nCy Example\nDPS \194\183 Cy Example\ncarry \194\183 +12\n", 1, true))
    assert.is_truthy(all:find("\nReserve: Bo Stone (Healer)\n", 1, true))
    assert.is_falsy(all:find("\nBo Stone\n", 1, true)) -- no slot
  end)

  it("shows a run: slots from the answers, the note, the link to copy (CF-46)", function()
    load(20, sampleRuns())
    open()
    local all = text()
    assert.is_truthy(all:find("\nThe Deadmines\n", 1, true))
    assert.is_truthy(all:find(whenText(NOW + 9600) .. " \194\183 in 2 h 40 min", 1, true))
    assert.is_truthy(all:find("17" .. DASH .. "26 \194\183 planned on the website", 1, true))
    assert.is_truthy(all:find("\226\128\156Bring water\226\128\157", 1, true))
    -- Tank: nobody plays one in range; healer Garraka; Ves and the maybe from Discord in damage slots.
    assert.is_truthy(all:find("\nTank\nnobody in range\n", 1, true))
    assert.is_truthy(all:find("\nHealer \194\183 Sjaakovich\nonline\n", 1, true))
    assert.is_truthy(all:find("\nDPS \194\183 you\norganiser\n", 1, true))
    assert.is_truthy(all:find("\nAda Lovewell\nDPS \194\183 Ada\nmaybe\n", 1, true))
    assert.are.equal(0.75, ns.DungeonsTab.slots()[4].alpha)
    assert.is_truthy(all:find("You'll get a reminder at " .. os.date("%H:%M", NOW + 9600 - 1800) .. ".", 1, true))
    local invite = ns.DungeonsTab.buttons()["Invite all \194\183 from " .. os.date("%H:%M", NOW + 9600)]
    assert.is_false(invite.enabled) -- CF-48 builds it
    assert.are.equal("https://example.com/runs/r1", ns.DungeonsTab.linkBox():GetText())
    select("run:r2")
    all = text()
    assert.is_truthy(all:find("planned on Discord", 1, true))
    assert.is_truthy(all:find("\nanswered on Discord\n", 1, true))
    assert.is_truthy(all:find("Organised by Ada \194\183 2 in", 1, true))
    assert.is_nil(ns.DungeonsTab.buttons()["Invite all \194\183 from " .. os.date("%H:%M", NOW + 26 * 3600)])
  end)

  it("keeps the link to copy when typed over", function()
    load(20, sampleRuns())
    open()
    local box = ns.DungeonsTab.linkBox()
    box.text = "oops" -- typed: the game changes the text without SetText
    box:RunScript("OnTextChanged", true)
    assert.are.equal("https://example.com/runs/r1", box:GetText())
  end)

  it("shows your answer and the stored runs after a reload without a newer file (CF-46)", function()
    local runs = sampleRuns(NOW - 60)
    runs.runs[2].answers[3] = { guid = VES, answer = "maybe" }
    load(20, sampleRuns(NOW - 3600), runs) -- stored is newer than the file
    open()
    assert.is_truthy(row("run:r2").meta:GetText():find("you: maybe", 1, true))
    assert.are.equal(NOW - 60, addon.db.global.plannedRuns.updatedAt)
  end)

  it("hides cancelled runs and runs that started long ago (CF-46)", function()
    local runs = sampleRuns()
    runs.runs[1].state = "cancelled"
    runs.runs[2].startsAt = NOW - 3 * 3600
    load(20, runs)
    open()
    assert.are.same({ "dm", "wc" }, values())
    assert.are.equal(0, ns.MainFrame.tabs().buttons.dungeons.badgeCount or 0)
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
    assert.is_truthy(text():find("Ves Doombringer is not in a dungeon's level range yet. The first one, Ragefire "
      .. "Chasm, starts at level 13.", 1, true))
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
end)
