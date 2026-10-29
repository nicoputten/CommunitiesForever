local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("loot, gold, sessions and groups (CF-53)", function()
  local state, ns, addon, myGuid
  local TODAY = 20744 -- mock realm date 2026-10-18

  local function load(setup)
    state, ns, addon = helpers.client({ setup = setup })
    myGuid = state.player.guid
  end

  local function entry() return addon.db.global.self.feed[TODAY][myGuid] end
  local function link(id, name) return "|cffffffff|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r" end

  after_each(function()
    wowapi.uninstall()
  end)

  it("records rare and epic loot, quest rewards and watch-list items", function()
    load()
    state.items[1] = { quality = 3, slot = "INVTYPE_HEAD" }
    state.items[2] = { quality = 4, slot = "INVTYPE_2HWEAPON" }
    state.items[19807] = { quality = 1 }
    state.items[14342] = { quality = 1 }
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive loot: " .. link(1, "Blue Hat") .. ".")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive item: " .. link(2, "Purple Axe") .. ".")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You receive loot: " .. link(19807, "Speckled Tastyfish") .. "x2.")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "You create: " .. link(14342, "Mooncloth") .. ".")
    wowapi.fireEvent(state, "CHAT_MSG_LOOT", "Bob Example receives loot: " .. link(2, "Purple Axe") .. ".")
    assert.are.same({ rare = 1, epic = { { id = 2, name = "Purple Axe", slot = "INVTYPE_2HWEAPON", level = 11 } } },
      entry().loot)
    assert.are.same({ [19807] = 2, [14342] = 1 }, entry().notable)
  end)

  it("adds up gold gained and spent from money changes", function()
    load(function(s) s.money = 1000 end)
    state.money = 1500
    wowapi.fireEvent(state, "PLAYER_MONEY")
    state.money = 1200
    wowapi.fireEvent(state, "PLAYER_MONEY")
    assert.are.same({ gained = 500, spent = 300 }, entry().gold)
  end)

  it("starts a session at login without a sync of its own, ends it at logout, continues it after /reload", function()
    load()
    local version = addon.db.global.self.version
    assert.are.same({ { from = 1000, to = 1000 } }, entry().sessions)
    state.serverTime = 1900
    wowapi.fireEvent(state, "PLAYER_LOGOUT")
    assert.are.equal(1900, entry().sessions[1].to)
    assert.are.equal(version, addon.db.global.self.version)
    -- /reload: the same SavedVariables, a login moments later.
    local saved = addon.db.global
    wowapi.uninstall()
    load(function(s) s.serverTime = 2000 end)
    addon.db.global.self.feed = saved.self.feed
    ns.PlayTracker.start(addon)
    assert.are.same({ { from = 1000, to = 2000 } }, entry().sessions)
  end)

  it("moves the session's end with a heartbeat when C_Timer.NewTicker exists", function()
    local ticks = {}
    load(function() _G.C_Timer.NewTicker = function(seconds, fn) ticks[#ticks + 1] = { seconds, fn } end end)
    assert.are.equal(300, ticks[1][1])
    state.serverTime = 1300
    ticks[1][2]()
    assert.are.equal(1300, entry().sessions[1].to)
  end)

  it("records community characters you group with, once a day", function()
    load()
    local friend = state.clubMembers["23125681"][2].guid
    state.setGroup({ friend, "Player-1-STRANGER" })
    wowapi.fireEvent(state, "GROUP_ROSTER_UPDATE")
    wowapi.fireEvent(state, "GROUP_ROSTER_UPDATE")
    assert.are.same({ [friend] = true }, entry().groups)
  end)

  describe("riding skill", function()
    local function char() return addon.db.global.self.chars[myGuid] end

    it("is unknown without any riding API", function()
      load()
      assert.is_nil(char().riding)
    end)

    it("comes from the race's skill line by ID first", function()
      load(function()
        _G.C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function(id)
          return { skillLevel = id == 713 and 75 or 0 }
        end }
      end)
      assert.are.equal(75, char().riding)
      _G.C_TradeSkillUI = nil
    end)

    it("falls back to the Classic skill list, and keeps the value when it can't be read later", function()
      load(function()
        _G.GetNumSkillLines = function() return 3 end
        _G.GetSkillLineInfo = function(i)
          return unpack(({ { "Secondary Skills", true }, { "Cooking", false, nil, 40 },
                           { "Kodo Riding", false, nil, 150 } })[i])
        end
      end)
      assert.are.equal(150, char().riding)
      _G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
      wowapi.fireEvent(state, "PLAYER_LEVEL_UP", 12)
      assert.are.equal(150, char().riding)
    end)
  end)
end)
