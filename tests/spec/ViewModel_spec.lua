local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("ViewModel", function()
  local state, ns, addon

  local function load(storedClubId)
    state, ns, addon = helpers.client({ clubId = storedClubId or false }) -- nil: no community
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("links the own character to self and a friend's character by presence", function()
    load("23125681")
    local view = ns.ViewModel.build(addon)
    assert.are.equal(2, #view.people)
    assert.are.same({}, view.unlinked)

    local byTag = {}
    for _, p in ipairs(view.people) do byTag[p.battleTag] = p end
    assert.is_true(byTag["Vestras#1000"].isSelf)
    assert.are.equal("Player-4619-01627852", byTag["Vestras#1000"].currentChar.guid)
    assert.are.equal("Player-4619-01789956", byTag["Solvar#2032"].currentChar.guid)
    assert.are.equal("presence", byTag["Solvar#2032"].chars[1].linkSource)
  end)

  it("after a reload shows the stored record's level when the roster's is behind (CF-123)", function()
    local GARRAKA = "Player-4619-01789956"
    state, ns, addon = helpers.client({ setup = function(s)
      s.clubMembers["23125681"][2].level = 2 -- the game's guild list, stale even after /reload
      s.savedVariables = { global = { people = { ["Solvar#2032"] = { displayName = "Sjaak", version = 500,
        receivedAt = 500, chars = { [GARRAKA] = { name = "Garraka Doombringer", classFile = "MAGE", level = 4,
                                                  updatedAt = 500 } } } } } }
    end })
    local view = ns.ViewModel.build(addon)
    local row
    for _, p in ipairs(view.people) do
      if p.battleTag == "Solvar#2032" then row = p.chars[1] end
    end
    assert.are.equal(GARRAKA, row.guid)
    assert.are.equal(4, row.level)
  end)

  it("shows a friend's character as Unlinked when the friend is gone", function()
    load("23125681")
    table.remove(state.friends, 1) -- Sjaak removed as Battle.net friend
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    local view = ns.ViewModel.build(addon)
    assert.are.equal(1, #view.people)
    assert.are.equal("Garraka Doombringer", view.unlinked[1].name)
  end)

  describe("/cf people", function()
    it("prints people with their characters", function()
      load("23125681")
      state.slash.cf("people")
      assert.are.equal("2 people, 0 unlinked", state.printed[1])
      assert.matches("^Solvar %(Solvar#2032%), online on Garraka Doombringer", state.printed[2])
      assert.matches("^  Garraka Doombringer: level 11, ilvl nil, online, Orgrimmar, seen 0s ago, via presence",
        state.printed[3])
      assert.matches("^Vestras %(Vestras#1000%) %[you%], online on Ves Doombringer", state.printed[4])
      assert.matches("via self$", state.printed[5])
    end)

    it("asks to select a community first", function()
      load(nil)
      state.slash.cf("people")
      assert.are.same({ "No community selected. Select one with /cf settings." }, state.printed)
    end)
  end)
end)
