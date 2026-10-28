-- Pending: what the player did in game that has to reach the website (CF-47): runs planned, answers given,
-- asks to post on Discord, and (CF-48) Discord pings; CF-51: friends' posted asks carried for the site, and your
-- answers to them. Pure Lua, no WoW globals.
-- The items live in global.pending; the game writes them to the saved file on /reload or logout, the
-- uploader sends that file, and the site (web WEB-43) turns each item into a run, an answer or a Discord
-- post. Each item has an id, so a file uploaded twice changes nothing. An item stays until the runs data
-- (Data\Runs.lua or a friend's RUNS) lists its id under `received`.
local _, ns = ...

local Pending = {}

Pending.ASK_EXPIRE = 600            -- an ask is posted only within 10 minutes (as CF-27's in-game ask)
Pending.MAX_AGE = 14 * 24 * 3600    -- anything older is dropped (the site would ignore it)
Pending.MAX_ITEMS = 100
Pending.MAX_NOTE = 200
Pending.KINDS = { plan = true, answer = true, ask = true, ping = true, askAnswer = true }

--[[ Item shapes (also the saved file's, read by the site; sample in tests/fixtures/pending.lua):
  plan   { id, kind = "plan", at, dungeon, startsAt, guid, name, role, note }      -- you lead as guid/name
  answer { id, kind = "answer", at, run, answer = "in"|"maybe"|"cant", guid, name, role }
  ask    { id, kind = "ask", at, dungeon, guid, name, role, note }                 -- "Also post on Discord"
         CF-51: a friend's ask carried for the site keeps the asker's id, at, guid, name, role and adds battleTag
  ping   { id, kind = "ping", at, run, battleTag, guid, name }                     -- CF-48: who to ping
  askAnswer { id, kind = "askAnswer", at, ask, answer = "in"|"maybe"|"cant", guid, name, role } -- CF-51
at and startsAt: UTC seconds. guid/name: the character; role: tank | heal | dps. ]]

-- A unique id: the account ID (CF-28), the time and a counter ("k3f9c0a7e21b-1793120000-1").
function Pending.newId(accountId, now, counter)
  return string.format("%s-%d-%d", tostring(accountId or "x"), now, counter)
end

-- Adds an item. A newer answer for the same run (CF-51: or ask) replaces the older one; an id already there
-- (CF-51: a friend's ask carried twice) is kept as it is. Returns the item.
function Pending.add(list, item)
  for _, existing in ipairs(list) do
    if existing.id == item.id then return existing end
  end
  if item.kind == "askAnswer" then
    for i = #list, 1, -1 do
      if list[i].kind == "askAnswer" and list[i].ask == item.ask then table.remove(list, i) end
    end
  end
  if item.kind == "answer" then
    for i = #list, 1, -1 do
      if list[i].kind == "answer" and list[i].run == item.run then table.remove(list, i) end
    end
  end
  list[#list + 1] = item
  while #list > Pending.MAX_ITEMS do table.remove(list, 1) end
  return item
end

-- Drops asks older than ASK_EXPIRE (no longer worth posting), anything older than MAX_AGE and broken
-- items. Run before the game saves, so an expired ask never reaches the site.
function Pending.prune(list, now)
  for i = #list, 1, -1 do
    local item = list[i]
    local broken = type(item) ~= "table" or not Pending.KINDS[item.kind] or type(item.at) ~= "number"
    local short = item and (item.kind == "ask" or item.kind == "askAnswer") -- CF-51: an answer lives as its ask
    if broken or now - item.at > Pending.MAX_AGE or (short and now - item.at > Pending.ASK_EXPIRE) then
      table.remove(list, i)
    end
  end
end

-- Removes the items the site confirmed (received: ids). Returns how many.
function Pending.confirm(list, received)
  local seen = {}
  for _, id in ipairs(received or {}) do seen[id] = true end
  local removed = 0
  for i = #list, 1, -1 do
    if type(list[i]) == "table" and seen[list[i].id] then
      table.remove(list, i)
      removed = removed + 1
    end
  end
  return removed
end

-- Your pending answer to a run, or nil.
function Pending.answerFor(list, runId)
  for i = #list, 1, -1 do
    if list[i].kind == "answer" and list[i].run == runId then return list[i] end
  end
  return nil
end

-- Pending items of one kind, oldest first.
function Pending.ofKind(list, kind)
  local out = {}
  for _, item in ipairs(list or {}) do
    if item.kind == kind then out[#out + 1] = item end
  end
  return out
end

-- A note as typed: no escape sequences or line breaks, at most MAX_NOTE characters; nil when empty.
function Pending.note(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("|", ""):gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  if text == "" then return nil end
  local chars = {}
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if #chars == Pending.MAX_NOTE then break end
    chars[#chars + 1] = char
  end
  return table.concat(chars)
end

ns.Pending = Pending
return Pending
