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
    -- CF-62 (board AG05): "Dungeons" with Ask now…, the empty run list, "In range for …" with its ⓘ.
    assert.is_truthy(all:find("\nDungeons\n", 1, true))
    assert.is_truthy(all:find("\nNo runs planned\nPlan one on the website, or ask who is up for something right "
      .. "now.\n", 1, true))
    assert.is_truthy(all:find("\nIn range for\n", 1, true)) -- CF-63c: and a dropdown of your characters
    assert.is_truthy(ns.DungeonsTab.buttons()["Ves Doombringer (20) \226\150\190"])
    assert.are.equal("17" .. DASH .. "26 \194\183 2 fit", row("dm").right:GetText())
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Ranges are typical levels", 1, true))
    assert.are.equal("17" .. DASH .. "24 \194\183 2 fit", row("wc").right:GetText()) -- one line per dungeon
    assert.is_true(row("dm").selected)
    -- The detail: title, the suggested group as rows, Online now, Quests, Go.
    assert.is_truthy(all:find("\nThe Deadmines\n", 1, true))
    assert.is_truthy(all:find("\nlevel 17" .. DASH .. "26 \194\183 Westfall\n", 1, true))
    assert.is_truthy(all:find("\nSuggested group\n", 1, true))
    assert.are.equal(5, #ns.DungeonsTab.groupRows())
    assert.is_truthy(all:find("\nVes Doombringer\n20 \194\183 you\nonline\n", 1, true))
    assert.is_truthy(all:find("\nTank \194\183 nobody fits\n", 1, true))
    assert.is_truthy(all:find("\nDamage \194\183 open\n", 1, true))
    assert.is_truthy(all:find("\nOnline now, fits\n", 1, true))
    assert.is_truthy(all:find("\nQuests\n", 1, true))
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Friends\226\128\153 and your characters whose "
      .. "level fits, online or not.", 1, true)) -- CF-63c: the ⓘ on Suggested group
    local askFor = ns.DungeonsTab.buttons()["Ask now"] -- CF-63c board CF63List
    assert.is_truthy(askFor.tooltip:find("Whispers online friends who fit", 1, true)) -- CF-61: its tooltip
    local plan = ns.DungeonsTab.buttons()["Plan a run\226\128\166"]
    assert.are.equal("A planned run reaches the website and Discord with your next upload.", plan.tooltip)
    assert.is_truthy(ns.DungeonsTab.buttons()["Ask now\226\128\166"])
    assert.is_falsy(all:find("Whispers online friends", 1, true))
    assert.is_falsy(all:find("reaches the website and Discord", 1, true)) -- in the tooltip only
    assert.are.equal("", ns.MainFrame.window().footerRightText.text)
  end)

  it("lists your characters in the In range dropdown, and follows the one picked (CF-63c)", function()
    load(20)
    addon.db.global.self.chars["Player-1-ALT"] = { guid = "Player-1-ALT", name = "Alt Example", level = 22,
                                                   classFile = "ROGUE" }
    state.clubMembers[CLUB][3] = { memberId = 3, guid = "Player-1-ALT", name = "Alt Example", classID = 4,
                                   level = 22, presence = 3, clubType = 1 }
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    open()
    ns.DungeonsTab.buttons()["Ves Doombringer (20) \226\150\190"]:RunScript("OnClick")
    local menu = state.menus[#state.menus]
    assert.are.same({ "Alt Example (22)", "Ves Doombringer (20)" }, { menu.buttons[1].text, menu.buttons[2].text })
    menu.buttons[1].fn()
    assert.is_truthy(ns.DungeonsTab.buttons()["Alt Example (22) \226\150\190"])
  end)

  it("lists runs from the runs file on top, with who organises and the answers, and counts them (CF-46)", function()
    load(20, sampleRuns())
    open()
    assert.are.same({ "run:r1", "run:r2", "dm", "wc" }, values())
    assert.are.equal(2, ns.MainFrame.tabs().buttons.dungeons.badgeCount)
    local r1, r2 = row("run:r1"), row("run:r2")
    -- CF-62: the short name and the time; role pips, the counts, who organises.
    assert.are.equal("The Deadmines", r1.name:GetText())
    assert.are.equal(os.date("%H:%M", NOW + 9600), r1.right:GetText())
    assert.are.equal("2 in \194\183 1 maybe", r1.meta:GetText())
    assert.are.equal("you organise", r1.who:GetText())
    assert.are.equal("Ada", r2.who:GetText())
    assert.are.equal(5, #r1.pips)
    local all = text()
    assert.is_truthy(all:find("\nTonight\n", 1, true) or all:find("\nToday\n", 1, true))
    assert.is_truthy(all:find("\nRuns from ", 1, true)) -- CF-63: "Runs from Wed 22:30" with an ⓘ
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Runs from the website. Type /reload after an "
      .. "upload for newer.", 1, true))
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
    assert.is_truthy(all:find("\nCy Example\nCy Example\ncarry \194\183 +12\n", 1, true)) -- CF-62: a group row
    assert.is_truthy(all:find("\nReserve: Bo Stone (Healer)\n", 1, true))
    assert.is_falsy(all:find("\nBo Stone\n", 1, true)) -- no slot
  end)

  it("shows a run: slots from the answers, the note, the link to copy (CF-46)", function()
    load(20, sampleRuns())
    open()
    local all = text()
    -- CF-62: the dungeon as the title, its range, the subtitle with the note.
    assert.is_truthy(all:find("\nThe Deadmines\n", 1, true))
    assert.is_truthy(all:find("\nlevel 17" .. DASH .. "26 \194\183 Westfall\n", 1, true))
    assert.is_truthy(all:find(whenText(NOW + 9600) .. " \194\183 in 2 h 40 m \194\183 planned on the website "
      .. "\194\183 note: \226\128\156Bring water\226\128\157", 1, true))
    -- Five group rows: nobody tanks; the healer Garraka; Ves organises; Ada maybe; an open damage slot.
    assert.are.equal(5, #ns.DungeonsTab.groupRows())
    assert.is_truthy(all:find("\nTank \194\183 nobody fits\n", 1, true))
    assert.is_truthy(all:find("\nGarraka Doombringer\n20 \194\183 Sjaakovich\n", 1, true))
    assert.is_truthy(all:find("\nVes Doombringer\n20 \194\183 you\norganiser\n", 1, true))
    assert.is_truthy(all:find("\nAda Lovewell\nAda\nmaybe\n", 1, true))
    assert.is_truthy(all:find("\nDamage \194\183 open\n", 1, true))
    assert.is_truthy(all:find("\n2 in \194\183 1 maybe \194\183 2 open\n", 1, true))
    -- The organiser before the start: Invite all opens 15 minutes early, with its tooltip; the reminder.
    assert.is_truthy(all:find("\nAt " .. os.date("%H:%M", NOW + 9600) .. "\n", 1, true))
    local invite = ns.DungeonsTab.buttons()["Invite all \194\183 opens " .. os.date("%H:%M", NOW + 9600 - 900)]
    assert.is_false(invite.enabled)
    assert.are.equal("Invite all invites everyone who is in and online.", invite.tooltip)
    assert.is_truthy(all:find("\nReminder at " .. os.date("%H:%M", NOW + 9600 - 1800) .. "\n", 1, true))
    -- Online now, fits: nobody else online in range here; its explanation in the ⓘ.
    assert.is_truthy(all:find("\nNobody else online fits\n", 1, true))
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Online members whose current character fits 17"
      .. DASH .. "26.", 1, true))
    assert.is_truthy(all:find("\nEdit or cancel\n", 1, true))
    assert.are.equal("https://example.com/runs/r1", ns.DungeonsTab.linkBox():GetText())
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Copy with Ctrl+C. Edit or cancel happens on the "
      .. "website.", 1, true)) -- CF-63: in the ⓘ, not a line
    -- Someone else's run: your answer, Online now with Whisper, "On the website".
    select("run:r2")
    all = text()
    assert.is_truthy(all:find("planned on Discord", 1, true))
    assert.is_truthy(all:find("\nDiscord\n", 1, true))
    assert.is_truthy(all:find("\nYour answer\n", 1, true))
    assert.is_truthy(ns.DungeonsTab.buttons()["I\226\128\153m in"] and ns.DungeonsTab.buttons()["Maybe"]
      and ns.DungeonsTab.buttons()["Can\226\128\153t"])
    assert.is_truthy(all:find("\nGarraka Doombringer\n20 \194\183 Sjaakovich\n", 1, true)) -- online, fits
    assert.is_truthy(ns.DungeonsTab.buttons()["Whisper:1"])
    assert.is_truthy(all:find("\nOn the website\n", 1, true))
  end)

  -- CF-63b (board CF63Group): a member's tooltip and right-click menu; an open slot's Ask and menu.
  it("shows a member's tooltip and menu, and asks for an open slot with the run's note", function()
    load(20, sampleRuns())
    open()
    local garraka, slot
    for _, g in ipairs(ns.DungeonsTab.groupRows()) do
      if (g.name:GetText() or ""):find("Garraka", 1, true) then garraka = g end
      if (g.name:GetText() or ""):find("Damage \194\183 open", 1, true) then slot = g end
    end
    assert.are.equal("Garraka Doombringer", garraka.tipLines[1])
    assert.are.equal("Level 20 \194\183 fits \194\183 Healer", garraka.tipLines[2])
    assert.are.equal("Answered in game", garraka.tipLines[3])
    garraka:RunScript("OnMouseUp", "RightButton")
    local menu = state.menus[#state.menus]
    assert.are.equal("Garraka Doombringer", menu.title)
    assert.are.same({ "Whisper", "Invite \194\183 from " .. os.date("%H:%M", NOW + 9600 - 900), "Show in Friends" },
      { menu.buttons[1].text, menu.buttons[2].text, menu.buttons[3].text })
    assert.is_false(menu.buttons[2].enabled) -- invites open 15 minutes before the start
    assert.is_true(menu.buttons[3].enabled)
    menu.buttons[3].fn()
    -- Show in Friends: the Friends tab on Garraka (Sjaak's card, his character).
    assert.are.equal(ns.Format.path("Sjaakovich#2232", GARRAKA), addon.db.global.settings.tree.selected)
    ns.MainFrame.selectTab("dungeons")
    -- Your own row has no menu.
    for _, g in ipairs(ns.DungeonsTab.groupRows()) do
      if (g.info:GetText() or ""):find("you", 1, true) then assert.is_nil(g.menu) end
    end
    -- The open slot: Ask now for this run fills the Ask dialog's note; a click opens Whisper / Ask / Invite.
    assert.is_true(slot.ask.shown)
    slot.ask:RunScript("OnClick")
    assert.are.equal("For The Deadmines " .. os.date("%H:%M", NOW + 9600) .. " \194\183 need Damage",
      ns.RunDialogs.widgets().note:GetText())
    slot:RunScript("OnMouseUp", "LeftButton")
    menu = state.menus[#state.menus]
    assert.are.equal("Damage \194\183 open", menu.title)
    assert.are.same({ "Whisper", "Ask now for this run" }, { menu.buttons[1].text, menu.buttons[2].text })
    assert.is_false(menu.buttons[1].enabled) -- nobody else online fits
  end)

  -- CF-63c (board CF63List): the filter chips, Show all dungeons, a dungeon out of range, planning inline.
  it("filters the runs by chip, back to All when the window closes", function()
    load(20, sampleRuns())
    open()
    local function runIds()
      local out = {}
      for _, value in ipairs(values()) do
        if value:find("^run:") then out[#out + 1] = value end
      end
      return out
    end
    assert.are.same({ "run:r1", "run:r2" }, runIds())
    ns.DungeonsTab.buttons()["chip:mine"]:RunScript("OnClick")
    assert.are.same({ "run:r1" }, runIds()) -- Ves organises r1 only
    assert.is_true(ns.DungeonsTab.buttons()["chip:mine"].on)
    ns.MainFrame.toggle()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
    assert.are.same({ "run:r1", "run:r2" }, runIds())
    assert.is_true(ns.DungeonsTab.buttons()["chip:all"].on)
  end)

  it("shows all dungeons, says how your characters fit one out of range, and plans it inline for 20:00", function()
    load(20, sampleRuns())
    open()
    assert.is_nil(row("smgy"))
    ns.DungeonsTab.buttons()["Show all dungeons"]:RunScript("OnClick")
    assert.is_truthy(text():find("\nOther dungeons\n", 1, true))
    select("smgy")
    local all = text()
    assert.is_truthy(all:find("\nScarlet Monastery Graveyard\n", 1, true))
    assert.is_truthy(all:find("\nVes Doombringer 20: too low\n", 1, true))
    ns.DungeonsTab.buttons()["Plan a run\226\128\166"]:RunScript("OnClick")
    local buttons = ns.DungeonsTab.buttons()
    assert.is_truthy(buttons["Other time\226\128\166"])
    local chips = ns.PlannedRuns.planChips(NOW, os.date, ns.Panels.localTime)
    assert.are.equal(3, #chips)
    assert.is_truthy(buttons[chips[1].label].on) -- the first evening is picked
    assert.is_truthy(text():find("\nPlan a run\n", 1, true))
    buttons[chips[2].label]:RunScript("OnClick")
    ns.DungeonsTab.buttons().Plan:RunScript("OnClick")
    local plan = addon.db.global.pending[1]
    assert.are.same({ "plan", "smgy", VES, chips[2].startsAt }, { plan.kind, plan.dungeon, plan.guid, plan.startsAt })
    assert.are.equal(20, os.date("*t", plan.startsAt).hour)
  end)

  it("says no dungeon fits yet, and the first one, below its level (CF-63c)", function()
    local runs = sampleRuns()
    runs.runs = { runs.runs[2] } -- a run Ves isn't in
    load(8, runs)
    open()
    local all = text()
    assert.is_truthy(all:find("\nNo dungeon fits yet\n", 1, true))
    local first = ns.Dungeons.first()
    assert.is_truthy(all:find(string.format("\nFirst one: %s at level %d\n", first.name, first.min), 1, true))
    assert.is_truthy(ns.DungeonsTab.buttons()["Pick another character"])
    ns.DungeonsTab.buttons()["Show all dungeons"]:RunScript("OnClick")
    assert.is_truthy(text():find("\nOther dungeons\n", 1, true))
  end)

  it("opens Invite all 15 minutes before the start, and Invite instead of Whisper (CF-62)", function()
    load(20, sampleRuns())
    state.serverTime = NOW + 9600 - 600 -- 10 minutes before The Deadmines
    open()
    local all = text()
    assert.is_truthy(all:find("\n" .. whenText(NOW + 9600) .. " \194\183 in 10 min", 1, true)) -- CF-63: not yet
    state.serverTime = NOW + 9600 + 60 -- the start: "Starting now" (for 30 minutes)
    ns.MainFrame.toggle()
    ns.MainFrame.toggle()
    assert.is_truthy(text():find("\nStarting now \194\183 " .. os.date("%H:%M", NOW + 9600), 1, true))
    state.serverTime = NOW + 9600 - 600
    assert.is_truthy(all:find("\nStart\n", 1, true))
    local invite
    for label, b in pairs(ns.DungeonsTab.buttons()) do
      if label:find("^Invite all \194\183 %d+ online$") then invite = b end
    end
    assert.is_not_nil(invite)
    assert.are.equal("Invite all invites everyone who is in and online.", invite.tooltip)
    select("run:r2") -- tomorrow: still Whisper there
    assert.is_truthy(ns.DungeonsTab.buttons()["Whisper:1"])
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
    select("run:r2")
    assert.are.equal("primary", ns.DungeonsTab.buttons()["Maybe"].kind) -- CF-62: your answer, highlighted
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
    assert.is_truthy(text():find("\nlevel 26" .. DASH .. "33\n", 1, true)) -- no zone known
    assert.is_truthy(text():find("\nneeds Questie\n", 1, true)) -- CF-62: no QuestieDB here
  end)

  -- CF-63: Nico's retail test. The Group Finder offers only Retail dungeons, a website run is for "smgy".
  it("keeps the static dungeons when the Group Finder offers none of them, and names a website run (CF-63)",
    function()
      load(30, { updatedAt = NOW - 600, runs = {
        { id = "r9", dungeon = "smgy", startsAt = NOW + 3600, state = "open", source = "site",
          url = "https://example.com/runs/r9",
          organiser = { battleTag = "Vestras#1000", guid = VES, name = "Ves Doombringer" },
          answers = {
            { guid = VES, name = "Ves Doombringer", answer = "in", role = "dps", source = "site" },
            { battleTag = "Ada#1001", name = "Bartholomew Thunderbrewington", answer = "in",
              role = "heal", source = "discord" },
            { battleTag = "Bo#2002", name = "Wilhelmina Featherstonehaugh", answer = "maybe", role = "tank",
              source = "discord" },
          } } } })
      state.lfgActivities[9001] = { fullName = "A Retail Dungeon", shortName = "A Retail Dungeon",
        minLevelSuggestion = 70, maxLevelSuggestion = 80, maxNumPlayers = 5, difficultyID = 1, isPvpActivity = false }
      open()
      -- "In range for" shows, also with nobody else online.
      assert.is_truthy(ns.DungeonsTab.buttons()["Ves Doombringer (30) \226\150\190"])
      assert.is_truthy(row("smgy"))
      assert.is_nil(row("lfg9001"))
      -- The run: the dungeon's name and range, never the raw id.
      assert.are.equal("SM: Graveyard", row("run:r9").name:GetText())
      assert.are.equal("Scarlet Monastery: Graveyard", row("run:r9").fullName) -- on hover
      select("run:r9")
      local all = text()
      assert.is_truthy(all:find("\nScarlet Monastery: Graveyard\n", 1, true))
      assert.is_truthy(all:find("\nlevel 26" .. DASH .. "36", 1, true))
      assert.is_falsy(all:find("smgy", 1, true))
      -- Long names never run into the status: name, info and status fit the row side by side.
      local lastY = 0
      for _, g in ipairs(ns.DungeonsTab.groupRows()) do
        local onlineW = (g.online:GetText() or "") ~= "" and (g.online:GetStringWidth() + 8) or 0
        local used = 66 + (g.name.width or 0) + 8 + (g.info.width or 0) + onlineW + 12 + (g.status.width or 0) + 10
        assert.is_true((g.status.width or 0) >= 64) -- the status column
        assert.is_true(used <= g.width, tostring(g.name:GetText()))
        if (g.name:GetText() or ""):find("Bartholomew", 1, true) then
          assert.is_true(g.name.width >= g.name:GetStringWidth() - 1) -- the full name at the normal width
          assert.are.equal("Discord", g.status:GetText())
        end
        lastY = math.max(lastY, -g.points[1][3])
      end
      -- CF-63 board: Edit or cancel / On the website below the group and your answer, in a 236 px column on the right.
      local box = ns.DungeonsTab.linkBox()
      assert.is_true(box.shown)
      assert.are.equal(20 + 520 - 236, box.points[1][2]) -- the 520 px detail of the specs
      assert.is_true(-box.points[1][3] > lastY)
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
      local all = text()
      assert.is_truthy(all:find("\n1 of 2 in your log\n", 1, true))
      assert.is_truthy(all:find("\nCollecting Memories\n", 1, true))
      -- CF-62: "!" for a quest not picked up yet
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
      local all = text()
      -- CF-62: a done quest stays listed, grey, with "done"; the heading counts it.
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

  it("remembers the selected dungeon", function()
    load(20)
    open()
    select("wc")
    ns.MainFrame.selectTab("friends")
    ns.MainFrame.selectTab("dungeons")
    assert.are.equal("wc", addon.db.global.settings.dungeonTree.selected)
    assert.is_truthy(text():find("\nlevel 17" .. DASH .. "24 \194\183 The Barrens\n", 1, true))
  end)

  it("jumps from a dungeon to its planned run, and offers the website link when nothing fits (CF-62)", function()
    load(20, sampleRuns())
    open()
    select("dm")
    local jump
    for label, b in pairs(ns.DungeonsTab.buttons()) do
      if label:find("^1 run planned") then jump = b end
    end
    assert.is_not_nil(jump)
    jump:RunScript("OnClick")
    assert.are.equal("run:r1", addon.db.global.settings.dungeonTree.selected)
    wowapi.uninstall()
    local empty = sampleRuns()
    empty.runs, empty.site = {}, "https://wow.example.org"
    load(11, empty)
    open()
    ns.DungeonsTab.buttons()["Copy website link"]:RunScript("OnClick")
    assert.are.equal("https://wow.example.org", ns.DungeonsTab.linkBox():GetText())
    assert.is_true(ns.DungeonsTab.linkBox().shown)
  end)

  it("explains when the character you are on is in no dungeon's level range", function()
    load(11)
    open()
    -- CF-62 (board D): the empty state with the reason.
    assert.is_truthy(text():find("\nNothing planned yet\n", 1, true))
    assert.is_truthy(text():find("Ves Doombringer is not in a dungeon's level range yet. The first one, Ragefire "
      .. "Chasm, starts at level 13.", 1, true))
    assert.is_false(ns.DungeonsTab.buttons()["Ask now\226\128\166"].enabled) -- no dungeon to ask for
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
