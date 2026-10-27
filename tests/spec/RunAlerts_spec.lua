local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-48: the reminder, the start of a run, the start panel and the chat lines.
describe("Run alerts (CF-48)", function()
  local state, ns, addon, invited, requested
  local CLUB = "23125681"
  local NOW = 1793120000
  local VES, GARRAKA = "Player-4619-01627852", "Player-4619-01789956"
  local SJAAK, SJAAK_GA = "Sjaakovich#2232", 5

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

  local function clickLink(label)
    for _, line in ipairs(state.printed) do
      local path = line:match("|Haddon:CommunitiesForever:([^|]+)|h%[" .. label:gsub("%p", "%%%0") .. "%]|h")
      if path then
        addon:SendMessage(ns.ChatLinks.CLICKED, path)
        return true
      end
    end
    return false
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

  it("reminds at the site's reminder time: a chat line, the note under the minimap and its Open", function()
    load(runs())
    state.printed = {}
    advance(NOW + 3600 - 1800)
    local all = printed()
    assert.is_truthy(all:find("The Deadmines starts in 30 min (" .. os.date("%H:%M", NOW + 3600) .. "). "
      .. "You organise. [Open]", 1, true))
    local toast = ns.RunToasts.frame()
    assert.is_true(toast.shown)
    assert.are.equal("IN 30 MINUTES", toast.title:GetText())
    assert.is_truthy(toast.text:GetText():find("You invite at start. 2 in.", 1, true))
    assert.is_truthy(clickLink("Open"))
    assert.are.equal("run:r1", addon.db.global.settings.dungeonTree.selected)
    -- Only once.
    state.printed = {}
    advance(NOW + 3600 - 1700)
    assert.is_falsy(printed():find("starts in", 1, true))
  end)

  it("leaves out the note and the line when turned off", function()
    load(runs(), function(g)
      g.settings.runToasts = false
      g.settings.runLines = { reminder = false }
    end)
    state.printed = {}
    advance(NOW + 3600 - 1800)
    assert.is_falsy(printed():find("starts in", 1, true))
    assert.is_nil(ns.RunToasts.frame())
    ns.Settings.option("runLine_reminder").set({}, true)
    assert.is_nil(addon.db.global.settings.runLines.reminder)
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
    assert.is_truthy(printed():find("Discord ping for Ada Lovewell queued. It reaches Discord after /reload. "
      .. "[Reload now]", 1, true))
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

  it("says when a friend is on another character, with Whisper and Invite instead", function()
    load(runs("Player-4619-0000ALT1"))
    state.printed = {}
    advance(NOW + 3600)
    local all = printed()
    assert.is_truthy(all:find("Garraka Doombringer is online on Garraka Doombringer, signed up as Garraka Doombringer. "
      .. "[Whisper] [Invite Garraka Doombringer]", 1, true))
    assert.is_truthy(panelText():find("online, but on Garraka Doombringer (20)", 1, true))
    assert.is_truthy(clickLink("Invite Garraka Doombringer"))
    assert.are.same({ "Garraka Doombringer" }, invited)
  end)

  it("tells everyone else it starts, with Request invite", function()
    load(runs())
    advance(NOW + 7200)
    local toast = ns.RunToasts.frame()
    assert.are.equal("STARTING NOW", toast.title:GetText())
    assert.are.equal("Waiting for Garraka Doombringer's invite", toast.text:GetText()) -- no record: the name
    toast.button:RunScript("OnClick")
    assert.are.same({ "Garraka Doombringer" }, requested)
    assert.is_truthy(printed():find("Wailing Caverns is starting now. Invites go out from Garraka Doombringer. "
      .. "[Request invite]", 1, true))
  end)

  it("announces answers to your run and runs from a friend", function()
    load(runs())
    state.printed = {}
    addon:SendMessage(ns.Messenger.RECEIVED, { t = "RUNANSWER", run = "r1", answer = "maybe", guid = GARRAKA,
      name = "Garraka Doombringer" }, SJAAK, SJAAK_GA)
    local newer = runs()
    newer.updatedAt = NOW
    newer.runs[1].answers[3] = { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "cant", source = "discord" }
    ns.Planner.receive(newer)
    local all = printed()
    assert.is_truthy(all:find("Garraka Doombringer is a maybe for The Deadmines (answered in game).", 1, true))
    assert.is_truthy(all:find("Ada Lovewell can't make The Deadmines (answered on Discord).", 1, true))
    assert.is_truthy(all:find("Runs updated at " .. os.date("%H:%M", NOW) .. ". Type /reload for newer.", 1, true))
  end)
end)
