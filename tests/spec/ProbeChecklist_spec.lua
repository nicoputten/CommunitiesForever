local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-60: the FriendProbe launch checklist (tools/FriendProbe) stays in step with VERIFY.md and stays silent.
describe("FriendProbe launch checklist (CF-60)", function()
  local PROBE = "tools/FriendProbe/"

  local function checklist()
    local ns = {}
    helpers.loadAddonFile(PROBE .. "Checklist.lua", ns)
    return ns
  end

  -- The open API questions of VERIFY.md: { [id] = true }.
  local function openQuestions()
    local open = {}
    for line in io.lines("VERIFY.md") do
      local id, status = line:match("^| (V%d+%a?) |.*| (%a+) |%s*$")
      if id and status == "open" then open[id] = true end
    end
    return open
  end

  it("has one item per open API question of VERIFY.md; done items are closed there (CF-61)", function()
    local ns, open = checklist(), openQuestions()
    local ids = {}
    for _, item in ipairs(ns.items) do
      assert.is_nil(ids[item.id], "twice: " .. item.id)
      ids[item.id] = true
      if item.id:match("^V%d") and item.done then
        assert.is_nil(open[item.id], item.id .. " is done but still open in VERIFY.md")
      elseif item.id:match("^V%d") then
        assert.is_true(open[item.id] == true, item.id .. " is not open in VERIFY.md")
      end
    end
    for id in pairs(open) do assert.is_true(ids[id] == true, id .. " (open in VERIFY.md) has no checklist item") end
    assert.is_true(next(open) ~= nil)
  end)

  it("ticks what Nico checked on Retail 12.1.5 and leaves the rest open (CF-61)", function()
    local done = {}
    for _, item in ipairs(checklist().items) do
      if item.done then done[#done + 1] = item.id end
    end
    table.sort(done)
    assert.are.same({ "V50b", "V54", "V55", "V61", "V63", "V68", "V71", "V77", "V78", "V80", "V81", "V82", "V83",
                      "V86" }, done)
  end)

  it("lists in the TOC only files that exist", function()
    local count = 0
    for line in io.lines(PROBE .. "FriendProbe.toc") do
      line = line:gsub("%s+$", "")
      if line ~= "" and not line:match("^#") then
        local f = io.open(PROBE .. line, "r")
        assert.is_truthy(f, "the TOC lists a missing file: " .. line)
        f:close()
        count = count + 1
      end
    end
    assert.is_true(count > 0)
  end)

  it("puts every item in one of the six sessions, and says what to do for the manual ones", function()
    local ns = checklist()
    assert.are.equal(6, #ns.sessions)
    for _, item in ipairs(ns.items) do
      assert.is_true(item.session >= 1 and item.session <= 6, item.id)
      assert.is_string(item.title, item.id)
      if not item.auto then assert.is_string(item.how, item.id .. " needs a how") end
    end
  end)

  describe("in the game (the WoW mock)", function()
    local state, printed, registered

    -- project: WOW_PROJECT_ID (18 Forever, the mock's; 1 Retail).
    local function login(serverTime, project)
      state = wowapi.install()
      state.serverTime = serverTime
      if project then _G.WOW_PROJECT_ID = project end
      -- Every event a probe frame registers (the mock's frames don't keep them).
      registered = {}
      local create = _G.CreateFrame
      _G.CreateFrame = function(...)
        local frame = create(...)
        frame.RegisterEvent = function(_, event) registered[event] = true end
        return frame
      end
      printed = {}
      _G.print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
      _G.SlashCmdList = {}
      _G.C_Timer.After = function() end -- the delayed self-whisper burst (V50b) isn't run here
      local ns = {}
      for _, file in ipairs({ "Checklist.lua", "FriendProbe.lua", "Window.lua" }) do
        local chunk = assert(loadfile(PROBE .. file))
        chunk("FriendProbe", ns)
      end
      for _, frame in ipairs(state.frames or {}) do
        local onEvent = frame.scripts.OnEvent
        if onEvent then
          onEvent(frame, "ADDON_LOADED", "FriendProbe")
          onEvent(frame, "PLAYER_LOGIN")
        end
      end
      return ns
    end

    after_each(function()
      _G.print = nil
      _G.FriendProbeDB = nil
      _G.SLASH_FRIENDPROBE1, _G.SlashCmdList = nil, nil
      wowapi.uninstall()
    end)

    it("checks and logs by itself before 18 Nov, without a word in chat", function()
      local ns = login(1793300000) -- 2026-10-30
      assert.are.same({}, printed)
      assert.is_table(_G.FriendProbeDB.log)
      assert.is_true(#_G.FriendProbeDB.log > 0)
      assert.are.equal("pass", _G.FriendProbeDB.results.forever.V63.status) -- date() works in the mock
      assert.is_true(ns.running())
      local report = ns.report()
      assert.is_truthy(report:find("1. First login alone", 1, true))
      assert.is_truthy(report:find("V78", 1, true))
      ns.toggleWindow() -- opens without errors
      assert.are.same({}, printed)
    end)

    it("dry-runs on Retail: its own results, Forever-only items greyed, no errors", function()
      local ns = login(1793300000, 1)
      assert.are.same({}, printed)
      assert.are.equal("retail", ns.client())
      assert.is_table(_G.FriendProbeDB.results.retail.V63)
      assert.is_nil(_G.FriendProbeDB.results.forever) -- a Retail answer never closes a Forever item
      assert.is_truthy(ns.report():find("client retail", 1, true))
      ns.toggleWindow()
      assert.are.same({}, printed)
    end)

    it("marks what Retail can answer", function()
      local items = checklist().items
      local retail = {}
      for _, item in ipairs(items) do
        if item.retail then retail[#retail + 1] = item.id end
      end
      table.sort(retail)
      assert.are.same({ "V47", "V48", "V54", "V55", "V61", "V62", "V63", "V64", "V65", "V66", "V67", "V68", "V69",
                        "V70", "V71", "V72", "V77", "V78", "V81", "V83", "V84", "V85", "V86" }, retail)
    end)

    it("never registers the combat log by itself, only from its button (Blizzard's popup on Retail)", function()
      for _, project in ipairs({ 18, 1 }) do
        local ns = login(1793300000, project)
        assert.is_nil(registered.COMBAT_LOG_EVENT_UNFILTERED)
        assert.is_true(registered.CHAT_MSG_COMBAT_HONOR_GAIN) -- the rest of the PvP logging runs
        for _, t in ipairs(ns.tests) do
          if t.text:find("combat log", 1, true) then t.run() end
        end
        assert.is_true(registered.COMBAT_LOG_EVENT_UNFILTERED)
        assert.is_table(ns.results().V75)
        if project == 18 then -- the last login is cleaned up by after_each
          _G.FriendProbeDB = nil
          wowapi.uninstall()
        end
      end
    end)

    it("stops by itself after 18 Nov", function()
      local ns = login(1794960000 + 60)
      assert.is_false(ns.running())
      assert.is_nil(_G.FriendProbeDB.results)
    end)
  end)
end)
