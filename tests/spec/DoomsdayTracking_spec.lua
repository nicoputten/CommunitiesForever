local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Doomsday goals tracked and shared (CF-56)", function()
  local state, ns, addon
  local CET, RESET = 3600, 68400

  -- The first day from launch whose dailies hold `id`.
  local function dayWith(D, id)
    for n = D.EPOCH, D.EPOCH + 60 do
      for _, g in ipairs(D.draw(n).dailies) do
        if g == id then return n end
      end
    end
  end

  -- setup(state) runs before the addon loads, afterLoad() after its files (Data\Runs.lua sets CF_RUNS).
  local function load(setup, afterLoad)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    if afterLoad then afterLoad() end
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
  end

  local function goals() return addon.db.global.self.goals end
  local questId = 9000
  local function quest()
    questId = questId + 1 -- a quest the log doesn't know: it counts under the zone you're in
    wowapi.fireEvent(state, "QUEST_TURNED_IN", questId, 500, 0)
  end

  -- Logs in on another character of the same account.
  local function switchTo(guid, name, level)
    state.player.guid, state.player.name, state.player.level = guid, name, level
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD")
  end

  after_each(function()
    wowapi.uninstall()
    _G.CF_RUNS = nil
  end)

  it("marks a daily done from progress on two characters, with its time", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = dayWith(D, "d.quests10")
    local start = D.dayStart(n, CET, RESET)
    load(function(s) s.serverTime = start + 3600 end)
    state.zone = "Westfall"
    for _ = 1, 6 do quest() end
    assert.is_nil(goals().days[n].done["d.quests10"])
    switchTo("Player-4619-0A0A0A0A", "Ves Alt", 20)
    state.serverTime = start + 7200
    for _ = 1, 4 do quest() end
    assert.are.equal(start + 7200, goals().days[n].done["d.quests10"])
    assert.is_true(addon.db.global.self.doomsday.days[n].chars["Player-4619-0A0A0A0A"])
    -- /cf doomsday shows it.
    state.slash.cf("doomsday")
    local all = table.concat(state.printed, "\n")
    assert.is_truthy(all:find("Finish 10 quests: done", 1, true))
    assert.is_truthy(all:find("CET/CEST", 1, true))
  end)

  it("turns the day at the reset and the week on Sunday", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local saturday = D.weekStart(D.week(D.EPOCH) + 1) - 1
    local start = D.dayStart(saturday, CET, RESET)
    load(function(s) s.serverTime = start + 86400 - 60 end)
    assert.is_table(goals().days[saturday])
    state.serverTime = start + 86400
    quest()
    assert.is_table(goals().days[saturday + 1])
    assert.is_table(goals().weeks[D.week(saturday) + 1])
    assert.are.equal(D.week(saturday) + 1, D.week(saturday + 1))
  end)

  it("turns the day at the reset with nothing happening in game, checked every minute", function()
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
    local n = D.EPOCH + 3
    local start = D.dayStart(n, CET, RESET)
    local ticks = {}
    load(function(s)
      s.serverTime = start + 86400 - 90
      _G.C_Timer.NewTicker = function(seconds, fn) ticks[#ticks + 1] = { seconds = seconds, fn = fn } end
    end)
    local tick
    for _, t in ipairs(ticks) do
      if t.seconds == 60 then tick = t.fn end
    end
    local changed = #wowapi.sentMessages(state, ns.DoomsdayTracker.CHANGED)
    -- A minute before the reset: still the same day, nothing to tell.
    state.serverTime = start + 86400 - 30
    tick()
    assert.is_nil(goals().days[n + 1])
    assert.are.equal(changed, #wowapi.sentMessages(state, ns.DoomsdayTracker.CHANGED))
    -- Past the reset: the new day's goals are drawn and told once (the window, the swap lines, the send).
    state.serverTime = start + 86400 + 30
    tick()
    assert.is_table(goals().days[n + 1])
    assert.are.equal(changed + 1, #wowapi.sentMessages(state, ns.DoomsdayTracker.CHANGED))
    tick()
    assert.are.equal(changed + 1, #wowapi.sentMessages(state, ns.DoomsdayTracker.CHANGED))
  end)

  it("takes the reset setting from the runs file, and a friend's newer one from HELLO", function()
    load(nil, function()
      _G.CF_RUNS = { updatedAt = 10, runs = {}, doomsday = { reset = 72000, changedAt = 50, offset = 25200 } }
    end)
    assert.are.same({ reset = 72000, changedAt = 50, offset = 25200 }, addon.db.global.settings.doomsdayReset)
    assert.are.same({ reset = 72000, offset = 25200, source = "site" }, ns.DoomsdayTracker.schedule())
    assert.is_false(ns.DoomsdayTracker.receiveSetting({ reset = 68400, changedAt = 40 }))
    assert.is_true(ns.DoomsdayTracker.receiveSetting({ reset = 68400, changedAt = 60 }))
    assert.are.equal(68400, ns.DoomsdayTracker.schedule().reset)
  end)

  -- CF-68: the site's mission schedule, from the runs file and SavedVariables.
  describe("the site's mission schedule (CF-68)", function()
    local cases = helpers.readJson("tests/fixtures/doomsday-cases.json").scheduled
    local D = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())

    -- A day's set with the swaps undone (the test character can't do every goal).
    local function beforeSwaps(entry)
      local list = {}
      for i, id in ipairs(entry.set) do list[i] = entry.swapped[id] or id end
      return list
    end

    local function file(schedule)
      return function() _G.CF_RUNS = { updatedAt = 10, runs = {}, doomsday = { schedule = schedule } } end
    end

    it("uses the runs file's schedule for the day it lists and keeps it", function()
      local c = cases[1]
      load(function(s) s.serverTime = D.dayStart(c.day, CET, RESET) + 3600 end, file(c.schedule))
      local day = c.schedule.days[tostring(c.day)]
      local scheduled = { day.daily[1], day.daily[2], day.daily[3], day.skirmish }
      assert.are.same(scheduled, beforeSwaps(goals().days[c.day]))
      assert.are.equal(c.schedule.v, addon.db.global.doomsdaySchedule.v)
      assert.are.equal(c.schedule.v, ns.DoomsdayTracker.missionScheduleVersion())
      -- The next day is the normal draw.
      state.serverTime = state.serverTime + 86400
      quest()
      local normal = D.draw(c.day + 1)
      assert.are.same({ normal.dailies[1], normal.dailies[2], normal.dailies[3], normal.skirmish },
        beforeSwaps(goals().days[c.day + 1]))
    end)

    it("keeps the set of a day already recorded", function()
      local c
      for _, case in ipairs(cases) do
        if case.recorded then c = case end
      end
      local start = D.dayStart(c.day, CET, RESET)
      local recorded = { set = c.recorded.set, swapped = c.recorded.swapped, done = {}, at = start + 60 }
      load(function(s)
        s.serverTime = start + 3600
        s.savedVariables = { global = { self = { goals = { days = { [c.day] = recorded } } } } }
      end, file(c.schedule))
      assert.are.equal(c.schedule.v, ns.DoomsdayTracker.missionScheduleVersion()) -- taken, but today stays
      assert.are.same(c.expect.set, goals().days[c.day].set)
      assert.are.same(c.expect.swapped, goals().days[c.day].swapped)
    end)

    it("drops days and weeks that are over at login, and starts without one when none is stored", function()
      local c = cases[1]
      local later = D.dayStart(c.day + 2, CET, RESET) + 3600
      local stored = { v = 7, days = { [tostring(c.day)] = c.schedule.days[tostring(c.day)],
                                       [tostring(c.day + 3)] = { skirmish = "p.loneWolf" } },
                       weeks = { ["2960"] = { bounty = "b.zone25" } } }
      load(function(s)
        s.serverTime = later
        s.savedVariables = { global = { doomsdaySchedule = stored } }
      end)
      assert.are.same({ v = 7, days = { [tostring(c.day + 3)] = { skirmish = "p.loneWolf" } }, weeks = {} },
        addon.db.global.doomsdaySchedule)
      wowapi.uninstall()
      load()
      assert.is_nil(addon.db.global.doomsdaySchedule)
      assert.are.equal(0, ns.DoomsdayTracker.missionScheduleVersion())
    end)
  end)

  it("sends goals in RECORD and the setting in HELLO", function()
    load()
    ns.DoomsdayTracker.receiveSetting({ reset = 68400, changedAt = 60 })
    local record = ns.Merge.outgoingRecord(addon.db.global.self, ns.DoomsdayTracker.outgoing())
    local today = ns.DoomsdayTracker.today()
    assert.is_table(record.goals.days[today])
    assert.are.equal(ns.Doomsday.POOL_VERSION, record.goals.pool)
    assert.are.equal(68400, record.goals.reset)
    state.bnSent = {}
    ns.Sync.announce()
    for _ = 1, 20 do
      state.time = state.time + 1
      wowapi.runTimers(state)
    end
    local codec = ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
    local reassembler, hello = ns.Protocol.reassembler(), nil
    for _, call in ipairs(state.bnSent) do
      local encoded = reassembler:add(call[1], call[3], 0)
      local message = encoded and codec:decode(encoded)
      if message and message.t == "HELLO" then hello = message end
    end
    assert.is_table(hello)
    assert.are.same({ reset = 68400, changedAt = 60 }, hello.dd)
  end)

  it("stores a friend's goals, keeps them for a record without (or false), takes newer days", function()
    load()
    local people = addon.db.global.people
    local bt = state.friends[1].battleTag
    local chars = { ["Player-4619-01789956"] = { name = "Garraka Doombringer", level = 11, updatedAt = 1 } }
    local function goalsAt(at)
      return { days = { [20800] = { set = { "d.quests10" }, done = { ["d.quests10"] = at }, at = at } },
               weeks = {}, streak = 1, best = 1, pool = 1 }
    end
    ns.Merge.store(people, { bt = bt, version = 10, chars = chars, goals = goalsAt(500) }, 1000, bt)
    assert.are.equal(500, people[bt].goals.days[20800].done["d.quests10"])
    ns.Merge.store(people, { bt = bt, version = 11, chars = chars }, 1000, bt)
    assert.is_table(people[bt].goals)
    ns.Merge.store(people, { bt = bt, version = 12, chars = chars, goals = false }, 1000, bt)
    assert.is_table(people[bt].goals)
    ns.Merge.store(people, { bt = bt, version = 13, chars = chars, goals = goalsAt(400) }, 1000, bt)
    assert.are.equal(500, people[bt].goals.days[20800].done["d.quests10"]) -- an older day doesn't undo it
    assert.are.same(people[bt].goals, ns.Merge.relayRecord(people, bt).goals)
  end)

  it("counts fish, trades with a friend, crafted items given away and discoveries locally", function()
    local stubs = { IsFishingLoot = function() return true end, GetNumLootItems = function() return 2 end,
                    GetTradePlayerItemLink = function(slot)
                      return slot == 1 and "|cffffffff|Hitem:14342::::|h[Mooncloth]|h|r" or nil
                    end,
                    ERR_TRADE_COMPLETE = "Trade complete.", ERR_ZONE_EXPLORED = "Discovered: %s" }
    load(function(s)
      for name, value in pairs(stubs) do _G[name] = value end
      s.unitGuids = { NPC = "Player-4619-01789956" } -- Garraka, the friend's character
    end)
    addon.db.global.people[state.friends[1].battleTag] = { version = 1, chars = {
      ["Player-4619-01789956"] = { name = "Garraka Doombringer", level = 11 } } }
    wowapi.fireEvent(state, "LOOT_OPENED")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:14342::::|h[Mooncloth]|h|r.")
    wowapi.fireEvent(state, "TRADE_SHOW")
    wowapi.fireEvent(state, "TRADE_PLAYER_ITEM_CHANGED", 1)
    wowapi.fireEvent(state, "UI_INFO_MESSAGE", 0, "Trade complete.")
    wowapi.fireEvent(state, "UI_INFO_MESSAGE", 0, "Discovered: Lake Everstill")
    wowapi.fireEvent(state, "UI_INFO_MESSAGE", 0, "Not enough mana.")
    local today = ns.DoomsdayTracker.today()
    local week = addon.db.global.self.doomsday.weeks[ns.Doomsday.week(today)]
    assert.are.same({ 2, 1, 1, 1 }, { week.fish, week.trades, week.craftTrade, week.discoveries })
    for name in pairs(stubs) do _G[name] = nil end
  end)

  it("caches the state until something changes, with fresh countdowns (CF-59)", function()
    load()
    local first = ns.DoomsdayTracker.state()
    local before = first.resetsIn
    state.serverTime = state.serverTime + 60
    local second = ns.DoomsdayTracker.state()
    assert.are.equal(first, second) -- the same table: not rebuilt
    assert.are.equal(before - 60, second.resetsIn) -- the countdown moved on
    quest()
    assert.are_not.equal(second, ns.DoomsdayTracker.state())
    local third = ns.DoomsdayTracker.state()
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, "Ada#1001")
    assert.are_not.equal(third, ns.DoomsdayTracker.state())
  end)
end)
