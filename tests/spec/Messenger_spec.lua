local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Messenger", function()
  local state, ns, addon, Messenger, Protocol, baseline

  local SJAAK, SJAAK_GA = "Sjaakovich#2232", 5

  local function load()
    state = wowapi.install()
    ns = helpers.loadAddon()
    Messenger, Protocol = ns.Messenger, ns.Protocol
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    -- Let the startup sync traffic (HELLO) go out, then start each test from a quiet state.
    for _ = 1, 50 do
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
    state.bnSent = {}
    baseline = Messenger.stats()
  end

  -- Delivers what this client sent as if it came back from a game account (loopback).
  local function deliverSent(fromGameAccount, startIndex)
    local sent = {}
    for i = startIndex or 1, #state.bnSent do sent[#sent + 1] = state.bnSent[i] end
    for _, call in ipairs(sent) do
      wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", call[2], call[3], "WHISPER", fromGameAccount)
    end
  end

  -- Lets queued chunks go out: advance time past the interval and run due timers.
  local function flush()
    for _ = 1, 200 do
      if #state.timers == 0 then return end
      state.time = state.time + 0.2
      wowapi.runTimers(state)
    end
  end

  local function received()
    return wowapi.sentMessages(state, Messenger.RECEIVED)
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("registers the addon message prefix", function()
    load()
    assert.is_true(state.prefixes.CommForever)
  end)

  it("sends a small message right away with the prefix", function()
    load()
    assert.are.equal(1, Messenger.send(SJAAK_GA, { t = "HELLO" }))
    assert.are.equal(1, #state.bnSent)
    assert.are.same({ SJAAK_GA, "CommForever" }, { state.bnSent[1][1], state.bnSent[1][2] })
    assert.is_true(#state.bnSent[1][3] <= Protocol.MAX_CHUNK)
  end)

  it("throttles chunks to one per interval", function()
    load()
    local noise, seed = {}, 7
    for i = 1, 12000 do -- pseudo-random, barely compressible
      seed = (seed * 1103515245 + 12345) % 2147483648
      noise[i] = string.char(32 + seed % 90)
    end
    local chunks = Messenger.send(SJAAK_GA, { t = "RECORD", data = table.concat(noise) })
    assert.is_true(chunks >= 3)
    assert.are.equal(1, #state.bnSent) -- first chunk immediately
    assert.are.equal(1, #state.timers)
    wowapi.runTimers(state) -- timer fires early: still rate limited, reschedules
    assert.are.equal(1, #state.bnSent)
    flush()
    assert.are.equal(chunks, #state.bnSent)
    assert.are.equal(0, Messenger.stats().queued)
  end)

  it("holds chunks during combat and sends them after combat ends", function()
    load()
    state.inCombat = true
    Messenger.send(SJAAK_GA, { t = "HELLO" })
    flush()
    assert.are.equal(0, #state.bnSent)
    assert.are.equal(1, Messenger.stats().queued)
    state.inCombat = false
    wowapi.fireEvent(state, "PLAYER_REGEN_ENABLED")
    assert.are.equal(1, #state.bnSent)
  end)

  it("broadcasts to every friend game account online in Forever", function()
    load()
    assert.are.equal(1, Messenger.broadcast({ t = "HELLO" })) -- only Sjaak's Forever account
    assert.are.equal(SJAAK_GA, state.bnSent[1][1])
  end)

  it("reassembles, decodes and passes on messages with the sender's BattleTag", function()
    load()
    local message = { t = "RECORD", bt = SJAAK, padding = string.rep("Mining 64/150 ", 2000) }
    Messenger.send(SJAAK_GA, message)
    flush()
    deliverSent(SJAAK_GA)
    local got = received()
    assert.are.equal(1, #got)
    assert.are.same(message, got[1][1])
    assert.are.same({ SJAAK, SJAAK_GA }, { got[1][2], got[1][3] })
  end)

  it("drops messages from game accounts that are not friends in Forever", function()
    load()
    Messenger.send(SJAAK_GA, { t = "HELLO" })
    deliverSent(99)
    assert.are.same({}, received())
    assert.are.equal(1, Messenger.stats().dropped)
  end)

  it("ignores other addon prefixes", function()
    load()
    wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "OtherAddon", "m:1:1:x", "WHISPER", SJAAK_GA)
    assert.are.same({}, received())
    assert.are.equal(0, Messenger.stats().dropped)
  end)

  it("reports an unsupported protocol version", function()
    load()
    local serializer, deflate = helpers.lib("LibSerialize"), helpers.lib("LibDeflate")
    local future = deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(serializer:Serialize({ t = "X", pv = 9 })))
    wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "CommForever", "f1:1:1:" .. future, "WHISPER", SJAAK_GA)
    assert.are.same({ { 9, SJAAK } }, wowapi.sentMessages(state, Messenger.UNSUPPORTED))
  end)

  it("uses different message ids for consecutive messages", function()
    load()
    Messenger.send(SJAAK_GA, { t = "A" })
    flush()
    Messenger.send(SJAAK_GA, { t = "B" })
    flush()
    local id1 = state.bnSent[1][3]:match("^(%w+):")
    local id2 = state.bnSent[2][3]:match("^(%w+):")
    assert.are_not.equal(id1, id2)
  end)

  describe("/cf ping", function()
    it("pings friends, answers a ping with pong and reports the pong", function()
      load()
      state.slash.cf("ping 5000")
      flush()
      assert.matches("^Ping sent to 1 game account%(s%), 5000 bytes padding%.$", state.printed[1])

      -- Our own PING comes back as if Sjaak sent it: we print it and answer with PONG.
      local before = #state.bnSent
      deliverSent(SJAAK_GA)
      flush()
      assert.are.equal("Ping from Ves Doombringer (Sjaakovich#2232), 5000 bytes padding.", state.printed[2])
      assert.is_true(#state.bnSent > before)

      -- The PONG comes back too.
      deliverSent(SJAAK_GA, before + 1)
      assert.are.equal("Pong from Ves Doombringer (Sjaakovich#2232) for 5000 bytes.", state.printed[3])
    end)

    it("says when no friend is online", function()
      load()
      state.friends[1].gameAccounts[1].isOnline = false
      wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_OFFLINE")
      wowapi.runTimers(state)
      state.slash.cf("ping")
      assert.are.same({ "Ping: no friends online in Forever." }, state.printed)
    end)

    it("prints transport stats", function()
      load()
      Messenger.send(SJAAK_GA, { t = "HELLO" })
      state.slash.cf("ping stats")
      local expected = string.format("Messages: %d chunks sent, 0 received, 0 dropped, 0 queued, 0 resent, 0 missed.",
        baseline.sent + 1)
      assert.are.same({ expected },
        state.printed)
    end)
  end)
end)
