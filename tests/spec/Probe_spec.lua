local helpers = require("helpers")

-- CF-82: the hidden launch probe's results (core/Probe.lua).
describe("Probe", function()
  local Probe

  before_each(function()
    Probe = helpers.loadAddonFile("src/core/Probe.lua", helpers.coreNs())
  end)

  describe("the stop date", function()
    it("runs before 2026-11-18 00:00 UTC and stops from then on", function()
      assert.are.equal(1794960000, Probe.STOP_AT)
      assert.is_true(Probe.running(Probe.STOP_AT - 1, {}))
      assert.is_false(Probe.running(Probe.STOP_AT, {}))
      assert.is_false(Probe.running(Probe.STOP_AT + 86400, {}))
    end)

    it("stops when stopped by hand or without a time", function()
      assert.is_false(Probe.running(1000, { stopped = true }))
      assert.is_false(Probe.running(nil, {}))
      assert.is_true(Probe.running(1000, nil))
    end)
  end)

  describe("the section", function()
    it("is created per client in data without one (older versions)", function()
      local global = { self = { chars = {} } }
      local results = Probe.results(global, Probe.client(18))
      assert.are.same({ results = { forever = {} } }, global.probe)
      assert.are.equal(global.probe.results.forever, results)
      assert.are.equal("retail", Probe.client(1))
      assert.are.equal("project 5", Probe.client(5))
    end)

    it("keeps results already stored", function()
      local global = { probe = { results = { forever = { V73 = { status = "pass" } } } } }
      assert.are.equal("pass", Probe.results(global, "forever").V73.status)
    end)

    it("replaces a damaged section", function()
      local global = { probe = "broken" }
      Probe.results(global, "forever")
      assert.are.same({ results = { forever = {} } }, global.probe)
    end)
  end)

  describe("recording", function()
    local results
    before_each(function() results = {} end)

    it("stores status, detail, time and build", function()
      assert.is_true(Probe.record(results, "V74", "fail", "race secret via target", 100, "12345"))
      assert.are.same({ status = "fail", detail = "race secret via target", at = 100, build = "12345" }, results.V74)
    end)

    it("cuts the detail to 120 characters", function()
      Probe.record(results, "V73", "info", string.rep("x", 300), 1, "b")
      assert.are.equal(120, #results.V73.detail)
      assert.are.equal("...", results.V73.detail:sub(-3))
    end)

    it("keeps a pass; a later fail or info goes to later", function()
      Probe.record(results, "V74", "pass", "readable via target", 100, "b")
      assert.is_true(Probe.record(results, "V74", "fail", "secret via nameplate", 200, "b"))
      assert.are.same({ status = "pass", detail = "readable via target", at = 100, build = "b",
                        later = "secret via nameplate" }, results.V74)
      assert.is_false(Probe.record(results, "V74", "fail", "secret via nameplate", 300, "b"))
    end)

    it("lets a pass replace a fail, and keeps a fail over an info", function()
      Probe.record(results, "V74", "fail", "secret", 100, "b")
      Probe.record(results, "V74", "info", "maybe", 150, "b")
      assert.are.equal("fail", results.V74.status)
      assert.are.equal("maybe", results.V74.later)
      Probe.record(results, "V74", "pass", "readable", 200, "b")
      assert.are.same({ status = "pass", detail = "readable", at = 200, build = "b" }, results.V74)
    end)

    it("doesn't rewrite the same result", function()
      Probe.record(results, "V77", "pass", "region 3", 100, "b")
      assert.is_false(Probe.record(results, "V77", "pass", "region 3", 200, "b"))
      assert.are.equal(100, results.V77.at)
    end)

    it("keeps the last 3 log lines of an item, each cut", function()
      for i = 1, 5 do Probe.note(results, "V81", "line " .. i) end
      Probe.note(results, "V81", "line 5")
      assert.are.same({ "line 3", "line 4", "line 5" }, results.V81.log)
      Probe.note(results, "V81", string.rep("y", 200))
      assert.are.equal(120, #results.V81.log[3])
    end)

    it("throttles a unit for 60 s", function()
      local seen = {}
      assert.is_false(Probe.throttled(seen, "Player-1", 100))
      assert.is_true(Probe.throttled(seen, "Player-1", 159))
      assert.is_false(Probe.throttled(seen, "Player-2", 159))
      assert.is_false(Probe.throttled(seen, "Player-1", 160))
    end)
  end)

  describe("the size cap", function()
    -- Saved files keep the results of the checks answered at launch (CF-96) next to the running ones.
    local ids = {}
    for _, id in ipairs(Probe.IDS) do ids[#ids + 1] = id end
    for _, id in ipairs({ "V55", "V63", "V71", "V77", "V78", "V79", "V81", "V83", "V84", "V86", "V87",
                          "V90", "V93", "V94", "V95", "V98", "V99", "V100", "V102", "V103", "V104", "V105", "V106",
                          "V107", "V109", "V110", "V111", "V112", "V113", "V115", "V116", "V117", "V60", "V60c",
                          "V114", "V120", "V73", "V80", "V96", "V101", "V108", "V60b", "V142" }) do
      ids[#ids + 1] = id
    end

    local function full()
      local section = { results = { forever = {}, retail = {} } }
      for _, client in ipairs({ "forever", "retail" }) do
        for _, id in ipairs(ids) do
          Probe.record(section.results[client], id, "fail", string.rep("d", 200), 1794000000, "65000")
          Probe.record(section.results[client], id, "info", string.rep("l", 200), 1794000000, "65000")
          for i = 1, 3 do Probe.note(section.results[client], id, i .. string.rep("n", 200)) end
        end
      end
      return section
    end

    it("estimates about what the saved file writes", function()
      local r = { status = "pass", detail = "region 3", at = 1, build = "1" }
      local section = { results = { forever = { V77 = r } } }
      local size = Probe.size(section)
      assert.is_true(size > 60 and size < 200, tostring(size))
    end)

    it("stays under 30 KB with every item full on two clients, log lines going first", function()
      local section = full()
      assert.is_true(Probe.size(section) > Probe.MAX_BYTES)
      local after = Probe.trim(section)
      assert.is_true(after <= Probe.MAX_BYTES, tostring(after))
      assert.are.equal(after, Probe.size(section))
      for _, id in ipairs(Probe.IDS) do
        assert.are.equal("fail", section.results.forever[id].status)
        assert.are.equal("fail", section.results.retail[id].status)
      end
    end)

    it("drops the oldest log lines first and keeps the rest", function()
      local section = full()
      local lines = 0
      local limit = Probe.size(section) - 2000
      Probe.trim(section, limit)
      for _, id in ipairs(Probe.IDS) do
        local log = section.results.forever[id].log
        if log then
          lines = lines + #log
          assert.are.equal("3", log[#log]:sub(1, 1))
        end
        assert.is_not_nil(section.results.forever[id].later)
      end
      assert.is_true(lines > 0)
    end)

    it("leaves a small section alone", function()
      local section = { results = { forever = { V77 = { status = "pass", detail = "region 3", log = { "a" } } } } }
      Probe.trim(section)
      assert.are.same({ "a" }, section.results.forever.V77.log)
    end)
  end)

  describe("the Hunt", function()
    it("reports the victim picked at a counted kill and the path that found it, without a name (CF-110, CF-117)",
      function()
      assert.are.same({ "pass", "Orc WARRIOR via target, dead after the delay, 2 candidates" },
        { Probe.huntPick({ name = "Grim Tusk", race = "Orc", class = "WARRIOR", source = "target", path = "later" },
          2) })
      assert.are.same({ "pass", "Orc WARRIOR via target, dead at once" },
        { Probe.huntPick({ name = "Grim Tusk", race = "Orc", class = "WARRIOR", source = "target", path = "dead" }) })
      assert.are.same({ "info", "victim via mouseover, dead at once, without race and class, 1 candidate" },
        { Probe.huntPick({ name = "Grim Tusk", class = "WARRIOR", source = "mouseover", path = "dead" }, 1) })
      assert.are.same({ "info", "kill counted, no victim: no enemy player as target, mouseover or nameplate dead, "
        .. "0 candidates" }, { Probe.huntPick(nil, 0) })
      assert.is_nil(Probe.HUNT_PATHS.health) -- CF-120: no low health path (V143: health is secret)
      assert.are.equal("pass", (Probe.huntPick({ race = "Orc", class = "MAGE", source = "nameplate" })))
      for _, pick in ipairs({ { name = "Grim Tusk", race = "Orc", class = "WARRIOR", source = "target" },
                              { name = "Grim Tusk", source = "target", path = "dead" } }) do
        assert.is_nil(select(2, Probe.huntPick(pick, 1)):find("Grim", 1, true))
      end
    end)
  end)

  -- CF-120: V74, an enemy player with a skull.
  describe("a skull's level (V74)", function()
    it("passes on -1 and on a readable level 10 or more above yours", function()
      assert.are.same({ "pass", "skull: UnitLevel -1 via nameplate" }, { Probe.skull(-1, 20, false, "nameplate") })
      assert.are.same({ "pass", "10+ levels above: UnitLevel 30 at own 20 (not -1) via target" },
        { Probe.skull(30, 20, false, "target") })
      assert.are.same({ "info", "enemy player's UnitLevel secret via mouseover" },
        { Probe.skull(nil, 20, true, "mouseover") })
    end)

    it("gives nothing for an ordinary or unknown level", function()
      assert.is_nil(Probe.skull(29, 20, false, "target"))
      assert.is_nil(Probe.skull(25, nil, false, "target"))
      assert.is_nil(Probe.skull(nil, 20, false, "target"))
      assert.is_nil(Probe.skull(30, 0, false, "target"))
    end)
  end)

  -- CF-120: V123, the zone's PvP type at every zone change.
  describe("the zone's PvP type (V123)", function()
    it("counts each zone once per type", function()
      local counts = {}
      assert.is_true(Probe.zoneSeen(counts, "Durotar", nil))
      assert.is_false(Probe.zoneSeen(counts, "Durotar", ""))
      assert.is_true(Probe.zoneSeen(counts, "Orgrimmar", "friendly"))
      assert.is_true(Probe.zoneSeen(counts, nil, "sanctuary"))
      assert.are.same({ none = { Durotar = true }, friendly = { Orgrimmar = true }, sanctuary = { ["?"] = true } },
        counts)
      assert.are.same({ "info", "zones per type: friendly 1, none 1, sanctuary 1" }, { Probe.zoneResult(counts) })
    end)

    it("passes once a type other than friendly, sanctuary or none was read", function()
      local counts = {}
      Probe.zoneSeen(counts, "Ashenvale", "hostile")
      Probe.zoneSeen(counts, "The Barrens", nil)
      Probe.zoneSeen(counts, "Ratchet", nil)
      assert.are.same({ "pass", "zones per type: hostile 1, none 2" }, { Probe.zoneResult(counts) })
    end)
  end)

  describe("the report", function()
    it("summarises and lists every check, open ones too", function()
      local results = {}
      Probe.record(results, "V74", "pass", "skull: UnitLevel -1 via target", 100, "65000")
      Probe.record(results, "V82", "fail", "IsInGroup secret", 100, "65000")
      Probe.record(results, "V82", "info", "later one", 100, "65000")
      Probe.note(results, "V82", "a line")
      Probe.note(results, "error", "PLAYER_DEAD: boom")
      local c = Probe.summary(results)
      assert.are.same({ pass = 1, fail = 1, info = 0, open = #Probe.IDS - 2 }, c)
      local lines = Probe.report(results, "forever", true, function(t) return "T" .. t end)
      assert.are.equal(string.format("Probe (forever): 1 pass, 1 fail, 0 info, %d open; running until 18 November.",
        #Probe.IDS - 2), lines[1])
      local text = table.concat(lines, "\n")
      assert.truthy(text:find("V74 pass: skull: UnitLevel -1 via target [T100, build 65000]", 1, true))
      assert.truthy(text:find("V82 fail: IsInGroup secret (later: later one) [T100, build 65000]\n  a line", 1, true))
      assert.truthy(text:find("V122 open", 1, true))
      assert.is_nil(text:find("V63", 1, true)) -- answered at launch (CF-96): no longer in the report
      assert.truthy(text:find("error: PLAYER_DEAD: boom", 1, true))
      assert.are.equal("Probe (retail): 1 pass, 1 fail, 0 info, " .. (#Probe.IDS - 2) .. " open; stopped.",
        Probe.summaryLine(results, "retail", false))
    end)

    it("keeps stored results of checks answered at launch, and leaves them out of the report (CF-96)", function()
      local results = {}
      Probe.record(results, "V63", "pass", "date: 14:48", 100, "70790")
      Probe.record(results, "V87", "fail", "playerGuid no, battleTag no", 100, "70790")
      local c = Probe.summary(results)
      assert.are.same({ pass = 0, fail = 0, info = 0, open = #Probe.IDS }, c)
      local text = table.concat(Probe.report(results, "forever", true), "\n")
      assert.is_nil(text:find("V87", 1, true))
      assert.are.equal("pass", results.V63.status) -- untouched: the upload still carries it
      for _, id in ipairs({ "V55", "V63", "V71", "V77", "V78", "V79", "V81", "V83", "V84", "V86",
                            "V87", "V90", "V93", "V94", "V95", "V98", "V99", "V100", "V102", "V103", "V104", "V105",
                            "V106", "V107", "V109", "V110", "V111", "V112", "V113", "V115", "V116", "V117",
                            "V60", "V60c", "V114", "V120", "V73", "V80",
                            "V96", "V101", "V108", "V60b", "V142" }) do -- CF-105, CF-109, CF-113, CF-116, CF-120
        for _, current in ipairs(Probe.IDS) do assert.are_not.equal(id, current) end
      end
    end)
  end)
end)
