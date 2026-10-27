local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-44: the level-up announcement at the top of the screen: one at a time, the rest wait.
describe("level-up announcement (CF-44)", function()
  local state, ns

  before_each(function()
    state = wowapi.install()
    ns = helpers.loadAddon()
    state.addon:OnInitialize()
    state.addon:OnEnable()
    wowapi.runTimers(state) -- the login timers first
    ns.LevelUpToast.reset()
  end)

  after_each(function()
    wowapi.uninstall()
  end)

  local function item(level) return { displayName = "Ironpaw", name = "Orin Blackwell", classFile = "PALADIN",
                                      level = level } end

  local function plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

  it("shows one at a time at the top centre, the next after 6 seconds", function()
    ns.LevelUpToast.announce(item(24))
    ns.LevelUpToast.announce(item(25))
    local toast = ns.LevelUpToast.frame()
    assert.is_true(toast.shown)
    assert.are.same({ "TOP", _G.UIParent, "TOP", 0, -34 }, toast.points[1])
    assert.are.equal("Ironpaw's Orin Blackwell reached level 24", plain(toast.text:GetText()))
    assert.are.equal(1, ns.LevelUpToast.waiting())
    assert.are.equal(ns.Kit.TOAST_SECONDS, state.timers[#state.timers].seconds)
    wowapi.runTimers(state)
    assert.is_true(toast.shown)
    assert.are.equal("Ironpaw's Orin Blackwell reached level 25", plain(toast.text:GetText()))
    wowapi.runTimers(state)
    assert.is_false(toast.shown)
  end)

  it("keeps at most five waiting, dropping the oldest", function()
    for level = 20, 27 do ns.LevelUpToast.announce(item(level)) end
    assert.are.equal(ns.LevelUpToast.MAX_WAITING, ns.LevelUpToast.waiting())
    wowapi.runTimers(state)
    assert.are.equal("Ironpaw's Orin Blackwell reached level 23", plain(ns.LevelUpToast.frame().text:GetText()))
  end)
end)
