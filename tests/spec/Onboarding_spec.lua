local helpers = require("helpers")

describe("Onboarding (CF-26)", function()
  local Onboarding

  before_each(function()
    Onboarding = helpers.loadAddonFile("src/core/Onboarding.lua", helpers.coreNs())
  end)

  local function ids(steps)
    local result = {}
    for i, step in ipairs(steps) do result[i] = step.id end
    return result
  end

  local ALL = { "welcome", "community", "name", "chat", "notifications", "done" }
  local ALT = { guid = "G-ALT", hasTab = false, inCommunity = true }

  it("shows the full wizard on the first run", function()
    local plan = Onboarding.plan({}, ALT)
    assert.are.equal("wizard", plan.kind)
    assert.are.same(ALL, ids(plan.steps))
    assert.are.same(ALL, ids(Onboarding.plan(nil, nil).steps))
  end)

  it("shows nothing after the wizard on the character it ran on", function()
    local settings = {}
    Onboarding.finish(settings, "G-MAIN")
    assert.is_true(settings.onboarded)
    assert.are.equal(Onboarding.VERSION, settings.onboardedVersion)
    assert.is_nil(Onboarding.plan(settings, { guid = "G-MAIN", hasTab = false, inCommunity = true }))
  end)

  it("offers only the Community tab on other characters in the community without one", function()
    local settings = {}
    Onboarding.finish(settings, "G-MAIN")
    assert.are.same({ kind = "chatPrompt" }, Onboarding.plan(settings, ALT))
    assert.is_nil(Onboarding.plan(settings, { guid = "G-ALT", hasTab = true, inCommunity = true }))
    assert.is_nil(Onboarding.plan(settings, { guid = "G-ALT", hasTab = false, inCommunity = false }))
  end)

  it("stops asking a character after Don't ask again", function()
    local settings = {}
    Onboarding.finish(settings, "G-MAIN")
    Onboarding.dontAsk(settings, "G-ALT")
    assert.is_nil(Onboarding.plan(settings, ALT))
  end)

  it("shows only new steps to existing users after a new version", function()
    Onboarding.VERSION = 2
    table.insert(Onboarding.STEPS, 5, { id = "planner", title = "Dungeon planner", since = 2 })
    local plan = Onboarding.plan({ onboarded = true, onboardedVersion = 1 }, ALT)
    assert.are.equal("wizard", plan.kind)
    assert.are.same({ "welcome", "planner", "done" }, ids(plan.steps))
    -- Seen version 2: nothing new, the chat prompt again.
    assert.are.same({ kind = "chatPrompt" }, Onboarding.plan({ onboarded = true, onboardedVersion = 2 }, ALT))
  end)

  it("keeps the step list when no step is new", function()
    assert.are.same({}, Onboarding.steps(Onboarding.VERSION))
    assert.are.same(ALL, ids(Onboarding.steps()))
  end)

  it("words the progress", function()
    assert.are.equal("Step 4 of 6", Onboarding.progress(4, 6))
  end)
end)
