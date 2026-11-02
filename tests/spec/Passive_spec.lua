local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- Without a community on the account or the character the addon stays passive: no setup, sync, notices
-- or minimap button. Joining a community starts everything.
describe("passive without a community", function()
  local state, ns, addon

  local function load(clubs)
    state = wowapi.install()
    state.clubs = clubs
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon:OnEnable()
    wowapi.runTimers(state)
  end

  local function join()
    table.insert(state.clubs, { clubId = "555", name = "New Friends", clubType = 1 })
    wowapi.fireEvent(state, "CLUB_ADDED", "555")
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("shows no setup, no minimap button and sends nothing", function()
    load({})
    assert.is_true(ns.CommunitySelection.passive())
    assert.is_false(ns.Setup.isShown())
    assert.is_false(state.minimapIcon.shown)
    assert.are.same({}, state.bnSent)
  end)

  it("stays passive in a guild only", function()
    load({ { clubId = "999", name = "Some Guild", clubType = 2 } })
    assert.is_true(ns.CommunitySelection.passive())
    assert.is_false(ns.Setup.isShown())
  end)

  it("explains how to join in the window", function()
    load({})
    assert.are.equal(ns.Format.PASSIVE_TEXT,
      ns.Format.emptyState({ people = {}, unlinked = {} }, { passive = ns.CommunitySelection.passive() }))
  end)

  it("starts the setup, the minimap button and sync on joining a community", function()
    load({})
    join()
    assert.is_false(ns.CommunitySelection.passive())
    assert.are.equal("555", addon.db.global.settings.clubId)
    assert.is_true(ns.Setup.isShown())
    assert.is_true(state.minimapIcon.shown)
    assert.is_true(state.minimapIcon.compartment) -- CF-66: in the addon compartment with the button
    assert.is_true(#state.bnSent > 0) -- HELLO to the Battle.net friends online
  end)

  it("keeps the minimap button hidden after joining when the setting hides it", function()
    load({})
    ns.Minimap.setShown(false)
    join()
    assert.is_false(state.minimapIcon.shown)
    assert.is_false(state.minimapIcon.compartment)
  end)

  -- CF-66: the designer's shield, shipped with the addon (media/textures), as the button's icon.
  it("shows the addon's shield on the minimap button", function()
    load({})
    assert.are.equal("Interface\\AddOns\\CommunitiesForever\\media\\textures\\mapicon.tga",
      state.minimapIcon.object.icon)
    local f = assert(io.open("media/textures/mapicon.tga", "rb"))
    local header = f:read(18)
    f:close()
    -- An uncompressed 32-bit TGA (type 2) of 64 x 64 with an alpha channel.
    assert.are.same({ 2, 64, 64, 32 }, { header:byte(3), header:byte(13), header:byte(15), header:byte(17) })
  end)

  it("is active with a stored community, also on a character outside it", function()
    state, ns, addon = helpers.client({ setup = function(s)
      s.clubs = {}
    end })
    assert.is_false(ns.CommunitySelection.passive())
    assert.is_true(state.minimapIcon.shown)
  end)
end)
