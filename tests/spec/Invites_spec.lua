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

  describe("joining a character outside the community", function()
    local function withFriendInvite(setup)
      load(setup)
      addon.db.global.people[SJAAK] = { version = 10, displayName = "Sjaak", chars = {},
                                        invite = { clubId = CLUB, code = "AbC123xyz", setAt = 900 } }
      asNonMember()
      ns.MainFrame.toggle()
    end

    local function postButton()
      for i = #state.guiWidgets, 1, -1 do
        local w = state.guiWidgets[i]
        if w.type == "Button" and w.text and w.text:find("^Post ") then return w end
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
      assert.are.equal("Post invite link in chat", postButton().text)
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
      postButton():Fire("OnClick")
      assert.are.same({
        "Click the link below to join Forever Friends, then click Join in Blizzard's window:",
        "|cffffd100|HclubTicket:AbC123xyz|h[Join Forever Friends]|h|r",
      }, state.printed)
      settle()
      assert.is_true(hasText("<- do this now"))
      assert.are.equal("Post the link again", postButton().text)
      assert.are.same({}, state.redeemed) -- never joins by itself (blocked for addons, V26)
    end)

    it("uses GetClubTicketLink when the game has it", function()
      withFriendInvite(function()
        _G.GetClubTicketLink = function(code, name, clubType)
          return string.format("LINK(%s,%s,%s)", code, name, tostring(clubType))
        end
      end)
      postButton():Fire("OnClick")
      assert.are.equal("LINK(AbC123xyz,Forever Friends,1)", state.printed[2])
      _G.GetClubTicketLink = nil
    end)

    it("goes back to the community once the character has joined", function()
      withFriendInvite()
      postButton():Fire("OnClick")
      state.clubs = { { clubId = CLUB, name = "Forever Friends", clubType = 1 } }
      wowapi.fireEvent(state, "CLUB_ADDED", CLUB)
      settle()
      assert.are.equal(CLUB, ns.CommunitySelection.active())
      assert.is_false(ns.Invites.linkPosted())
    end)
  end)
end)
