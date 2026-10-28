-- GroupAsk: "Who's up for it?" asks for a dungeon (CF-27). Pure Lua, no WoW globals.
-- The asker sends ASK to friends who run the addon, are online in Forever and have any character in
-- the dungeon's level range; they answer join, later or no (ANSWER).
local _, ns = ...

local GroupAsk = {}

GroupAsk.EXPIRE_SECONDS = 600   -- an ask can be answered for 10 minutes
GroupAsk.THROTTLE_SECONDS = 180 -- at most one ask per 3 minutes
GroupAsk.ANSWERS = { join = true, later = true, no = true }

local MAX_TEXT = 40
local MAX_LEVEL = 100

local function cleanText(value)
  if type(value) ~= "string" then return nil end
  local text = value:gsub("|", ""):sub(1, MAX_TEXT)
  return text ~= "" and text or nil
end

local function cleanLevel(value)
  if type(value) ~= "number" or value ~= value then return nil end
  return math.max(1, math.min(MAX_LEVEL, math.floor(value)))
end

-- Characters of a list { { name, level, ... } } in [min, max], highest level first (then name).
function GroupAsk.charsInRange(chars, min, max)
  local result = {}
  for _, c in pairs(chars or {}) do
    if type(c) == "table" and type(c.level) == "number" and c.level >= min and c.level <= max then
      result[#result + 1] = { name = c.name, level = c.level, classFile = c.classFile }
    end
  end
  table.sort(result, function(a, b)
    if a.level ~= b.level then return a.level > b.level end
    return tostring(a.name) < tostring(b.name)
  end)
  return result
end

--[[ Who to ask: friends online in Forever (online = { [battleTag] = { gameAccountID } }) who run the addon
(records = { [battleTag] = record }, the stored records of people) with any character in range. The
characters come from their record (also alts outside the community). selfTag is skipped.
Returns { { battleTag, gameAccountID, displayName, chars = { { name, level } } } }, by display name. ]]
function GroupAsk.recipients(dungeon, online, records, selfTag)
  local result = {}
  for battleTag, presence in pairs(online or {}) do
    local record = records and records[battleTag]
    -- CF-28: a Battle.net game account, or a community member's character name (presence.target).
    local target = type(presence) == "table" and (presence.gameAccountID or presence.target)
    if battleTag ~= selfTag and record and target then
      local chars = GroupAsk.charsInRange(record.chars, dungeon.min, dungeon.max)
      if #chars > 0 then
        result[#result + 1] = { battleTag = battleTag, gameAccountID = target,
                                displayName = record.displayName, chars = chars }
      end
    end
  end
  table.sort(result, function(a, b)
    return tostring(a.displayName or a.battleTag) < tostring(b.displayName or b.battleTag)
  end)
  return result
end

-- May you ask now? Returns true, or false and the seconds to wait.
function GroupAsk.canAsk(lastAskAt, now)
  if not lastAskAt then return true end
  local wait = GroupAsk.THROTTLE_SECONDS - (now - lastAskAt)
  if wait <= 0 then return true end
  return false, wait
end

function GroupAsk.expired(ask, now)
  return not ask or not ask.at or now - ask.at >= GroupAsk.EXPIRE_SECONDS
end

-- The ASK message for a dungeon. id: unique per asker and ask.
-- note (CF-47, optional): what the asker typed; older clients ignore it.
-- post (CF-51, optional): { item, guid, role } when the asker ticked "Also post on Discord": the message gets
-- post = true, the asker's Pending item id and character, so every friend's file carries the ask to the site.
function GroupAsk.message(id, dungeon, from, char, now, note, post)
  local m = { t = "ASK", id = id,
              dungeon = { id = dungeon.id, name = dungeon.name, min = dungeon.min, max = dungeon.max },
              from = from, char = char, at = now, note = note }
  if post and post.item then
    m.post, m.item, m.guid, m.role = true, post.item, post.guid, post.role
  end
  return m
end

local ROLES = { tank = true, heal = true, dps = true }
local function cleanId(value)
  return type(value) == "string" and value:match("^[%w%-:.]+$") and #value <= 64 and value or nil
end

-- A received ASK with only the expected fields, cleaned, or nil.
function GroupAsk.cleanAsk(message)
  if type(message) ~= "table" or type(message.dungeon) ~= "table" then return nil end
  local d = message.dungeon
  local id, name, min, max = cleanText(message.id), cleanText(d.name), cleanLevel(d.min), cleanLevel(d.max)
  if not (id and name and min and max and min <= max) then return nil end
  local ask = { id = id, dungeon = { id = cleanText(d.id), name = name, min = min, max = max },
                from = cleanText(message.from), char = cleanText(message.char),
                note = type(message.note) == "string" and message.note:gsub("[|%c]", ""):sub(1, 120) or nil }
  -- CF-51: a posted ask, carried for the site with the asker's item id and character.
  local item = cleanId(message.item)
  if message.post == true and item then
    ask.post, ask.item = true, item
    ask.guid = cleanId(message.guid)
    ask.role = ROLES[message.role] and message.role or nil
    ask.sentAt = type(message.at) == "number" and message.at == message.at and math.floor(message.at) or nil
  end
  return ask
end

-- CF-51: every online peer running the addon (a posted ask goes to all of them, in range or not).
function GroupAsk.peers(online, records, selfTag)
  local result = {}
  for battleTag, presence in pairs(online or {}) do
    local target = type(presence) == "table" and (presence.gameAccountID or presence.target)
    if battleTag ~= selfTag and records and records[battleTag] and target then
      result[#result + 1] = { battleTag = battleTag, gameAccountID = target }
    end
  end
  table.sort(result, function(a, b) return a.battleTag < b.battleTag end)
  return result
end

-- A received ANSWER, cleaned, or nil.
function GroupAsk.cleanAnswer(message)
  if type(message) ~= "table" or not GroupAsk.ANSWERS[message.answer] then return nil end
  local id = cleanText(message.id)
  if not id then return nil end
  return { id = id, answer = message.answer, from = cleanText(message.from), char = cleanText(message.char) }
end

--[[ The state of your ask: answers by person and who has not answered yet.
  ask = { recipients = { { battleTag, displayName } }, answers = { [battleTag] = { answer, char } } }
Returns { join = { name, ... }, later = {...}, no = {...}, waiting = {...} } with display names (and the
character for join: "Ben (Bob Example)"). ]]
function GroupAsk.summary(ask)
  local result = { join = {}, later = {}, no = {}, waiting = {} }
  for _, r in ipairs(ask and ask.recipients or {}) do
    local name = tostring(r.displayName or r.battleTag)
    local a = ask.answers and ask.answers[r.battleTag]
    if not a then
      table.insert(result.waiting, name)
    elseif a.answer == "join" then
      table.insert(result.join, a.char and (name .. " (" .. a.char .. ")") or name)
    else
      table.insert(result[a.answer], name)
    end
  end
  return result
end

ns.GroupAsk = GroupAsk
return GroupAsk
