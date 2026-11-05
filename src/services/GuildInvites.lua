-- GuildInvites: automatic guild invites for alts of members (CF-84). Rules: core/GuildInvite.lua; WoW calls:
-- adapters/Guild.lua; the code and member list: adapters/Vault.lua (never CommunitiesForeverDB: the uploader sends
-- that file to the website). Wire reference: docs/SYNC.md "Guild invites (CF-84)".
--   Code: a member types it in /cf settings; members' addons spread it over the guild's addon channel (GKEY,
--     GKEYHI); the newest wins (GuildInvite.newer). Without a code everything here stays off.
--   Members: keep the guild member list for alts (Vault), answer a valid request (GINVREQ) with GINVACK, claim it on
--     the guild channel (GINVCLAIM) and invite, or show a one-button popup when the invite needs a click.
--   Alt: a character outside the picked guild whispers a request to the stored members, most recently online
--     first, one at a time, until one acknowledges; then accepts the guild's invite by itself.
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
GuildInvites.ASKED = "Asked %s for an invite into %s. It is accepted by itself."
GuildInvites.NO_ANSWER = "No member of %s answered your guild invite request. /reload tries again."
GuildInvites.ACCEPTING = "Joining %s: accepting the invite from %s."
GuildInvites.CLICK_ACCEPT = "Click Accept to join %s."
GuildInvites.INVITED = "Invited %s into the guild."

local addonRef, codec
local events -- own AceEvent object for internal messages
local alt    -- the alt's request in progress: { id, guild, candidates, index, timer, attempts, done }
local requestedAt   -- server time of our last request (auto-accept window)
local seen, lastHandled = {}, {} -- member side: request ids handled or claimed; requester -> time
local pending = {}  -- member side: [lower-case name] = { name, friend, timer } invites waiting for "You have invited"
local needsClick = false -- the game blocked an invite without a click this session
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
    return { code = entry.code, at = entry.at }
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
  if key then sendGuild({ t = "GKEY", k = key.code, at = key.at }) end
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
  local key = ns.GuildInvite.acceptKey(stored, { code = message.k, at = message.at }, now())
  if key then
    local entry = entryOf(guild, true)
    if not entry then return end
    entry.code, entry.at = key.code, key.at
    cancelKeyAnswer()
    trace("guild code from %s taken (newer)", tostring(message.at))
    addonRef:SendMessage(GuildInvites.CHANGED)
  elseif stored and stored.code == message.k and stored.at == message.at then
    cancelKeyAnswer() -- someone else already answered with the same code
  elseif stored then
    scheduleKeyAnswer(guild) -- theirs is older (or not valid): answer with ours
  end
end

local function onKeyHello(message)
  local guild = memberGuild()
  local stored = guild and storedKey(guild)
  if stored and not (type(message.at) == "number" and message.at >= stored.at) then scheduleKeyAnswer(guild) end
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
-- Its time is now, or one second after the stored one when the clock says otherwise, so it is always the newest.
function GuildInvites.setCode(text)
  if not GuildInvites.available() then return nil, GuildInvites.SET_ERRORS.novault end
  local guild = rememberedGuild()
  if not guild then return nil, GuildInvites.SET_ERRORS.noguild end
  local code, reason = ns.GuildInvite.cleanCode(text)
  if not code then
    if reason == "empty" then return nil end -- an empty field changes nothing
    return nil, GuildInvites.SET_ERRORS[reason]
  end
  local stored = storedKey(guild)
  local at = now()
  if stored and stored.at >= at then at = stored.at + 1 end
  local entry = entryOf(guild, true)
  entry.code, entry.at = code, at
  cancelKeyAnswer()
  if memberGuild() then sendKey(guild) end
  addonRef:SendMessage(GuildInvites.CHANGED)
  return true
end

-- ===== The member list for alts =====

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
  entry.roster = ns.GuildInvite.updateRoster(entry.roster, members, now())
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

local function startAttempt()
  local guild = rememberedGuild()
  local key = storedKey(guild)
  if not (guild and key) or currentGuild() then return end
  local entry = entryOf(guild)
  local candidates = ns.GuildInvite.candidates(entry and entry.roster, ownGuids())
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
  whisper(name, { t = "GINVREQ", id = alt.id, at = at,
                  p = ns.GuildInvite.proof(alt.code, alt.guild, selfInfo.name, at), guid = selfInfo.guid,
                  dn = ns.GuildInvite.cleanDisplayName(addonRef.db.global.self.displayName) })
  alt.timer = C_Timer.NewTimer(ns.GuildInvite.ACK_WAIT, function()
    alt.timer = nil
    askNext()
  end)
end

local function onAck(message, sender)
  if not alt or alt.done or message.id ~= alt.id then return end
  stopTimer()
  alt.done = true
  requestedAt = now()
  addonRef:Print(string.format(GuildInvites.ASKED, sender, alt.guild))
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

-- GUILD_INVITE_REQUEST on the alt: accept it by itself for the remembered guild, shortly after our request.
local acceptingGuild
local function onInvited(inviter, guildName)
  local guild = rememberedGuild()
  if not ns.GuildInvite.shouldAccept(requestedAt, guildName, guild, now()) then return end
  acceptingGuild = guild
  if ns.Guild.accept() then
    addonRef:Print(string.format(GuildInvites.ACCEPTING, guild, tostring(inviter)))
  else
    addonRef:Print(string.format(GuildInvites.CLICK_ACCEPT, guild))
  end
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

