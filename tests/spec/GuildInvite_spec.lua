local helpers = require("helpers")

-- CF-84: the rules of automatic guild invites for alts (src/core/GuildInvite.lua).
describe("GuildInvite (CF-84)", function()
  local G

  before_each(function()
    local ns = helpers.coreNs()
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
    it("by the time it was set, then by the code that sorts last", function()
      assert.is_true(G.newer({ code = "aaaaaa", at = 200 }, { code = "zzzzzz", at = 100 }))
      assert.is_false(G.newer({ code = "zzzzzz", at = 100 }, { code = "aaaaaa", at = 200 }))
      assert.is_true(G.newer({ code = "bbbbbb", at = 100 }, { code = "aaaaaa", at = 100 }))
      assert.is_false(G.newer({ code = "aaaaaa", at = 100 }, { code = "bbbbbb", at = 100 }))
      assert.is_false(G.newer({ code = "aaaaaa", at = 100 }, { code = "aaaaaa", at = 100 }))
      assert.is_true(G.newer({ code = "aaaaaa", at = 1 }, nil))
    end)

    it("takes a received code only when valid and newer", function()
      local stored = { code = "oldcode1", at = 1000 }
      assert.are.same({ code = "newcode1", at = 1001 }, G.acceptKey(stored, { code = "newcode1", at = 1001 }, 2000))
      assert.is_nil(G.acceptKey(stored, { code = "newcode1", at = 999 }, 2000))
      assert.is_nil(G.acceptKey(stored, { code = "oldcode1", at = 1000 }, 2000)) -- the same: nothing to do
      assert.are.same({ code = "first1", at = 5 }, G.acceptKey(nil, { code = "first1", at = 5 }, 2000))
    end)

    it("never takes a time from the future, a bad time or a code that is not clean", function()
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", at = 2000 + G.FUTURE_SLACK + 1 }, 2000))
      assert.is_table(G.acceptKey(nil, { code = "abcdefg", at = 2000 + G.FUTURE_SLACK }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", at = 10.5 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", at = 0 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abcdefg", at = "10" }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = " abcdefg", at = 10 }, 2000))
      assert.is_nil(G.acceptKey(nil, { code = "abc", at = 10 }, 2000))
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

    it("drops members who left, and the longest unseen beyond the limit", function()
      local roster = G.updateRoster(nil, { ["Player-1"] = { name = "Ada Lovewell", online = true } }, 100)
      G.updateRoster(roster, { ["Player-2"] = { name = "Cora Lovewell", online = true } }, 200)
      assert.are.same({ ["Player-2"] = { name = "Cora Lovewell", seen = 200 } }, roster)
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

  it("cleans a requester's display name", function()
    assert.are.equal("Ada", G.cleanDisplayName(" Ada "))
    assert.are.equal("Adacffff", G.cleanDisplayName("Ada|cffff"))
    assert.are.equal(G.DISPLAY_MAX, #G.cleanDisplayName(string.rep("x", 40)))
    assert.is_nil(G.cleanDisplayName(""))
    assert.is_nil(G.cleanDisplayName(5))
  end)
end)
