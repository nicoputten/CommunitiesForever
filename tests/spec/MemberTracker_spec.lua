local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("MemberTracker", function()
  local state, ns, addon, Tracker

  local CLUB = "23125681"
  local VES = "Player-4619-01627852"
  local GARRAKA = "Player-4619-01789956"

  local function load(storedClubId)
    state = wowapi.install()
    ns = helpers.loadAddon()
    Tracker = ns.MemberTracker
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = storedClubId
    addon:OnEnable()
  end

  local function updates()
    return #wowapi.sentMessages(state, Tracker.UPDATED)
  end

  local function members(clubId)
    return state.clubMembers[clubId]
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("has no members without a selection", function()
    load(nil)
    assert.are.same({}, Tracker.members())
    assert.are.same({}, state.focusedClubs)
  end)

  it("focuses and reads the stored community on enable", function()
    load(CLUB)
    assert.are.same({ CLUB }, state.focusedClubs)
    assert.are.same({ name = "Garraka Doombringer", classID = 8, level = 11, zone = "Orgrimmar",
                      presence = 1, raceID = 2, faction = 0, role = 4 }, Tracker.members()[GARRAKA])
    assert.is_not_nil(Tracker.members()[VES])
    assert.are.equal(1, updates())
  end)

  it("focuses and reads a newly selected community", function()
    load(nil)
    ns.CommunitySelection.select(CLUB)
    assert.are.same({ CLUB }, state.focusedClubs)
    assert.is_not_nil(Tracker.members()[VES])
  end)

  it("empties the members when the selection is cleared", function()
    load(CLUB)
    ns.CommunitySelection.select(nil)
    assert.are.same({}, Tracker.members())
  end)

  for _, event in ipairs({ "CLUB_MEMBERS_UPDATED", "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED",
                           "CLUB_MEMBER_PRESENCE_UPDATED", "CLUB_MEMBER_UPDATED" }) do
    it("refreshes after " .. event .. ", debounced 1 s", function()
      load(CLUB)
      table.remove(members(CLUB), 2)
      wowapi.fireEvent(state, event, CLUB, 2)
      assert.is_not_nil(Tracker.members()[GARRAKA]) -- not yet
      assert.are.equal(1, state.timers[#state.timers].seconds)
      wowapi.runTimers(state)
      assert.is_nil(Tracker.members()[GARRAKA])
      assert.are.equal(2, updates())
    end)
  end

  it("refreshes once for a burst of events", function()
    load(CLUB)
    members(CLUB)[2].presence = 3
    wowapi.fireEvent(state, "CLUB_MEMBER_PRESENCE_UPDATED", CLUB, 2, 3)
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", CLUB, 2)
    wowapi.runTimers(state)
    assert.are.equal(3, Tracker.members()[GARRAKA].presence)
    assert.are.equal(2, updates())
  end)

  it("ignores events for other clubs", function()
    load(CLUB)
    local timers = #state.timers -- Sync may have a HELLO pending
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", "999")
    assert.are.equal(timers, #state.timers)
  end)

  it("does not announce when nothing changed", function()
    load(CLUB)
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    wowapi.runTimers(state)
    assert.are.equal(1, updates())
  end)

  it("saves the last zone of online members", function()
    load(CLUB)
    assert.are.same({ zone = "Orgrimmar", seenAt = 1000 }, addon.db.global.locations[GARRAKA])
  end)

  it("records when the member map last changed", function()
    load(CLUB)
    assert.are.equal(1000, Tracker.changedAt())
    state.serverTime = 1050
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    wowapi.runTimers(state)
    assert.are.equal(1000, Tracker.changedAt()) -- no change
    members(CLUB)[2].zone = "Durotar"
    wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", CLUB, 2)
    wowapi.runTimers(state)
    assert.are.equal(1050, Tracker.changedAt())
  end)

  it("picks up member data that arrives after focusing", function()
    local later
    state = wowapi.install()
    later = state.clubMembers[CLUB]
    state.clubMembers[CLUB] = nil -- not loaded yet
    ns = helpers.loadAddon()
    Tracker = ns.MemberTracker
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
    assert.are.same({}, Tracker.members())

    state.clubMembers[CLUB] = later
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    wowapi.runTimers(state)
    assert.is_not_nil(Tracker.members()[VES])
  end)

  it("clears members when the selected club is removed", function()
    load(CLUB)
    wowapi.fireEvent(state, "CLUB_REMOVED", CLUB)
    wowapi.runTimers(state)
    assert.are.same({}, Tracker.members())
  end)

  describe("the roster (CF-89)", function()
    local function loadWith(storedClubId, prepare)
      state = wowapi.install()
      if prepare then prepare(state) end
      ns = helpers.loadAddon()
      Tracker = ns.MemberTracker
      addon = state.addon
      addon:OnInitialize()
      addon.db.global.settings.clubId = storedClubId
      if state.stored then state.stored(addon.db.global) end
      addon:OnEnable()
    end

    it("stores the members as name and time seen, replaced as a whole on every update", function()
      load(CLUB)
      assert.are.same({ [VES] = { name = "Ves Doombringer", seenAt = 1000 },
                        [GARRAKA] = { name = "Garraka Doombringer", seenAt = 1000 } }, addon.db.global.members)
      table.remove(members(CLUB), 2)
      state.serverTime = 1100
      wowapi.fireEvent(state, "CLUB_MEMBER_REMOVED", CLUB, 2)
      wowapi.runTimers(state)
      assert.are.same({ [VES] = { name = "Ves Doombringer", seenAt = 1100 } }, addon.db.global.members)
    end)

    it("is empty without a selected community", function()
      load(nil)
      assert.are.same({}, addon.db.global.members)
      assert.are.same({}, Tracker.roster())
      assert.is_false(Tracker.belongs("Sjaakovich#2232"))
    end)

    it("is not replaced from a member list that does not list you yet (login)", function()
      loadWith(CLUB, function(s)
        table.remove(s.clubMembers[CLUB], 1) -- only Garraka loaded so far
        s.stored = function(global) global.members = { [VES] = { name = "Ves Doombringer", seenAt = 1 } } end
      end)
      assert.are.same({ [VES] = { name = "Ves Doombringer", seenAt = 1 } }, addon.db.global.members)
    end)

    it("keeps the last roster on a character outside the community", function()
      loadWith(CLUB, function(s)
        s.clubs = { { clubId = "999", name = "My Guild", clubType = 2 } } -- this character is in another one only
        s.stored = function(global)
          global.members = { [GARRAKA] = { name = "Garraka Doombringer", seenAt = 1 } }
          global.people["Sjaakovich#2232"] = { version = 1, chars = { [GARRAKA] = { name = "Garraka Doombringer" } } }
        end
      end)
      assert.is_nil(ns.CommunitySelection.active())
      assert.is_not_nil(addon.db.global.members[GARRAKA])
      assert.is_true(Tracker.belongs("Sjaakovich#2232"))
      assert.is_not_nil(addon.db.global.people["Sjaakovich#2232"])
    end)

    it("is not known yet on the first login before the members load, so nobody is dropped", function()
      loadWith(CLUB, function(s)
        s.later = s.clubMembers[CLUB]
        s.clubMembers[CLUB] = nil
        s.stored = function(global)
          global.people["Out#1"] = { version = 1, chars = { ["Player-1-0000OUT1"] = { name = "Out Example" } } }
          global.presence["Player-1-0000OUT1"] = { battleTag = "Out#1", lastSeen = 1 }
        end
      end)
      assert.is_nil(Tracker.roster())
      assert.is_nil(Tracker.belongs("Out#1"))
      assert.is_not_nil(addon.db.global.people["Out#1"])
      -- The members load: the one-time cleanup removes the friend outside the community.
      state.clubMembers[CLUB] = state.later
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
      wowapi.runTimers(state)
      assert.is_false(Tracker.belongs("Out#1"))
      assert.is_nil(addon.db.global.people["Out#1"])
      assert.is_nil(addon.db.global.presence["Player-1-0000OUT1"])
    end)

    it("cleans up stored data from before CF-89 once the members are known", function()
      loadWith(CLUB, function(s)
        s.stored = function(global)
          global.people["Sjaakovich#2232"] = { version = 1, chars = { ["Player-4619-0000ALT1"] = { name = "Alt" } } }
          global.people["Out#1"] = { version = 1, chars = { ["Player-1-0000OUT1"] = { name = "Out Example" } } }
          global.people["aid:aaaaaaaaaaaa"] = { version = 1, chars = { [GARRAKA] = { name = "Garraka Doombringer" } } }
          global.presence[GARRAKA] = { battleTag = "Sjaakovich#2232", lastSeen = 1 }
          global.presence["Player-4619-0000ALT1"] = { battleTag = "Sjaakovich#2232", lastSeen = 1 }
          global.presence["Player-1-0000OUT1"] = { battleTag = "Out#1", lastSeen = 1 }
        end
      end)
      local g = addon.db.global
      assert.is_not_nil(g.people["Sjaakovich#2232"]) -- belongs through the link of Garraka, even on an alt
      assert.is_not_nil(g.people["aid:aaaaaaaaaaaa"])
      assert.is_nil(g.people["Out#1"])
      assert.is_not_nil(g.presence["Player-4619-0000ALT1"])
      assert.is_nil(g.presence["Player-1-0000OUT1"])
    end)

    it("is not known after choosing another community until its members load", function()
      load(CLUB)
      ns.CommunitySelection.select("777")
      assert.is_nil(Tracker.roster())
      state.clubMembers["777"] = { members(CLUB)[1] }
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", "777")
      wowapi.runTimers(state)
      assert.are.same({ [VES] = { name = "Ves Doombringer", seenAt = 1000 } }, Tracker.roster())
    end)
  end)

  describe("/cf members", function()
    it("prints members sorted by name", function()
      load(CLUB)
      state.slash.cf("members")
      assert.are.equal("Forever Friends: 2 member(s), last change 0s ago", state.printed[1])
      assert.matches("^Garraka Doombringer: level 11", state.printed[2])
      assert.matches("^Ves Doombringer: level 11", state.printed[3])
    end)

    it("asks to select a community first", function()
      load(nil)
      state.slash.cf("members")
      assert.are.same({ "No community selected. Select one with /cf settings." }, state.printed)
    end)
  end)
end)
