local helpers = require("helpers")

describe("Queue (CF-44)", function()
  local Queue

  before_each(function()
    Queue = helpers.loadAddonFile("src/core/Queue.lua", {})
  end)

  it("gives items back in order and nil when empty", function()
    local q = {}
    Queue.push(q, "a")
    Queue.push(q, "b")
    assert.are.equal("a", Queue.pop(q))
    assert.are.equal("b", Queue.pop(q))
    assert.is_nil(Queue.pop(q))
  end)

  it("drops the oldest beyond the limit", function()
    local q = {}
    for i = 1, 5 do assert.are.equal(0, Queue.push(q, i, 5)) end
    assert.are.equal(1, Queue.push(q, 6, 5))
    assert.are.same({ 2, 3, 4, 5, 6 }, q)
  end)
end)
