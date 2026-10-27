local helpers = require("helpers")
local net = require("net")

-- CF-37: the right-click menu on people and characters.
describe("right-click menu (CF-37)", function()
  describe("Format.contextMenu (pure)", function()
    local Format

    before_each(function()
      local ns = {}
      helpers.loadAddonFile("src/core/Quests.lua", ns)
      Format = helpers.loadAddonFile("src/core/Format.lua", ns)
    end)

    local function view()
      local bobMain = { guid = "B1", name = "Bob Main", online = true }
      local bobAlt = { guid = "B2", name = "Bob Alt", online = false }
      return {
        people = {
          { battleTag = "Bob#2002", displayName = "Bob", online = true, currentChar = bobMain,
            chars = { bobMain, bobAlt } },
          { battleTag = "Cy#3003", displayName = "Cy", online = false, chars = { { guid = "C1", name = "Cy Char" } } },
          { battleTag = "Me#1", displayName = "Me", isSelf = true, online = true,
            chars = { { guid = "M1", name = "Mine" } } },
        },
        unlinked = { { guid = "U1", name = "Stranger Example", online = true } },
      }
    end

    local function labels(model)
      local list = {}
      for _, item in ipairs(model.items) do list[#list + 1] = item.label .. (item.enabled and "" or " (off)") end
      return list
    end

    it("acts on the character a person is playing", function()
      local model = Format.contextMenu(view(), "Bob#2002")
      assert.are.equal("Bob (on Bob Main)", model.title)
      assert.are.same({ "Whisper", "Invite to group" }, labels(model))
      assert.are.equal("Bob Main", model.items[1].name)
      assert.are.equal("Bob#2002", model.items[2].battleTag)
    end)

    it("disables both for an offline person or character", function()
      local model = Format.contextMenu(view(), "Cy#3003")
      assert.are.equal("Cy - Offline", model.title)
      assert.are.same({ "Whisper (off)", "Invite to group (off)" }, labels(model))
      model = Format.contextMenu(view(), "Bob#2002\001B2")
      assert.are.equal("Bob Alt - Offline", model.title)
      assert.are.same({ "Whisper (off)", "Invite to group (off)" }, labels(model))
    end)

    it("works on an online character and on an unlinked member", function()
      local model = Format.contextMenu(view(), "Bob#2002\001B1")
      assert.are.equal("Bob Main", model.title)
      assert.are.same({ "Whisper", "Invite to group" }, labels(model))
      model = Format.contextMenu(view(), Format.UNLINKED .. "\001U1")
      assert.are.equal("Stranger Example", model.items[1].name)
      assert.is_nil(model.items[1].battleTag)
    end)

    it("has no menu for your own rows, the Unlinked header or unknown paths", function()
      assert.is_nil(Format.contextMenu(view(), "Me#1"))
      assert.is_nil(Format.contextMenu(view(), "Me#1\001M1"))
      assert.is_nil(Format.contextMenu(view(), Format.UNLINKED))
      assert.is_nil(Format.contextMenu(view(), "Nobody#9"))
      assert.is_nil(Format.contextMenu(view(), "Bob#2002\001GONE"))
      assert.is_nil(Format.contextMenu(view(), nil))
    end)
  end)

  describe("in the window", function()
    local world, ns, state
    local tells, invites

    before_each(function()
      world = net.new()
      world:person({ key = "A", name = "Ada Example", guid = "Player-1-0000A001", battleTag = "Ada#1001",
                     classFile = "MAGE", classID = 8, level = 20, gameAccountID = 101, friends = { "B" } })
      world:person({ key = "B", name = "Bob Example", guid = "Player-1-0000B001", battleTag = "Bob#2002",
                     classFile = "ROGUE", classID = 4, level = 22, gameAccountID = 102, friends = { "A" } })
      world:login("A")
      world:login("B")
      world:settle()
      tells, invites = {}, {}
      world:with("A", function(c)
        ns, state = c.ns, c.state
        _G.ChatFrameUtil = { SendTell = function(name) tells[#tells + 1] = name end }
        _G.C_PartyInfo = { InviteUnit = function(name) invites[#invites + 1] = name end }
        ns.MainFrame.toggle()
      end)
    end)

    after_each(function()
      _G.ChatFrameUtil, _G.C_PartyInfo = nil, nil
      world:shutdown()
    end)

    local function tab() return helpers.friendsTab(ns) end
    local function treeButton(path) return tab().row(path) end -- CF-40: a row of the native list
    local function rightClick(frame) tab().rightClick(frame) end

    local function click(menu, text)
      for _, b in ipairs(menu.buttons) do
        if b.text == text then return b.fn() end
      end
      error("no menu button " .. text)
    end

    it("puts the window one strata below Blizzard's menus", function()
      assert.are.equal("DIALOG", ns.MainFrame.window():GetFrameStrata())
    end)

    it("opens on a person row and whispers or invites the character they are on", function()
      rightClick(treeButton("Bob#2002"))
      local menu = state.menus[#state.menus]
      assert.are.equal("Bob (on Bob Example)", menu.title)
      click(menu, "Whisper")
      assert.are.same({ "Bob Example" }, tells)
      click(menu, "Invite to group")
      assert.are.same({ "Bob Example" }, invites)
    end)

    it("opens on a character row and on the card's character list, never on your own", function()
      rightClick(treeButton("Bob#2002\001Player-1-0000B001"))
      assert.are.equal("Bob Example", state.menus[#state.menus].title)
      local before = #state.menus
      rightClick(treeButton("Ada#1001"))
      rightClick(treeButton("Ada#1001\001Player-1-0000A001"))
      assert.are.equal(before, #state.menus)
      -- the person card lists Bob's characters: right-click one there
      world:with("A", function() ns.FriendsTab.select("Bob#2002") end) -- Bob's card
      local entry = tab().cardLines()[1]
      assert.is_not_nil(entry, "card entry for Bob Example")
      assert.are.equal("Bob Example", entry.name:GetText())
      rightClick(entry)
      assert.are.equal("Bob Example", state.menus[#state.menus].title)
    end)

    -- CF-40: the character card has the menu's actions as buttons.
    it("whispers and invites from the character card's buttons, off on your own characters", function()
      world:with("A", function() ns.FriendsTab.select("Bob#2002\001Player-1-0000B001") end)
      local buttons = ns.FriendsTab.cardButtons()
      assert.is_true(buttons.Whisper.enabled)
      tab().click(buttons.Whisper)
      assert.are.same({ "Bob Example" }, tells)
      tab().click(buttons.Invite)
      assert.are.same({ "Bob Example" }, invites)

      world:with("A", function() ns.FriendsTab.select("Ada#1001\001Player-1-0000A001") end)
      buttons = ns.FriendsTab.cardButtons()
      assert.is_false(buttons.Whisper.enabled)
      assert.is_false(buttons.Invite.enabled)
    end)

    it("says so when an invite cannot be sent", function()
      _G.C_PartyInfo = nil
      _G.BNInviteFriend = nil
      rightClick(treeButton("Bob#2002"))
      click(state.menus[#state.menus], "Invite to group")
      assert.are.equal("Could not invite Bob Example.", state.printed[#state.printed])
    end)
  end)
end)
