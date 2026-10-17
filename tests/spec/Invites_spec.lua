local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Invites (CF-21)", function()
  local state, ns, addon

  local CLUB = "23125681"
  local SJAAK = "Sjaakovich#2232"
  local LINK = "https://blizzard.com/invite/AbC123xyz"

  local function load(setup)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
  end

  local function settle()
    for _ = 1, 100 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  -- This character is not a member: the club list only has another community.
  local function asNonMember()
    state.clubs = { { clubId = "777", name = "Other Friends", clubType = 1 } }
    wowapi.fireEvent(state, "CLUB_UPDATED", "777")
    settle()
  end

  local function texts()
    local list = {}
    local function walk(widget)
      for _, child in ipairs(widget.children) do
        if child.text then list[#list + 1] = child.text end
        walk(child)
      end
    end
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "TreeGroup" then walk(w) end
    end
    return list
  end

  local function joinButton()
    for i = #state.guiWidgets, 1, -1 do
      local w = state.guiWidgets[i]
      if w.type == "Button" and w.text and w.text:find("^Join ") then return w end
    end
  end

  after_each(function()
    wowapi.uninstall()
  end)

  describe("setting", function()
    it("is offered to owners, leaders and moderators only", function()
      load()
      assert.is_false(state.options.args.inviteLink.hidden()) -- Ves is the owner (role 1)
      state.clubMembers[CLUB][1].role = 4
      wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", CLUB, 1)
      settle()
      assert.is_true(state.options.args.inviteLink.hidden())
    end)

    it("stores the code, bumps the version and sends it with the own record", function()
      load()
      settle()
      local before = addon.db.global.self.version
      state.serverTime = 5000
      state.options.args.inviteLink.set({}, LINK)
      assert.are.same({ clubId = CLUB, code = "AbC123xyz", setAt = 5000 }, addon.db.global.self.invite)
      assert.is_true(addon.db.global.self.version > before)
      assert.are.equal("AbC123xyz", state.options.args.inviteLink.get())
      local record = ns.Merge.outgoingRecord(addon.db.global.self)
      assert.are.same({ clubId = CLUB, code = "AbC123xyz", setAt = 5000 }, record.invite)
    end)

    it("explains invalid input and clears with empty input", function()
      load()
      state.options.args.inviteLink.set({}, "hello world")
      assert.are.same({ "That doesn't look like a community invite link or code." }, state.printed)
      state.options.args.inviteLink.set({}, LINK)
      state.options.args.inviteLink.set({}, "")
      assert.is_nil(addon.db.global.self.invite)
    end)
  end)

  describe("join button", function()
    local function withFriendInvite()
      load()
      addon.db.global.people[SJAAK] = { version = 10, displayName = "Sjaak", chars = {},
                                        invite = { clubId = CLUB, code = "AbC123xyz", setAt = 900 } }
      asNonMember()
      ns.MainFrame.toggle()
    end

    it("shows on a character outside the community when an invite is known", function()
      withFriendInvite()
      assert.matches("isn't a member", texts()[1])
      assert.are.equal("Join Forever Friends", joinButton().text)
    end)

    it("is not shown without an invite for the community", function()
      load()
      asNonMember()
      ns.MainFrame.toggle()
      assert.is_nil(joinButton())
    end)

    it("redeems the code and shows the community once joined", function()
      withFriendInvite()
      joinButton():Fire("OnClick")
      assert.are.same({ "AbC123xyz" }, state.redeemed)
      settle()
      -- The game adds the community for this character.
      state.clubs = { { clubId = CLUB, name = "Forever Friends", clubType = 1 } }
      wowapi.fireEvent(state, "CLUB_ADDED", CLUB)
      settle()
      assert.are.equal(CLUB, ns.CommunitySelection.active())
      assert.is_nil(ns.Invites.joinState())
    end)

    it("says who to ask when joining did not work", function()
      withFriendInvite()
      joinButton():Fire("OnClick")
      settle() -- 10 s pass without the community showing up
      local found = false
      for _, text in ipairs(texts()) do
        if text == "Joining didn't work. The invite link may have expired. Ask Sjaak for a new one." then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it("explains when the game has no invite API", function()
      load()
      _G.C_Club.RedeemTicket = nil
      addon.db.global.people[SJAAK] = { version = 10, chars = {},
                                        invite = { clubId = CLUB, code = "AbC123xyz", setAt = 900 } }
      asNonMember()
      ns.MainFrame.toggle()
      joinButton():Fire("OnClick")
      settle()
      local found = false
      for _, text in ipairs(texts()) do
        if text:find("not possible in this version of the game", 1, true) then found = true end
      end
      assert.is_true(found)
    end)
  end)
end)
