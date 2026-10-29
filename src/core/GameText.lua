-- GameText: reading the game's own messages through its format strings (LOOT_ITEM_SELF, DUEL_WINNER_KNOCKOUT,
-- ...), so nothing depends on English text. Pure Lua, no WoW globals (the strings come in as arguments).
local _, ns = ...

local GameText = {}

-- Lua pattern of a game format string ("%1$s has defeated %2$s in a duel") and, per capture, the number
-- of the argument it holds. Plain "%s" and "%d" count in order. nil when the string has no arguments.
function GameText.pattern(format)
  if type(format) ~= "string" then return nil end
  local order, plain, pattern = {}, 0, ""
  local i = 1
  while i <= #format do
    local index, kind, after = format:match("^%%(%d)%$([sd])()", i)
    if not index then
      kind, after = format:match("^%%([sd])()", i)
    end
    if not kind and format:sub(i, i + 1) == "%%" then
      pattern = pattern .. "%%"
      i = i + 2
    elseif kind then
      if index then
        index = tonumber(index)
      else
        plain = plain + 1
        index = plain
      end
      order[#order + 1] = index
      pattern = pattern .. (kind == "d" and "(%d+)" or "(.+)")
      i = after
    else
      local char = format:sub(i, i)
      pattern = pattern .. (char:match("%W") and ("%" .. char) or char)
      i = i + 1
    end
  end
  if #order == 0 then return nil end
  return "^" .. pattern .. "$", order
end

-- The arguments of a message formatted with `format`, by argument number, or nil when it does not match.
function GameText.parse(message, format)
  local pattern, order = GameText.pattern(format)
  if not pattern or type(message) ~= "string" then return nil end
  local captures = { message:match(pattern) }
  if #captures == 0 then return nil end
  local args = {}
  for i, index in ipairs(order) do args[index] = captures[i] end
  return args
end

-- The item ID and name of the first item link in a text ("|Hitem:12784:...|h[Arcanite Reaper]|h"), or nil.
function GameText.item(text)
  if type(text) ~= "string" then return nil end
  local id, name = text:match("|Hitem:(%d+)[^|]*|h%[(.-)%]|h")
  if not id then return nil end
  return tonumber(id), name
end

ns.GameText = GameText
return GameText
