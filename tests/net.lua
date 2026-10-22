-- End-to-end harness: several addon clients in one spec, each on its own WoW mock, connected by a fake
-- network. What one client sends (BNSendGameData, addon whispers) is delivered to the other as the event
-- the game fires (BN_CHAT_MSG_ADDON, CHAT_MSG_ADDON). Runs in plain busted: no game client involved.
-- It checks our sharing end to end; whether Blizzard delivers the messages is VERIFY.md's job.
local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

local net = {}
net.CLUB = "40000001"
net.REALM = "Classic Beta PvP"

local Net = {}
Net.__index = Net

function net.new()
  return setmetatable({ clients = {}, time = 500, serverTime = 1000 }, Net)
end

-- People in the network: def = { key, name, guid, battleTag, classFile, classID, level, gameAccountID,
-- friends = { other keys }, version (optional: the addon version they run) }. Declared first, so friend
-- lists and the community know everyone.
function Net:person(def)
  self.people = self.people or {}
  self.people[def.key] = def
  return def
end

local function friendEntry(def, online)
  return { battleTag = def.battleTag, gameAccounts = online and {
    { clientProgram = "WoW", wowProjectID = 18, isOnline = true, characterName = def.name,
      realmName = "ClassicBetaPvP", realmDisplayName = net.REALM, className = def.className or "Mage",
      characterLevel = def.level, factionName = "Horde", playerGuid = def.guid, gameAccountID = def.gameAccountID },
  } or {} }
end

function Net:isOnline(key)
  local c = self.clients[key]
  return c ~= nil and c.online
end

-- The friend list and community as the client `key` sees them now.
function Net:refreshWorld(key)
  local me = self.people[key]
  local state = self.clients[key].state
  local friends = {}
  for _, other in ipairs(me.friends or {}) do
    friends[#friends + 1] = friendEntry(self.people[other], self:isOnline(other))
  end
  state.friends = friends
  local members, id = {}, 0
  for otherKey, def in pairs(self.people) do
    id = id + 1
    members[#members + 1] = { memberId = id, guid = def.guid, name = def.name, classID = def.classID or 8,
      level = def.level, zone = "Durotar", presence = self:isOnline(otherKey) and 1 or 0, race = 2, faction = 0,
      isSelf = otherKey == key, clubType = 1, role = 4 }
  end
  state.clubMembers = { [net.CLUB] = members }
end

function Net:with(key, fn)
  local c = self.clients[key]
  wowapi.activate(c.globals)
  c.state.time, c.state.serverTime = self.time, self.serverTime
  return fn(c)
end

-- Logs a client in: its own mock and addon instance, in the community, setup done.
function Net:login(key)
  local def = assert(self.people[key], "unknown person " .. key)
  local state = wowapi.install()
  local p = state.player
  p.guid, p.name, p.battleTag, p.classFile, p.level = def.guid, def.name, def.battleTag, def.classFile or "MAGE",
    def.level
  state.clubs = { { clubId = net.CLUB, name = "Test Friends", clubType = 1 } }
  if def.version then state.metadata.Version = def.version end -- the TOC version this client runs
  local client = { key = key, state = state, online = true, sentBn = 0, sentWhispers = 0 }
  self.clients[key] = client
  self:refreshWorld(key)
  client.ns = helpers.loadAddon()
  client.addon = state.addon
  client.addon:OnInitialize()
  local settings = client.addon.db.global.settings
  settings.clubId = net.CLUB
  settings.onboarded, settings.onboardedVersion = true, client.ns.Onboarding.VERSION
  settings.chatTabPrompt = { [def.guid] = true }
  client.globals = wowapi.snapshot()
  self:with(key, function(c) c.addon:OnEnable() end)
  -- Everyone else sees them come online.
  for other in pairs(self.clients) do
    if other ~= key and self.clients[other].online then self:notifyPresence(other) end
  end
  return client
end

function Net:logout(key)
  self:with(key, function(c)
    if c.state.eventHandlers.PLAYER_LOGOUT then wowapi.fireEvent(c.state, "PLAYER_LOGOUT") end
    wowapi.runTimers(c.state) -- the BYE goes out
  end)
  self:deliver()
  self.clients[key].online = false
  for other in pairs(self.clients) do
    if other ~= key and self.clients[other].online then self:notifyPresence(other) end
  end
end

-- Friend list and community changed for client `key`: refresh its view (as the game's events would).
function Net:notifyPresence(key)
  self:refreshWorld(key)
  self:with(key, function(c)
    for _, event in ipairs({ "BN_FRIEND_INFO_CHANGED", "CLUB_MEMBER_PRESENCE_UPDATED" }) do
      if c.state.eventHandlers[event] then wowapi.fireEvent(c.state, event, net.CLUB) end
    end
  end)
end

local function byName(self, name)
  for key, def in pairs(self.people) do
    if def.name == name then return key end
  end
end

local function byGameAccount(self, gameAccountID)
  for key, def in pairs(self.people) do
    if def.gameAccountID == gameAccountID then return key end
  end
end

-- Moves everything sent since the last call to its recipient. Returns the number of messages moved.
function Net:deliver()
  local moved = 0
  for key, c in pairs(self.clients) do
    if c.online then
      local from = self.people[key]
      local bn, whispers = c.state.bnSent, c.state.whispers
      for i = c.sentBn + 1, #bn do
        local to = byGameAccount(self, bn[i][1])
        if to and self:isOnline(to) then
          self:with(to, function(r) wowapi.fireEvent(r.state, "BN_CHAT_MSG_ADDON", bn[i][2], bn[i][3], "WHISPER",
            from.gameAccountID) end)
          moved = moved + 1
        end
      end
      for i = c.sentWhispers + 1, #whispers do
        local w = whispers[i]
        local to = byName(self, w[4])
        if to and self:isOnline(to) then
          self:with(to, function(r) wowapi.fireEvent(r.state, "CHAT_MSG_ADDON", w[1], w[2], "WHISPER",
            from.name .. "-ClassicBetaPvP") end)
          moved = moved + 1
        end
      end
      c.sentBn, c.sentWhispers = #bn, #whispers
    end
  end
  return moved
end

-- Lets time pass and all clients talk until nothing moves anymore (bounded).
function Net:settle(rounds)
  for _ = 1, rounds or 60 do
    self.time, self.serverTime = self.time + 1, self.serverTime + 1
    for key, c in pairs(self.clients) do
      if c.online then self:with(key, function() wowapi.runTimers(c.state) end) end
    end
    self:deliver()
  end
end

-- Every message a client sent, decoded: { channel = "bn"|"whisper", to, message }.
function Net:sentBy(key)
  local c = self.clients[key]
  local codec = c.ns.Protocol.codec(helpers.lib("LibSerialize"), helpers.lib("LibDeflate"))
  local out, r = {}, c.ns.Protocol.reassembler()
  for _, s in ipairs(c.state.bnSent) do
    local encoded = r:add("bn:" .. s[1], s[3], 0)
    if encoded then out[#out + 1] = { channel = "bn", to = s[1], message = codec:decode(encoded) } end
  end
  for _, w in ipairs(c.state.whispers) do
    local encoded = r:add("w:" .. w[4], w[2], 0)
    if encoded then out[#out + 1] = { channel = "whisper", to = w[4], message = codec:decode(encoded),
                                      raw = w[2] } end
  end
  return out
end

function Net:shutdown()
  wowapi.uninstall()
end

return net
