local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("shared quests in the window (CF-19)", function()
  local state, ns, addon
  local friendTag, friendGuid, myTag, myGuid

  local function questLog()
    return {
      { isHeader = true, title = "Durotar" },
      { questID = 1001, title = "Quest One" },
      { questID = 1002, title = "Quest Two" },
      { isHeader = true, title = "Blackfathom Deeps" },
      { questID = 2001, title = "Dungeon Quest", tagID = 81 },
    }
  end

  local function load()
    state, ns, addon = helpers.client({ setup = function(s)
      s.questLog = questLog()
    end })
    -- The mock's first community member is the player, the second an online Battle.net friend.
    myGuid = state.clubMembers["23125681"][1].guid
    friendGuid = state.clubMembers["23125681"][2].guid
    friendTag = state.friends[1].battleTag
    myTag = addon.db.global.self.battleTag
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function me()
    return addon.db.global.self.chars[myGuid]
  end

  -- Gives the friend's character a quest log, as a synced record would.
  local function friendQuests(quests)
    addon.db.global.people[friendTag] = { displayName = "Friend", version = 5, chars = {
      [friendGuid] = { guid = friendGuid, name = "Friend Char", classFile = "MAGE", level = 11, quests = quests },
    } }
  end

  -- CF-40: the native Friends tab.
  local function select(...) ns.FriendsTab.select(table.concat({ ... }, "\001")) end

  local function detailText() return table.concat(ns.FriendsTab.cardTexts(), "\n") end

  -- The list row of a character (its quest count: questCount, shown or not).
  local function treeChild(groupValue, guid) return helpers.friendsTab(ns).row(groupValue .. "\001" .. guid) end

  local function sharedCount(row) return row.questCount.shown and row.questCount:GetText() or nil end

  local function clickLabel(text)
    for _, link in ipairs(state.frames) do
      if link.shown and link.text and link.text.GetText and link.text:GetText() == text then
        return link:RunScript("OnClick")
      end
    end
    error("no link " .. text)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("stores the quest log of the current character on login", function()
    load()
    assert.are.same({ title = "Quest One", area = "Durotar", dungeon = false }, me().quests[1001])
    assert.is_true(me().quests[2001].dungeon)
  end)

  it("bumps the version only when the set of quests changes, debounced", function()
    load()
    local before = addon.db.global.self.version
    state.serverTime = 2000
    state.questLog[2].title = "Quest One (renamed)" -- not a new quest
    wowapi.fireEvent(state, "QUEST_LOG_UPDATE")
    settle()
    assert.are.equal(before, addon.db.global.self.version)

    state.serverTime = 3000
    table.insert(state.questLog, { questID = 1003, title = "Quest Three" })
    wowapi.fireEvent(state, "QUEST_ACCEPTED", 1003)
    assert.is_nil(me().quests[1003]) -- not yet
    settle()
    assert.is_truthy(me().quests[1003])
    assert.is_true(addon.db.global.self.version > before)
  end)

  it("keeps the quests when the log cannot be read for a moment", function()
    load()
    state.questLog = nil
    wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, true)
    assert.is_truthy(me().quests[1001])
  end)

  it("lists shared quests on a friend's character card, dungeons first", function()
    load()
    friendQuests({
      [1001] = { title = "Quest One", area = "Durotar", dungeon = false },
      [2001] = { title = "Dungeon Quest", area = "Blackfathom Deeps", dungeon = true },
      [9999] = { title = "Not mine", area = "Durotar", dungeon = false },
    })
    ns.MainFrame.toggle()
    select(friendTag, friendGuid)
    local text = detailText()
    assert.is_truthy(text:find("Quests you share", 1, true))
    assert.is_truthy(text:find("2 \194\183 grouped by where they are", 1, true))
    local dungeonAt = text:find("Blackfathom Deeps", 1, true)
    local zoneAt = text:find("\nDurotar\n", 1, true)
    assert.is_truthy(dungeonAt and zoneAt and dungeonAt < zoneAt)
    assert.is_truthy(text:find("DUNGEON", 1, true))
    assert.is_truthy(text:find("Quest One", 1, true))
    assert.is_falsy(text:find("Not mine", 1, true))
    assert.are.equal("2", sharedCount(treeChild(friendTag, friendGuid))) -- CF-40: the count in the list
  end)

  it("shows at most five quests, then Show all / Show fewer", function()
    load()
    local quests = {}
    for i = 1, 7 do
      state.questLog[#state.questLog + 1] = { questID = 3000 + i, title = "Shared " .. i }
      quests[3000 + i] = { title = "Shared " .. i, area = "Durotar", dungeon = false }
    end
    wowapi.fireEvent(state, "QUEST_LOG_UPDATE")
    settle()
    friendQuests(quests)
    ns.MainFrame.toggle()
    select(friendTag, friendGuid)
    local text = detailText()
    assert.is_truthy(text:find("7 \194\183 grouped", 1, true))
    assert.is_falsy(text:find("Shared 6", 1, true))

    clickLabel("Show all 7 \226\134\146")
    text = detailText()
    assert.is_truthy(text:find("Shared 6", 1, true))
    assert.is_truthy(text:find("Shared 7", 1, true))

    clickLabel("Show fewer")
    assert.is_falsy(detailText():find("Shared 6", 1, true))
  end)

  it("lists quests over all of a friend's characters on the person card", function()
    load()
    addon.db.global.people[friendTag] = { displayName = "Friend", version = 5, chars = {
      [friendGuid] = { guid = friendGuid, name = "Friend Char", classFile = "MAGE", level = 11,
                       quests = { [1001] = { title = "Quest One", area = "Durotar", dungeon = false } } },
      ["Player-0-ALT00001"] = { guid = "Player-0-ALT00001", name = "Friend Alt", classFile = "WARRIOR", level = 9,
                                quests = { [1001] = { title = "Quest One", area = "Durotar", dungeon = false },
                                           [1002] = { title = "Quest Two", area = "Durotar", dungeon = false } } },
    } }
    ns.MainFrame.toggle()
    select(friendTag)
    local text = detailText()
    assert.is_truthy(text:find("2 \194\183 grouped", 1, true))
    -- Quest One: both of their characters (the community member shows under its community name).
    assert.is_truthy(text:find("them|r Friend Alt, " .. state.clubMembers["23125681"][2].name, 1, true))
    assert.is_truthy(text:find("them|r Friend Alt |", 1, true)) -- Quest Two: only the alt

    select(myTag)
    assert.is_falsy(detailText():find("Quests you share", 1, true))
  end)

  it("ignores an empty quest log, except right after a turn-in or abandon", function()
    load()
    local before = addon.db.global.self.version
    state.serverTime = 2000
    state.questLog = {} -- not loaded yet
    wowapi.fireEvent(state, "QUEST_LOG_UPDATE")
    settle()
    assert.is_truthy(me().quests[1001])
    assert.are.equal(before, addon.db.global.self.version)

    wowapi.fireEvent(state, "QUEST_TURNED_IN", 1001)
    settle()
    assert.are.same({}, me().quests)
    assert.is_true(addon.db.global.self.version > before)
  end)

  it("says so when nothing is shared, and has no section on own characters", function()
    load()
    friendQuests({ [9999] = { title = "Not mine", area = "Durotar", dungeon = false } })
    ns.MainFrame.toggle()
    select(friendTag, friendGuid)
    assert.is_truthy(detailText():find("No shared quests.", 1, true))
    assert.is_nil(sharedCount(treeChild(friendTag, friendGuid)))

    select(myTag, myGuid)
    assert.is_falsy(detailText():find("Quests you share", 1, true))
  end)

  it("adds a fake friend with hidden /cf debugon, in the window only", function()
    load()
    local people = addon.db.global.people
    ns.MainFrame.toggle()
    addon:OnSlashCommand("debugon")
    select(ns.Debug.BATTLE_TAG, ns.Debug.GUID)
    local text = detailText()
    assert.is_truthy(text:find("Debug Character", 1, true))
    assert.is_truthy(text:find("4 \194\183 grouped", 1, true)) -- 3 copied from your log + the fake dungeon quest
    assert.is_truthy(text:find("Debug: Into the Deeps", 1, true))
    assert.are.equal("4", sharedCount(treeChild(ns.Debug.BATTLE_TAG, ns.Debug.GUID)))
    assert.is_truthy(text:find("Engineering", 1, true))
    assert.is_truthy(text:find("10 / 0 / 11", 1, true)) -- the talents header

    -- A second friend character sharing some of the same quests.
    select(ns.Debug.BATTLE_TAG, ns.Debug.ALT_GUID)
    text = detailText()
    assert.is_truthy(text:find("Debug Alt", 1, true))
    assert.is_truthy(text:find("3 \194\183 grouped", 1, true)) -- 2 copied + the fake dungeon quest
    assert.is_truthy(text:find("\nTank\n", 1, true)) -- the role tile

    -- Nothing stored or synced.
    assert.are.equal(people, addon.db.global.people)
    assert.is_nil(people[ns.Debug.BATTLE_TAG])
    assert.is_nil(me().quests[ns.Debug.DUNGEON_QUEST_ID])
    assert.is_nil(ns.Merge.outgoingRecord(addon.db.global.self).chars[myGuid].quests[ns.Debug.DUNGEON_QUEST_ID])

    addon:OnSlashCommand("debugoff")
    assert.is_nil(treeChild(ns.Debug.BATTLE_TAG, ns.Debug.GUID))
  end)
end)
