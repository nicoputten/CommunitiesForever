local helpers = require("helpers")

-- CF-48: when reminders and starts are due, and who is where at start time.
describe("RunStart (CF-48)", function()
  local RunStart, PlannedRuns
  local NOW = 1793120000
  local ME = { battleTag = "Me#1000", guids = { ["G-ME"] = true } }

  before_each(function()
    local ns = helpers.coreNs()
    PlannedRuns = helpers.loadAddonFile("src/core/PlannedRuns.lua", ns)
    RunStart = helpers.loadAddonFile("src/core/RunStart.lua", ns)
  end)

  local function run(id, startsAt, answers, organiser)
    return { id = id, startsAt = startsAt, answers = answers or {}, organiser = organiser }
  end

  it("fires the reminder and the start once, only for runs you organise or answered in or maybe", function()
    local runs = {
      run("in", NOW + 1800, { { guid = "G-ME", answer = "in" } }),
      run("maybe", NOW + 1800, { { battleTag = "Me#1000", answer = "maybe" } }),
      run("cant", NOW + 1800, { { guid = "G-ME", answer = "cant" } }),
      run("other", NOW + 1800, { { guid = "G-BEN", answer = "in" } }),
      run("mine", NOW, {}, { battleTag = "Me#1000" }),
    }
    local due = RunStart.due(runs, ME, NOW - 15, NOW, 30)
    local seen = {}
    for _, e in ipairs(due) do seen[#seen + 1] = e.kind .. ":" .. e.run.id end
    assert.are.same({ "reminder:in", "reminder:maybe", "start:mine" }, seen)
    assert.is_true(due[3].organiser)
    assert.are.same({}, RunStart.due(runs, ME, NOW, NOW + 15, 30)) -- not again
    -- Default 30 minutes without a site setting; 0: no reminder.
    assert.are.equal(3, #RunStart.due(runs, ME, NOW - 15, NOW, nil))
    assert.are.equal(1, #RunStart.due(runs, ME, NOW - 15, NOW, 0))
  end)

  describe("states", function()
    local online = {
      ["Ben#2000"] = { guid = "G-BEN", name = "Ben Example", level = 20, gameAccountID = 5 },
      ["Cy#3000"] = { guid = "G-CY2", name = "Cy Alt", level = 33, gameAccountID = 6 },
      ["aid:abc"] = { guid = "G-DEE", name = "Dee Example", level = 21, target = "Dee Example" },
    }
    local function ctx(grouped)
      return { online = online, grouped = grouped or {}, keyOf = function(a)
        return a.guid == "G-DEE" and "aid:abc" or nil
      end }
    end
    local answers = {
      { guid = "G-ME", answer = "in" },
      { battleTag = "Ben#2000", guid = "G-BEN", name = "Ben Example", answer = "in" },
      { battleTag = "Cy#3000", guid = "G-CY", name = "Cy Example", answer = "in" },
      { guid = "G-DEE", name = "Dee Example", answer = "maybe" },
      { battleTag = "Eve#5000", name = "Eve Example", answer = "in" },
      { name = "Fay Example", answer = "cant", source = "discord" },
    }

    it("says who is ready, on another character, offline, not coming; you left out", function()
      local states = RunStart.states(run("r", NOW, answers), ME, ctx())
      local got = {}
      for _, s in ipairs(states) do got[#got + 1] = tostring(s.answer.name) .. "=" .. s.state end
      assert.are.same({ "Ben Example=ready", "Cy Example=other", "Eve Example=offline", "Dee Example=ready",
                        "Fay Example=cant" }, got)
      assert.are.equal("Cy Alt", states[2].presence.name)
      assert.are.equal("aid:abc", states[4].key) -- a community member, by GUID
    end)

    it("invites only I'm in answers that are ready and not grouped; pings the offline ones", function()
      local states = RunStart.states(run("r", NOW, answers), ME, ctx({ ["G-BEN"] = true }))
      assert.are.equal("grouped", states[1].state)
      assert.are.same({}, RunStart.readyToInvite(states)) -- Dee is only a maybe
      local missing = RunStart.missing(states)
      assert.are.same({ "Eve Example" }, { missing[1].answer.name })
      states = RunStart.states(run("r", NOW, answers), ME, ctx())
      assert.are.same({ "Ben Example" }, { RunStart.readyToInvite(states)[1].answer.name })
      assert.are.equal("Ben Example", RunStart.nextPerson(states).answer.name)
    end)

    it("tells everyone else where the organiser is", function()
      assert.are.equal("online", RunStart.organiserState(run("r", NOW, {}, { battleTag = "Ben#2000",
        guid = "G-BEN" }), ctx()))
      assert.are.equal("other", RunStart.organiserState(run("r", NOW, {}, { battleTag = "Cy#3000", guid = "G-CY" }),
        ctx()))
      assert.are.equal("offline", RunStart.organiserState(run("r", NOW, {}, { battleTag = "Eve#5000" }), ctx()))
      assert.are.equal("offline", RunStart.organiserState(run("r", NOW, {}), ctx()))
    end)
  end)

  it("words the whisper to someone on another character", function()
    assert.are.equal("You're on Tok Ironhide. Switch to Bob Example? We're starting The Deadmines.",
      RunStart.switchText("The Deadmines", "Tok Ironhide", "Bob Example"))
    assert.is_truthy(PlannedRuns)
  end)
end)
