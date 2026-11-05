-- GuildInvite: automatic guild invites for alts of members (CF-84). Pure Lua, no WoW globals.
-- The guild code (set by a member, spread over the guild's addon channel), the newest-code rule, the proof an alt
-- sends with its request, checking a request, the guild member list kept for alts and the order they are asked in.
-- Wire reference: docs/SYNC.md "Guild invites (CF-84)".
local _, ns = ...

local GuildInvite = {}

GuildInvite.PREFIX = "CFGuild"       -- own addon prefix: older clients never register it, so never see these
GuildInvite.CODE_MIN = 6             -- characters in a guild code
GuildInvite.CODE_MAX = 64
GuildInvite.FUTURE_SLACK = 300       -- a code or request time more than this ahead of server time is refused
GuildInvite.REQUEST_WINDOW = 300     -- a request older than this (server seconds) is refused (replay)
GuildInvite.ROSTER_MAX = 500         -- guild members remembered for alts
GuildInvite.CANDIDATES_MAX = 10      -- members one attempt asks, one after another
GuildInvite.ACK_WAIT = 6             -- seconds to wait for a member's ack before asking the next one
GuildInvite.RETRY_SECONDS = 300      -- a new attempt this long after one that got no ack
GuildInvite.MAX_ATTEMPTS = 3         -- attempts per login
GuildInvite.LOGIN_DELAY = 15         -- seconds after login before the alt checks (club data needs to load)
GuildInvite.HANDLE_COOLDOWN = 60     -- a member handles one request per requester this often
GuildInvite.ACCEPT_WINDOW = 180      -- an invite is accepted by itself this long after our last request
GuildInvite.CONFIRM_WAIT = 3         -- seconds the member waits for "You have invited ..." before the popup
GuildInvite.KEY_ANSWER_MIN = 1       -- a member answers an older code after a random delay in this range,
GuildInvite.KEY_ANSWER_MAX = 5       -- unless another member's answer came first
GuildInvite.KEY_ANSWER_COOLDOWN = 60 -- and at most this often

GuildInvite.DISPLAY_MAX = 24         -- a requester's display name in the popup (as Merge caps display names)

-- Text compare that ignores case (names and guild names as the game prints them may differ in case only).
local function same(a, b)
  return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end
GuildInvite.same = same

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

--[[ The code as typed: trimmed. Returns code, or nil and the reason:
  "empty", "short" (fewer than CODE_MIN characters), "long" (more than CODE_MAX), "invalid" (| or control
  characters: WoW escapes and line breaks never belong in a code). ]]
function GuildInvite.cleanCode(text)
  if type(text) ~= "string" then return nil, "empty" end
  local code = text:gsub("^%s+", ""):gsub("%s+$", "")
  if code == "" then return nil, "empty" end
  if code:find("[%c|]") then return nil, "invalid" end
  if #code < GuildInvite.CODE_MIN then return nil, "short" end
  if #code > GuildInvite.CODE_MAX then return nil, "long" end
  return code
end

--[[ The newest code wins. "Newest" is the server time the member typed it (`at`, GetServerTime, the same clock on
every client); on the same second the code that sorts last wins, so every client ends on the same code. a and b
are { code, at }; true when a replaces b (b nil: always). ]]
function GuildInvite.newer(a, b)
  if not b or not b.code then return true end
  if a.at ~= b.at then return a.at > b.at end
  return a.code > b.code
end

-- A received code { code, at } checked against the stored one: the cleaned { code, at } to store, or nil (not a
-- valid code, a time from the future, or not newer).
function GuildInvite.acceptKey(stored, received, now)
  if type(received) ~= "table" then return nil end
  local code = GuildInvite.cleanCode(received.code)
  local at = received.at
  if not code or code ~= received.code or not integer(at) or at <= 0 then return nil end
  if type(now) == "number" and at > now + GuildInvite.FUTURE_SLACK then return nil end
  local key = { code = code, at = at }
  if not GuildInvite.newer(key, stored) then return nil end
  return key
end

-- 32-bit polynomial string hash with its own multiplier and seed (arithmetic only: Lua 5.1 has no bit operations).
local function hash32(text, multiplier, seed)
  local h = seed
  for i = 1, #text do h = (h * multiplier + text:byte(i)) % 4294967296 end
  return h
end

--[[ A 64-bit digest as 16 hex characters: two independent 32-bit hashes, each over the text twice (the second pass
mixes the end of the text back into the start). Not a cryptographic hash: it keeps the code out of the request
and binds the request to one character, one guild and one moment; see docs/SYNC.md "Guild invites". ]]
function GuildInvite.hash(text)
  text = tostring(text)
  local doubled = text .. "\31" .. text
  return string.format("%08x%08x", hash32(doubled, 131, 5381), hash32(doubled, 65599, 2166136261))
end

-- The proof an alt sends: the digest of the code, the guild, the requesting character and the request time.
-- Names compare without case on both sides.
function GuildInvite.proof(code, guildName, characterName, at)
  return GuildInvite.hash(table.concat({ "cf84", code, tostring(guildName):lower(), tostring(characterName):lower(),
    tostring(at) }, "\30"))
end

--[[ Checks a request (a GINVREQ message) on the member's side. ctx = {
  code         the guild code this member holds (nil: no code, the feature is off)
  guildName    this member's guild (the picked guild, while this character is in it)
  sender       the requesting character's name as the game reported the whisper (the one to invite: never a name
               from the message)
  now          server time
  memberNames  { [lower-case name] = true } of the guild's members (already in the guild: nothing to do)
  seen         { [request id] = true } requests handled or claimed by someone already
  lastHandled  { [lower-case name] = server time } of the last request handled per requester
}. Returns true, or nil and the reason: "nocode", "noguild", "malformed", "seen", "stale", "proof", "member",
"cooldown". ]]
function GuildInvite.checkRequest(message, ctx)
  if not ctx.code then return nil, "nocode" end
  if type(ctx.guildName) ~= "string" or ctx.guildName == "" then return nil, "noguild" end
  if type(message) ~= "table" or type(message.id) ~= "string" or #message.id > 32 or not integer(message.at)
    or type(message.p) ~= "string" or type(ctx.sender) ~= "string" or ctx.sender == "" then
    return nil, "malformed"
  end
  if ctx.seen and ctx.seen[message.id] then return nil, "seen" end
  if math.abs(ctx.now - message.at) > GuildInvite.REQUEST_WINDOW then return nil, "stale" end
  if message.p ~= GuildInvite.proof(ctx.code, ctx.guildName, ctx.sender, message.at) then return nil, "proof" end
  local lower = ctx.sender:lower()
  if ctx.memberNames and ctx.memberNames[lower] then return nil, "member" end
  local last = ctx.lastHandled and ctx.lastHandled[lower]
  if last and ctx.now - last < GuildInvite.HANDLE_COOLDOWN then return nil, "cooldown" end
  return true
