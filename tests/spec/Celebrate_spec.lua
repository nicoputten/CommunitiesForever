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
    assert.is_truthy(b.line:find("1 of 5$"))
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
    for _, id in ipairs(set) do done[id] = state.serverTime end
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
end)
