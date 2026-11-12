local helpers = require("helpers")

-- CF-122: the rules of the Hunt alerts (board HB01).
describe("Hunt alerts (CF-122)", function()
  local H, C, D
  local DOT = " \194\183 "
  local DRUID = { race = 4, class = 11 } -- Night Elf Druid (ids, pool version 6)

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/Pvp.lua", ns)
    D = helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/DoomsdayView.lua", ns)
    C = helpers.loadAddonFile("src/core/Celebrations.lua", ns)
    H = helpers.loadAddonFile("src/core/HuntAlerts.lua", ns)
  end)

  local function unit(extra)
    local u = { enemy = true, player = true, raceId = 4, classId = 11, race = "NightElf", class = "DRUID" }
    for k, v in pairs(extra or {}) do u[k] = v end
    return u
  end

  describe("the mark", function()
    it("is open for today's quarry, bagged once the Hunt is done", function()
      assert.are.equal("open", H.mark(DRUID, false, unit()))
      assert.are.equal("bagged", H.mark(DRUID, true, unit()))
    end)

    it("is nothing for others, friends, no Hunt or an unknown race", function()
      assert.is_nil(H.mark(DRUID, false, unit({ classId = 1, class = "WARRIOR" })))
      assert.is_nil(H.mark(DRUID, false, unit({ enemy = false })))
      assert.is_nil(H.mark(DRUID, false, unit({ player = false })))
      assert.is_nil(H.mark(nil, false, unit()))
      assert.is_nil(H.mark(DRUID, false, unit({ raceId = false, race = false })))
      assert.is_nil(H.mark(DRUID, false, nil))
    end)
  end)

  describe("the toast", function()
    local function sight(memory, guid, now, extra)
      local input = { mark = "open", guid = guid, now = now, day = 100 }
      for k, v in pairs(extra or {}) do input[k] = v end
      return H.toast(memory, input)
    end

    it("shows once per enemy per 10 minutes and at most once a minute", function()
      local m = H.newMemory()
      assert.are.same({ kind = "open", sound = true }, sight(m, "A", 1000))
      assert.is_nil(sight(m, "A", 1010))
      assert.is_nil(sight(m, "B", 1000 + H.TOAST_GAP - 1)) -- another enemy, within the minute
      assert.are.same({ kind = "open", sound = false }, sight(m, "B", 1000 + H.TOAST_GAP))
      assert.is_nil(sight(m, "A", 1000 + H.TOAST_EVERY - 1))
      assert.is_truthy(sight(m, "A", 1000 + H.TOAST_EVERY))
    end)

    it("plays its sound only at the first sighting of each day", function()
      local m = H.newMemory()
      assert.is_true(sight(m, "A", 1000).sound)
      assert.is_false(sight(m, "B", 2000).sound)
      assert.is_true(sight(m, "C", 3000, { day = 101 }).sound)
    end)

    it("is quiet when the quarry is already bagged: no sound, and the day's sound stays for later", function()
      local m = H.newMemory()
      assert.are.same({ kind = "bagged", sound = false }, sight(m, "A", 1000, { mark = "bagged" }))
      assert.is_nil(m.soundDay)
    end)

    it("never shows in a battleground or arena, without a mark, GUID or time", function()
      local m = H.newMemory()
      assert.is_nil(sight(m, "A", 1000, { instanceType = "pvp" }))
      assert.is_nil(sight(m, "A", 1000, { instanceType = "arena" }))
      assert.is_nil(sight(m, "A", 1000, { mark = false }))
      assert.is_nil(sight(m, nil, 1000))
      assert.is_nil(sight(m, "", 1000))
      assert.is_nil(sight(m, "A", nil))
      assert.is_nil(H.toast(nil, { mark = "open", guid = "A", now = 1 }))
      assert.is_truthy(sight(m, "A", 1000, { instanceType = "none" })) -- nothing above was recorded
    end)

    it("forgets enemies seen long ago", function()
      local m = H.newMemory()
      sight(m, "A", 0)
      sight(m, "B", H.TOAST_EVERY)
      assert.is_nil(m.seen.A)
    end)

    it("has the board's texts", function()
      assert.are.same({ kicker = "Prey in sight", title = "Night Elf Druid",
                        line = "+5 PvP" .. DOT .. "keep them targeted",
                        tip = "Today's quarry" .. DOT .. "Night Elf Druid" .. DOT .. "+5 PvP" },
        H.toastText("open", DRUID))
      assert.are.equal("Already bagged today" .. DOT .. "no points", H.toastText("bagged", DRUID).line)
      assert.are.same({ "NE", "UN", "HU" }, { H.initials(DRUID), H.initials({ race = "Scourge" }),
                                              H.initials({ race = "Human" }) })
      assert.are.same({ "DRUID", "MAGE" }, { H.classFile(DRUID), H.classFile({ class = "MAGE" }) })
    end)
  end)

  describe("the kill", function()
    it("is first in the group when no friend bagged one earlier today", function()
      assert.is_true(H.firstInGroup(500, {}))
      assert.is_true(H.firstInGroup(500, { 600, "x" }))
      assert.is_true(H.firstInGroup(500, { 500 }))
      assert.is_false(H.firstInGroup(500, { 499 }))
      assert.is_false(H.firstInGroup(nil, {}))
    end)

    it("is the big Quarry bagged banner", function()
      local m = H.killMoment({ hunt = DRUID, zone = "Ashenvale", clock = "21:02" }, true)
      assert.are.same({ key = "daily:hunt", kind = "daily", weight = "big", edge = "pvp", icon = "crosshair",
                        kicker = "Quarry bagged", title = "Night Elf Druid", line = "Ashenvale" .. DOT .. "21:02",
                        points = "+5 PvP", badge = "First in the group", view = "today" }, m)
      local plain = H.killMoment({ hunt = DRUID }, false)
      assert.are.same({ "", nil }, { plain.line, plain.badge })
      assert.are.equal("The Hunt", H.killMoment(nil).title)
    end)

    it("takes the Hunt's place among the goals done, big", function()
      local entry = { set = { "hunt" }, done = { hunt = 10 } }
      local list = C.goalMoments({ newly = { "hunt" }, today = entry, hunts = { DRUID },
                                   huntKill = { hunt = DRUID, zone = "Duskwood", clock = "20:15" }, huntFirst = false })
      assert.are.equal(1, #list)
      assert.are.same({ "big", "Quarry bagged", "Night Elf Druid", "Duskwood" .. DOT .. "20:15" },
        { list[1].weight, list[1].kicker, list[1].title, list[1].line })
      -- Without the kill, the day's Hunt names the quarry.
      list = C.goalMoments({ newly = { "hunt" }, today = entry, hunts = { DRUID } })
      assert.are.equal("Night Elf Druid", list[1].title)
    end)

    it("has one chat line, and a friend's line", function()
      assert.are.equal("Quarry bagged: Night Elf Druid (+5 PvP).", H.chatLine(DRUID))
      assert.are.equal("bagged the quarry" .. DOT .. "Night Elf Druid", H.friendText(DRUID))
      assert.are.equal("bagged the quarry", H.friendText(nil))
    end)

    it("gives a friend's line when their synced goals show the Hunt done today", function()
      local known = {}
      local person = { displayName = "Grom", goals = { days = {} },
                       chars = { G1 = { name = "Grom Ashfeller", classFile = "WARRIOR", faction = "Horde" } } }
      local ctx = { day = 7, week = 1, now = 1000, since = 0, hunts = { Horde = DRUID } }
      C.friendMoments(known, { ["Grom#1001"] = person }, ctx) -- the first sight: known
      person.goals.days[7] = { set = { "hunt" }, done = { hunt = 990 } }
      local lines = C.friendMoments(known, { ["Grom#1001"] = person }, ctx)
      assert.are.same({ "bagged the quarry" .. DOT .. "Night Elf Druid", "pvp" }, { lines[1].text, lines[1].edge })
      assert.are.same({}, C.friendMoments(known, { ["Grom#1001"] = person }, ctx)) -- never twice
      assert.is_function(D.goal)
    end)
  end)
end)
