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
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
  end

  local function texts()
    local list = {}
    for i, t in ipairs(ns.DoomsdayTab.texts()) do list[i] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end

  local function quest() wowapi.fireEvent(state, "QUEST_TURNED_IN", 9000 + math.random(999), 500, 0) end

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
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", {})
    local n = dayWith(D, "d.quests10")
    load(function(s) s.serverTime = D.dayStart(n, CET, RESET) + 3600 end)
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("doomsday")
    assert.are.equal("doomsday", ns.MainFrame.tabs().active)
    local t = texts()
    assert.is_truthy(t:find("\nToday \194\183 " .. D.label(n) .. " \194\183 0 of 4 done\n", 1, true))
    assert.is_truthy(t:find("\nFinish 10 quests\n", 1, true))
    assert.is_truthy(t:find("\n0/10\n", 1, true))
    assert.is_truthy(t:find("\nFirst duel with each friend\n", 1, true))
    assert.is_truthy(t:find("\nStreak 0 days \194\183 best 0\n", 1, true))
    assert.are.equal("resets in 23 h 0 m", ns.DoomsdayTab.resetLabel())
    local window = ns.MainFrame.window()
    assert.are.equal(ns.DoomsdayTab.NOTE, window.footerRightText.text)
    ns.DoomsdayTab.chips().week:RunScript("OnClick")
    t = texts()
    assert.is_truthy(t:find("\nThis week \194\183 15 points each\n", 1, true))
    assert.is_truthy(t:find("\nPER CHARACTER\n", 1, true))
    assert.is_truthy(t:find("Ves Doombringer", 1, true))
  end)

  it("says a daily is done in chat, and keeps quiet with the setting off", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", {})
    local n = dayWith(D, "d.quests10")
    load(function(s) s.serverTime = D.dayStart(n, CET, RESET) + 3600 end)
    for _ = 1, 10 do quest() end
    assert.is_true(printed("Daily done: Finish 10 quests (+5 PvE, 1 of 3 today)"))
    ns.Settings.options().args.doomsdayChat.set({}, false)
    state.printed = {}
    for _ = 1, 10 do quest() end
    assert.are.same({}, state.printed)
  end)

  it("shows the toast when you take the crown, and says it when someone else has it", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", {})
    local n = dayWith(D, "d.quests10")
    local start = D.dayStart(n, CET, RESET)
    load(function(s) s.serverTime = start + 3600 end)
    local day = addon.db.global.self.goals.days[n]
    for i, id in ipairs(day.set) do
      if ns.Doomsday.goal(id).slot == "daily" then day.done[id] = start + 60 * i end
    end
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
    assert.is_true(printed("Mira finished Doomsday first today. You're at 0 of 4."))
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
end)
