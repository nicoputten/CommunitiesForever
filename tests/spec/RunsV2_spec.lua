local helpers = require("helpers")

-- CF-49: Runs v2 in game, the same level fit and roles as the site (web WEB-47) and Discord.
describe("Runs v2 (CF-49)", function()
  local PlannedRuns

  before_each(function()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", helpers.coreNs())
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
      -- CF-50: every level may say I'm in; 6+ below is never suggested.
      { 24, "tooLow", "6 below", true, false },
      { 1, "tooLow", "29 below", true, false },
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

    it("counts an unknown level as too low, and it may still say I'm in (CF-50)", function()
      local fit = PlannedRuns.levelFit(nil, 30, 40)
      assert.are.equal("tooLow", fit.kind)
      assert.are.equal("level unknown", fit.label)
      assert.is_true(fit.canPick)
      assert.is_false(fit.suggested)
    end)

    it("6+ below may say I'm in with the tough note, and is never close or suggested (CF-50)", function()
      local fit = PlannedRuns.levelFit(20, 30, 40)
      assert.is_true(fit.canPick)
      assert.is_false(fit.suggested)
      assert.are.equal("This will be tough.", fit.note)
      local run = { answers = {} }
      local close = PlannedRuns.close(run, {
        { guid = "LOW", name = "Low", level = 27 },
        { guid = "TOO", name = "Too", level = 20 },
      }, { min = 30, max = 40 })
      assert.are.equal(1, #close)
      assert.are.equal("LOW", close[1].char.guid)
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

  describe("slots, reserves and suggestions", function()
    local DM = { id = "dm", min = 17, max = 26 }
    local ME = { battleTag = "Me#1000", guids = { ["G-ME"] = true, ["G-ALT"] = true, ["G-OLD"] = true } }

    it("gives a reserve no slot and lists it", function()
      local run = { answers = {
        { name = "Ada Lovewell", answer = "in", role = "heal" },
        { name = "Bo Stone", answer = "maybe", role = "heal", reserve = true },
      } }
      local slots = PlannedRuns.slots(run, {}, DM)
      assert.are.equal("Ada Lovewell", slots[2].answer.name)
      for i = 3, 5 do assert.is_nil(slots[i].answer) end
      local reserves = PlannedRuns.reserves(run)
      assert.are.same({ "Bo Stone" }, { reserves[1].name })
      assert.are.same({}, PlannedRuns.reserves({}))
    end)

    it("fills slots from an older file without roles as before", function()
      local slots = PlannedRuns.slots({ answers = { { name = "Ada Lovewell", answer = "in" } } }, {}, DM)
      assert.are.equal("Ada Lovewell", slots[3].answer.name)
    end)

    it("takes the fit from the character's level when known, else from the file", function()
      assert.are.equal("+4 over", PlannedRuns.fitOf({ fit = "fits" }, { level = 30 }, DM).label)
      assert.are.equal("carry \194\183 +12", PlannedRuns.fitOf({ fit = "carry \194\183 +12" }, nil, DM).label)
      assert.is_nil(PlannedRuns.fitOf({}, nil, DM))
    end)

    it("suggests a character of yours a few over, in a free role its class can play", function()
      local candidates = {
        { guid = "G-ME", name = "Me Example", level = 28, own = true, role = "dps", classFile = "WARRIOR" },
      }
      -- Damage is taken: the warrior is offered as tank, which its class can play.
      local run = { answers = { { name = "A", answer = "in", role = "dps" },
                                { name = "B", answer = "in", role = "dps" },
                                { name = "C", answer = "in", role = "dps" } } }
      local c, role = PlannedRuns.youFit(run, candidates, DM, ME, "G-ME")
      assert.are.same({ "Me Example", "tank" }, { c.name, role })
      -- A mage can't heal or tank.
      candidates[1].classFile = "MAGE"
      assert.is_nil(PlannedRuns.youFit(run, candidates, DM, ME, "G-ME"))
      -- A carry isn't suggested; it is "close".
      candidates[1].classFile, candidates[1].level = "WARRIOR", 40
      assert.is_nil(PlannedRuns.youFit(run, candidates, DM, ME, "G-ME"))
      local close = PlannedRuns.close(run, candidates, DM)
      assert.are.equal("carry \194\183 +14", close[1].fit.label)
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
