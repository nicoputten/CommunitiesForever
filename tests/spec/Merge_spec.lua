local helpers = require("helpers")

describe("Merge", function()
  local Merge
  local SJAAK = "Sjaakovich#2232"

  local function record(overrides)
    local r = { t = "RECORD", bt = SJAAK, displayName = "Sjaak", version = 2000,
                chars = { ["Player-1-G"] = { name = "Garraka", level = 11 } } }
    for k, v in pairs(overrides or {}) do r[k] = v end
    return r
  end

  before_each(function()
    Merge = helpers.loadAddonFile("src/core/Merge.lua", {})
  end)

  describe("nextVersion", function()
    it("uses server time when it is ahead", function()
      assert.are.equal(5000, Merge.nextVersion(10, 5000))
    end)

    it("increments when the previous version is at or ahead of server time", function()
      assert.are.equal(5001, Merge.nextVersion(5000, 5000))
      assert.are.equal(9001, Merge.nextVersion(9000, 5000))
    end)

    it("treats a missing previous version as 0", function()
      assert.are.equal(1, Merge.nextVersion(nil, 0))
      assert.are.equal(5000, Merge.nextVersion(nil, 5000))
    end)
  end)

  describe("accept", function()
    it("accepts a newer record from its owner", function()
      assert.is_true(Merge.accept(nil, record(), SJAAK))
      assert.is_true(Merge.accept({ version = 1999 }, record(), SJAAK))
    end)

    it("rejects a record from an unknown sender", function()
      assert.are.same({ false, "sender" }, { Merge.accept(nil, record(), nil) })
    end)

    it("rejects a record whose bt is not the sender's BattleTag (spoof)", function()
      assert.are.same({ false, "sender" }, { Merge.accept(nil, record({ bt = "Other#1111" }), SJAAK) })
      assert.are.same({ false, "sender" }, { Merge.accept(nil, record(), "Other#1111") })
    end)

    it("rejects older and equal versions", function()
      assert.are.same({ false, "old" }, { Merge.accept({ version = 2000 }, record(), SJAAK) })
      assert.are.same({ false, "old" }, { Merge.accept({ version = 3000 }, record(), SJAAK) })
    end)

    it("rejects malformed records", function()
      assert.are.same({ false, "malformed" }, { Merge.accept(nil, "x", SJAAK) })
      assert.are.same({ false, "malformed" }, { Merge.accept(nil, record({ version = "2000" }), SJAAK) })
      assert.are.same({ false, "malformed" }, { Merge.accept(nil, record({ chars = "x" }), SJAAK) })
      assert.are.same({ false, "malformed" }, { Merge.accept(nil, record({ chars = { [1] = {} } }), SJAAK) })
      assert.are.same({ false, "malformed" }, { Merge.accept(nil, record({ chars = { G = "x" } }), SJAAK) })
    end)
  end)

  describe("accept relayed records (CF-20)", function()
    local ANNA = "Anna#3333" -- relays Sjaak's record
    local function relay(overrides)
      local r = { ownBattleTag = "Vestras#2858", now = 2000, members = { ["Player-1-G"] = {} } }
      for k, v in pairs(overrides or {}) do r[k] = v end
      return r
    end

    it("rejects relayed records when relaying is not enabled", function()
      assert.are.same({ false, "sender" }, { Merge.accept(nil, record(), ANNA) })
    end)

    it("accepts a newer relayed record with a community character", function()
      assert.is_true(Merge.accept(nil, record(), ANNA, relay()))
      assert.is_true(Merge.accept({ version = 1999, via = "X#1" }, record(), ANNA, relay()))
    end)

    it("rejects a relayed copy of our own record", function()
      assert.are.same({ false, "own" }, { Merge.accept(nil, record({ bt = "Vestras#2858" }), ANNA, relay()) })
    end)

    it("rejects a relayed record that is not newer, also over the owner's record", function()
      assert.are.same({ false, "old" }, { Merge.accept({ version = 2000 }, record(), ANNA, relay()) })
      assert.are.same({ false, "old" }, { Merge.accept({ version = 2000, via = "X#1" }, record(), ANNA, relay()) })
    end)

    it("rejects a relayed version more than 5 minutes in the future", function()
      assert.is_true(Merge.accept(nil, record({ version = 2300 }), ANNA, relay()))
      assert.are.same({ false, "future" }, { Merge.accept(nil, record({ version = 2301 }), ANNA, relay()) })
    end)

    it("rejects a relayed record without a character in our community", function()
      assert.are.same({ false, "community" }, { Merge.accept(nil, record(), ANNA, relay({ members = {} })) })
    end)

    it("lets the owner's record replace a relayed copy, even at a lower version", function()
      local relayed = { version = 9000, via = ANNA }
      assert.is_true(Merge.accept(relayed, record({ version = 2000 }), SJAAK, relay()))
      local direct = { version = 9000 }
      assert.are.same({ false, "old" }, { Merge.accept(direct, record({ version = 2000 }), SJAAK, relay()) })
    end)
  end)

  describe("relay helpers", function()
    local people = {
      [SJAAK] = { version = 2000, displayName = "Sjaak", chars = { G = { name = "Garraka" } } },
      ["Out#1"] = { version = 50, chars = { X = { name = "Elsewhere" } } },
    }

    it("lists versions of people with a community character", function()
      assert.are.same({ [SJAAK] = 2000 }, Merge.knownVersions(people, { G = {} }))
    end)

    it("lists everything when the community is not visible on this character", function()
      assert.are.same({ [SJAAK] = 2000, ["Out#1"] = 50 }, Merge.knownVersions(people, {}))
    end)

    it("turns a stored record into a RECORD message", function()
      assert.are.same({ t = "RECORD", bt = SJAAK, displayName = "Sjaak", version = 2000,
                        chars = { G = { name = "Garraka" } } }, Merge.relayRecord(people, SJAAK))
      assert.is_nil(Merge.relayRecord(people, "Nobody#1"))
    end)

    it("stores who relayed a record", function()
      local stored = {}
      Merge.store(stored, record(), 5, "Anna#3333")
      assert.are.equal("Anna#3333", stored[SJAAK].via)
      Merge.store(stored, record(), 6, SJAAK)
      assert.is_nil(stored[SJAAK].via)
    end)
  end)

  describe("levelUps (CF-16)", function()
    it("lists characters whose level went up, sorted by name", function()
      local old = { A = { name = "Zed", level = 10 }, B = { name = "Amy", level = 5 },
                    C = { name = "Same", level = 7 } }
      local new = { A = { name = "Zed", level = 12, updatedAt = 9 }, B = { name = "Amy", level = 6, updatedAt = 8 },
                    C = { name = "Same", level = 7 }, D = { name = "New", level = 3 } }
      assert.are.same({
        { guid = "B", name = "Amy", level = 6, updatedAt = 8 },
        { guid = "A", name = "Zed", level = 12, updatedAt = 9 },
      }, Merge.levelUps(old, new))
    end)

    it("ignores lower levels, missing levels and a missing old record", function()
      assert.are.same({}, Merge.levelUps({ A = { level = 10 } }, { A = { level = 9 } }))
      assert.are.same({}, Merge.levelUps({ A = {} }, { A = { level = 9 } }))
      assert.are.same({}, Merge.levelUps(nil, { A = { level = 9 } }))
    end)
  end)

  describe("store", function()
    it("stores displayName, version, receivedAt and chars", function()
      local people = {}
      Merge.store(people, record(), 5000)
      assert.are.same({ displayName = "Sjaak", version = 2000, receivedAt = 5000,
                        chars = { ["Player-1-G"] = { name = "Garraka", level = 11 } } }, people[SJAAK])
    end)

    it("ignores a non-string displayName", function()
      local people = {}
      Merge.store(people, record({ displayName = 5 }), 1)
      assert.is_nil(people[SJAAK].displayName)
    end)
  end)

  describe("outgoing record", function()
    it("contains all own characters (always shared, CF-17)", function()
      local own = { battleTag = "Vestras#2858", displayName = "Nico", version = 7000,
                    chars = { A = { name = "Ves" }, C = { name = "Alt outside" } } }
      assert.are.same({
        t = "RECORD", bt = "Vestras#2858", displayName = "Nico", version = 7000,
        chars = { A = { name = "Ves" }, C = { name = "Alt outside" } },
      }, Merge.outgoingRecord(own))
    end)

    it("handles a record without characters", function()
      assert.are.same({}, Merge.outgoingRecord({ battleTag = "X#1", version = 1 }).chars)
    end)
  end)
end)