end

--[[ Keeps the guild member list for alts: roster[guid] = { name, seen } with seen the last server time the member was
seen online (0: not yet). members[guid] = { name, online } as the guild shows them now. Members who left are
dropped; with more than ROSTER_MAX the longest unseen go. Returns the roster (changed in place; a new one when nil). ]]
function GuildInvite.updateRoster(roster, members, now)
  roster = type(roster) == "table" and roster or {}
  for guid in pairs(roster) do
    if not members[guid] then roster[guid] = nil end
  end
  for guid, m in pairs(members) do
    if type(m.name) == "string" and m.name ~= "" then
      local entry = type(roster[guid]) == "table" and roster[guid] or { seen = 0 }
      entry.name = m.name
      if type(entry.seen) ~= "number" then entry.seen = 0 end
      if m.online then entry.seen = now end
      roster[guid] = entry
    end
  end
  local list = {}
  for guid, entry in pairs(roster) do list[#list + 1] = { guid = guid, seen = entry.seen, name = entry.name } end
  if #list > GuildInvite.ROSTER_MAX then
    table.sort(list, function(a, b)
      if a.seen ~= b.seen then return a.seen > b.seen end
      return a.guid < b.guid
    end)
    for i = GuildInvite.ROSTER_MAX + 1, #list do roster[list[i].guid] = nil end
  end
  return roster
end

-- Names to ask, most recently seen online first (then by name), without the GUIDs in `exclude` (your own
-- characters), at most `max` (default CANDIDATES_MAX).
function GuildInvite.candidates(roster, exclude, max)
  local list = {}
  for guid, entry in pairs(type(roster) == "table" and roster or {}) do
    if not (exclude and exclude[guid]) and type(entry) == "table" and type(entry.name) == "string"
      and entry.name ~= "" then
      list[#list + 1] = { name = entry.name, seen = type(entry.seen) == "number" and entry.seen or 0 }
    end
  end
  table.sort(list, function(a, b)
    if a.seen ~= b.seen then return a.seen > b.seen end
    return a.name < b.name
  end)
  local names = {}
  for i = 1, math.min(#list, max or GuildInvite.CANDIDATES_MAX) do names[i] = list[i].name end
  return names
end

-- True when a guild invite should be accepted by itself: we asked for one (requestedAt) less than ACCEPT_WINDOW ago,
-- and it is for the remembered guild.
function GuildInvite.shouldAccept(requestedAt, inviteGuild, rememberedGuild, now)
  if type(requestedAt) ~= "number" or type(now) ~= "number" then return false end
  if now - requestedAt > GuildInvite.ACCEPT_WINDOW or now < requestedAt then return false end
  return same(inviteGuild, rememberedGuild)
end

-- A requester's display name from a message: plain text (no escapes), at most DISPLAY_MAX characters, or nil.
function GuildInvite.cleanDisplayName(value)
  if type(value) ~= "string" then return nil end
  local text = value:gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  return text:sub(1, GuildInvite.DISPLAY_MAX)
end

GuildInvite.ALT = "%s (%s's alt)"
GuildInvite.POPUP = "Invite %s?"

-- "Bram Lovewell (Ada's alt)", or the character's name alone when its friend is unknown.
function GuildInvite.altLabel(characterName, friendName)
  if friendName then return string.format(GuildInvite.ALT, characterName, friendName) end
  return characterName
end

-- The member's popup line when the invite needs a click: "Invite Bram Lovewell (Ada's alt)?".
function GuildInvite.popupText(characterName, friendName)
  return string.format(GuildInvite.POPUP, GuildInvite.altLabel(characterName, friendName))
end

ns.GuildInvite = GuildInvite
return GuildInvite
