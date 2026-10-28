local helpers = require("helpers")

-- CF-49: Runs v2 in game, the same level fit and roles as the site (web WEB-47) and Discord.
describe("Runs v2 (CF-49)", function()
  local PlannedRuns

  before_each(function()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", {})
  end)

  describe("levelFit", function()
    -- Range 30-40 at every boundary.
    local cases = {
      { 30, "fits", "fits", true, true },
      { 40, "fits", "fits", true, true },
      { 35, "fits", "fits", true, true },
      { 41, "over", "+1 over", true, true },
      { 49, "over", "+9 over", true, true },
      { 50, "carry", "carry \194\183 +10", true, false },
      { 60, "carry", "carry \194\183 +20", true, false },
      { 29, "low", "1 below", true, false },
      { 25, "low", "5 below", true, false },
      { 24, "tooLow", "6 below", false, false },
      { 1, "tooLow", "29 below", false, false },
    }
    for _, c in ipairs(cases) do
      it("level " .. c[1] .. " is " .. c[3], function()
        local fit = PlannedRuns.levelFit(c[1], 30, 40)
        assert.are.equal(c[2], fit.kind)
        assert.are.equal(c[3], fit.label)
        assert.are.equal(c[4], fit.canPick)
        assert.are.equal(c[5], fit.suggested)
      end)
    end

    it("notes carries and low characters", function()
      assert.are.equal("Little XP for you here.", PlannedRuns.levelFit(50, 30, 40).note)
      assert.are.equal("This will be tough.", PlannedRuns.levelFit(27, 30, 40).note)
      assert.is_nil(PlannedRuns.levelFit(35, 30, 40).note)
    end)

    it("counts an unknown level as too low", function()
      local fit = PlannedRuns.levelFit(nil, 30, 40)
      assert.are.equal("tooLow", fit.kind)
      assert.are.equal("level unknown", fit.label)
      assert.is_false(fit.canPick)
    end)
  end)

  describe("rolesFor", function()
    local expected = {
      WARRIOR = { "tank", "dps" },
      PALADIN = { "tank", "heal", "dps" },
      DRUID = { "tank", "heal", "dps" },
      PRIEST = { "heal", "dps" },
      SHAMAN = { "heal", "dps" },
      MAGE = { "dps" },
      WARLOCK = { "dps" },
      HUNTER = { "dps" },
      ROGUE = { "dps" },
    }
    for class, roles in pairs(expected) do
      it(class, function()
        assert.are.same(roles, PlannedRuns.rolesFor(class))
      end)
    end

    it("gives every role for an unknown class, and a copy each time", function()
      assert.are.same({ "tank", "heal", "dps" }, PlannedRuns.rolesFor(nil))
      assert.are.same({ "tank", "heal", "dps" }, PlannedRuns.rolesFor("DEATHKNIGHT"))
      PlannedRuns.rolesFor("MAGE")[1] = "tank"
      assert.are.same({ "dps" }, PlannedRuns.rolesFor("MAGE"))
    end)

    it("starts on the character's own role when the class can play it", function()
      assert.are.equal("heal", PlannedRuns.defaultRole("DRUID", "heal"))
      assert.are.equal("tank", PlannedRuns.defaultRole("WARRIOR", "heal"))
      assert.are.equal("dps", PlannedRuns.defaultRole("MAGE", nil))
      assert.is_true(PlannedRuns.canPlay("SHAMAN", "heal"))
      assert.is_false(PlannedRuns.canPlay("SHAMAN", "tank"))
    end)
  end)

  describe("Runs.lua with role, fit and reserve", function()
    local function file(answers)
      return { v = 1, updatedAt = 1793120000,
               runs = { { id = "r-1", dungeon = "smarm", startsAt = 1793210400, answers = answers } } }
    end

    it("keeps fit and reserve when present", function()
      local data = PlannedRuns.validate(file({
        { guid = "Player-1-0000AAAA", name = "Ada Lovewell", answer = "maybe", role = "heal", reserve = true,
          fit = "carry \194\183 +12" },
      }))
      local a = data.runs[1].answers[1]
      assert.are.equal("heal", a.role)
      assert.is_true(a.reserve)
      assert.are.equal("carry \194\183 +12", a.fit)
    end)

    it("reads an older file without them as before", function()
      local data = PlannedRuns.validate(file({ { battleTag = "Bo#2002", answer = "in" } }))
      local a = data.runs[1].answers[1]
      assert.is_nil(a.role)
      assert.is_nil(a.reserve)
      assert.is_nil(a.fit)
    end)

    it("drops a wrong fit or reserve, and caps the fit", function()
      local data = PlannedRuns.validate(file({
        { name = "Ada Lovewell", answer = "in", reserve = "yes", fit = 12 },
        { name = "Bo Stone", answer = "in", fit = "|cffff0000" .. string.rep("x", 40) },
      }))
      local answers = data.runs[1].answers
      assert.is_nil(answers[1].reserve)
      assert.is_nil(answers[1].fit)
      assert.are.equal(PlannedRuns.MAX_FIT, #answers[2].fit)
      assert.is_nil(answers[2].fit:find("|", 1, true))
    end)
  end)
end)
