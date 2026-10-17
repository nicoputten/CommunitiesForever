-- Protocol: message encode/decode and chunking for BNet addon messages (ARCHITECTURE "Sync protocol").
-- Pure Lua, no WoW globals. LibSerialize and LibDeflate are passed in (they are pure Lua).
local _, ns = ...

local Protocol = {}

Protocol.PREFIX = "CommForever"
Protocol.VERSION = 1                       -- pv carried by every message
Protocol.MAX_CHUNK = 3500                  -- bytes per BNet message, header included
Protocol.EXPIRE_SECONDS = 30               -- incomplete messages are dropped after this

-- Supported protocol versions. A message with another pv is rejected.
local SUPPORTED = { [1] = true }

-- Chunk header: "<msgId>:<seq>:<total>:" then the payload slice. msgId is [%w]+.
local HEADER_PATTERN = "^(%w+):(%d+):(%d+):"

--[[ Codec bound to the serialization libraries:
  codec = Protocol.codec(LibSerialize, LibDeflate)
  codec:encode(message) -> string safe for the addon channel; message.pv is set to Protocol.VERSION
  codec:decode(text)    -> message | nil, reason ("corrupt" | "unsupported"), pv
]]
function Protocol.codec(serializer, deflate)
  local codec = {}

  function codec.encode(_, message)
    message.pv = Protocol.VERSION
    local serialized = serializer:Serialize(message)
    return deflate:EncodeForWoWAddonChannel(deflate:CompressDeflate(serialized))
  end

  function codec.decode(_, text)
    local compressed = type(text) == "string" and deflate:DecodeForWoWAddonChannel(text)
    if not compressed then return nil, "corrupt" end
    local serialized = deflate:DecompressDeflate(compressed)
    if not serialized then return nil, "corrupt" end
    local ok, message = serializer:Deserialize(serialized)
    if not ok or type(message) ~= "table" then return nil, "corrupt" end
    if not SUPPORTED[message.pv] then return nil, "unsupported", message.pv end
    return message
  end

  return codec
end

-- Splits an encoded message into chunks of at most Protocol.MAX_CHUNK bytes.
-- msgId must be alphanumeric and unique per sender for the expiry window.
function Protocol.chunk(encoded, msgId)
  assert(type(msgId) == "string" and msgId:match("^%w+$"), "msgId must be alphanumeric")
  -- The header length depends on the total, so size slices for the largest possible header.
  local headerRoom = #msgId + 2 * #tostring(#encoded + 1) + 3
  local sliceSize = Protocol.MAX_CHUNK - headerRoom
  local total = math.max(1, math.ceil(#encoded / sliceSize))
  local chunks = {}
  for seq = 1, total do
    local slice = encoded:sub((seq - 1) * sliceSize + 1, seq * sliceSize)
    chunks[seq] = string.format("%s:%d:%d:%s", msgId, seq, total, slice)
  end
  return chunks
end

--[[ Collects chunks per sender until a message is complete.
  local r = Protocol.reassembler()
  local encoded, err = r:add(sender, chunk, now)  -- encoded when complete; err "malformed" for bad chunks
Chunks may arrive in any order; duplicates are ignored; incomplete messages expire after
Protocol.EXPIRE_SECONDS (time is passed in by the caller).
]]
function Protocol.reassembler()
  local pending = {} -- [sender .. "|" .. msgId] = { total, parts = { [seq] = slice }, count, firstAt }
  local r = {}

  function r.expire(_, now)
    for key, entry in pairs(pending) do
      if now - entry.firstAt >= Protocol.EXPIRE_SECONDS then
        pending[key] = nil
      end
    end
  end

  function r.add(self, sender, chunk, now)
    self:expire(now)
    local msgId, seqText, totalText = chunk:match(HEADER_PATTERN)
    if not msgId then return nil, "malformed" end
    local seq, total = tonumber(seqText), tonumber(totalText)
    if seq < 1 or total < 1 or seq > total then return nil, "malformed" end
    local slice = chunk:sub(#msgId + #seqText + #totalText + 4)

    local key = tostring(sender) .. "|" .. msgId
    local entry = pending[key]
    if not entry then
      entry = { total = total, parts = {}, count = 0, firstAt = now }
      pending[key] = entry
    elseif entry.total ~= total then
      return nil, "malformed"
    end
    if entry.parts[seq] then return nil end -- duplicate

    entry.parts[seq] = slice
    entry.count = entry.count + 1
    if entry.count < entry.total then return nil end

    pending[key] = nil
    return table.concat(entry.parts, "", 1, entry.total)
  end

  -- Number of incomplete messages (for tests and debugging).
  function r.pendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
  end

  return r
end

ns.Protocol = Protocol
return Protocol
