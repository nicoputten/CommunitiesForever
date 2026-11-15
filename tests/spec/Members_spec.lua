local helpers = require("helpers")

describe("Members", function()
  local Members

  local function info(overrides)
    local base = { memberId = 1, guid = "Player-1-A", name = "Ves Doombringer", classID = 2, level = 11,
                   zone = "Durotar", presence = 1, race = 6, faction = 0, isSelf = true, role = 1 }
    for k, v in pairs(overrides or {}) do base[k] = v end
    return base
  end

  before_each(function()
    Members = helpers.loadAddonFile("src/core/Members.lua", helpers.coreNs())
  end)

  describe("build", function()
    it("keys members by GUID with the tracked fields only", function()
      assert.are.same({
        ["Player-1-A"] = { name = "Ves Doombringer", classID = 2, level = 11, zone = "Durotar",
                           presence = 1, raceID = 6, faction = 0, role = 1 },
      }, Members.build({ info() }))
    end)

    it("skips members without a GUID", function()
      assert.are.same({}, Members.build({ info({ guid = false }) }))
      local noGuid = info()
      noGuid.guid = nil
      assert.are.same({}, Members.build({ noGuid }))
    end)

    it("handles nil and empty input", function()
      assert.are.same({}, Members.build(nil))
      assert.are.same({}, Members.build({}))
    end)
  end)

  describe("recordLocations", function()
    it("remembers the zone of in-game members and keeps it after they log off", function()
      local locations = {}
      Members.recordLocations(locations, Members.build({ info({ zone = "The Barrens", presence = 1 }) }), 500)
      assert.are.same({ ["Player-1-A"] = { zone = "The Barrens", seenAt = 500 } }, locations)

      Members.recordLocations(locations, Members.build({ info({ zone = "", presence = 3 }) }), 900)
      assert.are.same({ zone = "The Barrens", seenAt = 500 }, locations["Player-1-A"])
    end)

    it("counts Away and Busy as in game, Mobile not", function()
      for presence, expected in pairs({ [4] = true, [5] = true, [2] = false }) do
        local locations = {}
        Members.recordLocations(locations, Members.build({ info({ presence = presence }) }), 1)
        assert.are.equal(expected, locations["Player-1-A"] ~= nil, "presence " .. presence)
      end
    end)
  end)

  describe("level (CF-123)", function()
    it("takes the higher of the roster's and the record's level", function()
      assert.are.equal(4, Members.level(1, 4))
      assert.are.equal(12, Members.level(12, 11))
      assert.are.equal(9, Members.level(9, 9))
    end)

    it("takes the one there is", function()
      assert.are.equal(7, Members.level(7, nil))
      assert.are.equal(4, Members.level(nil, 4))
      assert.is_nil(Members.level(nil, nil))
    end)

    it("ignores values that are not numbers (a secret read as nil, a broken record)", function()
      assert.are.equal(5, Members.level("12", 5))
      assert.are.equal(5, Members.level(5, false))
      assert.is_nil(Members.level({}, "x"))
    end)
  end)

  describe("recordOwn", function()
    local GUID = "Player-1-A"

    it("writes the own zone with the time", function()
      local locations = { [GUID] = { zone = "Westfall", seenAt = 100 } }
      assert.is_true(Members.recordOwn(locations, GUID, "Hillsbrad Foothills", 500))
      assert.are.same({ [GUID] = { zone = "Hillsbrad Foothills", seenAt = 500 } }, locations)
    end)

    it("writes the same zone again with a newer time", function()
      local locations = { [GUID] = { zone = "Westfall", seenAt = 100 } }
      assert.is_true(Members.recordOwn(locations, GUID, "Westfall", 200))
      assert.are.equal(200, locations[GUID].seenAt)
    end)

    it("keeps the old entry for an empty or unknown zone", function()
      for _, zone in ipairs({ "", false, 7 }) do
        local locations = { [GUID] = { zone = "Westfall", seenAt = 100 } }
        assert.is_false(Members.recordOwn(locations, GUID, zone, 500))
        assert.are.same({ zone = "Westfall", seenAt = 100 }, locations[GUID])
      end
      local locations = { [GUID] = { zone = "Westfall", seenAt = 100 } }
      assert.is_false(Members.recordOwn(locations, GUID, nil, 500))
      assert.are.same({ zone = "Westfall", seenAt = 100 }, locations[GUID])
    end)

    it("writes nothing without a GUID, a time or a table", function()
      local locations = {}
      assert.is_false(Members.recordOwn(locations, nil, "Westfall", 500))
      assert.is_false(Members.recordOwn(locations, "", "Westfall", 500))
      assert.is_false(Members.recordOwn(locations, GUID, "Westfall", nil))
      assert.are.same({}, locations)
      assert.is_false(Members.recordOwn(nil, GUID, "Westfall", 500))
    end)

    it("never moves seenAt back", function()
      local locations = { [GUID] = { zone = "Westfall", seenAt = 900 } }
      assert.is_false(Members.recordOwn(locations, GUID, "Duskwood", 500))
      assert.are.same({ zone = "Westfall", seenAt = 900 }, locations[GUID])
    end)

    it("overwrites an entry of an older shape", function()
      local locations = { [GUID] = { zone = "Westfall" } }
      assert.is_true(Members.recordOwn(locations, GUID, "Duskwood", 500))
      assert.are.same({ zone = "Duskwood", seenAt = 500 }, locations[GUID])
    end)
  end)

  describe("equal", function()
    it("is true for the same members", function()
      assert.is_true(Members.equal(Members.build({ info() }), Members.build({ info({ isSelf = false }) })))
    end)

    it("detects a changed field", function()
      for field, value in pairs({ name = "X", classID = 9, level = 12, zone = "Barrens", presence = 3,
                                  race = 2, faction = 1 }) do
        assert.is_false(Members.equal(Members.build({ info() }), Members.build({ info({ [field] = value }) })), field)
      end
    end)

    it("detects added and removed members", function()
      local one = Members.build({ info() })
      local two = Members.build({ info(), info({ guid = "Player-1-B", memberId = 2 }) })
      assert.is_false(Members.equal(one, two))
      assert.is_false(Members.equal(two, one))
    end)
  end)
end)
