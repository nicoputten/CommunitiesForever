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

  it("draws the same goals as the file", function()
    for _, c in ipairs(cases.draws.days) do
      local draw = Doomsday.draw(c.day)
      assert.are.same(c.expect.dailies, draw.dailies, "day " .. c.day)
      assert.are.equal(c.expect.skirmish, draw.skirmish, "day " .. c.day)
    end
    for _, c in ipairs(cases.draws.weeks) do
      assert.are.same(c.expect, Doomsday.drawWeek(c.week), "week " .. c.week)
    end
    for _, c in ipairs(cases.draws.zones) do
      assert.are.equal(c.expect, Doomsday.zone(c.n, c.salt, c.level), c.n .. "/" .. c.salt .. "/" .. c.level)
    end
  end)

  it("draws the Hunt once its pool version comes", function()
    assert.is_nil(Doomsday.draw(cases.epoch).hunt)
    Doomsday.HUNT_SINCE = 1
    for _, c in ipairs(cases.draws.hunts) do
      assert.are.same(c.expect, Doomsday.draw(c.day).hunt, "day " .. c.day)
      assert.are.same(c.expect.Horde, Doomsday.hunt(c.day, "Horde"))
    end
  end)

  it("keeps the draw's rules over 400 days: 3 categories, nothing twice in a row", function()
    local before = Doomsday.draw(cases.epoch)
    for n = cases.epoch + 1, cases.epoch + 400 do
      local draw = Doomsday.draw(n)
      local categories, previous = {}, set(before.dailies)
      for _, id in ipairs(draw.dailies) do
        categories[Doomsday.goal(id).category] = true
        assert.is_nil(previous[id], "day " .. n)
      end
      local count = 0
      for _ in pairs(categories) do count = count + 1 end
      assert.are.equal(3, count, "day " .. n)
      assert.are_not.equal(before.skirmish, draw.skirmish)
      before = draw
    end
    local week = Doomsday.drawWeek(Doomsday.week(cases.epoch))
    for w = Doomsday.week(cases.epoch) + 1, Doomsday.week(cases.epoch) + 60 do
      local draw = Doomsday.drawWeek(w)
      for _, id in ipairs(draw.weeklies) do assert.is_nil(set(week.weeklies)[id]) end
      assert.are_not.equal(week.bounty, draw.bounty)
      week = draw
    end
  end)

  it("swaps goals a friend can't do", function()
    for _, c in ipairs(cases.swaps) do
      local goals = c.day and Doomsday.goalsForDay(c.day, c.situation) or Doomsday.goalsForWeek(c.week, c.situation)
      assert.are.same(c.expect.set, goals.set, c.note)
      assert.are.same(c.expect.swapped, goals.swapped, c.note)
      if c.expect.zone then assert.are.equal(c.expect.zone, goals.zone, c.note) end
    end
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
