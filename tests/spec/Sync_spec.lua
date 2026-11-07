local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Sync", function()
  local state, ns, addon, codec

  local CLUB = "23125681"
  local ME, SJAAK, SJAAK_GA = "Vestras#1000", "Solvar#2032", 5
  local VES = "Player-4619-01627852"
  local SJAAK_ALT = "Player-4619-0000ALT1"

  -- setup(state) runs before OnEnable to change mock data; prepare(global) to change stored data.
  local function load(setup, prepare)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    codec = ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    if prepare then prepare(addon.db.global) end
    addon:OnEnable()
  end

  -- CF-89: the roster stored at an earlier login (you and Garraka, the character Sjaak is on).
  local function storedRoster(global)
    global.members = { [VES] = { name = "Ves Doombringer", seenAt = 1 },
                       ["Player-4619-01789956"] = { name = "Garraka Doombringer", seenAt = 1 } }
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

  -- Delivers a message as if Sjaak's client sent it (each with its own message id, CF-59: no random ids).
  local sentBySjaak = 0
  local function fromSjaak(message, gameAccountID)
    local encoded = codec:encode(message)
    sentBySjaak = sentBySjaak + 1
    for _, chunk in ipairs(ns.Protocol.chunk(encoded, "s" .. sentBySjaak)) do
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
      local hasHelloTimer = false
      for _, timer in ipairs(state.timers) do
        if timer.seconds == 5 then hasHelloTimer = true end
      end
      assert.is_true(hasHelloTimer) -- HELLO debounce
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(1, #hellos)
      assert.are.equal(addon.db.global.self.version, hellos[1].ver)
    end)

    -- AceEvent calls the objects listening to one event in no fixed order: SelfTracker's snapshot bump and the
    -- records missions' level-up (RecordEvents, a done mission) both listen to the level-up.
    it("is sent once for a level-up whatever order its handlers run in", function()
      for _, reversed in ipairs({ false, true }) do
        load()
        outgoing()
        if reversed then
          local order = state.handlerOrder[state.messageHandlers[ns.SelfInfo.CHANGED]]
          for i = 1, math.floor(#order / 2) do order[i], order[#order + 1 - i] = order[#order + 1 - i], order[i] end
        end
        state.serverTime = 1010
        wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
        local hellos = ofType(outgoing(), "HELLO")
        assert.are.equal(1, #hellos)
        assert.are.equal(1010, hellos[1].ver)
        assert.are.equal(1010, addon.db.global.self.version)
        wowapi.uninstall()
      end
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

  -- CF-89: Battle.net friends without a character in the selected community are left alone.
  describe("members only", function()
    local OUT_GA = 9

    -- A second Battle.net friend in Forever, on a character outside the community.
    local function withOutsider(s)
      s.friends[#s.friends + 1] = { battleTag = "Out#4444", gameAccounts = {
        { clientProgram = "WoW", wowProjectID = 18, isOnline = true, characterName = "Out Example",
          playerGuid = "Player-4619-0000OUT1", gameAccountID = OUT_GA, characterLevel = 20 } } }
    end

    local function to(messages, target)
      local found = {}
      for _, m in ipairs(messages) do if m.to == target then found[#found + 1] = m end end
      return found
    end

    it("sends no HELLO to a friend outside the community", function()
      load(withOutsider)
      local sent = outgoing()
      assert.are.equal(1, #ofType(to(sent, SJAAK_GA), "HELLO"))
      assert.are.same({}, to(sent, OUT_GA))
      state.slash.cf("sync")
      assert.are.same({}, to(outgoing(), OUT_GA))
    end)

    it("ignores their HELLO and records, and stores nothing of them", function()
      load(withOutsider)
      outgoing()
      fromSjaak({ t = "HELLO", bt = "Out#4444", ver = 5000, known = {} }, OUT_GA)
      fromSjaak({ t = "RECORD", bt = "Out#4444", version = 5000,
                  chars = { ["Player-4619-0000OUT1"] = { name = "Out Example", level = 20 } } }, OUT_GA)
      fromSjaak({ t = "REQ", bt = "Out#4444" }, OUT_GA)
      assert.are.same({}, to(outgoing(), OUT_GA))
      assert.is_nil(addon.db.global.people["Out#4444"])
      assert.is_nil(addon.db.global.presence["Player-4619-0000OUT1"])
    end)

    it("syncs with a friend who belongs while they play an alt outside the community", function()
      load(function(s)
        s.friends[1].gameAccounts[1].playerGuid = SJAAK_ALT
      end, function(global)
        global.presence["Player-4619-01789956"] = { battleTag = SJAAK, lastSeen = 1 } -- seen on Garraka before
      end)
      assert.are.equal(1, #ofType(to(outgoing(), SJAAK_GA), "HELLO"))
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000, known = {} })
      assert.are.equal(1, #ofType(outgoing(), "REQ"))
      assert.are.equal(SJAAK, addon.db.global.presence[SJAAK_ALT].battleTag)
    end)

    it("sends nothing at all without a selected community", function()
      state = wowapi.install()
      ns = helpers.loadAddon()
      addon = state.addon
      addon:OnInitialize()
      addon.db.global.settings.clubId = nil
      addon:OnEnable()
      codec = ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
      assert.are.same({}, outgoing())
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000, known = {} })
      assert.are.same({}, outgoing())
      assert.is_nil(addon.db.global.people[SJAAK])
    end)

    it("on the first login keeps a HELLO until the members have loaded, then answers friends who belong", function()
      local later
      load(function(s)
        withOutsider(s)
        later = s.clubMembers[CLUB]
        s.clubMembers[CLUB] = nil
      end)
      assert.are.same({}, outgoing()) -- not known yet who belongs: nothing sent
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000, known = {} })
      fromSjaak({ t = "HELLO", bt = "Out#4444", ver = 5000, known = {} }, OUT_GA)
      assert.are.same({}, outgoing())
      state.clubMembers[CLUB] = later
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
      local sent = outgoing()
      assert.are.equal(1, #ofType(to(sent, SJAAK_GA), "REQ"))
      assert.are.equal(1, #ofType(to(sent, SJAAK_GA), "HELLO"))
      assert.are.same({}, to(sent, OUT_GA))
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

    it("answers right away at login, before community member data has loaded (roster stored last time)", function()
      load(function(s) s.clubMembers[CLUB] = nil end, storedRoster)
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
      assert.is_nil(ns.Settings.options().args.shareAlts)
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

  describe("relay (CF-20)", function()
    local BRAM = "Bram#4444" -- not our Battle.net friend; Sjaak relays his record
    local BRAM_CHAR = "Player-4619-0000BRAM"

    local function bramRecord(version)
      return { t = "RECORD", bt = BRAM, displayName = "Bram", version = version,
               chars = { [BRAM_CHAR] = { guid = BRAM_CHAR, name = "Bram Stonefist", classFile = "WARRIOR",
                                         level = 40, updatedAt = version } } }
    end

    local function loadWithBram()
      load()
      table.insert(state.clubMembers[CLUB], { memberId = 7, guid = BRAM_CHAR, name = "Bram Stonefist",
                                              classID = 1, level = 40, presence = 3 })
      wowapi.fireEvent(state, "CLUB_MEMBER_ADDED", CLUB, 7)
      settle()
      outgoing()
    end

    it("asks a friend for records it knows newer versions of", function()
      loadWithBram()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 1, known = { [BRAM] = 3000 } })
      local reqs = ofType(outgoing(), "REQ")
      local wanted = {}
      for _, r in ipairs(reqs) do wanted[tostring(r.want)] = true end
      assert.is_true(wanted[BRAM])
    end)

    it("does not ask for our own record or for versions it already has", function()
      loadWithBram()
      addon.db.global.people[BRAM] = { version = 3000, chars = {} }
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 1, known = { [BRAM] = 3000, [ME] = 99999 } })
      for _, r in ipairs(ofType(outgoing(), "REQ")) do
        assert.is_nil(r.want)
      end
    end)

    it("stores a relayed record with via and links its owner although he is no friend", function()
      loadWithBram()
      state.serverTime = 3000
      fromSjaak(bramRecord(3000))
      local stored = addon.db.global.people[BRAM]
      assert.are.equal(3000, stored.version)
      assert.are.equal(SJAAK, stored.via)

      local view = ns.ViewModel.build(addon)
      local bram
      for _, p in ipairs(view.people) do
        if p.battleTag == BRAM then bram = p end
      end
      assert.are.equal("Bram", bram.displayName)
      assert.are.equal("record", bram.chars[1].linkSource)
      assert.are.equal("Solvar", bram.viaName)
      local detail = ns.Card.detail(view, BRAM, 3000 + 3 * 3600)
      assert.are.equal("Updated 3 h ago via Solvar", detail.source)
    end)

    it("rejects relayed records of our own BattleTag, far-future versions and outsiders", function()
      loadWithBram()
      local own = bramRecord(3000)
      own.bt = ME
      fromSjaak(own)
      fromSjaak(bramRecord(state.serverTime + 301))
      local outsider = bramRecord(3000)
      outsider.bt = "Stranger#5"
      outsider.chars = { ["Player-1-NOPE"] = { name = "Nope" } }
      fromSjaak(outsider)
      assert.is_nil(addon.db.global.people[BRAM])
      assert.is_nil(addon.db.global.people["Stranger#5"])
      assert.are.equal(addon.db.global.self.battleTag, ME)
    end)

    it("keeps a relayed record that arrives before member data has loaded, then accepts it", function()
      local members
      load(function(s)
        members = s.clubMembers[CLUB]
        s.clubMembers[CLUB] = nil -- login: community members not loaded yet
      end, storedRoster)
      table.insert(members, { memberId = 7, guid = BRAM_CHAR, name = "Bram Stonefist", classID = 1, level = 40,
                              presence = 3 })
      outgoing()
      state.serverTime = 3000
      fromSjaak(bramRecord(3000))
      assert.is_nil(addon.db.global.people[BRAM]) -- cannot check the community yet

      state.clubMembers[CLUB] = members
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
      settle()
      assert.are.equal(3000, addon.db.global.people[BRAM].version)
      assert.are.equal(SJAAK, addon.db.global.people[BRAM].via)
    end)

    it("still drops a relayed record without a community character once members are known", function()
      loadWithBram()
      local outsider = bramRecord(3000)
      outsider.chars = { ["Player-1-NOPE"] = { name = "Nope" } }
      fromSjaak(outsider)
      wowapi.fireEvent(state, "CLUB_MEMBERS_UPDATED", CLUB)
      settle()
      assert.is_nil(addon.db.global.people[BRAM])
    end)

    it("answers a REQ for a stored record with that record", function()
      loadWithBram()
      addon.db.global.people[BRAM] = { version = 3000, displayName = "Bram",
                                       chars = bramRecord(3000).chars }
      fromSjaak({ t = "REQ", bt = SJAAK, want = BRAM })
      local records = ofType(outgoing(), "RECORD")
      assert.are.equal(1, #records)
      assert.are.equal(BRAM, records[1].bt)
      assert.are.equal(3000, records[1].version)
    end)

    it("lists relayable records in HELLO, and says HELLO after accepting a new one", function()
      loadWithBram()
      state.serverTime = 3000
      fromSjaak(bramRecord(3000))
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(1, #hellos)
      assert.are.equal(3000, hellos[1].known[BRAM])
    end)

    it("replaces a relayed copy with the owner's own record, even at a lower version", function()
      load()
      addon.db.global.people[SJAAK] = { version = 9000, via = "Anna#3333", chars = {} }
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 2000 })
      local reqs = ofType(outgoing(), "REQ")
      assert.are.equal(1, #reqs)
      assert.is_nil(reqs[1].want)
      fromSjaak(sjaakRecord(2000))
      assert.are.equal(2000, addon.db.global.people[SJAAK].version)
      assert.is_nil(addon.db.global.people[SJAAK].via)
    end)
  end)

  -- CF-46: planned runs travel between addons; the newer updatedAt wins.
  describe("planned runs (CF-46)", function()
    local NOW = 1793120000

    local function runs(updatedAt)
      return { updatedAt = updatedAt, reminderMinutes = 30,
               runs = { { id = "r1", dungeon = "dm", startsAt = NOW + 3600,
                          organiser = { battleTag = "Ada#1001", name = "Ada Lovewell" },
                          answers = { { battleTag = "Ada#1001", name = "Ada Lovewell", answer = "in" } } } } }
    end

    -- file: CF_RUNS as Data\Runs.lua sets it.
    local function loadRuns(file)
      load(function(s)
        s.serverTime = NOW
        local install = helpers.loadAddon
        helpers.loadAddon = function()
          local loaded = install()
          _G.CF_RUNS = file
          return loaded
        end
        s.restoreLoad = function() helpers.loadAddon = install end
      end)
      state.restoreLoad()
    end

    local function hello(ru)
      return { t = "HELLO", bt = SJAAK, ver = 0, ru = ru }
    end

    after_each(function() _G.CF_RUNS = nil end)

    it("says in HELLO how new its runs are (0: none)", function()
      loadRuns(nil)
      assert.are.equal(0, ofType(outgoing(), "HELLO")[1].ru)
      wowapi.uninstall()
      loadRuns(runs(NOW - 60))
      assert.are.equal(NOW - 60, ofType(outgoing(), "HELLO")[1].ru)
    end)

    it("sends its runs to a friend with older ones, BattleTags included over Battle.net", function()
      loadRuns(runs(NOW - 60))
      outgoing()
      fromSjaak(hello(NOW - 600))
      local sent = ofType(outgoing(), "RUNS")
      assert.are.equal(1, #sent)
      assert.are.equal(NOW - 60, sent[1].runs.updatedAt)
      assert.are.equal("Ada#1001", sent[1].runs.runs[1].organiser.battleTag)
      fromSjaak(hello(NOW - 600)) -- the same again within a minute: not resent
      assert.are.equal(0, #ofType(outgoing(), "RUNS"))
    end)

    it("asks a friend with newer runs, and takes them", function()
      loadRuns(runs(NOW - 600))
      outgoing()
      fromSjaak(hello(NOW - 60))
      assert.are.equal(1, #ofType(outgoing(), "RUNREQ"))
      fromSjaak({ t = "RUNS", runs = runs(NOW - 60) })
      assert.are.equal(NOW - 60, ns.Planner.updatedAt())
      assert.are.equal(NOW - 60, addon.db.global.plannedRuns.updatedAt) -- kept for the next session
      -- And tells the others (HELLO with the new ru).
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(NOW - 60, hellos[#hellos].ru)
    end)

    it("answers RUNREQ with its runs", function()
      loadRuns(runs(NOW - 60))
      outgoing()
      fromSjaak({ t = "RUNREQ" })
      assert.are.equal(1, #ofType(outgoing(), "RUNS"))
    end)

    it("ignores older, broken and far-future runs", function()
      loadRuns(runs(NOW - 60))
      fromSjaak({ t = "RUNS", runs = runs(NOW - 600) })
      fromSjaak({ t = "RUNS", runs = "nope" })
      fromSjaak({ t = "RUNS", runs = runs(NOW + 3600) })
      assert.are.equal(NOW - 60, ns.Planner.updatedAt())
    end)

    it("sends nothing about runs to an older client (HELLO without ru)", function()
      loadRuns(runs(NOW - 60))
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 0 })
      local sent = outgoing()
      assert.are.equal(0, #ofType(sent, "RUNS"))
      assert.are.equal(0, #ofType(sent, "RUNREQ"))
    end)

    it("holds runs back during a PvP match and sends them after", function()
      loadRuns(runs(NOW - 60))
      outgoing()
      state.instance = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
      fromSjaak(hello(0))
      assert.are.equal(0, #ofType(outgoing(), "RUNS"))
      state.instance = { name = "Kalimdor", type = "none", instanceID = 1 }
      state.time = state.time + 30
      wowapi.runTimers(state)
      assert.are.equal(1, #ofType(outgoing(), "RUNS"))
    end)
  end)

  -- CF-68: the site's Doomsday mission schedule travels like planned runs; the newer v wins.
  describe("the mission schedule (CF-68)", function()
    local NOW = 1794500000 -- Doomsday day 20768 (CET, 19:00 reset), week 2967

    local function schedule(v)
      return { v = v, days = { ["20771"] = { skirmish = "p.loneWolf" } },
               weeks = { ["2968"] = { bounty = "b.zone25" } } }
    end

    local function loadSchedule(stored)
      load(function(s)
        s.serverTime = NOW
        if stored then s.savedVariables = { global = { doomsdaySchedule = stored } } end
      end)
    end

    local function hello(ds)
      return { t = "HELLO", bt = SJAAK, ver = 0, ds = ds }
    end

    it("says in HELLO how new its schedule is (0: none)", function()
      loadSchedule(nil)
      assert.are.equal(0, ofType(outgoing(), "HELLO")[1].ds)
      wowapi.uninstall()
      loadSchedule(schedule(NOW - 60))
      assert.are.equal(NOW - 60, ofType(outgoing(), "HELLO")[1].ds)
    end)

    it("asks a friend with a newer schedule, takes it and tells the others", function()
      loadSchedule(schedule(NOW - 600))
      outgoing()
      fromSjaak(hello(NOW - 60))
      assert.are.equal(1, #ofType(outgoing(), "SCHEDREQ"))
      fromSjaak(hello(NOW - 60)) -- the same again within a minute: not asked again
      assert.are.equal(0, #ofType(outgoing(), "SCHEDREQ"))
      local incoming = schedule(NOW - 60)
      fromSjaak({ t = "SCHED", v = incoming.v, days = incoming.days, weeks = incoming.weeks })
      assert.are.same(incoming, addon.db.global.doomsdaySchedule)
      local hellos = ofType(outgoing(), "HELLO")
      assert.are.equal(NOW - 60, hellos[#hellos].ds)
    end)

    it("answers SCHEDREQ with its schedule, and asks nothing of a friend with an older one", function()
      loadSchedule(schedule(NOW - 60))
      outgoing()
      fromSjaak(hello(NOW - 600))
      assert.are.equal(0, #ofType(outgoing(), "SCHEDREQ"))
      fromSjaak({ t = "SCHEDREQ" })
      local sent = ofType(outgoing(), "SCHED")
      assert.are.equal(1, #sent)
      assert.are.same(schedule(NOW - 60), { v = sent[1].v, days = sent[1].days, weeks = sent[1].weeks })
    end)

    it("ignores an older, a broken and a far-future schedule", function()
      loadSchedule(schedule(NOW - 60))
      fromSjaak({ t = "SCHED", v = NOW - 600, days = {} })
      fromSjaak({ t = "SCHED", v = "x" })
      fromSjaak({ t = "SCHED", v = NOW + 301, days = {} })
      assert.are.equal(NOW - 60, ns.DoomsdayTracker.missionScheduleVersion())
      fromSjaak({ t = "SCHED", v = NOW + 300 }) -- an empty newer one clears
      assert.are.same({ v = NOW + 300 }, addon.db.global.doomsdaySchedule)
    end)

    it("asks nothing of an older client (HELLO without ds) and has nothing to answer without one", function()
      loadSchedule(nil)
      outgoing()
      fromSjaak({ t = "HELLO", bt = SJAAK, ver = 0 })
      fromSjaak({ t = "SCHEDREQ" })
      local sent = outgoing()
      assert.are.equal(0, #ofType(sent, "SCHEDREQ"))
      assert.are.equal(0, #ofType(sent, "SCHED"))
    end)

    it("holds the schedule back during a PvP match and sends it after", function()
      loadSchedule(schedule(NOW - 60))
      outgoing()
      state.instance = { name = "Warsong Gulch", type = "pvp", instanceID = 489 }
      fromSjaak({ t = "SCHEDREQ" })
      assert.are.equal(0, #ofType(outgoing(), "SCHED"))
      state.instance = { name = "Kalimdor", type = "none", instanceID = 1 }
      state.time = state.time + 30
      wowapi.runTimers(state)
      assert.are.equal(1, #ofType(outgoing(), "SCHED"))
    end)
  end)

  describe("level-up announcements (CF-16)", function()
    -- Sjaak's alt is a community member, so it is visible and linked through his record.
    local function loadWithAlt()
      load()
      table.insert(state.clubMembers[CLUB], { memberId = 3, guid = SJAAK_ALT, name = "Alt Doombringer",
                                              classID = 4, level = 30, presence = 3 })
      wowapi.fireEvent(state, "CLUB_MEMBER_ADDED", CLUB, 3)
      settle()
      state.serverTime = 5000
      fromSjaak(sjaakRecord(4000, { [SJAAK_ALT] = { guid = SJAAK_ALT, name = "Alt Doombringer", level = 30,
                                                    updatedAt = 4000 } }))
      state.printed = {}
    end

    local function levelTo(level, version, updatedAt)
      fromSjaak(sjaakRecord(version, { [SJAAK_ALT] = { guid = SJAAK_ALT, name = "Alt Doombringer", level = level,
                                                       updatedAt = updatedAt or version } }))
    end

    -- CF-44: the announcement at the top of the screen. CF-91: no chat line any more.
    local function toasts()
      local list = {}
      for i, text in ipairs(ns.LevelUpToast.shown()) do
        list[i] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
      end
      return list
    end

    it("announces a friend's character reaching a new level at the top of the screen, not in chat", function()
      loadWithAlt()
      levelTo(31, 5000)
      assert.are.same({ "Sjaak's Alt Doombringer reached level 31" }, toasts())
      assert.are.same({}, state.printed)
      local toast = ns.LevelUpToast.frame()
      assert.are.equal("LEVEL UP", toast.chip.text:GetText())
      assert.are.equal("ROGUE", toast.portrait.classFile) -- from the member's classID
      assert.is_false(toast.shown) -- gone after its 6 seconds (the spec ran the timers)
    end)

    it("stays quiet for unchanged levels and characters seen for the first time", function()
      loadWithAlt()
      levelTo(30, 5000)
      fromSjaak(sjaakRecord(5001, {
        [SJAAK_ALT] = { guid = SJAAK_ALT, name = "Alt Doombringer", level = 30, updatedAt = 5001 },
        ["Player-4619-0000NEW9"] = { guid = "Player-4619-0000NEW9", name = "Brand New", level = 9, updatedAt = 5001 },
      }))
      assert.are.same({}, toasts())
    end)

    it("shows no announcement when it is off or old", function()
      loadWithAlt()
      ns.Settings.options().args.levelUpToast.set({}, false)
      levelTo(31, 5000)
      assert.are.same({}, toasts())
      ns.Settings.options().args.levelUpToast.set({}, true)
      state.serverTime = 5000 + 16 * 60
      levelTo(32, 5002, 5001)
      assert.are.same({}, toasts()) -- older than 15 minutes (late relayed records)
      levelTo(33, 5003, state.serverTime)
      assert.are.same({ "Sjaak's Alt Doombringer reached level 33" }, toasts())
      assert.are.same({}, state.printed)
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
  -- CF-103: boss kills go to online friends at once; theirs are kept as if they came in their record.
  describe("boss kills live (CF-103)", function()
    local NOW = 1794500000
    local DEADMINES = { name = "Deadmines", type = "party", instanceID = 36 }

    local function loadAt()
      load(function(s) s.serverTime = NOW end)
    end

    local function kill(encounterID)
      state.instance = DEADMINES
      wowapi.fireEvent(state, "PLAYER_ENTERING_WORLD", false, false)
      wowapi.fireEvent(state, "ENCOUNTER_END", encounterID, "Boss", 1, 5, 1)
    end

    after_each(function()
      _G.IsEncounterInProgress = nil
    end)

    it("sends an own kill to online friends", function()
      loadAt()
      outgoing()
      kill(1001)
      local kills = ofType(outgoing(), "KILL")
      assert.are.equal(1, #kills)
      assert.are.equal(SJAAK_GA, kills[1].to)
      assert.are.same({ VES, 36, "Deadmines", 1001, NOW },
        { kills[1].guid, kills[1].instance, kills[1].name, kills[1].encounter, kills[1].at })
      assert.are.same({ [1001] = NOW }, addon.db.global.runs[VES].bosses)
    end)

    it("holds a kill back while messaging is restricted and sends it after", function()
      loadAt()
      outgoing()
      _G.IsEncounterInProgress = function() return true end
      kill(1001)
      assert.are.equal(0, #ofType(outgoing(), "KILL"))
      _G.IsEncounterInProgress = function() return false end
      state.time = state.time + 30
      wowapi.runTimers(state)
      assert.are.equal(1, #ofType(outgoing(), "KILL"))
    end)

    it("keeps a friend's kill, the earliest time per boss, and tells the window", function()
      loadAt()
      fromSjaak(sjaakRecord(2000))
      fromSjaak({ t = "KILL", guid = SJAAK_ALT, instance = 36, name = "Deadmines", encounter = 1001, at = NOW - 60 })
      fromSjaak({ t = "KILL", guid = SJAAK_ALT, instance = 36, name = "Deadmines", encounter = 1001, at = NOW - 30 })
      assert.are.same({ [SJAAK_ALT] = { [1001] = NOW - 60 } }, addon.db.global.liveKills)
      assert.are.equal(1, #wowapi.sentMessages(state, ns.ActivityTracker.KILLS_CHANGED))
      local kills = ns.ActivityTracker.kills({ SJAAK_ALT }, { 1001, 1002 }, NOW - 3600, NOW)
      assert.are.same({ [1001] = { at = NOW - 60, by = { [SJAAK_ALT] = NOW - 60 } } }, kills)
    end)

    it("ignores kills of other characters, from the future or without an encounter", function()
      loadAt()
      fromSjaak(sjaakRecord(2000))
      fromSjaak({ t = "KILL", guid = "Player-4619-SOMEONE", encounter = 1001, at = NOW })
      fromSjaak({ t = "KILL", guid = SJAAK_ALT, encounter = 1001, at = NOW + 600 })
      fromSjaak({ t = "KILL", guid = SJAAK_ALT, encounter = "x", at = NOW })
      fromSjaak({ t = "KILL", guid = SJAAK_ALT, encounter = 1001 })
      assert.are.same({}, addon.db.global.liveKills)
    end)
  end)
end)
