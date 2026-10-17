local helpers = require("helpers")

describe("Linker", function()
  local Linker

  local ME, SJAAK, OTHER = "Vestras#2858", "Sjaakovich#2232", "Other#4444"

  local function member(name, presence, extra)
    local m = { name = name, classID = 8, level = 11, zone = "Durotar", presence = presence or 3, raceID = 2 }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
  end

  local function char(name, extra)
    local c = { guid = "?", name = name, classFile = "MAGE", level = 11, ilvl = 20, realm = "R",
                professions = { [186] = { name = "Mining", rank = 1, max = 75 } }, updatedAt = 100 }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
  end

  local function input(overrides)
    local base = {
      members = {},
      friends = { [SJAAK] = true, [OTHER] = true },
      online = {},
      people = {},
      presence = {},
      self = { battleTag = ME, chars = {} },
      selfGuid = "G-ME",
      nicknames = {},
    }
    for k, v in pairs(overrides or {}) do base[k] = v end
    return base
  end

  local function person(view, bt)
    for _, p in ipairs(view.people) do
      if p.battleTag == bt then return p end
    end
  end

  local function guids(rows)
    local list = {}
    for _, row in ipairs(rows) do list[#list + 1] = row.guid end
    return list
  end

  before_each(function()
    Linker = helpers.loadAddonFile("src/core/Linker.lua", {})
  end)

  describe("visibility", function()
    it("excludes non-members that are not in any record (presence only)", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 }, G2 = { battleTag = SJAAK, lastSeen = 1 } },
      }))
      assert.are.same({ "G1" }, guids(person(view, SJAAK).chars))
      assert.are.same({}, view.unlinked)
    end)
  end)

  describe("alts outside the community (CF-17)", function()
    it("shows a record alt under a person who has a member character, after the members", function()
      local view = Linker.build(input({
        members = { G1 = member("Zed Main") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        people = { [SJAAK] = { chars = { G3 = char("Alt Outside", { level = 30 }) } } },
      }))
      local rows = person(view, SJAAK).chars
      assert.are.same({ "G1", "G3" }, guids(rows))
      assert.is_true(rows[2].outside)
      assert.is_nil(rows[1].outside)
      assert.are.equal(30, rows[2].level)
      assert.are.equal("MAGE", rows[2].classFile)
      assert.are.equal("record", rows[2].linkSource)
      assert.are.same({}, view.unlinked)
    end)

    it("hides it when the person has no member character", function()
      local view = Linker.build(input({
        people = { [SJAAK] = { chars = { G3 = char("Alt Outside") } } },
      }))
      assert.are.same({}, view.people)
      assert.are.same({}, view.unlinked)
    end)

    it("hides it for someone who is not a friend", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        friends = { [SJAAK] = true },
        people = { [OTHER] = { chars = { G3 = char("Not My Friend's Alt") } } },
      }))
      assert.are.same({ "G1" }, guids(person(view, SJAAK).chars))
    end)

    it("turns into a normal member row when the character joins the community", function()
      local data = input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        people = { [SJAAK] = { chars = { G3 = char("Alt") } } },
      })
      assert.is_true(person(Linker.build(data), SJAAK).chars[2].outside)
      data.members.G3 = member("Alt")
      local rows = person(Linker.build(data), SJAAK).chars
      assert.are.equal(2, #rows)
      for _, row in ipairs(rows) do assert.is_nil(row.outside) end
    end)

    it("shows own alts outside the community, the current one as online", function()
      local view = Linker.build(input({
        members = { ["G-MAIN"] = member("Main", 3) },
        self = { battleTag = ME, chars = { ["G-MAIN"] = char("Main"), ["G-ME"] = char("Playing Now"),
                                           ["G-OLD"] = char("Old Alt") } },
      }))
      local rows = person(view, ME).chars
      assert.are.same({ "G-MAIN", "G-ME", "G-OLD" }, guids(rows))
      assert.is_true(rows[2].online)
      assert.is_true(rows[2].outside)
      assert.is_false(rows[3].online)
      assert.are.equal("G-ME", person(view, ME).currentChar.guid)
    end)

    it("marks a friend online on an outside alt, with that row as current character", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        people = { [SJAAK] = { chars = { G3 = char("Alt") } } },
        online = { [SJAAK] = { guid = "G3", name = "Alt" } },
      }))
      local sjaak = person(view, SJAAK)
      assert.are.equal("G3", sjaak.currentChar.guid)
      assert.is_true(sjaak.currentChar.outside)
      assert.is_true(sjaak.currentChar.online)
    end)

    it("drops a character removed from the community", function()
      local data = input({
        members = { G1 = member("Garraka"), G2 = member("Alt") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 }, G2 = { battleTag = SJAAK, lastSeen = 1 } },
      })
      assert.are.equal(2, #person(Linker.build(data), SJAAK).chars)
      data.members.G2 = nil
      assert.are.same({ "G1" }, guids(person(Linker.build(data), SJAAK).chars))
    end)

    it("omits people without any visible character", function()
      local view = Linker.build(input({
        online = { [SJAAK] = { guid = "G9", name = "Elsewhere" } },
        presence = { G9 = { battleTag = SJAAK, lastSeen = 1 } },
      }))
      assert.are.same({}, view.people)
    end)
  end)

  describe("linking", function()
    it("puts characters of a non-friend in Unlinked", function()
      local view = Linker.build(input({
        members = { G1 = member("Stranger") },
        presence = { G1 = { battleTag = "Gone#9999", lastSeen = 1 } },
        people = { ["Gone#9999"] = { chars = { G1 = char("Stranger") } } },
      }))
      assert.are.same({}, view.people)
      assert.are.same({ "G1" }, guids(view.unlinked))
    end)

    it("links a character by presence alone", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 42 } },
      }))
      local row = person(view, SJAAK).chars[1]
      assert.are.equal("G1", row.guid)
      assert.are.equal("presence", row.linkSource)
      assert.are.equal(42, row.lastSeen)
    end)

    it("links a record character only if the sender is a current friend", function()
      local data = input({
        members = { G1 = member("Garraka") },
        people = { [SJAAK] = { chars = { G1 = char("Garraka") } } },
      })
      assert.are.equal("record", person(Linker.build(data), SJAAK).chars[1].linkSource)

      data.friends = { [OTHER] = true } -- Sjaak is no longer a friend
      local view = Linker.build(data)
      assert.is_nil(person(view, SJAAK))
      assert.are.same({ "G1" }, guids(view.unlinked))
    end)

    it("lets presence win over a conflicting record", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        people = { [OTHER] = { chars = { G1 = char("Garraka", { updatedAt = 999 }) } } },
      }))
      assert.is_not_nil(person(view, SJAAK))
      assert.is_nil(person(view, OTHER))
    end)

    it("falls back to a record when presence points to a non-friend", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = "Gone#9999", lastSeen = 1 } },
        people = { [SJAAK] = { chars = { G1 = char("Garraka") } } },
      }))
      assert.are.equal("record", person(view, SJAAK).chars[1].linkSource)
    end)

    it("resolves two records claiming one character: newest updatedAt, then BattleTag", function()
      local data = input({
        members = { G1 = member("Garraka") },
        people = {
          [SJAAK] = { chars = { G1 = char("Garraka", { updatedAt = 100 }) } },
          [OTHER] = { chars = { G1 = char("Garraka", { updatedAt = 200 }) } },
        },
      })
      assert.is_not_nil(person(Linker.build(data), OTHER))
      data.people[OTHER].chars.G1.updatedAt = 100
      assert.is_not_nil(person(Linker.build(data), OTHER)) -- "Other#..." < "Sjaakovich#..."
    end)

    it("links own characters to self, ahead of presence and records", function()
      local view = Linker.build(input({
        members = { ["G-ME"] = member("Ves", 1), G2 = member("My Alt") },
        self = { battleTag = ME, chars = { G2 = char("My Alt", { classFile = "PALADIN" }) } },
        presence = { G2 = { battleTag = SJAAK, lastSeen = 1 } },
      }))
      local me = person(view, ME)
      assert.is_true(me.isSelf)
      assert.are.equal(2, #me.chars)
      assert.is_nil(person(view, SJAAK))
      assert.are.equal("self", me.chars[1].linkSource)
    end)

    it("groups own characters even when the own BattleTag is unknown", function()
      local view = Linker.build(input({
        members = { ["G-ME"] = member("Ves", 1) },
        self = { chars = {} },
      }))
      assert.are.equal(1, #view.people)
      assert.is_nil(view.people[1].battleTag)
      assert.is_true(view.people[1].isSelf)
      assert.are.equal("You", view.people[1].displayName)
    end)
  end)

  describe("rows", function()
    it("combines live community data with record data", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka", 1, { level = 12, zone = "Orgrimmar" }) },
        people = { [SJAAK] = { chars = { G1 = char("Garraka", { level = 11, ilvl = 25 }) } } },
      }))
      local row = person(view, SJAAK).chars[1]
      assert.are.equal(12, row.level) -- community level is live
      assert.are.equal("Orgrimmar", row.zone)
      assert.are.equal(25, row.ilvl)
      assert.are.equal("MAGE", row.classFile)
      assert.are.equal(8, row.classID)
      assert.are.equal("Mining", row.professions[186].name)
      assert.is_true(row.online)
    end)

    it("adds the last zone seen", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        locations = { G1 = { zone = "The Barrens", seenAt = 77 } },
      }))
      assert.are.equal("The Barrens", view.unlinked[1].lastZone)
      assert.are.equal(77, view.unlinked[1].lastZoneAt)
    end)

    it("treats Online, Away and Busy as online; Mobile and Offline not", function()
      for presence, expected in pairs({ [1] = true, [2] = false, [3] = false, [4] = true, [5] = true }) do
        local view = Linker.build(input({ members = { G1 = member("X", presence) } }))
        assert.are.equal(expected, view.unlinked[1].online, "presence " .. presence)
      end
    end)

    it("gives unlinked rows community data only", function()
      local view = Linker.build(input({ members = { G1 = member("Stranger", 1) } }))
      local row = view.unlinked[1]
      assert.are.equal("Stranger", row.name)
      assert.are.equal(11, row.level)
      assert.is_nil(row.ilvl)
      assert.is_nil(row.linkSource)
    end)
  end)

  describe("online and current character", function()
    it("marks a friend online in Forever and points to their current visible character", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka", 1), G2 = member("Alt") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 }, G2 = { battleTag = SJAAK, lastSeen = 1 } },
        online = { [SJAAK] = { guid = "G1", name = "Garraka", className = "Mage", level = 11 } },
      }))
      local sjaak = person(view, SJAAK)
      assert.is_true(sjaak.online)
      assert.are.equal("G1", sjaak.currentChar.guid)
      assert.are.equal(sjaak.chars[1], sjaak.currentChar)
    end)

    it("shows a current character outside the community as not visible", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        online = { [SJAAK] = { guid = "G9", name = "Outside", className = "Rogue", level = 5 } },
      }))
      assert.are.same({ guid = "G9", name = "Outside", className = "Rogue", level = 5, visible = false },
        person(view, SJAAK).currentChar)
    end)

    it("has no current character for an offline friend", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
      }))
      assert.is_false(person(view, SJAAK).online)
      assert.is_nil(person(view, SJAAK).currentChar)
    end)

    it("treats self as online on the current character", function()
      local view = Linker.build(input({ members = { ["G-ME"] = member("Ves", 1) } }))
      local me = person(view, ME)
      assert.is_true(me.online)
      assert.are.equal("G-ME", me.currentChar.guid)
    end)
  end)

  describe("display name", function()
    it("prefers nickname, then owner's displayName, then the BattleTag name part", function()
      assert.are.equal("Sjaak", Linker.displayName(SJAAK, "Sjaakie", "Sjaak"))
      assert.are.equal("Sjaakie", Linker.displayName(SJAAK, "Sjaakie", nil))
      assert.are.equal("Sjaakovich", Linker.displayName(SJAAK, nil, nil))
      assert.are.equal("Sjaakovich", Linker.displayName(SJAAK, "", ""))
    end)

    it("applies the rule in the view model", function()
      local view = Linker.build(input({
        members = { G1 = member("Garraka") },
        presence = { G1 = { battleTag = SJAAK, lastSeen = 1 } },
        people = { [SJAAK] = { displayName = "Sjaakie", chars = {} } },
        nicknames = { [SJAAK] = "Sjaak" },
      }))
      assert.are.equal("Sjaak", person(view, SJAAK).displayName)
    end)

    it("uses the own displayName for self", function()
      local view = Linker.build(input({
        members = { ["G-ME"] = member("Ves", 1) },
        self = { battleTag = ME, displayName = "Nico", chars = {} },
      }))
      assert.are.equal("Nico", person(view, ME).displayName)
    end)
  end)

  describe("sorting", function()
    it("sorts people online first, then by display name", function()
      local view = Linker.build(input({
        members = { A = member("a"), B = member("b"), C = member("c") },
        friends = { ["zed#1"] = true, ["Amy#2"] = true, ["bob#3"] = true },
        presence = {
          A = { battleTag = "zed#1", lastSeen = 1 },
          B = { battleTag = "Amy#2", lastSeen = 1 },
          C = { battleTag = "bob#3", lastSeen = 1 },
        },
        online = { ["zed#1"] = { guid = "A" } },
      }))
      local order = {}
      for _, p in ipairs(view.people) do order[#order + 1] = p.displayName end
      assert.are.same({ "zed", "Amy", "bob" }, order)
    end)

    it("sorts characters and unlinked rows online first, then by name", function()
      local view = Linker.build(input({
        members = { A = member("Zulu", 3), B = member("alpha", 3), C = member("Mike", 1) },
      }))
      assert.are.same({ "C", "B", "A" }, guids(view.unlinked))
    end)
  end)

  it("does not modify its input", function()
    local data = input({ members = { G1 = member("Garraka") } })
    data.self = nil
    Linker.build(data)
    assert.is_nil(data.self)
  end)
end)
