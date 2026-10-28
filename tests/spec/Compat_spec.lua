local helpers = require("helpers")
local net = require("net")
local wowapi = require("mocks.wowapi")

-- CLAUDE.md rule 8: every version keeps reading what earlier versions wrote. The golden fixtures in
-- tests/fixtures/<version>/ were captured with tests/fixtures/capture.lua; this spec feeds them to the
-- current code: messages as they arrive from a friend or community member on that version, and the
-- SavedVariables file as that version left it. Add a label here after capturing a new release.
local VERSIONS = { "v0.3", "v0.4", "v0.5", "v0.6" }
local PEOPLE = dofile("tests/fixtures/people.lua")

local function unhex(text)
  return (text:gsub("%x%x", function(byte) return string.char(tonumber(byte, 16)) end))
end

for _, version in ipairs(VERSIONS) do
  local dir = "tests/fixtures/" .. version
  local wire = dofile(dir .. "/wire.lua")
  local saved = dofile(dir .. "/savedvariables.lua")

  describe("compatibility with " .. version, function()
    local world

    after_each(function()
      if world then world:shutdown() end
      world = nil
    end)

    -- A world with the receiver and the sender logged in, nothing exchanged yet, later on the clock.
    local function receiverFor(fixture)
      world = net.new()
      for _, key in ipairs({ "A", "B", "C" }) do world:person(PEOPLE[key]) end
      world.serverTime = 5000
      local sender = fixture.sender
      local receiver
      if fixture.name:match("^bn%-") then
        receiver = sender == "A" and "B" or "A" -- Ada and Bob are Battle.net friends
      else
        receiver = sender == "C" and "B" or "C" -- Cy is nobody's friend: community whispers
      end
      world:login(sender)
      world:login(receiver)
      return receiver
    end

    -- Delivers the fixture's encoded message in parts, as the game would.
    local function deliver(fixture, receiver)
      local from = PEOPLE[fixture.sender]
      local encoded = unhex(fixture.hex)
      world:with(receiver, function(c)
        local whisper = fixture.name:match("^whisper%-")
        local chunks = c.ns.Protocol.chunk(encoded, "fx1", whisper and c.ns.Protocol.COMMUNITY_CHUNK or nil)
        for _, chunk in ipairs(chunks) do
          if whisper then
            wowapi.fireEvent(c.state, "CHAT_MSG_ADDON", c.ns.Protocol.PREFIX, chunk, "WHISPER",
              from.name .. "-ClassicBetaPvP")
          else
            wowapi.fireEvent(c.state, "BN_CHAT_MSG_ADDON", c.ns.Protocol.PREFIX, chunk, "WHISPER", from.gameAccountID)
          end
        end
        for _ = 1, 20 do -- answers queue behind the login messages, one part per 0.2 s
          c.state.time = c.state.time + 1
          wowapi.runTimers(c.state)
        end
      end)
    end

    local function storedChar(receiver, guid)
      for _, person in pairs(world.clients[receiver].addon.db.global.people) do
        if person.chars and person.chars[guid] then return person.chars[guid] end
      end
    end

    for _, fixture in ipairs(wire) do
      it("reads " .. fixture.name, function()
        local receiver = receiverFor(fixture)
        local c = world.clients[receiver]
        local codec = c.ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
        local message, reason = codec:decode(unhex(fixture.hex))
        assert.is_table(message, "decode failed: " .. tostring(reason))
        assert.are.equal(c.ns.Protocol.VERSION, message.pv)
        assert.are.equal(fixture.message.t, message.t)

        local before = c.ns.Messenger.stats().received
        deliver(fixture, receiver)
        assert.are.equal(before + 1, c.ns.Messenger.stats().received, "not received as a whole message")

        if message.t == "RECORD" then
          -- Its characters are stored (a relayed one through the community member who sent it).
          for guid in pairs(fixture.message.chars or {}) do
            assert.is_not_nil(storedChar(receiver, guid), "character " .. guid .. " not stored")
          end
        elseif message.t == "HELLO" then
          local asked = false
          for _, s in ipairs(world:sentBy(receiver)) do
            if s.message.t == "REQ" then asked = true end
          end
          assert.is_true(asked, "a HELLO with a newer version is answered with a REQ")
        end
      end)
    end

    it("starts with the SavedVariables it left", function()
      local state = wowapi.install()
      local a = PEOPLE.A
      local p = state.player
      p.guid, p.name, p.battleTag, p.classFile, p.level = a.guid, a.name, a.battleTag, a.classFile, a.level
      state.clubs = { { clubId = net.CLUB, name = "Test Friends", clubType = 1 } }
      local members = {}
      for i, key in ipairs({ "A", "B", "C" }) do
        local d = PEOPLE[key]
        members[i] = { memberId = i, guid = d.guid, name = d.name, classID = d.classID, level = d.level,
          zone = "Durotar", presence = 0, race = 2, faction = 0, isSelf = key == "A", clubType = 1, role = 4 }
      end
      state.clubMembers = { [net.CLUB] = members }
      local b = PEOPLE.B
      state.friends = { { battleTag = b.battleTag, gameAccounts = {} } } -- Bob: Battle.net friend, offline
      state.savedVariables = { global = saved }
      local ns = helpers.loadAddon()
      local addon = state.addon
      addon:OnInitialize()
      addon:OnEnable()
      wowapi.runTimers(state)
      assert.are.equal(ns.Store.SCHEMA_VERSION, addon.db.global.schemaVersion)
      local bob
      for _, person in ipairs(ns.ViewModel.build(addon).people) do
        if person.battleTag == PEOPLE.B.battleTag then bob = person end
      end
      assert.is_not_nil(bob, "Bob is still known")
      assert.are.equal(PEOPLE.B.guid, bob.chars[1].guid)
      ns.MainFrame.toggle() -- the window renders the old data
      assert.is_true(ns.MainFrame.isShown())
      wowapi.uninstall()
    end)
  end)
end
