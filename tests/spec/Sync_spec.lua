local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Sync", function()
  local state, ns, addon, codec

  local CLUB = "23125681"
  local ME, SJAAK, SJAAK_GA = "Vestras#2858", "Sjaakovich#2232", 5
  local VES = "Player-4619-01627852"
  local SJAAK_ALT = "Player-4619-0000ALT1"

  -- setup(state) runs before OnEnable to change mock data.
  local function load(setup)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    codec = ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
  end

  -- Runs timers (debounces, throttled sends) until nothing is pending.
  local function settle()
    for _ = 1, 100 do
      if #state.timers == 0 then return end
      state.time = state.time + 5
      wowapi.runTimers(state)
    end
  end

  -- Decodes everything this client sent so far (per target), then forgets it.
  local function outgoing()
    settle()
    local reassembler, messages = ns.Protocol.reassembler(), {}
    for _, call in ipairs(state.bnSent) do
      local encoded = reassembler:add(call[1], call[3], 0)
      if encoded then
        local message = codec:decode(encoded)
        message.to = call[1]
        messages[#messages + 1] = message
      end
    end
    state.bnSent = {}
    return messages
  end

  local function ofType(messages, kind)
    local found = {}
    for _, m in ipairs(messages) do
      if m.t == kind then found[#found + 1] = m end
    end
    return found
  end

  -- Delivers a message as if Sjaak's client sent it.
  local function fromSjaak(message, gameAccountID)
    local encoded = codec:encode(message)
    for _, chunk in ipairs(ns.Protocol.chunk(encoded, "s" .. tostring(math.random(1, 1e9)))) do
      wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "CommForever", chunk, "WHISPER", gameAccountID or SJAAK_GA)
    end
    settle()
  end

  local function sjaakRecord(version, chars)
    return { t = "RECORD", bt = SJAAK, displayName = "Sjaak", version = version,
             chars = chars or { [SJAAK_ALT] = { guid = SJAAK_ALT, name = "Alt Doombringer", classFile = "ROGUE",
                                                level = 30, updatedAt = 900 } } }
  end

  after_each(function()
    wowapi.uninstall()
  end)

  describe("HELLO", function()
    it("is sent to friends in Forever on login", function()
      load()
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(1, #hellos)
      assert.are.same({ SJAAK_GA, ME, addon.db.global.self.version }, { hellos[1].to, hellos[1].bt, hellos[1].ver })
    end)

    it("is sent 5 s after an own record change, even right after the login HELLO", function()
      load()
      outgoing()
      state.serverTime = 1010
      wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
      assert.are.equal(5, state.timers[#state.timers].seconds)
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(1, #hellos)
      assert.are.equal(addon.db.global.self.version, hellos[1].ver)
    end)

    it("is not repeated for the same version within 60 s", function()
      load()
      outgoing()
      addon:SendMessage(ns.SelfTracker.UPDATED) -- no real change
      assert.are.same({}, ofType(outgoing(), "HELLO"))
      state.serverTime = state.serverTime + 61
      addon:SendMessage(ns.SelfTracker.UPDATED)
      assert.are.equal(1, #ofType(outgoing(), "HELLO"))
    end)

    it("is sent to a friend who starts Forever", function()
      load(function(s) s.friends[1].gameAccounts[1].isOnline = false end)
      outgoing()
      state.friends[1].gameAccounts[1].isOnline = true
      wowapi.fireEvent(state, "BN_FRIEND_ACCOUNT_ONLINE")
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(1, #hellos)
      assert.are.equal(SJAAK_GA, hellos[1].to)
    end)

    it("is sent on /cf sync without dedupe", function()
      load()
      outgoing()
      state.slash.cf("sync")
      assert.are.equal(1, #ofType(outgoing(), "HELLO"))
      assert.are.equal("Sync: announced your record to friends online in Forever.", state.printed[1])
    end)
  end)

  describe("REQ", function()
    it("is sent when a friend advertises a newer version", function()
      load()
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000 })
      local reqs = ofType(outgoing(), "REQ")
      assert.are.equal(1, #reqs)
      assert.are.equal(SJAAK_GA, reqs[1].to)
    end)

    it("is not sent when the stored version is the same or newer", function()
      load()
      addon.db.global.people[SJAAK] = { version = 2000, chars = {} }
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000 })
      assert.are.same({}, ofType(outgoing(), "REQ"))
    end)

    it("is not sent for a HELLO claiming another BattleTag", function()
      load()
      outgoing()
      fromSjaak({ t = "HELLO", bt = "Other#1111", ver = 2000 })
      assert.are.same({}, ofType(outgoing(), "REQ"))
    end)

    it("is sent once per version within 60 s", function()
      load()
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000 })
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000 })
      assert.are.equal(1, #ofType(outgoing(), "REQ"))
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2001 })
      assert.are.equal(1, #ofType(outgoing(), "REQ"))
    end)
  end)

  describe("RECORD out", function()
    it("answers a REQ with all own characters, also those outside the community", function()
      load(function(s) s.player.guid = VES end)
      addon.db.global.self.chars["Player-4619-0000NOTM"] = { guid = "Player-4619-0000NOTM", name = "Not Member" }
      outgoing()
      fromSjaak({ t = "REQ", bt = SJAAK })
      local records = ofType(outgoing(), "RECORD")
      assert.are.equal(1, #records)
      assert.are.equal(ME, records[1].bt)
      assert.are.equal(addon.db.global.self.version, records[1].version)
      assert.is_not_nil(records[1].chars[VES])
      assert.is_not_nil(records[1].chars["Player-4619-0000NOTM"])
    end)

    it("answers right away, even before community member data has loaded", function()
      load(function(s) s.clubMembers[CLUB] = nil end)
      outgoing()
      fromSjaak({ t = "REQ", bt = SJAAK })
      local records = ofType(outgoing(), "RECORD")
      assert.are.equal(1, #records)
      assert.is_not_nil(records[1].chars[VES])
    end)

    it("does not change the version when community membership changes", function()
      load()
      outgoing()
      local before = addon.db.global.self.version
      state.clubMembers[CLUB][2].zone = "Durotar"
      wowapi.fireEvent(state, "CLUB_MEMBER_UPDATED", CLUB, 2)
      settle()
      assert.are.equal(before, addon.db.global.self.version)
    end)

    it("has no share setting any more", function()
      load()
      assert.is_nil(state.options.args.shareAlts)
    end)
  end)

  describe("RECORD in", function()
    it("stores a newer record from its owner and refreshes the window", function()
      load()
      outgoing()
      fromSjaak(sjaakRecord(2000))
      local stored = addon.db.global.people[SJAAK]
      assert.are.equal(2000, stored.version)
      assert.are.equal("Sjaak", stored.displayName)
      assert.is_not_nil(stored.chars[SJAAK_ALT])
      assert.are.same({ { SJAAK } }, wowapi.sentMessages(state, ns.Sync.PEOPLE_UPDATED))
    end)

    it("rejects older or equal versions", function()
      load()
      fromSjaak(sjaakRecord(2000))
      fromSjaak(sjaakRecord(2000, {}))
      fromSjaak(sjaakRecord(1500, {}))
      assert.is_not_nil(addon.db.global.people[SJAAK].chars[SJAAK_ALT])
    end)

    it("rejects a record spoofing another BattleTag", function()
      load()
      local spoof = sjaakRecord(2000)
      spoof.bt = "Other#1111"
      fromSjaak(spoof)
      assert.is_nil(addon.db.global.people["Other#1111"])
      assert.is_nil(addon.db.global.people[SJAAK])
    end)

    it("ignores records from game accounts that are not friends in Forever", function()
      load()
      fromSjaak(sjaakRecord(2000), 99)
      assert.is_nil(addon.db.global.people[SJAAK])
    end)

    it("links a friend's offline community alt from the record", function()
      load()
      table.insert(state.clubMembers[CLUB], { memberId = 3, guid = SJAAK_ALT, name = "Alt Doombringer",
                                              classID = 4, level = 30, presence = 3 })
      wowapi.fireEvent(state, "CLUB_MEMBER_ADDED", CLUB, 3)
      settle()
      fromSjaak(sjaakRecord(2000))
      local view = ns.ViewModel.build(addon)
      local sjaak
      for _, p in ipairs(view.people) do
        if p.battleTag == SJAAK then sjaak = p end
      end
      local alt
      for _, row in ipairs(sjaak.chars) do
        if row.guid == SJAAK_ALT then alt = row end
      end
      assert.are.equal("record", alt.linkSource)
      assert.are.equal("ROGUE", alt.classFile)
      assert.are.equal("Sjaak", sjaak.displayName)
    end)
  end)

  it("tells once per session when a friend uses a newer protocol", function()
    load()
    local serializer, deflate = helpers.lib("LibSerialize"), helpers.lib("LibDeflate")
    local future = deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(serializer:Serialize({ t = "X", pv = 2 })))
    wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "CommForever", "f1:1:1:" .. future, "WHISPER", SJAAK_GA)
    wowapi.fireEvent(state, "BN_CHAT_MSG_ADDON", "CommForever", "f2:1:1:" .. future, "WHISPER", SJAAK_GA)
    assert.are.same({ ns.Sync.NEWER_VERSION_NOTICE }, state.printed)
  end)
end)
