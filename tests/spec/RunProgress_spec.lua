local helpers = require("helpers")

-- CF-106: a planned run's boss progress (golden cases shared with the site), the row status and the badge.
describe("Run progress (CF-106)", function()
  local RunProgress, ns

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/PlannedRuns.lua", ns)
    RunProgress = helpers.loadAddonFile("src/core/RunProgress.lua", ns)
  end)

  describe("golden cases (tests/fixtures/run-progress-cases.json)", function()
    local data = helpers.readJson("tests/fixtures/run-progress-cases.json")
    it("uses the file's times", function()
      assert.are.equal(data.beforeStart, RunProgress.BEFORE)
      assert.are.equal(data.noBossFor, RunProgress.NO_BOSS_FOR)
    end)
    for _, c in ipairs(data.cases) do
      it(c.name, function()
        local p = RunProgress.progress(c.run, c.bosses or data.bosses, c.kills, c.now, c.resetAt)
        local e = c.expect
        assert.are.equal(e.state, p.state)
        assert.are.equal(e.done, p.done)
        assert.are.equal(e.total, p.total)
        assert.are.equal(e.cleared, p.cleared)
        assert.are.equal(e.visible, p.visible)
        assert.are.equal(e.label, p.label)
        assert.are.equal(e.firstKill, p.firstKill)
        local skipped = {}
        for id in pairs(p.skipped) do skipped[#skipped + 1] = id end
        table.sort(skipped)
        assert.are.same(e.skipped, skipped)
      end)
    end
  end)

  local NOW = 1793120000
  local me = { battleTag = "Hex#1000", guids = { ["Player-1-H"] = true } }
  local dm = { id = "dm", min = 17, max = 26 }
  local gnomer = { id = "gnomer", min = 29, max = 38 }

  it("gives each row its status", function()
    local run = { startsAt = NOW + 3600, answers = {} }
    local ctx = { me = me, levels = { 16 }, dungeon = dm, progress = { state = "upcoming" } }
    assert.are.equal("answer", RunProgress.rowStatus(run, ctx))
    ctx.dungeon = gnomer
    assert.are.equal("nofit", RunProgress.rowStatus(run, ctx))
    run.answers = { { guid = "Player-1-H", answer = "maybe" } }
    assert.are.equal("maybe", RunProgress.rowStatus(run, ctx)) -- you can answer a run that doesn't fit
    run.answers[1].answer = "cant"
    assert.are.equal("cant", RunProgress.rowStatus(run, ctx))
    run.answers[1].answer = "in"
    assert.are.equal("in", RunProgress.rowStatus(run, ctx))
    ctx.progress = { state = "noBoss" }
    assert.are.equal("noBoss", RunProgress.rowStatus(run, ctx))
    assert.are.equal("organiser", RunProgress.rowStatus({ organiser = { battleTag = "Hex#1000" }, answers = {} },
      { me = me, levels = {}, dungeon = gnomer }))
  end)

  it("counts runs not started, not answered, that one of your characters fits", function()
    local runs = {
      { startsAt = NOW + 3600, dungeon = "dm", answers = {} },                                     -- counts
      { startsAt = NOW + 3600, dungeon = "gnomer", answers = {} },                                 -- no fit
      { startsAt = NOW - 60, dungeon = "dm", answers = {} },                                       -- started
      { startsAt = NOW + 3600, dungeon = "dm", answers = { { guid = "Player-1-H", answer = "cant" } } }, -- answered
      { startsAt = NOW + 3600, dungeon = "dm", state = "cancelled", answers = {} },                -- cancelled
      { startsAt = NOW + 3600, dungeon = "lfg1982", answers = {} },                                -- unknown: counts
    }
    local byId = { dm = dm, gnomer = gnomer }
    local ctx = { me = me, levels = { 16 }, now = NOW, dungeonOf = function(r) return byId[r.dungeon] end }
    assert.are.equal(2, RunProgress.badge(runs, ctx))
    ctx.levels = { 16, 30 } -- any of your characters
    assert.are.equal(3, RunProgress.badge(runs, ctx))
  end)

  it("groups runs Today, Tomorrow and Later by the local date", function()
    local base = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 51 })
    assert.are.equal("Today", RunProgress.dayGroup(base + 4 * 3600, base, os.date)) -- 14:00 is Today
    assert.are.equal("Today", RunProgress.dayGroup(base - 3600, base, os.date))
    assert.are.equal("Tomorrow", RunProgress.dayGroup(base + 24 * 3600, base, os.date))
    assert.are.equal("Later", RunProgress.dayGroup(base + 48 * 3600, base, os.date))
  end)
end)
