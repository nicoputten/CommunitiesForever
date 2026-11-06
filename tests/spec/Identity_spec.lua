local helpers = require("helpers")

describe("Identity (CF-28)", function()
  local Identity
  local OWN = { battleTag = "Me#1", accountId = "aaaaaaaaaaaa" }

  before_each(function()
    Identity = helpers.loadAddonFile("src/core/Identity.lua", helpers.coreNs())
  end)

  it("makes 12-character hex account IDs", function()
    local n = 0
    local id = Identity.newAccountId(function(max)
      n = n % max + 1
      return n
    end)
    assert.are.equal("0123456789ab", id)
    assert.is_true(Identity.isAccountId(id))
    assert.is_false(Identity.isAccountId("xyz"))
    assert.is_false(Identity.isAccountId("Me#1"))
  end)

  it("puts only account-ID keys on the community wire", function()
    local people = { ["Ben#2"] = { aid = "bbbbbbbbbbbb" }, ["Cid#3"] = {}, ["aid:cccccccccccc"] = {} }
    assert.are.equal("aid:bbbbbbbbbbbb", Identity.toCommunity(people, OWN, "Ben#2"))
    assert.is_nil(Identity.toCommunity(people, OWN, "Cid#3")) -- no account ID known: not shared
    assert.are.equal("aid:cccccccccccc", Identity.toCommunity(people, OWN, "aid:cccccccccccc"))
    assert.are.equal("aid:aaaaaaaaaaaa", Identity.toCommunity(people, OWN, "Me#1"))
    assert.are.same({ ["aid:bbbbbbbbbbbb"] = 5, ["aid:cccccccccccc"] = 7 },
      Identity.knownForCommunity(people, OWN, { ["Ben#2"] = 5, ["Cid#3"] = 6, ["aid:cccccccccccc"] = 7 }))
  end)

  it("maps keys from the wire to local keys", function()
    local people = { ["Ben#2"] = { aid = "bbbbbbbbbbbb" } }
    assert.are.same({ "Ben#2", false }, { Identity.fromWire(people, OWN, "aid:bbbbbbbbbbbb") })
    assert.are.same({ "aid:dddddddddddd", false }, { Identity.fromWire(people, OWN, "aid:dddddddddddd") })
    assert.are.same({ "Me#1", true }, { Identity.fromWire(people, OWN, "aid:aaaaaaaaaaaa") })
    assert.are.same({ "Me#1", true }, { Identity.fromWire(people, OWN, "Me#1") })
    assert.are.same({ "Ben#2", false }, { Identity.fromWire(people, OWN, "Ben#2") })
  end)

  it("finds the person whose record lists a character", function()
    local people = { ["aid:dddddddddddd"] = { chars = { G1 = {} } } }
    assert.are.equal("aid:dddddddddddd", Identity.personOfGuid(people, "G1"))
    assert.is_nil(Identity.personOfGuid(people, "G9"))
  end)

  describe("bindAccountId (a HELLO from a known person's character)", function()
    it("learns the account ID of a BattleTag person without one", function()
      local people = { ["Ann#1"] = { chars = { G1 = {} } } }
      assert.is_true(Identity.bindAccountId(people, "Ann#1", "aid:bbbbbbbbbbbb"))
      assert.are.equal("bbbbbbbbbbbb", people["Ann#1"].aid)
      assert.are.equal("Ann#1", (Identity.fromWire(people, OWN, "aid:bbbbbbbbbbbb")))
    end)

    it("never overwrites a known account ID", function()
      local people = { ["Ann#1"] = { aid = "cccccccccccc" } }
      assert.is_false(Identity.bindAccountId(people, "Ann#1", "aid:bbbbbbbbbbbb"))
      assert.are.equal("cccccccccccc", people["Ann#1"].aid)
    end)

    it("never takes an account ID another person already has", function()
      local people = { ["Ann#1"] = {}, ["Ben#2"] = { aid = "bbbbbbbbbbbb" } }
      assert.is_false(Identity.bindAccountId(people, "Ann#1", "aid:bbbbbbbbbbbb"))
      assert.is_nil(people["Ann#1"].aid)
    end)

    it("ignores unknown senders, aid-keyed people and keys that are no account ID", function()
      local people = { ["Ann#1"] = {}, ["aid:dddddddddddd"] = {} }
      assert.is_false(Identity.bindAccountId(people, "member:G9", "aid:bbbbbbbbbbbb"))
      assert.is_false(Identity.bindAccountId(people, "aid:dddddddddddd", "aid:bbbbbbbbbbbb"))
      assert.is_false(Identity.bindAccountId(people, "Ann#1", "Ann#1"))
      assert.is_false(Identity.bindAccountId(people, "Ann#1", "aid:not-an-id"))
      assert.is_nil(people["Ann#1"].aid)
    end)
  end)

  describe("isBattleTag (CF-90)", function()
    it("accepts a name, # and 3 to 10 digits", function()
      assert.is_true(Identity.isBattleTag("Ada#1001"))
      assert.is_true(Identity.isBattleTag("Ad\195\169le#21234"))
      for _, bad in ipairs({ "Ada", "Ada#", "Ada#12", "Ada#12345678901", "#1001", "aid:bbbbbbbbbbbb", "Ada #1001",
                             "member:G1#1001", "Ada#10a1", "A#1#1001", string.rep("a", 40) .. "#1001", 1001 }) do
        assert.is_false(Identity.isBattleTag(bad), tostring(bad))
      end
    end)
  end)

  describe("claimBattleTag (CF-90, a community member says their own BattleTag)", function()
    local AID, BID = "aid:bbbbbbbbbbbb", "bbbbbbbbbbbb"
    local CTX = { ownBattleTag = "Me#1001", ownAccountId = "aaaaaaaaaaaa", friends = { ["Fay#1006"] = true },
                  presence = { G7 = { battleTag = "Fay#1006" } }, characters = { G8 = "Gus#1007" } }

    local function stored()
      return { [AID] = { version = 5, aid = BID, displayName = "Ben", chars = { G1 = { name = "Ben Example" } } } }
    end

    it("re-keys an aid: person to the BattleTag and keeps the account ID", function()
      local people = stored()
      assert.is_true(Identity.claimBattleTag(people, AID, "Ben#1002", "G1", CTX))
      assert.is_nil(people[AID])
      assert.are.equal(BID, people["Ben#1002"].aid)
      assert.are.equal("Ben", people["Ben#1002"].displayName)
      assert.are.equal("Ben#1002", (Identity.fromWire(people, OWN, AID)))
      assert.are.equal(AID, Identity.toCommunity(people, OWN, "Ben#1002"))
    end)

    it("binds the account ID to a stored BattleTag person who lists the character (the caller absorbs)", function()
      local people = stored()
      people["Ben#1002"] = { version = 4, chars = { G1 = {} } }
      assert.is_true(Identity.claimBattleTag(people, AID, "Ben#1002", "G1", CTX))
      assert.are.equal(BID, people["Ben#1002"].aid)
      assert.is_not_nil(people[AID]) -- left for Merge.absorb
    end)

    it("changes nothing when there is nothing stored yet or it is known already", function()
      assert.is_false(Identity.claimBattleTag({}, AID, "Ben#1002", "G1", CTX))
      local people = { ["Ben#1002"] = { aid = BID, chars = { G1 = {} } } }
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G1", CTX))
    end)

    it("refuses an invalid BattleTag, your own, and keys that are no account ID", function()
      for _, args in ipairs({ { AID, "Ben" }, { AID, "Me#1001" }, { "aid:aaaaaaaaaaaa", "Ben#1002" },
                              { "Ben#1002", "Ben#1002" }, { "aid:nope", "Ben#1002" } }) do
        local people = stored()
        assert.is_false(Identity.claimBattleTag(people, args[1], args[2], "G1", CTX))
        assert.is_not_nil(people[AID])
      end
    end)

    it("never takes a Battle.net friend's BattleTag or overrides a presence link", function()
      local people = stored()
      assert.is_false(Identity.claimBattleTag(people, AID, "Fay#1006", "G1", CTX)) -- a current friend
      people[AID].chars.G7, people[AID].chars.G8 = {}, {}
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G7", CTX)) -- G7 is Fay's (stored link)
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G8", CTX)) -- G8 is Gus's (live)
      assert.is_true(Identity.claimBattleTag(people, AID, "Gus#1007", "G8", { characters = { G8 = "Gus#1007" } }))
    end)

    it("never takes a BattleTag that belongs to another account ID", function()
      local people = stored()
      people["Ben#1002"] = { aid = "cccccccccccc", chars = { G1 = {} } }
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G1", CTX))
      assert.are.equal("cccccccccccc", people["Ben#1002"].aid)
      assert.is_not_nil(people[AID])
    end)

    it("refuses when the account ID is known under another BattleTag", function()
      local people = { ["Bob#2002"] = { aid = BID, chars = { G1 = {} } } }
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G1", CTX))
      assert.is_nil(people["Ben#1002"])
    end)

    it("refuses a character that is not the account's (posing with a learned account ID)", function()
      local people = stored()
      assert.is_false(Identity.claimBattleTag(people, AID, "Evil#6666", "G9", CTX)) -- G9 not in Ben's record
      people["Cat#3003"] = { chars = { G9 = {} } }
      people[AID].chars = {}
      assert.is_false(Identity.claimBattleTag(people, AID, "Evil#6666", "G9", CTX)) -- G9 is Cat's
      people["Cat#3003"] = nil
      people["Ben#1002"] = { chars = { G2 = {} } }
      assert.is_false(Identity.claimBattleTag(people, AID, "Ben#1002", "G9", CTX)) -- stored Ben does not list G9
    end)
  end)

  describe("claimBattleTag for a friend who appears offline (CF-97, V87)", function()
    local AID, BID = "aid:bbbbbbbbbbbb", "bbbbbbbbbbbb"
    local BEN = "Ben#1002"

    local function stored()
      return { [AID] = { version = 5, aid = BID, displayName = "Ben", chars = { G1 = { name = "Ben Example" } } } }
    end

    -- Ben is a Battle.net friend; online = who Battle.net shows in Forever now.
    local function ctx(online, extra)
      local c = { ownBattleTag = "Me#1001", ownAccountId = "aaaaaaaaaaaa", friends = { [BEN] = true }, online = online }
      for k, v in pairs(extra or {}) do c[k] = v end
      return c
    end

    it("takes a friend's BattleTag when Battle.net does not show them in Forever", function()
      local people = stored()
      assert.is_true(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({})))
      assert.is_nil(people[AID])
      assert.are.equal(BID, people[BEN].aid)
      assert.are.equal(BEN, (Identity.fromWire(people, OWN, AID)))
    end)

    it("refuses while Battle.net shows the friend in Forever, from any character", function()
      local online = { [BEN] = { guid = "G1" } }
      local people = stored()
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx(online))) -- their own: Battle.net links
      online = { [BEN] = { guid = "G5" } }
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx(online))) -- another character
      assert.is_not_nil(people[AID])
      assert.is_nil(people[BEN])
    end)

    it("refuses when it is not known who Battle.net shows (no online list)", function()
      local people = stored()
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx(nil)))
      assert.is_not_nil(people[AID])
    end)

    it("takes it before the Battle.net friends are read, like any BattleTag", function()
      local people = stored()
      assert.is_true(Identity.claimBattleTag(people, AID, BEN, "G1", { friends = {}, online = {} }))
      assert.are.equal(BID, people[BEN].aid)
    end)

    it("changes nothing once the friend shows online later: Battle.net agrees", function()
      local people = stored()
      assert.is_true(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({})))
      local online = { [BEN] = { guid = "G1" } }
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx(online, { characters = { G1 = BEN } })))
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({}))) -- already known by it
      assert.are.equal(BID, people[BEN].aid)
      assert.are.equal(BEN, (Identity.fromWire(people, OWN, AID)))
    end)

    it("keeps the guards: a friend synced before keeps their BattleTag, links and records decide", function()
      -- Ben synced over Battle.net before (his record carries his account ID): really offline now.
      local people = stored()
      people[BEN] = { version = 9, aid = "cccccccccccc", chars = { G2 = {} } }
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({})))
      assert.are.equal("cccccccccccc", people[BEN].aid)
      -- Synced through a relay (no account ID): only a character in Ben's record may claim it.
      people[BEN] = { version = 9, chars = { G2 = {} } }
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({})))
      -- The sending character is linked to another BattleTag (stored or live presence).
      people = stored()
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1",
        ctx({}, { presence = { G1 = { battleTag = "Fay#1006" } } })))
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G1", ctx({}, { characters = { G1 = "Fay#1006" } })))
      -- Someone else's character, or one the aid: person's record does not list.
      people["Cat#3003"] = { chars = { G9 = {} } }
      assert.is_false(Identity.claimBattleTag(people, AID, BEN, "G9", ctx({})))
      assert.is_not_nil(people[AID])
    end)
  end)
end)
