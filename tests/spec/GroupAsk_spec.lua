local helpers = require("helpers")

describe("GroupAsk (CF-27)", function()
  local GroupAsk
  local DM = { id = "dm", name = "The Deadmines", min = 17, max = 26 }

  before_each(function()
    GroupAsk = helpers.loadAddonFile("src/core/GroupAsk.lua", {})
  end)

  local function record(name, chars)
    local result = { displayName = name, chars = {} }
    for i, c in ipairs(chars) do result.chars["G" .. name .. i] = { name = c[1], level = c[2] } end
    return result
  end

  it("asks friends online with the addon and any character in range, not yourself", function()
    local online = { ["Ben#1"] = { gameAccountID = 5 }, ["Cid#2"] = { gameAccountID = 6 },
                     ["Dee#3"] = { gameAccountID = 7 }, ["Me#0"] = { gameAccountID = 1 } }
    local records = {
      ["Ben#1"] = record("Ben", { { "Ben Main", 40 }, { "Bob Alt", 20 } }), -- an alt in range
      ["Cid#2"] = record("Cid", { { "Cid Main", 50 } }),                    -- nothing in range
      ["Eve#4"] = record("Eve", { { "Eve Main", 20 } }),                    -- not online
      ["Me#0"] = record("Me", { { "My Main", 20 } }),
    }                                                                       -- Dee: no record (no addon)
    local result = GroupAsk.recipients(DM, online, records, "Me#0")
    assert.are.equal(1, #result)
    assert.are.equal("Ben#1", result[1].battleTag)
    assert.are.equal(5, result[1].gameAccountID)
    assert.are.same({ { name = "Bob Alt", level = 20 } }, result[1].chars)
  end)

  it("lists characters in range, highest level first", function()
    local chars = { a = { name = "A", level = 18 }, b = { name = "B", level = 25 }, c = { name = "C", level = 30 } }
    local result = GroupAsk.charsInRange(chars, 17, 26)
    assert.are.same({ "B", "A" }, { result[1].name, result[2].name })
  end)

  it("throttles asks to one per 3 minutes and expires them after 10", function()
    assert.is_true(GroupAsk.canAsk(nil, 1000))
    local ok, wait = GroupAsk.canAsk(1000, 1100)
    assert.is_false(ok)
    assert.are.equal(80, wait)
    assert.is_true(GroupAsk.canAsk(1000, 1180))
    assert.is_false(GroupAsk.expired({ at = 1000 }, 1599))
    assert.is_true(GroupAsk.expired({ at = 1000 }, 1600))
    assert.is_true(GroupAsk.expired(nil, 1000))
  end)

  it("cleans received asks and answers", function()
    local ask = GroupAsk.cleanAsk({ t = "ASK", id = "17", from = "|cffff0000Ben", char = "Bob Alt",
      dungeon = { id = "dm", name = "The Deadmines", min = 17.6, max = 999 } })
    assert.are.same({ id = "17", from = "cffff0000Ben", char = "Bob Alt",
                      dungeon = { id = "dm", name = "The Deadmines", min = 17, max = 100 } }, ask)
    assert.is_nil(GroupAsk.cleanAsk({ id = "1", dungeon = { name = "X", min = 30, max = 20 } }))
    assert.is_nil(GroupAsk.cleanAsk({ id = "1" }))
    assert.are.same({ id = "17", answer = "join", char = "Bob Alt" },
      GroupAsk.cleanAnswer({ id = "17", answer = "join", char = "Bob Alt" }))
    assert.is_nil(GroupAsk.cleanAnswer({ id = "17", answer = "maybe" }))
  end)

  it("sums up the answers per person", function()
    local ask = { recipients = { { battleTag = "B", displayName = "Ben" }, { battleTag = "C", displayName = "Cid" },
                                 { battleTag = "D", displayName = "Dee" }, { battleTag = "E", displayName = "Eve" } },
                  answers = { B = { answer = "join", char = "Bob Alt" }, C = { answer = "later" },
                              D = { answer = "no" } } }
    assert.are.same({ join = { "Ben (Bob Alt)" }, later = { "Cid" }, no = { "Dee" }, waiting = { "Eve" } },
      GroupAsk.summary(ask))
  end)
end)
