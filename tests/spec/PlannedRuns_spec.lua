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

-- CF-46: sharing and the Dungeons tab.
describe("PlannedRuns views (CF-46)", function()
  local PlannedRuns
  local NOW = 1793120000
  local DM = { id = "dm", min = 17, max = 26 }
  local ME = { battleTag = "Me#1000", guids = { ["G-ME"] = true, ["G-ALT"] = true } }

  local function cand(guid, name, level, extra)
    local c = { guid = guid, name = name, level = level, key = guid }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
  end
  local CANDIDATES = {
    cand("G-ME", "Me Example", 20, { own = true, role = "dps" }),
    cand("G-ALT", "Alt Example", 22, { own = true, role = "tank" }),
    cand("G-LOW", "Low Example", 13, { own = true }),
    cand("G-BEN", "Ben Example", 19, { role = "heal", displayName = "Ben" }),
    cand("G-CY", "Cy Example", 30, { role = "tank", displayName = "Cy" }),
  }

  before_each(function()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", {})
  end)

  it("takes newer runs only, not far in the future", function()
    local current = { updatedAt = NOW - 60 }
    assert.is_true(PlannedRuns.isNewer(current, { updatedAt = NOW }, NOW))
    assert.is_false(PlannedRuns.isNewer(current, { updatedAt = NOW - 60 }, NOW))
    assert.is_false(PlannedRuns.isNewer(current, { updatedAt = NOW + 301 }, NOW))
    assert.is_true(PlannedRuns.isNewer(nil, { updatedAt = 1 }, NOW))
    assert.is_false(PlannedRuns.isNewer(current, nil, NOW))
  end)

  it("drops BattleTags for the community wire and the dropped count always", function()
    local data = PlannedRuns.validate({ updatedAt = NOW, runs = { { id = "r1", dungeon = "dm", startsAt = NOW,
      organiser = { battleTag = "Ada#1001", name = "Ada Lovewell" },
      answers = { { battleTag = "Ada#1001", guid = "G-ADA", answer = "in" } } } } })
    local bnet, community = PlannedRuns.wire(data), PlannedRuns.wire(data, true)
    assert.is_nil(bnet.dropped)
    assert.are.equal("Ada#1001", bnet.runs[1].organiser.battleTag)
    assert.is_nil(community.runs[1].organiser.battleTag)
    assert.are.same({ guid = "G-ADA", answer = "in" }, community.runs[1].answers[1])
    assert.are.equal("Ada#1001", data.runs[1].organiser.battleTag) -- the original is untouched
    assert.is_nil(PlannedRuns.wire(nil))
  end)

  it("lists upcoming runs: not cancelled, started at most 2 hours ago", function()
    local data = { runs = { { id = "a", startsAt = NOW - 7201 }, { id = "b", startsAt = NOW - 7200 },
                            { id = "c", startsAt = NOW + 60, state = "cancelled" },
                            { id = "d", startsAt = NOW + 60 } } }
    local ids = {}
    for _, r in ipairs(PlannedRuns.upcoming(data, NOW)) do ids[#ids + 1] = r.id end
    assert.are.same({ "b", "d" }, ids)
    assert.are.same({}, PlannedRuns.upcoming(nil, NOW))
  end)

  it("finds your answer and whether you organise, by character or BattleTag", function()
    local run = { organiser = { battleTag = "Me#1000" },
                  answers = { { guid = "G-BEN", answer = "in" }, { guid = "G-ALT", answer = "maybe" } } }
    assert.is_true(PlannedRuns.isOrganiser(run, ME))
    assert.are.equal("maybe", PlannedRuns.yourAnswer(run, ME).answer)
    assert.are.same({ 1, 1 }, { PlannedRuns.counts(run) })
    assert.is_nil(PlannedRuns.yourAnswer({ answers = { { guid = "G-BEN", answer = "in" } } }, ME))
  end)

  it("fills the slots: in by role, then maybe; tank or healer missing when nobody in range plays it", function()
    local run = { answers = {
      { guid = "G-BEN", answer = "in" },                     -- healer by the role the addon knows
      { name = "Dee Example", answer = "in", role = "tank" }, -- from the site, unknown to the addon
      { guid = "G-ME", answer = "maybe" },
      { name = "Eve", answer = "cant", role = "dps" },
    } }
    local slots = PlannedRuns.slots(run, CANDIDATES, DM)
    assert.are.equal("Dee Example", slots[1].answer.name)
    assert.is_nil(slots[1].char)
    assert.are.equal("Ben Example", slots[2].char.name)
    assert.are.equal("G-ME", slots[3].answer.guid)
    assert.is_true(slots[3].maybe)
    assert.is_nil(slots[4].answer)
    -- Nobody answered tank or healer: Alt Example tanks in range (open), nobody heals but Ben, who said no.
    slots = PlannedRuns.slots({ answers = { { guid = "G-BEN", answer = "cant" } } }, CANDIDATES, DM)
    assert.is_nil(slots[1].missing)
    assert.is_true(slots[2].missing)
  end)

  it("puts extra tanks in damage slots", function()
    local run = { answers = { { name = "T1", answer = "in", role = "tank" },
                              { name = "T2", answer = "in", role = "tank" } } }
    local slots = PlannedRuns.slots(run, {}, DM)
    assert.are.same({ "T1", "T2" }, { slots[1].answer.name, slots[3].answer.name })
  end)

  it("says which of your characters fits a free slot, the one you are on first", function()
    local run = { answers = { { name = "T", answer = "in", role = "tank" } } }
    local c, role = PlannedRuns.youFit(run, CANDIDATES, DM, ME, "G-ME")
    assert.are.same({ "Me Example", "dps" }, { c.name, role })
    c, role = PlannedRuns.youFit({ answers = {} }, CANDIDATES, DM, ME, "G-ALT")
    assert.are.same({ "Alt Example", "tank" }, { c.name, role })
    assert.is_nil(PlannedRuns.youFit({ answers = { { guid = "G-ME", answer = "cant" } } }, CANDIDATES, DM, ME, "G-ME"))
    assert.is_nil(PlannedRuns.youFit({ organiser = { battleTag = "Me#1000" }, answers = {} }, CANDIDATES, DM, ME))
  end)

  it("lists characters close to the range, your own first", function()
    local close = PlannedRuns.close({ answers = {} }, CANDIDATES, DM)
    assert.are.same({ "Low Example", "Cy Example" }, { close[1].char.name, close[2].char.name })
    assert.are.same({ 4, 4 }, { close[1].short, close[2].over })
    assert.are.same({}, PlannedRuns.close({ answers = {} }, CANDIDATES, nil))
  end)

  it("words times in local time and how long until the start", function()
    local function fakeDate(_, t)
      local day = math.floor(t / 86400)
      local s = t % 86400
      return { year = 2026, month = 10, day = 20 + day - 20000, hour = math.floor(s / 3600),
               min = math.floor(s % 3600 / 60),
               wday = (day % 7) + 1 }
    end
    local now = 20000 * 86400 + 12 * 3600
    assert.are.equal("Today 20:30", PlannedRuns.whenText(now + 8 * 3600 + 1800, now, fakeDate))
    assert.are.equal("Tomorrow 09:00", PlannedRuns.whenText(now + 21 * 3600, now, fakeDate))
    assert.is_truthy(PlannedRuns.whenText(now + 3 * 86400, now, fakeDate):match("^%a%a%a 12:00$"))
    assert.is_truthy(PlannedRuns.whenText(now + 9 * 86400, now, fakeDate):match("^%a%a%a 29 Oct 12:00$"))
    assert.are.equal("20:30", PlannedRuns.clock(now + 8 * 3600 + 1800, fakeDate))
    assert.are.equal("in 2 h 40 min", PlannedRuns.untilText(NOW + 9600, NOW))
    assert.are.equal("in 2 h", PlannedRuns.untilText(NOW + 7200, NOW))
    assert.are.equal("in 25 min", PlannedRuns.untilText(NOW + 1500, NOW))
    assert.are.equal("in 1 day", PlannedRuns.untilText(NOW + 86400, NOW))
    assert.are.equal("started 10 min ago", PlannedRuns.untilText(NOW - 600, NOW))
  end)
end)

-- CF-47: what the site received, and the dialog helpers.
describe("PlannedRuns for the dialogs (CF-47)", function()
  local PlannedRuns
  local NOW = 1793120000

  before_each(function()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", {})
  end)

  it("keeps the ids the site received, capped, and sends them on", function()
    local raw = { updatedAt = NOW, received = { "k1-1-1", "bad id", 42 } }
    for i = 1, 300 do raw.received[#raw.received + 1] = "k-" .. i end
    local data = PlannedRuns.validate(raw)
    assert.are.equal("k1-1-1", data.received[1])
    assert.are.equal("k-1", data.received[2]) -- broken ids are left out
    assert.are.equal(PlannedRuns.MAX_RECEIVED - 2, #data.received)
    assert.are.same(data.received, PlannedRuns.wire(data).received)
    assert.are.same({}, PlannedRuns.validate({ updatedAt = NOW }).received)
  end)

  it("reads a typed time", function()
    assert.are.same({ 20, 30 }, { PlannedRuns.parseClock("20:30") })
    assert.are.same({ 8, 5 }, { PlannedRuns.parseClock(" 8:05 ") })
    assert.are.same({ 20, 30 }, { PlannedRuns.parseClock("2030") })
    assert.are.same({ 20, 30 }, { PlannedRuns.parseClock("20.30") })
    assert.is_nil(PlannedRuns.parseClock("24:00"))
    assert.is_nil(PlannedRuns.parseClock("20:60"))
    assert.is_nil(PlannedRuns.parseClock("soon"))
    assert.is_nil(PlannedRuns.parseClock(nil))
  end)

  it("offers today and the next six days by the calendar, across a month end", function()
    -- os.date with a fixed "now": 2026-10-27 (a Tuesday) in local time.
    local function fakeDate(fmt, t)
      assert.are.equal("*t", fmt)
      assert.are.equal(NOW, t)
      return { year = 2026, month = 10, day = 27, hour = 23, min = 50, wday = 3 }
    end
    local days = PlannedRuns.dayChoices(NOW, fakeDate)
    local labels, dates = {}, {}
    for i, d in ipairs(days) do
      labels[i] = d.label
      dates[i] = string.format("%d-%02d-%02d", d.year, d.month, d.day)
    end
    assert.are.same({ "Today", "Wed", "Thu", "Fri", "Sat", "Sun", "Mon" }, labels)
    assert.are.same({ "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01",
                      "2026-11-02" }, dates)
  end)

  it("gives the organiser's clock time from their offset", function()
    local at = 1793210400 -- 2026-11-02 19:20 UTC
    assert.are.equal(os.date("!%H:%M", at + 3600), PlannedRuns.theirClock(at, 3600, os.date))
    assert.is_nil(PlannedRuns.theirClock(at, nil, os.date))
  end)
end)
