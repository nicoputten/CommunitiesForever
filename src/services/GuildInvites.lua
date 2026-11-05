-- GuildInvites: automatic guild invites for alts of members (CF-84). Rules: core/GuildInvite.lua; WoW calls:
-- adapters/Guild.lua; the code and member list: adapters/Vault.lua (never CommunitiesForeverDB: the uploader sends
-- that file to the website). Wire reference: docs/SYNC.md "Guild invites (CF-84)".
--   Code: a member types it in /cf settings; members' addons spread it over the guild's addon channel (GKEY,
--     GKEYHI); the newest version wins (GuildInvite.newer). Without a code everything here stays off.
--   Members: keep the guild member list for alts and the characters removed from the guild (Vault, GKICK), answer a
--     valid request (GINVREQ) with GINVACK, claim it on the guild channel (GINVCLAIM) and show the Invite popup
--     (CF-87: addons may not invite, V126; the popup runs /ginvite); a refused invite is reported back (GINVFAIL).
--   Alt: a character outside the picked guild whispers a request to the stored members, most recently online
--     first, one at a time, until one invites; then says "Click Accept" (CF-87: no AcceptGuild from addon code).
--     Another faction or realm stops it for good, with one chat line.
local _, ns = ...

local GuildInvites = {}

-- Internal message: the guild code was set or replaced (the settings window shows its status).
GuildInvites.CHANGED = "CF_GUILD_CODE_CHANGED"

GuildInvites.SET = "Guild code saved. Members' addons share it with each other in the guild."
GuildInvites.SET_ERRORS = {
  short = "The guild code needs at least 6 characters.",
  long = "The guild code can have at most 64 characters.",
  invalid = "The guild code can't contain | or line breaks.",
  novault = "Guild invites need the CommunitiesForever_Vault folder in Interface\\AddOns (it comes with the addon).",
  noguild = "Pick your guild as the community first.",
}
GuildInvites.ASKED = "Asked %s for an invite into %s."
GuildInvites.NO_ANSWER = "No member of %s answered your guild invite request. /reload tries again."
GuildInvites.CLICK_ACCEPT = "Click Accept to join %s."
GuildInvites.INVITED = "Invited %s into the guild."
-- Shown once per character, then it never asks again.
GuildInvites.STOPPED = {
  faction = "This character can't join %s: the guild is on the other faction. It won't ask for an invite again.",
  realm = "This character can't join %s: the guild is on another realm. It won't ask for an invite again.",
}

local addonRef, codec
local events -- own AceEvent object for internal messages
local alt    -- the alt's request in progress: { id, guild, code, candidates, index, timer, attempts, done }
local requestedAt   -- server time of our last request or ack ("Click Accept" window)
local seen, lastHandled = {}, {} -- member side: request ids handled or claimed; requester -> time
-- member side: [lower-case name] = { name, raw, friend, id, at } popups shown, waiting for "You have invited"
-- (at: the Invite click, for refusal texts)
local pending = {}
local answerTimer, lastAnswerAt
local debugging = false

local function now() return GetServerTime() end

local function trace(text, ...)
  if debugging then addonRef:Print("|cffa0a0a0[guild]|r " .. string.format(text, ...)) end
end

function GuildInvites.setDebug(on) debugging = on and true or false end
function GuildInvites.debugOn() return debugging end

-- The picked guild's name (remembered account-wide, CF-83), or nil when the community is not a guild.
local function rememberedGuild()
  if not ns.CommunitySelection.isGuild() then return nil end
  return ns.CommunitySelection.name()
end

-- The guild this character is in, from the club list: its name, or nil when in no guild.
local function currentGuild()
  local guildType = ns.Community.guildType()
  for _, club in ipairs(ns.Community.subscribedClubs()) do
    if club.clubType == guildType then return club.name or "" end
  end
  return nil
end

-- The picked guild's name while this character is in it, else nil.
local function memberGuild()
  local remembered = rememberedGuild()
  if remembered and ns.GuildInvite.same(currentGuild(), remembered) then return remembered end
  return nil
end

local function entryOf(guild, create)
  return guild and ns.Vault.guild(guild, create)
end

local function storedKey(guild)
  local entry = entryOf(guild)
  if entry and type(entry.code) == "string" and type(entry.at) == "number" then
    return { code = entry.code, v = type(entry.v) == "number" and entry.v or 0, at = entry.at }
  end
  return nil
end

local function encode(message)
  return codec:encode(message)
end

local function decode(text)
  local message = codec:decode(text)
  if type(message) ~= "table" or type(message.t) ~= "string" then return nil end
  return message
end

