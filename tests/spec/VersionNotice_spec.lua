local net = require("net")

-- CF-35: a friend or community member on a newer release gets you one line per session.
describe("newer version notice (CF-35)", function()
  local world

  local function people(adaVersion, bobVersion, friends)
    world:person({ key = "A", name = "Ada Example", guid = "Player-1-0000A001", battleTag = "Ada#1001",
                   classFile = "MAGE", classID = 8, level = 20, gameAccountID = 101,
                   friends = friends == false and {} or { "B" }, version = adaVersion })
    world:person({ key = "B", name = "Bob Example", guid = "Player-1-0000B001", battleTag = "Bob#2002",
                   classFile = "ROGUE", classID = 4, level = 22, gameAccountID = 102,
                   friends = friends == false and {} or { "A" }, version = bobVersion })
  end

  local function noticesAt(key)
    local found = {}
    for _, line in ipairs(world.clients[key].state.printed) do
      if line:find("A newer version of CommunitiesForever is available", 1, true) then found[#found + 1] = line end
    end
    return found
  end

  before_each(function()
    world = net.new()
  end)

  after_each(function()
    world:shutdown()
  end)

  it("tells the one on the older release, once, with the newer version", function()
    people("v0.3.0-beta1", "v0.3.1")
    world:login("A")
    world:login("B")
    world:settle()
    assert.are.same({ "A newer version of CommunitiesForever is available (v0.3.1). Update with the CurseForge "
      .. "app or WowUp." }, noticesAt("A"))
    assert.are.same({}, noticesAt("B"))
    -- More HELLOs later in the session (Bob levels up): no second line.
    world:with("B", function(c)
      c.state.player.level = 23
      require("mocks.wowapi").fireEvent(c.state, "PLAYER_LEVEL_UP", 23)
    end)
    world:settle()
    assert.are.equal(1, #noticesAt("A"))
  end)

  it("works over the community too (not Battle.net friends)", function()
    people("v0.3.0", "v0.4.0-beta1", false)
    world:login("A")
    world:login("B")
    world:settle()
    assert.are.equal(1, #noticesAt("A"))
  end)

  it("stays quiet for equal versions and dev builds", function()
    people("v0.3.0", "v0.3.0")
    world:login("A")
    world:login("B")
    world:settle()
    assert.are.same({}, noticesAt("A"))
    world:shutdown()

    world = net.new()
    people("0.1.155", "v9.9.9") -- a dev build never gets the line
    world:login("A")
    world:login("B")
    world:settle()
    assert.are.same({}, noticesAt("A"))
  end)
end)
