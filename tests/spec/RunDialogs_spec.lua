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

  -- CF-64 (Nico): no planning in the game; the reload prompt is short, its detail in an ⓘ, and sits on the window.
  it("has no Plan a run; the reload prompt is short and reloads", function()
    load(nil)
    open("dm")
    assert.is_nil(ns.DungeonsTab.buttons()["Plan a run\226\128\166"])
    assert.is_nil(ns.RunDialogs.plan)
    ns.RunDialogs.reloadPrompt()
    local all = dialogText()
    assert.is_truthy(all:find("\nReload to post it on Discord\nFriends in game got it already.", 1, true))
    assert.is_truthy(table.concat(ns.RunDialogs.tips(), "\n"):find("The game saves only on a reload or logout", 1,
      true))
    local frame, window = ns.RunDialogs.frame(), ns.MainFrame.window()
    assert.are.same({ "CENTER", window }, { frame.points[1][1], frame.points[1][2] })
    local reloaded = false
    _G.ReloadUI = function() reloaded = true end
    click("Reload now")
    assert.is_true(reloaded)
  end)

  it("asks without Discord when unticked (CF-65)", function()
    load(nil)
    open("dm")
    ns.DungeonsTab.buttons()["Ask now\226\128\166"]:RunScript("OnClick")
    ns.RunDialogs.widgets().discord:RunScript("OnClick")
    assert.is_false(ns.RunDialogs.widgets().discord:GetChecked())
    click("Ask now")
    assert.are.equal(0, #pending())
    assert.is_falsy(dialogText():find("Reload to post it on Discord", 1, true))
  end)

  -- CF-65: every dialog sits above the main window (FULLSCREEN over its DIALOG), raised on show.
  it("opens every dialog above the main window", function()
    load(nil)
    open("dm")
    assert.are.equal("DIALOG", ns.MainFrame.window().strata)
    ns.DungeonsTab.buttons()["Ask now\226\128\166"]:RunScript("OnClick")
    assert.are.equal("FULLSCREEN", ns.RunDialogs.frame().strata) -- Ask now and the reload prompt
    ns.StartPanel.open("r2")
    ns.Settings.open()
    local frames = { ns.StartPanel.frame(), ns.SettingsWindow.window() }
    assert.are.equal(2, #frames)
    for _, f in ipairs(frames) do assert.are.equal("FULLSCREEN", f.strata) end
  end)

  it("says how to reload without the API", function()
    load(nil)
    open("dm")
    ns.RunDialogs.reloadPrompt()
    state.printed = {}
    click("Reload now")
    assert.is_truthy(state.printed[1]:find("Type /reload to post it now.", 1, true))
  end)

  it("asks now, always for Discord too; an ask older than 10 minutes is dropped when the game saves", function()
    load(nil)
    open("dm")
    ns.DungeonsTab.buttons()["Ask now\226\128\166"]:RunScript("OnClick")
    local all = dialogText()
    assert.is_truthy(all:find("\nYou go as Ves Doombringer 20 \194\183 damage\n", 1, true))
    assert.is_truthy(all:find("\nWHISPERED NOW \194\183 ONLINE AND FIT\n", 1, true))
    assert.is_true(ns.RunDialogs.widgets().discord:GetChecked()) -- CF-65: on by default
    ns.RunDialogs.widgets().note:SetText("Defias quests")
    click("Ask now")
    assert.are.same({ "ask", "dm", "Defias quests" }, { pending()[1].kind, pending()[1].dungeon, pending()[1].note })
    assert.are.equal(1, #pending()) -- one Discord ask (GroupAsks makes none of its own then)
    assert.is_truthy(dialogText():find("Reload to post it on Discord", 1, true))
    click("Later")
    state.serverTime = NOW + 601
    wowapi.fireEvent(state, "PLAYER_LOGOUT")
    assert.are.equal(0, #pending())
  end)

  -- CF-63b (board CF63Answer): answering is inline under the group; every click saves at once.
  local IN, CANT = "I\226\128\153m in", "Can\226\128\153t"
  local function tap(label) ns.DungeonsTab.buttons()[label]:RunScript("OnClick") end
  local function detailText() return plain(table.concat(ns.DungeonsTab.texts(), "\n")) end

  it("answers a run inline: pending, shown in the row, sent to the organiser, cleared when the site has it", function()
    load(runs())
    open("run:r2")
    assert.is_truthy(detailText():find("\nYour answer\nNot answered yet\n", 1, true))
    assert.is_truthy(detailText():find("Ves Doombringer  20  fits", 1, true)) -- the character you go as
    tap("Maybe")
    local item = pending()[1]
    assert.are.same({ "answer", "r2", "maybe", VES }, { item.kind, item.run, item.answer, item.guid })
    local answers = ofType("RUNANSWER")
    assert.are.equal(1, #answers)
    assert.are.equal(SJAAK_GA, answers[1].target)
    assert.are.same({ "r2", "maybe", VES }, { answers[1].message.run, answers[1].message.answer,
                                              answers[1].message.guid })
    settle()
    -- The run's detail shows your answer highlighted and a clock until the next upload.
    assert.are.equal("primary", ns.DungeonsTab.buttons()["Maybe"].kind)
    assert.is_truthy(detailText():find("\nYour answer\nYou said maybe\n", 1, true))
    assert.is_truthy(table.concat(ns.DungeonsTab.tips(), "\n"):find("Saved. Reaches the website with your next upload.",
      1, true))
    -- Can't hides the character, the roles and the note.
    tap(CANT) -- replaces the pending answer (one per run)
    assert.are.equal(1, #pending())
    assert.are.equal("cant", pending()[1].answer)
    assert.is_nil(pending()[1].guid)
    assert.is_truthy(detailText():find("\nYou can\226\128\153t make it", 1, true))
    assert.is_nil(ns.DungeonsTab.buttons().character)
    -- The site has it: a newer runs list confirms the id.
    local newer = runs()
    newer.updatedAt, newer.received = NOW, { pending()[1].id }
    newer.runs[2].answers[2] = { guid = VES, answer = "cant", source = "game" }
    assert.is_true(ns.Planner.receive(newer))
    assert.are.equal(0, #pending())
  end)

  -- CF-49: the role is picked apart from the character, from the roles its class can play.
  it("answers with a role the class can play, with its slot, and a note", function()
    load(runs())
    open("run:r2")
    local buttons = ns.DungeonsTab.buttons()
    assert.is_truthy(buttons["Tank"] and buttons["Healer"] and buttons["Damage"]) -- a paladin plays all three
    local all = detailText()
    assert.is_truthy(all:find("\nHealer \194\183 full\n", 1, true)) -- Garraka heals
    assert.is_truthy(all:find("\nTank \194\183 open\n", 1, true))
    assert.are.equal("Healer is full \194\183 you join as reserve.", buttons["Healer"].tooltip)
    tap("Healer") -- before answering: kept, not saved
    assert.are.equal(0, #pending())
    tap(IN)
    assert.are.same({ "in", "heal" }, { pending()[1].answer, pending()[1].role })
    assert.are.equal("heal", ofType("RUNANSWER")[1].message.role)
    settle()
    assert.is_truthy(detailText():find("\nYou\226\128\153re on reserve\n", 1, true)) -- the healer slot is taken
    -- Changing the role saves at once; so does the note (on Enter or when the box loses focus).
    tap("Tank")
    assert.are.same({ "in", "tank" }, { pending()[1].answer, pending()[1].role })
    settle()
    local note = ns.RunAnswer.block().note
    note:SetText("Bringing water")
    note:RunScript("OnEditFocusLost")
    assert.are.same({ "in", "tank", "Bringing water" }, { pending()[1].answer, pending()[1].role, pending()[1].note })
    assert.are.equal("Bringing water", ofType("RUNANSWER")[3].message.note)
    settle()
    assert.is_truthy(detailText():find("\n14/80", 1, true))
  end)

  it("lets a character 6+ levels below answer I'm in, its fit in the dropdown (CF-50)", function()
    local data = runs()
    data.runs[2].dungeon = "smarm" -- 32-42: Ves at 20 is 12 below
    load(data)
    open("run:r2")
    assert.is_truthy(detailText():find("Ves Doombringer  20  12 below", 1, true))
    tap(IN)
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
