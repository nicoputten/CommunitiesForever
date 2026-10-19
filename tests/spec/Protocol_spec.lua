local helpers = require("helpers")

describe("Protocol", function()
  local Protocol, codec

  -- Deterministic pseudo-random text; barely compressible, so it really needs several chunks.
  local function noise(length, seed)
    local bytes, state = {}, seed or 1
    for i = 1, length do
      state = (state * 1103515245 + 12345) % 2147483648
      bytes[i] = string.char(32 + state % 90)
    end
    return table.concat(bytes)
  end

  local function sendAndReceive(message, order)
    local chunks = Protocol.chunk(codec:encode(message), "m1")
    local r = Protocol.reassembler()
    local result
    for _, index in ipairs(order and order(#chunks) or {}) do
      result = r:add(5, chunks[index], 0) or result
    end
    if not order then
      for _, chunk in ipairs(chunks) do result = r:add(5, chunk, 0) or result end
    end
    return result and codec:decode(result), chunks
  end

  before_each(function()
    Protocol = helpers.loadAddonFile("src/core/Protocol.lua", {})
    codec = Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
  end)

  describe("encode and decode", function()
    it("round-trips messages from 10 bytes to 50 KB", function()
      for _, size in ipairs({ 10, 100, 1000, 3400, 3600, 10000, 50000 }) do
        local message = { t = "RECORD", bt = "Sjaakovich#2232", data = noise(size, size) }
        local decoded, chunks = sendAndReceive(message)
        assert.are.same(message, decoded, "size " .. size)
        assert.are.equal(1, decoded.pv)
        if size >= 10000 then assert.is_true(#chunks > 1, "size " .. size) end
      end
    end)

    it("round-trips nested tables like a record", function()
      local record = { t = "RECORD", bt = "Sjaakovich#2232", displayName = "Sjaak", version = 1760000000,
                       chars = { ["Player-4619-01789956"] = { name = "Garraka Doombringer", level = 11, ilvl = 20,
                                 professions = { [186] = { name = "Mining", rank = 64, max = 150 } } } } }
      assert.are.same(record, (sendAndReceive(record)))
    end)

    it("produces text without NUL bytes (addon channel safe)", function()
      local encoded = codec:encode({ t = "HELLO", data = "\0\1\2" .. noise(500) })
      assert.is_nil(encoded:find("\0", 1, true))
    end)

    it("compresses repetitive data", function()
      local encoded = codec:encode({ t = "RECORD", data = string.rep("Mining 64/150 ", 1000) })
      assert.is_true(#encoded < 1000)
    end)

    it("rejects an unsupported protocol version, returning it", function()
      local encoded = codec:encode({ t = "HELLO" })
      local serializer, deflate = helpers.lib("LibSerialize"), helpers.lib("LibDeflate")
      local future = deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(
        serializer:Serialize({ t = "HELLO", pv = 2 })))
      assert.is_table(codec:decode(encoded))
      assert.are.same({ nil, "unsupported", 2 }, { codec:decode(future) })
      local missing = deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(serializer:Serialize({ t = "HELLO" })))
      assert.are.same({ nil, "unsupported" }, { codec:decode(missing) })
    end)

    it("returns corrupt for garbage instead of erroring", function()
      for _, garbage in ipairs({ "", "hello", noise(200), 42 }) do
        local message, reason = codec:decode(garbage)
        assert.is_nil(message)
        assert.are.equal("corrupt", reason)
      end
    end)
  end)

  describe("chunk", function()
    it("keeps every chunk within the limit, header included", function()
      for _, size in ipairs({ 1, 3480, 3500, 3501, 20000, 60000 }) do
        local chunks = Protocol.chunk(noise(size), "abc123")
        for _, chunk in ipairs(chunks) do
          assert.is_true(#chunk <= Protocol.MAX_CHUNK, "size " .. size .. ": " .. #chunk)
        end
      end
    end)

    it("writes msgId, sequence and total in each header", function()
      local chunks = Protocol.chunk(noise(8000), "x9")
      assert.are.equal(3, #chunks)
      assert.matches("^x9:1:3:", chunks[1])
      assert.matches("^x9:3:3:", chunks[3])
    end)

    it("sends an empty payload as one chunk", function()
      assert.are.same({ "m:1:1:" }, Protocol.chunk("", "m"))
    end)

    it("requires an alphanumeric msgId", function()
      assert.has_error(function() Protocol.chunk("x", "a:b") end)
      assert.has_error(function() Protocol.chunk("x", nil) end)
    end)
  end)

  describe("reassembler", function()
    local function reversed(n)
      local order = {}
      for i = n, 1, -1 do order[#order + 1] = i end
      return order
    end

    it("reassembles out-of-order chunks", function()
      local message = { t = "RECORD", data = noise(12000) }
      assert.are.same(message, (sendAndReceive(message, reversed)))
    end)

    it("ignores duplicate chunks", function()
      local encoded = noise(9000)
      local chunks = Protocol.chunk(encoded, "d")
      local r = Protocol.reassembler()
      assert.is_nil(r:add(1, chunks[1], 0))
      assert.is_nil(r:add(1, chunks[1], 0))
      assert.is_nil(r:add(1, chunks[2], 0))
      assert.is_nil(r:add(1, chunks[2], 0))
      assert.are.equal(encoded, r:add(1, chunks[3], 0))
      assert.is_nil(r:add(1, chunks[3], 0)) -- late duplicate after completion starts a new, incomplete entry
    end)

    it("keeps messages from different senders and ids apart", function()
      local a, b = noise(5000, 1), noise(5000, 2)
      local ca, cb = Protocol.chunk(a, "m"), Protocol.chunk(b, "m")
      local r = Protocol.reassembler()
      r:add(1, ca[1], 0)
      r:add(2, cb[1], 0)
      assert.are.equal(b, r:add(2, cb[2], 0))
      assert.are.equal(a, r:add(1, ca[2], 0))
    end)

    it("expires incomplete messages 30 s after their last part (CF-28: resent parts keep them alive)", function()
      local encoded = noise(9000)
      local chunks = Protocol.chunk(encoded, "e")
      local r = Protocol.reassembler()
      r:add(1, chunks[1], 100)
      r:add(1, chunks[2], 110)
      assert.are.equal(1, r:pendingCount())
      r:expire(139)
      assert.are.equal(1, r:pendingCount())
      r:expire(140)
      assert.are.equal(0, r:pendingCount())
      assert.is_nil(r:add(1, chunks[3], 141)) -- the earlier parts are gone
    end)

    it("expires old entries when new chunks arrive", function()
      local r = Protocol.reassembler()
      r:add(1, Protocol.chunk(noise(9000), "old")[1], 0)
      r:add(2, Protocol.chunk(noise(9000), "new")[1], 31)
      assert.are.equal(1, r:pendingCount())
    end)

    it("reports malformed chunks", function()
      local r = Protocol.reassembler()
      for _, bad in ipairs({ "nonsense", "m:0:1:x", "m:3:2:x", "m:a:2:x", ":1:1:x" }) do
        assert.are.same({ nil, "malformed" }, { r:add(1, bad, 0) }, bad)
      end
      r:add(1, "m:1:3:x", 0)
      assert.are.same({ nil, "malformed" }, { r:add(1, "m:2:4:y", 0) }) -- total changed
    end)

    it("completes a single-chunk message immediately", function()
      local r = Protocol.reassembler()
      assert.are.equal("payload:with:colons", r:add(1, "m:1:1:payload:with:colons", 0))
    end)
  end)
end)
