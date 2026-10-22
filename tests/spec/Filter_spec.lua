local helpers = require("helpers")

describe("Filter (CF-36)", function()
  local Filter

  before_each(function()
    Filter = helpers.loadAddonFile("src/core/Filter.lua", {})
  end)

  local function row(extra)
    local r = { guid = "G1", name = "Ada Example", classFile = "MAGE", level = 24, zone = "Durotar",
                professions = { [197] = { name = "Tailoring", rank = 160, max = 225 },
                                [185] = { name = "Cooking", rank = 40, max = 75 } }, role = "dps" }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end

  local function match(text, r, owner)
    return Filter.matches(r or row(), owner or "Ada", Filter.parse(text))
  end

  describe("parse", function()
    it("reads words, word plus number, single numbers and ranges", function()
      assert.are.same({}, Filter.parse(""))
      assert.are.same({}, Filter.parse(nil))
      assert.are.same({ { text = "tailoring", number = 150 } }, Filter.parse("Tailoring 150"))
      assert.are.same({ { text = "mage" }, { min = 20, max = 30 } }, Filter.parse("mage 20-30"))
      assert.are.same({ { min = 20, max = 30 } }, Filter.parse("30-20"))
      assert.are.same({ { level = 24 } }, Filter.parse("24"))
      assert.are.same({ { text = "mage" }, { text = "tail", number = 100 } }, Filter.parse("mage, tail 100"))
      assert.are.same({ { text = "mage", number = 20 }, { level = 30 } }, Filter.parse("mage 20 30"))
    end)
  end)

  describe("matching a character", function()
    it("matches name, owner, class, role, profession and zone, on part of a word, any case", function()
      for _, text in ipairs({ "ada", "EXAMPLE", "Ad", "mage", "dps", "damage", "tail", "cooking", "durotar" }) do
        assert.is_true(match(text), text)
      end
      assert.is_true(match("healer", row({ role = "heal" })))
      assert.is_true(match("tank", row({ role = "dps", roleOverride = "tank" })))
      assert.is_false(match("warrior"))
      assert.is_false(match("mage", row({ classFile = "ROGUE" }))) -- not via "damage"
      assert.is_false(match("orgrimmar"))
    end)

    it("uses the class from the community list for members without a record", function()
      local member = { guid = "G2", name = "Bob Member", classID = 4, level = 12 }
      assert.is_true(match("rogue", member, nil))
      assert.is_false(match("tailoring", member, nil))
    end)

    it("reads a number after a profession as a minimum rank", function()
      assert.is_true(match("tailoring 150"))
      assert.is_true(match("tailoring 160"))
      assert.is_false(match("tailoring 161"))
      assert.is_false(match("mining 1"))
    end)

    it("reads a number after another word as its level, a lone number as a level, a-b as a range", function()
      assert.is_true(match("mage 24"))
      assert.is_false(match("mage 20"))
      assert.is_true(match("24"))
      assert.is_false(match("23"))
      assert.is_true(match("20-30"))
      assert.is_true(match("24-24"))
      assert.is_false(match("25-30"))
      local unknown = row()
      unknown.level = nil
      assert.is_false(match("20-30", unknown))
    end)

    it("needs every term", function()
      assert.is_true(match("mage tail 100 20-30"))
      assert.is_false(match("mage rogue"))
    end)
  end)

  describe("apply", function()
    local view

    before_each(function()
      view = {
        people = {
          { displayName = "Ada", chars = { row(), row({ guid = "G3", name = "Ada Alt", classFile = "PRIEST", level = 8,
                                                         professions = {} }) } },
          { displayName = "Bob", chars = { row({ guid = "G4", name = "Bob Main", classFile = "ROGUE", level = 30,
                                                 professions = {} }) } },
        },
        unlinked = { { guid = "U1", name = "Cy Stranger", classID = 8, level = 26 } },
        selfName = "kept",
      }
    end)

    it("keeps people with a matching character, only those characters, and counts them", function()
      local filtered, shown, total = Filter.apply(view, Filter.parse("mage"))
      assert.are.equal(1, #filtered.people)
      assert.are.same({ "G1" }, { filtered.people[1].chars[1].guid })
      assert.are.equal(1, #filtered.people[1].chars)
      assert.are.same({ "U1" }, { filtered.unlinked[1].guid }) -- classID 8 = mage
      assert.are.equal(2, shown)
      assert.are.equal(4, total)
      assert.are.equal("kept", filtered.selfName)
      assert.are.equal(2, #view.people[1].chars) -- the view itself is untouched
    end)

    it("returns the view unchanged without terms, and nothing on no match", function()
      local same, shown, total = Filter.apply(view, {})
      assert.are.equal(view, same)
      assert.are.equal(4, shown)
      assert.are.equal(4, total)
      local none, n = Filter.apply(view, Filter.parse("paladin"))
      assert.are.same({}, none.people)
      assert.are.same({}, none.unlinked)
      assert.are.equal(0, n)
    end)
  end)
end)
