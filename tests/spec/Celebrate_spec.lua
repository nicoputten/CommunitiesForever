local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Celebration banners in game (CF-67)", function()
  local state, ns, addon, D
  local CET, RESET = 3600, 68400
  local DOT = " \194\183 "

  local function dayWith(id)
    for n = D.EPOCH, D.EPOCH + 60 do
      for _, g in ipairs(D.draw(n).dailies) do
        if g == id then return n end
      end
    end
  end

  local function load(setup)
    D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = dayWith("d.quests10")
    state, ns, addon = helpers.client({ setup = function(s)
      s.serverTime = D.dayStart(n, CET, RESET) + 3600
      if setup then setup(s) end
    end })
    _G.SOUNDKIT.IG_QUEST_LIST_COMPLETE = 878
    _G.SOUNDKIT.UI_EPICLOOT_TOAST = 31578
    return n
  end

  local questId = 9000
  local function quests(count)
    for _ = 1, count do
      questId = questId + 1
      wowapi.fireEvent(state, "QUEST_TURNED_IN", questId, 500, 0)
    end
  end

  -- Lets `seconds` pass and runs the timers due.
  local function wait(seconds)
    state.time = state.time + seconds
    state.serverTime = state.serverTime + seconds
    wowapi.runTimers(state)
  end

  local function shown() return ns.CelebrationBanner.shown() end

  after_each(function()
    wowapi.uninstall()
  end)

  it("a daily done: the small banner after 3 s, with its sound (CB01)", function()
    load()
    quests(10)
    assert.are.equal(0, #shown())
    wait(3)
    assert.are.equal(1, #shown())
    local b = shown()[1]
    assert.are.equal("Daily goal" .. DOT .. "PvE", b.kicker)
    assert.are.equal("Finish 10 quests", b.title)
    assert.is_truthy(b.line:find("1 of 6$")) -- CF-104: the Hunt counts too
    assert.are.same({ 878 }, state.sounds)
    local frame = ns.CelebrationBanner.frame()
    assert.is_true(frame:IsShown())
    assert.are.same({ 400, 64 }, { frame:GetWidth(), frame:GetHeight() })
    assert.are.equal("DAILY GOAL" .. DOT .. "PVE", frame.kicker:GetText())
    assert.are.equal("+3", frame.pointsText:GetText()) -- CF-77: its size in pool version 2
    -- The same goal again (another CHANGED): nothing twice.
    addon:SendMessage(ns.DoomsdayTracker.CHANGED, { "d.quests10" }, {})
    wait(10)
    assert.are.equal(1, #shown())
  end)

  it("hover tells what a click opens; a click opens Doomsday › Today; right-click dismisses", function()
    load()
    quests(10)
    wait(3)
    local frame = ns.CelebrationBanner.frame()
    frame:RunScript("OnClick", "LeftButton")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal("doomsday", ns.MainFrame.tabs().active)
    assert.are.equal("today", ns.DoomsdayTab.current())
    assert.is_false(frame:IsShown())
    ns.Celebrate.preview()
    assert.is_true(frame:IsShown())
    frame:RunScript("OnClick", "RightButton")
    assert.is_false(frame:IsShown())
  end)

  it("waits in combat, then 2 s after it", function()
    load()
    state.inCombat = true
    quests(10)
    wait(5)
    assert.are.equal(0, #shown())
    state.inCombat = false
    wait(1)
    assert.are.equal(0, #shown())
    wait(2)
    assert.are.equal(1, #shown())
  end)

  it("nothing with banners off; no sound with sounds off", function()
    load()
    ns.Settings.options().args.celebrations.set({}, false)
    quests(10)
    wait(5)
    assert.are.equal(0, #shown())
    ns.Settings.options().args.celebrations.set({}, true)
    ns.Settings.options().args.celebrationSounds.set({}, false)
    ns.Celebrate.preview()
    assert.are.equal(1, #shown())
    assert.are.same({}, state.sounds)
  end)

  it("settings: a Celebrations section, friends greyed out with banners off, Preview (CB09)", function()
    load()
    ns.SettingsWindow.open()
    local banners = ns.SettingsWindow.control("celebrations")
    local friends = ns.SettingsWindow.control("celebrationFriends")
    assert.are.equal("Celebration banners", banners.text:GetText())
    assert.are.equal("Celebration sounds", ns.SettingsWindow.control("celebrationSounds").text:GetText())
    assert.are.equal("Friends' celebrations", friends.text:GetText())
    assert.is_true(banners:GetChecked() and friends:IsEnabled())
    banners:RunScript("OnClick")
    assert.is_false(addon.db.global.settings.celebrations)
    assert.is_false(friends:IsEnabled())
    friends:RunScript("OnClick") -- greyed out: no change
    assert.is_nil(addon.db.global.settings.celebrationFriends)
    ns.SettingsWindow.control("celebrationPreview"):RunScript("OnClick")
    local b = shown()[1]
    assert.are.same({ "medium", "Day complete" }, { b.weight, b.kicker })
    assert.are.same({ 470, 80 }, { ns.CelebrationBanner.frame():GetWidth(), ns.CelebrationBanner.frame():GetHeight() })
    assert.are.same({ 31578 }, state.sounds)
  end)

  it("a friend's day complete after login: one quiet line, no sound (CB06)", function()
    local n = load()
    local start = D.dayStart(n, CET, RESET)
    local bt = state.friends[1].battleTag
    local set = addon.db.global.self.goals.days[n].set
    local person = { displayName = "Mira", version = 1, goals = { days = {}, weeks = {} },
                     chars = { G1 = { name = "Mira Sunstrider", classFile = "MAGE", level = 30, updatedAt = 1 } } }
    addon.db.global.people[bt] = person
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt) -- the first sight: known
    assert.are.same({}, ns.CelebrationBanner.friendTexts())
    local done = {}
    for _, id in ipairs(set) do
      if id ~= "hunt" then done[id] = state.serverTime end -- CF-122: the Hunt has a line of its own
    end
    person.goals.days[n] = { set = set, done = done, at = start }
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt)
    local lines = ns.CelebrationBanner.friendTexts()
    assert.are.equal(1, #lines)
    local plain = lines[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    assert.are.equal("Mira Mira Sunstrider" .. DOT .. "completed the day", plain)
    assert.are.same({}, state.sounds)
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt)
    assert.are.equal(1, #ns.CelebrationBanner.friendTexts()) -- never twice
  end)

  it("a friend bags the quarry: a line in the friend bar with today's combination (CF-122)", function()
    local n = load()
    local bt = state.friends[1].battleTag
    local person = { displayName = "Grom", version = 1, goals = { days = {}, weeks = {} },
                     chars = { G1 = { name = "Grom Ashfeller", classFile = "WARRIOR", faction = "Horde", level = 30,
                                      updatedAt = 1 } } }
    addon.db.global.people[bt] = person
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt) -- the first sight: known
    person.goals.days[n] = { set = { "hunt" }, done = { hunt = state.serverTime }, at = state.serverTime }
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt)
    local lines = ns.CelebrationBanner.friendTexts()
    assert.are.equal(1, #lines)
    local plain = lines[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local combo = ns.HuntAlerts.comboText(ns.DoomsdayTracker.huntFor("Horde"))
    assert.is_string(combo)
    assert.are.equal("Grom Grom Ashfeller" .. DOT .. "bagged the quarry" .. DOT .. combo, plain)
    assert.are.same({}, state.sounds)
  end)

  it("new feats right after login are known, later ones celebrate (CB04)", function()
    load()
    local level60 = { key = "maxLevel", kind = "maxLevel", title = "Level 60" }
    addon:SendMessage(ns.DoomsdayBoard.FEATS, { { guid = state.player.guid, key = "maxLevel", feat = level60 } })
    wait(5)
    assert.are.equal(0, #shown())
    wait(10)
    addon:SendMessage(ns.DoomsdayBoard.FEATS, { { guid = state.player.guid, key = "maxLevel", feat = level60 } })
    wait(3)
    local b = shown()[1]
    assert.are.same({ "big", "Feat unlocked", "Level 60" }, { b.weight, b.kicker, b.title })
    assert.are.equal("First in the group", b.badge)
    assert.are.same({ 540, 98 }, { ns.CelebrationBanner.frame():GetWidth(), ns.CelebrationBanner.frame():GetHeight() })
  end)

  -- CF-85: without a community this character is in, Doomsday is tracked quietly: no banner, sound, friends' line
  -- or crown toast; picking one counts today's progress right away and brings up nothing old.
  describe("without a community (CF-85)", function()
    local function loadPassive()
      D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
      local n = dayWith("d.quests10")
      state, ns, addon = helpers.client({ clubId = false, setup = function(s)
        s.serverTime = D.dayStart(n, CET, RESET) + 3600
        s.clubs = {}
      end })
      _G.SOUNDKIT.IG_QUEST_LIST_COMPLETE = 878
      _G.SOUNDKIT.UI_EPICLOOT_TOAST = 31578
      assert.is_true(ns.CommunitySelection.passive())
      return n
    end

    it("records a daily but shows no banner and plays no sound; joining counts it and shows nothing old", function()
      local n = loadPassive()
      quests(10)
      wait(5)
      assert.are.equal(0, #shown())
      assert.are.same({}, state.sounds)
      assert.is_number(addon.db.global.self.goals.days[n].done["d.quests10"]) -- tracked
      -- A community appears: picked, today's goal counts at once, the old moment stays quiet.
      table.insert(state.clubs, { clubId = "555", name = "New Friends", clubType = 1 })
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      assert.are.equal("555", ns.CommunitySelection.active())
      assert.is_number(ns.DoomsdayTracker.state().today.done["d.quests10"])
      wait(10)
      assert.are.equal(0, #shown())
      assert.are.same({}, state.sounds)
    end)

    it("shows no crown toast and no friends' lines", function()
      local n = loadPassive()
      local start = D.dayStart(n, CET, RESET)
      local day = addon.db.global.self.goals.days[n]
      for i, id in ipairs(day.set) do
        if (ns.Doomsday.goal(id) or {}).slot == "daily" then day.done[id] = start + 60 * i end
      end
      ns.DoomsdayTracker.invalidate() -- the goals were changed by hand
      addon:SendMessage(ns.DoomsdayTracker.CHANGED, {}, {})
      assert.are.equal(0, #ns.CrownToast.shown())
      -- Told once a day: picking a community later doesn't bring it up.
      table.insert(state.clubs, { clubId = "555", name = "New Friends", clubType = 1 })
      wowapi.fireEvent(state, "CLUB_ADDED", "555")
      addon:SendMessage(ns.DoomsdayTracker.CHANGED, {}, {})
      assert.are.equal(0, #ns.CrownToast.shown())
      ns.CrownToast.reset()

      -- A friend's record (from before the switch to passive) brings no line either.
      wowapi.uninstall()
      n = loadPassive()
      local bt = state.friends[1].battleTag
      local set = addon.db.global.self.goals.days[n].set
      local done = {}
      for _, id in ipairs(set) do done[id] = state.serverTime end
      addon.db.global.people[bt] = { displayName = "Mira", version = 1, goals = { days = { [n] = { set = set,
        done = done, at = start } }, weeks = {} },
        chars = { G1 = { name = "Mira Sunstrider", classFile = "MAGE", level = 30, updatedAt = 1 } } }
      addon:SendMessage(ns.Sync.PEOPLE_UPDATED, bt)
      wait(5)
      assert.are.same({}, ns.CelebrationBanner.friendTexts())
      assert.are.equal(0, #ns.Celebrate.waiting())
    end)
  end)
end)
