local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-91: friends coming online or switching character bring no chat line (CF-15's notice is gone).
describe("Quiet chat (CF-91)", function()
  local state, ns, addon

  local CLUB = "23125681"

  -- Sjaak starts offline, so coming online is a real change (not the login baseline).
  local function load()
    state, ns, addon = helpers.client({ clubId = CLUB, setup = function(s)
      s.friends[1].gameAccounts[1].isOnline = false
    end })
    -- Garraka was seen online before (presence link), so Sjaak is linked in the community.
    addon.db.global.presence["Player-4619-01789956"] = { battleTag = "Sjaakovich#2232", lastSeen = 1 }
    state.printed = {}
    state.serverTime = state.serverTime + 60 -- well past the login baseline
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

  it("says nothing when a linked friend comes online or switches character", function()
    load()
    sjaakOnline()
    assert.are.same({}, state.printed)
    state.serverTime = state.serverTime + 60
    sjaakOnline("Player-4619-0000ALT1", "Alt Doombringer")
    assert.are.same({}, state.printed)
  end)

  it("has no switches for the removed chat lines, and keeps their stored values", function()
    load()
    local args = ns.Settings.options().args
    for _, key in ipairs({ "notifications", "levelUps", "doomsdayChat", "runLine_reminder", "runLine_updated" }) do
      assert.is_nil(args[key], key)
    end
    assert.is_true(addon.db.global.settings.notifications) -- rule 8: left alone, unused
  end)
end)
