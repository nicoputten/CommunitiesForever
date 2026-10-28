local helpers = require("helpers")

-- CF-47: what has to reach the website waits in global.pending.
describe("Pending (CF-47)", function()
  local Pending
  local NOW = 1793120000

  before_each(function()
    Pending = helpers.loadAddonFile("src/core/Pending.lua", {})
  end)

  it("makes ids from the account ID, the time and a counter", function()
    assert.are.equal("k3f9c0a7e21b-1793120000-7", Pending.newId("k3f9c0a7e21b", NOW, 7))
  end)

  it("keeps one answer per run, the newest", function()
    local list = {}
    Pending.add(list, { id = "a", kind = "answer", run = "r1", answer = "in", at = NOW })
    Pending.add(list, { id = "b", kind = "answer", run = "r2", answer = "in", at = NOW })
    Pending.add(list, { id = "c", kind = "answer", run = "r1", answer = "maybe", at = NOW + 1 })
    assert.are.same({ "b", "c" }, { list[1].id, list[2].id })
    assert.are.equal("maybe", Pending.answerFor(list, "r1").answer)
    assert.is_nil(Pending.answerFor(list, "r3"))
  end)

  it("keeps at most MAX_ITEMS, dropping the oldest", function()
    local list = {}
    for i = 1, Pending.MAX_ITEMS + 5 do Pending.add(list, { id = "p" .. i, kind = "plan", at = NOW }) end
    assert.are.equal(Pending.MAX_ITEMS, #list)
    assert.are.equal("p6", list[1].id)
  end)

  it("drops asks older than 10 minutes, anything older than 14 days and broken items", function()
    local list = {
      { id = "ask-old", kind = "ask", at = NOW - 601 },
      { id = "ask-new", kind = "ask", at = NOW - 600 },
      { id = "plan-old", kind = "plan", at = NOW - 15 * 86400 },
      { id = "plan", kind = "plan", at = NOW - 3600 },
      { id = "odd", kind = "spell", at = NOW },
      "junk",
    }
    Pending.prune(list, NOW)
    assert.are.same({ "ask-new", "plan" }, { list[1].id, list[2].id })
    assert.are.equal(2, #list)
  end)

  it("keeps an item once by its id, one answer per ask, and drops ask answers with their ask (CF-51)", function()
    local list = {}
    Pending.add(list, { id = "k-1", kind = "ask", at = 100, dungeon = "dm" })
    Pending.add(list, { id = "k-1", kind = "ask", at = 100, dungeon = "dm", note = "again" })
    assert.are.equal(1, #list)
    assert.is_nil(list[1].note)
    Pending.add(list, { id = "a-1", kind = "askAnswer", at = 110, ask = "k-1", answer = "in" })
    Pending.add(list, { id = "a-2", kind = "askAnswer", at = 120, ask = "k-1", answer = "cant" })
    assert.are.same({ "k-1", "a-2" }, { list[1].id, list[2].id })
    Pending.prune(list, 120 + Pending.ASK_EXPIRE + 1)
    assert.are.equal(0, #list)
  end)

  it("removes what the site confirmed", function()
    local list = { { id = "a", kind = "plan", at = NOW }, { id = "b", kind = "ask", at = NOW } }
    assert.are.equal(1, Pending.confirm(list, { "b", "zzz" }))
    assert.are.same({ "a" }, { list[1].id })
    assert.are.equal(0, Pending.confirm(list, nil))
  end)

  it("cleans a typed note", function()
    assert.are.equal("Bring water now", Pending.note("  Bring\nwater   now ||"))
    assert.are.equal("cffff0000Red", Pending.note("|cffff0000Red")) -- escapes are plain text
    assert.is_nil(Pending.note("   "))
    assert.is_nil(Pending.note(42))
    assert.are.equal(string.rep("é", Pending.MAX_NOTE), Pending.note(string.rep("é", 300)))
  end)

  -- The sample the web's parser is built against: every kind with every field, as the addon writes them.
  it("matches the shared saved-file sample (tests/fixtures/pending.lua)", function()
    local sample = dofile("tests/fixtures/pending.lua")
    local list = {}
    local function id(n) return Pending.newId("k3f9c0a7e21b", NOW + (n - 1) * 60, n) end
    Pending.add(list, { id = id(1), kind = "plan", at = NOW, dungeon = "smarm", startsAt = 1793190600,
      guid = "Player-1-0000AAAA", name = "Ada Lovewell", role = "tank", note = Pending.note("Bring water") })
    Pending.add(list, { id = id(2), kind = "answer", at = NOW + 60, run = "r-102", answer = "in",
      guid = "Player-1-0000AAAB", name = "Ada Stormbrew", role = "heal" })
    Pending.add(list, { id = id(3), kind = "answer", at = NOW + 120, run = "r-103", answer = "cant" })
    Pending.add(list, { id = id(4), kind = "ask", at = NOW + 180, dungeon = "dm", guid = "Player-1-0000AAAA",
      name = "Ada Lovewell", role = "tank", note = Pending.note("Quick run for the Defias quests") })
    Pending.add(list, { id = Pending.newId("k3f9c0a7e21b", NOW + 190, 5), kind = "ping", at = NOW + 190,
      run = "r-102", battleTag = "Bo#2002", guid = "Player-1-0000BBBB", name = "Bo Example" })
    Pending.prune(list, NOW + 200)
    assert.are.same(sample, list)
  end)
end)
