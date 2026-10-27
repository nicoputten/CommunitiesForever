local net = require("net")
local helpers = require("helpers")

-- CF-36: the search box in the Friends tab, on a real window with synced people (end-to-end harness).
describe("smart filter in the Friends tab (CF-36)", function()
  local world, ns

  before_each(function()
    world = net.new()
    world:person({ key = "A", name = "Ada Example", guid = "Player-1-0000A001", battleTag = "Ada#1001",
                   classFile = "MAGE", classID = 8, level = 20, gameAccountID = 101, friends = { "B", "C" } })
    world:person({ key = "B", name = "Bob Example", guid = "Player-1-0000B001", battleTag = "Bob#2002",
                   classFile = "ROGUE", classID = 4, level = 22, gameAccountID = 102, friends = { "A" } })
    world:person({ key = "C", name = "Cy Example", guid = "Player-1-0000C001", battleTag = "Cy#3003",
                   classFile = "PRIEST", classID = 5, level = 30, gameAccountID = 103, friends = { "A" } })
    world:login("A")
    world:login("B")
    world:login("C")
    world:settle()
    world:with("A", function(c)
      ns = c.ns
      ns.MainFrame.toggle()
    end)
  end)

  after_each(function()
    world:shutdown()
  end)

  local function tab() return helpers.friendsTab(ns) end

  local function people()
    local list = tab().paths("group")
    table.sort(list)
    return list
  end

  local function type_(text)
    world:with("A", function() tab().type(text) end)
  end

  it("shows only people with a matching character, and how many of all", function()
    assert.are.same({ "Ada#1001", "Bob#2002", "Cy#3003" }, people())
    type_("rogue")
    assert.are.same({ "Bob#2002" }, people())
    assert.are.equal("1 of 3", ns.FriendsTab.countText())
    type_("20-25")
    assert.are.same({ "Ada#1001", "Bob#2002" }, people())
    type_("priest 30")
    assert.are.same({ "Cy#3003" }, people())
  end)

  it("says when nothing matches, and shows everyone again when cleared", function()
    type_("paladin")
    assert.are.same({}, people())
    type_("")
    assert.are.same({ "Ada#1001", "Bob#2002", "Cy#3003" }, people())
    assert.are.equal("", ns.FriendsTab.countText())
    assert.is_false(tab().has("No character matches"))
  end)

  it("says so on the card when nothing matches", function()
    type_("paladin")
    assert.is_true(tab().has('No character matches "paladin".'))
  end)

  it("sits above the list in the Friends tab and keeps its text across tab switches", function()
    type_("rogue")
    world:with("A", function()
      ns.MainFrame.selectTab("activity")
      assert.is_false(ns.FriendsTab.searchBox():GetParent():GetParent().shown) -- the tab is hidden
      ns.MainFrame.selectTab("friends")
    end)
    assert.are.equal("rogue", ns.FriendsTab.searchBox():GetText())
    assert.are.same({ "Bob#2002" }, people())
  end)

  it("unfolds matches, then puts the groups back and clears on close", function()
    local status = world.clients.A.addon.db.global.settings.tree
    status.groups["Bob#2002"] = false -- folded by the player
    type_("rogue")
    assert.is_true(status.groups["Bob#2002"])
    world:with("A", function() ns.MainFrame.toggle() end) -- close
    assert.are.equal("", ns.MainFrame.filterText())
    assert.is_false(status.groups["Bob#2002"])
    world:with("A", function() ns.MainFrame.toggle() end) -- open again
    assert.are.equal("", ns.FriendsTab.searchBox():GetText())
  end)
end)
