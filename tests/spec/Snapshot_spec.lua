local helpers = require("helpers")

describe("Snapshot", function()
  local Snapshot

  -- overrides cannot carry nil; list fields to drop in `without`.
  local function info(overrides, without)
    local base = {
      guid = "Player-4619-01627852",
      name = "Ves Doombringer",
      classFile = "PALADIN",
      raceID = 6,
      level = 11,
      faction = "Horde",
      realm = "Classic Beta PvP",
      ilvl = 12.75,
      professions = {
        { name = "Mining", rank = 64, max = 150, skillLine = 186 },
        { name = "Cooking", rank = 2, max = 75, skillLine = 185 },
      },
      battleTag = "Vestras#2858",
    }
    for k, v in pairs(overrides or {}) do base[k] = v end
    for _, k in ipairs(without or {}) do base[k] = nil end
    return base
  end

  local function emptyRecord()
    return { version = 0, chars = {} }
  end

  before_each(function()
    local ns = {}
    helpers.loadAddonFile("src/core/Merge.lua", ns)
    Snapshot = helpers.loadAddonFile("src/core/Snapshot.lua", ns)
  end)

  describe("build", function()
    it("copies all Char fields and keys professions by skillLine", function()
      local char = Snapshot.build(info())
      assert.are.same({
        guid = "Player-4619-01627852",
        name = "Ves Doombringer",
        classFile = "PALADIN",
        raceID = 6,
        level = 11,
        faction = "Horde",
        realm = "Classic Beta PvP",
        ilvl = 12,
        professions = {
          [186] = { name = "Mining", rank = 64, max = 150 },
          [185] = { name = "Cooking", rank = 2, max = 75 },
        },
      }, char)
    end)

    it("floors the item level", function()
      assert.are.equal(1, Snapshot.build(info({ ilvl = 1.5625 })).ilvl)
    end)

    it("keeps ilvl nil when unavailable", function()
      assert.is_nil(Snapshot.build(info(nil, { "ilvl" })).ilvl)
    end)

    it("skips professions without a skillLine", function()
      local char = Snapshot.build(info({ professions = { { name = "Odd", rank = 1, max = 1 } } }))
      assert.are.same({}, char.professions)
    end)

    it("does not include battleTag or updatedAt", function()
      local char = Snapshot.build(info())
      assert.is_nil(char.battleTag)
      assert.is_nil(char.updatedAt)
    end)
  end)

  describe("equal", function()
    it("is true for identical snapshots", function()
      assert.is_true(Snapshot.equal(Snapshot.build(info()), Snapshot.build(info())))
    end)

    it("ignores updatedAt", function()
      local a, b = Snapshot.build(info()), Snapshot.build(info())
      a.updatedAt, b.updatedAt = 1, 2
      assert.is_true(Snapshot.equal(a, b))
    end)

    it("ignores ilvl changes within the same whole level", function()
      assert.is_true(Snapshot.equal(Snapshot.build(info({ ilvl = 12.1 })), Snapshot.build(info({ ilvl = 12.9 }))))
    end)

    it("detects a changed scalar field", function()
      for field, value in pairs({ level = 12, ilvl = 20, name = "X", realm = "Y", faction = "Alliance", raceID = 2,
                                  classFile = "MAGE", guid = "Player-1-2" }) do
        assert.is_false(Snapshot.equal(Snapshot.build(info()), Snapshot.build(info({ [field] = value }))), field)
      end
    end)

    it("detects a profession rank change", function()
      local changed = info({ professions = { { name = "Mining", rank = 65, max = 150, skillLine = 186 },
                                             { name = "Cooking", rank = 2, max = 75, skillLine = 185 } } })
      assert.is_false(Snapshot.equal(Snapshot.build(info()), Snapshot.build(changed)))
    end)

    it("detects an added or removed profession", function()
      local fewer = info({ professions = { { name = "Mining", rank = 64, max = 150, skillLine = 186 } } })
      assert.is_false(Snapshot.equal(Snapshot.build(info()), Snapshot.build(fewer)))
      assert.is_false(Snapshot.equal(Snapshot.build(fewer), Snapshot.build(info())))
    end)

    it("handles nil", function()
      assert.is_true(Snapshot.equal(nil, nil))
      assert.is_false(Snapshot.equal(nil, Snapshot.build(info())))
    end)
  end)

  describe("markPlayed", function()
    it("sets lastPlayed without bumping the version", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      Snapshot.markPlayed(record, "Player-4619-01627852", 7000)
      assert.are.equal(7000, record.chars["Player-4619-01627852"].lastPlayed)
      assert.are.equal(5000, record.version)
      assert.is_false(Snapshot.apply(record, info(), 8000)) -- lastPlayed is not a synced-field change
    end)

    it("ignores unknown characters", function()
      local record = emptyRecord()
      Snapshot.markPlayed(record, "Player-1-X", 7000)
      Snapshot.markPlayed(record, nil, 7000)
      assert.are.same({}, record.chars)
    end)
  end)

  describe("apply", function()
    it("stores a new character and bumps the version", function()
      local record = emptyRecord()
      assert.is_true(Snapshot.apply(record, info(), 5000))
      local char = record.chars["Player-4619-01627852"]
      assert.are.equal(11, char.level)
      assert.are.equal(5000, char.updatedAt)
      assert.are.equal(5000, record.version)
    end)

    it("does not bump for an identical snapshot", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      assert.is_false(Snapshot.apply(record, info(), 6000))
      assert.are.equal(5000, record.version)
      assert.are.equal(5000, record.chars["Player-4619-01627852"].updatedAt)
    end)

    it("bumps on a real change", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      assert.is_true(Snapshot.apply(record, info({ level = 12 }), 6000))
      assert.are.equal(6000, record.version)
      assert.are.equal(12, record.chars["Player-4619-01627852"].level)
      assert.are.equal(6000, record.chars["Player-4619-01627852"].updatedAt)
    end)

    it("keeps the version increasing when server time lags", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      Snapshot.apply(record, info({ level = 12 }), 4000)
      assert.are.equal(5001, record.version)
    end)

    it("keeps other characters", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      Snapshot.apply(record, info({ guid = "Player-4619-0000AAAA", name = "Alt One" }), 6000)
      assert.is_not_nil(record.chars["Player-4619-01627852"])
      assert.is_not_nil(record.chars["Player-4619-0000AAAA"])
    end)

    it("stores the battleTag without bumping", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      record.battleTag = nil
      assert.is_false(Snapshot.apply(record, info(), 6000))
      assert.are.equal("Vestras#2858", record.battleTag)
    end)

    it("keeps a known battleTag when BNet is unavailable", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      Snapshot.apply(record, info({ level = 12 }, { "battleTag" }), 6000)
      assert.are.equal("Vestras#2858", record.battleTag)
    end)

    it("keeps lastPlayed when a character is re-stored", function()
      local record = emptyRecord()
      Snapshot.apply(record, info(), 5000)
      Snapshot.markPlayed(record, "Player-4619-01627852", 5100)
      Snapshot.apply(record, info({ level = 12 }), 6000)
      assert.are.equal(5100, record.chars["Player-4619-01627852"].lastPlayed)
    end)

    it("ignores info without a GUID", function()
      local record = emptyRecord()
      assert.is_false(Snapshot.apply(record, { battleTag = "Vestras#2858" }, 5000))
      assert.are.same({}, record.chars)
      assert.are.equal(0, record.version)
    end)
  end)
end)
