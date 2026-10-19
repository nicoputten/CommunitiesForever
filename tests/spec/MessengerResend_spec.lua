local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Messenger resend (CF-28)", function()
  local state, ns, addon, Messenger
  local FRIEND_GA = 5

  local function load()
    state = wowapi.install()
    ns = helpers.loadAddon()
    Messenger = ns.Messenger
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = "23125681"
    addon:OnEnable()
    for _ = 1, 50 do
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
    state.bnSent = {}
  end

  local function flush(seconds)
    for _ = 1, math.floor((seconds or 1) / 0.2) do
      state.time = state.time + 0.2
      wowapi.runTimers(state)
    end
  end

  local function fromFriend(text)
    wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "CommForever", text, "WHISPER", FRIEND_GA)
  end

  -- Pseudo-random padding, so compression cannot shrink it into one part.
  local function big()
    local t, seed = {}, 12345
    for i = 1, 12000 do
      seed = (seed * 1103515245 + 12345) % 2147483648
      t[i] = string.char(33 + math.floor(seed / 65536) % 90)
    end
    return { t = "PING", padding = table.concat(t) }
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("asks the sender for missing parts and completes when they arrive", function()
    load()
    -- Build the parts as a friend would send them: send to ourselves, capture, then replay with a gap.
    Messenger.send(FRIEND_GA, big())
    flush(5)
    local parts = {}
    for _, call in ipairs(state.bnSent) do parts[#parts + 1] = call[3] end
    assert.is_true(#parts >= 3)
    state.bnSent = {}
    for i, text in ipairs(parts) do
      if i ~= 2 then fromFriend(text) end
    end
    flush(4)
    local miss
    for _, call in ipairs(state.bnSent) do
      if call[3]:sub(1, 3) == "!M:" then miss = call end
    end
    assert.is_not_nil(miss)
    assert.are.equal(FRIEND_GA, miss[1])
    assert.is_truthy(miss[3]:match(":2$"))
    fromFriend(parts[2])
    local got
    for _, m in ipairs(wowapi.sentMessages(state, Messenger.RECEIVED)) do
      if m[1] and m[1].t == "PING" then got = m[1] end
    end
    assert.are.equal(big().padding, got.padding)
    assert.are.equal(1, Messenger.stats().missed)
  end)

  it("resends asked parts to the one who asked, twice at most", function()
    load()
    Messenger.send(FRIEND_GA, big())
    flush(5)
    local second = state.bnSent[2][3]
    local msgId = second:match("^(%w+):")
    state.bnSent = {}
    fromFriend("!M:" .. msgId .. ":2")
    flush(1)
    assert.are.equal(1, #state.bnSent)
    assert.are.equal(second, state.bnSent[1][3])
    fromFriend("!M:" .. msgId .. ":2")
    fromFriend("!M:" .. msgId .. ":2")
    flush(1)
    assert.are.equal(2, #state.bnSent)
    assert.are.equal(2, Messenger.stats().resent)
  end)

  it("traces parts, misses and resends with /cf sync debug", function()
    load()
    addon:OnSlashCommand("sync debug")
    assert.is_true(addon.db.global.settings.syncDebug)
    state.printed = {}
    Messenger.send(FRIEND_GA, big())
    flush(5)
    local msgId = state.bnSent[1][3]:match("^(%w+):")
    fromFriend("!M:" .. msgId .. ":1")
    flush(1)
    local text = table.concat(state.printed, "\n")
    assert.is_truthy(text:find("[sync]|r to ", 1, true))
    assert.is_truthy(text:find("PING " .. msgId .. " in ", 1, true))
    assert.is_truthy(text:find("resent 1 part(s) of " .. msgId, 1, true))
    addon:OnSlashCommand("sync debug")
    assert.is_nil(addon.db.global.settings.syncDebug)
  end)
end)