local function sendGuild(message)
  local result = ns.Guild.send(ns.GuildInvite.PREFIX, encode(message))
  trace("to the guild: %s -> %s", message.t, tostring(result))
end

local function whisper(name, message)
  ns.Guild.whisper(name, ns.GuildInvite.PREFIX, encode(message))
  trace("to %s: %s", name, message.t)
end

local function randomId()
  return string.format("%04x%04x", math.random(0, 65535), math.random(0, 65535))
end

-- ===== The code =====

local function sendKey(guild)
  local key = storedKey(guild)
  if key then sendGuild({ t = "GKEY", k = key.code, v = key.v, at = key.at }) end
end

-- Another member has an older code (or none): answer with ours after a random moment, unless someone else's answer
-- comes first; at most once per KEY_ANSWER_COOLDOWN.
local function scheduleKeyAnswer(guild)
  if answerTimer then return end
  if lastAnswerAt and ns.Transport.now() - lastAnswerAt < ns.GuildInvite.KEY_ANSWER_COOLDOWN then return end
  local delay = ns.GuildInvite.KEY_ANSWER_MIN
    + math.random() * (ns.GuildInvite.KEY_ANSWER_MAX - ns.GuildInvite.KEY_ANSWER_MIN)
  answerTimer = C_Timer.NewTimer(delay, function()
    answerTimer = nil
    lastAnswerAt = ns.Transport.now()
    if memberGuild() == guild then sendKey(guild) end
  end)
end

local function cancelKeyAnswer()
  if answerTimer then answerTimer:Cancel() end
  answerTimer = nil
end

local function onKey(message)
  local guild = memberGuild()
  if not guild then return end
  local stored = storedKey(guild)
  local key = ns.GuildInvite.acceptKey(stored, { code = message.k, v = message.v, at = message.at }, now())
  if key then
    local entry = entryOf(guild, true)
    if not entry then return end
    entry.code, entry.v, entry.at = key.code, key.v, key.at
    cancelKeyAnswer()
    trace("guild code version %s taken (newer)", tostring(key.v))
    addonRef:SendMessage(GuildInvites.CHANGED)
  elseif stored and stored.code == message.k and stored.v == message.v and stored.at == message.at then
    cancelKeyAnswer() -- someone else already answered with the same code
  elseif stored then
    scheduleKeyAnswer(guild) -- theirs is older (or not valid): answer with ours
  end
end

local function onKeyHello(message)
  local guild = memberGuild()
  local stored = guild and storedKey(guild)
  if stored and not (type(message.v) == "number" and message.v >= stored.v) then scheduleKeyAnswer(guild) end
end

-- True when the vault (the companion folder) is there: without it the feature is off.
function GuildInvites.available()
  return ns.Vault.available()
end

-- When the picked guild's code was set (server time), or nil when there is none.
function GuildInvites.codeSetAt()
  local key = storedKey(rememberedGuild())
  return key and key.at or nil
end

-- Sets the picked guild's code (typed in /cf settings). Returns true, or nil and a message (GuildInvites.SET_ERRORS).
-- Its version is one more than the stored one, so it beats every code this client knows of, whatever the clocks say.
function GuildInvites.setCode(text)
  if not GuildInvites.available() then return nil, GuildInvites.SET_ERRORS.novault end
  local guild = rememberedGuild()
  if not guild then return nil, GuildInvites.SET_ERRORS.noguild end
  local code, reason = ns.GuildInvite.cleanCode(text)
  if not code then
    if reason == "empty" then return nil end -- an empty field changes nothing
    return nil, GuildInvites.SET_ERRORS[reason]
  end
  local entry = entryOf(guild, true)
  entry.v = ns.GuildInvite.nextVersion(storedKey(guild))
  entry.code, entry.at = code, now()
  cancelKeyAnswer()
  if memberGuild() then sendKey(guild) end
  addonRef:SendMessage(GuildInvites.CHANGED)
  return true
end

-- ===== The member list for alts, and removed characters =====

local IN_GAME = { [1] = true, [4] = true, [5] = true } -- Online, Away, Busy (as core/Linker.lua)

local function keepRoster()
  local guild = memberGuild()
  if not guild or not GuildInvites.available() then return end
  local members = {}
  for guid, m in pairs(ns.MemberTracker.members()) do
    members[guid] = { name = m.name, online = IN_GAME[m.presence] == true }
  end
  if next(members) == nil then return end -- not loaded yet: keep what we have
  local entry = entryOf(guild, true)
  local place = ns.Guild.place()
  entry.faction, entry.realm = place.faction, place.realm -- an alt compares its own (another faction or realm)
  local roster, gone = ns.GuildInvite.updateRoster(entry.roster, members, now())
  entry.roster = roster
  ns.GuildInvite.liftRemoved(entry.removed, members) -- back in the guild: invited by hand, so lifted
  for guid, name in pairs(gone) do
    entry.removed = ns.GuildInvite.markRemoved(entry.removed, guid, name, now())
    trace("%s left the guild: never invited by itself again", name)
    sendGuild({ t = "GKICK", g = guid, n = name, at = now() })
  end
