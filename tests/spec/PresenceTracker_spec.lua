local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("PresenceTracker", function()
  local state, ns, addon, Tracker

  local SJAAK = "Solvar#2032"
  local GARRAKA = "Player-4619-01789956"
  local CLUB = "23125681" -- the mock's community: Ves (you) and Garraka (CF-89: Sjaak belongs)

  local function load(setup, clubId)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    Tracker = ns.PresenceTracker
    addon = state.addon
    addon:OnInitialize()
    if clubId ~= false then addon.db.global.settings.clubId = clubId or CLUB end
    addon:OnEnable()
  end

  local function sent(message)
    return wowapi.sentMessages(state, message)
  end

  local function sjaakAccounts()
    return state.friends[1].gameAccounts
  end

  -- Fires a BNet event and runs the 1 s debounce.
  local function bnet(event)
    wowapi.fireEvent(state, event)
    wowapi.runTimers(state)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("tracks only Forever game accounts", function()
    load()
    assert.are.same({ [SJAAK] = { guid = GARRAKA, name = "Garraka Doombringer", className = "Mage", level = 11,
                                  gameAccountID = 5 } }, Tracker.online())
    assert.are.same({ [SJAAK] = true, ["Retailer#1111"] = true, ["Offline#3333"] = true }, Tracker.friends())
  end)

  it("maps gameAccountID to BattleTag for Forever accounts only", function()
    load()
    assert.are.equal(SJAAK, Tracker.battleTagFor(5))
    assert.is_nil(Tracker.battleTagFor(6)) -- Battle.net app
    assert.is_nil(Tracker.battleTagFor(7)) -- other WoW project
  end)

  it("writes presence links with lastSeen", function()
    load()
    assert.are.same({ [GARRAKA] = { battleTag = SJAAK, lastSeen = 1000 } }, addon.db.global.presence)
  end)

  describe("CF-89 members only", function()
    it("writes no presence links without a selected community", function()
      load(nil, false)
      assert.are.same({}, addon.db.global.presence)
      assert.is_not_nil(Tracker.online()[SJAAK]) -- still seen, just not stored
    end)

    it("does not link a friend with no character in the community", function()
      load(function(s)
        s.friends[1].gameAccounts[1].playerGuid = "Player-4619-0000OUT1"
      end)
      assert.are.same({}, addon.db.global.presence)
    end)

    it("links the alt of a friend who belongs through an earlier link", function()
      load(function(s)
        s.friends[1].gameAccounts[1].playerGuid = "Player-4619-0000ALT1"
      end)
      assert.are.same({}, addon.db.global.presence)
      addon.db.global.presence[GARRAKA] = { battleTag = SJAAK, lastSeen = 1 }
      sjaakAccounts()[1].characterLevel = 12
      bnet("BN_FRIEND_INFO_CHANGED")
      assert.are.equal(SJAAK, addon.db.global.presence["Player-4619-0000ALT1"].battleTag)
    end)
  end)

  it("does not announce friends already online at login", function()
    load()
    assert.are.same({}, sent(Tracker.FRIEND_ONLINE))
    assert.are.equal(1, #sent(Tracker.UPDATED))
  end)

  for _, event in ipairs({ "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
                           "BN_CONNECTED" }) do
    it("refreshes on " .. event .. " after a 1 s debounce", function()
      load()
      sjaakAccounts()[1].isOnline = false
      wowapi.fireEvent(state, event)
      assert.is_not_nil(Tracker.online()[SJAAK]) -- not yet
      assert.are.equal(1, state.timers[#state.timers].seconds)
      wowapi.runTimers(state)
      assert.is_nil(Tracker.online()[SJAAK])
    end)
  end

  it("announces a friend going offline", function()
    load()
    sjaakAccounts()[1].isOnline = false
    bnet("BN_FRIEND_ACCOUNT_OFFLINE")
    assert.are.same({ { SJAAK, GARRAKA } }, sent(Tracker.FRIEND_OFFLINE))
    assert.is_nil(Tracker.battleTagFor(5))
  end)

  it("announces a friend coming online", function()
    load(function(s) s.friends[1].gameAccounts[1].isOnline = false end)
    sjaakAccounts()[1].isOnline = true
    state.serverTime = 2000
    bnet("BN_FRIEND_ACCOUNT_ONLINE")
    assert.are.same({ { SJAAK, GARRAKA } }, sent(Tracker.FRIEND_ONLINE))
    assert.are.same({ battleTag = SJAAK, lastSeen = 2000 }, addon.db.global.presence[GARRAKA])
  end)

  it("announces a character switch and links the new character", function()
    load()
    local ga = sjaakAccounts()[1]
    ga.playerGuid, ga.characterName = "Player-4619-0000ALT1", "Alt Doombringer"
    bnet("BN_FRIEND_INFO_CHANGED")
    assert.are.same({ { SJAAK, "Player-4619-0000ALT1", GARRAKA } }, sent(Tracker.FRIEND_SWITCHED))
    assert.are.equal(SJAAK, addon.db.global.presence["Player-4619-0000ALT1"].battleTag)
    assert.are.equal(SJAAK, addon.db.global.presence[GARRAKA].battleTag) -- old link kept
  end)

  it("sends UPDATED on a level change but no online/switch/offline", function()
    load()
    sjaakAccounts()[1].characterLevel = 12
    bnet("BN_FRIEND_INFO_CHANGED")
    assert.are.equal(2, #sent(Tracker.UPDATED))
    assert.are.same({}, sent(Tracker.FRIEND_SWITCHED))
    assert.are.equal(12, Tracker.online()[SJAAK].level)
  end)

  it("does not send UPDATED when nothing changed", function()
    load()
    bnet("BN_FRIEND_INFO_CHANGED")
    assert.are.equal(1, #sent(Tracker.UPDATED))
  end)

  it("sends UPDATED when the friend list changes", function()
    load()
    table.insert(state.friends, { battleTag = "New#4444", gameAccounts = {} })
    bnet("BN_FRIEND_INFO_CHANGED")
    assert.are.equal(2, #sent(Tracker.UPDATED))
    assert.is_true(Tracker.friends()["New#4444"])
  end)

  it("falls back to \"WoW\" without BNET_CLIENT_WOW", function()
    load(function() _G.BNET_CLIENT_WOW = nil end)
    assert.is_not_nil(Tracker.online()[SJAAK])
  end)

  describe("/cf friends", function()
    it("prints friends in Forever and presence links", function()
      load()
      state.slash.cf("friends")
      assert.are.same({
        "3 Battle.net friend(s), 1 online in Forever",
        "Solvar#2032: Garraka Doombringer (Mage 11), game account 5, Player-4619-01789956",
        "Presence links: 1",
        "  Player-4619-01789956 -> Solvar#2032, seen 0s ago",
      }, state.printed)
    end)
  end)
end)
