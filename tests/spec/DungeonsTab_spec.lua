local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Dungeons tab (CF-24)", function()
  local state, ns, addon
  local CLUB = "23125681"

  local function load(level)
    state = wowapi.install()
    state.player.level = level or 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = level or 20 end
    for _, f in ipairs(state.friends) do
      for _, g in ipairs(f.gameAccounts) do g.characterLevel = level or 20 end
    end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    -- No setup wizard or Community tab prompt in the way (CF-26).
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    addon:OnEnable()
  end

  local function settle()
    for _ = 1, 50 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  local function window()
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "Frame" and w.title == "CommunitiesForever" then return w end
    end
  end

  local function walk(widget, visit)
    for _, child in ipairs(widget.children) do
      visit(child)
      walk(child, visit)
    end
  end

  local function text()
    local out = {}
    walk(window(), function(w) if w.text then out[#out + 1] = w.text end end)
    return table.concat(out, "\n")
  end

  local function find(widgetType, label)
    local found
    walk(window(), function(w)
      if not found and w.type == widgetType and (w.text == label or w.label == label) then found = w end
    end)
    return assert(found, "no " .. widgetType .. " " .. label)
  end

  local function dungeonTree()
    local found
    walk(window(), function(w) if w.type == "TreeGroup" then found = w end end)
    return found
  end

  local function open()
    settle()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("lists the dungeons that fit your characters and suggests a group for the first", function()
    load(20)
    open()
    local values = {}
    for _, node in ipairs(dungeonTree().tree) do values[#values + 1] = node.value end
    assert.are.same({ "dm", "wc" }, values) -- both 2 people; then by level, then name
    local all = text()
    assert.is_truthy(all:find("The Deadmines  |cffa0a0a0levels 17 to 26|r", 1, true))
    assert.is_truthy(all:find("Suggested group", 1, true))
    assert.is_falsy(all:find("Also in range", 1, true)) -- nobody else
    assert.is_falsy(all:find("Planned", 1, true)) -- no calendar event
    find("EditBox", "The Deadmines") -- the title to copy: just the dungeon name
    local edits = 0
    walk(window(), function(w) if w.type == "EditBox" then edits = edits + 1 end end)
    assert.are.equal(1, edits) -- no group field (CF-24 feedback)
  end)

  it("shows your other characters in range on one line under yours", function()
    load(20)
    addon.db.global.self.chars["Player-1-ALT"] = { guid = "Player-1-ALT", name = "Alt Example", level = 22,
                                                   classFile = "ROGUE" }
    state.clubMembers[CLUB][3] = { memberId = 3, guid = "Player-1-ALT", name = "Alt Example", classID = 4,
                                   level = 22, presence = 3, clubType = 1 }
    wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
    open()
    assert.is_truthy(text():find("or Alt Example 22", 1, true))
    assert.is_falsy(text():find("Also in range", 1, true))
  end)

  it("puts runs planned in the next 3 days on top, with sign-ups, and counts them on the tab", function()
    load(20)
    open()
    state.calendarEvents[0] = {
      [20] = { { title = "Deadmines run", calendarType = "COMMUNITY_EVENT", inviteStatus = 6,
                 startTime = { year = 2026, month = 10, monthDay = 20, weekday = 3, hour = 20, minute = 0 } } },
      [24] = { { title = "Wailing Caverns", calendarType = "COMMUNITY_EVENT",
                 startTime = { year = 2026, month = 10, monthDay = 24, weekday = 7, hour = 19, minute = 0 } } },
    }
    state.calendarInvites["0:20:1"] = { 6, 6, 3, 8, 2 }
    wowapi.fireEvent(state, "CALENDAR_UPDATE_EVENT_LIST")
    assert.are.same({ { 0, 20, 1 } }, state.calendarOpenedEvents) -- only the planned run is opened
    wowapi.fireEvent(state, "CALENDAR_OPEN_EVENT", "COMMUNITY_EVENT")
    settle()
    local values = {}
    for _, node in ipairs(dungeonTree().tree) do values[#values + 1] = node.value end
    assert.are.same({ "header:planned", "planned:1", "header:range", "dm", "wc" }, values)
    assert.is_truthy(dungeonTree().tree[2].text:find("Tue 20:00 \194\183 3", 1, true))
    assert.is_truthy(text():find("|cffffd100Dungeons (1)|r", 1, true))
    dungeonTree():SelectByValue("planned:1")
    assert.is_truthy(text():find("Tue 20 Oct, 20:00 \194\183 Deadmines run \194\183 3 signed up \194\183 +1 tentative"
      .. " \194\183 you signed up", 1, true))
    dungeonTree():SelectByValue("wc") -- 6 days ahead: in the detail, not planned in the list
    assert.is_truthy(text():find("Sat 24 Oct, 19:00 \194\183 Wailing Caverns", 1, true))
  end)

  it("lists a planned run for a dungeon none of your characters fits, greyed", function()
    load(20)
    open()
    state.calendarEvents[0] = { [19] = { { title = "Stratholme", calendarType = "COMMUNITY_EVENT",
      startTime = { year = 2026, month = 10, monthDay = 19, weekday = 2, hour = 20, minute = 0 } } } }
    wowapi.fireEvent(state, "CALENDAR_UPDATE_EVENT_LIST")
    settle() -- no CALENDAR_OPEN_EVENT: the sign-ups time out
    assert.are.equal("|cffa0a0a0Stratholme|r  |cff40c040Mon 20:00|r", dungeonTree().tree[2].text)
    dungeonTree():SelectByValue("planned:1")
    assert.is_truthy(text():find("None of your characters is in range.", 1, true))
  end)

  it("opens Blizzard's calendar, or says how when it can't", function()
    load(20)
    open()
    find("Button", "Open calendar"):Fire("OnClick")
    assert.is_true(state.calendarToggled)
    _G.ToggleCalendar = nil
    state.printed = {}
    find("Button", "Open calendar"):Fire("OnClick")
    assert.is_truthy(state.printed[1]:find("date button next to the minimap", 1, true))
  end)

  it("remembers the selected dungeon", function()
    load(20)
    open()
    dungeonTree():SelectByValue("wc")
    ns.MainFrame.selectTab("friends")
    ns.MainFrame.selectTab("dungeons")
    assert.is_truthy(text():find("Wailing Caverns  |cffa0a0a0levels 17 to 24|r", 1, true))
  end)

  it("explains when no character is in a dungeon's level range", function()
    load(11)
    open()
    assert.is_truthy(text():find("None of your characters is in a dungeon's level range yet", 1, true))
  end)
end)
