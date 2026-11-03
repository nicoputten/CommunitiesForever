local helpers = require("helpers")

describe("Missions: quests (CF-71)", function()
  local ns, Q

  before_each(function()
    ns = helpers.coreNs()
    helpers.loadAddonFile("src/core/Doomsday.lua", ns)
    helpers.loadAddonFile("src/core/Goals.lua", ns)
    helpers.loadAddonFile("src/core/missions/Quests.lua", ns)
    Q = ns.Missions.Quests
  end)

  it("loads as a mission module", function()
    assert.is_table(Q)
    assert.is_true(ns.Goals.isModuleKind("questDone"))
    assert.is_true(ns.Goals.isModuleKind("questAccepted"))
  end)

  it("passes its progress cases", function()
    local cases = helpers.readJson("tests/fixtures/missions/quests.json").cases
    assert.is_true(#cases > 0)
    for _, case in ipairs(cases) do
      local f = ns.Goals.newFacts()
      for _, obs in ipairs(case.observations) do ns.Goals.observe(f, obs) end
      local value, target, done = ns.Doomsday.progress(case.goal, ns.Goals.progressFacts(f, {}))
      assert.are.same({ case.value, case.target, case.done }, { value, target, done }, case.name)
    end
  end)

  it("registers the progress of every quests daily and the weeklies that read its data", function()
    for _, id in ipairs({ "d.questUp", "d.groupQuest", "d.classQuest", "d.dungeonQuest", "d.questBurst", "d.accept5",
                          "d.questTogether", "w.groupQuests3", "w.questUp5", "w.duoQuests5" }) do
      local value, _, done = ns.Doomsday.progress(id, {})
      assert.are.same({ 0, false }, { value, done }, id)
    end
  end)

  it("keeps a day's facts small: accepted IDs and characters with times are capped", function()
    local f = ns.Goals.newFacts()
    for id = 1, Q.MAX_ACCEPTED + 10 do ns.Goals.observe(f, { kind = "questAccepted", questID = id }) end
    assert.are.equal(Q.MAX_ACCEPTED, f.quests2.acceptedCount)
    for i = 1, Q.MAX_CHARS + 5 do ns.Goals.observe(f, { kind = "questDone", guid = "Player-1-" .. i, t = i }) end
    local n = 0
    for _, list in pairs(f.quests2.times) do
      n = n + 1
      assert.is_true(#list <= Q.BURST_COUNT - 1)
    end
    assert.are.equal(Q.MAX_CHARS, n)
  end)

  describe("turnIn", function()
    local char = { guid = "Player-1-A", level = 10, classFile = "PRIEST", quests = {
      [101] = { title = "Group quest", area = "Priest", dungeon = false, level = 12, suggestedGroup = 3 },
      [102] = { title = "Older record", area = "Wailing Caverns", dungeon = true },
    } }

    it("reads the quest's details from the stored log", function()
      assert.are.same({ kind = "questDone", t = 500, guid = "Player-1-A", charLevel = 10, classFile = "PRIEST",
                        level = 12, group = 3, area = "Priest", dungeon = false, grouped = true },
        Q.turnIn(char, 101, 500, true))
    end)

    it("leaves missing fields nil: a record of an older version, a quest the log doesn't know", function()
      local old = Q.turnIn(char, 102, 500, false)
      assert.is_nil(old.level)
      assert.is_nil(old.group)
      assert.is_true(old.dungeon)
      local unknown = Q.turnIn(char, 999, 500, false)
      assert.is_nil(unknown.area)
      assert.is_false(unknown.dungeon)
      assert.are.equal("Player-1-A", unknown.guid)
      assert.are.equal("questDone", Q.turnIn(nil, nil, nil, nil).kind)
    end)
  end)

  describe("friendInGroup", function()
    local people = {
      ["Ada#1001"] = { chars = { ["Player-1-F"] = {} } },
      ["Me#1234"] = { chars = { ["Player-1-ALT"] = {} } },
    }
    local presence = { ["Player-1-P"] = { battleTag = "Bob#1002" }, ["Player-1-ME"] = { battleTag = "Me#1234" } }

    it("finds a friend's character, from synced records or presence", function()
      assert.is_true(Q.friendInGroup({ "Player-1-X", "Player-1-F" }, people, presence, "Me#1234"))
      assert.is_true(Q.friendInGroup({ "Player-1-P" }, people, presence, "Me#1234"))
    end)

    it("never counts an own alt or a stranger", function()
      assert.is_false(Q.friendInGroup({ "Player-1-ALT", "Player-1-ME", "Player-1-X" }, people, presence, "Me#1234"))
      assert.is_false(Q.friendInGroup({}, people, presence, "Me#1234"))
      assert.is_false(Q.friendInGroup(nil, nil, nil, "Me#1234"))
    end)
  end)
end)

describe("Missions: quests in game (CF-71)", function()
  local wowapi = require("mocks.wowapi")
  local state, ns, addon

  after_each(function()
    wowapi.uninstall()
  end)

  local function load()
    state, ns, addon = helpers.client({ setup = function(s)
      s.questLog = {
        { isHeader = true, title = "Durotar" },
        { questID = 1001, title = "Hard One", level = 15 },
        { questID = 1002, title = "Group One", level = 8, suggestedGroup = 3 },
        { isHeader = true, title = "Warrior" },
        { questID = 1003, title = "Class One", level = 10 },
      }
    end })
  end

  local function quests2()
    local days = addon.db.global.self.doomsday.days
    return days[ns.DoomsdayTracker.today()].quests2
  end

  it("stores the quest level and group size in the quest log", function()
    load()
    local guid = state.clubMembers["23125681"][1].guid
    local quests = addon.db.global.self.chars[guid].quests
    assert.are.same({ title = "Hard One", area = "Durotar", dungeon = false, level = 15 }, quests[1001])
    assert.are.equal(3, quests[1002].suggestedGroup)
  end)

  it("tracks hand-ins with the stored details and a friend in the group, and accepted quests", function()
    load()
    local friendGuid = state.clubMembers["23125681"][2].guid
    local friendTag = state.friends[1].battleTag
    addon.db.global.people[friendTag] = { displayName = "Friend", version = 5, chars = {
      [friendGuid] = { guid = friendGuid, name = "Friend Char", classFile = "MAGE", level = 11 },
    } }
    local char = addon.db.global.self.chars[state.clubMembers["23125681"][1].guid]
    char.level, char.classFile = 10, "WARRIOR"
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 1001, 500, 0)
    state.setGroup({ friendGuid })
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 1002, 500, 0)
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 1003, 500, 0)
    wowapi.fireEvent(state, "QUEST_ACCEPTED", 2001)
    wowapi.fireEvent(state, "QUEST_ACCEPTED", 7, 2002) -- the Classic form: (questLogIndex, questID)
    local q = quests2()
    assert.are.equal(1, q.up)
    assert.are.equal(1, q.group)
    assert.are.equal(1, q.class)
    assert.are.equal(2, q.together)
    assert.are.equal(3, q.burst)
    assert.are.same({ [2001] = true, [2002] = true }, q.accepted)
    local week = addon.db.global.self.doomsday.weeks[ns.Doomsday.week(ns.DoomsdayTracker.today())]
    assert.are.equal(2, week.quests2.together)
  end)
end)
