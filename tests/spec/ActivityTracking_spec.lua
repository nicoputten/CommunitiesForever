local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("dungeon, raid and battleground runs (CF-23)", function()
  local state, ns, addon
  local TODAY = 20744 -- mock realm date 2026-10-18
  local CLUB = "23125681"
  local myGuid, friendGuid
  local DEADMINES = { name = "Deadmines", type = "party", instanceID = 36 }
  local WSG = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
  local OUTSIDE = { name = "Eastern Kingdoms", type = "none", instanceID = 0 }

  local function load()
    state = wowapi.install()
    state.serverTime = 10000
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
    -- The mock's first community member is the player, the second an online Battle.net friend.
    myGuid = state.clubMembers[CLUB][1].guid
    friendGuid = state.clubMembers[CLUB][2].guid
  end

  local function enter(instance)
    state.instance = instance
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, false)
  end

  local function runs()
    local feed = addon.db.global.self.feed
    local entry = feed and feed[TODAY] and feed[TODAY][myGuid]
    return entry and entry.runs
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("records a dungeon run with a boss after 10 minutes, with community companions", function()
    load()
    enter(DEADMINES)
    state.setGroup({ friendGuid, "Player-1-STRANGER" })
    wowapi.fireEvent(state, "GROUP_ROSTER_UPDATE")
    state.serverTime = 10300
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 1)
    wowapi.fireEvent(state, "BOSS_KILL", 1001, "Boss") -- the same kill, counted once
    state.serverTime = 10700
    wowapi.fireEvent(state, "PLAYER_LEAVING_WORLD")
    enter(OUTSIDE)
    assert.are.same({ { name = "Deadmines", kind = "party", bosses = 1, with = { friendGuid } } }, runs())
    assert.is_nil(addon.db.global.runs[myGuid])
  end)

  it("does not record a wipe or a short visit", function()
    load()
    enter(DEADMINES)
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 0) -- wipe
    state.serverTime = 11000
    enter(OUTSIDE)
    assert.is_nil(runs())

    enter(DEADMINES)
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 1)
    state.serverTime = 11300
    enter(OUTSIDE)
    assert.is_nil(runs())
  end)

  it("keeps the run over a reload and counts the time until logout", function()
    load()
    enter(DEADMINES)
    wowapi.fireEvent(state, "BOSS_KILL", 1001, "Boss")
    state.serverTime = 10900
    wowapi.fireEvent(state, "PLAYER_LOGOUT")
    local saved = addon.db.global
    wowapi.uninstall()

    -- Next login, hours later and outside: the run ends at the logout (15 min inside), not now.
    state = wowapi.install()
    state.serverTime = 30000
    state.instance = OUTSIDE
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    for k, v in pairs(saved) do addon.db.global[k] = v end
    addon:OnEnable()
    assert.are.equal(1, #runs())
    assert.are.equal("Deadmines", runs()[1].name)
  end)

  it("records a battleground when the match ends, won by your faction's team", function()
    load()
    enter(WSG)
    state.bgWinner = nil
    wowapi.fireEvent(state, "UPDATE_BATTLEFIELD_STATUS", 1) -- still running
    assert.is_nil(addon.db.global.runs[myGuid].ended)
    wowapi.fireEvent(state, "PVP_MATCH_COMPLETE", 0, 900) -- Horde (the mock player) won
    enter(OUTSIDE)
    assert.are.same({ { name = "Warsong Gulch", kind = "pvp", won = true, with = {} } }, runs())
  end)

  it("falls back to GetBattlefieldWinner and the battleground team", function()
    load()
    enter(WSG)
    state.bgWinner, state.bgTeam = 1, 0
    wowapi.fireEvent(state, "UPDATE_BATTLEFIELD_STATUS", 1)
    enter(OUTSIDE)
    assert.is_false(runs()[1].won)
  end)

  it("does not record a battleground left early", function()
    load()
    enter(WSG)
    state.serverTime = 12000
    enter(OUTSIDE)
    assert.is_nil(runs())
  end)

  it("works without the unverified instance APIs", function()
    state = wowapi.install({ missing = { GetInstanceInfo = true, GetNumGroupMembers = true, IsInRaid = true,
                                         GetBattlefieldWinner = true, GetBattlefieldArenaFaction = true } })
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon:OnEnable()
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, false)
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 1)
    assert.is_nil(ns.ActivityTracker.current())
  end)

  it("prints the trace with /cf activity debug, also after a reload", function()
    load()
    addon:OnSlashCommand("activity debug")
    assert.is_true(addon.db.global.settings.activityDebug)
    state.printed = {}
    enter(DEADMINES)
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 1)
    local text = table.concat(state.printed, "\n")
    assert.is_truthy(text:find("instance: Deadmines, party, 36", 1, true))
    assert.is_truthy(text:find("entered Deadmines (party): run started", 1, true))
    assert.is_truthy(text:find("ENCOUNTER_END: 1001, Boss, 1, 5, 1", 1, true))
    assert.is_truthy(text:find("boss killed (encounter 1001): 1 bosses", 1, true))
    state.printed = {}
    enter(OUTSIDE)
    assert.is_truthy(table.concat(state.printed, "\n"):find("not recorded, 0 min inside, needs 10", 1, true))

    addon:OnSlashCommand("activity")
    addon:OnSlashCommand("activity debug")
    assert.is_nil(addon.db.global.settings.activityDebug)
  end)

  it("shows the run in progress with /cf activity", function()
    load()
    enter(DEADMINES)
    state.serverTime = 10600
    state.printed = {}
    addon:OnSlashCommand("activity")
    assert.is_truthy(state.printed[1]:find("In Deadmines (party) for 10 min, 0 bosses killed.", 1, true))
  end)

  it("shows a shared line in the Activity tab", function()
    load()
    enter(DEADMINES)
    state.setGroup({ friendGuid })
    wowapi.fireEvent(state, "GROUP_ROSTER_UPDATE")
    wowapi.fireEvent(state, "ENCOUNTER_END", 1001, "Boss", 1, 5, 1)
    state.serverTime = 10700
    enter(OUTSIDE)
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    local texts = {}
    local function walk(widget)
      for _, child in ipairs(widget.children) do
        if child.text then texts[#texts + 1] = child.text end
        walk(child)
      end
    end
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" then walk(w) end
    end
    local all = table.concat(texts, "\n")
    assert.is_truthy(all:find("|cffa0a0a0together|r", 1, true))
    assert.is_truthy(all:find("   ran Deadmines", 1, true))
  end)
end)
