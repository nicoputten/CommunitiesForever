local helpers = require("helpers")

describe("DoomsdayView (CF-57)", function()
  local V, D

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/Pvp.lua", ns)
    D = helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    V = helpers.loadAddonFile("src/core/DoomsdayView.lua", ns)
  end)

  local function scored(kill, points, extra)
    local s = { kill = kill, points = points, counted = true, track = "pvp", day = 1 }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
  end

  it("builds goal rows with progress, done times, swaps and the Hunt", function()
    local entry = { set = { "d.quests10", "d.altLevel", "hunt", "x.new" },
                    swapped = { ["d.quests10"] = "d.shared3" }, done = { ["d.altLevel"] = 500 } }
    local progress = { ["d.quests10"] = { value = 7, target = 10 }, ["d.altLevel"] = { value = 1, target = 1 } }
    local rows = V.rows(entry, progress, { { race = "NightElf", class = "DRUID" } })
    assert.are.same({ id = "d.quests10", kind = "Daily", text = "Finish 10 quests", value = 7, target = 10,
                      done = false, fraction = 0.7, instead = "Share 3 quests with a friend" }, rows[1])
    assert.are.same({ true, 500, 1 }, { rows[2].done, rows[2].at, rows[2].fraction })
    assert.are.same({ "Hunt", "Night Elf Druids" }, { rows[3].kind, rows[3].text })
    assert.are.equal("A goal from a newer version", rows[4].text)
    assert.are.same({ 1, 4 }, { V.doneCount(rows) })
  end)

  it("sums up today's kills", function()
    assert.is_nil(V.killSummary({}))
    local list = {
      scored({ lvl = 30, myLvl = 30, solo = true }, 2), scored({ lvl = 33, myLvl = 30 }, 2),
      scored({ lvl = -1, myLvl = 30 }, 3), scored({ lvl = 20, myLvl = 30 }, 0), scored({}, 1),
      scored({ lvl = 30, myLvl = 30 }, 1, { track = "bg" }),
    }
    assert.are.equal("5 kills: 1 near level, 1 solo, 2 above, 1 below", V.killSummary(list))
  end)

  it("shows the Duel slot: who you dueled and who's still open", function()
    local duels = { { day = 5, a = "Ada#1", b = "Bob#2", winner = "Ada#1", disputed = false },
                    { day = 5, a = "Ada#1", b = "Cy#3", disputed = true },
                    { day = 4, a = "Ada#1", b = "Mira#4", winner = "Mira#4" } }
    local slot = V.duelSlot(duels, 5, "Ada#1", { ["Bob#2"] = "Bob", ["Cy#3"] = "Cy", ["Mira#4"] = "Mira" },
      { "Bob#2", "Cy#3", "Mira#4" })
    assert.are.same({ { name = "Bob", won = true, disputed = false }, { name = "Cy", won = false, disputed = true } },
      slot.done)
    assert.are.same({ "Mira" }, slot.open)
    assert.are.equal("won vs Bob", V.duelText(slot.done[1]))
    assert.are.equal("disputed vs Cy", V.duelText(slot.done[2]))
  end)

  it("says what a bounty still needs", function()
    local list = { scored({ class = "WARRIOR" }, 1), scored({ class = "MAGE" }, 1) }
    assert.are.equal("Paladin, Hunter, Rogue, Priest, Warlock, Druid", V.stillNeeded("b.allClasses", list, { "Horde" }))
    assert.are.equal("Human, Dwarf, Night Elf, Gnome", V.stillNeeded("b.allRaces", {}, { "Horde" }))
    assert.is_nil(V.stillNeeded("b.kills50", list, { "Horde" }))
  end)

  it("writes the chat lines", function()
    assert.are.equal("Daily done: Finish 10 quests (+5 PvE, 2 of 3 today)", V.dailyDoneLine("Finish 10 quests", 2, 3))
    assert.are.equal("Weekly done: Run 3 dungeons (+15 PvE)", V.weeklyDoneLine("Run 3 dungeons", "pve"))
    assert.are.equal("Skirmish done: Lone wolf: 3 solo kills (+5 PvP)", V.skirmishDoneLine("Lone wolf: 3 solo kills"))
    assert.are.equal("Hunt done: a Night Elf Druid fell to Ada Nightshade (+5 PvP)",
      V.huntDoneLine({ race = "NightElf", class = "DRUID" }, "Ada Nightshade"))
    assert.are.equal("Kill: +2 PvP \194\183 3 levels above you, and solo (+1)",
      V.killLine(scored({ lvl = 33, myLvl = 30, solo = true }, 3)))
    assert.are.equal("Kill: +3 PvP \194\183 a skull", V.killLine(scored({ lvl = -1, myLvl = 30 }, 3)))
    assert.are.equal("Kill: +1 PvP \194\183 solo (+1)", V.killLine(scored({ lvl = 30, myLvl = 30, solo = true }, 2)))
    assert.is_nil(V.killLine(scored({ lvl = 30, myLvl = 30 }, 1)))
    assert.is_nil(V.killLine(scored({ lvl = 33, myLvl = 30 }, 2, { track = "bg" })))
    assert.are.equal("Mira finished Doomsday first today. You're at 3 of 5.", V.crownLine("Mira", 3, 5))
    assert.are.equal("Swapped for you: \"Gain a level on an alt\" to \"Finish 10 quests\"",
      V.swapLine("Gain a level on an alt", "Finish 10 quests"))
  end)

  it("names the day by its start and shows times after midnight with the weekday (CF-61, your clock)", function()
    assert.are.equal("morning", V.partOfDay(5))
    assert.are.equal("afternoon", V.partOfDay(12))
    assert.are.equal("evening", V.partOfDay(19))
    assert.are.equal("night", V.partOfDay(23))
    assert.are.equal("night", V.partOfDay(4))
    -- A fake clock: hours since t = 0 on "Tue" before 24 and "Wed" after.
    local function clock(fmt, t)
      local h, m = math.floor(t / 3600) % 24, math.floor(t / 60) % 60
      local day = t < 86400 and "Tue" or "Wed"
      if fmt == "%a" then return day end
      if fmt == "%H" then return string.format("%02d", h) end
      if fmt == "%H:%M" then return string.format("%02d:%02d", h, m) end
      if fmt == "%a %H:%M" then return string.format("%s %02d:%02d", day, h, m) end
      if fmt == "%Y-%m-%d" then return day end
    end
    local start = 19 * 3600
    assert.are.equal("Tue evening", V.dayLabel(start, clock))
    assert.are.equal("20:14", V.timeText(start + 3600 + 14 * 60, start, clock))
    assert.are.equal("Wed 00:04", V.timeText(86400 + 4 * 60, start, clock))
    assert.are.equal("Tue 20:14", V.timeText(start + 3600 + 14 * 60, nil, clock)) -- a time in the week
    assert.is_nil(V.dayLabel(start, function() return nil end))
  end)

  it("counts the Duel slot in N of M done once asked to (CF-61)", function()
    local rows = { { done = true }, { done = false }, { done = true } }
    assert.are.same({ 2, 3 }, { V.doneCount(rows) })
    assert.are.same({ 2, 4 }, { V.doneCount(rows, false) })
    assert.are.same({ 3, 4 }, { V.doneCount(rows, true) })
  end)

  it("writes the character card's PvP line", function()
    assert.are.equal("Stone Guard, a.k.a. Mailbox Menace \194\183 1,234 honorable kills \194\183 PvP 40 this week",
      V.pvpLine({ hk = 1234, rank = 6 }, "Horde", 40))
    -- CF-61: rank 0 is "No rank yet · N kills" once there is any PvP point; a duel ends the PvP Virgin.
    assert.are.equal("No rank yet \194\183 3 kills", V.pvpLine({ hk = 3, rank = 0 }, "Alliance", 0))
    assert.are.equal("PvP Virgin", V.pvpLine({ hk = 0, rank = 0 }, "Horde", 0))
    assert.are.equal("No rank yet \194\183 0 kills", V.pvpLine({ hk = 0, rank = 0, duelsLost = 1 }, "Horde", 0))
    assert.is_nil(V.pvpLine(nil, "Horde", 0))
    assert.is_nil(V.pvpLine({ deaths = 3 }, "Horde", 0)) -- counters unknown: nothing to say
    assert.are.equal("1,000,000", V.thousands(1000000))
    assert.are.equal("999", V.thousands(999))
  end)

  it("counts today's points and formats durations", function()
    local state = { today = { done = { ["d.quests10"] = 1, ["p.loneWolf"] = 2, ["hunt"] = 3 } },
                    dayScored = { scored({}, 2), scored({}, 4, { track = "bg" }) },
                    duels = { done = { { won = true }, { won = false }, { won = true, disputed = true } } } }
    assert.are.same({ pve = 5, pvp = 5 + 5 + 2 + 3 + 1 }, V.todayPoints(state))
    assert.are.equal("4 d 11 h", V.until_(4 * 86400 + 11 * 3600 + 120))
    assert.are.equal("11 h 30 m", V.until_(11 * 3600 + 1800))
    assert.is_function(D.goal)
  end)
end)
