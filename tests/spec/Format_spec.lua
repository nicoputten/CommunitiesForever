local helpers = require("helpers")

describe("Format", function()
  local Format
  local NOW = 100000

  local function charRow(overrides)
    local row = { guid = "G1", name = "Garraka", classFile = "MAGE", classID = 8, level = 11, ilvl = 20,
                  online = true, zone = "Orgrimmar", realm = "Classic Beta PvP",
                  professions = { [186] = { name = "Mining", rank = 60, max = 150 },
                                  [185] = { name = "Cooking", rank = 75, max = 75 } } }
    for k, v in pairs(overrides or {}) do row[k] = v end
    return row
  end

  local function person(overrides)
    local p = { battleTag = "Sjaakovich#2232", displayName = "Sjaak", isSelf = false, online = true,
                chars = { charRow(), charRow({ guid = "G2", name = "Grom", classFile = "WARRIOR", online = false,
                                               lastSeen = NOW - 7200, ilvl = false, professions = {} }) } }
    p.currentChar = p.chars[1]
    for k, v in pairs(overrides or {}) do p[k] = v end
    return p
  end

  local function me()
    local p = person({ battleTag = "Vestras#2858", displayName = "Vestras", isSelf = true,
                       chars = { charRow({ guid = "G-ME", name = "Ves" }) } })
    p.currentChar = p.chars[1]
    return p
  end

  local unlinked = { { guid = "U1", name = "Stranger", classID = 8, level = 9, online = false } }

  before_each(function()
    local ns = {}
    helpers.loadAddonFile("src/core/Quests.lua", ns)
    Format = helpers.loadAddonFile("src/core/Format.lua", ns)
  end)

  describe("ago and seen", function()
    it("formats durations", function()
      assert.are.equal("just now", Format.ago(NOW - 30, NOW))
      assert.are.equal("5 min ago", Format.ago(NOW - 300, NOW))
      assert.are.equal("3 h ago", Format.ago(NOW - 3 * 3600 - 10, NOW))
      assert.are.equal("2 d ago", Format.ago(NOW - 2 * 86400, NOW))
      assert.are.equal("never", Format.ago(nil, NOW))
      assert.are.equal("just now", Format.ago(NOW + 50, NOW)) -- clock skew
    end)

    it("uses the latest of presence, lastPlayed and data change", function()
      assert.are.equal("Now", Format.seen(charRow(), NOW))
      assert.are.equal("2 h ago", Format.seen(charRow({ online = false, lastSeen = NOW - 7200 }), NOW))
      assert.are.equal("just now", -- own alt: last played beats an old data change
        Format.seen(charRow({ online = false, updatedAt = NOW - 7200, lastPlayed = NOW - 10 }), NOW))
      assert.are.equal("never", Format.seen(charRow({ online = false }), NOW))
    end)
  end)

  describe("professionList", function()
    it("sorts by name with a progress fraction", function()
      assert.are.same({
        { name = "Cooking", rank = 75, max = 75, fraction = 1 },
        { name = "Mining", rank = 60, max = 150, fraction = 0.4 },
      }, Format.professionList(charRow().professions))
      assert.are.same({}, Format.professionList(nil))
      assert.are.equal(0, Format.professionList({ [1] = { name = "X", rank = 5, max = 0 } })[1].fraction)
    end)
  end)

  describe("truncate", function()
    it("keeps short text and cuts long text with dots", function()
      assert.are.equal("Garraka", Format.truncate("Garraka", 10))
      assert.are.equal("Kawkartha Skystrider", Format.truncate("Kawkartha Skystrider", 20))
      assert.are.equal("Kawkartha Sky...", Format.truncate("Kawkartha Skystrider", 16))
    end)

    it("counts characters, not bytes", function()
      assert.are.equal("Åsa Öberg", Format.truncate("Åsa Öberg", 9))
      assert.are.equal("Åsa Ö...", Format.truncate("Åsa Öbergström", 8))
    end)
  end)

  describe("talentSummary (CF-18)", function()
    local function talents(a, b, c)
      return { { name = "Holy", points = a }, { name = "Protection", points = b },
               { name = "Retribution", points = c } }
    end

    it("uses the classic notation with the main tree", function()
      assert.are.same({ role = "Healer", roleSource = "talents", mainName = "Holy", numbers = "31 / 5 / 15",
                        treeNames = "Holy \194\183 Protection \194\183 Retribution" },
        Format.talentSummary({ talents = talents(31, 5, 15), role = "heal" }))
    end)

    it("has no main tree without spent points and says when the role was set by the player", function()
      local summary = Format.talentSummary({ talents = talents(0, 0, 0), role = "tank", roleOverride = "tank" })
      assert.is_nil(summary.mainName)
      assert.are.equal("0 / 0 / 0", summary.numbers)
      assert.are.equal("player", summary.roleSource)
    end)

    it("returns nil without talent data", function()
      assert.is_nil(Format.talentSummary({}))
    end)
  end)

  describe("professionGroups", function()
    it("splits primary and secondary professions, leaving out empty groups", function()
      local groups = Format.professionGroups({
        [186] = { name = "Mining", rank = 1, max = 75 },
        [164] = { name = "Blacksmithing", rank = 1, max = 75 },
        [129] = { name = "First Aid", rank = 1, max = 75 },
        [185] = { name = "Cooking", rank = 1, max = 75 },
        [356] = { name = "Fishing", rank = 1, max = 75 },
      })
      assert.are.same({ "Primary", "Secondary" }, { groups[1].title, groups[2].title })
      assert.are.same({ "Blacksmithing", "Mining" }, { groups[1].list[1].name, groups[1].list[2].name })
      assert.are.same({ "Cooking", "First Aid", "Fishing" },
        { groups[2].list[1].name, groups[2].list[2].name, groups[2].list[3].name })

      local onlySecondary = Format.professionGroups({ [185] = { name = "Cooking", rank = 1, max = 75 } })
      assert.are.same({ "Secondary" }, { onlySecondary[1].title })
      assert.are.same({}, Format.professionGroups(nil))
    end)
  end)

  describe("paths", function()
    it("joins and splits group and character", function()
      local path = Format.path("Sjaakovich#2232", "G1")
      assert.are.equal("Sjaakovich#2232\001G1", path)
      assert.are.same({ "Sjaakovich#2232", "G1" }, { Format.splitPath(path) })
      assert.are.same({ "Sjaakovich#2232" }, { Format.splitPath("Sjaakovich#2232") })
    end)
  end)

  describe("tree", function()
    it("lists people with their characters, then Unlinked", function()
      local nodes = Format.tree({ people = { person(), me() }, unlinked = unlinked })
      assert.are.equal(3, #nodes)
      assert.are.same({ "Sjaakovich#2232", "Sjaak", true, false },
        { nodes[1].value, nodes[1].text, nodes[1].online, nodes[1].isSelf })
      assert.are.equal(2, nodes[1].count)
      assert.are.same({ value = "G1", name = "Garraka", classFile = "MAGE", classID = 8, level = 11, online = true,
                        outside = false, sharedDungeon = false, shared = 0 },
        nodes[1].children[1])
      assert.are.equal("Vestras (you)", nodes[2].text)
      assert.are.same({ Format.UNLINKED, "Unlinked", true }, { nodes[3].value, nodes[3].text, nodes[3].unlinked })
      assert.are.equal("U1", nodes[3].children[1].value)
    end)

    it("has no Unlinked group without unlinked characters", function()
      assert.are.equal(1, #Format.tree({ people = { person() }, unlinked = {} }))
    end)

    it("uses a special value for own characters without a BattleTag", function()
      local nodes = Format.tree({ people = { person({ battleTag = false, isSelf = true }) }, unlinked = {} })
      assert.are.equal(Format.SELF, nodes[1].value)
    end)
  end)

  -- CF-40: the revamped Friends tab.
  describe("friends tab models (CF-40)", function()
    it("draws professions on the vanilla scale with training steps, secondary ones muted", function()
      assert.are.same({ fill = 60 / 300, cap = 150 / 300, ticks = { 0.25, 0.5, 0.75 }, muted = false },
        Format.skillBar({ rank = 60, max = 150 }))
      local cooking = Format.skillBar({ rank = 400, max = nil }, true)
      assert.are.same({ 1, 0, true }, { cooking.fill, cooking.cap, cooking.muted }) -- clamped, nil max
    end)

    it("draws talent trees as bars out of 31, the fullest tree marked", function()
      assert.is_nil(Format.talentBars({}))
      assert.is_nil(Format.talentBars({ talents = {} }))
      local bars = Format.talentBars({ talents = { { name = "Arms", points = 31 }, { name = "Fury", points = 5 },
                                                   { name = "Protection" } } })
      assert.are.same({ name = "Arms", points = 31, fraction = 1, main = true }, bars[1])
      assert.are.same({ name = "Fury", points = 5, fraction = 5 / 31, main = false }, bars[2])
      assert.are.same({ name = "Protection", points = 0, fraction = 0, main = false }, bars[3])
      assert.is_false(Format.talentBars({ talents = { { name = "Arms", points = 0 } } })[1].main)
    end)

    it("says under the name who plays it and where it is", function()
      local view = { people = { person(), me() }, unlinked = unlinked }
      local grom = Format.detail(view, Format.path("Sjaakovich#2232", "G2"), NOW)
      assert.are.equal("played by Sjaak \194\183 offline, last seen 2 h ago", grom.subtitle)
      view.people[1].chars[2].lastZone = "The Barrens"
      grom = Format.detail(view, Format.path("Sjaakovich#2232", "G2"), NOW)
      assert.are.equal("played by Sjaak \194\183 offline, last seen in The Barrens 2 h ago", grom.subtitle)
      local ves = Format.detail(view, Format.path("Vestras#2858", "G-ME"), NOW)
      assert.are.equal("your character \194\183 online in Orgrimmar", ves.subtitle)
      view.people[1].chars[1].outside = true
      local garraka = Format.detail(view, Format.path("Sjaakovich#2232", "G1"), NOW)
      assert.are.equal("played by Sjaak \194\183 online in Orgrimmar \194\183 not in community", garraka.subtitle)
    end)

    it("has level, item level and role tiles, with where the role comes from", function()
      local view = { people = { person(), me() }, unlinked = unlinked }
      view.people[1].chars[2].talents = { { name = "Arms", points = 20 }, { name = "Fury", points = 0 },
                                          { name = "Protection", points = 0 } }
      view.people[1].chars[2].role = "tank"
      view.people[1].chars[2].roleOverride = "tank"
      local d = Format.detail(view, Format.path("Sjaakovich#2232", "G2"), NOW)
      assert.are.same({ label = "Item level", value = "-" }, d.tiles[2])
      assert.are.equal("Role", d.tiles[3].label)
      assert.is_string(d.tiles[3].note)
      assert.are.equal(3, #d.talentBars)
      assert.is_nil(Format.detail(view, Format.path("Sjaakovich#2232", "G1"), NOW).talentBars)
    end)

    it("sums up the sync state for the footer", function()
      local view = { people = { person(), me() }, unlinked = unlinked }
      assert.are.equal("Not synced yet \194\183 2 characters from 1 friend", Format.friendsFooter(view, NOW))
      view.people[1].receivedAt = NOW - 120
      assert.are.equal("Synced with Sjaak 2 min ago \194\183 2 characters from 1 friend",
        Format.friendsFooter(view, NOW))
      assert.are.equal("Not synced yet \194\183 0 characters from 0 friends", Format.friendsFooter({}, NOW))
      assert.are.equal("Synced with Sjaak 2 min ago", Format.syncedText(view, NOW)) -- CF-42: the Dungeons footer
    end)

    it("counts quests shared with you on friends' characters in the list", function()
      local friend = person()
      friend.chars[1].quests = { [1] = { title = "One", area = "Durotar" }, [2] = { title = "Two", area = "Durotar" } }
      local mine = me()
      mine.chars[1].quests = { [1] = { title = "One", area = "Durotar" } }
      local nodes = Format.tree({ people = { friend, mine }, unlinked = {} })
      assert.are.equal(1, nodes[1].children[1].shared)
      assert.is_nil(nodes[2].children[1].shared) -- your own
    end)
  end)

  describe("detail", function()
    local view

    before_each(function()
      view = { people = { person(), me() }, unlinked = unlinked }
    end)

    it("asks for a selection without a path", function()
      assert.are.same({ kind = "message", text = "Select a person or character on the left." },
        Format.detail(view, nil, NOW))
    end)

    it("describes a person with status and characters", function()
      local d = Format.detail(view, "Sjaakovich#2232", NOW)
      assert.are.equal("person", d.kind)
      assert.are.equal("Sjaak", d.title)
      assert.are.equal("Sjaakovich#2232", d.battleTag)
      assert.are.equal("Online on Garraka", d.status)
      assert.are.same({ guid = "G2", name = "Grom", classFile = "WARRIOR", classID = 8, level = 11, seen = "2 h ago",
                        own = false, outside = false },
        d.characters[2])
    end)

    it("says on the card whether they run the addon (CF-34), not on your own", function()
      view.people[1] = person({ usesAddon = true })
      assert.are.equal(Format.USES_ADDON, Format.detail(view, "Sjaakovich#2232", NOW).addon)
      view.people[1] = person({ usesAddon = false })
      assert.are.equal(Format.NO_ADDON, Format.detail(view, "Sjaakovich#2232", NOW).addon)
      local mine = Format.detail(view, view.people[2].battleTag, NOW)
      assert.is_nil(mine.addon)
      local nodes = Format.tree(view)
      assert.is_false(nodes[1].usesAddon)
    end)

    it("describes an offline person and one on a character outside the community", function()
      view.people[1] = person({ online = false, currentChar = false })
      assert.are.equal("Offline - last seen on Grom, 2 h ago", Format.detail(view, "Sjaakovich#2232", NOW).status)
      view.people[1] = person({ currentChar = { name = "Alt", visible = false } })
      assert.are.equal("Online on Alt (not in community)", Format.detail(view, "Sjaakovich#2232", NOW).status)
    end)

    it("describes a character with stats and professions", function()
      local d = Format.detail(view, Format.path("Sjaakovich#2232", "G1"), NOW)
      assert.are.same({
        kind = "character", guid = "G1", name = "Garraka", classFile = "MAGE", classID = 8, owner = "Sjaak",
        status = "Online in Orgrimmar", online = true, outside = false,
        stats = { { label = "Level", value = "11" }, { label = "Item level", value = "20" },
                  { label = "Last seen", value = "Now" } },
        professions = Format.professionGroups(charRow().professions),
        sharedQuests = { total = 0, more = 0, areas = {}, expandable = false, showAll = false }, -- CF-19
        subtitle = "played by Sjaak \194\183 online in Orgrimmar", -- CF-40
        tiles = { { label = "Level", value = "11", fraction = 11 / 60 }, { label = "Item level", value = "20" },
                  { label = "Role", value = "-" } },
      }, d)
    end)

    it("shows missing item level and offline characters", function()
      local d = Format.detail(view, Format.path("Sjaakovich#2232", "G2"), NOW)
      assert.are.equal("Offline", d.status) -- the time is in the Last seen box, not repeated here
      assert.are.equal("-", d.stats[2].value)
      assert.are.equal("2 h ago", d.stats[3].value)
      assert.are.same({}, d.professions)
    end)

    it("describes the Unlinked group and its characters", function()
      assert.are.equal("unlinked", Format.detail(view, Format.UNLINKED, NOW).kind)
      local d = Format.detail(view, Format.path(Format.UNLINKED, "U1"), NOW)
      assert.are.equal("Stranger", d.name)
      assert.are.equal("Unlinked", d.owner)
    end)

    it("shows the last seen zone, character and time for an offline person", function()
      local p = person({ online = false, currentChar = false })
      p.chars[1].online = false
      p.chars[1].lastZone, p.chars[1].lastZoneAt = "The Barrens", NOW - 600
      view.people[1] = p
      assert.are.equal("Offline - last seen in The Barrens on Garraka, 10 min ago",
        Format.detail(view, "Sjaakovich#2232", NOW).status)
      assert.are.equal("Offline - last seen in The Barrens",
        Format.detail(view, Format.path("Sjaakovich#2232", "G1"), NOW).status)
    end)

    it("says \"played\" for your own characters", function()
      local mine = me()
      mine.chars[2] = charRow({ guid = "G-ALT", name = "Alt", online = false, lastZone = "Durotar",
                                lastPlayed = NOW - 60 })
      view.people[2] = mine
      local d = Format.detail(view, Format.path("Vestras#2858", "G-ALT"), NOW)
      assert.are.equal("Offline - last played in Durotar", d.status)
      assert.are.same({ label = "Last played", value = "1 min ago" }, d.stats[3])
      assert.is_true(Format.detail(view, "Vestras#2858", NOW).characters[2].own)
    end)

    it("says just Offline when nothing is known", function()
      local p = person({ online = false, currentChar = false,
                         chars = { charRow({ online = false }) } })
      view.people[1] = p
      assert.are.equal("Offline", Format.detail(view, "Sjaakovich#2232", NOW).status)
    end)

    it("falls back to the message for paths that no longer exist", function()
      assert.are.equal("message", Format.detail(view, "Gone#1", NOW).kind)
      assert.are.equal("message", Format.detail(view, Format.path("Sjaakovich#2232", "G9"), NOW).kind)
    end)
  end)

  describe("onlineList (CF-33)", function()
    local function onlinePerson(name, online, char, isSelf)
      return { displayName = name, online = online, isSelf = isSelf, currentChar = char }
    end

    it("lists other people online, sorted by display name, with their current character", function()
      local view = { people = {
        onlinePerson("cid", true, { name = "Cid Char", classFile = "MAGE", level = 20 }),
        onlinePerson("Ann", true, { name = "Ann Char", classFile = "PRIEST", classID = 5, level = 24 }),
        onlinePerson("Me", true, { name = "My Char" }, true),
        onlinePerson("Ben", false, { name = "Ben Char" }),
      } }
      local list = Format.onlineList(view)
      assert.are.same({
        { displayName = "Ann", name = "Ann Char", classFile = "PRIEST", classID = 5, level = 24 },
        { displayName = "cid", name = "Cid Char", classFile = "MAGE", level = 20 },
      }, list.entries)
      assert.are.equal(0, list.more)
    end)

    it("keeps people whose character is not known, and caps the list", function()
      local people = { onlinePerson("Solo", true, nil) }
      for i = 1, 17 do people[#people + 1] = onlinePerson(string.format("P%02d", i), true, { name = "C" .. i }) end
      local list = Format.onlineList({ people = people })
      assert.are.equal(Format.ONLINE_MAX, #list.entries)
      assert.are.equal(18 - Format.ONLINE_MAX, list.more)
      assert.is_nil(Format.onlineList({ people = { onlinePerson("Solo", true, nil) } }).entries[1].name)
    end)

    it("is empty with nobody online", function()
      assert.are.same({ entries = {}, more = 0 }, Format.onlineList({ people = {} }))
    end)
  end)

  describe("empty state and hint", function()
    it("asks to select a community", function()
      assert.are.equal("Select a community in settings (/cf settings).",
        Format.emptyState({ people = {}, unlinked = {} }, { selected = false }))
    end)

    it("explains that this character is not a member of the community", function()
      assert.are.equal("Your account has characters in Forever Friends, but Kawkartha Skystrider isn't a member, "
        .. "so it can't be shown here. Log in on a member character, or invite this one.",
        Format.emptyState({ people = {}, unlinked = {} }, { selected = true, active = false,
          communityName = "Forever Friends", characterName = "Kawkartha Skystrider" }))
      assert.matches("characters in the selected community, but this character",
        Format.emptyState({ people = {}, unlinked = {} }, { selected = true, active = false }), 1, true)
    end)

    it("says when the community has nobody to show", function()
      assert.are.equal("Nobody in this community yet.",
        Format.emptyState({ people = {}, unlinked = {} }, { selected = true, active = true }))
      assert.is_nil(Format.emptyState({ people = { me() }, unlinked = {} }, { selected = true, active = true }))
    end)

    it("hints when only you are linked", function()
      assert.matches("^No linked friends yet", Format.friendsHint({ people = { me() }, unlinked = {} }))
      assert.is_nil(Format.friendsHint({ people = { me(), person() }, unlinked = {} }))
    end)
  end)
end)
