local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("community chat (CF-25)", function()
  local state, ns, addon, myGuid, friendGuid
  local CHANNEL = "Community:23125681:1"

  local function load()
    state, ns, addon = helpers.client()
    myGuid = state.clubMembers["23125681"][1].guid
    friendGuid = state.clubMembers["23125681"][2].guid
  end

  -- CHAT_MSG_COMMUNITIES_CHANNEL: arg 9 channel name, arg 12 sender GUID (V38).
  local function message(senderGuid, channel)
    wowapi.fireEvent(state, "CHAT_MSG_COMMUNITIES_CHANNEL", "|Kx1|k", "Sender Name", "", "6. " .. CHANNEL, "", "",
      0, 6, channel or CHANNEL, 0, 0, senderGuid)
  end

  local function option(name) return ns.Settings.options().args.chat.args[name] end

  after_each(function()
    wowapi.uninstall()
  end)

  it("colors the community channel purple on login, and in the color you pick", function()
    load()
    assert.are.same({ r = 0.75, g = 0.5, b = 1 }, state.chatColors.CHANNEL6)
    option("color").set({}, 0.2, 0.4, 0.6)
    assert.are.same({ r = 0.2, g = 0.4, b = 0.6 }, state.chatColors.CHANNEL6)
    assert.are.same({ 0.2, 0.4, 0.6 }, { option("color").get() })
    option("resetColor").func()
    assert.are.same({ r = 0.75, g = 0.5, b = 1 }, state.chatColors.CHANNEL6)
  end)

  it("waits for the channel when the client has not joined it yet", function()
    state, ns, addon = helpers.client({ setup = function(s)
      s.chatChannels = {}
    end })
    assert.is_nil(state.chatColors.CHANNEL6)
    state.chatChannels[CHANNEL] = 6
    wowapi.runTimers(state)
    assert.is_truthy(state.chatColors.CHANNEL6)
  end)

  it("flashes tabs with the community chat for others' messages, not your own", function()
    load()
    message(friendGuid)
    assert.are.same({}, state.flashed) -- General shows it but is the selected tab
    option("createTab").func()
    message(friendGuid)
    assert.are.same({ 3 }, state.flashed) -- the new Community tab
    message(myGuid)
    message(friendGuid, "Community:999:1")
    assert.are.same({ 3 }, state.flashed)
    assert.are.same({}, state.sounds)

    option("sound").set({}, true)
    message(friendGuid)
    assert.are.same({ 3081 }, state.sounds)
    option("alert").set({}, false)
    message(friendGuid)
    assert.are.equal(2, #state.flashed)
  end)

  it("creates the Community tab once per character", function()
    load()
    option("createTab").func()
    local tab = state.chatWindows[3]
    assert.are.equal(ns.CommunityChat.tabName(), tab.name)
    assert.are.same({ CHANNEL }, tab.channels)
    assert.is_true(addon.db.global.settings.chatTab[myGuid])
    option("createTab").func()
    assert.are.equal(3, #state.chatWindows)
    assert.is_truthy(state.printed[#state.printed]:find("already has", 1, true))
  end)

  it("removes the community chat from General only when a Community tab exists", function()
    load()
    option("keepGeneral").set({}, false)
    assert.are.same({ CHANNEL }, state.chatWindows[1].channels) -- no tab yet: keep it
    option("createTab").func()
    assert.are.same({}, state.chatWindows[1].channels)
    option("keepGeneral").set({}, true)
    assert.are.same({ CHANNEL }, state.chatWindows[1].channels)
  end)
end)