end

-- Another member saw a character leave the guild (GKICK).
local function onKick(message)
  local guild = memberGuild()
  if not guild or type(message.g) ~= "string" or type(message.n) ~= "string" then return end
  if ns.MemberTracker.members()[message.g] then return end -- in the guild as far as we see
  local entry = entryOf(guild, true)
  if not entry then return end
  entry.removed = ns.GuildInvite.markRemoved(entry.removed, message.g, message.n, now())
end

-- ===== The alt's request =====

local function ownGuids()
  local set = {}
  for guid in pairs(addonRef.db.global.self.chars or {}) do set[guid] = true end
  local guid = ns.SelfInfo.guid()
  if guid then set[guid] = true end
  return set
end

local askNext

local function stopTimer()
  if alt and alt.timer then alt.timer:Cancel() end
  if alt then alt.timer = nil end
end

-- This character can't join (another faction or realm): one chat line, then it never asks again.
local function stopForGood(guild, reason)
  stopTimer()
  if alt then alt.done = true end
  local entry = entryOf(guild, true)
  local guid = ns.SelfInfo.guid()
  if not (entry and guid) then return end
  entry.stopped = type(entry.stopped) == "table" and entry.stopped or {}
  if entry.stopped[guid] then return end
  entry.stopped[guid] = reason
  addonRef:Print(string.format(GuildInvites.STOPPED[reason], guild))
end

