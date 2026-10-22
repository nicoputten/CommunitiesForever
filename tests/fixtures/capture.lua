-- Captures golden fixtures (CLAUDE.md rule 8): the messages and the SavedVariables this version writes,
-- so later versions can be checked against them (tests/spec/Compat_spec.lua). Run from the repo root once
-- per release whose format matters, then commit the output; never edit a captured fixture:
--   lua tests/fixtures/capture.lua v0.3
-- Uses the end-to-end harness (tests/net.lua): only invented names, no real players.
package.path = "tests/?.lua;" .. package.path
local label = assert(arg[1], "usage: lua tests/fixtures/capture.lua <label, e.g. v0.3>")
local helpers = require("helpers")
local net = require("net")
local wowapi = require("mocks.wowapi")

-- Deterministic Lua source for a value (sorted keys).
local function dump(value, indent)
  indent = indent or ""
  if type(value) == "string" then return string.format("%q", value) end
  if type(value) ~= "table" then return tostring(value) end
  local keys = {}
  for k in pairs(value) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  if #keys == 0 then return "{}" end
  local inner, lines = indent .. "  ", {}
  for _, k in ipairs(keys) do
    local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or "[" .. dump(k) .. "]"
    lines[#lines + 1] = inner .. key .. " = " .. dump(value[k], inner) .. ","
  end
  return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
end

local function hex(text)
  return (text:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local world = net.new()
local people = dofile("tests/fixtures/people.lua")
for _, key in ipairs({ "A", "B", "C" }) do world:person(people[key]) end

world:login("A")
world:with("A", function(c)
  c.state.questLog = { { questID = 5001, title = "A Fixture Quest", isHeader = false } }
  wowapi.fireEvent(c.state, "QUEST_LOG_UPDATE")
end)
world:login("B")
world:settle()
world:with("A", function(c)
  c.state.player.level = 21
  wowapi.fireEvent(c.state, "PLAYER_LEVEL_UP", 21)
end)
world:settle()
world:with("A", function(c)
  c.ns.GroupAsks.ask({ id = "dm", name = "The Deadmines", min = 17, max = 26 })
  c.ns.Ping.send(10)
end)
world:settle()
-- B answers the ask (the link click).
world:with("B", function(c)
  for _, s in ipairs(world:sentBy("A")) do
    if s.message.t == "ASK" then c.ns.ChatLinks.dispatch("addon:CommunitiesForever:ask:later:" .. s.message.id) end
  end
end)
world:settle()
-- Relay: Ada logs off, Cy (in the community, nobody's Battle.net friend) gets Ada's record through Bob.
world:logout("A")
world:login("C")
world:settle()
world:logout("C")

-- Every kind of message once: "<bn|whisper>-<t>[-want|-relay]".
local wire, seen = {}, {}
for _, key in ipairs({ "A", "B", "C" }) do
  local c = world.clients[key]
  local r = c.ns.Protocol.reassembler()
  local codec = c.ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
  local function add(channel, sender, encoded)
    local message = codec:decode(encoded)
    if not message then return end
    local name = channel .. "-" .. message.t
    if message.t == "REQ" and message.want then name = name .. "-want" end
    if message.t == "RECORD" and message.chars and not message.chars[world.people[key].guid] then
      name = name .. "-relay"
    end
    if not seen[name] then
      seen[name] = true
      wire[#wire + 1] = { name = name, sender = sender, hex = hex(encoded), message = message }
    end
  end
  for _, s in ipairs(c.state.bnSent) do
    local encoded = r:add("bn:" .. s[1], s[3], 0)
    if encoded then add("bn", key, encoded) end
  end
  for _, w in ipairs(c.state.whispers) do
    local encoded = r:add("w:" .. w[4], w[2], 0)
    if encoded then add("whisper", key, encoded) end
  end
end
table.sort(wire, function(a, b) return a.name < b.name end)

local saved = world.clients.A.addon.db.global
local dir = "tests/fixtures/" .. label
if package.config:sub(1, 1) == "\\" then
  os.execute('if not exist "' .. dir:gsub("/", "\\") .. '" mkdir "' .. dir:gsub("/", "\\") .. '"')
else
  os.execute('mkdir -p "' .. dir .. '"')
end

local function write(file, header, value)
  local f = assert(io.open(dir .. "/" .. file, "wb"))
  f:write(header, "return ", dump(value), "\n")
  f:close()
end

local protocol = world.clients.A.ns.Protocol.VERSION
local schema = world.clients.A.ns.Store.SCHEMA_VERSION
write("wire.lua", string.format("-- Golden fixture %s: messages as pv %d writes them (tests/fixtures/capture.lua). "
  .. "Do not edit.\n", label, protocol), wire)
write("savedvariables.lua", string.format("-- Golden fixture %s: CommunitiesForeverDB.global as schema %d writes it "
  .. "(tests/fixtures/capture.lua). Do not edit.\n", label, schema), saved)
world:shutdown()
local names = {}
for _, w in ipairs(wire) do names[#names + 1] = w.name end
print(string.format("%s: pv %d, schema %d, %d messages: %s", dir, protocol, schema, #wire, table.concat(names, ", ")))