local function popup(name, friend)
  pending[name:lower()] = nil
  ns.GuildInvitePopup.show(name, friend)
end

local function invite(name, friend)
  if needsClick then
    popup(name, friend)
    return
  end
  local how = ns.Guild.invite(name)
  trace("invite %s: %s", name, tostring(how))
  if not how then
    popup(name, friend)
    return
  end
  if not ns.Guild.canConfirm() then return end -- no "You have invited" text to wait for (V126)
  local entry = { name = name, friend = friend }
  entry.timer = C_Timer.NewTimer(ns.GuildInvite.CONFIRM_WAIT, function()
    entry.timer = nil
    if pending[name:lower()] == entry then
      needsClick = true -- nothing came of it: the invite needs a click on this client
      popup(name, friend)
    end
  end)
  pending[name:lower()] = entry
end

local function onRequest(message, sender)
  local guild = memberGuild()
  local key = guild and storedKey(guild)
  local names = {}
  for _, m in pairs(ns.MemberTracker.members()) do
    if type(m.name) == "string" then names[m.name:lower()] = true end
  end
  local ok, reason = ns.GuildInvite.checkRequest(message, {
    code = key and key.code, guildName = guild, sender = sender, now = now(), memberNames = names, seen = seen,
    lastHandled = lastHandled,
  })
  if not ok then
    trace("request from %s refused: %s", tostring(sender), tostring(reason))
    return
  end
  seen[message.id] = true
  lastHandled[sender:lower()] = now()
  whisper(sender, { t = "GINVACK", id = message.id })
  sendGuild({ t = "GINVCLAIM", id = message.id, n = sender })
  invite(sender, friendOf(message))
end

local function onClaim(message, sender)
  if type(message.id) == "string" and #message.id <= 32 then
    seen[message.id] = true
    trace("%s handles request %s", tostring(sender), message.id)
  end
end

local function onInviteSent(name)
  local entry = type(name) == "string" and pending[name:lower()]
  if not entry then return end
  if entry.timer then entry.timer:Cancel() end
  pending[name:lower()] = nil
  addonRef:Print(string.format(GuildInvites.INVITED, ns.GuildInvite.altLabel(entry.name, entry.friend)))
end

local function onBlocked(functionName)
  local fn = tostring(functionName)
  trace("blocked: %s", fn)
  if fn:find("AcceptGuild", 1, true) then
    if acceptingGuild then addonRef:Print(string.format(GuildInvites.CLICK_ACCEPT, acceptingGuild)) end
    return
  end
  if fn:find("Invite", 1, true) then
    needsClick = true
    for _, entry in pairs(pending) do
      if entry.timer then entry.timer:Cancel() end
      popup(entry.name, entry.friend)
    end
  end
end

-- ===== Wiring =====

local function onWhisper(text, sender)
  if not sender or sender == "" then return end
  local message = decode(text)
  if not message then return end
  if message.t == "GINVREQ" then
    onRequest(message, sender)
  elseif message.t == "GINVACK" then
    onAck(message, sender)
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
  end
end

-- After login, once the club list had time to load: members share their code (or ask for one), alts ask.
local function afterLogin()
  if not GuildInvites.available() then return end -- no vault folder: the feature is off
  keepRoster()
  local guild = memberGuild()
  if guild then
    if storedKey(guild) then sendKey(guild) else sendGuild({ t = "GKEYHI", at = 0 }) end
  elseif not currentGuild() then
    startAttempt()
  end
end

function GuildInvites.start(addon)
  addonRef = addon
  codec = ns.Protocol.codec(LibStub("LibSerialize"), LibStub("LibDeflate"))
  alt, requestedAt, acceptingGuild = nil, nil, nil
  seen, lastHandled, pending = {}, {}, {}
  needsClick, answerTimer, lastAnswerAt, debugging = false, nil, nil, false
  events = LibStub("AceEvent-3.0"):Embed({})
  ns.Guild.registerPrefix(ns.GuildInvite.PREFIX)
  ns.Guild.watch(addon, ns.GuildInvite.PREFIX)
  events:RegisterMessage(ns.Guild.WHISPER_RECEIVED, function(_, text, sender) onWhisper(text, sender) end)
  events:RegisterMessage(ns.Guild.GUILD_RECEIVED, function(_, text, sender) onGuildMessage(text, sender) end)
  events:RegisterMessage(ns.Guild.INVITED, function(_, inviter, guildName) onInvited(inviter, guildName) end)
  events:RegisterMessage(ns.Guild.BLOCKED, function(_, fn) onBlocked(fn) end)
  events:RegisterMessage(ns.Guild.INVITE_SENT, function(_, name) onInviteSent(name) end)
  events:RegisterMessage(ns.Transport.WHISPER_FAILED, function(_, name) onWhisperFailed(name) end)
  events:RegisterMessage(ns.MemberTracker.UPDATED, function() keepRoster() end)
  -- Joined: the guild's club appears. The popup goes once the invite was accepted.
  events:RegisterMessage(ns.Community.CLUBS_CHANGED, function()
    if acceptingGuild and ns.GuildInvite.same(currentGuild(), acceptingGuild) then
      ns.Guild.hideInvitePopup()
      acceptingGuild = nil
    end
  end)
  C_Timer.NewTimer(ns.GuildInvite.LOGIN_DELAY, afterLogin)
end

ns.GuildInvites = GuildInvites
return GuildInvites
