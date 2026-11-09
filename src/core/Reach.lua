-- Reach (CF-112): who may get an addon whisper, so the game never answers "No player named '...' is currently
-- playing." for one of ours. Pure Lua, no WoW globals: names, presence and times are passed in.
--   * The freshest source decides whether a character is online: Battle.net (the friend is on this character, or on
--     another one), else whichever came later of the community presence and the last message heard from them.
--   * A failed whisper (the game's "No player named" line) blocks that name until it shows online again: something
--     heard from it, or its community presence going offline and then online. A presence that was online all along
--     is what made the whisper fail, so it does not lift the block.
-- Names are compared without case and without a "-Realm" suffix (the game may report either form); never split
-- further (CLAUDE.md rule 4: the GUID is the key, names are only matched).
local _, ns = ...

local Reach = {}

Reach.FAILED_WINDOW = 30 -- seconds after our whisper in which a "No player named" line counts as its answer
Reach.HEARD_FRESH = 120  -- something heard from a character this recently counts as online (unless newer news)

-- The game's English line, when its global (ERR_CHAT_PLAYER_NOT_FOUND_S) is missing.
Reach.NOT_FOUND_TEXT = "No player named '%s' is currently playing."

-- A name without "-Realm", lower case: the form names are compared in. nil for anything but a non-empty string.
function Reach.key(name)
  if type(name) ~= "string" or name == "" then return nil end
  local short = name:match("^(.-)%-[^%-]+$") or name
  if short == "" then return nil end
  return short:lower()
end

function Reach.sameName(a, b)
  local ka = Reach.key(a)
  return ka ~= nil and ka == Reach.key(b)
end

-- A Lua pattern from a format string with one %s: magic characters escaped, %s captures the name.
local function toPattern(format)
  local escaped = format:gsub("%%s", "\1"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  return "^" .. escaped:gsub("\1", "(.+)") .. "$"
end

--[[ The name in a "No player named '...' is currently playing." line, or nil when the line is another one.
format: the game's format string (ERR_CHAT_PLAYER_NOT_FOUND_S), nil for the English default. Also matches the
English text with double quotes, none, or without the final period, in case Forever's line differs a little. ]]
function Reach.notFoundName(format, message)
  if type(message) ~= "string" or message == "" then return nil end
  if type(format) == "string" and format:find("%s", 1, true) then
    local name = message:match(toPattern(format))
    if name then return name end
  end
  local name = message:match("^No player named%s+(.-)%s+is currently playing%.?$")
  if not name then return nil end
  name = name:gsub("^[\"']+", ""):gsub("[\"']+$", "")
  return name ~= "" and name or nil
end

--[[ The name we whispered that a "No player named" line answers: among `whispered` ({ [name] = time of our last
whisper }) the one with the same name (Reach.sameName) whispered within FAILED_WINDOW, the latest if several. nil
when the line names someone we did not whisper lately (a whisper the player typed: shown as usual). ]]
function Reach.matchFailure(whispered, reported, now)
  if type(whispered) ~= "table" or type(now) ~= "number" or not Reach.key(reported) then return nil end
  local best, bestAt
  for name, at in pairs(whispered) do
    if type(at) == "number" and now - at <= Reach.FAILED_WINDOW and Reach.sameName(name, reported)
       and (not bestAt or at > bestAt) then
      best, bestAt = name, at
    end
  end
  return best
end

-- Drops entries of `whispered` older than FAILED_WINDOW (keeps the table small).
function Reach.prune(whispered, now)
  for name, at in pairs(whispered) do
    if type(at) ~= "number" or now - at > Reach.FAILED_WINDOW then whispered[name] = nil end
  end
end

--[[ Whom to whisper, in order: the names (already in the caller's order) online first, then those no source knows;
those offline or blocked after a failed whisper are left out. statusOf(name) -> a status of reach:status. ]]
function Reach.order(names, statusOf)
  local online, unknown = {}, {}
  for _, name in ipairs(type(names) == "table" and names or {}) do
    local status = statusOf(name)
    if status == "online" then
      online[#online + 1] = name
    elseif status == "unknown" then
      unknown[#unknown + 1] = name
    end
  end
  for _, name in ipairs(unknown) do online[#online + 1] = name end
  return online
end

--[[ local reach = Reach.new()
  reach:failed(name, now)                  the game said "No player named" for our whisper to name
  reach:heard(name, now)                   a message from name (whisper, channel): online now, lifts a block
  reach:presence(name, online, now)        the community presence of name (true in game, false not); an offline ->
                                           online change lifts a block
  reach:status(name, battleNet, now)       "failed" | "online" | "offline" | "unknown"
      battleNet: true when a Battle.net friend is on this character now, false when that friend is in Forever on
      another character, nil when Battle.net can't tell (not a friend, appears offline, unknown)
  reach:mayWhisper(name, battleNet, now, allowUnknown) -> bool, status
  reach:blocked() -> { [key] = failedAt }  the names blocked now (debug)
]]
function Reach.new()
  local reach = { entries = {} }

  local function entry(self, name, create)
    local key = Reach.key(name)
    if not key then return nil end
    local e = self.entries[key]
    if not e and create then
      e = {}
      self.entries[key] = e
    end
    return e
  end

  function reach.failed(self, name, now)
    local e = entry(self, name, true)
    if not e then return end
    e.failedAt = now
    e.sawOffline = false
  end

  function reach.heard(self, name, now)
    local e = entry(self, name, true)
    if not e then return end
    e.heardAt = now
    e.failedAt = nil
  end

  function reach.presence(self, name, online, now)
    local e = entry(self, name, online ~= nil)
    if not e or online == nil then return end
    online = online == true
    if e.online ~= online then
      e.online, e.presenceAt = online, now
    end
    if not online then
      e.sawOffline = true
    elseif e.sawOffline then
      e.sawOffline = false
      if e.failedAt then e.failedAt = nil end
    end
  end

  function reach.status(self, name, battleNet, now)
    if not Reach.key(name) then return "unknown" end
    local e = entry(self, name, false) or {}
    if e.failedAt then return "failed" end
    if battleNet ~= nil then return battleNet and "online" or "offline" end
    local heardFresh = e.heardAt and now - e.heardAt <= Reach.HEARD_FRESH
    if e.online == false then
      -- Offline by presence, unless we heard from them after that change.
      if heardFresh and e.heardAt > (e.presenceAt or 0) then return "online" end
      return "offline"
    end
    if e.online == true or heardFresh then return "online" end
    return "unknown"
  end

  function reach.mayWhisper(self, name, battleNet, now, allowUnknown)
    local status = self:status(name, battleNet, now)
    return status == "online" or (allowUnknown == true and status == "unknown"), status
  end

  function reach.blocked(self)
    local result = {}
    for key, e in pairs(self.entries) do
      if e.failedAt then result[key] = e.failedAt end
    end
    return result
  end

  return reach
end

ns.Reach = Reach
return Reach
