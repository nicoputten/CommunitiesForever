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
                      presence = 1, raceID = 2, faction = 0 }, Tracker.members()[GARRAKA])
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
