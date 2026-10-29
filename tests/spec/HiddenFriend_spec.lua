local net = require("net")

-- A Battle.net friend set to "Appear offline" (retail test, 2026-10-29): their data still arrives, so they are
-- linked and synced both ways, but the window keeps them offline.
describe("a friend who appears offline", function()
  local world
  local PEOPLE = dofile("tests/fixtures/people.lua")

  after_each(function()
    if world then world:shutdown() end
    world = nil
  end)

  local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
  end

  it("still syncs and links both ways, and stays shown as offline", function()
    world = net.new()
    local ada = copy(PEOPLE.A)
    ada.hidden = true
    world:person(ada)
    world:person(PEOPLE.B)
    world:login("B")
    world:login("A")
    world:settle()
    world:with("B", function(c)
      assert.is_table(c.addon.db.global.people[ada.battleTag]) -- Ada's record arrived
      assert.is_nil(c.ns.PresenceTracker.online()[ada.battleTag]) -- not online in the window
      local view = c.ns.ViewModel.build(c.addon)
      local found
      for _, person in ipairs(view.people) do
        if person.battleTag == ada.battleTag then found = person end
      end
      assert.is_table(found) -- her characters are under her, not Unlinked
      for _, row in ipairs(view.unlinked) do assert.are_not.equal(ada.guid, row.guid) end
      -- Battle.net never reports her as on: no "came online" line (the community roster is the game's own).
      for _, line in ipairs(c.state.printed or {}) do
        assert.is_falsy(tostring(line):find("is online", 1, true), line)
      end
    end)
    world:with("A", function(c)
      assert.is_table(c.addon.db.global.people[PEOPLE.B.battleTag]) -- and Bob's reached her
    end)
  end)
end)
