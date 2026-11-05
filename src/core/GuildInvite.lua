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
GuildInvite.ACCEPT_WINDOW = 180      -- an invite this long after our last request gets "Click Accept"
GuildInvite.REFUSAL_WINDOW = 60      -- a refusal text counts as ours this long after the popup showed or closed
GuildInvite.KEY_ANSWER_MIN = 1       -- a member answers an older code after a random delay in this range,
GuildInvite.KEY_ANSWER_MAX = 5       -- unless another member's answer came first
GuildInvite.KEY_ANSWER_COOLDOWN = 60 -- and at most this often
GuildInvite.INVITE_WAIT = 120        -- after an ack, the alt waits this long for the invite (pasted by hand)
GuildInvite.REMOVED_MAX = 200        -- removed characters remembered per guild
GuildInvite.NO_ANSWER_QUIET = 86400  -- "No member answered" shows once a day per character

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

--[[ The newest code wins, by a version counter, not by clocks: each new code gets `v` = the highest version the
member's client knows + 1, so a member coming back with an old code (a lower `v`) never overwrites a newer one,
whatever the clocks say. Only two codes set at the same version (two members at once, before they heard of each
other) fall back to the time it was typed (`at`, server time), then to the code that sorts last, so every client ends
on the same code. a and b are { code, v, at } (v nil counts as 0); true when a replaces b (b nil: always). ]]
function GuildInvite.newer(a, b)
  if not b or not b.code then return true end
  local av, bv = a.v or 0, b.v or 0
  if av ~= bv then return av > bv end
  if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
  return a.code > b.code
end

-- The version a member gives a code it sets now: one more than the stored one.
function GuildInvite.nextVersion(stored)
  return ((stored and integer(stored.v) and stored.v) or 0) + 1
end

-- A received code { code, v, at } checked against the stored one: the cleaned { code, v, at } to store, or nil (not
-- a valid code, a bad version or time, a time from the future, or not newer).
function GuildInvite.acceptKey(stored, received, now)
  if type(received) ~= "table" then return nil end
  local code = GuildInvite.cleanCode(received.code)
  local v, at = received.v, received.at
  if not code or code ~= received.code or not integer(at) or at <= 0 then return nil end
  if not integer(v) or v < 1 then return nil end
  if type(now) == "number" and at > now + GuildInvite.FUTURE_SLACK then return nil end
  local key = { code = code, v = v, at = at }
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
  removedNames { [lower-case name] = true } of characters removed from the guild (never invited by themselves)
  seen         { [request id] = true } requests handled or claimed by someone already
  lastHandled  { [lower-case name] = server time } of the last request handled per requester
}. Returns true, or nil and the reason: "nocode", "noguild", "malformed", "seen", "stale", "proof", "member",
"removed", "cooldown". ]]
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
  if ctx.removedNames and ctx.removedNames[lower] then return nil, "removed" end
  local last = ctx.lastHandled and ctx.lastHandled[lower]
  if last and ctx.now - last < GuildInvite.HANDLE_COOLDOWN then return nil, "cooldown" end
  return true
end

--[[ Keeps the guild member list for alts: roster[guid] = { name, seen } with seen the last server time the member was
seen online (0: not yet). members[guid] = { name, online } as the guild shows them now. Members who left (kicked or
left themselves) are dropped and returned as gone[guid] = name, unless so many vanish at once that the list looks
half loaded (more than 5 and more than a fifth): then nobody counts as gone and the old entries stay. With more than
ROSTER_MAX the longest unseen go (not "gone"). Returns roster (changed in place; a new one when nil), gone. ]]
function GuildInvite.updateRoster(roster, members, now)
  roster = type(roster) == "table" and roster or {}
  local gone, size, vanished = {}, 0, 0
  for guid, entry in pairs(roster) do
    size = size + 1
    if not members[guid] then
      vanished = vanished + 1
      gone[guid] = type(entry) == "table" and entry.name or nil
    end
  end
  if vanished > 5 and vanished > size / 5 then
    gone = {}
  else
    for guid in pairs(gone) do roster[guid] = nil end
    for guid in pairs(roster) do
      if not members[guid] then roster[guid] = nil end -- an entry without a name
    end
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
  return roster, gone
