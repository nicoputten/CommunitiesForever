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

    it("takes the character you are on, your others are alternatives (CF-42)", function()
      local v = view()
      v.people[1].chars[2] = row("G-ALT", "Amy Example", 21, { quests = { [101] = DM_QUEST } })
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(v), "G-ME"), "dm")
      local group = Dungeons.suggest(dm)
      assert.are.equal("Ann Example", group[1].name)
      local alternatives, others = Dungeons.outside(dm, group)
      assert.are.same({ "Amy Example" }, names(alternatives))
      assert.are.same({ "Bob Example" }, names(others)) -- Ben's tank alt: Ben brings his healer
      -- Without the character you are on, your best one (quests first).
      dm = entryFor(Dungeons.overview(Dungeons.candidates(v)), "dm")
      assert.are.equal("Amy Example", Dungeons.suggest(dm)[1].name)
    end)

    it("lists only dungeons for the character you are on (CF-42)", function()
      local overview = Dungeons.overview(Dungeons.candidates(view()), "G-ALT") -- Amy, 45
      assert.is_nil(entryFor(overview, "dm"))
      assert.is_true(entryFor(overview, "zf").fits)
      assert.are.equal("Tanaris", Dungeons.ZONES.zf)
    end)

    it("lays the group out as tank, healer and three damage slots (CF-42)", function()
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(view()), "G-ME"), "dm")
      local slots = Dungeons.slots(Dungeons.suggest(dm), "G-ME")
      assert.are.same({ "tank", "heal", "dps", "dps", "dps" },
        { slots[1].role, slots[2].role, slots[3].role, slots[4].role, slots[5].role })
      assert.are.equal("Cid Example", slots[1].char.name)
      assert.are.equal("Ben Example", slots[2].char.name)
      assert.are.equal("Ann Example", slots[3].char.name)
      assert.is_true(slots[3].own)
      assert.are.equal("Dee Example", slots[4].char.name)
      assert.is_nil(slots[5].char) -- open
      assert.is_nil(slots[5].missing)

      -- Nobody heals: the healer slot is missing; extra characters fill free slots.
      local noHeal = Dungeons.slots({ { guid = "A", role = "tank" }, { guid = "B" }, { guid = "C" }, { guid = "D" },
                                      { guid = "E" } }, "B")
      assert.are.same({ "B", "C", "D" }, { noHeal[3].char.guid, noHeal[4].char.guid, noHeal[5].char.guid })
      assert.are.equal("E", noHeal[2].char.guid) -- 4 damage for 3 damage slots: the fourth fills the healer slot
      assert.is_nil(noHeal[2].missing)
      local fewer = Dungeons.slots({ { guid = "A", role = "tank" } }, "X")
      assert.is_true(fewer[2].missing)
      assert.is_nil(fewer[1].own)
    end)

    it("stops at five", function()
      local v = view()
      for i = 1, 8 do
        v.unlinked[#v.unlinked + 1] = row("G-U" .. i, "Member " .. i, 20)
      end
      local dm = entryFor(Dungeons.overview(Dungeons.candidates(v), "G-ME"), "dm")
      assert.are.equal(5, #Dungeons.suggest(dm))
    end)
  end)

  describe("Group Finder list (V46)", function()
    local ACTIVITIES = {
      { activityID = 800, name = "Shadowfang Keep", min = 20, max = 30 },
      { activityID = 813, name = "Dire Maul (East)", min = 54, max = 60 },
      { activityID = 815, name = "Dire Maul (North)", min = 56, max = 60 },
      { activityID = 1981, name = "Excavation Site: Wetlands", min = 26, max = 33 },
      { activityID = 1999, name = "Broken", min = 0, max = 0 },
    }

    it("takes the game's level ranges and adds dungeons the static table does not know", function()
      Dungeons.applyGroupFinder(ACTIVITIES)
      assert.are.same({ 20, 30 }, { Dungeons.get("sfk").min, Dungeons.get("sfk").max })
      assert.are.same({ 54, 60 }, { Dungeons.get("dme").min, Dungeons.get("dme").max }) -- wings: lowest min
      assert.is_nil(Dungeons.get("dm")) -- not offered by the Group Finder: not listed (feedback)
      assert.is_nil(Dungeons.get("stocks"))
      local new = Dungeons.get("lfg1981")
      assert.are.equal("Excavation Site: Wetlands", new.name)
      assert.are.same({ 26, 33 }, { new.min, new.max })
      assert.are.same({ "Excavation Site: Wetlands" }, new.areas)
      assert.is_nil(Dungeons.get("lfg1999"))
      assert.are.equal(22, Dungeons.STATIC[4].min) -- the static table itself is untouched
      assert.are.equal("lfg1981", Dungeons.dungeonOf("Excavation Site: Wetlands run").id)
    end)

    it("keeps the static list without Group Finder data", function()
      Dungeons.applyGroupFinder(ACTIVITIES)
      Dungeons.applyGroupFinder({})
      assert.are.equal(Dungeons.STATIC, Dungeons.LIST)
    end)

    it("lists a new dungeon for your characters in its range", function()
      Dungeons.applyGroupFinder(ACTIVITIES)
      local v = view()
      v.people[1].chars[1].level = 30
      local overview = Dungeons.overview(Dungeons.candidates(v), "G-ME")
      assert.is_not_nil(entryFor(overview, "lfg1981"))
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

    it("reads quests from the area IDs QuestieDB files them under", function()
      local gnomer = Dungeons.get("gnomer")
      local info = Dungeons.quests(gnomer, { [133] = { { id = 2904, name = "A Fine Mess", level = 30 } } },
        { char = { guid = "G-ME", level = 30 } })
      assert.are.equal(1, info.total)
    end)

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

  it("finds the dungeon a text names, the longest name first", function()
    assert.are.equal("dm", Dungeons.dungeonOf("Deadmines run").id)
    assert.are.equal("smcath", Dungeons.dungeonOf("Scarlet Monastery Cathedral tonight").id)
    assert.are.equal("ubrs", Dungeons.dungeonOf("Upper Blackrock Spire").id)
    assert.is_nil(Dungeons.dungeonOf("Raid night"))
  end)
end)
