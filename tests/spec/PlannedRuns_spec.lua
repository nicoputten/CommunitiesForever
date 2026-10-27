local helpers = require("helpers")

-- CF-45: the planned runs file (Data\Runs.lua, CF_RUNS) is checked like received sync data.
describe("PlannedRuns (CF-45)", function()
  local PlannedRuns

  local function sample()
    return {
      v = 1,
      updatedAt = 1793120000,
      reminderMinutes = 30,
      runs = {
        {
          id = "r-102", dungeon = "smlib", startsAt = 1793210400, state = "open", note = "Bring water",
          url = "https://example.com/runs/102",
          organiser = { battleTag = "Ada#1001", guid = "Player-1-0000AAAA", name = "Ada Lovewell", utcOffset = 3600 },
          answers = {
            { battleTag = "Ada#1001", guid = "Player-1-0000AAAA", name = "Ada Lovewell", answer = "in",
              role = "tank", source = "site", at = 1793100000 },
            { battleTag = "Bo#2002", answer = "maybe", source = "discord" },
          },
        },
        { id = "r-101", dungeon = "dm", startsAt = 1793200000 },
      },
    }
  end

  before_each(function()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", {})
  end)

  it("keeps a valid file, runs sorted by start time", function()
    local result, reason = PlannedRuns.validate(sample())
    assert.is_nil(reason)
    assert.are.equal(1, result.v)
    assert.are.equal(1793120000, result.updatedAt)
    assert.are.equal(30, result.reminderMinutes)
    assert.are.equal(0, result.dropped)
    assert.are.same({ "r-101", "r-102" }, { result.runs[1].id, result.runs[2].id })
    local run = result.runs[2]
    assert.are.same({ battleTag = "Ada#1001", guid = "Player-1-0000AAAA", name = "Ada Lovewell", utcOffset = 3600 },
      run.organiser)
    assert.are.equal("open", run.state)
    assert.are.equal("Bring water", run.note)
    assert.are.equal("https://example.com/runs/102", run.url)
    assert.are.same({ battleTag = "Ada#1001", guid = "Player-1-0000AAAA", name = "Ada Lovewell", answer = "in",
      role = "tank", source = "site", at = 1793100000 }, run.answers[1])
    assert.are.same({ battleTag = "Bo#2002", answer = "maybe", source = "discord" }, run.answers[2])
    assert.are.same({}, result.runs[1].answers)
  end)

  it("reports the shipped empty file and broken files", function()
    assert.are.same({ nil, "missing" }, { PlannedRuns.validate(nil) })
    assert.are.same({ nil, "not a table" }, { PlannedRuns.validate("runs") })
    assert.are.same({ nil, "not a table" }, { PlannedRuns.validate({ v = "1", updatedAt = 1 }) })
    assert.are.same({ nil, "no updatedAt" }, { PlannedRuns.validate({ runs = {} }) })
    assert.are.same({ nil, "no updatedAt" }, { PlannedRuns.validate({ updatedAt = "1793120000" }) })
    assert.are.same({ nil, "no updatedAt" }, { PlannedRuns.validate({ updatedAt = 0 / 0 }) })
    assert.are.same({ nil, "no updatedAt" }, { PlannedRuns.validate({ updatedAt = 1e12 }) })
  end)

  it("ignores a newer format and reads a file without v as format 1", function()
    assert.are.same({ nil, "newer format" }, { PlannedRuns.validate({ v = 2, updatedAt = 1793120000 }) })
    local result = PlannedRuns.validate({ updatedAt = 1793120000 })
    assert.are.equal(1, result.v)
    assert.are.same({}, result.runs)
  end)

  it("treats missing or wrong runs as none", function()
    assert.are.same({}, PlannedRuns.validate({ updatedAt = 1793120000, runs = "x" }).runs)
    assert.is_nil(PlannedRuns.validate({ updatedAt = 1793120000, reminderMinutes = -5 }).reminderMinutes)
    assert.is_nil(PlannedRuns.validate({ updatedAt = 1793120000, reminderMinutes = "30" }).reminderMinutes)
  end)

  it("drops runs without id, dungeon or start, and duplicate ids", function()
    local raw = sample()
    raw.runs[3] = { id = "r-103", dungeon = "rfc" }                   -- no start
    raw.runs[4] = { dungeon = "rfc", startsAt = 1793200000 }          -- no id
    raw.runs[5] = { id = "r 105", dungeon = "rfc", startsAt = 1793200000 } -- bad id
    raw.runs[6] = { id = "r-106", dungeon = "|cffff0000rfc", startsAt = 1793200000 }
    raw.runs[7] = "run"
    raw.runs[8] = { id = "r-101", dungeon = "wc", startsAt = 1793300000 } -- duplicate
    local result = PlannedRuns.validate(raw)
    assert.are.equal(2, #result.runs)
    assert.are.equal(6, result.dropped)
    assert.are.equal("dm", result.runs[1].dungeon)
  end)

  it("drops wrong optional fields but keeps the run", function()
    local raw = sample()
    local r = raw.runs[1]
    r.state, r.note, r.url, r.organiser.utcOffset = "exploded", 42, "javascript:alert(1)", 99999
    r.answers[1].role, r.answers[1].source, r.answers[1].at = "bard", "fax", "now"
    r.answers[3] = { battleTag = "Cy#3003", answer = "yes" } -- unknown answer
    r.answers[4] = { answer = "in" }                         -- nobody
    local run = PlannedRuns.validate(raw).runs[2]
    assert.is_nil(run.state)
    assert.is_nil(run.note)
    assert.is_nil(run.url)
    assert.is_nil(run.organiser.utcOffset)
    assert.are.same({ battleTag = "Ada#1001", guid = "Player-1-0000AAAA", name = "Ada Lovewell", answer = "in" },
      run.answers[1])
    assert.are.equal(2, #run.answers)
  end)

  it("removes escape sequences and control characters from text", function()
    local raw = sample()
    raw.runs[1].note = "|cffff0000Red|r\nline |Hitem:1|h[x]|h  two"
    raw.runs[1].organiser.name = "|TInterface\\Icons\\x:0|tAda"
    raw.runs[1].answers[2].battleTag = "   "
    local run = PlannedRuns.validate(raw).runs[2]
    assert.are.equal("cffff0000Redr line Hitem:1h[x]h two", run.note)
    assert.are.equal("TInterface\\Icons\\x:0tAda", run.organiser.name)
    assert.are.equal(1, #run.answers) -- the second answer had nobody left
  end)

  it("caps string lengths on whole UTF-8 characters", function()
    local raw = sample()
    raw.runs[1].note = string.rep("é", 500)
    raw.runs[1].organiser.name = string.rep("a", 100)
    raw.runs[1].url = "https://example.com/" .. string.rep("a", 300)
    raw.runs[1].id = string.rep("r", 65)
    raw.runs[2].note = string.rep("x", 10 ^ 6)
    local result = PlannedRuns.validate(raw)
    assert.are.equal(1, #result.runs)
    local run = result.runs[1]
    assert.are.equal(string.rep("x", PlannedRuns.MAX_NOTE), run.note)
    raw.runs[1].id = "r-102"
    run = PlannedRuns.validate(raw).runs[2]
    assert.are.equal(string.rep("é", PlannedRuns.MAX_NOTE), run.note)
    assert.are.equal(PlannedRuns.MAX_NAME, #run.organiser.name)
    assert.is_nil(run.url)
  end)

  it("caps the number of runs and answers without walking the rest", function()
    local backing = {}
    for i = 1, 500 do backing[i] = { id = "r" .. i, dungeon = "rfc", startsAt = 1793200000 + i } end
    local answers = {}
    for i = 1, 500 do answers[i] = { name = "Name " .. i, answer = "in" } end
    backing[1].answers = answers
    local visited = 0
    local runs = setmetatable({}, { __index = function(_, i)
      visited = visited + 1
      return backing[i]
    end })
    local result = PlannedRuns.validate({ updatedAt = 1793120000, runs = runs })
    assert.are.equal(PlannedRuns.MAX_RUNS, #result.runs)
    assert.are.equal(1, result.dropped)
    assert.are.equal(PlannedRuns.MAX_ANSWERS, #result.runs[1].answers)
    assert.are.equal(PlannedRuns.MAX_RUNS + 1, visited)
  end)
end)

-- The adapter reads the global once per load and clears it.
describe("RunsFile (CF-45)", function()
  local function load()
    local ns = {}
    helpers.loadAddonFile("src/core/PlannedRuns.lua", ns)
    return helpers.loadAddonFile("src/adapters/RunsFile.lua", ns)
  end

  after_each(function()
    _G.CF_RUNS = nil
  end)

  it("reads the shipped empty file as missing", function()
    helpers.loadAddonFile("Data/Runs.lua", {})
    assert.is_nil(_G.CF_RUNS)
    assert.are.same({ nil, "missing" }, { load().read() })
  end)

  it("checks CF_RUNS once and clears the global", function()
    _G.CF_RUNS = { updatedAt = 1793120000, runs = { { id = "r1", dungeon = "rfc", startsAt = 1793200000 } } }
    local RunsFile = load()
    local runs = RunsFile.read()
    assert.are.equal("r1", runs.runs[1].id)
    assert.is_nil(_G.CF_RUNS)
    assert.are.equal(runs, RunsFile.read())
  end)

  it("survives data that errors when read", function()
    _G.CF_RUNS = setmetatable({}, { __index = function() error("boom") end })
    assert.are.same({ nil, "unreadable" }, { load().read() })
  end)
end)
