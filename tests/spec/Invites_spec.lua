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

  local function texts() return ns.FriendsTab.cardTexts() end -- CF-40: the native card

  after_each(function()
    wowapi.uninstall()
  end)

  describe("setting", function()
    it("is offered to owners, leaders and moderators only", function()
      load()
      assert.is_false(ns.Settings.options().args.inviteLink.hidden()) -- Ves is the owner (role 1)
      state.clubMembers[CLUB][1].role = 4
      wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", CLUB, 1)
      settle()
      assert.is_true(ns.Settings.options().args.inviteLink.hidden())
    end)

    it("stores the code, bumps the version and sends it with the own record", function()
      load()
      settle()
      local before = addon.db.global.self.version
      state.serverTime = 5000
      ns.Settings.options().args.inviteLink.set({}, LINK)
      assert.are.same({ clubId = CLUB, code = "AbC123xyz", setAt = 5000 }, addon.db.global.self.invite)
      assert.is_true(addon.db.global.self.version > before)
      assert.are.equal("AbC123xyz", ns.Settings.options().args.inviteLink.get())
      local record = ns.Merge.outgoingRecord(addon.db.global.self)
      assert.are.same({ clubId = CLUB, code = "AbC123xyz", setAt = 5000 }, record.invite)
    end)

    it("explains invalid input and clears with empty input", function()
      load()
      ns.Settings.options().args.inviteLink.set({}, "hello world")
      assert.are.same({ "That doesn't look like a community invite link or code." }, state.printed)
      ns.Settings.options().args.inviteLink.set({}, LINK)
      ns.Settings.options().args.inviteLink.set({}, "")
      assert.is_nil(addon.db.global.self.invite)
    end)
  end)

  describe("joining a character outside the community", function()
    local function withFriendInvite(setup)
      load(setup)
      addon.db.global.people[SJAAK] = { version = 10, displayName = "Sjaak", chars = {},
                                        invite = { clubId = CLUB, code = "AbC123xyz", setAt = 900 } }
      asNonMember()
      ns.MainFrame.toggle()
    end

    local function postButton()
      for label, b in pairs(ns.FriendsTab.cardButtons()) do
        if label:find("^Post ") then return b end
      end
    end

    local function hasText(needle)
      for _, text in ipairs(texts()) do
        if text:find(needle, 1, true) then return true end
      end
      return false
    end

    it("explains the steps when an invite is known", function()
      withFriendInvite()
      assert.matches("isn't a member", texts()[1])
      assert.is_true(hasText("How to join Forever Friends with Ves Doombringer"))
      assert.is_true(hasText("1. Click \"Post invite link in chat\" below."))
      assert.is_true(hasText("2. In your chat window, click the gold [Join Forever Friends] link."))
      assert.is_true(hasText("3. In Blizzard's window that opens, click Join."))
      assert.is_true(hasText("ask Sjaak for a new one"))
      assert.are.equal("Post invite link in chat", postButton().label:GetText())
    end)

    it("shows no steps without an invite for the community", function()
      load()
      asNonMember()
      ns.MainFrame.toggle()
      assert.is_nil(postButton())
      assert.is_false(hasText("How to join"))
    end)

    it("posts a clickable invite link in chat and points at it", function()
      withFriendInvite()
      postButton():RunScript("OnClick")
      assert.are.same({
        "Click the link below to join Forever Friends, then click Join in Blizzard's window:",
        "|cffffd100|HclubTicket:AbC123xyz|h[Join Forever Friends]|h|r",
      }, state.printed)
      settle()
      assert.is_true(hasText("<- do this now"))
      assert.are.equal("Post the link again", postButton().label:GetText())
      assert.are.same({}, state.redeemed) -- never joins by itself (blocked for addons, V26)
    end)

    it("uses GetClubTicketLink when the game has it", function()
      withFriendInvite(function()
        _G.GetClubTicketLink = function(code, name, clubType)
          return string.format("LINK(%s,%s,%s)", code, name, tostring(clubType))
        end
      end)
      postButton():RunScript("OnClick")
      assert.are.equal("LINK(AbC123xyz,Forever Friends,1)", state.printed[2])
      _G.GetClubTicketLink = nil
    end)

    it("goes back to the community once the character has joined", function()
      withFriendInvite()
      postButton():RunScript("OnClick")
      state.clubs = { { clubId = CLUB, name = "Forever Friends", clubType = 1 } }
      wowapi.fireEvent(state, "CLUB_ADDED", CLUB)
      settle()
      assert.are.equal(CLUB, ns.CommunitySelection.active())
      assert.is_false(ns.Invites.linkPosted())
    end)
  end)
end)
