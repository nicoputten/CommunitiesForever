-- GroupAsks: "Who's up for it?" (CF-27). Sends an ask for a dungeon to friends who run the addon and
-- have a character in range, shows received asks as a chat line with a sound and [Join] [Later] [No]
-- links, collects the answers, and helps into the party: the joiner's click asks you for an invite, and
-- you get an [Invite] link as well (which of the two works on Forever: VERIFY.md V48).
local _, ns = ...

local GroupAsks = {}

-- Internal message: your ask or its answers changed (the Dungeons tab refreshes).
GroupAsks.CHANGED = "CF_GROUP_ASK_CHANGED"

local GOLD, GREY = "|cffffd100", "|cffa0a0a0"
local ANSWER_TEXT = { join = "Join", later = "Later", no = "No" }

local addonRef
local mine         -- your ask: { id, dungeon, at, recipients, answers = { [battleTag] = { answer, char } } }
local lastAskAt
local received = {} -- asks to you: [id] = { battleTag, gameAccountID, from, char, dungeon, at }
local counter = 0

local function say(text) addonRef:Print(text) end
local function now() return GetServerTime() end

local function own() return addonRef.db.global.self end

local function ownName()
  return ns.Linker.displayName(own().battleTag or "", own().displayName)
end

function GroupAsks.receiving()
  return addonRef.db.global.settings.groupAsks ~= false
end

-- Your ask while it can still be answered, or nil.
function GroupAsks.current()
  if mine and not ns.GroupAsk.expired(mine, now()) then return mine end
  return nil
end

-- May you ask now? true, or false and the seconds to wait.
function GroupAsks.canAsk()
  return ns.GroupAsk.canAsk(lastAskAt, now())
end

-- Asks who's up for the dungeon. Returns the number of friends asked (0: nobody to ask), or nil and the
-- seconds to wait when you asked too recently. note (CF-47): optional, shown with the ask.
function GroupAsks.ask(dungeon, note)
  local ok, wait = GroupAsks.canAsk()
  if not ok then
    say(string.format("You can ask again in %d min.", math.ceil(wait / 60)))
    return nil, wait
  end
  local recipients = ns.GroupAsk.recipients(dungeon, ns.Sync.online(), addonRef.db.global.people,
    own().battleTag)
  if #recipients == 0 then
    say("Nobody with CommunitiesForever is online with a character in range of " .. dungeon.name .. ".")
    return 0
  end
  counter = counter + 1
  local t = now()
  local id = string.format("%d%d", t, counter)
  local message = ns.GroupAsk.message(id, dungeon, ownName(), ns.SelfInfo.read().name, t, note)
  local names = {}
  for i, r in ipairs(recipients) do
    ns.Messenger.send(r.gameAccountID, message)
    names[i] = tostring(r.displayName or r.battleTag)
  end
  mine = { id = id, dungeon = dungeon, at = t, recipients = recipients, answers = {} }
  lastAskAt = t
  say(string.format("Asked %s who's up for %s.", table.concat(names, ", "), dungeon.name))
  addonRef:SendMessage(GroupAsks.CHANGED)
  return #recipients
end

-- An ask from a friend: a chat line with a sound and the answer links.
local function onAsk(message, battleTag, gameAccountID)
  if not GroupAsks.receiving() then return end
  local ask = ns.GroupAsk.cleanAsk(message)
  if not ask then return end
  ask.battleTag, ask.gameAccountID, ask.at = battleTag, gameAccountID, now()
  received[ask.id] = ask
  local d = ask.dungeon
  say(string.format("%s%s|r asks: %s now? %s(%d-%d)|r", GOLD, tostring(ask.from or battleTag), d.name, GREY,
    d.min, d.max) .. (ask.note and (" \226\128\156" .. ask.note .. "\226\128\157") or ""))
  local chars = ns.GroupAsk.charsInRange(own().chars, d.min, d.max)
  if #chars > 0 then
    local list = {}
    for i, c in ipairs(chars) do list[i] = string.format("%s %d", tostring(c.name), c.level) end
    say("  You could come on: " .. table.concat(list, ", "))
  end
  say("  " .. ns.ChatLinks.link("ask:join:" .. ask.id, "Join") .. "  "
    .. ns.ChatLinks.link("ask:later:" .. ask.id, "Later") .. "  " .. ns.ChatLinks.link("ask:no:" .. ask.id, "No"))
  ns.ChatFrames.playSound()
end

-- You clicked an answer link.
local function answer(kind, id)
  local ask = received[id]
  if not ask or ns.GroupAsk.expired(ask, now()) then
    say("This ask has expired.")
    return
  end
  ns.Messenger.send(ask.gameAccountID, { t = "ANSWER", id = id, answer = kind, from = ownName(),
                                         char = ns.SelfInfo.read().name })
  say(string.format("You answered %s to %s.", ANSWER_TEXT[kind], tostring(ask.from or ask.battleTag)))
  if kind == "join" then
    if ns.Party.requestInvite(ask.char) then
      say("Asked " .. tostring(ask.char) .. " for a party invite.")
    else
      say(tostring(ask.from or ask.battleTag) .. " gets a link to invite you.")
    end
  end
end

-- An answer to your ask.
local function onAnswer(message, battleTag)
  local a = ns.GroupAsk.cleanAnswer(message)
  local ask = GroupAsks.current()
  if not a or not ask or a.id ~= ask.id then return end
  local recipient
  for _, r in ipairs(ask.recipients) do
    if r.battleTag == battleTag then recipient = r end
  end
  if not recipient then return end
  ask.answers[battleTag] = { answer = a.answer, char = a.char }
  local name = tostring(recipient.displayName or battleTag)
  if a.answer == "join" then
    say(string.format("%s%s|r joins your %s run%s: %s", GOLD, name, ask.dungeon.name,
      a.char and (" on " .. a.char) or "", ns.ChatLinks.link("invite:" .. battleTag, "Invite")))
  else
    say(string.format("%s: %s for %s.", name, a.answer == "later" and "later" or "not now", ask.dungeon.name))
  end
  addonRef:SendMessage(GroupAsks.CHANGED)
end

-- You clicked [Invite] for someone who joins.
local function invite(battleTag)
  local ask = GroupAsks.current()
  local a = ask and ask.answers[battleTag]
  if not a then return end
  local gameAccountID
  for _, r in ipairs(ask.recipients) do
    if r.battleTag == battleTag then gameAccountID = r.gameAccountID end
  end
  local how = ns.Party.invite(a.char, gameAccountID)
  if how then
    say("Invited " .. tostring(a.char or battleTag) .. ".")
  else
    say("Could not invite " .. tostring(a.char or battleTag) .. " from the addon: invite them yourself.")
  end
end

local function onLink(path)
  local kind, id = path:match("^ask:(%a+):(%w+)$")
  if kind and ns.GroupAsk.ANSWERS[kind] then
    answer(kind, id)
    return
  end
  local battleTag = path:match("^invite:(.+)$")
  if battleTag then invite(battleTag) end
end

function GroupAsks.start(addon)
  addonRef = addon
  mine, lastAskAt, received, counter = nil, nil, {}, 0
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.Messenger.RECEIVED, function(_, message, battleTag, gameAccountID)
    if message.t == "ASK" then
      onAsk(message, battleTag, gameAccountID)
    elseif message.t == "ANSWER" then
      onAnswer(message, battleTag)
    end
  end)
  events:RegisterMessage(ns.ChatLinks.CLICKED, function(_, path) onLink(path) end)
end

ns.GroupAsks = GroupAsks
return GroupAsks
