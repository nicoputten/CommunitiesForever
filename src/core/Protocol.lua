-- Protocol: message encode/decode and chunking for BNet addon messages (ARCHITECTURE "Sync protocol").
-- Pure Lua, no WoW globals. LibSerialize and LibDeflate are passed in (they are pure Lua).
local _, ns = ...

local Protocol = {}

Protocol.PREFIX = "CommForever"
Protocol.VERSION = 1                       -- pv carried by every message
Protocol.MAX_CHUNK = 3500                  -- bytes per BNet message, header included
Protocol.EXPIRE_SECONDS = 30               -- incomplete messages are dropped this long after their last part
-- CF-28: reliable delivery. A message quiet this long while incomplete gets a MISS for its missing parts
-- (at most MAX_MISS times); the sender keeps sent parts for SENT_KEEP_SECONDS and resends at most
-- MAX_RESENDS times per message.
Protocol.MISS_QUIET_SECONDS = 3
Protocol.MAX_MISS = 2
Protocol.SENT_KEEP_SECONDS = 60
Protocol.MAX_RESENDS = 2
Protocol.MAX_MISS_PARTS = 40              -- part numbers per MISS, so it stays one short message
local MISS_PREFIX = "!M:"

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
-- maxChunk (optional, CF-28): bytes per message, default MAX_CHUNK (Battle.net); community whispers are smaller.
function Protocol.chunk(encoded, msgId, maxChunk)
  assert(type(msgId) == "string" and msgId:match("^%w+$"), "msgId must be alphanumeric")
  -- The header length depends on the total, so size slices for the largest possible header.
  local headerRoom = #msgId + 2 * #tostring(#encoded + 1) + 3
  local sliceSize = (maxChunk or Protocol.MAX_CHUNK) - headerRoom
  local total = math.max(1, math.ceil(#encoded / sliceSize))
  local chunks = {}
  for seq = 1, total do
    local slice = encoded:sub((seq - 1) * sliceSize + 1, seq * sliceSize)
    chunks[seq] = string.format("%s:%d:%d:%s", msgId, seq, total, slice)
  end
  return chunks
end

-- CF-28: "!M:<msgId>:3,7": the parts of msgId that did not arrive. Never looks like a chunk header.
function Protocol.missMessage(msgId, parts)
  local list = {}
  for i = 1, math.min(#parts, Protocol.MAX_MISS_PARTS) do list[i] = tostring(parts[i]) end
  return MISS_PREFIX .. msgId .. ":" .. table.concat(list, ",")
end

-- msgId and the part numbers of a MISS, or nil when text is not one.
function Protocol.parseMiss(text)
  if type(text) ~= "string" or text:sub(1, #MISS_PREFIX) ~= MISS_PREFIX then return nil end
  local msgId, list = text:sub(#MISS_PREFIX + 1):match("^(%w+):([%d,]+)$")
  if not msgId then return nil end
  local parts = {}
  for n in list:gmatch("%d+") do
    if #parts >= Protocol.MAX_MISS_PARTS then break end
    parts[#parts + 1] = tonumber(n)
  end
  return msgId, parts
end

--[[ CF-28: the parts we sent, kept for resends.
  local s = Protocol.sentStore()
  s:put(target, msgId, chunks, now)
  s:resend(target, msgId, parts, now) -> { chunk, ... } to send again (empty when unknown, expired or
    resent MAX_RESENDS times already); part numbers outside the message are ignored
]]
function Protocol.sentStore()
  local sent = {} -- [target .. "|" .. msgId] = { chunks, at, resends }
  local s = {}

  local function expire(now)
    for key, entry in pairs(sent) do
      if now - entry.at >= Protocol.SENT_KEEP_SECONDS then sent[key] = nil end
    end
  end

  function s.put(_, target, msgId, chunks, now)
    expire(now)
    sent[tostring(target) .. "|" .. msgId] = { chunks = chunks, at = now, resends = 0 }
  end

  function s.resend(_, target, msgId, parts, now)
    expire(now)
    local entry = sent[tostring(target) .. "|" .. msgId]
    if not entry or entry.resends >= Protocol.MAX_RESENDS then return {} end
    entry.resends = entry.resends + 1
    local result = {}
    for _, n in ipairs(parts or {}) do
      if entry.chunks[n] then result[#result + 1] = entry.chunks[n] end
    end
    return result
  end

  function s.size()
    local n = 0
    for _ in pairs(sent) do n = n + 1 end
    return n
  end

  return s
end

--[[ Collects chunks per sender until a message is complete.
  local r = Protocol.reassembler()
  local encoded, err = r:add(sender, chunk, now)  -- encoded when complete; err "malformed" for bad chunks
  r:missing(now) -> { { sender, msgId, total, parts = { n, ... } } }  -- CF-28: to ask for again
Chunks may arrive in any order; duplicates are ignored; incomplete messages expire
Protocol.EXPIRE_SECONDS after their last part (time is passed in by the caller).
]]
function Protocol.reassembler()
  -- [sender .. "|" .. msgId] = { sender, msgId, total, parts = { [seq] = slice }, count, firstAt, lastAt, asks }
  local pending = {}
  local r = {}

  function r.expire(_, now)
    for key, entry in pairs(pending) do
      if now - entry.lastAt >= Protocol.EXPIRE_SECONDS then
        pending[key] = nil
      end
    end
  end

  -- Incomplete messages quiet for MISS_QUIET_SECONDS that were not asked for MAX_MISS times yet, with
  -- their missing part numbers. Each one returned counts as asked and waits again.
  function r.missing(self, now)
    self:expire(now)
    local result = {}
    for _, entry in pairs(pending) do
      if now - entry.lastAt >= Protocol.MISS_QUIET_SECONDS and entry.asks < Protocol.MAX_MISS then
        local parts = {}
        for seq = 1, entry.total do
          if not entry.parts[seq] then parts[#parts + 1] = seq end
        end
        entry.asks = entry.asks + 1
        entry.lastAt = now
        result[#result + 1] = { sender = entry.sender, msgId = entry.msgId, total = entry.total, parts = parts }
      end
    end
    table.sort(result, function(a, b) return a.msgId < b.msgId end)
    return result
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
      entry = { sender = sender, msgId = msgId, total = total, parts = {}, count = 0, firstAt = now, lastAt = now,
                asks = 0 }
      pending[key] = entry
    elseif entry.total ~= total then
      return nil, "malformed"
    end
    if entry.parts[seq] then return nil end -- duplicate

    entry.parts[seq] = slice
    entry.count = entry.count + 1
    entry.lastAt = now
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
