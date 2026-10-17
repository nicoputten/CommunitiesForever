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
