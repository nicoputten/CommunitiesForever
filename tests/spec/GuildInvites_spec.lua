local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-84: automatic guild invites for alts (src/services/GuildInvites.lua) against the WoW mock: the code in the
-- vault, spread on the guild channel; a member answering a request; an alt asking and accepting.
describe("GuildInvites (CF-84)", function()
  local state, ns, addon, codec
  local GUILD_CLUB = "999"   -- the mock's "My Guild" (clubType 2)
  local ALT_GUID = "Player-4619-0BBBBBBB"
  local invited, accepted

  local function install(opts)
    opts = opts or {}
    state = wowapi.install()
    if opts.inGuild ~= false then
      state.clubs = { { clubId = GUILD_CLUB, name = "My Guild", clubType = 2 } }
      state.clubMembers[GUILD_CLUB] = {
        { memberId = 1, guid = "Player-4619-01627852", name = "Ves Doombringer", presence = 1, isSelf = true,
          clubType = 2, role = 4 },
        { memberId = 2, guid = "Player-4619-0AAAAAAA", name = "Ada Lovewell", presence = 1, clubType = 2, role = 4 },
        { memberId = 3, guid = "Player-4619-0CCCCCCC", name = "Cora Lovewell", presence = 3, clubType = 2, role = 4 },
      }
    else
      state.clubs = {}
    end
    invited, accepted = {}, 0
    _G.C_GuildInfo = { Invite = function(name) invited[#invited + 1] = name end }
    _G.AcceptGuild = function() accepted = accepted + 1 end
    _G.StaticPopup_Hide = function() end
    _G.ERR_GUILD_INVITE_S = "You have invited %s to join your guild."
    _G.ERR_GUILD_PERMISSIONS = "You don't have permission to do that."
    _G.ERR_GUILD_NOT_ALLIED = "You cannot invite players from the opposing alliance"
    if opts.members then state.clubMembers[GUILD_CLUB] = opts.members end
    if opts.vault ~= false then _G.CommunitiesForeverVaultDB = opts.vault or {} end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    local s = addon.db.global.settings
    s.clubId, s.clubName, s.clubType = GUILD_CLUB, "My Guild", 2
    if opts.people then addon.db.global.people = opts.people end
    addon:OnEnable()
    codec = ns.Protocol.codec(_G.LibStub("LibSerialize"), _G.LibStub("LibDeflate"))
  end

  after_each(function()
    _G.C_GuildInfo, _G.AcceptGuild, _G.StaticPopup_Hide, _G.ERR_GUILD_INVITE_S = nil, nil, nil, nil
    _G.ERR_GUILD_PERMISSIONS, _G.ERR_GUILD_NOT_ALLIED = nil, nil
    wowapi.uninstall()
  end)

  -- Our prefix's messages sent so far (decoded): { message, channel, target }.
  local function sent()
    local list = {}
    for _, w in ipairs(state.whispers) do
      if w[1] == "CFGuild" then list[#list + 1] = { message = codec:decode(w[2]), channel = w[3], target = w[4] } end
    end
    return list
  end

  local function sentOfType(t)
    local list = {}
    for _, s in ipairs(sent()) do
      if s.message and s.message.t == t then list[#list + 1] = s end
    end
    return list
  end

  local function receive(message, channel, sender)
    wowapi.fireEvent(state, "CHAT_MSG_ADDON", "CFGuild", codec:encode(message), channel, sender)
  end

  local function printed(text)
    for _, line in ipairs(state.printed) do
      if line:find(text, 1, true) then return true end
    end
    return false
  end

  local function contains(value, text)
    if type(value) == "string" then return value:find(text, 1, true) ~= nil end
    if type(value) ~= "table" then return false end
    for k, v in pairs(value) do
      if contains(k, text) or contains(v, text) then return true end
    end
    return false
  end

  describe("the code", function()
    it("is kept in the vault, never in CommunitiesForeverDB, and shared on the guild channel", function()
      install()
      assert.is_true(ns.GuildInvites.setCode("  Open Sesame "))
      assert.are.equal("Open Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
      assert.are.equal(state.serverTime, _G.CommunitiesForeverVaultDB.guilds["my guild"].at)
      assert.is_false(contains(addon.db.global, "Open Sesame"))
      local keys = sentOfType("GKEY")
      assert.are.equal(1, #keys)
      assert.are.equal("GUILD", keys[1].channel)
      assert.are.same({ "Open Sesame", 1, state.serverTime }, { keys[1].message.k, keys[1].message.v,
        keys[1].message.at })
    end)

    it("is never shown: the settings field reads empty, the status line has only the time", function()
      install()
      ns.GuildInvites.setCode("Open Sesame")
      local option = ns.Settings.options().args.guildCode
      assert.is_false(option.hidden())
      assert.are.equal("", option.get())
      assert.is_true(option.masked)
      assert.is_truthy(option.status():find("A guild code is set", 1, true))
      assert.is_false(contains(option.status(), "Open Sesame"))
      for _, line in ipairs(state.printed) do assert.is_nil(line:find("Open Sesame", 1, true)) end
    end)

    it("is typed in a masked field in the settings window, which empties itself after each entry", function()
      install()
      ns.SettingsWindow.open()
      local field = ns.SettingsWindow.control("guildCode")
      assert.is_true(field.password) -- EditBox:SetPassword(true) (V130)
      assert.is_true(ns.SettingsWindow.window().guild:IsShown())
      field:SetText("Open Sesame")
      field:RunScript("OnEditFocusLost")
      assert.are.equal("Open Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
      assert.are.equal("", field:GetText())
      assert.is_true(printed(ns.GuildInvites.SET))
      addon.db.global.settings.clubType = 1
      ns.SettingsWindow.open()
      assert.is_false(ns.SettingsWindow.window().guild:IsShown())
    end)

    it("is shown only while the guild is picked", function()
      install()
      addon.db.global.settings.clubType = 1
      assert.is_true(ns.Settings.options().args.guildCode.hidden())
    end)

    it("refuses a short code and says why; an empty field changes nothing", function()
      install()
      assert.are.same({ nil, ns.GuildInvites.SET_ERRORS.short }, { ns.GuildInvites.setCode("abc") })
      assert.are.same({ nil }, { ns.GuildInvites.setCode("   ") })
      assert.is_nil(ns.GuildInvites.codeSetAt())
    end)

    it("is off without the vault folder", function()
      install({ vault = false })
      wowapi.runTimers(state)
      assert.are.same({}, sent()) -- no GKEYHI either
      assert.is_false(ns.GuildInvites.available())
      assert.are.same({ nil, ns.GuildInvites.SET_ERRORS.novault }, { ns.GuildInvites.setCode("Open Sesame") })
      assert.are.equal(ns.Settings.GUILD_CODE_NO_VAULT, ns.Settings.guildCodeStatus())
    end)

    it("replaced by a member gets the next version, also on the same second", function()
      install()
      ns.GuildInvites.setCode("Open Sesame")
      ns.GuildInvites.setCode("Close Sesame")
      local entry = _G.CommunitiesForeverVaultDB.guilds["my guild"]
      assert.are.same({ "Close Sesame", 2 }, { entry.code, entry.v })
    end)

    it("takes a newer code from a guild member", function()
      install({ vault = { guilds = { ["my guild"] = { code = "Old Sesame", v = 1, at = 500 } } } })
      receive({ t = "GKEY", k = "New Sesame", v = 2, at = 900 }, "GUILD", "Ada Lovewell-ClassicBetaPvP")
      assert.are.equal("New Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
      assert.are.equal(2, _G.CommunitiesForeverVaultDB.guilds["my guild"].v)
    end)

    -- Edge case 5: newest by version, not by clock.
    it("keeps a newer version when a member comes back with an old code, whatever its clock says", function()
      install({ vault = { guilds = { ["my guild"] = { code = "New Sesame", v = 3, at = 500 } } } })
      wowapi.runTimers(state)
      local before = #sentOfType("GKEY")
      receive({ t = "GKEY", k = "Old Sesame", v = 2, at = state.serverTime + 100 }, "GUILD",
        "Ada Lovewell-ClassicBetaPvP")
      assert.are.equal("New Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
      wowapi.runTimers(state)
      local answer = sentOfType("GKEY")[before + 1]
      assert.are.same({ "New Sesame", 3 }, { answer.message.k, answer.message.v })
    end)

    it("refuses a code without a version", function()
      install({ vault = { guilds = { ["my guild"] = { code = "Old Sesame", v = 1, at = 500 } } } })
      receive({ t = "GKEY", k = "New Sesame", at = 900 }, "GUILD", "Ada Lovewell-ClassicBetaPvP")
      assert.are.equal("Old Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
    end)

    it("answers an older code, or a member without one, with its own after a moment", function()
      install({ vault = { guilds = { ["my guild"] = { code = "New Sesame", v = 2, at = 900 } } } })
      wowapi.runTimers(state) -- after login: our own GKEY once
      local before = #sentOfType("GKEY")
      receive({ t = "GKEY", k = "Old Sesame", v = 1, at = 500 }, "GUILD", "Ada Lovewell-ClassicBetaPvP")
      assert.are.equal("New Sesame", _G.CommunitiesForeverVaultDB.guilds["my guild"].code)
      assert.are.equal(before, #sentOfType("GKEY"))
      wowapi.runTimers(state)
      assert.are.equal(before + 1, #sentOfType("GKEY"))
    end)

    it("asks for the code after login when it has none, and a member with one answers", function()
      install()
      wowapi.runTimers(state)
      local hello = sentOfType("GKEYHI")
      assert.are.equal(1, #hello)
      assert.are.equal("GUILD", hello[1].channel)
    end)

    it("does not answer when another member answered first", function()
      install({ vault = { guilds = { ["my guild"] = { code = "New Sesame", v = 2, at = 900 } } } })
      wowapi.runTimers(state)
      local before = #sentOfType("GKEY")
      receive({ t = "GKEYHI", v = 0 }, "GUILD", "Cora Lovewell-ClassicBetaPvP")
      receive({ t = "GKEY", k = "New Sesame", v = 2, at = 900 }, "GUILD", "Ada Lovewell-ClassicBetaPvP")
      wowapi.runTimers(state)
      assert.are.equal(before, #sentOfType("GKEY"))
    end)

    it("keeps the guild member list for alts in the vault", function()
      install()
      ns.GuildInvites.setCode("Open Sesame")
      wowapi.runTimers(state)
      local roster = _G.CommunitiesForeverVaultDB.guilds["my guild"].roster
      assert.are.same({ name = "Ada Lovewell", seen = state.serverTime }, roster["Player-4619-0AAAAAAA"])
      assert.are.same({ name = "Cora Lovewell", seen = 0 }, roster["Player-4619-0CCCCCCC"])
    end)
  end)

  describe("a member", function()
    local PEOPLE = { ["Ada#1001"] = { displayName = "Ada", chars = { [ALT_GUID] = { name = "Bram Lovewell" } } } }

    local function request(over)
      local at = state.serverTime - 5
      local m = { t = "GINVREQ", id = "1a2b3c4d", at = at, guid = ALT_GUID,
                  p = ns.GuildInvite.proof("Open Sesame", "My Guild", "Bram Lovewell", at) }
      for k, v in pairs(over or {}) do m[k] = v end
      return m
    end

    local function member()
      install({ people = PEOPLE, vault = { guilds = { ["my guild"] = { code = "Open Sesame", v = 1, at = 900 } } } })
      wowapi.runTimers(state)
    end

    it("acknowledges a valid request, claims it in the guild and invites the character that asked", function()
      member()
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      local ack = sentOfType("GINVACK")
      assert.are.equal(1, #ack)
      -- Edge case 2: whispered back and invited with the name exactly as the game reported it (with the realm).
      assert.are.same({ "WHISPER", "Bram Lovewell-ClassicBetaPvP", "1a2b3c4d" },
        { ack[1].channel, ack[1].target, ack[1].message.id })
      local claim = sentOfType("GINVCLAIM")
      assert.are.same({ "GUILD", "1a2b3c4d", "Bram Lovewell" },
        { claim[1].channel, claim[1].message.id, claim[1].message.n })
      assert.are.same({ "Bram Lovewell-ClassicBetaPvP" }, invited)
      wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", "You have invited Bram Lovewell to join your guild.")
      assert.is_true(printed("Invited Bram Lovewell (Ada's alt) into the guild."))
      wowapi.runTimers(state)
      assert.is_nil(ns.GuildInvitePopup.frame()) -- confirmed: no popup
    end)

    it("shows the one-button popup when nothing came of the invite, and the click invites", function()
      member()
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      wowapi.runTimers(state)
      local popup = ns.GuildInvitePopup.frame()
      assert.is_true(popup:IsShown())
      assert.are.equal("Invite Bram Lovewell (Ada's alt)?", popup.line:GetText())
      popup.button:RunScript("OnClick")
      assert.are.same({ "Bram Lovewell-ClassicBetaPvP", "Bram Lovewell-ClassicBetaPvP" }, invited)
      assert.is_false(popup:IsShown())
    end)

    it("shows the popup at once when the game blocks the invite, and for later requests too", function()
      member()
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      wowapi.fireEvent(state, "ADDON_ACTION_BLOCKED", "CommunitiesForever", "C_GuildInfo.Invite()")
      assert.is_true(ns.GuildInvitePopup.frame():IsShown())
      ns.GuildInvitePopup.frame():Hide()
      local at = state.serverTime
      receive(request({ id = "99999999", at = at, guid = false, p = ns.GuildInvite.proof("Open Sesame", "My Guild",
        "Dina Lovewell", at) }), "WHISPER", "Dina Lovewell-ClassicBetaPvP")
      assert.are.equal(1, #invited) -- no second try without a click
      assert.are.equal("Invite Dina Lovewell?", ns.GuildInvitePopup.frame().line:GetText())
    end)

    it("ignores a wrong code, a guild member, a request someone claimed and a second one within a minute", function()
      member()
      receive(request({ p = ns.GuildInvite.proof("Wrong Code", "My Guild", "Bram Lovewell", state.serverTime - 5) }),
        "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      local at = state.serverTime
      local proof = ns.GuildInvite.proof("Open Sesame", "My Guild", "Ada Lovewell", at)
      receive(request({ id = "22222222", at = at, p = proof }),
        "WHISPER", "Ada Lovewell-ClassicBetaPvP")
      receive({ t = "GINVCLAIM", id = "33333333", n = "Bram Lovewell" }, "GUILD", "Cora Lovewell-ClassicBetaPvP")
      receive(request({ id = "33333333" }), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      assert.are.same({}, invited)
      assert.are.same({}, sentOfType("GINVACK"))
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      receive(request({ id = "44444444" }), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      assert.are.equal(1, #invited)
    end)

    -- Edge case 4: the game refuses the invite (no rights): the alt hears it at once, no popup.
    it("tells the alt when the game refuses the invite", function()
      member()
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      wowapi.fireEvent(state, "UI_ERROR_MESSAGE", 1, "You don't have permission to do that.")
      local fail = sentOfType("GINVFAIL")
      assert.are.equal(1, #fail)
      assert.are.same({ "Bram Lovewell-ClassicBetaPvP", "1a2b3c4d", "rights" },
        { fail[1].target, fail[1].message.id, fail[1].message.r })
      wowapi.runTimers(state)
      assert.is_nil(ns.GuildInvitePopup.frame())
    end)

    -- Edge case 6: a character removed from the guild is never invited by itself again; a manual invite lifts it.
    describe("a character removed from the guild", function()
      local MEMBERS
      before_each(function()
        MEMBERS = {
          { memberId = 1, guid = "Player-4619-01627852", name = "Ves Doombringer", presence = 1, isSelf = true,
            clubType = 2, role = 4 },
          { memberId = 2, guid = "Player-4619-0AAAAAAA", name = "Ada Lovewell", presence = 1, clubType = 2, role = 4 },
          { memberId = 4, guid = ALT_GUID, name = "Bram Lovewell", presence = 3, clubType = 2, role = 4 },
        }
      end)

      local function kickBram()
        table.remove(state.clubMembers[GUILD_CLUB], 3)
        wowapi.fireEvent(state, "CLUB_MEMBER_REMOVED", GUILD_CLUB, 4)
        wowapi.runTimers(state)
      end

      it("is remembered, shared in the guild, and not invited by itself", function()
        install({ people = PEOPLE, members = MEMBERS,
                  vault = { guilds = { ["my guild"] = { code = "Open Sesame", v = 1, at = 900 } } } })
        wowapi.runTimers(state)
        kickBram()
        local removed = _G.CommunitiesForeverVaultDB.guilds["my guild"].removed
        assert.are.equal("Bram Lovewell", removed[ALT_GUID].name)
        local kick = sentOfType("GKICK")
        assert.are.same({ "GUILD", ALT_GUID, "Bram Lovewell" },
          { kick[1].channel, kick[1].message.g, kick[1].message.n })
        receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
        assert.are.same({}, invited)
        assert.are.same({}, sentOfType("GINVACK"))
      end)

      it("is lifted by a manual invite", function()
        install({ people = PEOPLE, members = MEMBERS,
                  vault = { guilds = { ["my guild"] = { code = "Open Sesame", v = 1, at = 900 } } } })
        wowapi.runTimers(state)
        kickBram()
        wowapi.fireEvent(state, "CHAT_MSG_SYSTEM", "You have invited Bram Lovewell to join your guild.")
        assert.is_nil(_G.CommunitiesForeverVaultDB.guilds["my guild"].removed[ALT_GUID])
        receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
        assert.are.equal(1, #invited)
      end)

      it("is learned from another member's GKICK, and lifted when the character is back in the guild", function()
        member()
        receive({ t = "GKICK", g = ALT_GUID, n = "Bram Lovewell", at = 950 }, "GUILD", "Ada Lovewell-ClassicBetaPvP")
        receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
        assert.are.same({}, invited)
        table.insert(state.clubMembers[GUILD_CLUB], { memberId = 4, guid = ALT_GUID, name = "Bram Lovewell",
          presence = 1, clubType = 2, role = 4 })
        wowapi.fireEvent(state, "CLUB_MEMBER_ADDED", GUILD_CLUB, 4)
        wowapi.runTimers(state)
        assert.is_nil(_G.CommunitiesForeverVaultDB.guilds["my guild"].removed[ALT_GUID])
      end)
    end)

    it("does nothing without a code", function()
      install({ people = PEOPLE })
      receive(request(), "WHISPER", "Bram Lovewell-ClassicBetaPvP")
      assert.are.same({}, invited)
      assert.are.same({}, sentOfType("GINVACK"))
    end)
  end)

  -- Edge case 1: a bank alt in another guild must not move the account's pick.
  describe("the guild pick", function()
    it("stays on the picked guild when a character is only in another guild", function()
      install({ inGuild = false, vault = {} })
      state.clubs = { { clubId = "555", name = "Bank Guild", clubType = 2 } }
      wowapi.fireEvent(state, "INITIAL_CLUBS_LOADED")
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      wowapi.runTimers(state)
      local s = addon.db.global.settings
      assert.are.same({ GUILD_CLUB, "My Guild", 2 }, { s.clubId, s.clubName, s.clubType })
      assert.is_nil(ns.CommunitySelection.active())
      assert.is_false(printed("Showing community"))
    end)

    it("is made only when there is none yet", function()
      install({ inGuild = false, vault = {} })
      addon.db.global.settings.clubId = nil
      state.clubs = { { clubId = "555", name = "Bank Guild", clubType = 2 } }
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      assert.are.equal("555", addon.db.global.settings.clubId)
    end)
  end)

  describe("an alt outside the guild", function()
    local VAULT
    before_each(function()
      VAULT = { guilds = { ["my guild"] = { code = "Open Sesame", v = 1, at = 900, roster = {
        ["Player-4619-0AAAAAAA"] = { name = "Ada Lovewell", seen = 500 },
        ["Player-4619-0CCCCCCC"] = { name = "Cora Lovewell", seen = 900 },
        ["Player-4619-01627852"] = { name = "Ves Doombringer", seen = 950 }, -- this character: never asked
        ["Player-4619-0DDDDDDD"] = { name = "Dina Lovewell", seen = 0 },
      } } } }
    end)

    local function requests()
      return sentOfType("GINVREQ")
    end

    it("asks the most recently online member after login, with a proof of the code", function()
      install({ inGuild = false, vault = VAULT })
      assert.are.same({}, requests())
      wowapi.runTimers(state)
      local r = requests()
      assert.are.equal(1, #r)
      assert.are.same({ "WHISPER", "Cora Lovewell" }, { r[1].channel, r[1].target })
      local m = r[1].message
      assert.are.equal(ns.GuildInvite.proof("Open Sesame", "My Guild", "Ves Doombringer", m.at), m.p)
      assert.are.equal("Player-4619-01627852", m.guid)
      assert.is_false(contains(m, "Open Sesame"))
    end)

    it("asks the next member at once when the game says the first is offline, and the line is hidden", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      local filter = state.chatFilters.CHAT_MSG_SYSTEM[1]
      assert.is_true(filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Cora Lovewell' is currently playing."))
      wowapi.runTimers(state)
      local r = requests()
      assert.are.equal(2, #r)
      assert.are.equal("Ada Lovewell", r[2].target)
      assert.are.equal(r[1].message.id, r[2].message.id)
    end)

    it("asks the next member when one does not answer, and stops once the acknowledged invite arrives", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      wowapi.runTimers(state) -- Cora does not answer within ACK_WAIT
      local r = requests()
      assert.are.equal("Ada Lovewell", r[2].target)
      receive({ t = "GINVACK", id = r[2].message.id }, "WHISPER", "Ada Lovewell-ClassicBetaPvP")
      assert.is_true(printed("Asked Ada Lovewell for an invite into My Guild."))
      wowapi.fireEvent(state, "GUILD_INVITE_REQUEST", "Ada Lovewell", "My Guild")
      assert.are.equal(1, accepted)
      for _ = 1, 5 do wowapi.runTimers(state) end
      assert.are.equal(2, #requests())
    end)

    -- Edge case 4: a member without invite rights, or whose invite fails, must not hold the alt up.
    it("asks the next member at once, with a new request, when the member's invite was refused", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      local r = requests()
      receive({ t = "GINVACK", id = r[1].message.id }, "WHISPER", "Cora Lovewell-ClassicBetaPvP")
      receive({ t = "GINVFAIL", id = r[1].message.id, r = "rights" }, "WHISPER", "Cora Lovewell-ClassicBetaPvP")
      r = requests()
      assert.are.equal(2, #r)
      assert.are.equal("Ada Lovewell", r[2].target)
      assert.are_not.equal(r[1].message.id, r[2].message.id) -- the old one is claimed in the guild
    end)

    it("asks the next member when an acknowledged invite never comes", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      local r = requests()
      receive({ t = "GINVACK", id = r[1].message.id }, "WHISPER", "Cora Lovewell-ClassicBetaPvP")
      wowapi.runTimers(state) -- INVITE_WAIT passes
      r = requests()
      assert.are.equal(2, #r)
      assert.are.equal("Ada Lovewell", r[2].target)
    end)

    -- Edge case 3: another faction or realm can never join: one line, then quiet for good.
    for _, case in ipairs({
      { what = "faction", place = { faction = "Alliance" }, line = "the guild is on the other faction" },
      { what = "realm", place = { realm = "Classic Beta RP" }, line = "the guild is on another realm" },
    }) do
      it("stops for good, with one line, when the guild is on another " .. case.what, function()
        for k, v in pairs(case.place) do VAULT.guilds["my guild"][k] = v end
        install({ inGuild = false, vault = VAULT })
        wowapi.runTimers(state)
        assert.are.same({}, requests())
        assert.is_true(printed("This character can't join My Guild: " .. case.line))
        local vault = _G.CommunitiesForeverVaultDB
        wowapi.uninstall()
        install({ inGuild = false, vault = vault }) -- the next login
        wowapi.runTimers(state)
        assert.are.same({}, requests())
        assert.are.same({}, state.printed)
      end)
    end

    it("stops for good when a member's invite says the other faction", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      local r = requests()
      receive({ t = "GINVFAIL", id = r[1].message.id, r = "faction" }, "WHISPER", "Cora Lovewell-ClassicBetaPvP")
      assert.is_true(printed("the guild is on the other faction"))
      for _ = 1, 10 do wowapi.runTimers(state) end
      assert.are.equal(1, #requests())
    end)

    it("says that nobody answered at most once a day", function()
      install({ inGuild = false, vault = VAULT })
      for _ = 1, 30 do wowapi.runTimers(state) end
      assert.is_true(printed("No member of My Guild answered"))
      local vault = _G.CommunitiesForeverVaultDB
      wowapi.uninstall()
      install({ inGuild = false, vault = vault })
      for _ = 1, 30 do wowapi.runTimers(state) end
      assert.is_false(printed("No member of My Guild answered"))
    end)

    it("accepts the invite into the remembered guild by itself, not another guild's", function()
      install({ inGuild = false, vault = VAULT })
      wowapi.runTimers(state)
      wowapi.fireEvent(state, "GUILD_INVITE_REQUEST", "Pip Stranger", "Other Guild")
      assert.are.equal(0, accepted)
      wowapi.fireEvent(state, "GUILD_INVITE_REQUEST", "Cora Lovewell", "My Guild")
      assert.are.equal(1, accepted)
      assert.is_true(printed("Joining My Guild: accepting the invite from Cora Lovewell."))
    end)

    it("does not accept an invite it never asked for", function()
      local roster = VAULT.guilds["my guild"].roster
      install({ inGuild = false, vault = { guilds = { ["my guild"] = { at = 1, roster = roster } } } })
      wowapi.runTimers(state)
      assert.are.same({}, requests()) -- no code: the feature is off
      wowapi.fireEvent(state, "GUILD_INVITE_REQUEST", "Cora Lovewell", "My Guild")
      assert.are.equal(0, accepted)
    end)

    it("tries again later and gives up after three attempts with one line", function()
      install({ inGuild = false, vault = VAULT })
      for _ = 1, 30 do wowapi.runTimers(state) end
      assert.are.equal(3 * 3, #requests()) -- three members (not this character), three attempts
      assert.is_true(printed("No member of My Guild answered your guild invite request."))
    end)

    it("does nothing in another guild, or without the vault", function()
      install({ inGuild = false, vault = VAULT })
      state.clubs = { { clubId = "555", name = "Other Guild", clubType = 2 } }
      wowapi.runTimers(state)
      assert.are.same({}, requests())
      wowapi.uninstall()
      install({ inGuild = false, vault = false })
      wowapi.runTimers(state)
      assert.are.same({}, requests())
    end)
  end)
end)
