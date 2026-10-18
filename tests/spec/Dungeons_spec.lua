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

    it("words the event title and the group", function()
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(view()), "G-ME"), "dm")
      assert.are.equal("The Deadmines run", Dungeons.eventTitle(dm.dungeon))
      assert.are.equal("Ann Example (DPS), Cid Example (Tank), Ben Example (Healer), Dee Example",
        Dungeons.groupText(Dungeons.suggest(dm)))
    end)
  end)

  describe("calendar events", function()
    local NOW = { year = 2026, month = 10, monthDay = 18, weekday = 1, hour = 12, minute = 0 }
    local function at(day, hour)
      return { year = 2026, month = 10, monthDay = day, weekday = 7, hour = hour, minute = 0 }
    end

    it("matches titles that mention the dungeon by name or a whole-word alias, soonest first", function()
      local dm = Dungeons.get("dm")
      local events = {
        { title = "Deadmines run", calendarType = "COMMUNITY_EVENT", startTime = at(25, 20) },
        { title = "VC farm", calendarType = "PLAYER", startTime = at(24, 19) },
        { title = "Darkmoon Faire", calendarType = "HOLIDAY", startTime = at(20, 0) },
        { title = "Deadmines yesterday", calendarType = "PLAYER", startTime = at(17, 20) },
        { title = "Wailing Caverns", calendarType = "PLAYER", startTime = at(26, 20) },
        { title = "avcd", calendarType = "PLAYER", startTime = at(26, 20) }, -- "vc" inside a word
      }
      local found = Dungeons.events(events, dm, NOW)
      assert.are.same({ "VC farm", "Deadmines run" }, { found[1].title, found[2].title })
    end)

    it("words the event time and your sign-up", function()
      assert.are.equal("Sat 25 Oct, 20:00", Dungeons.eventTime(at(25, 20)))
      assert.are.equal("you signed up", Dungeons.signUp(6))
      assert.is_nil(Dungeons.signUp(nil))
    end)
  end)
end)
