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
    Members = helpers.loadAddonFile("src/core/Members.lua", {})
  end)

  describe("build", function()
    it("keys members by GUID with the tracked fields only", function()
      assert.are.same({
        ["Player-1-A"] = { name = "Ves Doombringer", classID = 2, level = 11, zone = "Durotar",
                           presence = 1, raceID = 6, faction = 0 },
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
