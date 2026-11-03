local helpers = require("helpers")

describe("Celebrations (CF-67)", function()
  local C, Feats

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/Pvp.lua", ns)
    helpers.loadAddonFile("src/core/Feed.lua", ns)
    helpers.loadAddonFile("src/core/Loot.lua", ns)
    Feats = helpers.loadAddonFile("src/core/Feats.lua", ns)
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/DoomsdayView.lua", ns)
    C = helpers.loadAddonFile("src/core/Celebrations.lua", ns)
  end)

  local DOT = " \194\183 "
  local SET = { "d.quests10", "d.level", "d.dungeon", "p.loneWolf" }

  local function today(done) return { set = SET, done = done } end

  describe("your goals", function()
    it("a PvE daily: small, green edge, the board's texts (CB01)", function()
      local list = C.goalMoments({ newly = { "d.level" }, today = today({ ["d.quests10"] = 100, ["d.level"] = 200 }),
                                   dayLabel = "Wed evening", duelDone = false })
      assert.are.equal(1, #list)
      local m = list[1]
      assert.are.same({ "daily", "small", "pve", "goal" }, { m.kind, m.weight, m.edge, m.icon })
      assert.are.equal("Daily goal" .. DOT .. "PvE", m.kicker)
      assert.are.equal("Gain a level", m.title)
      assert.are.equal("Wed evening" .. DOT .. "2 of 5", m.line)
      assert.are.equal("+5", m.points)
      assert.are.equal("today", m.view)
    end)

    it("the goal's own points in the day's pool version (CF-69)", function()
      local day = { set = { "d.campfire", "d.level", "d.dungeon" }, done = { ["d.campfire"] = 1 }, pool = 2 }
      assert.are.equal("+1", C.goalMoments({ newly = { "d.campfire" }, today = day })[1].points)
      day.pool = nil
      assert.are.equal("+5", C.goalMoments({ newly = { "d.campfire" }, today = day })[1].points)
    end)

    it("a Skirmish: red edge, its name before the colon", function()
      local m = C.goalMoments({ newly = { "p.loneWolf" }, today = today({ ["p.loneWolf"] = 1 }),
                                dayLabel = "Wed evening", duelDone = true })[1]
      assert.are.equal("pvp", m.edge)
      assert.are.equal("Daily goal" .. DOT .. "PvP", m.kicker)
      assert.are.equal("Lone wolf", m.title)
      assert.are.equal("Wed evening" .. DOT .. "2 of 5", m.line)
    end)

    it("the third PvE daily completes the day: one day moment, with the crown and the points (CB02)", function()
      local done = { ["d.quests10"] = 100, ["d.level"] = 200, ["d.dungeon"] = 300 }
      local list = C.goalMoments({ newly = { "d.dungeon" }, today = today(done), dayLabel = "Wed evening",
                                   crownMine = true, points = { pve = 15, pvp = 10 }, streak = 6 })
      assert.are.equal(1, #list)
      local m = list[1]
      assert.are.same({ "day", "medium", "day", "emblem" }, { m.kind, m.weight, m.edge, m.icon })
      assert.are.equal("Day complete", m.kicker)
      assert.are.equal("Wed evening", m.title)
      assert.are.equal("PvE 15" .. DOT .. "PvP 10" .. DOT .. "6 days", m.line)
      assert.is_true(m.crown)
    end)

    it("the day is complete without the PvP goals; a Skirmish in the same batch stays its own moment", function()
      local done = { ["d.quests10"] = 100, ["d.level"] = 200, ["d.dungeon"] = 300, ["p.loneWolf"] = 300 }
      local list = C.goalMoments({ newly = { "d.dungeon", "p.loneWolf" }, today = today(done) })
      assert.are.same({ "daily", "day" }, { list[1].kind, list[2].kind })
      assert.are.equal("Lone wolf", list[1].title)
      assert.is_false(list[2].crown)
    end)

    it("no day moment when the day was already complete", function()
      local done = { ["d.quests10"] = 100, ["d.level"] = 200, ["d.dungeon"] = 300, ["p.loneWolf"] = 400 }
      local list = C.goalMoments({ newly = { "p.loneWolf" }, today = today(done) })
      assert.are.same({ "daily" }, { list[1].kind })
      assert.are.equal(1, #list)
    end)

    it("a weekly and the Bounty (CB03)", function()
      local week = { set = { "w.days3", "w.dungeonsDiff3", "w.quests50", "b.allClasses" },
                     done = { ["w.days3"] = 1, ["w.dungeonsDiff3"] = 2, ["b.allClasses"] = 3 } }
      local list = C.goalMoments({ weekly = { "w.dungeonsDiff3", "b.allClasses" }, thisWeek = week,
                                   weekLabel = "Week 44" })
      local w, b = list[1], list[2]
      assert.are.same({ "weekly", "medium", "weekly", "hourglass" }, { w.kind, w.weight, w.edge, w.icon })
      assert.are.equal("Weekly goal", w.kicker)
      assert.are.equal("Run 3 different dungeons", w.title)
      assert.are.equal("Week 44" .. DOT .. "3 of 4", w.line)
      assert.are.equal("+15", w.points)
      assert.are.equal("week", w.view)
      assert.are.same({ "bounty", "bounty", "swords" }, { b.kind, b.edge, b.icon })
      assert.are.equal("Bounty", b.kicker)
      assert.are.equal("A kill of every enemy class", b.title)
      assert.are.equal("Week 44", b.line)
    end)

    it("the day line: points side by side, never a total, and the streak", function()
      assert.are.equal("PvE 0" .. DOT .. "PvP 0", C.dayLine(nil, 0, ""))
      assert.are.equal("PvE 5" .. DOT .. "PvP 0" .. DOT .. "* 1 day", C.dayLine({ pve = 5, pvp = 0 }, 1, "*"))
    end)

    it("the week label from the calendar week (Sunday first)", function()
      local fake = function(fmt) return fmt == "%U" and "44" or nil end
      assert.are.equal("Week 44", C.weekLabel(1, fake))
      assert.is_nil(C.weekLabel(nil, fake))
    end)
  end)

  describe("feats (CB04)", function()
    it("special feats are big; the rest medium", function()
      assert.is_true(C.special({ key = "pvpRank:6", kind = "pvpRank" }))
      assert.is_false(C.special({ key = "pvpRank:5", kind = "pvpRank" }))
      assert.is_true(C.special({ key = "honorKills:1000", kind = "honorKills" }))
      assert.is_false(C.special({ key = "honorKills:100", kind = "honorKills" }))
      for _, kind in ipairs({ "maxLevel", "firstEpic", "mount", "epicMount" }) do
        assert.is_true(C.special({ key = kind, kind = kind }))
      end
      assert.is_false(C.special({ key = "level:50", kind = "level" }))
    end)

    it("a rank feat: big, the rank name and the character with its rank", function()
      local m = C.featMoment({ key = "pvpRank:6", kind = "pvpRank", title = "Stone Guard" }, "Ves Doombringer")
      assert.are.same({ "feat", "big", "day", "rank" }, { m.kind, m.weight, m.edge, m.icon })
      assert.are.equal("Feat unlocked", m.kicker)
      assert.are.equal("Stone Guard", m.title)
      assert.are.equal("Ves Doombringer" .. DOT .. "rank 6", m.line)
      assert.is_nil(m.badge)
      assert.are.equal("feats", m.view)
    end)

    it("the first epic, first in the group: violet edge and the badge", function()
      local m = C.featMoment({ key = "firstEpic", kind = "firstEpic", title = "Staff of Jordan" }, "Icyra Frostwhisper",
        true)
      assert.are.same({ "big", "epic", "epic" }, { m.weight, m.edge, m.icon })
      assert.are.equal("First in the group", m.badge)
      assert.are.equal("Icyra Frostwhisper" .. DOT .. "first epic", m.line)
    end)

    it("a normal feat: medium, the character alone; first in the group makes it big", function()
      local f = { key = "honorKills:100", kind = "honorKills", title = "100 honorable kills" }
      local m = C.featMoment(f, "Ves Doombringer")
      assert.are.same({ "medium", "swords", "Ves Doombringer" }, { m.weight, m.icon, m.line })
      assert.are.equal("big", C.featMoment(f, "Ves Doombringer", true).weight)
      assert.are.equal("emblem", C.featMoment({ key = "level:20", kind = "level", title = "Level 20" }, "X").icon)
    end)

    it("first in the group: nobody else holds the key", function()
      local others = { { { key = "level:10" } }, { { key = "mount" }, { key = "level:20" } } }
      assert.is_true(C.firstInGroup("maxLevel", others))
      assert.is_false(C.firstInGroup("mount", others))
      assert.is_true(C.firstInGroup("mount", {}))
    end)
  end)

  describe("folding (CB05)", function()
    local function daily(n) return { kind = "daily", weight = "small", key = "daily:" .. n } end
    local day = { kind = "day", weight = "medium", key = "day", crown = true }
    local feat = { kind = "feat", weight = "big", key = "feat:pvpRank:6", title = "Stone Guard" }
    local weekly = { kind = "weekly", weight = "medium", key = "week:w.days3" }

    it("the heaviest wins; the rest in one line in the board's order", function()
      local b = C.fold({ daily(1), day, daily(2), feat, daily(3) })
      assert.are.equal("Stone Guard", b.title)
      assert.are.equal("Day complete" .. DOT .. "+3 goals" .. DOT .. "crown", b.folded)
    end)

    it("a day complete with a weekly: ties go to the latest", function()
      assert.are.equal("Day complete" .. DOT .. "crown", C.fold({ day, weekly }).folded)
      local b = C.fold({ weekly, day })
      assert.are.equal("day", b.kind)
      assert.are.equal("+1 weekly", b.folded)
    end)

    it("one moment: nothing folded; empty: no banner", function()
      assert.is_nil(C.fold({ daily(1) }).folded)
      assert.is_nil(C.fold({}))
      assert.are.equal("+1 goal" .. DOT .. "+2 feats", C.fold({ daily(1), feat, feat, feat }).folded)
    end)
  end)

  describe("waiting", function()
    it("gathers for 3 s, then one banner", function()
      local q = C.newQueue()
      C.push(q, { { kind = "daily", weight = "small", title = "A" } }, 100)
      assert.is_nil(C.take(q, 101, false))
      assert.are.equal(2, C.waitFor(q, 101))
      C.push(q, { { kind = "daily", weight = "small", title = "B" } }, 102)
      local b = C.take(q, 103, false)
      assert.are.equal("B", b.title)
      assert.are.equal("+1 goal", b.folded)
      assert.is_nil(C.take(q, 104, false))
      assert.is_nil(C.waitFor(q, 104))
    end)

    it("waits while busy, then 2 s more", function()
      local q = C.newQueue()
      C.push(q, { { kind = "daily", weight = "small" } }, 100)
      assert.is_nil(C.take(q, 110, true))
      assert.is_nil(C.take(q, 150, false)) -- combat just ended
      assert.is_nil(C.take(q, 151, false))
      assert.is_not_nil(C.take(q, 152, false))
    end)
  end)

  describe("remembered keys", function()
    it("once, and old days and weeks forgotten", function()
      local set = {}
      assert.is_true(C.once(set, "d10:daily:x"))
      assert.is_false(C.once(set, "d10:daily:x"))
      set["d7:day"], set["w3:b.kills50"], set["w4:w.days3"], set["Player-1:mount"] = true, true, true, true
      C.prune(set, 10, 5)
      assert.is_nil(set["d7:day"])
      assert.is_nil(set["w3:b.kills50"])
      assert.is_true(set["d10:daily:x"])
      assert.is_true(set["w4:w.days3"])
      assert.is_true(set["Player-1:mount"])
    end)

    it("own keys by day, week and character", function()
      assert.are.equal("d9:daily:d.level", C.ownKey({ kind = "daily", key = "daily:d.level" }, 9, 2))
      assert.are.equal("w2:week:w.days3", C.ownKey({ kind = "weekly", key = "week:w.days3" }, 9, 2))
      assert.are.equal("G:feat:mount", C.ownKey({ kind = "feat", key = "feat:mount" }, 9, 2, "G"))
    end)
  end)

  describe("friends (CB06)", function()
    local NOW, SINCE, DAY, WEEK = 10000, 9000, 20800, 2972

    local function person(over)
      local p = { displayName = "Mira", chars = { G1 = { name = "Mira Sunstrider", classFile = "MAGE", level = 40,
                                                        updatedAt = 9500 } },
                  goals = { days = {}, weeks = {} } }
      for k, v in pairs(over or {}) do p[k] = v end
      return p
    end

    local function ctx() return { day = DAY, week = WEEK, now = NOW, since = SINCE, derive = Feats.derive } end

    it("the first sight of a friend is known, not shown", function()
      local known = {}
      local p = person()
      p.goals.days[DAY] = { set = SET, done = { ["d.quests10"] = 9900, ["d.level"] = 9900, ["d.dungeon"] = 9900 } }
      assert.are.same({}, C.friendMoments(known, { ["Mira#1001"] = p }, ctx()))
      assert.is_true(known["Mira#1001"].keys["d" .. DAY .. ":day"])
      assert.are.same({}, C.friendMoments(known, { ["Mira#1001"] = p }, ctx())) -- never twice
    end)

    it("a day complete, a weekly and a special feat after login make lines", function()
      local known = {}
      local p = person()
      C.friendMoments(known, { ["Mira#1001"] = p }, ctx())
      p.goals.days[DAY] = { set = SET, done = { ["d.quests10"] = 9900, ["d.level"] = 9900, ["d.dungeon"] = 9950 } }
      p.goals.weeks[WEEK] = { set = { "b.kills50" }, done = { ["b.kills50"] = 9960 } }
      p.chars.G1.level, p.chars.G1.updatedAt = 60, 9970
      local lines = C.friendMoments(known, { ["Mira#1001"] = p }, ctx())
      assert.are.equal(3, #lines)
      assert.are.same({ "completed the day", "day", "Mira", "Mira Sunstrider", "MAGE", "board" },
        { lines[1].text, lines[1].edge, lines[1].name, lines[1].charName, lines[1].classFile, lines[1].view })
      assert.are.same({ "finished a weekly", "bounty" }, { lines[2].text, lines[2].edge })
      assert.are.equal("reached level 60", lines[3].text)
    end)

    it("normal feats, moments before login and old ones say nothing", function()
      local known = {}
      local p = person()
      C.friendMoments(known, { ["Mira#1001"] = p }, ctx())
      p.chars.G1.level, p.chars.G1.updatedAt = 50, 9970 -- level 50: not special
      p.goals.weeks[WEEK] = { set = { "w.days3" }, done = { ["w.days3"] = 8000 } } -- before login
      assert.are.same({}, C.friendMoments(known, { ["Mira#1001"] = p }, ctx()))
      p.chars.G1.level, p.chars.G1.updatedAt = 60, 9970
      local late = ctx()
      late.now = 9970 + C.FRIEND_MAX_AGE + 1
      assert.are.same({}, C.friendMoments(known, { ["Mira#1001"] = p }, late))
    end)

    it("a friend's new character is known at first sight", function()
      local known = {}
      local p = person()
      C.friendMoments(known, { ["Mira#1001"] = p }, ctx())
      p.chars.G2 = { name = "Mira Alt", classFile = "ROGUE", level = 60, updatedAt = 9990 }
      assert.are.same({}, C.friendMoments(known, { ["Mira#1001"] = p }, ctx()))
    end)

    it("the texts of special feats", function()
      assert.are.equal("is now a Stone Guard", C.friendFeatText({ kind = "pvpRank", title = "Stone Guard" }))
      assert.are.equal("looted Robe of Volatile Power",
        C.friendFeatText({ kind = "firstEpic", title = "Robe of Volatile Power" }))
      assert.are.equal("got a mount", C.friendFeatText({ kind = "mount" }))
      assert.are.equal("got an epic mount", C.friendFeatText({ kind = "epicMount" }))
      assert.are.equal("reached 1,000 honorable kills",
        C.friendFeatText({ kind = "honorKills", title = "1,000 honorable kills" }))
    end)

    it("waiting lines are capped", function()
      local waiting = {}
      for i = 1, C.FRIEND_WAITING + 2 do C.pushFriends(waiting, { { key = i } }) end
      assert.are.equal(C.FRIEND_WAITING, #waiting)
      assert.are.equal(3, waiting[1].key)
    end)
  end)

  it("draws at 85 % below 1600 px", function()
    assert.are.equal(0.85, C.scale(1280))
    assert.are.equal(1, C.scale(1920))
    assert.are.equal(1, C.scale(nil))
  end)

  it("the Preview is a medium sample", function()
    local p = C.preview("Wed evening")
    assert.are.same({ "medium", "Day complete", "Wed evening" }, { p.weight, p.kicker, p.title })
  end)
end)
