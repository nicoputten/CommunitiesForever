local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-47: Ask now, Plan a run, answering a run in game, and the reload prompt.
describe("Run dialogs (CF-47)", function()
  local state, ns, addon, sent
  local CLUB = "23125681"
  local NOW = 1793120000
  local VES, GARRAKA = "Player-4619-01627852", "Player-4619-01789956"
  local SJAAK, SJAAK_GA = "Sjaakovich#2232", 5

  local function load(runs)
    state = wowapi.install()
    state.serverTime = NOW
    state.player.level = 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = 20 end
    for _, f in ipairs(state.friends) do
      for _, g in ipairs(f.gameAccounts) do g.characterLevel = 20 end
    end
    ns = helpers.loadAddon()
    _G.CF_RUNS = runs
    _G.time = os.time
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    addon:OnEnable()
    sent = {}
    local send = ns.Messenger.send
    ns.Messenger.send = function(target, message)
      sent[#sent + 1] = { target = target, message = message }
      return send(target, message)
    end
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

  local function dialogText()
    local list = {}
    for i, t in ipairs(ns.RunDialogs.texts()) do list[i] = plain(t) end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  local function row(value)
    for _, r in ipairs(ns.DungeonsTab.rows()) do
      if r.value == value then return r.frame end
    end
  end

  local function open(value)
    settle()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
    if value then row(value):RunScript("OnClick") end
  end

  local function click(name) ns.RunDialogs.buttons()[name]:RunScript("OnClick") end

  local function ofType(kind)
    local out = {}
    for _, s in ipairs(sent) do
      if s.message.t == kind then out[#out + 1] = s end
    end
    return out
  end

  local function pending() return addon.db.global.pending end

  -- Sjaak organises Wailing Caverns tomorrow; Ves organises the Deadmines.
  local function runs()
    return { updatedAt = NOW - 600, reminderMinutes = 30, runs = {
      { id = "r1", dungeon = "dm", startsAt = NOW + 9600,
        organiser = { battleTag = "Vestras#1000", guid = VES, name = "Ves Doombringer" },
        answers = { { guid = VES, answer = "in", role = "dps" } } },
      { id = "r2", dungeon = "wc", startsAt = NOW + 26 * 3600,
        organiser = { battleTag = SJAAK, guid = GARRAKA, name = "Garraka Doombringer", utcOffset = 3600 },
        answers = { { guid = GARRAKA, answer = "in", role = "heal" } } },
    } }
  end

  after_each(function()
    wowapi.uninstall()
    _G.CF_RUNS, _G.time, _G.ReloadUI, _G.C_UI = nil, nil, nil, nil
  end)

  it("plans a run: a pending item, shown at once, then the reload prompt reloads", function()
    load(nil)
    open("dm")
    ns.DungeonsTab.buttons()["Plan a run\226\128\166"]:RunScript("OnClick")
    local all = dialogText()
    assert.is_truthy(all:find("\nDUNGEON\n", 1, true) and all:find("\nLEAD AS\n", 1, true))
    assert.is_truthy(all:find("your PC clock \194\183 friends see their own time", 1, true))
    assert.is_truthy(all:find("Reaches the site and Discord after /reload. You'll be asked next.", 1, true))
    assert.are.equal("dm", ns.RunDialogs.widgets().dungeon.value)
    local days = ns.PlannedRuns.dayChoices(NOW, os.date)
    click(days[2].label) -- tomorrow
    local w = ns.RunDialogs.widgets()
    w.time:SetText("21:30")
    w.note:SetText("Bring water")
    click("Plan run")
    local item = pending()[1]
    assert.are.equal("plan", item.kind)
    assert.are.same({ "dm", VES, "Bring water" }, { item.dungeon, item.guid, item.note })
    assert.are.equal(os.time({ year = days[2].year, month = days[2].month, day = days[2].day, hour = 21, min = 30,
                               sec = 0 }), item.startsAt)
    -- The run shows in the list, marked as not on the site yet.
    settle()
    assert.are.equal("The Deadmines", row("run:" .. item.id).name:GetText())
    local clock = row("run:" .. item.id).clock -- CF-63: a clock icon, its tooltip says when
    assert.is_true(clock:IsShown())
    assert.is_truthy(clock.tip:find("Reaches the website with your next upload", 1, true))
    -- The reload prompt.
    assert.is_truthy(dialogText():find("\nReload now to post on Discord\n", 1, true))
    local reloaded = false
    _G.ReloadUI = function() reloaded = true end
    click("Reload now")
    assert.is_true(reloaded)
  end)

  it("says what is wrong with the time, and how to reload without the API", function()
    load(nil)
    open("dm")
    ns.DungeonsTab.buttons()["Plan a run\226\128\166"]:RunScript("OnClick")
    ns.RunDialogs.widgets().time:SetText("soon")
    click("Plan run")
    assert.is_truthy(dialogText():find("Type the time as 20:30.", 1, true))
    ns.RunDialogs.widgets().time:SetText("00:00") -- today, already past
    click("Plan run")
    assert.is_truthy(dialogText():find("That time has passed.", 1, true))
    assert.are.equal(0, #pending())
    ns.RunDialogs.reloadPrompt()
    state.printed = {}
    click("Reload now")
    assert.is_truthy(state.printed[1]:find("Type /reload to post it now.", 1, true))
  end)

  it("asks now, also for Discord; an ask older than 10 minutes is dropped when the game saves", function()
    load(nil)
    open("dm")
    ns.DungeonsTab.buttons()["Ask now\226\128\166"]:RunScript("OnClick")
    local all = dialogText()
    assert.is_truthy(all:find("\nYou go as Ves Doombringer 20 \194\183 damage\n", 1, true))
    assert.is_truthy(all:find("\nWHISPERED NOW \194\183 ONLINE AND FIT\n", 1, true))
    ns.RunDialogs.widgets().discord:RunScript("OnClick")
    ns.RunDialogs.widgets().note:SetText("Defias quests")
    click("Ask now")
    assert.are.same({ "ask", "dm", "Defias quests" }, { pending()[1].kind, pending()[1].dungeon, pending()[1].note })
    assert.is_truthy(dialogText():find("Reload now to post on Discord", 1, true))
    click("Later")
    state.serverTime = NOW + 601
    wowapi.fireEvent(state, "PLAYER_LOGOUT")
    assert.are.equal(0, #pending())
  end)

  it("answers a run: pending, shown in the row, sent to the organiser, cleared when the site has it", function()
    load(runs())
    open("run:r2")
    ns.DungeonsTab.buttons()["change"]:RunScript("OnClick") -- CF-62: "change" opens the answer dialog
    local all = dialogText()
    assert.is_truthy(all:find("\nWailing Caverns\n", 1, true))
    assert.is_truthy(all:find(" for Garraka Doombringer\n", 1, true)) -- the organiser's own time
    assert.is_truthy(all:find("Ves Doombringer 20 \194\183 damage | fits", 1, true))
    click("Maybe")
    click("Save answer")
    local item = pending()[1]
    assert.are.same({ "answer", "r2", "maybe", VES }, { item.kind, item.run, item.answer, item.guid })
    local answers = ofType("RUNANSWER")
    assert.are.equal(1, #answers)
    assert.are.equal(SJAAK_GA, answers[1].target)
    assert.are.same({ "r2", "maybe", VES }, { answers[1].message.run, answers[1].message.answer,
                                              answers[1].message.guid })
    settle()
    -- CF-62: the run's detail shows your answer highlighted and that it waits for the next upload.
    local function detailText() return plain(table.concat(ns.DungeonsTab.texts(), "\n")) end
    assert.are.equal("primary", ns.DungeonsTab.buttons()["Maybe"].kind)
    assert.is_falsy(detailText():find("after /reload", 1, true)) -- CF-63: no text line, a clock
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Reaches the website with your next upload",
      1, true))
    -- The site has it: a newer runs list confirms the id.
    local newer = runs()
    newer.updatedAt, newer.received = NOW, { item.id }
    newer.runs[2].answers[2] = { guid = VES, answer = "maybe", source = "game" }
    assert.is_true(ns.Planner.receive(newer))
    assert.are.equal(0, #pending())
    settle()
    assert.is_falsy(detailText():find("reaches Discord", 1, true))
  end)

  -- CF-49: the role is picked apart from the character, from the roles its class can play.
  it("answers with a role the class can play, and plans as one", function()
    load(runs())
    open("run:r2")
    ns.DungeonsTab.buttons()["change"]:RunScript("OnClick") -- CF-62: "change" opens the answer dialog
    assert.is_truthy(dialogText():find("\nROLE\n", 1, true))
    local buttons = ns.RunDialogs.buttons()
    assert.is_truthy(buttons["Tank"] and buttons["Healer"] and buttons["Damage"]) -- a paladin plays all three
    click("Healer")
    click("Save answer")
    assert.are.equal("heal", pending()[1].role)
    assert.are.equal("heal", ofType("RUNANSWER")[1].message.role)

    open("dm")
    ns.DungeonsTab.buttons()["Plan a run\226\128\166"]:RunScript("OnClick")
    click("Tank")
    ns.RunDialogs.widgets().time:SetText("23:30")
    click("Plan run")
    assert.are.equal("tank", pending()[2].role)
  end)

  it("lets a character 6+ levels below answer I'm in, with the tough note (CF-50)", function()
    local data = runs()
    data.runs[2].dungeon = "smarm" -- 32-42: Ves at 20 is 12 below
    load(data)
    open("run:r2")
    ns.DungeonsTab.buttons()["change"]:RunScript("OnClick") -- CF-62: "change" opens the answer dialog
    assert.is_truthy(dialogText():find("Ves Doombringer 20 \194\183 damage | 12 below", 1, true))
    ns.RunDialogs.rows()[1]:RunScript("OnClick")
    assert.is_truthy(dialogText():find("This will be tough.", 1, true))
    assert.is_not_false(ns.RunDialogs.buttons()["I'm in"].enabled)
    click("Save answer")
    assert.are.equal("in", pending()[1].answer)
  end)

  it("as organiser, shows an answer a friend sent in game; ignores answers to other runs", function()
    load(runs())
    addon:SendMessage(ns.Messenger.RECEIVED, { t = "RUNANSWER", run = "r1", answer = "in", guid = GARRAKA,
      name = "Garraka Doombringer", role = "heal" }, SJAAK, SJAAK_GA)
    addon:SendMessage(ns.Messenger.RECEIVED, { t = "RUNANSWER", run = "r2", answer = "cant", guid = GARRAKA },
      SJAAK, SJAAK_GA)
    local list = ns.Planner.upcoming()
    assert.are.equal(2, #list[1].answers)
    assert.are.same({ GARRAKA, "game", SJAAK }, { list[1].answers[2].guid, list[1].answers[2].source,
                                                  list[1].answers[2].battleTag })
    assert.are.equal(1, #list[2].answers) -- r2 is Sjaak's run, not yours
  end)

  it("migrates saved data from schema 1 with an empty pending list (rule 8)", function()
    local Store = helpers.loadAddonFile("src/core/Store.lua", helpers.coreNs())
    local global = Store.init({ schemaVersion = 1, people = { x = {} } })
    assert.are.same({}, global.pending)
    assert.are.same({ x = {} }, global.people)
    assert.are.equal(2, global.schemaVersion)
  end)
end)
