local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Who's up for it? (CF-27)", function()
  local state, ns, addon, sent
  local CLUB = "23125681"
  local FRIEND, FRIEND_GA -- the mock's Battle.net friend online in Forever

  local function load()
    state = wowapi.install()
    state.player.level = 20
    for _, m in ipairs(state.clubMembers[CLUB]) do m.level = 20 end
    FRIEND = state.friends[1].battleTag
    FRIEND_GA = state.friends[1].gameAccounts[1].gameAccountID
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    -- The friend runs the addon: their record has an alt in Deadmines range.
    addon.db.global.people[FRIEND] = { displayName = "Ben", version = 1,
      chars = { ["Player-1-B1"] = { name = "Ben Main", level = 50 },
                ["Player-1-B2"] = { name = "Bob Alt", level = 20 } } }
    addon:OnEnable()
    sent = {}
    ns.Messenger.send = function(gameAccountID, message)
      sent[#sent + 1] = { gameAccountID = gameAccountID, message = message }
      return 1
    end
    state.printed = {}
  end

  local function printed() return table.concat(state.printed, "\n") end
  local function deliver(message, battleTag, gameAccountID)
    addon:SendMessage(ns.Messenger.RECEIVED, message, battleTag or FRIEND, gameAccountID or FRIEND_GA)
  end
  local function click(path) assert.is_true(ns.ChatLinks.dispatch("addon:CommunitiesForever:" .. path)) end

  after_each(function()
    _G.C_PartyInfo = nil
    wowapi.uninstall()
  end)

  describe("asking", function()
    it("sends the ask to friends with a character in range, once per 3 minutes", function()
      load()
      assert.are.equal(1, ns.GroupAsks.ask(ns.Dungeons.get("dm")))
      assert.are.equal(1, #sent)
      assert.are.equal(FRIEND_GA, sent[1].gameAccountID)
      local m = sent[1].message
      assert.are.equal("ASK", m.t)
      assert.are.same({ id = "dm", name = "The Deadmines", min = 17, max = 26 }, m.dungeon)
      assert.is_truthy(printed():find("Asked Ben who's up for The Deadmines.", 1, true))
      assert.is_nil(ns.GroupAsks.ask(ns.Dungeons.get("wc")))
      assert.are.equal(1, #sent)
      state.serverTime = state.serverTime + 180
      assert.are.equal(1, ns.GroupAsks.ask(ns.Dungeons.get("wc")))
    end)

    it("says so when nobody can be asked", function()
      load()
      assert.are.equal(0, ns.GroupAsks.ask(ns.Dungeons.get("strat")))
      assert.are.equal(0, #sent)
      assert.is_truthy(printed():find("Nobody with CommunitiesForever is online", 1, true))
    end)

    it("collects answers, offers an invite link and invites on click", function()
      load()
      local invited
      _G.C_PartyInfo = { InviteUnit = function(name) invited = name end }
      ns.GroupAsks.ask(ns.Dungeons.get("dm"))
      local id = sent[1].message.id
      deliver({ t = "ANSWER", id = id, answer = "join", from = "Ben", char = "Bob Alt" })
      assert.is_truthy(printed():find("joins your The Deadmines run on Bob Alt: ", 1, true))
      assert.is_truthy(printed():find("|Haddon:CommunitiesForever:invite:" .. FRIEND .. "|h[Invite]|h", 1, true))
      assert.are.same({ "Ben (Bob Alt)" }, ns.GroupAsk.summary(ns.GroupAsks.current()).join)
      click("invite:" .. FRIEND)
      assert.are.equal("Bob Alt", invited)
      assert.is_truthy(printed():find("Invited Bob Alt.", 1, true))
    end)

    it("ignores answers to other asks and from people not asked", function()
      load()
      ns.GroupAsks.ask(ns.Dungeons.get("dm"))
      deliver({ t = "ANSWER", id = "other", answer = "join" })
      deliver({ t = "ANSWER", id = sent[1].message.id, answer = "join" }, "Stranger#9", 99)
      assert.is_nil(next(ns.GroupAsks.current().answers))
    end)

    it("asks with /cf ask and the full dungeon name", function()
      load()
      addon:OnSlashCommand("ask The Deadmines")
      assert.are.equal("The Deadmines", sent[1].message.dungeon.name)
      addon:OnSlashCommand("ask")
      assert.is_truthy(printed():find("The Deadmines: joining ; later ; no ; waiting Ben.", 1, true))
    end)
  end)

  describe("receiving", function()
    local ASK = { t = "ASK", id = "1001", from = "Ben", char = "Ben Main",
                  dungeon = { id = "dm", name = "The Deadmines", min = 17, max = 26 } }

    it("shows a chat line with your characters in range, the answer links and a sound", function()
      load()
      deliver(ASK)
      local all = printed()
      assert.is_truthy(all:find("Ben|r asks: The Deadmines now? |cffa0a0a0(17-26)|r", 1, true))
      assert.is_truthy(all:find("You could come on: " .. state.player.name .. " 20", 1, true))
      assert.is_truthy(all:find("|Haddon:CommunitiesForever:ask:join:1001|h[Join]|h", 1, true))
      assert.is_truthy(all:find("|Haddon:CommunitiesForever:ask:no:1001|h[No]|h", 1, true))
      assert.are.same({ 3081 }, state.sounds)
    end)

    it("stays quiet when receiving asks is off", function()
      load()
      ns.Settings.options().args.groupAsks.set({}, false)
      deliver(ASK)
      assert.are.equal("", printed())
      assert.are.same({}, state.sounds)
    end)

    it("answers Join and asks the asker for an invite", function()
      load()
      local requested
      _G.C_PartyInfo = { RequestInviteFromUnit = function(name) requested = name end }
      deliver(ASK)
      click("ask:join:1001")
      assert.are.equal(FRIEND_GA, sent[1].gameAccountID)
      assert.are.equal("join", sent[1].message.answer)
      assert.are.equal(state.player.name, sent[1].message.char)
      assert.are.equal("Ben Main", requested)
      assert.is_truthy(printed():find("Asked Ben Main for a party invite.", 1, true))
    end)

    it("answers Later without an invite, and says when the request call is missing", function()
      load()
      deliver(ASK)
      click("ask:later:1001")
      assert.are.equal("later", sent[1].message.answer)
      click("ask:join:1001")
      assert.is_truthy(printed():find("Ben gets a link to invite you.", 1, true))
    end)

    it("does not answer an expired ask", function()
      load()
      deliver(ASK)
      state.serverTime = state.serverTime + 600
      click("ask:join:1001")
      assert.are.equal(0, #sent)
      assert.is_truthy(printed():find("This ask has expired.", 1, true))
    end)
  end)

  it("asks from the Dungeons tab and shows the answers there", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
    local function find(widgetType, text)
      local found
      local function walk(w)
        for _, child in ipairs(w.children) do
          if not found and child.type == widgetType and child.text and child.text:find(text, 1, true) then
            found = child
          end
          walk(child)
        end
      end
      for _, w in ipairs(state.guiWidgets) do
        if w.cfMainRoot then walk(w) end -- CF-39: the tab content
      end
      return found
    end
    for _, w in ipairs(state.guiWidgets) do
      if w.type == "TreeGroup" then w:SelectByValue("dm") end
    end
    find("Button", "Ask who's up for it"):Fire("OnClick")
    assert.are.equal(1, #sent)
    deliver({ t = "ANSWER", id = sent[1].message.id, answer = "later" })
    for _ = 1, 10 do wowapi.runTimers(state) end
    assert.is_truthy(find("Label", "Asked who's up for it"))
    assert.is_truthy(find("Label", "later: Ben"))
  end)
end)
