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

  it("has one item per open API question of VERIFY.md, and none for answered ones", function()
    local ns, open = checklist(), openQuestions()
    local ids = {}
    for _, item in ipairs(ns.items) do
      assert.is_nil(ids[item.id], "twice: " .. item.id)
      ids[item.id] = true
      if item.id:match("^V%d") then assert.is_true(open[item.id] == true, item.id .. " is not open in VERIFY.md") end
    end
    for id in pairs(open) do assert.is_true(ids[id] == true, id .. " (open in VERIFY.md) has no checklist item") end
    assert.is_true(next(open) ~= nil)
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
    local state, printed

    local function login(serverTime)
      state = wowapi.install()
      state.serverTime = serverTime
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
      assert.are.equal("pass", _G.FriendProbeDB.results.V63.status) -- date() works in the mock
      assert.is_true(ns.running())
      local report = ns.report()
      assert.is_truthy(report:find("1. First login alone", 1, true))
      assert.is_truthy(report:find("V78", 1, true))
      ns.toggleWindow() -- opens without errors
      assert.are.same({}, printed)
    end)

    it("stops by itself after 18 Nov", function()
      local ns = login(1794960000 + 60)
      assert.is_false(ns.running())
      assert.is_nil(_G.FriendProbeDB.results)
    end)
  end)
end)
