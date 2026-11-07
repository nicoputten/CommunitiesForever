local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Runs tab (CF-106; runs since CF-46)", function()
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
    for i, t in ipairs(ns.RunsTab.texts()) do
      list[i] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  local function values()
    local list = {}
    for i, r in ipairs(ns.RunsTab.rows()) do list[i] = r.value end
    return list
  end

  local function row(value)
    for _, r in ipairs(ns.RunsTab.rows()) do
      if r.value == value then return r.frame end
    end
  end

  local function select(value) row(value):RunScript("OnClick") end

  local function open()
    settle()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("runs")
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

  it("lists the runs by day with your status on each row, and badges the ones waiting for you (CF-106)", function()
    load(20, sampleRuns())
    open()
    assert.are.same({ "run:r1", "run:r2" }, values()) -- CF-106: only runs; the dungeons are in their own tab
    -- The badge: r2 isn't answered and Wailing Caverns fits; r1 you answered.
    assert.are.equal(1, ns.MainFrame.tabs().buttons.runs.badgeCount)
    assert.is_nil(ns.MainFrame.tabs().buttons.dungeons.badgeCount)
    local r1, r2 = row("run:r1"), row("run:r2")
    -- CF-62: the short name and the time; role pips, the counts; CF-106: your status on the right.
    assert.are.equal("The Deadmines", r1.name:GetText())
    assert.are.equal(os.date("%H:%M", NOW + 9600), r1.right:GetText())
    assert.are.equal("2 in \194\183 2 open", r1.meta:GetText())
    assert.are.equal("you\226\128\153re in", r1.who:GetText())
    assert.are.equal("answer", r2.who:GetText())
    assert.is_true(r2.dot.shown) -- the gold square before "answer"
    assert.is_false(r1.dot.shown)
    assert.are.equal(5, #r1.pips)
    local all = text()
    assert.is_truthy(all:find("\nRuns\n", 1, true))
    assert.is_truthy(ns.RunsTab.buttons()["Ask now\226\128\166"]) -- CF-106 (board DL01): back on the list
    assert.are.equal(ns.PlannedRuns.whenText(NOW + 9600, NOW, os.date):find("^Today") and "Today" or "Tomorrow",
      ns.RunProgress.dayGroup(NOW + 9600, NOW, os.date))
    assert.is_truthy(all:find("\n" .. ns.RunProgress.dayGroup(NOW + 9600, NOW, os.date) .. "\n", 1, true))
    assert.is_truthy(all:find("\n" .. ns.RunProgress.dayGroup(NOW + 26 * 3600, NOW, os.date) .. "\n", 1, true))
    assert.is_truthy(all:find("\nRuns from ", 1, true)) -- CF-63: "Runs from Wed 22:30" with an â“˜
    assert.is_truthy(table.concat(ns.RunsTab.tips(), "\n"):find("Runs from the website. Type /reload after an "
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
    assert.are.equal(5, #ns.RunsTab.groupRows())
    assert.is_truthy(all:find("\nTank \194\183 nobody fits\n", 1, true))
    assert.is_truthy(all:find("\nGarraka Doombringer\n20 \194\183 Solvar\n", 1, true))
    assert.is_truthy(all:find("\nVes Doombringer\n20 \194\183 you\norganiser\n", 1, true))
    assert.is_truthy(all:find("\nAda Lovewell\nAda\nmaybe\n", 1, true))
    assert.is_truthy(all:find("\nDamage \194\183 open\n", 1, true))
    assert.is_truthy(all:find("\n2 in \194\183 1 maybe \194\183 2 open\n", 1, true))
    -- The organiser before the start: Invite all opens 15 minutes early, with its tooltip; the reminder.
    assert.is_truthy(all:find("\nAt " .. os.date("%H:%M", NOW + 9600) .. "\n", 1, true))
    local invite = ns.RunsTab.buttons()["Invite all \194\183 opens " .. os.date("%H:%M", NOW + 9600 - 900)]
    assert.is_false(invite.enabled)
    assert.are.equal("Invite all invites everyone who is in and online.", invite.tooltip)
    assert.is_truthy(all:find("\nReminder at " .. os.date("%H:%M", NOW + 9600 - 1800) .. "\n", 1, true))
    -- Online now, fits: nobody else online in range here; its explanation in the â“˜.
    assert.is_truthy(all:find("\nNobody else online fits\n", 1, true))
    assert.is_truthy(table.concat(ns.RunsTab.tips(), "\n"):find("Online members whose current character fits 17"
      .. DASH .. "26.", 1, true))
    assert.is_truthy(all:find("\nEdit or cancel\n", 1, true))
    assert.are.equal("https://example.com/runs/r1", ns.RunsTab.linkBox():GetText())
    assert.is_truthy(table.concat(ns.RunsTab.tips(), "\n"):find("Copy with Ctrl+C. Edit or cancel happens on the "
      .. "website.", 1, true)) -- CF-63: in the â“˜, not a line
    -- Someone else's run: your answer, Online now with Whisper, "On the website".
    select("run:r2")
    all = text()
    assert.is_truthy(all:find("planned on Discord", 1, true))
    assert.is_truthy(all:find("\nDiscord\n", 1, true))
    assert.is_truthy(all:find("\nYour answer\n", 1, true))
    assert.is_truthy(ns.RunsTab.buttons()["I\226\128\153m in"] and ns.RunsTab.buttons()["Maybe"]
      and ns.RunsTab.buttons()["Can\226\128\153t"])
    assert.is_truthy(all:find("\nGarraka Doombringer\n20 \194\183 Solvar\n", 1, true)) -- online, fits
    assert.is_truthy(ns.RunsTab.buttons()["Whisper:1"])
    assert.is_truthy(all:find("\nOn the website\n", 1, true))
  end)

  -- CF-63b (board CF63Group): a member's tooltip and right-click menu; an open slot's Ask and menu.
  it("shows a member's tooltip and menu, and asks for an open slot with the run's note", function()
    load(20, sampleRuns())
    open()
    local garraka, slot
    for _, g in ipairs(ns.RunsTab.groupRows()) do
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
    assert.are.equal(ns.Format.path("Solvar#2032", GARRAKA), addon.db.global.settings.tree.selected)
    ns.MainFrame.selectTab("runs")
    -- Your own row has no menu.
    for _, g in ipairs(ns.RunsTab.groupRows()) do
      if (g.info:GetText() or ""):find("you", 1, true) then assert.is_nil(g.menu) end
    end
    -- CF-64: one "Ask now for this run" for the run; it fills the Ask dialog's note. A click on an open slot opens
    -- Whisper / Ask / Invite.
    local asks = 0
    for label in pairs(ns.RunsTab.buttons()) do
      if label == "Ask now for this run" then asks = asks + 1 end
    end
    assert.are.equal(1, asks)
    ns.RunsTab.buttons()["Ask now for this run"]:RunScript("OnClick")
    -- The run's first open role: the tank.
    assert.are.equal("For The Deadmines " .. os.date("%H:%M", NOW + 9600) .. " \194\183 need a tank",
      ns.RunDialogs.widgets().note:GetText())
    slot:RunScript("OnMouseUp", "LeftButton")
    menu = state.menus[#state.menus]
    assert.are.equal("Damage \194\183 open", menu.title)
    assert.are.same({ "Whisper", "Ask now for this run" }, { menu.buttons[1].text, menu.buttons[2].text })
    assert.is_false(menu.buttons[1].enabled) -- nobody else online fits
  end)

  -- CF-64: a group member's class icon comes from synced records or the community roster too; unknown: no ring.
  it("shows a member's class icon from the records, and none when the class is unknown", function()
    local runs = sampleRuns()
    runs.runs[1].answers[4] = { guid = "Player-1-0000BBBB", name = "Bo Example", answer = "in", role = "dps",
                                source = "site" }
    load(20, runs)
    addon.db.global.people["Bo#2002"] = { displayName = "Bo", version = 3,
      chars = { ["Player-1-0000BBBB"] = { name = "Bo Example", classFile = "PRIEST", level = 20 } } }
    open()
    local bo, ada
    for _, g in ipairs(ns.RunsTab.groupRows()) do
      if (g.name:GetText() or ""):find("Bo Example", 1, true) then bo = g end
      if (g.name:GetText() or ""):find("Ada Lovewell", 1, true) then ada = g end
    end
    assert.are.equal("PRIEST", bo.portrait.classFile)
    assert.is_true(bo.portrait.shown)
    assert.is_false(ada.portrait.shown) -- a Discord answer without a character: no empty ring
  end)

  -- CF-65: a redraw (the minute countdown, a roster change) keeps a drawn button shown: hiding and showing it
  -- between mouse down and up drops the click.
  it("keeps its buttons shown through a redraw, and opens the Ask dialog from every entry point", function()
    load(20, sampleRuns())
    open()
    local before = ns.RunsTab.buttons()["Ask now for this run"]
    local hidden = 0
    local hide = before.Hide
    before.Hide = function(self) hidden = hidden + 1 return hide(self) end
    ns.MainFrame.render()
    ns.MainFrame.render()
    assert.are.equal(0, hidden)
    assert.are.equal(before, ns.RunsTab.buttons()["Ask now for this run"])
    -- Ask now for this run: the dialog with the run's dungeon and note.
    before:RunScript("OnClick")
    assert.is_true(ns.RunDialogs.frame().shown)
    assert.is_truthy(ns.RunDialogs.widgets().note:GetText():find("^For The Deadmines "))
    ns.RunDialogs.frame():Hide()
    -- A dungeon's Ask now (CF-106: in the Dungeons tab).
    ns.MainFrame.showDungeon("wc")
    ns.DungeonsTab.buttons()["Ask now"]:RunScript("OnClick")
    assert.is_truthy(table.concat(ns.RunDialogs.texts(), "\n"):find("Wailing Caverns", 1, true))
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
    for label, b in pairs(ns.RunsTab.buttons()) do
      if label:find("^Invite all \194\183 %d+ online$") then invite = b end
    end
    assert.is_not_nil(invite)
    assert.are.equal("Invite all invites everyone who is in and online.", invite.tooltip)
    select("run:r2") -- tomorrow: still Whisper there
    assert.is_truthy(ns.RunsTab.buttons()["Whisper:1"])
  end)

  -- CF-106 (board DL01 A): once a run started, its bosses with a check per kill from the group's kill log.
  it("shows the bosses of a started run from the group's kill log, and opens its dungeon", function()
    local runs = sampleRuns()
    runs.runs[1].startsAt = NOW - 1800
    load(20, runs)
    open()
    -- Your own feed has a kill (contract 1: bossKills), a friend's kills came live (CF-103's KILL: liveKills).
    addon.db.global.self.feed = { [20760] = { [VES] = { runs = { { name = "The Deadmines", kind = "party",
      bosses = 1, bossKills = { [90003] = NOW - 600 } } } } } }
    addon.db.global.liveKills = { [GARRAKA] = { [90001] = NOW - 1500, [90002] = NOW - 900 },
                                  ["Player-1-STRANGER"] = { [90004] = NOW - 300 } } -- not in the group: doesn't count
    ns.MainFrame.render()
    assert.are.equal("2 in \194\183 3/6 bosses", row("run:r1").meta:GetText())
    local all = text()
    assert.is_truthy(all:find("\nBosses\n", 1, true))
    assert.is_truthy(all:find("\n3 of 6\n", 1, true))
    assert.is_truthy(all:find("started " .. os.date("%H:%M", NOW - 1500), 1, true))
    local bosses = ns.RunsTab.bossRows()
    assert.are.equal(7, #bosses)
    local checked = 0
    for _, b in ipairs(bosses) do
      if b.check.shown then checked = checked + 1 end
    end
    assert.are.equal(3, checked)
    assert.is_truthy(all:find("\nCookie optional\n", 1, true))
    local tips = table.concat(ns.RunsTab.tips(), "\n")
    assert.is_truthy(tips:find("Killed " .. os.date("%H:%M", NOW - 1500) .. " (from Solvar\226\128\153s log)", 1, true))
    assert.is_truthy(tips:find("Killed " .. os.date("%H:%M", NOW - 600) .. " (from your log)", 1, true))
    -- The final boss: cleared, Cookie skipped.
    addon.db.global.liveKills[GARRAKA][90006] = NOW - 60
    ns.MainFrame.render()
    assert.is_truthy(text():find("\nCookie \226\128\147 skipped\n", 1, true))
    -- Dungeon › opens it in the Dungeons tab.
    ns.RunsTab.buttons()["Dungeon \226\128\186"]:RunScript("OnClick")
    assert.are.equal("dungeons", ns.MainFrame.tabs().active)
    assert.are.equal("dm", addon.db.global.settings.dungeonTree.selected)
  end)

  -- CF-106 (board DL03 E): a started run without a kill, and a run none of your characters fits.
  it("marks a run without a boss yet and a run that fits none of your characters", function()
    local runs = sampleRuns()
    runs.runs[1].startsAt = NOW - 600
    runs.runs[3] = { id = "r3", dungeon = "gnomer", startsAt = NOW + 50 * 3600, source = "site",
                     organiser = { battleTag = "Ada#1001", name = "Ada Lovewell" }, answers = {} }
    load(20, runs)
    open()
    assert.are.same({ "run:r1", "run:r2", "run:r3" }, values())
    assert.are.equal("no boss yet", row("run:r1").who:GetText())
    assert.are.equal("2 in", row("run:r1").meta:GetText())
    assert.are.equal("no fit", row("run:r3").who:GetText())
    assert.is_truthy(text():find("\nLater\n", 1, true))
    assert.are.equal(1, ns.MainFrame.tabs().buttons.runs.badgeCount) -- r2 only: no fit never counts
    -- You can still answer a run that doesn't fit.
    select("run:r3")
    assert.is_truthy(ns.RunsTab.buttons()["I\226\128\153m in"])
    -- 3 h after its start without a kill, r1 leaves the list.
    state.serverTime = NOW - 600 + 3 * 3600
    ns.MainFrame.render()
    assert.are.same({ "run:r2", "run:r3" }, values())
  end)

  it("keeps the link to copy when typed over", function()
    load(20, sampleRuns())
    open()
    local box = ns.RunsTab.linkBox()
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
    assert.are.equal("primary", ns.RunsTab.buttons()["Maybe"].kind) -- CF-62: your answer, highlighted
    assert.are.equal(NOW - 60, addon.db.global.plannedRuns.updatedAt)
  end)

  it("hides cancelled runs and runs that started long ago (CF-46)", function()
    local runs = sampleRuns()
    runs.runs[1].state = "cancelled"
    runs.runs[2].startsAt = NOW - 3 * 3600
    load(20, runs)
    open()
    assert.are.same({}, values()) -- CF-106: no boss 3 h after the start: gone
    assert.are.equal(0, ns.MainFrame.tabs().buttons.runs.badgeCount or 0)
    assert.is_truthy(text():find("\nNo runs planned\n", 1, true))
    ns.RunsTab.buttons()["Find a dungeon \226\128\186"]:RunScript("OnClick") -- opens the Dungeons tab on Fits you
    assert.are.equal("dungeons", ns.MainFrame.tabs().active)
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
      for _, g in ipairs(ns.RunsTab.groupRows()) do
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
      -- CF-94: Edit or cancel / On the website below the group and your answer, at the full width.
      local box = ns.RunsTab.linkBox()
      assert.is_true(box.shown)
      assert.are.equal(20, box.points[1][2])
      assert.are.equal(520, box.width) -- the 520 px detail of the specs
      assert.is_true(-box.points[1][3] > lastY)
    end)

  -- CF-94: Online now, fits takes the full width with Edit or cancel below it; Whisper (and Invite) at the right
  -- never cover the name and "level Â· friend", which are cut before them at the window's narrowest.
  describe("online now, fits (CF-94)", function()
    local LONG = "Bartholomew Thunderbrewington Featherstonehaugh of the Western Reach"

    local function loadWithOnline(count)
      load(20, sampleRuns())
      for i = 1, count do
        state.clubMembers[CLUB][#state.clubMembers[CLUB] + 1] = { memberId = 100 + i,
          guid = "Player-1-ON" .. i, name = (i == 1 and LONG or ("Online Example" .. i)), classID = 1,
          level = 20, presence = 1, clubType = 1 }
      end
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    end

    local function assertRows(expected, inviteShown, width)
      local rows = ns.RunsTab.onlineRows()
      assert.are.equal(expected, #rows)
      local lastY = 0
      for _, o in ipairs(rows) do
        assert.are.equal(20, o.points[1][2]) -- at the left edge of the detail
        assert.are.equal(width or 520, o.width) -- the full width
        assert.are.equal(inviteShown, o.invite.shown)
        local buttons = o.button.width + (inviteShown and (o.invite.width + 6) or 0)
        local used = 26 + o.name.width + 8 + o.info.width + 8 + buttons
        assert.is_true(used <= o.width, tostring(o.name:GetText()))
        assert.is_true(o.info.width >= o.info:GetStringWidth() - 1) -- "20 Â· community" whole
        if inviteShown then
          assert.are.same({ "RIGHT", o.invite, "LEFT", -6, 0 }, o.button.points[1])
        else
          assert.are.same({ "RIGHT", 0, 0 }, o.button.points[1])
        end
        lastY = math.max(lastY, -o.points[1][3])
      end
      return lastY
    end

    it("lays the rows out at the full width, Edit or cancel below them", function()
      loadWithOnline(6)
      open()
      local all = text()
      assert.is_truthy(all:find("\nOnline now, fits\n", 1, true))
      assert.is_truthy(all:find("\n20 \194\183 community\n", 1, true))
      local lastY = assertRows(6, false)
      local long = ns.RunsTab.onlineRows()[1]
      assert.is_true(long.name:GetText():find("Bartholomew", 1, true) ~= nil)
      assert.is_true(long.name.width < long.name:GetStringWidth()) -- cut, not over Whisper
      -- Edit or cancel below the last row, at the left edge and the full width.
      local box = ns.RunsTab.linkBox()
      assert.are.equal(20, box.points[1][2])
      assert.are.equal(520, box.width)
      assert.is_true(-box.points[1][3] > lastY + 30)
      assert.is_truthy(all:find("\nEdit or cancel\n", 1, true))
      -- Someone else's run: the same, with On the website.
      select("run:r2")
      assertRows(7, false) -- Garraka too: not in this group
      assert.is_truthy(text():find("\nOn the website\n", 1, true))
      assert.are.equal(20, ns.RunsTab.linkBox().points[1][2])
    end)

    it("keeps the text clear of Invite and Whisper once inviting opens", function()
      loadWithOnline(2)
      state.serverTime = NOW + 9600 - 600 -- 10 minutes before The Deadmines
      open()
      assertRows(2, true)
    end)

    it("fits the rows and the link to the detail that shows at the window's 700 px minimum", function()
      loadWithOnline(3)
      open()
      local area = ns.RunsTab.onlineRows()[1].parent.parent -- the detail's scroll area
      area:SetWidth(700 - 290 - 2) -- the window's minimum less the list
      select("run:r1")
      assertRows(3, false, 408 - 6 - 40)
      assert.is_true(ns.RunsTab.onlineRows()[1].name.width < ns.RunsTab.onlineRows()[1].name:GetStringWidth())
      assert.are.equal(362, ns.RunsTab.linkBox().width)
      state.serverTime = NOW + 9600 - 600 -- Invite beside Whisper: still clear
      select("run:r1")
      assertRows(3, true, 362)
    end)

    it("puts Edit or cancel below the line when nobody else online fits", function()
      load(20, sampleRuns())
      open()
      assert.are.equal(0, #ns.RunsTab.onlineRows())
      assert.is_truthy(text():find("\nNobody else online fits\n", 1, true))
      assert.are.equal(20, ns.RunsTab.linkBox().points[1][2])
      assert.are.equal(520, ns.RunsTab.linkBox().width)
    end)
  end)

  -- CF-95: at the window's 700 px minimum the detail shows 408 px; everything in it follows that width (362 px
  -- between the 20 px pads): texts end within it on one line (cut with "..."), buttons stay whole, and what
  -- doesn't fit beside something goes below it.
  describe("at the window's 700 px minimum (CF-95)", function()
    local W -- the width of the layout: 362 at the minimum (set by narrow)
    local LONG = "Bartholomew Thunderbrewington Featherstonehaugh of the Western Reach"

    -- A region's left edge below the parent's left, from its first anchor.
    local function leftOf(r)
      local p = r.points[1]
      if p[1] == "TOPLEFT" and type(p[2]) == "number" then return p[2] end
      if p[1] == "TOPRIGHT" then return p[4] - r.width end
      if p[1] == "LEFT" then return leftOf(p[2]) + p[2].width + p[4] end
      if p[1] == "TOP" then return leftOf(p[2]) + (p[2].width - r.width) / 2 end
      error("anchor " .. tostring(p[1]))
    end
    local function topOf(r) return -r.points[1][#r.points[1]] end

    local function narrow(width)
      width = width or (700 - 290 - 2) -- the window's minimum less the list
      W = math.max(300, width - 6 - 40)
      ns.RunsTab.detailArea():SetWidth(width)
      ns.MainFrame.render()
    end

    -- Every text in the detail ends within the width, on one line (the empty state's explainer wraps).
    local function textsFit(wraps)
      for _, h in ipairs(ns.RunsTab.detailTexts()) do
        local t = h.text:GetText() or ""
        if t ~= "" then
          local x = h.points[1][2]
          assert.is_true(x >= 20 and x + (h.text.width or 0) <= 20 + W, t .. " at " .. x .. " + " .. h.text.width)
          if t ~= wraps then assert.is_false(h.text.wordWrap, t) end
        end
      end
    end

    -- Every button of the detail is whole within the width (the answer block's are placed in it, at x 20).
    local function buttonsFit()
      local block = ns.RunAnswer.block()
      local seen = 0
      for label, b in pairs(ns.RunsTab.buttons()) do
        if b.shown and b.points and b.points[1] and type(label) == "string" and not label:find("^select:")
            and not label:find("^chip:") and not label:find("^Whisper:") and b.parent ~= nil then
          local x
          if block and b.parent == block then
            x = 20 + leftOf(b)
          elseif b.parent == ns.RunsTab.detailArea().child then
            x = leftOf(b)
          end
          if x then
            seen = seen + 1
            assert.is_true(x >= 20 and x + b.width <= 20 + W, label .. " at " .. x .. " + " .. b.width)
          end
        end
      end
      return seen
    end

    local function groupRowsFit()
      for _, g in ipairs(ns.RunsTab.groupRows()) do
        assert.are.equal(W, g.width)
        local onlineW = (g.online:GetText() or "") ~= "" and (g.online:GetStringWidth() + 8) or 0
        local used = 66 + g.name.width + 8 + g.info.width + onlineW + 12 + g.status.width + 10
        assert.is_true(used <= g.width, tostring(g.name:GetText()))
      end
    end

    local function onlineRowsFit()
      for _, o in ipairs(ns.RunsTab.onlineRows()) do
        assert.are.equal(W, o.width)
        local buttons = o.button.width + (o.invite.shown and (o.invite.width + 6) or 0)
        assert.is_true(26 + o.name.width + 8 + o.info.width + 8 + buttons <= o.width, tostring(o.name:GetText()))
      end
    end

    local function loadNarrow(level, runs, online)
      load(level or 20, runs)
      for i = 1, online or 0 do
        state.clubMembers[CLUB][#state.clubMembers[CLUB] + 1] = { memberId = 100 + i,
          guid = "Player-1-ON" .. i, name = (i == 1 and LONG or ("Online Example" .. i)), classID = 1,
          level = level or 20, presence = 1, clubType = 1 }
      end
      if online then wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB) end
      open()
      narrow()
    end

    -- A run with long names, a long note and a reserve, so every line has more than fits.
    local function longRuns()
      local runs = sampleRuns()
      local r1 = runs.runs[1]
      r1.note = "Bring water, food, a repair bill and patience; we clear the whole place including the ship"
      r1.answers[3].name = LONG
      r1.answers[#r1.answers + 1] = { battleTag = "Cy#3003", name = "Cyrilla Longername-Featherstonehaugh",
        answer = "in", role = "dps", source = "discord" }
      r1.answers[#r1.answers + 1] = { battleTag = "Di#4004", name = "Dimitri Reservington", answer = "in",
        role = "heal", source = "discord", reserve = true }
      r1.answers[#r1.answers + 1] = { battleTag = "Ed#5005", name = "Edwina Reservington", answer = "in",
        role = "heal", source = "discord", reserve = true }
      return runs
    end

    it("lays your run out at the width that shows: header, group, start, online now, the link", function()
      loadNarrow(20, longRuns(), 3)
      select("run:r1")
      local all = text()
      assert.is_truthy(all:find("\nEdit or cancel\n", 1, true))
      assert.is_truthy(all:find("\nReserve: ", 1, true))
      textsFit()
      assert.is_true(buttonsFit() >= 2) -- Invite all, Ask now for this run
      groupRowsFit()
      onlineRowsFit()
      assert.are.equal(W, ns.RunsTab.linkBox().width)
      -- Ask now for this run: beside "Group" and the counts when they fit, else below them.
      local ask = ns.RunsTab.buttons()["Ask now for this run"]
      local counts
      for _, h in ipairs(ns.RunsTab.detailTexts()) do
        if (h.text:GetText() or ""):find(" in \194\183 ", 1, true) then counts = h end
      end
      if ask.points[1][1] == "TOPRIGHT" then
        assert.is_true(counts.points[1][2] + counts.text.width <= leftOf(ask) - 8)
      else
        assert.is_true(topOf(ask) >= topOf(counts) + 16)
        assert.is_true(topOf(ns.RunsTab.groupRows()[1]) >= topOf(ask) + 24) -- the rows below it
      end
    end)

    it("puts Ask now for this run beside the counts when they fit", function()
      loadNarrow(20, sampleRuns())
      narrow(560 + 300) -- a wide window
      local ask = ns.RunsTab.buttons()["Ask now for this run"]
      assert.are.equal("TOPRIGHT", ask.points[1][1])
      buttonsFit()
    end)

    it("lays someone else's run out with your answer wrapping to the width", function()
      loadNarrow(20, sampleRuns(), 2)
      select("run:r2")
      assert.is_truthy(text():find("\nOn the website\n", 1, true))
      textsFit()
      local answers = ns.RunAnswer.buttons()
      assert.is_truthy(answers["I\226\128\153m in"] and answers.character)
      assert.is_true(buttonsFit() >= 4) -- the three answers and the character at least
      groupRowsFit()
      onlineRowsFit()
      -- The answer texts end within the width; the note line below the last row of buttons.
      local block = ns.RunAnswer.block()
      assert.are.equal(W, block.width)
      local lowest = 0
      for _, b in pairs(answers) do lowest = math.max(lowest, topOf(b) + 28) end
      assert.is_true(topOf(block.note) >= lowest, topOf(block.note) .. " vs " .. lowest)
      assert.is_true(block.select.text.width <= block.select.width - 62)
      assert.is_false(block.select.text.wordWrap)
      local hw = block.heading:GetStringWidth()
      assert.is_true(hw + 10 + block.status.width <= W)
    end)

    it("keeps Invite all, Whisper and the Invite buttons whole once inviting opens", function()
      local runs = longRuns()
      load(20, runs)
      state.serverTime = NOW + 9600 - 600 -- 10 minutes before The Deadmines
      -- Someone in on another character: Whisper <friend> beside Invite all, or below it when it doesn't fit.
      ns.RunAlerts.context = function() return {} end
      ns.RunStart.states = function(run)
        return { { answer = run.answers[2], state = "other" }, { answer = run.answers[3], state = "offline" } }
      end
      for i = 1, 2 do
        state.clubMembers[CLUB][#state.clubMembers[CLUB] + 1] = { memberId = 100 + i, guid = "Player-1-ON" .. i,
          name = LONG, classID = 1, level = 20, presence = 1, clubType = 1 }
      end
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
      open()
      for _, width in ipairs({ 408, 346 }) do -- the minimum, and the 300 px floor of the layout
        narrow(width)
        local all = text()
        assert.is_truthy(all:find("\nStart\n", 1, true))
        assert.is_truthy(all:find(" is offline.\n", 1, true))
        local whisper
        for label, b in pairs(ns.RunsTab.buttons()) do
          if type(label) == "string" and label:find("^Whisper ") then whisper = b end
        end
        assert.is_table(whisper)
        assert.are.equal(width == 408 and 362 or 300, W)
        textsFit()
        buttonsFit()
        groupRowsFit()
        onlineRowsFit()
        assert.is_true(ns.RunsTab.onlineRows()[1].invite.shown)
      end
      -- At the floor Whisper goes below Invite all.
      local whisper
      for label, b in pairs(ns.RunsTab.buttons()) do
        if type(label) == "string" and label:find("^Whisper ") then whisper = b end
      end
      assert.are.equal(20, whisper.points[1][2])
    end)
  end)

end)
