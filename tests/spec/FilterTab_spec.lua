local net = require("net")

-- CF-36: the search box in the Friends tab, on a real window with synced people (end-to-end harness).
describe("smart filter in the Friends tab (CF-36)", function()
  local world, ns, state

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
      ns, state = c.ns, c.state
      ns.MainFrame.toggle()
    end)
  end)

  after_each(function()
    world:shutdown()
  end)

  local function widget(widgetType, check)
    for _, w in ipairs(state.guiWidgets) do
      if w.type == widgetType and (not check or check(w)) then return w end
    end
  end

  local function searchBox() return widget("EditBox", function(w) return w.width == 180 end) end
  local function tree() return widget("TreeGroup") end

  local function people()
    local list = {}
    for _, node in ipairs(tree().tree or {}) do list[#list + 1] = node.value end
    table.sort(list)
    return list
  end

  local function type_(text)
    world:with("A", function() searchBox():Fire("OnTextChanged", text) end)
  end

  it("shows only people with a matching character, and how many of all", function()
    assert.are.same({ "Ada#1001", "Bob#2002", "Cy#3003" }, people())
    type_("rogue")
    assert.are.same({ "Bob#2002" }, people())
    assert.is_truthy(widget("Label", function(w) return w.width == 120 end).text:find("1 of 3", 1, true))
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
    assert.are.equal("", widget("Label", function(w) return w.width == 120 end).text)
  end)

  it("sits above the tree in the Friends tab and keeps its text across tab switches", function()
    assert.is_true(tree().fullHeight) -- the tree fills the tab below the search row
    type_("rogue")
    world:with("A", function()
      ns.MainFrame.selectTab("activity")
      ns.MainFrame.selectTab("friends")
    end)
    local boxes = 0
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "EditBox" and w.width == 180 and w.text == "rogue" then boxes = boxes + 1 end
    end
    assert.is_true(boxes >= 1, "the new search box shows the text")
    local trees = {}
    for _, w in ipairs(state.guiWidgets) do if w.type == "TreeGroup" then trees[#trees + 1] = w end end
    local nodes = trees[#trees].tree
    assert.are.equal(1, #nodes)
    assert.are.equal("Bob#2002", nodes[1].value)
  end)

  it("expands matches, then puts the groups back and clears on close", function()
    local status = world.clients.A.addon.db.global.settings.tree
    status.groups["Bob#2002"] = false -- collapsed by the player
    type_("rogue")
    assert.is_true(status.groups["Bob#2002"])
    world:with("A", function() ns.MainFrame.toggle() end) -- close
    assert.are.equal("", ns.MainFrame.filterText())
    assert.is_false(status.groups["Bob#2002"])
    assert.are.equal("", searchBox().text)
  end)
end)
