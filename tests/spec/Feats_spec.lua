local helpers = require("helpers")

describe("Feats, scores and sprees (CF-57b)", function()
  local Feats, Feed, V, D

  before_each(function()
    local ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/GameText.lua", ns)
    helpers.loadAddonFile("src/core/Pvp.lua", ns)
    Feed = helpers.loadAddonFile("src/core/Feed.lua", ns)
    helpers.loadAddonFile("src/core/Loot.lua", ns)
    Feats = helpers.loadAddonFile("src/core/Feats.lua", ns)
    D = helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    V = helpers.loadAddonFile("src/core/DoomsdayView.lua", ns)
  end)

  local function keys(list)
    local out = {}
    for i, f in ipairs(list) do out[i] = f.key end
    return out
  end

  local function find(list, key)
    for _, f in ipairs(list) do
      if f.key == key then return f end
    end
  end

  it("derives feats with the site's thresholds", function()
    local char = { level = 60, faction = "Alliance", riding = 150,
                   professions = { [185] = { name = "Cooking", rank = 300, max = 300 },
                                   [129] = { name = "First Aid", rank = 300, max = 300 },
                                   [356] = { name = "Fishing", rank = 300, max = 300 },
                                   [186] = { name = "Mining", rank = 300, max = 300 },
                                   [197] = { name = "Tailoring", rank = 225, max = 225 },
                                   [171] = { name = "Alchemy", rank = 300, max = 300 } },
                   pvp = { hk = 1234, rank = 6, duelsWon = 52, deaths = 101 } }
    local entries = { { runs = { { name = "Warsong Gulch", kind = "pvp", won = true },
                                 { name = "Arathi Basin", kind = "pvp", won = false } },
                        loot = { epic = { { id = 1, name = "Big Sword", level = 58 } } },
                        notable = { [19970] = 1, [14342] = 1 } } }
    local list = Feats.derive(char, entries)
    assert.are.same({ "level:10", "level:20", "level:30", "level:40", "level:50", "maxLevel",
                      "professionCap:129:300", "professionCap:171:300", "professionCap:185:300",
                      "professionCap:186:300", "professionCap:197:225", "professionCap:356:300",
                      "honorKills:1", "honorKills:100", "honorKills:1000", "pvpRank:6", "duelWins:10", "duelWins:50",
                      "deaths100", "mount", "epicMount", "firstCatch", "jackOfAllTrades", "bgFirstWin:Warsong Gulch",
                      "firstEpic", "notableItem:mooncloth", "notableItem:extravaganzaWon" }, keys(list))
    assert.are.same({ "Head Chef", "Cooking 300" }, { find(list, "professionCap:185:300").title,
                                                     find(list, "professionCap:185:300").detail })
    assert.are.equal("Tailoring 225", find(list, "professionCap:197:225").title)
    assert.are.equal("First blood", find(list, "honorKills:1").title)
    assert.are.equal("1,000 honorable kills", find(list, "honorKills:1000").title)
    assert.are.same({ "Knight", "a.k.a. Mailbox Menace \194\183 rank 6" },
      { find(list, "pvpRank:6").title, find(list, "pvpRank:6").detail })
    assert.are.equal("Big Sword", find(list, "firstEpic").title)
    assert.are.equal("Extravaganza winner", find(list, "notableItem:extravaganzaWon").title)
    assert.are.same({}, Feats.derive({ level = 9 }, {}))
  end)

  it("gives a mount only from level 40 and an epic mount from 60, and hides older ones below (CF-61)", function()
    local function has(list, key) return find(list, key) ~= nil end
    local low = Feats.derive({ level = 12, riding = 150 }, {})
    assert.is_false(has(low, "mount"))
    assert.is_false(has(low, "epicMount"))
    local mid = Feats.derive({ level = 45, riding = 150 }, {})
    assert.is_true(has(mid, "mount"))
    assert.is_false(has(mid, "epicMount"))
    local stored = { mount = { at = 0, title = "Mount", detail = "at level 12" },
                     epicMount = { at = 5, title = "Epic mount", detail = "at level 60" },
                     ["level:10"] = { at = 0, title = "Level 10", detail = "Reached level 10" } }
    assert.are.same({ "epicMount", "level:10" }, keys(Feats.list(stored)))
  end)

  it("splits earned feats from those a character already had (CF-61)", function()
    local earned, earlier = Feats.split({ { key = "a", at = 20 }, { key = "b", at = 0 }, { key = "c", at = 10 } })
    assert.are.same({ "a", "c" }, keys(earned))
    assert.are.same({ "b" }, keys(earlier))
  end)

  it("remembers when it first saw a feat: Earlier at the first sight, never removed", function()
    local store = {}
    assert.are.same({}, Feats.remember(store, { { key = "level:10", title = "Level 10" } }, 100))
    assert.are.equal(0, store["level:10"].at)
    local list = { { key = "level:10" }, { key = "level:20", title = "Level 20" } }
    assert.are.same({ "level:20" }, Feats.remember(store, list, 200))
    assert.are.equal(200, store["level:20"].at)
    Feats.remember(store, {}, 300) -- a rank that dropped keeps its feat
    assert.is_table(store["level:20"])
    assert.are.same({ "level:20", "level:10" }, keys(Feats.list(store)))
    local empty = {}
    Feats.remember(empty, {}, 5)
    assert.are.same({ "level:10" }, Feats.remember(empty, { { key = "level:10" } }, 6)) -- after an empty first sight
  end)

  it("names the next honorable-kill feat", function()
    assert.are.same({ "First blood", "0 / 1" }, { Feats.nextKills(0) })
    assert.are.same({ "1,000 honorable kills", "412 / 1,000" }, { Feats.nextKills(412) })
    assert.is_nil(Feats.nextKills(12000))
  end)

  it("puts a spree badge on a feed line", function()
    local entry = { name = "Ada Example", pvpKills = {}, deaths = { { t = 6 } } }
    for t = 1, 5 do entry.pvpKills[#entry.pvpKills + 1] = { t = t } end
    for t = 7, 17 do entry.pvpKills[#entry.pvpKills + 1] = { t = t, bg = t == 7 or nil } end
    assert.are.equal(10, Feed.spree(entry))
    assert.are.same({ "a spree of 10" }, Feed.parts(entry))
    entry.pvpKills = { { t = 1 }, { t = 2 }, { t = 3 }, { t = 4 }, { t = 5 } }
    assert.are.same({ "a spree of 5" }, Feed.parts(entry))
    entry.pvpKills = { { t = 1 } }
    assert.are.same({}, Feed.parts(entry))
  end)

  it("scores a friend's day and week from their synced data", function()
    local schedule = { offset = 3600, reset = 68400 }
    local day = 20767
    local week = D.week(day)
    local start = D.dayStart(day, 3600, 68400)
    local today = { set = { "d.quests10" }, done = { ["d.quests10"] = start + 5, ["p.loneWolf"] = 1 } }
    local goals = { days = { [day] = today, [day - 1] = { done = { ["d.level"] = 1 } } },
                    weeks = { [week] = { done = { ["w.days3"] = 1 } } }, streak = 4 }
    local kill = { t = start + 10, name = "V", lvl = 30, myLvl = 30, zone = "Ashenvale" }
    local feed = { [day] = { G1 = { pvpKills = { kill,
                                                 { t = start + 20, name = "W", lvl = 30, myLvl = 30, bg = true,
                                                   zone = "Warsong Gulch" } },
                                    runs = { { name = "Warsong Gulch", kind = "pvp", won = true } } } } }
    local s = V.score({ goals = goals, feed = feed, chars = { G1 = { pvp = { hk = 2 } } }, schedule = schedule,
                        community = {}, day = day, week = week })
    assert.are.same({ pve = 5, pvp = 5 + 1 }, s.today)
    local daysInWeek = D.week(day - 1) == week and 5 or 0
    assert.are.same({ pve = 5 + 15 + daysInWeek, pvp = 5 + 1 }, s.week)
    assert.are.same({ 1, 1, true, 4 }, { s.kills, s.perChar.G1, s.killedEver, s.streak })
    assert.are.same({ won = 1, lost = 0, points = 1 }, s.bg["Warsong Gulch"])
    assert.are.same({ "Ashenvale", 1 }, { V.topZone(s.killsByZone) })
    assert.are.same({ "+2", "-1", "new", "" }, { V.moveText(2), V.moveText(-1), V.moveText("new"), V.moveText(0) })
    assert.are.equal("\226\150\1782", V.moveText(2, true))
  end)
end)
