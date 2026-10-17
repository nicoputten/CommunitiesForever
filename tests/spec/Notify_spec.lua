local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Notify (CF-15)", function()
  local state, ns, addon

  local CLUB = "23125681"
  local NOTICE = "Sjaakovich is online on Garraka Doombringer (Mage 11)"

  -- Sjaak starts offline, so coming online is a real change (not the login baseline).
  local function load(setup)
    state = wowapi.install()
    state.friends[1].gameAccounts[1].isOnline = false
    if setup then setup(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
    -- Garraka was seen online before (presence link), so Sjaak is linked in the community.
    addon.db.global.presence["Player-4619-01789956"] = { battleTag = "Sjaakovich#2232", lastSeen = 1 }
    state.printed = {}
  end

  local function sjaakOnline(guid, name)
    local ga = state.friends[1].gameAccounts[1]
    ga.isOnline = true
    if guid then ga.playerGuid, ga.characterName = guid, name end
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_ONLINE")
    wowapi.runTimers(state)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("formats the notice, leaving out unknown parts", function()
    load()
    assert.are.equal("Sjaak is online on Garraka (Mage 11)",
      ns.Format.loginNotice("Sjaak", { name = "Garraka", className = "Mage", level = 11 }))
    assert.are.equal("Sjaak is online on Garraka", ns.Format.loginNotice("Sjaak", { name = "Garraka" }))
  end)

  it("tells when a linked friend comes online", function()
    load()
    sjaakOnline()
    assert.are.same({ NOTICE }, state.printed)
  end)

  it("tells when a linked friend switches character", function()
    load()
    sjaakOnline()
    state.serverTime = state.serverTime + 60
    sjaakOnline("Player-4619-0000ALT1", "Alt Doombringer")
    assert.are.equal("Sjaakovich is online on Alt Doombringer (Mage 11)", state.printed[2])
  end)

  it("does not repeat for the same person within 30 s", function()
    load()
    sjaakOnline()
    state.friends[1].gameAccounts[1].isOnline = false
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
    wowapi.runTimers(state)
    state.serverTime = state.serverTime + 20
    sjaakOnline()
    assert.are.equal(1, #state.printed)
    state.friends[1].gameAccounts[1].isOnline = false
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
    wowapi.runTimers(state)
    state.serverTime = state.serverTime + 11
    sjaakOnline()
    assert.are.equal(2, #state.printed)
  end)

  it("stays quiet for friends who are not linked in the community", function()
    load(function(s) s.clubMembers[CLUB] = { s.clubMembers[CLUB][1] } end) -- Garraka not a member
    addon.db.global.presence = {}
    sjaakOnline()
    assert.are.same({}, state.printed)
  end)

  it("stays quiet for friends already online at login", function()
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
    assert.are.same({}, state.printed)
  end)

  it("can be switched off in settings", function()
    load()
    local option = state.options.args.notifications
    assert.is_true(option.get())
    option.set({}, false)
    sjaakOnline()
    assert.are.same({}, state.printed)
  end)
end)
