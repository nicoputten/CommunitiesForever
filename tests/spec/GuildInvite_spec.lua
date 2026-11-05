local helpers = require("helpers")

-- CF-84: the rules of automatic guild invites for alts (src/core/GuildInvite.lua).
describe("GuildInvite (CF-84)", function()
  local G

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/GuildInvite.lua", ns)
    G = ns.GuildInvite
  end)

  describe("the code as typed", function()
    it("is trimmed and needs 6 to 64 characters", function()
      assert.are.equal("Open Sesame", G.cleanCode("  Open Sesame \t"))
      assert.are.equal("abcdef", G.cleanCode("abcdef"))
      assert.are.same({ nil, "short" }, { G.cleanCode("abcde") })
      assert.are.equal(string.rep("x", 64), G.cleanCode(string.rep("x", 64)))
      assert.are.same({ nil, "long" }, { G.cleanCode(string.rep("x", 65)) })
    end)

    it("refuses empty text, escapes and line breaks", function()
      assert.are.same({ nil, "empty" }, { G.cleanCode("   ") })
      assert.are.same({ nil, "empty" }, { G.cleanCode(nil) })
      assert.are.same({ nil, "invalid" }, { G.cleanCode("abc|cffdef") })
      assert.are.same({ nil, "invalid" }, { G.cleanCode("abc\ndefgh") })
    end)
  end)

  describe("the newest code wins", function()
    it("by version first, whatever the times say (edge case 5)", function()
      assert.is_true(G.newer({ code = "aaaaaa", v = 3, at = 100 }, { code = "zzzzzz", v = 2, at = 9999 }))
      assert.is_false(G.newer({ code = "zzzzzz", v = 2, at = 9999 }, { code = "aaaaaa", v = 3, at = 100 }))
      assert.is_true(G.newer({ code = "aaaaaa", v = 1, at = 1 }, { code = "zzzzzz", at = 100 })) -- no v: 0
    end)

    it("on the same version by the time it was set, then by the code that sorts last", function()
      assert.is_true(G.newer({ code = "aaaaaa", v = 2, at = 200 }, { code = "zzzzzz", v = 2, at = 100 }))
      assert.is_true(G.newer({ code = "bbbbbb", v = 2, at = 100 }, { code = "aaaaaa", v = 2, at = 100 }))
      assert.is_false(G.newer({ code = "aaaaaa", v = 2, at = 100 }, { code = "bbbbbb", v = 2, at = 100 }))
      assert.is_false(G.newer({ code = "aaaaaa", v = 2, at = 100 }, { code = "aaaaaa", v = 2, at = 100 }))
      assert.is_true(G.newer({ code = "aaaaaa", v = 1, at = 1 }, nil))
    end)

    it("gives a code set here the next version", function()
      assert.are.equal(1, G.nextVersion(nil))
      assert.are.equal(1, G.nextVersion({ code = "abcdefg", at = 5 }))
      assert.are.equal(8, G.nextVersion({ code = "abcdefg", v = 7, at = 5 }))
    end)

    it("takes a received code only when valid and newer", function()
      local stored = { code = "oldcode1", v = 4, at = 1000 }
      assert.are.same({ code = "newcode1", v = 5, at = 900 },
        G.acceptKey(stored, { code = "newcode1", v = 5, at = 900 }, 2000))
      assert.is_nil(G.acceptKey(stored, { code = "newcode1", v = 3, at = 1999 }, 2000))
      assert.is_nil(G.acceptKey(stored, { code = "oldcode1", v = 4, at = 1000 }, 2000)) -- the same: nothing to do
      assert.are.same({ code = "first1", v = 1, at = 5 }, G.acceptKey(nil, { code = "first1", v = 1, at = 5 }, 2000))
    end)

    it("never takes a bad version, a time from the future, a bad time or a code that is not clean", function()
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 0, at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 1.5, at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 1, at = 2000 + G.FUTURE_SLACK + 1 }, 2000))
      assert.is_table(G.acceptKey(nil, { code = "abcdefg", v = 1, at = 2000 + G.FUTURE_SLACK }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 1, at = 10.5 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 1, at = 0 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", v = 1, at = "10" }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = " abcdefg", v = 1, at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abc", v = 1, at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, "abcdefg", 2000))
    end)
  end)

  describe("the proof", function()
    it("is 16 hex characters, the same on both sides, without case in names", function()
      local p = G.proof("Open Sesame", "My Guild", "Bram Lovewell", 1793300000)
      assert.is_truthy(p:match("^%x+$"))
      assert.are.equal(16, #p)
      assert.are.equal(p, G.proof("Open Sesame", "my guild", "bram lovewell", 1793300000))
    end)

    it("changes with the code, the guild, the character and the time", function()
      local p = G.proof("Open Sesame", "My Guild", "Bram Lovewell", 1793300000)
      assert.are_not.equal(p, G.proof("Open sesame", "My Guild", "Bram Lovewell", 1793300000))
      assert.are_not.equal(p, G.proof("Open Sesame", "My Guilds", "Bram Lovewell", 1793300000))
      assert.are_not.equal(p, G.proof("Open Sesame", "My Guild", "Ada Lovewell", 1793300000))
      assert.are_not.equal(p, G.proof("Open Sesame", "My Guild", "Bram Lovewell", 1793300001))
    end)

    it("does not contain the code", function()
      assert.is_nil(G.proof("abcdef", "g", "n", 1):find("abcdef", 1, true))
    end)
  end)

  describe("checking a request", function()
    local NOW = 1793300000
    local function ctx(over)
      local c = { code = "Open Sesame", guildName = "My Guild", sender = "Bram Lovewell", now = NOW,
                  memberNames = { ["ada lovewell"] = true }, seen = {}, lastHandled = {} }
      for k, v in pairs(over or {}) do c[k] = v end
      return c
    end
    local function request(over)
      local m = { t = "GINVREQ", id = "1a2b3c4d", at = NOW - 10,
                  p = G.proof("Open Sesame", "My Guild", "Bram Lovewell", NOW - 10) }
      for k, v in pairs(over or {}) do m[k] = v end
      return m
    end

    it("accepts a request with the right proof from a character outside the guild", function()
      assert.is_true(G.checkRequest(request(), ctx()))
      assert.is_true(G.checkRequest(request(), ctx({ sender = "bram lovewell" })))
    end)

    it("refuses without a code, outside the guild and when malformed", function()
      assert.are.same({ nil, "nocode" }, { G.checkRequest(request(), ctx({ code = false })) })
      assert.are.same({ nil, "noguild" }, { G.checkRequest(request(), ctx({ guildName = false })) })
      assert.are.same({ nil, "malformed" }, { G.checkRequest(request({ id = 5 }), ctx()) })
      assert.are.same({ nil, "malformed" }, { G.checkRequest(request({ at = "x" }), ctx()) })
      assert.are.same({ nil, "malformed" }, { G.checkRequest(request({ p = false }), ctx()) })
      assert.are.same({ nil, "malformed" }, { G.checkRequest(request({ id = string.rep("a", 33) }), ctx()) })
      assert.are.same({ nil, "malformed" }, { G.checkRequest("text", ctx()) })
    end)

    it("refuses a wrong code, another character or guild, and an old or future request", function()
      assert.are.same({ nil, "proof" }, { G.checkRequest(request(), ctx({ code = "Other Code" })) })
      assert.are.same({ nil, "proof" }, { G.checkRequest(request(), ctx({ sender = "Cora Lovewell" })) })
      assert.are.same({ nil, "proof" }, { G.checkRequest(request(), ctx({ guildName = "Other Guild" })) })
      local old = NOW - G.REQUEST_WINDOW - 1
      assert.are.same({ nil, "stale" }, { G.checkRequest(request({ at = old,
        p = G.proof("Open Sesame", "My Guild", "Bram Lovewell", old) }), ctx()) })
      local future = NOW + G.REQUEST_WINDOW + 1
      assert.are.same({ nil, "stale" }, { G.checkRequest(request({ at = future,
        p = G.proof("Open Sesame", "My Guild", "Bram Lovewell", future) }), ctx()) })
    end)

    it("does nothing for a member, a request someone handles already, or the same requester within a minute",
      function()
      local members = { ["bram lovewell"] = true }
      assert.are.same({ nil, "member" }, { G.checkRequest(request(), ctx({ memberNames = members })) })
      assert.are.same({ nil, "removed" }, { G.checkRequest(request(), ctx({ removedNames = members })) })
      assert.are.same({ nil, "seen" }, { G.checkRequest(request(), ctx({ seen = { ["1a2b3c4d"] = true } })) })
      assert.are.same({ nil, "cooldown" },
        { G.checkRequest(request(), ctx({ lastHandled = { ["bram lovewell"] = NOW - 30 } })) })
      assert.is_true(G.checkRequest(request(), ctx({ lastHandled = { ["bram lovewell"] = NOW - G.HANDLE_COOLDOWN } })))
    end)
  end)

  describe("the member list for alts", function()
    it("remembers names and when each member was last seen online", function()
      local roster = G.updateRoster(nil, {
        ["Player-1"] = { name = "Ada Lovewell", online = true },
        ["Player-2"] = { name = "Cora Lovewell", online = false },
      }, 100)
      assert.are.same({ ["Player-1"] = { name = "Ada Lovewell", seen = 100 },
                        ["Player-2"] = { name = "Cora Lovewell", seen = 0 } }, roster)
      G.updateRoster(roster, {
        ["Player-1"] = { name = "Ada Lovewell", online = false },
        ["Player-2"] = { name = "Cora Lovewell", online = true },
      }, 200)
      assert.are.same({ ["Player-1"] = { name = "Ada Lovewell", seen = 100 },
                        ["Player-2"] = { name = "Cora Lovewell", seen = 200 } }, roster)
    end)

    it("drops members who left and names them, and the longest unseen beyond the limit", function()
      local roster = G.updateRoster(nil, { ["Player-1"] = { name = "Ada Lovewell", online = true } }, 100)
      local _, gone = G.updateRoster(roster, { ["Player-2"] = { name = "Cora Lovewell", online = true } }, 200)
      assert.are.same({ ["Player-2"] = { name = "Cora Lovewell", seen = 200 } }, roster)
      assert.are.same({ ["Player-1"] = "Ada Lovewell" }, gone)
      local members, big = {}, {}
      for i = 1, G.ROSTER_MAX + 5 do
        members["Player-" .. i] = { name = "Member " .. i, online = false }
        big["Player-" .. i] = { name = "Member " .. i, seen = i }
      end
      G.updateRoster(big, members, 1000)
      local count = 0
      for _ in pairs(big) do count = count + 1 end
      assert.are.equal(G.ROSTER_MAX, count)
      assert.is_nil(big["Player-1"])
      assert.is_table(big["Player-" .. (G.ROSTER_MAX + 5)])
    end)

    it("does not count anyone as gone when the list looks half loaded", function()
      local roster, members = {}, {}
      for i = 1, 20 do roster["Player-" .. i] = { name = "Member " .. i, seen = i } end
      for i = 1, 10 do members["Player-" .. i] = { name = "Member " .. i, online = false } end
      local _, gone = G.updateRoster(roster, members, 300)
      assert.are.same({}, gone)
      assert.is_table(roster["Player-20"]) -- kept until the list is complete
      members = {}
      for i = 1, 18 do members["Player-" .. i] = { name = "Member " .. i, online = false } end
      _, gone = G.updateRoster(roster, members, 300)
      assert.are.same({ ["Player-19"] = "Member 19", ["Player-20"] = "Member 20" }, gone)
    end)

    it("asks the most recently online first, without your own characters, at most ten", function()
      local roster = {
        a = { name = "Ada Lovewell", seen = 300 },
        b = { name = "Cora Lovewell", seen = 500 },
        c = { name = "Dina Lovewell", seen = 0 },
        d = { name = "Bram Lovewell", seen = 900 },
        e = { name = "Abe Lovewell", seen = 300 },
      }
      assert.are.same({ "Cora Lovewell", "Abe Lovewell", "Ada Lovewell", "Dina Lovewell" },
        G.candidates(roster, { d = true }))
      assert.are.same({ "Bram Lovewell", "Cora Lovewell" }, G.candidates(roster, nil, 2))
      local many = {}
      for i = 1, 20 do many["g" .. i] = { name = "Member " .. i, seen = i } end
      assert.are.equal(G.CANDIDATES_MAX, #G.candidates(many))
      assert.are.same({}, G.candidates(nil))
    end)
  end)

  describe("characters removed from the guild (edge case 6)", function()
    it("are remembered, matched by name, and lifted by GUID back in the guild or a manual invite by name", function()
      local removed = G.markRemoved(nil, "Player-9", "Bram Lovewell", 100)
      G.markRemoved(removed, "Player-8", "Cora Lovewell", 110)
      assert.are.same({ ["bram lovewell"] = true, ["cora lovewell"] = true }, G.removedNames(removed))
      assert.is_true(G.liftRemoved(removed, { ["Player-9"] = { name = "Bram Lovewell" } }))
      assert.is_true(G.liftRemoved(removed, nil, "cora lovewell"))
      assert.are.same({}, removed)
      assert.is_false(G.liftRemoved(removed, nil, "Nobody"))
      assert.is_false(G.liftRemoved(nil, nil, "Nobody"))
    end)

    it("ignores bad entries and keeps the newest when full", function()
      assert.are.same({}, G.markRemoved(nil, nil, "Bram Lovewell", 1))
      assert.are.same({}, G.markRemoved(nil, "Player-1", "", 1))
      local removed = {}
      for i = 1, G.REMOVED_MAX + 3 do G.markRemoved(removed, "Player-" .. i, "Member " .. i, i) end
      local count = 0
      for _ in pairs(removed) do count = count + 1 end
      assert.are.equal(G.REMOVED_MAX, count)
      assert.is_nil(removed["Player-1"])
    end)
  end)

  describe("faction and realm (edge case 3)", function()
    it("tells another faction or realm, and is fine when equal or unknown", function()
      local guild = { faction = "Horde", realm = "Classic Beta PvP" }
      assert.are.equal("faction", G.placeMismatch(guild, { faction = "Alliance", realm = "Classic Beta PvP" }))
      assert.are.equal("realm", G.placeMismatch(guild, { faction = "Horde", realm = "Classic Beta RP" }))
      assert.is_nil(G.placeMismatch(guild, { faction = "Horde", realm = "Classic Beta PvP" }))
      assert.is_nil(G.placeMismatch({}, { faction = "Horde" }))
      assert.is_nil(G.placeMismatch(nil, { faction = "Horde" }))
    end)
  end)

  describe("the game's refusals (edge case 4)", function()
    local FORMATS = { rights = "You don't have permission to do that.",
                      member = "%s is already in a guild.",
                      faction = "You cannot invite players from the opposing alliance" }

    it("are read through the game's own texts, with the name when they give one", function()
      assert.are.same({ "rights" }, { G.inviteError("You don't have permission to do that.", FORMATS) })
      assert.are.same({ "member", "Bram Lovewell" }, { G.inviteError("Bram Lovewell is already in a guild.", FORMATS) })
      assert.are.same({ "faction" }, { G.inviteError("You cannot invite players from the opposing alliance", FORMATS) })
      assert.is_nil(G.inviteError("You have invited Bram Lovewell to join your guild.", FORMATS))
      assert.is_nil(G.inviteError(nil, FORMATS))
    end)
  end)

  describe("accepting the invite", function()
    it("only for the remembered guild, shortly after our request", function()
      assert.is_true(G.shouldAccept(1000, "My Guild", "my guild", 1000 + G.ACCEPT_WINDOW))
      assert.is_false(G.shouldAccept(1000, "My Guild", "My Guild", 1001 + G.ACCEPT_WINDOW))
      assert.is_false(G.shouldAccept(1000, "Other Guild", "My Guild", 1010))
      assert.is_false(G.shouldAccept(nil, "My Guild", "My Guild", 1010))
      assert.is_false(G.shouldAccept(1000, nil, "My Guild", 1010))
    end)
  end)

  it("words the popup with the friend when known", function()
    assert.are.equal("Invite Bram Lovewell (Ada's alt)?", G.popupText("Bram Lovewell", "Ada"))
    assert.are.equal("Invite Bram Lovewell?", G.popupText("Bram Lovewell", nil))
    assert.are.equal("Bram Lovewell (Ada's alt)", G.altLabel("Bram Lovewell", "Ada"))
  end)

  -- CF-87: the popup's /ginvite line, with the name exactly as given (a space, a realm), one line, no escapes.
  it("makes the /ginvite command from the name as the game reported it", function()
    assert.are.equal("/ginvite Bram Lovewell-ClassicBetaPvP", G.inviteCommand("Bram Lovewell-ClassicBetaPvP"))
    assert.are.equal("/ginvite Bram Lovewell", G.inviteCommand("Bram Lovewell"))
    assert.is_nil(G.inviteCommand(""))
    assert.is_nil(G.inviteCommand(nil))
    assert.is_nil(G.inviteCommand("Bram\n/script x()"))
    assert.is_nil(G.inviteCommand("Bram|cffff"))
  end)

  it("cleans a requester's display name", function()
    assert.are.equal("Ada", G.cleanDisplayName(" Ada "))
    assert.are.equal("Adacffff", G.cleanDisplayName("Ada|cffff"))
    assert.are.equal(G.DISPLAY_MAX, #G.cleanDisplayName(string.rep("x", 40)))
    assert.is_nil(G.cleanDisplayName(""))
    assert.is_nil(G.cleanDisplayName(5))
  end)
end)
