local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Sync", function()
  local state, ns, addon, codec

  local CLUB = "23125681"
  local ME, SJAAK, SJAAK_GA = "Vestras#1000", "Sjaakovich#2232", 5
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
      local hasHelloTimer = false
      for _, timer in ipairs(state.timers) do
        if timer.seconds == 5 then hasHelloTimer = true end
      end
      assert.is_true(hasHelloTimer) -- HELLO debounce
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
      assert.are.equal("Sjaakovich", bram.viaName)
      local detail = ns.Format.detail(view, BRAM, 3000 + 3 * 3600)
      assert.are.equal("Updated 3 h ago via Sjaakovich", detail.source)
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
      end)
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

    it("announces a friend's character reaching a new level", function()
      loadWithAlt()
      levelTo(31, 5000)
      assert.are.same({ "Sjaak's Alt Doombringer reached level 31" }, state.printed)
    end)

    it("stays quiet for unchanged levels and characters seen for the first time", function()
      loadWithAlt()
      levelTo(30, 5000)
      fromSjaak(sjaakRecord(5001, {
        [SJAAK_ALT] = { guid = SJAAK_ALT, name = "Alt Doombringer", level = 30, updatedAt = 5001 },
        ["Player-4619-0000NEW9"] = { guid = "Player-4619-0000NEW9", name = "Brand New", level = 9, updatedAt = 5001 },
      }))
      assert.are.same({}, state.printed)
    end)

    it("stays quiet for level-ups older than 15 minutes (late relayed records)", function()
      loadWithAlt()
      state.serverTime = 5000 + 16 * 60
      levelTo(31, 5001, 5000)
      assert.are.same({}, state.printed)
    end)

    it("can be switched off in settings", function()
      loadWithAlt()
      ns.Settings.options().args.levelUps.set({}, false)
      levelTo(31, 5000)
      assert.are.same({}, state.printed)
    end)

    -- CF-44: the announcement at the top of the screen, by the same rules as the chat line.
    local function toasts()
      local list = {}
      for i, text in ipairs(ns.LevelUpToast.shown()) do
        list[i] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
      end
      return list
    end

    it("shows the level-up at the top of the screen too", function()
      loadWithAlt()
      levelTo(31, 5000)
      assert.are.same({ "Sjaak's Alt Doombringer reached level 31" }, toasts())
      local toast = ns.LevelUpToast.frame()
      assert.are.equal("LEVEL UP", toast.chip.text:GetText())
      assert.are.equal("ROGUE", toast.portrait.classFile) -- from the member's classID
      assert.is_false(toast.shown) -- gone after its 6 seconds (the spec ran the timers)
    end)

    it("shows no announcement when it is off or old, and works without the chat line", function()
      loadWithAlt()
      ns.Settings.options().args.levelUpToast.set({}, false)
      levelTo(31, 5000)
      assert.are.same({}, toasts())
      assert.are.same({ "Sjaak's Alt Doombringer reached level 31" }, state.printed) -- the chat line stays
      ns.Settings.options().args.levelUpToast.set({}, true)
      ns.Settings.options().args.levelUps.set({}, false)
      state.serverTime = 5000 + 16 * 60
      levelTo(32, 5002, 5001)
      assert.are.same({}, toasts()) -- older than 15 minutes
      levelTo(33, 5003, state.serverTime)
      assert.are.same({ "Sjaak's Alt Doombringer reached level 33" }, toasts())
      assert.are.equal(1, #state.printed) -- no second chat line
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
