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
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", helpers.coreNs())
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

  it("keeps the site's dungeon name, cleaned and capped (CF-63)", function()
    local raw = sample()
    raw.runs[1].dungeonName = "|cffff0000Hall of Thanes|r " .. string.rep("x", 100)
    local run = PlannedRuns.validate(raw).runs[2]
    assert.are.equal("cffff0000Hall of Thanesr x", run.dungeonName:sub(1, 26))
    assert.is_true(#run.dungeonName <= 60)
    assert.is_nil(PlannedRuns.validate(sample()).runs[1].dungeonName)
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
    local ns = helpers.coreNs()
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
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", helpers.coreNs())
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

  it("lists characters that may join but aren't suggested (CF-49: 1-5 below, carries), your own first", function()
    local close = PlannedRuns.close({ answers = {} }, CANDIDATES, DM)
    -- Cy Example is 4 over: suggested, so not "close".
    assert.are.equal(1, #close)
    assert.are.same({ "Low Example", "4 below" }, { close[1].char.name, close[1].fit.label })
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
    assert.are.equal("in 2 h 40 m", PlannedRuns.untilText(NOW + 9600, NOW))
    -- CF-63: "Starting now" for 30 minutes from the start, then "started … ago".
    assert.are.equal("in 12 min", PlannedRuns.countdown(NOW + 720, NOW))
    assert.are.equal("Starting now", PlannedRuns.countdown(NOW, NOW))
    assert.are.equal("Starting now", PlannedRuns.countdown(NOW - 29 * 60, NOW))
    assert.are.equal("started 30 min ago", PlannedRuns.countdown(NOW - 30 * 60, NOW))
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
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", helpers.coreNs())
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

  it("gives the organiser's clock time from their offset", function()
    local at = 1793210400 -- 2026-11-02 19:20 UTC
    assert.are.equal(os.date("!%H:%M", at + 3600), PlannedRuns.theirClock(at, 3600, os.date))
    assert.is_nil(PlannedRuns.theirClock(at, nil, os.date))
  end)
  it("reads the site's address and the friends it knows (CF-62, optional)", function()
    assert.are.equal("https://wow.example.org", PlannedRuns.site({ site = "https://wow.example.org" }))
    assert.is_nil(PlannedRuns.site({ site = "javascript:alert(1)" }))
    assert.is_nil(PlannedRuns.site({}))
    local friends = PlannedRuns.friends({ friends = {
      { name = "Mira", chars = { { name = "Mira Sunstrider", realm = "Chromaggus", classFile = "PRIEST", level = 41,
                                   seenAt = 1793000000 }, { name = "Bad", classFile = "priest|r" }, "junk" } },
      { name = "" }, "junk", { name = "Ada", chars = {} },
    } })
    assert.are.equal(2, #friends)
    assert.are.same({ name = "Mira Sunstrider", realm = "Chromaggus", classFile = "PRIEST", level = 41,
                      seenAt = 1793000000 }, friends[1].chars[1])
    assert.is_nil(friends[1].chars[2].classFile)
    assert.are.same({ name = "Ada", chars = {} }, friends[2])
    assert.are.same({}, PlannedRuns.friends(nil))
  end)
  it("groups and times runs for the Dungeons list (CF-62)", function()
    local function clock(fmt, t)
      assert(fmt == "*t")
      local day = math.floor(t / 86400)
      local secs = t % 86400
      return { year = 2026, month = 11, day = 4 + day, hour = math.floor(secs / 3600), min = math.floor(secs / 60) % 60,
               wday = (3 + day) % 7 + 1 }
    end
    local now = 10 * 3600 -- Wed 4 Nov 10:00 in the fake clock
    assert.are.equal("Today", PlannedRuns.bucket(now + 3600, now, clock))
    assert.are.equal("Tonight", PlannedRuns.bucket(20 * 3600, now, clock))
    assert.are.equal("Tomorrow", PlannedRuns.bucket(86400 + 20 * 3600, now, clock))
    assert.are.equal("This week", PlannedRuns.bucket(3 * 86400, now, clock))
    assert.are.equal("Later", PlannedRuns.bucket(9 * 86400, now, clock))
    assert.are.equal("20:30", PlannedRuns.rowTime(20 * 3600 + 1800, now, clock))
    assert.are.equal("Fri 20:00", PlannedRuns.rowTime(2 * 86400 + 20 * 3600, now, clock))
    assert.are.equal("SM: Graveyard", PlannedRuns.shortName("Scarlet Monastery: Graveyard"))
    assert.are.equal("Razorfen Kraul", PlannedRuns.shortName("Razorfen Kraul"))
    local run = { startsAt = 5000 }
    assert.is_false(PlannedRuns.inviteOpen(run, 5000 - 901))
    assert.is_true(PlannedRuns.inviteOpen(run, 5000 - 900))
  end)

  -- CF-63: the logic of the interactive Dungeons tab.
  describe("CF-63", function()
    local DOT = " \194\183 "
    local SMGY = { min = 26, max = 36 }
    local ME = { battleTag = "Me#1000", guids = { ["G-ME"] = true } }
    -- 2026-11-06 (a Friday) 18:30 local; os.date / os.time as the game's date and localTime.
    local AT = os.time({ year = 2026, month = 11, day = 6, hour = 18, min = 30, sec = 0 })

    it("lists all your characters with their fit, best first, the one you are on before others", function()
      local chars = {
        { own = true, guid = "G-A", name = "Alt Low", level = 22 },
        { own = true, guid = "G-B", name = "Big Carry", level = 60 },
        { own = true, guid = "G-ME", name = "Me Now", level = 30 },
        { own = true, guid = "G-C", name = "Other Fit", level = 34 },
        { own = false, guid = "G-F", name = "Friend", level = 30 },
      }
      local list = PlannedRuns.charChoices(chars, SMGY, "G-ME")
      local names, labels = {}, {}
      for i, o in ipairs(list) do names[i], labels[i] = o.char.name, o.fit.label end
      assert.are.same({ "Me Now", "Other Fit", "Alt Low", "Big Carry" }, names)
      assert.are.same({ "fits", "fits", "4 below", "carry" .. DOT .. "+24" }, labels)
      assert.are.equal(4, #PlannedRuns.charChoices(chars, nil, "G-ME")) -- unknown range: all, all fit
    end)

    it("shows each role the class can play as open or full, your own answer left out", function()
      local run = { answers = {
        { guid = "G-ME", answer = "in", role = "heal" },
        { guid = "G-T", answer = "in", role = "tank" },
        { guid = "G-1", answer = "in", role = "dps" }, { guid = "G-2", answer = "in", role = "dps" },
        { guid = "G-3", answer = "maybe", role = "dps" },
      } }
      local list = PlannedRuns.roleChoices(run, {}, SMGY, "DRUID", ME)
      local labels = {}
      for i, o in ipairs(list) do labels[i] = o.label end
      -- Your heal slot counts as open for you; a maybe holds a slot loosely: damage stays open.
      assert.are.same({ "Tank" .. DOT .. "full", "Healer" .. DOT .. "open", "Damage" .. DOT .. "open" }, labels)
      run.answers[5].answer = "in"
      assert.are.equal("full", PlannedRuns.roleChoices(run, {}, SMGY, "MAGE", ME)[1].state)
      assert.are.equal(1, #PlannedRuns.roleChoices(run, {}, SMGY, "MAGE", ME))
    end)

    it("says what your answer is, reserve when your role is full (CF-63b)", function()
      assert.are.equal("none", PlannedRuns.answerState(nil, false))
      assert.are.equal("in", PlannedRuns.answerState({ answer = "in" }, false))
      assert.are.equal("reserve", PlannedRuns.answerState({ answer = "in" }, true))
      assert.are.equal("reserve", PlannedRuns.answerState({ answer = "in", reserve = true }, false))
      assert.are.equal("maybe", PlannedRuns.answerState({ answer = "maybe" }, true))
      assert.are.equal("You\226\128\153re on reserve", PlannedRuns.ANSWER_STATES.reserve)
    end)

    it("writes a group member's tooltip lines (CF-63b)", function()
      local a = { name = "Jo Goldmane", answer = "in", role = "tank", source = "site",
                  at = os.time({ year = 2026, month = 11, day = 2, hour = 21, min = 12, sec = 0 }), note = "late" }
      local lines = PlannedRuns.memberLines(a, { name = "Jo Goldmane", level = 30 }, SMGY,
        { name = "Jo Goldmane", zone = "Undercity" }, AT, os.date)
      assert.are.same({ "Jo Goldmane", "Level 30" .. DOT .. "fits" .. DOT .. "Tank",
        "Answered on the website, Mon 21:12", "\226\128\156late\226\128\157",
        "Online on Jo Goldmane" .. DOT .. "Undercity" },
        lines)
      assert.are.same({ "Bo", "Answered on Discord" },
        PlannedRuns.memberLines({ name = "Bo", answer = "maybe", source = "discord" }, nil, SMGY, nil, AT, os.date))
    end)

    it("filters runs by the chips: mine, open slots, in range (CF-63c)", function()
      local runs = {
        { id = "lead", dungeon = "dm", organiser = { battleTag = "Me#1000" }, answers = {} },
        { id = "in", dungeon = "smgy", answers = { { guid = "G-ME", answer = "in" } } },
        { id = "cant", dungeon = "dm", answers = { { guid = "G-ME", answer = "cant" } } },
        { id = "full", dungeon = "smgy", answers = {
          { guid = "A", answer = "in", role = "tank" }, { guid = "B", answer = "in", role = "heal" },
          { guid = "C", answer = "in" }, { guid = "D", answer = "in" }, { guid = "E", answer = "in" } } },
      }
      local dungeons = { dm = { min = 17, max = 26 }, smgy = SMGY }
      local ctx = { me = ME, candidates = {}, dungeonOf = function(run) return dungeons[run.dungeon] end, level = 30 }
      local function ids(kind)
        local out = {}
        for i, run in ipairs(PlannedRuns.filterRuns(runs, kind, ctx)) do out[i] = run.id end
        return out
      end
      assert.are.same({ "lead", "in", "cant", "full" }, ids("all"))
      assert.are.same({ "lead", "in" }, ids("mine"))
      assert.are.same({ "lead", "in", "cant" }, ids("open"))
      assert.are.same({ "in", "full" }, ids("range"))
    end)

    it("names the first role a run needs", function()
      assert.are.equal("tank", PlannedRuns.neededRole({ answers = {} }, {}, SMGY))
      assert.are.equal("heal", PlannedRuns.neededRole({ answers = { { answer = "in", role = "tank" } } }, {}, SMGY))
    end)

    it("writes the whisper and the ask note to fill a slot", function()
      local today = { startsAt = AT + 7200 } -- 20:30
      local monday = { startsAt = AT + 3 * 86400 }
      local name = "Scarlet Monastery: Graveyard"
      assert.are.equal("Up for SM: Graveyard at 20:30? We need a healer.",
        PlannedRuns.whisperText(today, name, "heal", AT, os.date))
      assert.are.equal("Up for SM: Graveyard at 20:30?", PlannedRuns.whisperText(today, name, nil, AT, os.date))
      assert.is_truthy(PlannedRuns.whisperText(monday, "The Deadmines", "dps", AT, os.date)
        :find("^Up for The Deadmines on Mon 18:30%? We need damage%.$"))
      assert.are.equal("For SM: Graveyard 20:30" .. DOT .. "need a healer",
        PlannedRuns.askNote(today, name, "heal", AT, os.date))
      assert.are.equal("For SM: Graveyard 20:30", PlannedRuns.askNote(today, name, nil, AT, os.date))
    end)

  end)
end)
