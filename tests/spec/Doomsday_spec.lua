local helpers = require("helpers")

-- CF-55: src/core/Doomsday.lua against the golden cases shared with the site. The file is read as is;
-- never change a case to make this pass (see "about" in the file).
describe("Doomsday (CF-55)", function()
  local Doomsday
  local cases = helpers.readJson("tests/fixtures/doomsday-cases.json")

  before_each(function()
    Doomsday = helpers.loadAddonFile("src/core/Doomsday.lua", helpers.coreNs())
  end)

  local function set(list)
    local result = {}
    for _, name in ipairs(list or {}) do result[name] = true end
    return result
  end

  local function scored(c)
    return Doomsday.scoreKills(c.facts and c.facts.kills or c.kills, c.schedule, set(c.community))
  end

  it("matches the file's pools and constants", function()
    assert.are.equal(cases.poolVersion, Doomsday.POOL_VERSION)
    assert.are.equal(cases.epoch, Doomsday.EPOCH)
    assert.are.equal(cases.defaultReset, Doomsday.DEFAULT_RESET)
    for _, slot in ipairs({ "daily", "weekly", "skirmish", "bounty" }) do
      assert.are.same(cases.pools[slot], Doomsday.pool(slot), slot)
    end
    assert.is_nil(Doomsday.HUNT_SINCE)
    assert.are.same(cases.salts.dailies, Doomsday.SALT.dailies)
    assert.are.same(cases.salts.weeklies, Doomsday.SALT.weeklies)
  end)

  it("gives every goal a short label of at most 10 characters (CF-61, the same on the site)", function()
    for _, g in ipairs(Doomsday.GOALS) do
      assert.is_string(g.shortLabel, g.id)
      assert.is_true(#g.shortLabel >= 1 and #g.shortLabel <= 10, g.id .. ": " .. g.shortLabel)
    end
    for id in pairs(Doomsday.SHORT_LABELS) do assert.is_table(Doomsday.goal(id), id) end
  end)

  -- CF-70: the catalogue in code (docs/DOOMSDAY-CATALOGUE.md), pinned for the site's copy.
  describe("the catalogue", function()
    it("matches the file's catalogue, in pool order", function()
      local list = {}
      for i, g in ipairs(Doomsday.GOALS) do
        list[i] = { id = g.id, slot = g.slot, category = g.category, needs = g.needs, since = g.since,
                    points = g.points, text = g.text, short = g.shortLabel, can = g.can, fallback = g.fallback,
                    retired = g.retired, canFrom = g.canFrom }
      end
      assert.are.same(cases.pools.catalogue, list)
    end)

    it("has the 118 PvE dailies in 15 categories, sized 1, 3 or 5, the untracked ones waiting for data", function()
      local dailies, categories, n = 0, {}, 0
      for _, g in ipairs(Doomsday.GOALS) do
        if g.slot == "daily" then
          dailies = dailies + 1
          if not categories[g.category] then categories[g.category], n = true, n + 1 end
          assert.is_true(g.points == 1 or g.points == 3 or g.points == 5, g.id)
        end
      end
      assert.are.equal(118, dailies)
      assert.are.equal(15, n)
      for _, id in ipairs({ "d.cook5", "d.scrolls10", "d.fish20", "d.groupFriend", "p.flex", "p.punchDown5" }) do
        assert.is_nil(Doomsday.goal(id).since, id)
      end
    end)

    it("gives labels unique within a slot", function()
      local seen = {}
      for _, g in ipairs(Doomsday.GOALS) do
        local key = g.slot .. ":" .. g.shortLabel
        assert.is_nil(seen[key], g.id .. " and " .. tostring(seen[key]))
        seen[key] = g.id
      end
    end)

    -- CF-79: docs/DOOMSDAY-WEEKLY-CATALOGUE.md and docs/DOOMSDAY-PVP-CATALOGUE.md.
    it("has the 50 weeklies in 14 categories, sized 5, 10 or 15, and w.ilvl3 retired from pool version 2", function()
      local weeklies, categories, n = 0, {}, 0
      for _, g in ipairs(Doomsday.GOALS) do
        if g.slot == "weekly" and g.id ~= "w.ilvl3" then
          weeklies = weeklies + 1
          if not categories[g.category] then categories[g.category], n = true, n + 1 end
          assert.is_true(g.points == 5 or g.points == 10 or g.points == 15, g.id)
        end
      end
      assert.are.same({ 50, 14 }, { weeklies, n })
      assert.are.same({ 2, nil }, { Doomsday.goal("w.ilvl3").retired, Doomsday.goal("w.blueGear").since })
      local function has(list, id)
        for _, x in ipairs(list) do if x == id then return true end end
        return false
      end
      assert.is_true(has(Doomsday.pool("weekly", 1), "w.ilvl3"))
      assert.is_false(has(Doomsday.pool("weekly", 2), "w.ilvl3"))
    end)

    it("has 57 Skirmish and 43 Bounty goals, each with what it needs", function()
      local count, sizes = { skirmish = 0, bounty = 0 }, { skirmish = { 1, 3, 5 }, bounty = { 5, 10, 15 } }
      local needs = { kill = true, duel = true, bg = true, emote = true, flag = true }
      for _, g in ipairs(Doomsday.GOALS) do
        if sizes[g.slot] then
          count[g.slot] = count[g.slot] + 1
          assert.is_true(needs[g.needs], g.id)
          local s = sizes[g.slot]
          assert.is_true(g.points == s[1] or g.points == s[2] or g.points == s[3], g.id)
        end
      end
      assert.are.same({ skirmish = 57, bounty = 43 }, count)
      assert.are.same({ "taunts", "emote" }, { Doomsday.goal("p.flex").category, Doomsday.goal("p.flex").needs })
    end)

    it("checks b.zone25's level only from pool version 2 (pool version 1 is unchanged)", function()
      assert.is_true(Doomsday.canDo("b.zone25", { highest = 15 }, 1))
      assert.is_false(Doomsday.canDo("b.zone25", { highest = 15 }, 2))
      assert.is_false(Doomsday.canDo("p.bgWin", { highest = 9 }))
      assert.is_true(Doomsday.canDo("p.bgWin", { highest = 9, highestToday = 10 }))
      assert.is_false(Doomsday.canDo("w.blueGear", { highest = 14 }))
    end)

    it("names known goals as fallbacks and known situation checks", function()
      for _, g in ipairs(Doomsday.GOALS) do
        for _, f in ipairs(g.fallback or {}) do
          assert.are.equal(g.slot, Doomsday.goal(f).slot, g.id .. " -> " .. f)
        end
        assert.is_true(Doomsday.canDo(g.id, {}), g.id) -- a missing field never swaps
      end
    end)

    it("swaps on the catalogue's situation fields", function()
      local cases_ = {
        { "d.lowbie", { below20 = 0 } }, { "d.cook5", { hasCooking = false } },
        { "d.bandage3", { hasFirstAid = false } }, { "d.gather10", { hasGathering = false } },
        { "d.ride", { riding = false } }, { "d.buffFriend", { canBuff = false } },
        { "d.sameZone", { friends = 0 } }, { "d.online3", { friends = 2 } }, { "d.dustOff", { idle7 = 0 } },
        { "d.nostalgia", { highest = 29 } }, { "d.dingDungeon", { dungeonInRange = false } },
        { "d.dingDungeon", { below60 = 0 } },
        { "d.craft5", { hasProfession = false, hasCooking = false, hasFirstAid = false, hasFishing = false } },
      }
      for _, c in ipairs(cases_) do
        assert.is_false(Doomsday.canDo(c[1], c[2]), c[1])
      end
      assert.is_true(Doomsday.canDo("d.online3", { friends = 3 }))
      assert.is_true(Doomsday.canDo("d.nostalgia", { highest = 30 }))
      assert.is_true(Doomsday.canDo("d.craft5", { hasProfession = false, hasCooking = true }))
    end)

    it("takes a module's progress function, never over a built-in one", function()
      assert.is_nil(Doomsday.progress("d.levels2", {}))
      Doomsday.registerProgress("d.levels2", function(f) return f.levels or 0, 2 end)
      Doomsday.registerProgress("d.level", function() return 9, 1 end)
      assert.are.same({ 2, 2, true }, { Doomsday.progress("d.levels2", { levels = 2 }) })
      assert.are.same({ 0, 1, false }, { Doomsday.progress("d.level", {}) })
    end)
  end)

  it("picks", function()
    for _, c in ipairs(cases.pick) do
      assert.are.equal(c.expect, Doomsday.pick(c.n, c.salt, c.count), c.n .. "/" .. c.salt)
    end
  end)

  it("finds the realm offset", function()
    for _, c in ipairs(cases.realmOffset) do
      assert.are.equal(c.expect, Doomsday.realmOffset(c.hour, c.minute, c.serverTime), c.note)
    end
    assert.is_nil(Doomsday.realmOffset(nil, 0, 1))
  end)

  it("numbers days and weeks around the reset", function()
    for _, c in ipairs(cases.schedule) do
      local e = c.expect
      local day = Doomsday.day(c.serverTime, c.offset, c.reset)
      assert.are.equal(e.day, day, c.note)
      assert.are.equal(e.week, Doomsday.week(day), c.note)
      assert.are.equal(e.dayStart, Doomsday.dayStart(day, c.offset, c.reset), c.note)
      assert.are.equal(e.resetsIn, Doomsday.resetsIn(c.serverTime, c.offset, c.reset), c.note)
      assert.are.equal(e.label, Doomsday.label(day), c.note)
    end
    for _, c in ipairs(cases.duration) do assert.are.equal(c.expect, Doomsday.duration(c.seconds)) end
    assert.are.equal(Doomsday.weekStart(Doomsday.week(20765)), 20765) -- a Sunday starts its week
  end)

  -- CF-77: a case without `pool` is of pool version 1.
  it("draws the same goals as the file", function()
    for _, c in ipairs(cases.draws.days) do
      local draw = Doomsday.draw(c.day, c.pool or 1)
      assert.are.same(c.expect.dailies, draw.dailies, "day " .. c.day)
      assert.are.equal(c.expect.skirmish, draw.skirmish, "day " .. c.day)
    end
    for _, c in ipairs(cases.draws.weeks) do
      assert.are.same(c.expect, Doomsday.drawWeek(c.week, c.pool or 1), "week " .. c.week)
    end
    for _, c in ipairs(cases.draws.zones) do
      assert.are.equal(c.expect, Doomsday.zone(c.n, c.salt, c.level), c.n .. "/" .. c.salt .. "/" .. c.level)
    end
  end)

  it("draws the Hunt once its pool version comes", function()
    assert.is_nil(Doomsday.draw(cases.epoch).hunt)
    Doomsday.HUNT_SINCE = 1
    for _, c in ipairs(cases.draws.hunts) do
      assert.are.same(c.expect, Doomsday.draw(c.day, c.pool or 1).hunt, "day " .. c.day)
      assert.are.same(c.expect.Horde, Doomsday.hunt(c.day, "Horde", c.pool or 1))
    end
  end)

  local function categoryCount(ids)
    local categories, count = {}, 0
    for _, id in ipairs(ids) do
      local c = Doomsday.goal(id).category
      if not categories[c] then categories[c], count = true, count + 1 end
    end
    return count
  end

  for _, version in ipairs({ 1, 2 }) do
    it("keeps the draw's rules over 400 days in pool version " .. version .. ": 3 categories, nothing twice in a row",
      function()
        local before = Doomsday.draw(cases.epoch, version)
        for n = cases.epoch + 1, cases.epoch + 400 do
          local draw = Doomsday.draw(n, version)
          local previous = set(before.dailies)
          for _, id in ipairs(draw.dailies) do assert.is_nil(previous[id], "day " .. n) end
          assert.are.equal(3, categoryCount(draw.dailies), "day " .. n)
          assert.are_not.equal(before.skirmish, draw.skirmish)
          before = draw
        end
        local week = Doomsday.drawWeek(Doomsday.week(cases.epoch), version)
        for w = Doomsday.week(cases.epoch) + 1, Doomsday.week(cases.epoch) + 60 do
          local draw = Doomsday.drawWeek(w, version)
          assert.are.equal(3, #draw.weeklies, "week " .. w)
          for _, id in ipairs(draw.weeklies) do assert.is_nil(set(week.weeklies)[id], "week " .. w) end
          -- CF-77: from pool version 2 the weeklies are of 3 different categories.
          if version >= 2 then assert.are.equal(3, categoryCount(draw.weeklies), "week " .. w) end
          assert.are_not.equal(week.bounty, draw.bounty)
          week = draw
        end
      end)
  end

  -- CF-77: pool version 2 takes the missions of the trackers built on verified APIs (CF-71 to CF-73).
  it("puts the tracked missions in pool version 2, each with its progress", function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    for _, file in ipairs({ "Quests", "Records", "Places" }) do
      helpers.loadAddonFile("src/core/missions/" .. file .. ".lua", ns)
    end
    local joined = 0
    for _, g in ipairs(ns.Doomsday.GOALS) do
      if g.since == 2 then
        joined = joined + 1
        assert.is_true(g.slot == "daily" or g.slot == "weekly", g.id)
        assert.is_number(ns.Doomsday.progress(g.id, ns.Goals.progressFacts(ns.Goals.newFacts())), g.id)
      end
    end
    assert.are.equal(42, joined)
    assert.are.same({ 43, 27, 3, 5 }, { #Doomsday.pool("daily", 2), #Doomsday.pool("weekly", 2),
                                        #Doomsday.pool("skirmish", 2), #Doomsday.pool("bounty", 2) })
  end)

  it("swaps goals a friend can't do", function()
    for _, c in ipairs(cases.swaps) do
      local v = c.pool or 1
      local goals = c.day and Doomsday.goalsForDay(c.day, c.situation, v)
        or Doomsday.goalsForWeek(c.week, c.situation, v)
      assert.are.same(c.expect.set, goals.set, c.note)
      assert.are.same(c.expect.swapped, goals.swapped, c.note)
      if c.expect.zone then assert.are.equal(c.expect.zone, goals.zone, c.note) end
    end
  end)

  -- CF-68: the site's schedule on top of the draw (addonOnly cases are DoomsdayTracking's).
  it("puts the site's schedule on the draw", function()
    for _, c in ipairs(cases.scheduled) do
      if not c.addonOnly then
        local e = c.expect
        if e.set then
          local goals = Doomsday.goalsForDay(c.day, c.situation, c.pool or 1, c.schedule)
          assert.are.same(e.set, goals.set, c.note)
          assert.are.same(e.swapped, goals.swapped, c.note)
        elseif e.dailies then
          local draw = Doomsday.scheduledDraw(c.day, c.schedule, c.pool or 1)
          assert.are.same(e.dailies, draw.dailies, c.note)
          assert.are.equal(e.skirmish, draw.skirmish, c.note)
        else
          local draw = Doomsday.scheduledWeek(c.week, c.schedule, c.pool or 1)
          assert.are.same(e.weeklies, draw.weeklies, c.note)
          assert.are.equal(e.bounty, draw.bounty, c.note)
        end
      end
    end
  end)

  it("never changes the normal draw, and keeps the Hunt the normal draw's", function()
    local n = cases.epoch + 7
    local schedule = { v = 1, days = { [tostring(n)] = { daily = { "d.quests10", "d.level", "d.dungeon" },
                                                         hunt = { Horde = "Gnome.MAGE" } } } }
    local before = Doomsday.draw(n).dailies
    Doomsday.scheduledDraw(n, schedule)
    assert.are.same(before, Doomsday.draw(n).dailies)
    assert.are.equal(Doomsday.draw(n), Doomsday.scheduledDraw(n, nil))
    Doomsday.HUNT_SINCE = 1
    assert.are.same(Doomsday.draw(n).hunt, Doomsday.scheduledDraw(n, schedule).hunt)
    assert.are.same(Doomsday.draw(n).hunt, Doomsday.goalsForDay(n, {}, nil, schedule).hunt)
  end)

  it("scores kills", function()
    for _, c in ipairs(cases.kills) do
      local result = scored(c)
      local totals, countedKills = { pvp = 0, bg = 0 }, 0
      for i, s in ipairs(result) do
        local e = c.expect.kills[i]
        assert.are.same(e, { counted = s.counted, points = s.points, track = s.track, day = s.day,
                             reason = s.reason }, "kill " .. i)
        totals[s.track] = totals[s.track] + s.points
        if s.counted and s.track == "pvp" then countedKills = countedKills + 1 end
      end
      assert.are.equal(#c.expect.kills, #result)
      assert.are.same({ c.expect.pvp, c.expect.bg, c.expect.counted }, { totals.pvp, totals.bg, countedKills })
    end
  end)

  it("counts the Duel slot", function()
    for _, c in ipairs(cases.duels) do
      assert.are.same(c.expect, Doomsday.duels(c.duels, c.owner, c.schedule), c.note)
    end
  end)

  it("measures goal progress (addon only)", function()
    for _, c in ipairs(cases.progress) do
      local facts = {}
      for k, v in pairs(c.facts) do facts[k] = v end
      if facts.kills then facts.scored = scored(c) end
      local value, target, done = Doomsday.progress(c.id, facts)
      assert.are.same(c.expect, { value = value, target = target, done = done }, c.id .. " " .. tostring(c.note))
    end
  end)

  it("adds up points per track", function()
    for _, c in ipairs(cases.points) do
      assert.are.same(c.expect, Doomsday.points(c.done, c.killPoints, c.duelPoints), c.note)
    end
  end)

  -- CF-69: points per goal, in the pool version of the day or week.
  it("scores each goal in its day's pool version", function()
    for _, c in ipairs(cases.pointsPerGoal) do
      local pool = Doomsday.entryPool(c.entry, c.goalsPool)
      assert.are.equal(c.expect.pool, pool, c.note)
      local total = Doomsday.points(c.done, 0, 0, pool)
      assert.are.same({ c.expect.pve, c.expect.pvp }, { total.pve, total.pvp }, c.note)
      for id in pairs(c.done) do
        assert.are.equal(c.expect.goals[id], Doomsday.pointsFor(id, pool), c.note .. ": " .. id)
      end
    end
  end)

  it("keeps the flat points without a pool and for goals without a size", function()
    assert.are.equal(5, Doomsday.pointsFor("d.quests10"))
    assert.are.equal(15, Doomsday.pointsFor("w.days3"))
    assert.are.equal(5, Doomsday.pointsFor("w.days3", 2))
    assert.are.equal(15, Doomsday.pointsFor("w.ilvl3", 2)) -- no size (retired from pool 2): flat
    assert.are.same({ "pve", 3 }, { Doomsday.goalPoints("d.quests10", 2) })
    assert.is_nil(Doomsday.goalPoints("x.newer", 2))
    assert.are.equal(1, Doomsday.entryPool(nil, nil))
    assert.are.equal(1, Doomsday.entryPool({ pool = 0 }, "2"))
  end)

  it("crosses out and crowns", function()
    for _, c in ipairs(cases.crown) do
      for _, f in ipairs(c.friends) do
        assert.are.equal(c.expect.crossedOut[f.friend], Doomsday.crossedOut(f.set, f.done), f.friend)
      end
      assert.are.equal(c.expect.crown, Doomsday.crown(c.friends), c.note)
    end
  end)

  it("keeps the streak", function()
    for _, c in ipairs(cases.streak) do
      local days = {}
      for day, n in pairs(c.days) do days[tonumber(day)] = n end
      local streak, best = Doomsday.streak(days, c.today, c.best)
      assert.are.same(c.expect, { streak = streak, best = best }, c.note)
    end
  end)

  it("ranks the ladder", function()
    for _, c in ipairs(cases.ladder) do
      assert.are.same(c.expect, Doomsday.ladder(c.friends, c.previous), c.note)
    end
  end)

  it("knows every goal's text, slot and fallbacks, and every id once", function()
    local ids = {}
    for _, g in ipairs(Doomsday.GOALS) do
      assert.is_nil(ids[g.id], g.id)
      ids[g.id] = true
      assert.is_string(g.text)
      assert.is_true(#g.id <= 24, g.id)
      for _, f in ipairs(g.fallback or {}) do assert.are.equal(g.slot, Doomsday.goal(f).slot, g.id) end
    end
    assert.are.equal(20, #Doomsday.combos("Horde"))
    assert.are.equal(20, #Doomsday.combos("Alliance"))
  end)
end)
