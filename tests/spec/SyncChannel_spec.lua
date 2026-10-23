local helpers = require("helpers")
local net = require("net")
local wowapi = require("mocks.wowapi")

-- CF-31: HELLO and BYE on the hidden community channel, whispers as the fallback (end-to-end harness).
describe("hidden community channel (CF-31)", function()
  local world

  -- Three community members, nobody's Battle.net friend (so everything goes over the community).
  local function people(extra)
    local defs = {
      { key = "A", name = "Ada Example", guid = "Player-1-0000A001", battleTag = "Ada#1001", classFile = "MAGE",
        classID = 8, level = 20, gameAccountID = 101, friends = {} },
      { key = "B", name = "Bob Example", guid = "Player-1-0000B001", battleTag = "Bob#2002", classFile = "ROGUE",
        classID = 4, level = 22, gameAccountID = 102, friends = {} },
      { key = "C", name = "Cy Example", guid = "Player-1-0000C001", battleTag = "Cy#3003", classFile = "PRIEST",
        classID = 5, level = 18, gameAccountID = 103, friends = {} },
    }
    for _, def in ipairs(defs) do
      for k, v in pairs(extra and extra[def.key] or {}) do def[k] = v end
      world:person(def)
    end
  end

  local function loginAll()
    world:login("A")
    world:login("B")
    world:login("C")
    world:settle()
  end

  local function storedAt(key, guid)
    for _, person in pairs(world.clients[key].addon.db.global.people) do
      if person.chars and person.chars[guid] then return person.chars[guid] end
    end
  end

  -- Messages of one type a client sent since `from` (an index in sentBy), split by how they went.
  local function sentSince(key, from, t)
    local channel, whispers = 0, {}
    local sent = world:sentBy(key)
    for i = from + 1, #sent do
      local s = sent[i]
      if s.message.t == t then
        if s.channel == "channel" then channel = channel + 1 else whispers[#whispers + 1] = s.to end
      end
    end
    return channel, whispers
  end

  local function levelUp(key, level)
    world:with(key, function(c)
      c.state.player.level = level
      wowapi.fireEvent(c.state, "PLAYER_LEVEL_UP", level)
    end)
  end

  after_each(function()
    world:shutdown()
  end)

  it("joins one channel per community, named after it, out of every chat window", function()
    world = net.new({ channel = true })
    people()
    loginAll()
    local name
    world:with("A", function(c)
      name = c.ns.SyncChannel.name()
      assert.are.equal(c.ns.Chat.syncChannel("Test Friends"), name)
      assert.is_not_nil(c.ns.SyncChannel.index())
      for _, window in ipairs(c.state.chatWindows) do
        for _, channel in ipairs(window.channels) do assert.are_not.equal(name, channel) end
      end
    end)
    world:with("B", function(c) assert.are.equal(name, c.ns.SyncChannel.name()) end)
  end)

  it("syncs records as before, then sends a new HELLO once on the channel instead of a whisper each", function()
    world = net.new({ channel = true })
    people()
    loginAll()
    assert.are.equal(20, storedAt("B", "Player-1-0000A001").level)
    assert.are.equal(18, storedAt("A", "Player-1-0000C001").level)
    local from = #world:sentBy("A")
    levelUp("A", 21)
    world:settle()
    local channel, whispers = sentSince("A", from, "HELLO")
    assert.are.equal(1, channel)
    assert.are.same({}, whispers) -- B and C said they listen on the channel
    assert.are.equal(21, storedAt("B", "Player-1-0000A001").level)
    assert.are.equal(21, storedAt("C", "Player-1-0000A001").level)
  end)

  it("tells someone who logs in later about you, without a change of yours", function()
    world = net.new({ channel = true })
    people()
    world:login("A")
    world:settle()
    world:login("B") -- after Ada's last HELLO: Ada answers Bob's first HELLO
    world:settle()
    assert.are.equal(20, storedAt("B", "Player-1-0000A001").level)
    assert.are.equal(22, storedAt("A", "Player-1-0000B001").level)
  end)

  it("still whispers a member whose client does not listen on the channel (older version)", function()
    world = net.new({ channel = true })
    people({ C = { noChannel = true } })
    loginAll()
    local from = #world:sentBy("A")
    levelUp("A", 21)
    world:settle()
    local channel, whispers = sentSince("A", from, "HELLO")
    assert.are.equal(1, channel)
    assert.are.same({ "Cy Example" }, whispers)
    assert.are.equal(21, storedAt("C", "Player-1-0000A001").level)
  end)

  it("says BYE once on the channel", function()
    world = net.new({ channel = true })
    people()
    loginAll()
    local from = #world:sentBy("A")
    world:logout("A")
    local channel, whispers = sentSince("A", from, "BYE")
    assert.are.equal(1, channel)
    assert.are.same({}, whispers)
    world:with("B", function(c) assert.is_true(c.ns.Sync.offline()["Player-1-0000A001"]) end)
  end)

  it("whispers everything when the channel cannot be joined", function()
    world = net.new({ channel = false })
    people()
    loginAll()
    local from = #world:sentBy("A")
    levelUp("A", 21)
    world:settle()
    local channel, whispers = sentSince("A", from, "HELLO")
    assert.are.equal(0, channel)
    table.sort(whispers)
    assert.are.same({ "Bob Example", "Cy Example" }, whispers)
    assert.are.equal(21, storedAt("B", "Player-1-0000A001").level)
  end)

  it("ignores channel messages from outside the community and its own", function()
    world = net.new({ channel = true })
    people()
    loginAll()
    world:with("A", function(c)
      local before = c.ns.Messenger.stats().received
      local codec = c.ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
      local name, index = c.ns.SyncChannel.name(), c.ns.SyncChannel.index()
      local chunk = c.ns.Protocol.chunk(codec:encode({ t = "HELLO", bt = "aid:eeeeeeeeeeee", ver = 1 }), "x1", 255)[1]
      wowapi.fireEvent(c.state, "CHAT_MSG_ADDON", c.ns.Protocol.PREFIX, chunk, "CHANNEL", "Stranger Example-Realm",
        name, 0, index, index .. ". " .. name)
      wowapi.fireEvent(c.state, "CHAT_MSG_ADDON", c.ns.Protocol.PREFIX, chunk, "CHANNEL", "Ada Example-Realm",
        name, 0, index, index .. ". " .. name)
      wowapi.fireEvent(c.state, "CHAT_MSG_ADDON", c.ns.Protocol.PREFIX, chunk, "CHANNEL", "Bob Example-Realm",
        "some other channel", 0, 99, "99. some other channel")
      assert.are.equal(before, c.ns.Messenger.stats().received)
    end)
  end)
end)
