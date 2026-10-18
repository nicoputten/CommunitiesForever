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
    assert.is_truthy(all:find("you", 1, true))
    assert.are.equal("The Deadmines run", find("EditBox", "Event title").text)
    assert.is_truthy(find("EditBox", "Group").text:find(state.player.name, 1, true))
  end)

  it("asks for the calendar once and shows events that mention the dungeon", function()
    load(20)
    open()
    assert.are.equal(1, state.calendarOpened)
    assert.is_truthy(text():find("No upcoming calendar event mentions The Deadmines.", 1, true))
    state.calendarEvents[0] = { [24] = { { title = "Deadmines run", calendarType = "COMMUNITY_EVENT",
      startTime = { year = 2026, month = 10, monthDay = 24, weekday = 7, hour = 20, minute = 0 },
      inviteStatus = 6 } } }
    wowapi.fireEvent(state, "CALENDAR_UPDATE_EVENT_LIST")
    settle()
    assert.is_truthy(text():find("Sat 24 Oct, 20:00  Deadmines run|cffa0a0a0", 1, true))
    assert.is_truthy(text():find("you signed up", 1, true))
    ns.MainFrame.selectTab("friends")
    ns.MainFrame.selectTab("dungeons")
    assert.are.equal(1, state.calendarOpened)
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
