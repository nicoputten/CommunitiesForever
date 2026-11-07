local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-48: the reminder, the start of a run, the start panel and the chat lines.
describe("Run alerts (CF-48)", function()
  local state, ns, addon, invited, requested
  local CLUB = "23125681"
  local NOW = 1793120000
  local VES, GARRAKA = "Player-4619-01627852", "Player-4619-01789956"
  local SJAAK, SJAAK_GA = "Solvar#2032", 5

  local function load(runs, setup)
    state = wowapi.install()
    state.serverTime = NOW
    state.player.level = 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = 20 end
    for _, f in ipairs(state.friends) do
      for _, g in ipairs(f.gameAccounts) do g.characterLevel = 20 end
    end
    ns = helpers.loadAddon()
    _G.CF_RUNS = runs
    invited, requested = {}, {}
    _G.C_PartyInfo = { InviteUnit = function(name) invited[#invited + 1] = name end,
                       RequestInviteFromUnit = function(name) requested[#requested + 1] = name end }
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    if setup then setup(addon.db.global) end
    addon:OnEnable()
  end

  local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")) end

  local function printed()
    local list = {}
    for i, line in ipairs(state.printed) do list[i] = plain(line) end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  -- Moves the server clock to `at` and lets the pending timers (the 15 s check among them) run once.
  local function advance(at)
    state.serverTime = at
    state.time = state.time + 15
    wowapi.runTimers(state)
  end

  local function panelText()
    local list = {}
    for i, t in ipairs(ns.StartPanel.texts()) do list[i] = plain(t) end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  -- Ves organises the Deadmines at NOW + 1 h; Sjaak (Garraka) is in. Sjaak organises Wailing Caverns at
  -- NOW + 2 h; Ves is in.
  local function runs(garrakaGuid)
    return { updatedAt = NOW - 600, reminderMinutes = 30, runs = {
      { id = "r1", dungeon = "dm", startsAt = NOW + 3600,
        organiser = { battleTag = "Vestras#1000", guid = VES, name = "Ves Doombringer" },
        answers = { { guid = VES, answer = "in" },
                    { battleTag = SJAAK, guid = garrakaGuid or GARRAKA, name = "Garraka Doombringer", answer = "in",
                      role = "heal" },
                    { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "maybe", source = "discord" } } },
      { id = "r2", dungeon = "wc", startsAt = NOW + 7200,
        organiser = { battleTag = SJAAK, guid = GARRAKA, name = "Garraka Doombringer" },
        answers = { { guid = VES, name = "Ves Doombringer", answer = "in" } } },
    } }
  end

  after_each(function()
    wowapi.uninstall()
    _G.CF_RUNS, _G.C_PartyInfo, _G.ReloadUI = nil, nil, nil
  end)

  it("reminds with the banner (CF-63d) and its Open, not in chat (CF-91)", function()
    load(runs())
    state.printed = {}
    advance(NOW + 3600 - 1800)
    assert.are.same({}, state.printed)
    local banner = ns.RunBanner.frame()
    assert.is_true(banner.shown)
    assert.are.same({ "In 30 minutes", "The Deadmines", "Ves Doombringer \194\183 " .. os.date("%H:%M", NOW + 3600) },
      { banner.title:GetText(), banner.name:GetText(), banner.line:GetText() })
    assert.is_false(banner.invite.shown)
    -- 15 minutes before: Invites open, and the organiser's Invite all.
    advance(NOW + 3600 - 900)
    local shown = ns.RunBanner.shown()
    assert.are.same({ "invites", true }, { shown[#shown].kind, shown[#shown].invite })
    banner:RunScript("OnClick")
    assert.are.equal("run:r1", addon.db.global.settings.runsTab.selected) -- CF-106: the Runs tab
    assert.are.same({}, state.printed)
  end)

  it("leaves out the note when turned off", function()
    load(runs(), function(g) g.settings.runToasts = false end)
    state.printed = {}
    advance(NOW + 3600 - 1800)
    assert.are.same({}, state.printed)
    assert.is_nil(ns.RunBanner.frame())
    assert.is_nil(ns.Settings.option("runLine_reminder")) -- CF-91: the run chat line switches are gone
  end)

  it("opens the start panel for the organiser: invite everyone ready, ping the missing", function()
    load(runs())
    advance(NOW + 3600)
    assert.is_true(ns.StartPanel.isShown())
    local all = panelText()
    assert.is_truthy(all:find("\nThe Deadmines \194\183 starting now\n", 1, true))
    assert.is_truthy(all:find("\nready \194\183 online on this character\n", 1, true))
    assert.is_truthy(all:find("\noffline \194\183 answered on Discord\n", 1, true))
    ns.StartPanel.buttons()["Invite everyone ready (1)"]:RunScript("OnClick")
    assert.are.same({ "Garraka Doombringer" }, invited)
    state.printed = {}
    ns.StartPanel.buttons()["Ping on Discord"]:RunScript("OnClick")
    local ping = addon.db.global.pending[1]
    assert.are.same({ "ping", "r1", "Ada#1001" }, { ping.kind, ping.run, ping.battleTag })
    assert.are.same({}, state.printed) -- CF-91: the panel says it, not chat
    assert.is_truthy(panelText():find("ping queued", 1, true))
    assert.is_truthy(ns.StartPanel.buttons()["Reload now"])
    assert.is_false(ns.StartPanel.buttons()["Ping everyone missing on Discord"].enabled)
  end)

  it("skips friends already in your group", function()
    load(runs())
    state.group = { GARRAKA }
    state.unitGuids = { party1 = GARRAKA }
    advance(NOW + 3600)
    assert.is_truthy(panelText():find("\nalready grouped\n", 1, true))
    assert.is_false(ns.StartPanel.buttons()["Invite everyone ready (0)"].enabled)
  end)

  it("shows a friend on another character in the start panel, with Whisper and Invite instead", function()
    load(runs("Player-4619-0000ALT1"))
    state.printed = {}
    advance(NOW + 3600)
    assert.are.same({}, state.printed) -- CF-91: no chat line
    assert.is_truthy(panelText():find("online, but on Garraka Doombringer (20)", 1, true))
    local whisper
    for label in pairs(ns.StartPanel.buttons()) do
      if label:find("^Whisper ") then whisper = label end
    end
    assert.is_truthy(whisper)
  end)

  it("shows everyone else the start banner; the run's start panel has Request invite", function()
    load(runs())
    state.printed = {}
    advance(NOW + 7200)
    local shown = ns.RunBanner.shown()
    assert.are.same({ "start", "Starting now", "Wailing Caverns", false },
      { shown[#shown].kind, shown[#shown].title, shown[#shown].name, shown[#shown].invite })
    assert.are.same({}, state.printed) -- CF-91: no "starting now" line
    ns.StartPanel.open("r2")
    ns.StartPanel.buttons()["Request invite"]:RunScript("OnClick")
    assert.are.same({ "Garraka Doombringer" }, requested)
    assert.is_truthy(printed():find("Asked Garraka Doombringer for an invite.", 1, true)) -- the click's answer
  end)

  it("holds banners during combat, then shows only the latest still worth showing (CF-63d)", function()
    load(runs())
    state.inCombat = true
    advance(NOW + 3600 - 1800)
    assert.is_nil(ns.RunBanner.frame()) -- held
    advance(NOW + 3600 - 900)
    state.inCombat = false
    advance(NOW + 3600 - 890)
    local shown = ns.RunBanner.shown()
    assert.are.equal(1, #shown)
    assert.are.equal("invites", shown[1].kind) -- the 30-minute one is not shown any more
  end)

  it("says nothing in chat about answers to your run or runs from a friend (CF-91)", function()
    load(runs())
    state.printed = {}
    addon:SendMessage(ns.Messenger.RECEIVED, { t = "RUNANSWER", run = "r1", answer = "maybe", guid = GARRAKA,
      name = "Garraka Doombringer" }, SJAAK, SJAAK_GA)
    local newer = runs()
    newer.updatedAt = NOW
    newer.runs[1].answers[3] = { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "cant", source = "discord" }
    ns.Planner.receive(newer)
    assert.are.same({}, state.printed)
  end)
end)
