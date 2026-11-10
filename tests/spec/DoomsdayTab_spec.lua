local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Doomsday tab, chat lines and the toast (CF-57a)", function()
  local state, ns, addon
  local CET, RESET = 3600, 68400

  local function dayWith(D, id)
    for n = D.EPOCH, D.EPOCH + 60 do
      for _, g in ipairs(D.draw(n).dailies) do
        if g == id then return n end
      end
    end
  end

  local function load(setup)
    state, ns, addon = helpers.client({ setup = setup })
  end

  local function texts()
    local list = {}
    for i, t in ipairs(ns.DoomsdayTab.texts()) do list[i] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  local questId = 9000
  local function quest()
    questId = questId + 1 -- a quest the log doesn't know: it counts under the zone you're in
    wowapi.fireEvent(state, "QUEST_TURNED_IN", questId, 500, 0)
  end

  local function printed(text)
    for _, line in ipairs(state.printed) do
      if line:find(text, 1, true) then return true end
    end
    return false
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("adds a Doomsday tab with Today and Week", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = dayWith(D, "d.quests10")
    load(function(s) s.serverTime = D.dayStart(n, CET, RESET) + 3600 end)
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("doomsday")
    assert.are.equal("doomsday", ns.MainFrame.tabs().active)
    local t = texts()
    -- CF-61: "Wed evening" in your own clock, and the Duel slot counts in "N of M done".
    local label = ns.DoomsdayView.dayLabel(D.dayStart(n, CET, RESET), os.date) or D.label(n)
    -- CF-104: the Hunt counts too.
    assert.is_truthy(t:find("\nToday \194\183 " .. label .. " \194\183 0 of 6 done\n", 1, true))
    assert.is_truthy(t:find("\nFinish 10 quests\n", 1, true))
    assert.is_truthy(t:find("\n0/10\n", 1, true))
    -- CF-118: from pool version 6 the Duel slot is the day's duel mission ("First duel with each friend" is one).
    -- (swapped within the duel pool when no friend is known: "Duel a friend" becomes "Win a duel").
    assert.are.equal("p.spar", D.draw(n).duel)
    assert.is_truthy(t:find("\nDuel\n", 1, true) and t:find("\nWin a duel\n", 1, true))
    -- CF-62: points per goal, the stat boxes, the Friends today mini board, the swap note in an ⓘ.
    assert.is_truthy(t:find("\n+5\n", 1, true))
    assert.is_truthy(t:find("\nToday\n", 1, true) and t:find("\nThis week\n", 1, true))
    assert.is_truthy(t:find("\nStreak\n", 1, true))
    assert.is_truthy(t:find("0 days", 1, true) and t:find("best 0", 1, true))
    assert.is_truthy(t:find("\nFriends today\n", 1, true))
    -- The first-duel tooltip ("Win +3") is on the Duel row only when the day's Duel slot is p.duelFirst (CF-118).
    assert.is_falsy(table.concat(ns.DoomsdayTab.tips(), "\n"):find("Win +3", 1, true))
    -- CF-61/62: the reset in the view's header, with the time; no notes about the rules or the site.
    assert.is_truthy(t:find("in 23 h 0 m\n", 1, true))
    assert.is_truthy(t:find("\nNew goals ", 1, true))
    assert.is_falsy(t:find("Any of your characters counts", 1, true))
    local window = ns.MainFrame.window()
    assert.are.equal("", window.footerRightText.text)
    ns.DoomsdayTab.chips().week:RunScript("OnClick")
    t = texts()
    assert.is_truthy(t:find("\nThis week\n", 1, true))
    -- (CF-118: the pool-6 draw puts the test's day on a Saturday: under a day left)
    assert.is_truthy(t:find("\nWeek resets %a+ %d%d:%d%d \194\183 in %d+ [dh] %d+ [hm]\n"))
    assert.is_falsy(t:find("New goals in", 1, true))
    assert.is_truthy(t:find("\nPER CHARACTER\n", 1, true))
    assert.is_truthy(t:find("Ves Doombringer", 1, true))
  end)

  it("counts down while open and shows the new day after the reset", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = D.EPOCH + 3
    local start = D.dayStart(n, CET, RESET)
    local ticks = {}
    load(function(s)
      s.serverTime = start + 3600
      _G.C_Timer.NewTicker = function(seconds, fn) ticks[#ticks + 1] = { seconds = seconds, fn = fn } end
    end)
    local function minute()
      for _, t in ipairs(ticks) do t.fn() end
    end
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("doomsday")
    assert.is_truthy(texts():find("in 23 h 0 m\n", 1, true))
    state.serverTime = start + 3 * 3600
    minute()
    assert.is_truthy(texts():find("in 21 h 0 m\n", 1, true))
    -- Across the reset, the tab still open: the next day, its goals and a full day to go.
    state.serverTime = start + 86400 + 60
    minute()
    local label = ns.DoomsdayView.dayLabel(D.dayStart(n + 1, CET, RESET), os.date) or D.label(n + 1)
    assert.is_truthy(texts():find("\nToday \194\183 " .. label .. " \194\183 ", 1, true))
    assert.is_truthy(texts():find("in 23 h 59 m\n", 1, true))
    assert.is_table(addon.db.global.self.goals.days[n + 1])
    -- Closed: no redraws.
    ns.MainFrame.toggle()
    state.serverTime = start + 86400 + 660
    minute()
    assert.is_truthy(texts():find("in 23 h 59 m\n", 1, true))
  end)

  it("says nothing in chat when a daily is done (CF-91: the banner shows it)", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = dayWith(D, "d.quests10")
    load(function(s) s.serverTime = D.dayStart(n, CET, RESET) + 3600 end)
    state.printed = {}
    for _ = 1, 10 do quest() end
    assert.is_true(addon.db.global.self.goals.days[n].done["d.quests10"] ~= nil)
    assert.are.same({}, state.printed)
    assert.is_nil(ns.Settings.options().args.doomsdayChat) -- CF-91: the switch is gone
  end)

  it("shows the toast when you take the crown, and nothing when someone else has it", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = dayWith(D, "d.quests10")
    local start = D.dayStart(n, CET, RESET)
    load(function(s) s.serverTime = start + 3600 end)
    local day = addon.db.global.self.goals.days[n]
    for i, id in ipairs(day.set) do
      if (ns.Doomsday.goal(id) or {}).slot == "daily" then day.done[id] = start + 60 * i end
    end
    ns.DoomsdayTracker.invalidate() -- the goals were changed by hand
    addon:SendMessage(ns.DoomsdayTracker.CHANGED, {}, {})
    local shown = ns.CrownToast.shown()
    assert.are.equal(1, #shown)
    assert.are.equal("First to finish today!", shown[1].title)
    assert.is_truthy(shown[1].line:find("All three dailies done at", 1, true))
    addon:SendMessage(ns.DoomsdayTracker.CHANGED, {}, {})
    assert.are.equal(1, #ns.CrownToast.shown()) -- once a day

    -- Another day: a friend crossed out first.
    ns.CrownToast.reset()
    wowapi.uninstall()
    load(function(s) s.serverTime = start + 3600 end)
    local bt = state.friends[1].battleTag
    local set = addon.db.global.self.goals.days[n].set
    local done = {}
    for _, id in ipairs(set) do done[id] = start + 10 end
    local goals = { days = { [n] = { set = set, done = done, at = start + 10 } }, weeks = {} }
    addon.db.global.people[bt] = { displayName = "Mira", version = 1, chars = {}, goals = goals }
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt)
    assert.is_false(printed("Mira finished Doomsday first today. You're at 0 of 6.")) -- CF-91: no chat line
    assert.are.equal(0, #ns.CrownToast.shown())
  end)

  it("puts the PvP line on a friend's character card", function()
    load()
    local guid = state.clubMembers["23125681"][2].guid
    local bt = state.friends[1].battleTag
    ns.Merge.store(addon.db.global.people, { bt = bt, version = 10, chars = {
      [guid] = { guid = guid, name = "Garraka Doombringer", classFile = "MAGE", level = 11, faction = "Horde",
                 updatedAt = 5, pvp = { hk = 1234, rank = 6 } } } }, 1000, bt)
    ns.MainFrame.toggle()
    local tab = helpers.friendsTab(ns)
    for _, r in ipairs(ns.FriendsTab.rows()) do
      if r.kind == "char" and r.path:find(guid, 1, true) then tab.click(r.frame) end
    end
    assert.is_true(tab.has("Stone Guard, a.k.a. Mailbox Menace \194\183 1,234 honorable kills"))
  end)

  describe("Board, Ladder and Feats (CF-57b)", function()
    local D, n, start

    local function setup()
      D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
      n = dayWith(D, "d.quests10")
      start = D.dayStart(n, CET, RESET)
      load(function(s) s.serverTime = start + 3600 end)
      local bt = state.friends[1].battleTag
      local set = addon.db.global.self.goals.days[n].set
      local done = {}
      for _, id in ipairs(set) do done[id] = start + 600 end
      local guid = state.clubMembers["23125681"][2].guid
      addon.db.global.people[bt] = { displayName = "Mira", version = 3, goals = {
        days = { [n] = { set = set, done = done, at = start + 600 } }, weeks = {}, streak = 6 },
        chars = { [guid] = { name = "Garraka Doombringer", classFile = "MAGE", level = 11, pvp = { hk = 3 } } },
        feed = { [n] = { [guid] = { pvpKills = { { t = start + 700, name = "Grim Tusk", lvl = 12, myLvl = 11 } } } } } }
      addon.db.global.people["Tok#1003"] = { displayName = "Tok", version = 2, chars = {} }
      ns.MainFrame.toggle()
      ns.MainFrame.selectTab("doomsday")
    end

    it("shows everyone's goals on the Board, crossed out and crowned", function()
      setup()
      ns.DoomsdayTab.chips().board:RunScript("OnClick")
      local t = texts()
      assert.is_truthy(t:find("\nFRIEND\n", 1, true))
      assert.is_truthy(t:find("\n10 QUESTS\n", 1, true)) -- the goal's shortLabel
      assert.is_truthy(t:find("\nPOINTS\n", 1, true))
      -- CF-61c: the streak is in the name's tooltip (CF-118: a goal like "Streak 20" may be a column).
      assert.is_falsy(t:find("\nSTREAK\n", 1, true))
      assert.is_truthy(t:find("\nMira\n", 1, true))
      assert.is_truthy(t:find("\n%d%d:%d%d  crown\n")) -- the finish time and the crown after the name
      assert.is_falsy(t:find("0/10", 1, true)) -- a check or a box, the progress in the tooltip
      -- CF-104: the Hunt done, +5; CF-118: the Duel slot's mission too (+5: the entry has no pool, so it scores flat)
      assert.is_truthy(t:find("\nPvE 15 \194\183 PvP 16\n", 1, true))
      assert.is_truthy(t:find("\nno Doomsday data yet\n", 1, true)) -- Tok, an older addon
      local tips = table.concat(ns.DoomsdayTab.tips(), "\n|\n")
      assert.is_truthy(tips:find("Finish 10 quests\n0/10", 1, true)) -- your own progress
      assert.is_truthy(tips:find("Finish 10 quests\nMira \194\183 done ", 1, true)) -- Mira's
      assert.is_truthy(tips:find("\194\183 resets ", 1, true)) -- CF-63: when the goals reset
      -- CF-63 (board CF63DoomBoard): drawn 15 px boxes, no text characters; Mira's are all done.
      local done, open = 0, 0
      for _, b in ipairs(ns.DoomsdayTab.goalBoxes()) do
        assert.are.equal(15, b.width)
        if b.done then done = done + 1 else open = open + 1 end
        assert.are.equal(b.done, b.check.shown)
      end
      assert.is_true(done > 0 and open > 0)
      assert.is_falsy(t:find("\226\150\161", 1, true)) -- no box character
      assert.is_falsy(t:find("\226\156\147", 1, true)) -- no check character
      assert.is_truthy(tips:find("Streak 6 days\nAll three PvE dailies done at ", 1, true))
      local board = ns.DoomsdayBoard.board()
      local mira
      for _, row in ipairs(board.rows) do
        if row.name == "Mira" then mira = row end
      end
      assert.is_true(mira.crossed)
      assert.is_true(mira.crown)
      -- the Skirmish, the Hunt, the Duel slot's mission (CF-118), a kill
      assert.are.same({ pve = 15, pvp = 5 + 5 + 5 + 1 }, mira.today)
    end)

    it("shows Friends today on Today: you, a crossed-out friend with the crown (CF-62)", function()
      setup()
      local t = texts()
      assert.is_truthy(t:find("\nFriends today\n", 1, true))
      assert.is_truthy(t:find("\nYou\n", 1, true))
      assert.is_truthy(t:find("\nMira\n", 1, true) and t:find("\ncrown\n", 1, true))
      assert.is_truthy(table.concat(ns.DoomsdayTab.tips(), "\n"):find("Live for friends online", 1, true))
    end)

    it("ranks this week on the Ladder, PvE and PvP apart, the PvP Virgin unranked", function()
      setup()
      ns.DoomsdayTab.chips().ladder:RunScript("OnClick")
      local t = texts()
      assert.is_truthy(t:find("\nPvE\n", 1, true) and t:find("\nPvP\n", 1, true))
      local l = ns.DoomsdayBoard.ladder()
      assert.are.equal("Solvar#2032", l.pve[1].friend)
      assert.are.equal(15, l.pve[1].points)
      assert.are.same({ "Vestras#1000" }, l.virgins)
      assert.is_truthy(t:find("PvP Virgin", 1, true))
      assert.is_falsy(t:find("All-time totals", 1, true)) -- CF-61: no note about the site
      assert.is_truthy(t:find("Week resets", 1, true))
    end)

    it("lists the feats earned while watched; what a character already had folds into one line", function()
      setup()
      ns.DoomsdayTab.chips().feats:RunScript("OnClick")
      local t = texts()
      -- CF-61: one "Already had" line, the details on hover.
      assert.is_truthy(t:find("Already had: Level 10", 1, true))
      assert.is_falsy(t:find("earlier", 1, true))
      assert.is_truthy(table.concat(ns.DoomsdayTab.tips(), "\n"):find("Level 10 \194\183 Reached level 10", 1, true))
      wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 20)
      local feats = addon.db.global.self.feats[state.player.guid]
      assert.are.equal(state.serverTime, feats["level:20"].at)
      ns.DoomsdayTab.chips().feats:RunScript("OnClick")
      assert.is_truthy(texts():find("Level 20  \194\183 Reached level 20 \194\183 ", 1, true)) -- earned: listed
    end)
  end)
end)