local function startAttempt()
  local guild = rememberedGuild()
  local key = storedKey(guild)
  if not (guild and key) or currentGuild() then return end
  local entry = entryOf(guild)
  local guid = ns.SelfInfo.guid()
  if type(entry.stopped) == "table" and guid and entry.stopped[guid] then return end -- told once already
  local mismatch = ns.GuildInvite.placeMismatch(entry, ns.Guild.place())
  if mismatch then
    stopForGood(guild, mismatch)
    return
  end
  local candidates = ns.GuildInvite.candidates(entry.roster, ownGuids())
  if #candidates == 0 then
    trace("no guild members stored to ask")
    return
  end
  alt = alt or { attempts = 0 }
  alt.attempts = alt.attempts + 1
  alt.guild, alt.code, alt.candidates, alt.index, alt.done = guild, key.code, candidates, 0, false
  alt.id = randomId()
  trace("attempt %d: %d members to ask", alt.attempts, #candidates)
  askNext()
end

local function attemptFailed()
  if alt.attempts >= ns.GuildInvite.MAX_ATTEMPTS then
    alt.done = true
    -- Once a day per character: an alt that can't reach anyone (another ruleset, members never online) stays quiet.
    local entry, guid = entryOf(alt.guild, true), ns.SelfInfo.guid()
    if entry and guid then
      entry.quiet = type(entry.quiet) == "table" and entry.quiet or {}
      local last = entry.quiet[guid]
      if type(last) == "number" and now() - last < ns.GuildInvite.NO_ANSWER_QUIET then return end
      entry.quiet[guid] = now()
    end
    addonRef:Print(string.format(GuildInvites.NO_ANSWER, alt.guild))
    return
  end
  alt.timer = C_Timer.NewTimer(ns.GuildInvite.RETRY_SECONDS, function()
    alt.timer = nil
    if not currentGuild() then startAttempt() end
  end)
end

function askNext()
  stopTimer()
  if not alt or alt.done then return end
  alt.index = alt.index + 1
  local name = alt.candidates[alt.index]
  if not name then
    attemptFailed()
    return
  end
  local at = now()
  local selfInfo = ns.SelfInfo.read()
  requestedAt = at
  -- The name exactly as the guild's member list gave it (C_Club.GetMemberInfo), never built from parts (V131).
  whisper(name, { t = "GINVREQ", id = alt.id, at = at,
                  p = ns.GuildInvite.proof(alt.code, alt.guild, selfInfo.name, at), guid = selfInfo.guid,
                  dn = ns.GuildInvite.cleanDisplayName(addonRef.db.global.self.displayName) })
  alt.timer = C_Timer.NewTimer(ns.GuildInvite.ACK_WAIT, function()
    alt.timer = nil
    askNext()
  end)
end

-- The member that took our request could not invite (refused, no rights, popup ignored): ask the next one with a
-- new request id (the old one is claimed in the guild).
local function askNextMember()
  if not alt or alt.done then return end
  alt.id = randomId()
  askNext()
end

local function onAck(message, sender)
  if not alt or alt.done or message.id ~= alt.id then return end
  stopTimer()
  requestedAt = now()
  addonRef:Print(string.format(GuildInvites.ASKED, sender, alt.guild))
  alt.timer = C_Timer.NewTimer(ns.GuildInvite.INVITE_WAIT, function()
    alt.timer = nil
    trace("no invite from %s: asking the next member", sender)
    askNextMember()
  end)
end

local function onFail(message, sender)
  if not alt or alt.done or message.id ~= alt.id then return end
  trace("%s could not invite: %s", sender, tostring(message.r))
  if message.r == "faction" then
    stopForGood(alt.guild, "faction")
  else
    askNextMember()
  end
end

-- "No player named X is currently playing" after our whisper: that member is offline, ask the next one at once.
local function onWhisperFailed(name)
  if not alt or alt.done or not alt.timer then return end
  if ns.GuildInvite.same(alt.candidates[alt.index], name) then
    stopTimer()
    alt.timer = C_Timer.NewTimer(0.2, function() -- the addon's pace between whispers
      alt.timer = nil
      askNext()
    end)
  end
end

-- GUILD_INVITE_REQUEST on the alt, shortly after our request, for the remembered guild: Blizzard's popup has the
-- Accept button; one chat line says to click it (CF-87: AcceptGuild is not called from addon code, V127).
local function onInvited(_, guildName)
  local guild = rememberedGuild()
  if not ns.GuildInvite.shouldAccept(requestedAt, guildName, guild, now()) then return end
  stopTimer()
  if alt then alt.done = true end
  addonRef:Print(string.format(GuildInvites.CLICK_ACCEPT, guild))
end

-- ===== The member's side =====

local function friendOf(message)
  local people = addonRef.db.global.people
  local key = type(message.guid) == "string" and ns.Identity.personOfGuid(people, message.guid)
  local person = key and people[key]
  local name = person and ns.GuildInvite.cleanDisplayName(person.displayName)
  if not name and key and not key:find("^aid:") and not key:find("^member:") then
    name = key:match("^([^#]+)#") -- the BattleTag's name part, as the Friends tab shows people
  end
  return name or ns.GuildInvite.cleanDisplayName(message.dn)
end

-- The member's popup: the click runs /ginvite (CF-87). The entry waits in pending for "You have invited" (the
-- confirmation line) or a refusal text right after the click (GINVFAIL to the alt).
local function invite(entry)
  pending[entry.name:lower()] = entry
  -- The name exactly as the game reported the whisper's sender (V131).
  ns.GuildInvitePopup.show(entry.raw, entry.friend, entry.name, function(how)
    entry.at = ns.Transport.now()
    trace("invite %s: %s", entry.raw, tostring(how))
  end)
end

local function onRequest(message, sender, raw)
  local guild = memberGuild()
  local key = guild and storedKey(guild)
  local entry = guild and entryOf(guild)
  local names = {}
  for _, m in pairs(ns.MemberTracker.members()) do
    if type(m.name) == "string" then names[m.name:lower()] = true end
  end
  local ok, reason = ns.GuildInvite.checkRequest(message, {
    code = key and key.code, guildName = guild, sender = sender, now = now(), memberNames = names, seen = seen,
    lastHandled = lastHandled, removedNames = ns.GuildInvite.removedNames(entry and entry.removed),
  })
  if not ok then
    trace("request from %s refused: %s", tostring(sender), tostring(reason))
    return
  end
  seen[message.id] = true
  lastHandled[sender:lower()] = now()
  whisper(raw, { t = "GINVACK", id = message.id })
  sendGuild({ t = "GINVCLAIM", id = message.id, n = sender })
  invite({ name = sender, raw = raw, friend = friendOf(message), id = message.id })
end

local function onClaim(message, sender)
  if type(message.id) == "string" and #message.id <= 32 then
    seen[message.id] = true
    trace("%s handles request %s", tostring(sender), message.id)
  end
end

local function onInviteSent(name)
  local short = ns.Transport.shortName(name)
  local entry = short and pending[short:lower()]
  if not entry then
    -- A manual invite (not one of ours): it lifts a removal of that character (Nico, 2026-11-05).
    local guild = memberGuild()
    local stored = guild and entryOf(guild)
    if stored and short then ns.GuildInvite.liftRemoved(stored.removed, nil, short) end
    return
  end
  pending[short:lower()] = nil
  addonRef:Print(string.format(GuildInvites.INVITED, ns.GuildInvite.altLabel(entry.name, entry.friend)))
