local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-83: the guild picked as the community, next to character communities. Data stays keyed by GUID and friend;
-- only the member list changes, so switching back and forth loses nothing and needs no reload.
describe("the guild as the community (CF-83)", function()
  local state, ns, addon
  local COMMUNITY, GUILD = "23125681", "999"
  local ME = "Player-4619-01627852"
  local GUILDIE = "Player-4619-0AAAA001"

  local function load(clubId)
    state, ns, addon = helpers.client({ clubId = clubId, setup = function(s)
      s.clubMembers[GUILD] = {
        { memberId = 1, guid = ME, name = "Ves Doombringer", classID = 2, level = 11, zone = "Durotar",
          presence = 1, race = 6, faction = 0, isSelf = true, clubType = 2, role = 4 },
        { memberId = 7, guid = GUILDIE, name = "Ada Stormwind", classID = 1, level = 20, zone = "Barrens",
          presence = 1, race = 2, faction = 0, isSelf = false, clubType = 2, role = 4 },
      }
    end })
  end

  local function memberGuids()
    local guids = {}
    for guid in pairs(ns.MemberTracker.members()) do guids[#guids + 1] = guid end
    table.sort(guids)
    return guids
  end

  -- CHAT_MSG_GUILD: arg 12 the sender GUID (as CHAT_MSG_COMMUNITIES_CHANNEL, V125).
  local function guildChat(senderGuid)
    wowapi.fireEvent(state, "CHAT_MSG_GUILD", "hi", "Sender Name", "", "", "", "", 0, 0, "", 0, 0, senderGuid)
  end

  local function chatMissions()
    local found = {}
    for _, m in ipairs(wowapi.sentMessages(state, ns.DoomsdayTracker.MISSION_EVENT)) do
      if m[1] == "placeChat" then found[#found + 1] = m end
    end
    return #found
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("switches guild, community, guild without a reload and without losing data", function()
    load(GUILD)
    local db = addon.db.global
    db.people["Ada#1001"] = { displayName = "Ada", chars = { [GUILDIE] = { name = "Ada Stormwind", level = 20 } } }
    local chars = db.self.chars
    assert.is_true(ns.CommunitySelection.isGuild())
    assert.are.equal("My Guild", ns.CommunitySelection.name())
    assert.are.same({ ME, GUILDIE }, memberGuids())

    ns.CommunitySelection.select(COMMUNITY)
    assert.is_false(ns.CommunitySelection.isGuild())
    assert.are.equal(COMMUNITY, ns.CommunitySelection.active())
    assert.are.equal("Forever Friends", ns.CommunitySelection.name())
    assert.are.same({ "Player-4619-01627852", "Player-4619-01789956" }, memberGuids())

    ns.CommunitySelection.select(GUILD)
    assert.is_true(ns.CommunitySelection.isGuild())
    assert.are.equal(GUILD, ns.CommunitySelection.active())
    assert.are.same({ ME, GUILDIE }, memberGuids())
    -- Everything carries over: friends, their characters and the own characters stay as they were.
    assert.are.equal(20, db.people["Ada#1001"].chars[GUILDIE].level)
    assert.are.equal(chars, db.self.chars)
    assert.is_truthy(db.self.chars[ME])
  end)

  it("remembers the guild's type for characters outside it", function()
    load(GUILD)
    assert.are.equal(2, addon.db.global.settings.clubType)
    ns.CommunitySelection.select(COMMUNITY)
    assert.are.equal(1, addon.db.global.settings.clubType)
  end)

  it("counts own guild chat for the community chat missions only while the guild is picked", function()
    load(GUILD)
    guildChat(GUILDIE)
    assert.are.equal(0, chatMissions()) -- someone else
    guildChat(ME)
    assert.are.equal(1, chatMissions())
    guildChat(nil) -- no GUID: nobody's
    assert.are.equal(1, chatMissions())

    ns.CommunitySelection.select(COMMUNITY)
    guildChat(ME)
    assert.are.equal(1, chatMissions()) -- guild chat is not the community's chat
    wowapi.fireEvent(state, "CHAT_MSG_COMMUNITIES_CHANNEL", "|Kx1|k", "Me", "", "6. x", "", "", 0, 6,
      "Community:23125681:1", 0, 0, ME)
    assert.are.equal(2, chatMissions())
  end)

  it("leaves the community chat features out for a guild", function()
    load(GUILD)
    assert.is_nil(ns.CommunityChat.channel())
    assert.are.equal("none", ns.CommunityChat.applyColor())
    assert.is_false(ns.CommunityChat.createTab())
    assert.are.same({ "Your community is a guild: guild chat already has its place in your chat windows." },
      state.printed)
    ns.CommunitySelection.select(COMMUNITY)
    assert.are.equal("Community:23125681:1", ns.CommunityChat.channel())
  end)

  it("hides invite links while the guild is picked", function()
    load(GUILD)
    state.clubMembers[GUILD][1].role = 1 -- the guild master
    addon:SendMessage(ns.Community.MEMBERS_CHANGED, "CLUB_MEMBER_UPDATED", GUILD)
    local db = addon.db.global
    db.people["Ada#1001"] = { invite = { clubId = GUILD, code = "abcd1234", setAt = 100 } }
    assert.is_false(ns.Invites.canSet())
    assert.is_nil(ns.Invites.current())
    assert.is_true(ns.Settings.options().args.inviteLink.hidden())
    local plan = ns.Setup.plan()
    assert.is_true(plan == nil or plan.kind ~= "chatPrompt") -- no Community tab prompt for a guild

    ns.CommunitySelection.select(COMMUNITY) -- owner there (role 1 in the mock)
    assert.is_true(ns.Invites.canSet())
  end)
end)