end

--[[ Characters removed from the guild (Nico, 2026-11-05: kicked or left, never invited again by themselves; a manual
invite still works). removed[guid] = { name, at }. Returns the list (changed in place; a new one when nil). ]]
function GuildInvite.markRemoved(removed, guid, name, at)
  removed = type(removed) == "table" and removed or {}
  if type(guid) ~= "string" or guid == "" or type(name) ~= "string" or name == "" then return removed end
  removed[guid] = { name = name, at = integer(at) and at or 0 }
  local list = {}
  for g, entry in pairs(removed) do list[#list + 1] = { guid = g, at = type(entry) == "table" and entry.at or 0 } end
  if #list > GuildInvite.REMOVED_MAX then
    table.sort(list, function(a, b)
      if a.at ~= b.at then return a.at > b.at end
      return a.guid < b.guid
    end)
    for i = GuildInvite.REMOVED_MAX + 1, #list do removed[list[i].guid] = nil end
  end
  return removed
end

-- Lifts removals: every GUID back in the guild (members[guid]) and, when given, the character `name` (a manual
-- invite). Returns true when something was lifted.
function GuildInvite.liftRemoved(removed, members, name)
  if type(removed) ~= "table" then return false end
  local lifted = false
  for guid, entry in pairs(removed) do
    if (members and members[guid]) or (name and type(entry) == "table" and same(entry.name, name)) then
      removed[guid] = nil
      lifted = true
    end
  end
  return lifted
end

-- { [lower-case name] = true } of the removed characters, for checkRequest.
function GuildInvite.removedNames(removed)
  local names = {}
  for _, entry in pairs(type(removed) == "table" and removed or {}) do
    if type(entry) == "table" and type(entry.name) == "string" then names[entry.name:lower()] = true end
  end
  return names
end

--[[ Can this character join the guild at all? Guild members share a faction and (mega-realms) a realm per ruleset.
guild = { faction, realm } as a member's client stored them; here = { faction, realm } of this character (the
same game functions on both sides). Returns "faction", "realm" or nil (fine, or unknown). ]]
function GuildInvite.placeMismatch(guild, here)
  if type(guild) ~= "table" or type(here) ~= "table" then return nil end
  if type(guild.faction) == "string" and type(here.faction) == "string" and guild.faction ~= here.faction then
    return "faction"
  end
  if type(guild.realm) == "string" and type(here.realm) == "string" and guild.realm ~= here.realm then
    return "realm"
  end
  return nil
end

--[[ A system or error message after a guild invite, read through the game's own format strings (no English text).
formats = { [kind] = format string } (kinds: "rights", "faction", "member", "invited", "notfound"). Returns kind and
the character's name when the format names one, or nil. ]]
function GuildInvite.inviteError(message, formats)
  if type(message) ~= "string" then return nil end
  for kind, format in pairs(formats or {}) do
    if type(format) == "string" then
      if format == message then return kind end
      local args = ns.GameText.parse(message, format)
      if args then return kind, args[1] end
    end
  end
  return nil
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

-- True when a guild invite is the one we asked for: we asked (requestedAt) less than ACCEPT_WINDOW ago, and it is
-- for the remembered guild. Then the alt is told to click Accept (CF-87: no AcceptGuild from addon code).
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

-- CF-87: the slash command the member's popup offers to copy into chat: the name exactly as the game reported it
-- (V131), never built from parts. nil for an empty name or one with a control
-- character or "|" (a macro line must stay one line, without escapes).
GuildInvite.INVITE_COMMAND = "/ginvite %s"
function GuildInvite.inviteCommand(name)
  if type(name) ~= "string" or name == "" or name:find("[%c|]") then return nil end
  return string.format(GuildInvite.INVITE_COMMAND, name)
end

-- The member's popup line: "Invite Bram Lovewell (Ada's alt)?".
function GuildInvite.popupText(characterName, friendName)
  return string.format(GuildInvite.POPUP, GuildInvite.altLabel(characterName, friendName))
end

ns.GuildInvite = GuildInvite
return GuildInvite
