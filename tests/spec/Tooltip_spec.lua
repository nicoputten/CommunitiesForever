local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Tooltip (CF-14)", function()
  local state, ns, addon

  local CLUB = "23125681"
  local VES = "Player-4619-01627852"
  local GARRAKA = "Player-4619-01789956"
  local STRANGER = "Player-4619-0000STRA"

  local function load(setup)
    state = wowapi.install()
    if setup then setup(state) end
    ns = helpers.loadAddon()
    addon = state.addon
    addon:OnInitialize()
    addon.db.global.settings.clubId = CLUB
    addon:OnEnable()
  end

  local function texts(added)
    local list = {}
    for _, line in ipairs(added) do list[#list + 1] = line.text end
    return list
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("registers a unit tooltip post-call", function()
    load()
    assert.are.equal(1, #state.tooltipPostCalls)
  end)

  it("names the friend and counts their characters", function()
    load()
    assert.are.same({ "Sjaakovich \194\183 1 character" }, texts(wowapi.hoverUnit(state, GARRAKA)))
  end)

  it("uses the plural and counts alts outside the community too", function()
    load()
    addon.db.global.people["Sjaakovich#2232"] = { version = 5, displayName = "Sjaak", chars = {
      ["Player-4619-0000ALT1"] = { name = "Alt One", classFile = "MAGE", level = 3 },
    } }
    addon:SendMessage(ns.Sync.PEOPLE_UPDATED, "Sjaakovich#2232")
    assert.are.same({ "Sjaak \194\183 2 characters" }, texts(wowapi.hoverUnit(state, GARRAKA)))
  end)

  it("marks unlinked community members", function()
    load(function(s)
      table.insert(s.clubMembers[CLUB], { memberId = 3, guid = STRANGER, name = "Some Stranger", classID = 1,
                                          level = 9, presence = 3 })
    end)
    assert.are.same({ "CommunitiesForever member" }, texts(wowapi.hoverUnit(state, STRANGER)))
  end)

  it("adds nothing for your own characters or unknown units", function()
    load()
    assert.are.same({}, wowapi.hoverUnit(state, VES))
    assert.are.same({}, wowapi.hoverUnit(state, "Creature-0-1-2-3-4-5"))
  end)

  it("falls back to the tooltip's unit when data has no guid", function()
    load()
    _G.UnitGUID = function(unit) return unit == "mouseover" and GARRAKA or VES end
    assert.are.same({ "Sjaakovich \194\183 1 character" }, texts(wowapi.hoverUnit(state, nil, {})))
  end)

  it("skips secret GUIDs instead of erroring", function()
    load()
    _G.issecretvalue = function() return true end
    assert.are.same({}, wowapi.hoverUnit(state, GARRAKA))
    _G.issecretvalue = nil
  end)

  it("follows changes, e.g. when the friend is removed", function()
    load()
    assert.are.equal(1, #wowapi.hoverUnit(state, GARRAKA))
    table.remove(state.friends, 1)
    wowapi.fireEvent(state, "BN_FRIEND_INFO_CHANGED")
    wowapi.runTimers(state)
    assert.are.same({ "CommunitiesForever member" }, texts(wowapi.hoverUnit(state, GARRAKA)))
  end)

  it("does nothing when the tooltip API is missing", function()
    load(function() _G.TooltipDataProcessor = nil end)
    assert.are.same({}, state.tooltipPostCalls)
  end)
end)
