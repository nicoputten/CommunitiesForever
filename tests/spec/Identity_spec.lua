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
end)
