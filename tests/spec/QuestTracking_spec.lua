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
    state = wowapi.install()
    state.questLog = questLog()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
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

  local function treeWidget()
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "TreeGroup" then return w end
    end
  end

  local function detailText()
    local texts = {}
    local function walk(widget)
      for _, child in ipairs(widget.children) do
        if child.text then texts[#texts + 1] = child.text end
        walk(child)
      end
    end
    walk(treeWidget())
    return table.concat(texts, "\n")
  end

  local function treeChild(groupValue, guid)
    for _, node in ipairs(treeWidget().tree) do
      if node.value == groupValue then
        for _, c in ipairs(node.children) do
          if c.value == guid then return c end
        end
      end
    end
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
    treeWidget():SelectByPath(friendTag, friendGuid)
    local text = detailText()
    assert.is_truthy(text:find("Shared quests (2)", 1, true))
    local dungeonAt = text:find("Blackfathom Deeps", 1, true)
    local zoneAt = text:find("Durotar|r", 1, true)
    assert.is_truthy(dungeonAt and zoneAt and dungeonAt < zoneAt)
    assert.is_truthy(text:find("|A:Dungeon:14:14|a", 1, true))
    assert.is_truthy(text:find("Quest One", 1, true))
    assert.is_falsy(text:find("Not mine", 1, true))
    assert.is_truthy(treeChild(friendTag, friendGuid).text:find("|A:Dungeon:14:14|a", 1, true))
  end)

  it("shows at most five quests, then +N more", function()
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
    treeWidget():SelectByPath(friendTag, friendGuid)
    local text = detailText()
    assert.is_truthy(text:find("Shared quests (7)", 1, true))
    assert.is_truthy(text:find("+2 more", 1, true))
    assert.is_falsy(text:find("Shared 6", 1, true))
  end)

  it("says so when nothing is shared, and has no section on own characters", function()
    load()
    friendQuests({ [9999] = { title = "Not mine", area = "Durotar", dungeon = false } })
    ns.MainFrame.toggle()
    treeWidget():SelectByPath(friendTag, friendGuid)
    assert.is_truthy(detailText():find("No shared quests.", 1, true))
    assert.is_falsy(treeChild(friendTag, friendGuid).text:find("Dungeon", 1, true))

    treeWidget():SelectByPath(myTag, myGuid)
    assert.is_falsy(detailText():find("Shared quests", 1, true))
  end)

  it("adds a fake friend with hidden /cf debugon, in the window only", function()
    load()
    local people = addon.db.global.people
    ns.MainFrame.toggle()
    addon:OnSlashCommand("debugon")
    treeWidget():SelectByPath(ns.Debug.BATTLE_TAG, ns.Debug.GUID)
    local text = detailText()
    assert.is_truthy(text:find("Debug Character", 1, true))
    assert.is_truthy(text:find("Shared quests (4)", 1, true)) -- 3 copied from your log + the fake dungeon quest
    assert.is_truthy(text:find("Debug: Into the Deeps", 1, true))
    assert.is_truthy(treeChild(ns.Debug.BATTLE_TAG, ns.Debug.GUID).text:find("|A:Dungeon:14:14|a", 1, true))

    -- Nothing stored or synced.
    assert.are.equal(people, addon.db.global.people)
    assert.is_nil(people[ns.Debug.BATTLE_TAG])
    assert.is_nil(me().quests[ns.Debug.DUNGEON_QUEST_ID])
    assert.is_nil(ns.Merge.outgoingRecord(addon.db.global.self).chars[myGuid].quests[ns.Debug.DUNGEON_QUEST_ID])

    addon:OnSlashCommand("debugoff")
    assert.is_nil(treeChild(ns.Debug.BATTLE_TAG, ns.Debug.GUID))
  end)

  it("falls back to a text badge without the dungeon atlas", function()
    load()
    state.atlases = {}
    friendQuests({ [2001] = { title = "Dungeon Quest", area = "Blackfathom Deeps", dungeon = true } })
    ns.MainFrame.toggle()
    treeWidget():SelectByPath(friendTag, friendGuid)
    assert.is_truthy(detailText():find("[D]", 1, true))
  end)
end)
