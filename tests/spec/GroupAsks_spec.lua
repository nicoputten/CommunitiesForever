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
      assert.is_truthy(printed():find("Asked Ben who's up for The Deadmines. It's on Discord after your next /reload.",
        1, true))
      assert.are.equal("ask", addon.db.global.pending[1].kind) -- CF-64: always posted on Discord too
      assert.is_nil(ns.GroupAsks.ask(ns.Dungeons.get("wc")))
      assert.are.equal(1, #sent)
      state.serverTime = state.serverTime + 180
      assert.are.equal(1, ns.GroupAsks.ask(ns.Dungeons.get("wc")))
    end)

    it("asks friends only, without a post, when Discord is unticked (CF-65)", function()
      load()
      assert.are.equal(1, ns.GroupAsks.ask(ns.Dungeons.get("dm"), nil, false))
      assert.are.equal(1, #sent)
      assert.is_nil(sent[1].message.post)
      assert.are.equal(0, #(addon.db.global.pending or {}))
      state.serverTime = state.serverTime + 180
      assert.are.equal(0, ns.GroupAsks.ask(ns.Dungeons.get("strat"), nil, false))
      assert.is_truthy(printed():find("and it isn't posted on Discord.", 1, true))
    end)

    it("still asks when nobody online is in range: it goes to Discord (CF-64)", function()
      load()
      assert.are.equal(0, ns.GroupAsks.ask(ns.Dungeons.get("strat")))
      assert.is_falsy(printed():find("Nobody with CommunitiesForever", 1, true))
      assert.is_truthy(printed():find("Your ask for Stratholme is on Discord after your next /reload.", 1, true))
      assert.are.same({ "ask", "strat" }, { addon.db.global.pending[1].kind, addon.db.global.pending[1].dungeon })
      assert.is_truthy(ns.GroupAsks.current())
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

  describe("carried asks (CF-51)", function()
    local function posted(over)
      local m = { t = "ASK", id = "2001", from = "Ben", char = "Ben Main", post = true, item = "kben-1793-1",
                  guid = "Player-1-B1", role = "tank", at = state.serverTime - 30, note = "Quick",
                  dungeon = { id = "dm", name = "The Deadmines", min = 17, max = 26 } }
      for k, v in pairs(over or {}) do m[k] = v end
      return m
    end
    local function pending() return addon.db.global.pending or {} end
    local function ofKind(kind)
      local out = {}
      for _, item in ipairs(pending()) do
        if item.kind == kind then out[#out + 1] = item end
      end
      return out
    end

    it("sends a posted ask to every friend with the addon, also out of range", function()
      load()
      addon.db.global.people[FRIEND].chars = { ["Player-1-B1"] = { name = "Ben Main", level = 50 } }
      local item = { id = "kme-1-1", guid = state.player.guid, role = "dps" }
      assert.are.equal(0, ns.GroupAsks.ask(ns.Dungeons.get("dm"), nil, item))
      assert.are.equal(1, #sent)
      local m = sent[1].message
      assert.are.same({ true, "kme-1-1", state.player.guid, "dps" }, { m.post, m.item, m.guid, m.role })
      -- CF-64: /cf ask posts too, so it reaches the out-of-range friend as well (to carry it to the site).
      state.serverTime = state.serverTime + 180
      sent = {}
      assert.are.equal(0, ns.GroupAsks.ask(ns.Dungeons.get("dm")))
      assert.are.equal(1, #sent)
      assert.is_true(sent[1].message.post)
    end)

    it("carries a friend's posted ask once, with the asker's id, and asks you when you fit", function()
      load()
      deliver(posted())
      deliver(posted())
      local asks = ofKind("ask")
      assert.are.equal(1, #asks)
      assert.are.same({ "kben-1793-1", "dm", "Player-1-B1", "Ben Main", "tank", FRIEND, "Quick" },
        { asks[1].id, asks[1].dungeon, asks[1].guid, asks[1].name, asks[1].role, asks[1].battleTag, asks[1].note })
      assert.is_truthy(printed():find("Ben|r asks: The Deadmines now?", 1, true))
    end)

    it("carries silently when none of your characters fits, and drops an expired ask", function()
      load()
      deliver(posted({ dungeon = { id = "scholo", name = "Scholomance", min = 58, max = 60 }, item = "kben-2" }))
      assert.are.equal(1, #ofKind("ask"))
      assert.are.equal("", printed())
      deliver(posted({ item = "kben-old", at = state.serverTime - 700 }))
      assert.are.equal(1, #ofKind("ask"))
    end)

    it("keeps your answer to a posted ask for the site", function()
      load()
      deliver(posted())
      click("ask:join:2001")
      local answers = ofKind("askAnswer")
      assert.are.equal(1, #answers)
      assert.are.same({ "kben-1793-1", "in", state.player.guid },
        { answers[1].ask, answers[1].answer, answers[1].guid })
      -- A newer answer replaces it; an ask that wasn't posted makes none.
      click("ask:no:2001")
      assert.are.equal("cant", ofKind("askAnswer")[1].answer)
      assert.are.equal(1, #ofKind("askAnswer"))
      deliver({ t = "ASK", id = "1001", from = "Ben", char = "Ben Main",
                dungeon = { id = "dm", name = "The Deadmines", min = 17, max = 26 } })
      click("ask:join:1001")
      assert.are.equal(1, #ofKind("askAnswer"))
    end)
  end)

  it("asks from the Dungeons tab and shows the answers there", function()
    load()
    ns.MainFrame.toggle()
    ns.MainFrame.selectTab("dungeons")
    -- CF-42: the native tab.
    local function hasText(needle)
      for _, t in ipairs(ns.DungeonsTab.texts()) do
        if t:find(needle, 1, true) then return true end
      end
      return false
    end
    ns.DungeonsTab.select("dm")
    ns.DungeonsTab.buttons()["Ask now\226\128\166"]:RunScript("OnClick") -- CF-47: the Ask now dialog
    ns.RunDialogs.buttons()["Ask now"]:RunScript("OnClick")
    assert.are.equal(1, #sent)
    deliver({ t = "ANSWER", id = sent[1].message.id, answer = "later" })
    for _ = 1, 10 do wowapi.runTimers(state) end
    assert.is_true(hasText("Asked who's up for it"))
    assert.is_true(hasText("later: Ben"))
  end)
end)
