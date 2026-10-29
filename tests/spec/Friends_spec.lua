local helpers = require("helpers")

describe("Friends", function()
  local Friends

  local function ga(overrides)
    local base = { clientProgram = "WoW", wowProjectID = 18, isOnline = true, characterName = "Garraka Doombringer",
                   className = "Mage", characterLevel = 11, playerGuid = "Player-1-G", gameAccountID = 5 }
    for k, v in pairs(overrides or {}) do base[k] = v end
    return base
  end

  local function snap(accounts)
    return Friends.snapshot(accounts, "WoW", 18)
  end

  before_each(function()
    Friends = helpers.loadAddonFile("src/core/Friends.lua", helpers.coreNs())
  end)

  describe("snapshot", function()
    it("lists every friend, and the online Forever character per friend", function()
      local s = snap({
        { battleTag = "Sjaak#1", gameAccounts = { ga() } },
        { battleTag = "Off#2", gameAccounts = {} },
      })
      assert.are.same({ ["Sjaak#1"] = true, ["Off#2"] = true }, s.friends)
      assert.are.same({ [5] = "Sjaak#1" }, s.gameAccounts)
      assert.are.same({ ["Player-1-G"] = "Sjaak#1" }, s.characters)
      assert.are.same({ ["Sjaak#1"] = { guid = "Player-1-G", name = "Garraka Doombringer", className = "Mage",
                                        level = 11, gameAccountID = 5 } }, s.online)
    end)

    it("ignores other clients, other WoW projects and offline accounts", function()
      local s = snap({ { battleTag = "Sjaak#1", gameAccounts = {
        ga({ clientProgram = "BSAp", gameAccountID = 1 }),
        ga({ wowProjectID = 1, gameAccountID = 2 }),
        ga({ isOnline = false, gameAccountID = 3 }),
      } } })
      assert.are.same({}, s.online)
      assert.are.same({}, s.gameAccounts)
      assert.is_true(s.friends["Sjaak#1"])
    end)

    it("ignores game accounts without GUID or gameAccountID", function()
      local s = snap({ { battleTag = "Sjaak#1", gameAccounts = {
        ga({ playerGuid = false }), ga({ gameAccountID = false }),
      } } })
      assert.are.same({}, s.online)
    end)

    it("handles a friend with several Forever game accounts online", function()
      local s = snap({ { battleTag = "Sjaak#1", gameAccounts = {
        ga({ gameAccountID = 9, playerGuid = "Player-1-B", characterName = "Two" }),
        ga({ gameAccountID = 4, playerGuid = "Player-1-A", characterName = "One" }),
      } } })
      assert.are.equal("Player-1-A", s.online["Sjaak#1"].guid) -- lowest gameAccountID is current
      assert.are.same({ [9] = "Sjaak#1", [4] = "Sjaak#1" }, s.gameAccounts)
      assert.are.same({ ["Player-1-A"] = "Sjaak#1", ["Player-1-B"] = "Sjaak#1" }, s.characters)
    end)

    it("skips accounts without a BattleTag", function()
      assert.are.same({}, snap({ { gameAccounts = { ga() } } }).friends)
    end)
  end)

  describe("changes", function()
    local function online(bt, guid)
      return snap({ { battleTag = bt, gameAccounts = { ga({ playerGuid = guid }) } } })
    end
    local empty

    before_each(function()
      empty = snap({})
    end)

    it("reports nothing for the first snapshot (baseline)", function()
      assert.are.same({}, Friends.changes(nil, online("Sjaak#1", "G1")))
    end)

    it("reports a friend coming online", function()
      assert.are.same({ { kind = "online", battleTag = "Sjaak#1", guid = "G1" } },
        Friends.changes(empty, online("Sjaak#1", "G1")))
    end)

    it("reports a friend going offline", function()
      assert.are.same({ { kind = "offline", battleTag = "Sjaak#1", previousGuid = "G1" } },
        Friends.changes(online("Sjaak#1", "G1"), empty))
    end)

    it("reports a character switch", function()
      assert.are.same({ { kind = "switched", battleTag = "Sjaak#1", guid = "G2", previousGuid = "G1" } },
        Friends.changes(online("Sjaak#1", "G1"), online("Sjaak#1", "G2")))
    end)

    it("reports nothing when the character stays the same", function()
      local before = online("Sjaak#1", "G1")
      local after = snap({
        { battleTag = "Sjaak#1", gameAccounts = { ga({ playerGuid = "G1", characterLevel = 12 }) } },
      })
      assert.are.same({}, Friends.changes(before, after))
    end)

    it("sorts changes by BattleTag", function()
      local before = snap({})
      local after = snap({
        { battleTag = "Zed#1", gameAccounts = { ga({ playerGuid = "Z", gameAccountID = 1 }) } },
        { battleTag = "Amy#1", gameAccounts = { ga({ playerGuid = "A", gameAccountID = 2 }) } },
      })
      local changes = Friends.changes(before, after)
      assert.are.equal("Amy#1", changes[1].battleTag)
      assert.are.equal("Zed#1", changes[2].battleTag)
    end)
  end)

  describe("recordPresence", function()
    it("links every online Forever character to its BattleTag with lastSeen", function()
      local presence = {}
      Friends.recordPresence(presence, snap({ { battleTag = "Sjaak#1", gameAccounts = {
        ga({ gameAccountID = 1, playerGuid = "A" }), ga({ gameAccountID = 2, playerGuid = "B" }),
      } } }), 5000)
      assert.are.same({
        A = { battleTag = "Sjaak#1", lastSeen = 5000 },
        B = { battleTag = "Sjaak#1", lastSeen = 5000 },
      }, presence)
    end)

    it("keeps links of characters that are no longer online", function()
      local presence = { Old = { battleTag = "Sjaak#1", lastSeen = 100 } }
      Friends.recordPresence(presence, snap({}), 5000)
      assert.are.same({ battleTag = "Sjaak#1", lastSeen = 100 }, presence.Old)
    end)

    it("reassigns a GUID seen under another BattleTag", function()
      local presence = { A = { battleTag = "Old#1", lastSeen = 100 } }
      Friends.recordPresence(presence, snap({ { battleTag = "New#2", gameAccounts = { ga({ playerGuid = "A" }) } } }),
        5000)
      assert.are.same({ battleTag = "New#2", lastSeen = 5000 }, presence.A)
    end)
  end)
  describe("a friend who appears offline (Battle.net)", function()
    local friends = { ["Ada#1001"] = true }

    it("is resolved from the sending game account, only for a friend in this game", function()
      local info = { clientProgram = "WoW", wowProjectID = 18, playerGuid = "Player-1-A" }
      assert.are.same({ "Ada#1001", "Player-1-A" },
        { Friends.resolveHidden(info, "Ada#1001", friends, {}, {}, "WoW", 18) })
      -- No account lookup: the GUID from presence seen earlier, or from a stored record.
      assert.are.equal("Ada#1001", Friends.resolveHidden(info, nil, friends,
        { ["Player-1-A"] = { battleTag = "Ada#1001" } }, {}, "WoW", 18))
      assert.are.equal("Ada#1001", Friends.resolveHidden(info, nil, friends, {},
        { ["Ada#1001"] = { chars = { ["Player-1-A"] = {} } } }, "WoW", 18))
      assert.is_nil(Friends.resolveHidden(info, "Zed#9", friends, {}, {}, "WoW", 18)) -- not a friend
      assert.is_nil(Friends.resolveHidden({ clientProgram = "WoW", wowProjectID = 1, playerGuid = "x" }, "Ada#1001",
        friends, {}, {}, "WoW", 18)) -- another game
      assert.is_nil(Friends.resolveHidden(nil, "Ada#1001", friends, {}, {}, "WoW", 18))
    end)

    it("joins the snapshot for sync and linking, never as online", function()
      local hiddenSnap = Friends.snapshot({ { battleTag = "Ada#1001", gameAccounts = {} } }, "WoW", 18)
      Friends.addHidden(hiddenSnap, 77, "Ada#1001", "Player-1-A")
      assert.are.equal("Ada#1001", hiddenSnap.gameAccounts[77])
      assert.is_nil(hiddenSnap.online["Ada#1001"])
      assert.is_nil(hiddenSnap.characters["Player-1-A"])
      local presence = { ["Player-1-A"] = { battleTag = "Ada#1001", lastSeen = 100 } }
      Friends.recordPresence(presence, hiddenSnap, 999)
      assert.are.same({ battleTag = "Ada#1001", lastSeen = 100 }, presence["Player-1-A"]) -- lastSeen not moved
      assert.are.same({}, Friends.changes(Friends.snapshot({}, "WoW", 18), hiddenSnap)) -- no "came online"
    end)
  end)
end)
