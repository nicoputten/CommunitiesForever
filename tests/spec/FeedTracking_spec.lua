local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("activity feed (CF-22)", function()
  local state, ns, addon
  local TODAY = 20744 -- mock realm date 2026-10-18
  local myGuid, friendTag, friendGuid

  local function load()
    state, ns, addon = helpers.client({ setup = function(s)
      s.questLog = {
        { isHeader = true, title = "Westfall" },
        { questID = 101, title = "Quest A" },
        { questID = 102, title = "Quest B" },
      }
    end })
    -- The mock's first community member is the player, the second an online Battle.net friend.
    myGuid = state.clubMembers["23125681"][1].guid
    friendGuid = state.clubMembers["23125681"][2].guid
    friendTag = state.friends[1].battleTag
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function mine() return addon.db.global.self.feed[TODAY][myGuid] end

  -- CF-41: the native Activity tab.
  local function activityText() return helpers.activityTab(ns).text() end
  local function click(prefix) helpers.activityTab(ns).click(prefix) end

  after_each(function()
    wowapi.uninstall()
  end)

  it("records level-ups, new profession ranks and turned-in quests of your character", function()
    load()
    wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
    state.player.professionInfo[10][4] = 225 -- Mining: trained Expert
    wowapi.fireEvent(state, "SKILL_LINES_CHANGED")
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0)
    table.remove(state.questLog, 2)
    settle()
    assert.are.equal(11, mine().levelFrom)
    assert.are.equal(12, mine().levelTo)
    assert.are.same({ Mining = "Expert" }, mine().ranks)
    assert.are.same({ Westfall = 1 }, mine().quests)
  end)

  it("counts a quest the stored log does not know under the zone you are in, else Other", function()
    load()
    state.zone = "Shadowfang Keep"
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 999, 500, 0)
    state.zone = nil -- right after a loading screen
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 998, 500, 0)
    settle()
    assert.are.same({ ["Shadowfang Keep"] = 1, Other = 1 }, mine().quests)
  end)

  it("bumps the version for a feed-only change once, after 60 s", function()
    load()
    settle()
    local before = addon.db.global.self.version
    state.serverTime = 2000
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0) -- log not changed yet: no snapshot change
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 102, 500, 0)
    assert.are.equal(before, addon.db.global.self.version)
    settle()
    assert.is_true(addon.db.global.self.version > before)
    local after = addon.db.global.self.version
    settle()
    assert.are.equal(after, addon.db.global.self.version)
  end)

  it("always sends the feed with the record (CF-58: no sharing setting)", function()
    load()
    addon.db.global.settings.shareActivity = false -- stored by a released version: ignored
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0)
    assert.is_truthy(ns.Merge.outgoingRecord(addon.db.global.self).feed)
    assert.is_nil(ns.Settings.options().args.shareActivity)
  end)

  it("shows one entry per person per day in the Activity tab, expandable (CF-41)", function()
    load()
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0)
    ns.Merge.store(addon.db.global.people, { t = "RECORD", bt = friendTag, displayName = "Friend", version = 5,
      chars = { [friendGuid] = { guid = friendGuid, name = "Friend Char", classFile = "MAGE", level = 11 } },
      feed = { [TODAY] = {
        [friendGuid] = { name = "Friend Char", classFile = "MAGE", at = 900, levelFrom = 12, levelTo = 14,
                         quests = { Durotar = 4, Barrens = 2 }, ranks = { Mining = "Journeyman" },
                         learned = { Alchemy = true } },
        ["Player-0-ALT00001"] = { name = "Friend Alt", classFile = "WARRIOR", at = 800, quests = { Durotar = 1 } },
      } } }, 1000, friendTag)
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    local text = activityText()
    assert.are.equal("activity", ns.MainFrame.tabs().active) -- CF-39: the kit tabs mark the active one
    assert.is_truthy(text:find("\nToday\n", 1, true))
    -- CF-62: the character first, then the friend; a summary right of the chips; the end of the day in an ⓘ.
    assert.is_truthy(text:find("\nFriend Char \194\183 Friend and 1 more character\n", 1, true))
    local summary = ns.ActivityTab.summary()
    assert.is_truthy(summary:find("^Today: %d friends? active \194\183 %d+ quests? \194\183 %d+ levels?$"), summary)
    assert.is_truthy(table.concat(ns.ActivityTab.tips(), "\n"):find("That's all for today", 1, true))
    assert.is_truthy(text:find("\n12 \226\134\146 14\n", 1, true)) -- the LEVEL UP chip
    assert.is_truthy(text:find("\nMining reached Journeyman\n", 1, true))
    assert.is_truthy(text:find("\nlearned Alchemy\n", 1, true))
    assert.is_truthy(text:find("\nDurotar\n", 1, true) and text:find("\nBarrens\n", 1, true)) -- zone pills
    assert.is_truthy(text:find("\n\194\183 6 quests done\n", 1, true))
    assert.is_truthy(text:find("\n\194\183 1 quest done\n", 1, true)) -- your own entry
    assert.is_truthy(text:find("\nShow all (1)\n", 1, true))
    assert.is_falsy(text:find("Friend Alt", 1, true))

    click("Show all")
    text = activityText()
    assert.is_truthy(text:find("\non Friend Alt\n", 1, true))
    assert.is_truthy(text:find("\nShow less\n", 1, true))
    click("Show less")
    assert.is_falsy(activityText():find("Friend Alt", 1, true))

    -- The footer: how long it keeps (CF-61: no note on who shares).
    local window = ns.MainFrame.window()
    assert.are.equal("", window.footerText.text)
    assert.are.equal("Keeps 7 days", window.footerRightText.text)

    ns.MainFrame.selectTab("friends")
    assert.are.equal("", window.footerRightText.text)
  end)

  it("filters with the chips, whole entries, and starts at All after closing (CF-41)", function()
    load()
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0) -- your own entry: questing only
    ns.Merge.store(addon.db.global.people, { t = "RECORD", bt = friendTag, displayName = "Friend", version = 5,
      chars = { [friendGuid] = { guid = friendGuid, name = "Friend Char", classFile = "MAGE", level = 11 } },
      feed = { [TODAY] = { [friendGuid] = { name = "Friend Char", classFile = "MAGE", at = 900, levelFrom = 12,
                                            levelTo = 14, quests = { Durotar = 4 } } } } }, 1000, friendTag)
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    local chips = ns.ActivityTab.chips()
    assert.is_true(chips.all.active)
    chips.levels:RunScript("OnClick")
    assert.is_true(chips.levels.active)
    local text = activityText()
    assert.is_truthy(text:find("\nFriend Char \194\183 Friend\n", 1, true))
    assert.is_truthy(text:find("\nDurotar\n", 1, true)) -- the whole entry, questing too
    assert.is_falsy(text:find("1 quest done", 1, true)) -- your entry has no level-up
    chips.together:RunScript("OnClick")
    assert.is_truthy(activityText():find("Nothing of this kind in the last 7 days.", 1, true))

    ns.MainFrame.toggle() -- close
    ns.MainFrame.toggle()
    assert.are.equal("all", ns.ActivityTab.filter())
  end)

  it("gives the hidden debug friend a sample feed", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    addon:OnSlashCommand("debugon")
    local text = activityText()
    assert.is_truthy(text:find("\n27 \226\134\146 30\n", 1, true))
    assert.is_truthy(text:find("\nEngineering reached Expert\n", 1, true))
    assert.is_truthy(text:find("\nShow all (", 1, true)) -- the alt adds a raid, battlegrounds and quests (CF-23)
    -- CF-23: the dungeon runs with your current character show as one shared entry.
    assert.is_truthy(text:find(" and Debug Friend together\n", 1, true))
    assert.is_truthy(text:find("\nran Blackfathom Deeps \195\1512\n", 1, true))
    assert.is_truthy(text:find("\nYesterday\n", 1, true))
    assert.is_truthy(text:find("\n19 \226\134\146 21\n", 1, true))
    assert.is_nil(addon.db.global.people[ns.Debug.BATTLE_TAG]) -- view only
  end)

  it("says so when there is no activity yet", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    assert.is_truthy(activityText():find("No activity yet.", 1, true))
  end)
end)
