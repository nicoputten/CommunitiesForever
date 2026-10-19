local helpers = require("helpers")

describe("Protocol reliable delivery (CF-28)", function()
  local Protocol

  before_each(function()
    Protocol = helpers.loadAddonFile("src/core/Protocol.lua", {})
  end)

  local function noise(n)
    local t = {}
    for i = 1, n do t[i] = string.char(65 + (i * 7) % 26) end
    return table.concat(t)
  end

  describe("MISS messages", function()
    it("round-trip and never look like a chunk", function()
      local text = Protocol.missMessage("a1x3", { 2, 7 })
      assert.are.equal("!M:a1x3:2,7", text)
      local msgId, parts = Protocol.parseMiss(text)
      assert.are.equal("a1x3", msgId)
      assert.are.same({ 2, 7 }, parts)
      assert.is_nil(text:match("^(%w+):(%d+):(%d+):"))
      assert.is_nil(Protocol.parseMiss("a1x3:1:2:payload"))
      assert.is_nil(Protocol.parseMiss("!M:bad id:1"))
    end)

    it("carry at most MAX_MISS_PARTS part numbers", function()
      local many = {}
      for i = 1, 100 do many[i] = i end
      local _, parts = Protocol.parseMiss(Protocol.missMessage("m", many))
      assert.are.equal(Protocol.MAX_MISS_PARTS, #parts)
      assert.is_true(#Protocol.missMessage("m", many) < 255)
    end)
  end)

  describe("sent store", function()
    it("resends the asked parts, at most twice per message", function()
      local s = Protocol.sentStore()
      s:put(5, "m1", { "c1", "c2", "c3" }, 100)
      assert.are.same({ "c2" }, s:resend(5, "m1", { 2 }, 101))
      assert.are.same({ "c1", "c3" }, s:resend(5, "m1", { 1, 3, 9 }, 102)) -- 9 is not a part
      assert.are.same({}, s:resend(5, "m1", { 2 }, 103))
    end)

    it("only resends to the target it was sent to, within a minute", function()
      local s = Protocol.sentStore()
      s:put(5, "m1", { "c1" }, 100)
      assert.are.same({}, s:resend(6, "m1", { 1 }, 101))
      assert.are.same({}, s:resend(5, "m1", { 1 }, 160))
      assert.are.equal(0, s:size())
    end)
  end)

  describe("missing parts", function()
    it("reports the missing parts after 3 quiet seconds, at most twice, and completes with resent parts", function()
      local chunks = Protocol.chunk(noise(9000), "m", 1000)
      assert.is_true(#chunks >= 5)
      local r = Protocol.reassembler()
      for i, chunk in ipairs(chunks) do
        if i ~= 2 and i ~= 4 then r:add(7, chunk, 100) end
      end
      assert.are.same({}, r:missing(102.9))
      local first = r:missing(103)
      assert.are.same({ { sender = 7, msgId = "m", total = #chunks, parts = { 2, 4 } } }, first)
      assert.are.same({}, r:missing(105)) -- waits again after asking
      r:add(7, chunks[2], 105)
      local second = r:missing(108)
      assert.are.same({ 4 }, second[1].parts)
      assert.are.same({}, r:missing(120)) -- asked twice: no more
      local encoded = r:add(7, chunks[4], 121)
      assert.are.equal(noise(9000), encoded)
      assert.are.equal(0, r:pendingCount())
    end)

    it("splits into smaller parts on request (community messages)", function()
      local chunks = Protocol.chunk(noise(2000), "m", 255)
      for _, chunk in ipairs(chunks) do assert.is_true(#chunk <= 255) end
    end)
  end)
end)
