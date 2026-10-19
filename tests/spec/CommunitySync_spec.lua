local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("sync over the community (CF-28 part 2b)", function()
  local state, ns, addon, codec
  local CLUB = "23125681"
  local DEE, DEE_GUID = "Dee Example", "Player-1-0000DEE1"
  local DEE_AID = "aid:dddddddddddd"
  local counter = 0

  local function load(prepare)
    state = wowapi.install()
    table.insert(state.clubMembers[CLUB], { memberId = 3, guid = DEE_GUID, name = DEE, classID = 4, level = 20,
      zone = "Durotar", presence = 1, race = 2, faction = 0, isSelf = false, clubType = 1, role = 4 })
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon.db.global.settings.onboarded = true
    addon.db.global.settings.chatTabPrompt = { [state.player.guid] = true }
    if prepare then prepare(addon.db.global) end
    addon:OnEnable()
    codec = ns.Protocol.codec(_G.LibStub("LibSerialize"), _G.LibStub("LibDeflate"))
  end

  local function flush()
    for _ = 1, 100 do
      state.time = state.time + 0.5
      wowapi.runTimers(state)
    end
  end

  -- Dee sends a message: encoded, in 255-byte parts, as addon whispers ("Name-Realm" sender).
  local function fromDee(message, sender)
    counter = counter + 1
    local chunks = ns.Protocol.chunk(codec:encode(message), "d" .. counter, 255)
    for _, chunk in ipairs(chunks) do
      wowapi.fireEvent(state, "CHAT_MSG_ADDON", "CommForever", chunk, "WHISPER", (sender or DEE) .. "-ClassicBetaPvP")
    end
  end

  -- Everything whispered to a character, decoded.
  local function whisperedTo(name)
    local r, messages = ns.Protocol.reassembler(), {}
    for _, w in ipairs(state.whispers) do
      if w[4] == name and w[1] == "CommForever" then
        assert.is_true(#w[2] <= 255, "whisper longer than 255 bytes")
        local encoded = r:add(name, w[2], 0)
        if encoded then messages[#messages + 1] = codec:decode(encoded) end
      end
    end
    return messages
  end

  local function ofType(messages, t)
    local result = {}
    for _, m in ipairs(messages) do if m.t == t then result[#result + 1] = m end end
    return result
  end

  -- True when a BattleTag ("Name#1234") appears anywhere in a value.
  local function hasBattleTag(value)
    if type(value) == "string" then return value:match("[%w]+#%d%d%d%d") ~= nil end
    if type(value) == "table" then
      for k, v in pairs(value) do
        if hasBattleTag(k) or hasBattleTag(v) then return true end
      end
    end
    return false
  end

  local function deeRecord(version, chars, extra)
    local r = { t = "RECORD", bt = DEE_AID, version = version, aid = "dddddddddddd", displayName = "Dee",
                chars = chars or { [DEE_GUID] = { name = DEE, classFile = "ROGUE", level = 20, updatedAt = 900 } } }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("makes an account ID and says HELLO to community members who are not Battle.net friends", function()
    load()
    flush()
    assert.is_true(ns.Identity.isAccountId(addon.db.global.self.accountId))
    local hellos = ofType(whisperedTo(DEE), "HELLO")
    assert.is_true(#hellos >= 1)
    assert.are.equal("aid:" .. addon.db.global.self.accountId, hellos[1].bt)
    -- The Battle.net friend (also a member) gets nothing over the community.
    assert.are.equal(0, #whisperedTo(state.clubMembers[CLUB][2].name))
    assert.is_false(hasBattleTag(whisperedTo(DEE)))
  end)

  it("asks for the record of a member who says HELLO, and marks them online", function()
    load()
    flush()
    state.whispers = {}
    fromDee({ t = "HELLO", bt = DEE_AID, ver = 950, known = {} })
    flush()
    local reqs = ofType(whisperedTo(DEE), "REQ")
    assert.are.equal(1, #reqs)
    assert.is_nil(reqs[1].want)
    assert.are.equal(DEE_GUID, ns.Sync.online()[DEE_AID].guid)
  end)

  it("stores the member's own record and shows them as a person", function()
    load()
    flush()
    fromDee(deeRecord(950))
    local person = addon.db.global.people[DEE_AID]
    assert.is_not_nil(person)
    assert.is_nil(person.via) -- direct: the record lists the sending character
    assert.are.equal("dddddddddddd", person.aid)
    local found
    for _, p in ipairs(ns.ViewModel.build(addon).people) do
      if p.battleTag == DEE_AID then found = p end
    end
    assert.are.equal("Dee", found.displayName)
    assert.are.equal(DEE_GUID, found.chars[1].guid)
  end)

  it("sends your record with the account ID key and no BattleTag", function()
    load()
    flush()
    state.whispers = {}
    fromDee({ t = "REQ", bt = DEE_AID })
    flush()
    local records = ofType(whisperedTo(DEE), "RECORD")
    assert.are.equal(1, #records)
    assert.are.equal("aid:" .. addon.db.global.self.accountId, records[1].bt)
    assert.is_false(hasBattleTag(records[1]))
  end)

  it("does not let one member pose as another with a learned account ID", function()
    load(function(global)
      global.people["aid:eeeeeeeeeeee"] = { version = 100, aid = "eeeeeeeeeeee", displayName = "Eve",
        chars = { ["Player-1-0000EEE1"] = { name = "Eve Example", level = 30, updatedAt = 800 } } }
    end)
    flush()
    -- Dee claims Eve's account ID, with only Dee's character in the record.
    fromDee(deeRecord(200, nil, { bt = "aid:eeeeeeeeeeee", aid = "eeeeeeeeeeee" }))
    local eve = addon.db.global.people["aid:eeeeeeeeeeee"]
    assert.is_not_nil(eve.chars["Player-1-0000EEE1"]) -- not removed: treated as relayed, not as Eve
    assert.are.equal("member:" .. DEE_GUID, eve.via)
  end)

  it("ignores whispers from characters outside the community and your own record", function()
    load()
    flush()
    fromDee(deeRecord(950), "Stranger Example")
    assert.is_nil(addon.db.global.people[DEE_AID])
    local ownBefore = addon.db.global.self.version
    fromDee(deeRecord(99999, nil, { bt = "aid:" .. addon.db.global.self.accountId }))
    assert.are.equal(ownBefore, addon.db.global.self.version)
    assert.is_nil(addon.db.global.people["aid:" .. addon.db.global.self.accountId])
  end)

  it("marks a member offline after BYE or a failed whisper", function()
    load()
    flush()
    fromDee({ t = "HELLO", bt = DEE_AID, ver = 950, known = {} })
    fromDee(deeRecord(950))
    assert.is_not_nil(ns.Sync.online()[DEE_AID])
    fromDee({ t = "BYE" })
    assert.is_nil(ns.Sync.online()[DEE_AID])
    assert.is_true(ns.Sync.offline()[DEE_GUID])
    local row
    for _, p in ipairs(ns.ViewModel.build(addon).people) do
      if p.battleTag == DEE_AID then row = p.chars[1] end
    end
    assert.is_false(row.online) -- the community presence still says online
    fromDee({ t = "HELLO", bt = DEE_AID, ver = 950, known = {} })
    assert.is_nil(ns.Sync.offline()[DEE_GUID])
    addon:SendMessage(ns.Transport.WHISPER_FAILED, DEE)
    assert.is_true(ns.Sync.offline()[DEE_GUID])
  end)

  it("merges a community copy into the BattleTag once a friend's record shows the account ID", function()
    load(function(global)
      global.people[DEE_AID] = { version = 900, aid = "dddddddddddd",
        chars = { [DEE_GUID] = { name = DEE, classFile = "ROGUE", level = 20, updatedAt = 900 } } }
    end)
    local people = addon.db.global.people
    ns.Merge.store(people, { bt = "Dee#4444", version = 950, aid = "dddddddddddd",
      chars = { ["Player-1-0000DEE2"] = { name = "Dee Alt", level = 5, updatedAt = 950 } } }, 1000, "Dee#4444")
    assert.is_true(ns.Merge.absorb(people, "Dee#4444", 1000))
    assert.is_nil(people[DEE_AID])
    assert.is_not_nil(people["Dee#4444"].chars[DEE_GUID])
    assert.is_not_nil(people["Dee#4444"].chars["Player-1-0000DEE2"])
    assert.is_nil(people["Dee#4444"].via)
  end)
end)
