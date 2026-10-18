local helpers = require("helpers")

describe("Dungeons (CF-24)", function()
  local Dungeons

  before_each(function()
    Dungeons = helpers.loadAddonFile("src/core/Dungeons.lua", {})
  end)

  local function row(guid, name, level, extra)
    local r = { guid = guid, name = name, classFile = "MAGE", level = level, online = false }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end

  local DM_QUEST = { title = "Red Silk Bandanas", area = "The Deadmines" }

  local function view(extra)
    local v = {
      people = {
        { battleTag = "Me#1", displayName = "Ann", isSelf = true,
          chars = { row("G-ME", "Ann Example", 20, { role = "dps", online = true }),
                    row("G-ALT", "Amy Example", 45) } },
        { battleTag = "Fr#2", displayName = "Ben", chars = {
          row("G-BEN", "Ben Example", 19, { role = "heal", online = true, quests = { [101] = DM_QUEST } }),
          row("G-BEN2", "Bob Example", 22, { role = "tank" }) } },
        { battleTag = "Fr#3", displayName = "Cid", chars = { row("G-CID", "Cid Example", 24, { role = "tank" }) } },
      },
      unlinked = { row("G-DEE", "Dee Example", 18, { classFile = nil, classID = 4 }),
                   row("G-OLD", "Old Example", 60) },
    }
    for k, val in pairs(extra or {}) do v[k] = val end
    return v
  end

  local function entryFor(overview, id)
    for _, e in ipairs(overview) do
      if e.dungeon.id == id then return e end
    end
  end

  local function names(list)
    local result = {}
    for i, c in ipairs(list) do result[i] = c.name end
    return result
  end

  describe("overview", function()
    it("lists a planned dungeon that fits none of your characters when asked to", function()
      local overview = Dungeons.overview(Dungeons.candidates(view()), "G-ME", { strat = true })
      local strat = entryFor(overview, "strat")
      assert.is_false(strat.fits)
      assert.are.equal(1, strat.people) -- the unlinked level 60
      assert.is_true(entryFor(overview, "dm").fits)
    end)

    it("lists only dungeons that fit one of your characters, most people first", function()
      local overview = Dungeons.overview(Dungeons.candidates(view()), "G-ME")
      for _, e in ipairs(overview) do
        local fits = false
        for _, c in ipairs(e.candidates) do
          if c.own then fits = true end
          assert.is_true(c.level >= e.dungeon.min and c.level <= e.dungeon.max, e.dungeon.name)
        end
        assert.is_true(fits, e.dungeon.name)
      end
      assert.is_nil(entryFor(overview, "rfc")) -- 13 to 18: none of your characters
      assert.is_nil(entryFor(overview, "strat")) -- only an unlinked 60
      -- Deadmines (17-26): you, Ben (two characters, one person), Cid, Dee: 4 people.
      local dm = entryFor(overview, "dm")
      assert.are.equal(4, dm.people)
      assert.are.equal(1, dm.quests)
      assert.are.equal("dm", overview[1].dungeon.id)
    end)

    it("counts quests for the dungeon by quest log area", function()
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(view()), "G-ME"), "dm")
      for _, c in ipairs(dm.candidates) do
        assert.are.same(c.guid == "G-BEN" and { 101 } or {}, c.questIDs)
      end
    end)

    it("keeps unlinked members as their own people and skips unknown levels", function()
      local v = view()
      v.unlinked[#v.unlinked + 1] = { guid = "G-X", name = "No Level" }
      local candidates = Dungeons.candidates(v)
      local keys = {}
      for _, c in ipairs(candidates) do keys[c.guid] = c.key end
      assert.are.equal("member:G-DEE", keys["G-DEE"])
      assert.are.equal("self", keys["G-ME"])
      assert.is_nil(keys["G-X"])
    end)
  end)

  describe("suggestion", function()
    it("puts you first, then a tank and a healer, one character per person", function()
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(view()), "G-ME"), "dm")
      local group = Dungeons.suggest(dm)
      -- Bob is Ben's tank alt: Ben can bring only one, so Cid tanks and Ben heals.
      assert.are.same({ "Ann Example", "Cid Example", "Ben Example", "Dee Example" }, names(group))
      assert.are.same({ "you", "tank", "healer" }, { group[1].reason, group[2].reason, group[3].reason })
    end)

    it("prefers shared quests, then online", function()
      local v = view()
      v.people[2].chars = { row("G-BEN", "Ben Example", 19, { role = "heal", quests = { [101] = DM_QUEST } }) }
      v.people[3].chars = { row("G-CID", "Cid Example", 24, { online = true }) }
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(v), "G-ME"), "dm")
      local group = Dungeons.suggest(dm)
      assert.are.same({ "Ann Example", "Ben Example", "Cid Example", "Dee Example" }, names(group))
      assert.are.equal("healer", group[2].reason)
      assert.is_nil(group[3].reason)
    end)

    it("picks your character with quests for the dungeon over the one you are on", function()
      local v = view()
      v.people[1].chars[2] = row("G-ALT", "Amy Example", 21, { quests = { [101] = DM_QUEST } })
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(v), "G-ME"), "dm")
      assert.are.equal("Amy Example", Dungeons.suggest(dm)[1].name)
    end)

    it("stops at five", function()
      local v = view()
      for i = 1, 8 do
        v.unlinked[#v.unlinked + 1] = row("G-U" .. i, "Member " .. i, 20)
      end
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(v), "G-ME"), "dm")
      assert.are.equal(5, #Dungeons.suggest(dm))
    end)

    it("uses the dungeon name as event title", function()
      assert.are.equal("The Deadmines", Dungeons.eventTitle(Dungeons.get("dm")))
    end)
  end)

  describe("dungeon quests", function()
    local HORDE, ALLIANCE = 690, 77 -- race masks (Vanilla Questie encoding)
    local DATA = { [1581] = {
      { id = 101, name = "Red Silk Bandanas", level = 17, requiredLevel = 14, requiredRaces = ALLIANCE + HORDE },
      { id = 102, name = "Oh Brother...", level = 20, requiredLevel = 15, requiredRaces = 0 },
      { id = 103, name = "Underground Assault", level = 20, requiredLevel = 15, requiredRaces = ALLIANCE },
      { id = 104, name = "The Defias Brotherhood", level = 22, requiredLevel = 22, requiredRaces = 0 },
      { id = 105, name = "Collecting Memories", level = 18, requiredLevel = 13, requiredRaces = 0 },
    } }

    local function dmEntry(v)
      return entryFor(Dungeons.overview(Dungeons.candidates(v or view()), "G-ME"), "dm")
    end

    local function states(info)
      local result = {}
      for _, q in ipairs(info.quests) do result[#result + 1] = q.id .. ":" .. q.state end
      return result
    end

    it("checks a race mask against a faction, also above 32 bits", function()
      assert.is_true(Dungeons.factionAllows(0, HORDE))
      assert.is_true(Dungeons.factionAllows(HORDE, HORDE))
      assert.is_false(Dungeons.factionAllows(ALLIANCE, HORDE))
      assert.is_true(Dungeons.factionAllows(8589934592 + 2, HORDE)) -- Horde Skyborne (bit 33) plus Orc
      assert.is_false(Dungeons.factionAllows(8589934592, 4294967296)) -- the two Skyborne bits
      assert.is_true(Dungeons.factionAllows(ALLIANCE, nil)) -- unknown faction: no filter
    end)

    it("lists QuestieDB quests for your faction: have, available, later, done", function()
      local entry = dmEntry()
      local me = entry.candidates[2] -- Ann (20), not Ben
      assert.are.equal("G-ME", me.guid)
      me.quests = { [102] = { title = "Oh Brother..." } }
      local info = Dungeons.quests(entry.dungeon, DATA, { char = me, candidates = entry.candidates,
        factionMask = HORDE, completed = { [105] = true } })
      assert.is_true(info.complete)
      assert.are.same({ "102:have", "101:available", "104:later", "105:done" }, states(info)) -- 103 is Alliance
      assert.are.equal(1, info.have)
      assert.are.equal(2, info.total)
      assert.are.same({ "Ben Example" }, info.quests[2].holders) -- Ben has 101 in his log
    end)

    it("falls back to the quests people in range have in their logs", function()
      local entry = dmEntry()
      local me
      for _, c in ipairs(entry.candidates) do if c.guid == "G-ME" then me = c end end
      local info = Dungeons.quests(entry.dungeon, nil, { char = me, candidates = entry.candidates })
      assert.is_false(info.complete)
      assert.are.same({ "101:available" }, states(info))
      assert.are.equal("Red Silk Bandanas", info.quests[1].name)
      assert.are.same({ 0, 1 }, { info.have, info.total })
    end)
  end)

  describe("calendar events", function()
    local NOW = { year = 2026, month = 10, monthDay = 18, weekday = 1, hour = 12, minute = 0 }
    local function at(day, hour)
      return { year = 2026, month = 10, monthDay = day, weekday = 7, hour = hour, minute = 0 }
    end

    it("matches events on the dungeon name, \"The\" optional, soonest first", function()
      local dm = Dungeons.get("dm")
      local events = {
        { title = "Deadmines run", calendarType = "COMMUNITY_EVENT", startTime = at(25, 20) },
        { title = "The Deadmines", calendarType = "PLAYER", startTime = at(24, 19) },
        { title = "VC farm", calendarType = "PLAYER", startTime = at(24, 19) }, -- no short names
        { title = "Darkmoon Faire", calendarType = "HOLIDAY", startTime = at(20, 0) },
        { title = "Deadmines yesterday", calendarType = "PLAYER", startTime = at(17, 20) },
        { title = "Wailing Caverns", calendarType = "PLAYER", startTime = at(26, 20) },
      }
      local found = Dungeons.events(events, dm, NOW)
      assert.are.same({ "The Deadmines", "Deadmines run" }, { found[1].title, found[2].title })
      assert.are.equal(2, #found)
    end)

    it("picks the longest dungeon name in a title", function()
      assert.are.equal("smcath", Dungeons.dungeonOf("Scarlet Monastery Cathedral tonight").id)
      assert.are.equal("ubrs", Dungeons.dungeonOf("Upper Blackrock Spire").id)
      assert.is_nil(Dungeons.dungeonOf("Raid night"))
    end)

    it("lists runs planned in the next 3 days, also across a month end", function()
      local now = { year = 2026, month = 10, monthDay = 30, weekday = 6, hour = 12, minute = 0 }
      local events = {
        { title = "Deadmines", startTime = { year = 2026, month = 11, monthDay = 2, weekday = 2, hour = 11 } },
        { title = "Stratholme", startTime = { year = 2026, month = 11, monthDay = 2, weekday = 2, hour = 13 } },
        { title = "Wailing Caverns", startTime = { year = 2026, month = 10, monthDay = 31, weekday = 7, hour = 20 } },
        { title = "Raid night", startTime = { year = 2026, month = 10, monthDay = 31, weekday = 7, hour = 20 } },
      }
      local planned = Dungeons.planned(events, now)
      assert.are.same({ "wc", "dm" }, { planned[1].dungeon.id, planned[2].dungeon.id })
      assert.are.equal(2, #planned) -- Stratholme is 3 days and 1 hour away
      assert.are.equal("Sat 20:00", Dungeons.shortTime(planned[1].event.startTime))
    end)

    it("counts signed up, accepted and confirmed; tentative apart", function()
      assert.are.same({ 3, 1 }, { Dungeons.signUps({ 6, 3, 1, 8, 2, 0, 7 }) })
      assert.are.same({ 0, 0 }, { Dungeons.signUps(nil) })
    end)

    it("words the event time and your sign-up", function()
      assert.are.equal("Sat 25 Oct, 20:00", Dungeons.eventTime(at(25, 20)))
      assert.are.equal("you signed up", Dungeons.signUp(6))
      assert.is_nil(Dungeons.signUp(nil))
    end)
  end)
end)
