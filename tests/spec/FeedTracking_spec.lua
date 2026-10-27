local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("activity feed (CF-22)", function()
  local state, ns, addon
  local TODAY = 20744 -- mock realm date 2026-10-18
  local myGuid, friendTag, friendGuid

  local function load()
    state = wowapi.install()
    state.questLog = {
      { isHeader = true, title = "Westfall" },
      { questID = 101, title = "Quest A" },
      { questID = 102, title = "Quest B" },
    }
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
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

  local DOT = " \194\183 "

  -- The main window's tab content (CF-39: an AceGUI root container in the kit window).
  local function tabs()
    for _, w in ipairs(state.guiWidgets) do
      if w.cfMainRoot then return w end
    end
  end

  local function texts(widget, out)
    out = out or {}
    for _, child in ipairs(widget.children) do
      if child.text then out[#out + 1] = child.text end
      texts(child, out)
    end
    return out
  end

  local function activityText()
    return table.concat(texts(tabs()), "\n")
  end

  local function click(pattern)
    local function walk(widget)
      for _, child in ipairs(widget.children) do
        if child.type == "InteractiveLabel" and child.text:find(pattern, 1, true) then return child end
        local found = walk(child)
        if found then return found end
      end
    end
    assert(walk(tabs()), "no clickable line with " .. pattern):Fire("OnClick")
  end

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

  it("sends the feed with the record unless sharing is off", function()
    load()
    wowapi.fireEvent(state, "QUEST_TURNED_IN", 101, 500, 0)
    assert.is_truthy(ns.Merge.outgoingRecord(addon.db.global.self, ns.FeedTracker.shared()).feed)
    local before = addon.db.global.self.version
    state.serverTime = 3000
    ns.Settings.options().args.shareActivity.set({}, false)
    assert.is_true(addon.db.global.self.version > before) -- friends get the record without the feed
    assert.is_false(ns.Merge.outgoingRecord(addon.db.global.self, ns.FeedTracker.shared()).feed) -- CF-28
    assert.is_truthy(addon.db.global.self.feed) -- still kept for your own window
  end)

  it("shows one line per person per day in the Activity tab, expandable", function()
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
    assert.is_truthy(text:find("Today", 1, true))
    assert.is_truthy(text:find("|cffffd100Friend|r |cffa0a0a0on|r |cff40c7ebFriend Char|r "
      .. "|cffa0a0a0and 1 more character|r", 1, true))
    assert.is_truthy(text:find("   12 to 14" .. DOT .. "Mining reached Journeyman" .. DOT .. "learned Alchemy   "
      .. "|cff6aa7ffShow all (2)|r", 1, true))
    assert.is_truthy(text:find("questing in Westfall (1)", 1, true)) -- your own line
    assert.is_falsy(text:find("Friend Alt", 1, true))

    click("Show all (2)")
    text = activityText()
    -- Expanded: one part per line, then the other character with its parts, then Show less.
    assert.is_truthy(text:find("\n   12 to 14\n   Mining reached Journeyman\n   learned Alchemy\n"
      .. "   questing in Durotar and Barrens (6)\n   |cffa0a0a0on|r ", 1, true))
    assert.is_truthy(text:find("Friend Alt", 1, true) and text:find("\n      questing in Durotar (1)\n", 1, true))
    assert.is_truthy(text:find("\n   |cff6aa7ffShow less|r", 1, true))
    click("Show less")
    assert.is_falsy(activityText():find("Friend Alt", 1, true))

    ns.MainFrame.selectTab("friends")
    assert.is_falsy(activityText():find("questing in", 1, true))
  end)

  it("turns off the tree's hover tooltips", function()
    load()
    ns.MainFrame.toggle()
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "TreeGroup" then assert.is_false(w.buttonTooltips) end
    end
  end)

  it("gives the hidden debug friend a sample feed", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    addon:OnSlashCommand("debugon")
    local text = activityText()
    assert.is_truthy(text:find("   27 to 30" .. DOT .. "Engineering reached Expert" .. DOT .. "learned Mining   "
      .. "|cff6aa7ffShow all (4)|r", 1, true)) -- the alt adds a raid, battlegrounds and quests (CF-23)
    -- CF-23: the dungeon runs with your current character show as one shared line.
    assert.is_truthy(text:find(" and Debug Friend|r |cffa0a0a0together|r", 1, true))
    assert.is_truthy(text:find("   ran Blackfathom Deeps \195\1512", 1, true))
    assert.is_truthy(text:find("Yesterday", 1, true))
    assert.is_truthy(text:find("reached 20", 1, true))
    assert.is_nil(addon.db.global.people[ns.Debug.BATTLE_TAG]) -- view only
  end)

  it("says so when there is no activity yet", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("activity")
    assert.is_truthy(activityText():find("No activity yet.", 1, true))
  end)
end)
