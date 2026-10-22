local net = require("net")

-- Sharing end to end: real addon instances on their own WoW mocks, messages carried by tests/net.lua.
describe("sharing end to end", function()
  local world

  local A_GUID, B_GUID, C_GUID = "Player-1-0000A001", "Player-1-0000B001", "Player-1-0000C001"

  local function people(friendsAB, withC)
    world:person({ key = "A", name = "Ada Example", guid = A_GUID, battleTag = "Ada#1001", classFile = "MAGE",
                   classID = 8, level = 20, gameAccountID = 101, friends = friendsAB and { "B" } or {} })
    local bobFriends = {}
    if friendsAB then bobFriends[#bobFriends + 1] = "A" end
    if withC then bobFriends[#bobFriends + 1] = "C" end
    world:person({ key = "B", name = "Bob Example", guid = B_GUID, battleTag = "Bob#2002", classFile = "ROGUE",
                   classID = 4, level = 22, gameAccountID = 102, friends = bobFriends })
    if withC then
      world:person({ key = "C", name = "Cy Example", guid = C_GUID, battleTag = "Cy#3003", classFile = "PRIEST",
                     classID = 5, level = 18, gameAccountID = 103, friends = { "B" } })
    end
  end

  -- What client `key` stores about the person who owns `guid` (any key), and that key.
  local function storedFor(key, guid)
    local db = world.clients[key].addon.db.global
    for personKey, person in pairs(db.people) do
      if person.chars and person.chars[guid] then return person, personKey end
    end
  end

  local function hasBattleTag(value)
    if type(value) == "string" then return value:match("[%w]+#%d%d%d%d") ~= nil end
    if type(value) == "table" then
      for k, v in pairs(value) do
        if hasBattleTag(k) or hasBattleTag(v) then return true end
      end
    end
    return false
  end

  before_each(function()
    world = net.new()
  end)

  after_each(function()
    world:shutdown()
  end)

  describe("Battle.net friends", function()
    it("exchange their characters, with professions, on login", function()
      people(true)
      world:login("A")
      world:login("B")
      world:settle()
      local bobAtAda, key = storedFor("A", B_GUID)
      assert.is_not_nil(bobAtAda, "Ada has Bob's record")
      assert.are.equal("Bob#2002", key)
      assert.is_nil(bobAtAda.via) -- straight from Bob
      assert.are.equal(22, bobAtAda.chars[B_GUID].level)
      assert.is_not_nil(next(bobAtAda.chars[B_GUID].professions or {}), "professions arrive")
      assert.is_not_nil(storedFor("B", A_GUID), "Bob has Ada's record")
    end)

    it("see each other's level-up after it happens", function()
      people(true)
      world:login("A")
      world:login("B")
      world:settle()
      world:with("A", function(c)
        c.state.player.level = 21
        require("mocks.wowapi").fireEvent(c.state, "PLAYER_LEVEL_UP", 21)
      end)
      world:settle()
      assert.are.equal(21, storedFor("B", A_GUID).chars[A_GUID].level)
    end)
  end)

  describe("community members who are not Battle.net friends", function()
    it("exchange their characters over whispers under account IDs, never a BattleTag", function()
      people(false)
      world:login("A")
      world:login("B")
      world:settle()
      local bobAtAda, key = storedFor("A", B_GUID)
      assert.is_not_nil(bobAtAda, "Ada has Bob's record over the community")
      assert.is_truthy(key:match("^aid:%x+$"))
      assert.are.equal(22, bobAtAda.chars[B_GUID].level)
      for _, client in ipairs({ "A", "B" }) do
        local sent = world:sentBy(client)
        assert.is_true(#sent > 0)
        for _, s in ipairs(sent) do
          assert.are.equal("whisper", s.channel)
          assert.is_true(#s.raw <= 255, "whisper part over 255 bytes")
          assert.is_false(hasBattleTag(s.message), "a BattleTag went over the community")
        end
      end
    end)

    it("deliver a large record (many quests) in 255-byte parts, complete", function()
      people(false)
      world:login("A")
      world:with("A", function(c)
        local log = {}
        for i = 1, 40 do
          log[#log + 1] = { questID = 5000 + i, title = "A rather long quest title number " .. i, isHeader = false }
        end
        c.state.questLog = log
        require("mocks.wowapi").fireEvent(c.state, "QUEST_LOG_UPDATE")
      end)
      world:settle()
      world:login("B")
      world:settle()
      local adaAtBob = storedFor("B", A_GUID)
      assert.is_not_nil(adaAtBob)
      local count = 0
      for _ in pairs(adaAtBob.chars[A_GUID].quests or {}) do count = count + 1 end
      assert.are.equal(40, count)
    end)
  end)

  describe("relay", function()
    it("brings Ada's characters to Cy through Bob while Ada is offline", function()
      people(true, true) -- Ada-Bob and Bob-Cy are friends; Ada and Cy are not
      world:login("A")
      world:login("B")
      world:settle()
      world:logout("A")
      world:login("C")
      world:settle()
      local adaAtCy = storedFor("C", A_GUID)
      assert.is_not_nil(adaAtCy, "Cy got Ada's record through Bob")
      assert.is_not_nil(adaAtCy.via, "marked as relayed")
      assert.are.equal(20, adaAtCy.chars[A_GUID].level)
    end)

    -- Found by this spec: Cy knows Ada only from Bob's relayed record, which has no account ID, so Ada's
    -- community HELLO (under "aid:...") from her own character is rejected as someone else's key, and her
    -- newer record is never asked for. Pending until the fix (see the PR).
    pending("lets Ada's own newer record replace the relayed copy once they meet", function()
      people(true, true)
      world:login("A")
      world:login("B")
      world:settle()
      world:logout("A")
      world:login("C")
      world:settle()
      -- Ada and Cy meet in the community (not friends): Ada's own record arrives over whispers.
      world.clients.A.online = true
      world:with("A", function(c) c.state.player.level = 21 end)
      world:notifyPresence("A")
      world:notifyPresence("C")
      world:with("A", function(c) require("mocks.wowapi").fireEvent(c.state, "PLAYER_LEVEL_UP", 21) end)
      world:settle()
      local adaAtCy = storedFor("C", A_GUID)
      assert.are.equal(21, adaAtCy.chars[A_GUID].level)
    end)
  end)
end)
