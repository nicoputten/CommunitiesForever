local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("ViewModel", function()
  local state, ns, addon

  local function load(storedClubId)
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = storedClubId
    addon:OnEnable()
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
    assert.are.equal("Player-4619-01789956", byTag["Sjaakovich#2232"].currentChar.guid)
    assert.are.equal("presence", byTag["Sjaakovich#2232"].chars[1].linkSource)
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
      assert.matches("^Sjaakovich %(Sjaakovich#2232%), online on Garraka Doombringer", state.printed[2])
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