end

-- The game refused one of our invites (no rights, other faction, already in a guild, ...): tell the alt, so it asks
-- the next member at once (or stops, for another faction). Without a name: our most recent invite.
local function onInviteFailed(kind, name)
  local entry
  local short = name and ns.Transport.shortName(name)
  if short then
    entry = pending[short:lower()]
  else
    for _, e in pairs(pending) do
      if e.at and (not entry or e.at > entry.at) then entry = e end
    end
  end
  -- Only right after a click on our popup: "no permission" is a generic text the game shows for other things too.
  if not (entry and entry.at) or ns.Transport.now() - entry.at > ns.GuildInvite.CONFIRM_WAIT * 3 then return end
  pending[entry.name:lower()] = nil
  trace("invite %s refused: %s", entry.raw, tostring(kind))
  whisper(entry.raw, { t = "GINVFAIL", id = entry.id, r = kind })
end

-- Nothing of ours should be blocked any more (CF-87); /cf sync debug shows it if something is.
local function onBlocked(functionName)
  trace("blocked: %s", tostring(functionName))
end

-- ===== Wiring =====

local function onWhisper(text, sender, raw)
  if not sender or sender == "" then return end
  local message = decode(text)
  if not message then return end
  raw = type(raw) == "string" and raw ~= "" and raw or sender
  if message.t == "GINVREQ" then
    onRequest(message, sender, raw)
  elseif message.t == "GINVACK" then
    onAck(message, sender)
  elseif message.t == "GINVFAIL" then
    onFail(message, sender)
  end
end

local function onGuildMessage(text, sender)
  if not sender or ns.GuildInvite.same(sender, ns.SelfInfo.fullName()) then return end -- our own, back
  local message = decode(text)
  if not message then return end
  if message.t == "GKEY" then
    onKey(message)
  elseif message.t == "GKEYHI" then
    onKeyHello(message)
  elseif message.t == "GINVCLAIM" then
    onClaim(message, sender)
  elseif message.t == "GKICK" then
    onKick(message)
  end
end

-- After login, once the club list had time to load: members share their code (or ask for one), alts ask.
local function afterLogin()
  if not GuildInvites.available() then return end -- no vault folder: the feature is off
  keepRoster()
  local guild = memberGuild()
  if guild then
    local key = storedKey(guild)
    if key then sendKey(guild) else sendGuild({ t = "GKEYHI", v = 0 }) end
  elseif not currentGuild() then
    startAttempt()
  end
end

function GuildInvites.start(addon)
  addonRef = addon
  codec = ns.Protocol.codec(LibStub("LibSerialize"), LibStub("LibDeflate"))
  alt, requestedAt = nil, nil
  seen, lastHandled, pending = {}, {}, {}
  answerTimer, lastAnswerAt, debugging = nil, nil, false
  events = LibStub("AceEvent-3.0"):Embed({})
  ns.Guild.registerPrefix(ns.GuildInvite.PREFIX)
  ns.Guild.watch(addon, ns.GuildInvite.PREFIX)
  events:RegisterMessage(ns.Guild.WHISPER_RECEIVED, function(_, text, sender, raw) onWhisper(text, sender, raw) end)
  events:RegisterMessage(ns.Guild.GUILD_RECEIVED, function(_, text, sender) onGuildMessage(text, sender) end)
  events:RegisterMessage(ns.Guild.INVITED, function(_, inviter, guildName) onInvited(inviter, guildName) end)
  events:RegisterMessage(ns.Guild.BLOCKED, function(_, fn) onBlocked(fn) end)
  events:RegisterMessage(ns.Guild.COMBAT_STARTED, function() ns.GuildInvitePopup.combatStarted() end)
  events:RegisterMessage(ns.Guild.COMBAT_ENDED, function() ns.GuildInvitePopup.combatEnded() end)
  events:RegisterMessage(ns.Guild.INVITE_SENT, function(_, name) onInviteSent(name) end)
  events:RegisterMessage(ns.Guild.INVITE_FAILED, function(_, kind, name) onInviteFailed(kind, name) end)
  events:RegisterMessage(ns.Transport.WHISPER_FAILED, function(_, name) onWhisperFailed(name) end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function() keepRoster() end)
  C_Timer.NewTimer(ns.GuildInvite.LOGIN_DELAY, afterLogin)
end

ns.GuildInvites = GuildInvites
return GuildInvites
