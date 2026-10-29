-- Loot: rare and epic items, the watch list of notable items, and gold (CF-53). Pure Lua, no WoW globals.
-- The events go into the feed through Feed.add ("rare", "epic", "notable", "gold"). Requires ns.GameText.
local _, ns = ...

local Loot = {}

Loot.RARE, Loot.EPIC = 3, 4 -- item quality (Enum.ItemQuality): blue, purple; epic counts legendary too

--[[ Items whose loot or creation is notable for the profession feats (docs/DOOMSDAY.md "Feats"). Changing
it needs an addon release. IDs checked on Wowhead Classic (2026-10-28) and in game at launch (VERIFY.md V83).
how: "created" (made with a profession) or "looted" (looted or a quest reward). ]]
Loot.WATCH = {
  [12784] = "created", -- Arcanite Reaper
  [12360] = "created", -- Arcanite Bar (the first Arcanite transmute)
  [14342] = "created", -- Mooncloth
  [15063] = "created", -- Devilsaur Gauntlets
  [15062] = "created", -- Devilsaur Leggings
  [19807] = "looted",  -- Speckled Tastyfish: joined the Stranglethorn Fishing Extravaganza
  [19970] = "looted",  -- Arcanite Fishing Pole: won the Extravaganza
  [19979] = "looted",  -- Hook of the Master Angler: won the Extravaganza
}

-- Link colours by quality, for when the game has not cached the item's quality yet. Newer clients (Retail 12.1.5)
-- write the quality into the link instead: "|cnIQ4:" (API-FINDINGS "Retail 12.1.5 dry run"; Forever: V83).
local COLORS = { ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }

-- The keys of `formats` (the game's own strings) and where each one says the item came from.
local SOURCES = {
  { key = "looted", source = "looted" }, { key = "lootedMultiple", source = "looted" },
  { key = "pushed", source = "looted" }, { key = "pushedMultiple", source = "looted" },
  { key = "created", source = "created" }, { key = "createdMultiple", source = "created" },
}

--[[ An own loot message (CHAT_MSG_LOOT) as { source = "looted"|"created", id, name, count, color, linkQuality } or
nil. color: the link's |cffRRGGBB colour; linkQuality: the quality of a |cnIQ<n>: link (each nil when absent).
formats = { looted = LOOT_ITEM_SELF, lootedMultiple = LOOT_ITEM_SELF_MULTIPLE, pushed = LOOT_ITEM_PUSHED_SELF
(quest rewards), pushedMultiple, created = LOOT_ITEM_CREATED_SELF, createdMultiple }. Other players' loot
uses other strings and does not match. The multiple forms are tried first ("%sx%d." also fits "%s."). ]]
function Loot.parse(message, formats)
  if type(message) ~= "string" or type(formats) ~= "table" then return nil end
  for pass = 1, 2 do
    for _, s in ipairs(SOURCES) do
      local multiple = s.key:match("Multiple$") ~= nil
      if multiple == (pass == 1) then
        local args = ns.GameText.parse(message, formats[s.key])
        local id, name
        if args then id, name = ns.GameText.item(args[1]) end
        if id then
          local color = args[1]:match("|cff(%x%x%x%x%x%x)")
          local linkQuality = tonumber(args[1]:match("|cnIQ(%d+):"))
          return { source = s.source, id = id, name = name, count = tonumber(args[2]) or 1,
                   color = color and color:lower(), linkQuality = linkQuality }
        end
      end
    end
  end
  return nil
end

--[[ Feed events (Feed.add) for a parsed loot message. quality: the game's item quality (nil: from the link's
colour or its |cnIQ quality, for items not cached yet); slot: the INVTYPE_* token (nil or "" for items you can't equip); level: the character's level.
Rare and epic count only looted items and quest rewards; the watch list follows Loot.WATCH. ]]
function Loot.events(item, quality, slot, level)
  local events = {}
  if type(item) ~= "table" or not item.id then return events end
  quality = type(quality) == "number" and quality or COLORS[item.color or ""] or item.linkQuality
  if item.source == "looted" and quality == Loot.RARE then
    events[#events + 1] = { kind = "rare", count = item.count }
  elseif item.source == "looted" and quality and quality >= Loot.EPIC then
    events[#events + 1] = { kind = "epic", id = item.id, name = item.name,
                            slot = type(slot) == "string" and slot:match("^INVTYPE_") and slot or nil, level = level }
  end
  if Loot.WATCH[item.id] == item.source then
    events[#events + 1] = { kind = "notable", id = item.id, count = item.count }
  end
  return events
end

-- The feed event for a change of money (copper): { kind = "gold", gained, spent }, or nil when either is
-- unknown or nothing changed.
function Loot.gold(before, after)
  if type(before) ~= "number" or type(after) ~= "number" or before == after then return nil end
  return { kind = "gold", gained = math.max(0, after - before), spent = math.max(0, before - after) }
end

ns.Loot = Loot
return Loot
