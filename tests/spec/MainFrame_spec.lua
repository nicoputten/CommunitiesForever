local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("MainFrame", function()
  local state, ns, addon

  local SJAAK = "Sjaakovich#2232"
  local GARRAKA = "Player-4619-01789956"

  local function load(storedClubId)
    state = wowapi.install()
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = storedClubId
    addon:OnEnable()
  end

  local function frame() return ns.MainFrame.window() end -- CF-39: the kit window
  local function tab() return helpers.friendsTab(ns) end -- CF-40: the native Friends tab
  local function hasText(text) return tab().has(text) end
  local function select(path) ns.FriendsTab.select(path) end

  after_each(function()
    wowapi.uninstall()
  end)

  it("opens with /cf and closes with /cf, reusing the window", function()
    load("23125681")
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal("Forever Friends", frame().titleText.text) -- CF-39: the community in the title
    local window = frame()
    state.slash.cf("")
    assert.is_false(ns.MainFrame.isShown())
    state.slash.cf("")
    assert.is_true(ns.MainFrame.isShown())
    assert.are.equal(window, frame()) -- reused
  end)

  it("stores window and list state in settings", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.equal(addon.db.global.settings.window, frame().status)
    assert.are.equal(SJAAK, addon.db.global.settings.tree.selected) -- the AceGUI tree's keys (rule 8)
  end)

  it("lists people with their online dot and count, and class-colored characters (CF-40)", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.same({ SJAAK, "Vestras#1000" }, tab().paths("group"))
    local sjaak = tab().row(SJAAK)
    assert.are.equal("Sjaakovich", sjaak.name:GetText())
    assert.are.equal("1", sjaak.count:GetText())
    assert.are.same({ ns.Theme.color("online") }, sjaak.dot.vertexColor)
    local garraka = tab().row(SJAAK .. "\001" .. GARRAKA)
    assert.are.equal("Garraka Doombringer", garraka.name:GetText())
    local r, g, b = ns.Kit.classColor("MAGE")
    assert.are.same({ r, g, b, 1 }, garraka.name.textColor)
    assert.is_true(garraka.portrait.online) -- playing it
    assert.are.equal("Vestras (you)", tab().row("Vestras#1000").name:GetText())
    assert.is_false(tab().row("Vestras#1000").mark.shown) -- no addon mark on your own row
    -- CF-40: the footer: sync state left, the hint right.
    assert.is_truthy(frame().footerText.text:find("1 character from 1 friend", 1, true))
    assert.is_truthy(frame().footerRightText.text:find("/cf to open", 1, true))
  end)

  it("shortens long character names in the list but keeps the level", function()
    load("23125681")
    state.clubMembers["23125681"][2].name = "Garrakathorian Doombringerson"
    wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", "23125681", 2)
    wowapi.runTimers(state)
    ns.MainFrame.toggle()
    local row = tab().row(SJAAK .. "\001" .. GARRAKA)
    assert.are.equal(ns.Format.truncate("Garrakathorian Doombringerson", 24), row.name:GetText())
    assert.are.equal("11", row.level:GetText())
  end)

  it("shows alts outside the community tagged (CF-17)", function()
    load("23125681")
    addon.db.global.self.chars["Player-4619-0000OLD1"] = { guid = "Player-4619-0000OLD1", name = "Old Alt",
                                                           classFile = "MAGE", level = 7, updatedAt = 900 }
    ns.MainFrame.toggle()
    assert.is_not_nil(tab().row("Vestras#1000\001Player-4619-0000OLD1"))
    select("Vestras#1000\001Player-4619-0000OLD1")
    assert.is_true(hasText("not in community"))
    select("Vestras#1000")
    assert.is_true(hasText("not in community"))
  end)

  it("unfolds new people, folds with the arrow and remembers it", function()
    load("23125681")
    ns.MainFrame.toggle()
    local groups = addon.db.global.settings.tree.groups
    assert.is_nil(groups[SJAAK]) -- new: unfolded
    assert.is_not_nil(tab().row(SJAAK .. "\001" .. GARRAKA))
    tab().click(tab().row(SJAAK).arrow)
    assert.is_false(groups[SJAAK])
    assert.is_nil(tab().row(SJAAK .. "\001" .. GARRAKA))
    ns.MainFrame.render()
    assert.is_nil(tab().row(SJAAK .. "\001" .. GARRAKA))
    tab().click(tab().row(SJAAK).arrow)
    assert.is_true(groups[SJAAK])
    assert.is_not_nil(tab().row(SJAAK .. "\001" .. GARRAKA))
  end)

  it("selects the first person and shows the person card; clicking a name opens it", function()
    load("23125681")
    ns.MainFrame.toggle()
    assert.are.equal(SJAAK, addon.db.global.settings.tree.selected)
    assert.is_true(hasText("Sjaakovich"))
    assert.is_true(hasText("Online on Garraka Doombringer"))
    assert.is_true(hasText("Characters"))
    tab().click(tab().row("Vestras#1000"))
    assert.are.equal("Vestras#1000", addon.db.global.settings.tree.selected)
    assert.is_true(tab().row("Vestras#1000").selectedBg.shown)
  end)

  it("shows the character card with subtitle, tiles, skill bars and talents (CF-40)", function()
    load("23125681")
    ns.MainFrame.toggle()
    tab().click(tab().row("Vestras#1000\001Player-4619-01627852"))
    assert.is_true(tab().row("Vestras#1000\001Player-4619-01627852").selected)
    assert.is_true(hasText("Ves Doombringer"))
    assert.is_true(hasText("Paladin \194\183 your character \194\183 online in Durotar"))
    assert.is_true(hasText("LEVEL"))
    assert.is_true(hasText("ITEM LEVEL"))
    assert.is_true(hasText("ROLE"))
    assert.is_true(hasText("Talents"))
    assert.is_true(hasText("No talent data yet."))
    assert.is_true(hasText("Mining"))
    assert.is_true(hasText("64 / 150"))
    assert.is_true(hasText("Cooking"))
    assert.is_false(hasText("Quests you share")) -- own character
  end)

  it("opens a character from the person card list", function()
    load("23125681")
    ns.MainFrame.toggle()
    tab().click(tab().cardLines()[1])
    assert.are.equal(SJAAK .. "\001" .. GARRAKA, addon.db.global.settings.tree.selected)
    assert.is_true(hasText("LEVEL"))
  end)

  it("keeps the selection across refreshes and falls back when it disappears", function()
    load("23125681")
    ns.MainFrame.toggle()
    select(SJAAK .. "\001" .. GARRAKA)
    ns.MainFrame.render()
    assert.are.equal(SJAAK .. "\001" .. GARRAKA, addon.db.global.settings.tree.selected)

    table.remove(state.friends, 1) -- Sjaak is no longer a friend: Garraka becomes Unlinked
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    wowapi.runTimers(state)
    assert.are.equal("Vestras#1000", addon.db.global.settings.tree.selected)
  end)

  it("explains on a character outside the community, and keeps syncing", function()
    load("23125681")
    state.clubs = { { clubId = "777", name = "Other Friends", clubType = 1 } } -- this alt is not a member
    wowapi.fireEvent(state, "CLUB_UPDATED", "777")
    ns.MainFrame.toggle()
    assert.are.same({}, tab().rows())
    assert.matches("^Your account has characters in Forever Friends, but Ves Doombringer isn't a member",
      tab().texts()[1])
    assert.are.equal("23125681", addon.db.global.settings.clubId)
  end)

  it("shows the empty state without a community", function()
    load(nil)
    ns.MainFrame.toggle()
    assert.are.same({}, tab().rows())
    assert.are.same({ "Select a community in settings (/cf settings)." }, tab().texts())
    assert.are.equal("", frame().footerText.text)
  end)

  it("hints when no friend is linked yet", function()
    load("23125681")
    table.remove(state.friends, 1)
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    ns.MainFrame.toggle()
    assert.is_true(hasText("No linked friends yet."))
  end)

  it("refreshes while shown when data changes, debounced", function()
    load("23125681")
    ns.MainFrame.toggle()
    state.friends[1].gameAccounts[1].isOnline = false
    wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
    wowapi.runTimers(state) -- presence refresh, then window refresh
    wowapi.runTimers(state)
    assert.are.same({ ns.Theme.color("faint") }, tab().row(SJAAK).dot.vertexColor)
  end)

  it("does not render while hidden", function()
    load("23125681")
    wowapi.runTimers(state) -- the login timers (CF-26 setup wizard) first
    ns.MainFrame.toggle()
    ns.MainFrame.toggle()
    local before = #tab().rows()
    ns.CommunitySelection.select(nil)
    wowapi.runTimers(state)
    assert.are.equal(before, #tab().rows())
  end)

  it("shows only the active tab: Friends, Activity or Dungeons (CF-40 to CF-42)", function()
    load("23125681")
    ns.MainFrame.toggle()
    local friends = ns.FriendsTab.searchBox():GetParent():GetParent()
    local activity = ns.ActivityTab.chips().all:GetParent():GetParent()
    local dungeons = ns.DungeonsTab.titleBox():GetParent():GetParent():GetParent()
    local function shown() return { friends.shown, activity.shown, dungeons.shown } end
    assert.are.same({ true, false, false }, shown())
    ns.MainFrame.selectTab("activity")
    assert.are.same({ false, true, false }, shown())
    ns.MainFrame.selectTab("dungeons")
    assert.are.same({ false, false, true }, shown())
    ns.MainFrame.selectTab("friends")
    assert.are.same({ true, false, false }, shown())
  end)

  describe("minimap button", function()
    it("registers a launcher: left-click toggles, right-click opens settings", function()
      load("23125681")
      local launcher = state.ldbObjects.CommunitiesForever
      assert.are.equal("launcher", launcher.type)
      launcher.OnClick(nil, "LeftButton")
      assert.is_true(ns.MainFrame.isShown())
      launcher.OnClick(nil, "RightButton")
      assert.is_true(ns.SettingsWindow.isShown()) -- CF-43
    end)

    -- CF-33: who is online, display name left, character and level right.
    local function tooltip()
      local lines = {}
      local tip = {
        AddLine = function(_, text) lines[#lines + 1] = { text } end,
        AddDoubleLine = function(_, left, right) lines[#lines + 1] = { left, right } end,
      }
      state.ldbObjects.CommunitiesForever.OnTooltipShow(tip)
      return lines
    end

    it("lists who is online in the tooltip", function()
      load("23125681")
      local list = ns.Format.onlineList(ns.ViewModel.build(addon))
      assert.is_true(#list.entries > 0, "the mock has a friend online")
      local lines = tooltip()
      local first = list.entries[1]
      assert.are.equal(first.displayName, lines[2][1])
      assert.is_truthy(lines[2][2]:find(first.name, 1, true))
      assert.is_truthy(lines[2][2]:find(" " .. first.level .. "$"))
      assert.are.equal("Left-click: open window", lines[#lines - 1][1])
    end)

    it("says nobody is online when nobody is", function()
      state = wowapi.install()
      state.friends = {}
      ns = helpers.loadAddon()
      addon = state.addon
      addon:OnInitialize()
      addon.db.global.settings.clubId = "23125681"
      addon:OnEnable()
      assert.are.equal(ns.Format.NOBODY_ONLINE, tooltip()[2][1])
    end)

    it("can be hidden and shown from settings", function()
      load("23125681")
      local option = ns.Settings.options().args.minimap
      assert.is_true(option.get())
      option.set({}, false)
      assert.is_true(addon.db.global.settings.minimap.hide)
      assert.is_false(state.minimapIcon.shown)
      option.set({}, true)
      assert.is_nil(addon.db.global.settings.minimap.hide)
      assert.is_true(state.minimapIcon.shown)
    end)
  end)
end)
