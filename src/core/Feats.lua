-- Feats: the feats the addon can derive for the own characters (CF-57b). Pure Lua, no WoW globals. The same kinds,
-- thresholds and titles as the site (web src/core/doomsday/feats.ts, WEB-56), without "First in the group" and
-- without the group's mount count. The addon has only current data and 7 days of feed, so it remembers locally
-- when it first saw each feat (Nico, 2026-10-28): self.feats[guid][key] = { at, title, detail } (at 0 = it was
-- there before, "Earlier"). Requires ns.Pvp (rank names and titles) and ns.Text.
local _, ns = ...

local Feats = {}

Feats.LEVELS = { 10, 20, 30, 40, 50 }   -- every 10 levels below the cap (the site's milestones)
Feats.MAX_LEVEL = 60
Feats.HONOR_KILLS = { 1, 100, 1000, 5000, 10000 }
Feats.DUEL_WINS = { 10, 50, 100 }
Feats.DEATHS = 100
Feats.RIDING_MOUNT, Feats.RIDING_EPIC = 75, 150
Feats.BATTLEGROUNDS = { ["Warsong Gulch"] = true, ["Arathi Basin"] = true, ["Alterac Valley"] = true }

local COOKING, FIRST_AID, FISHING = 185, 129, 356
local CAP_TITLES = { [COOKING] = "Head Chef", [FIRST_AID] = "Field Medic", [FISHING] = "Fish Whisperer" }
local CAPS = { [75] = true, [150] = true, [225] = true, [300] = true }
-- Primary professions by skill line: Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Leatherworking,
-- Mining, Skinning, Tailoring.
local PRIMARY = { [171] = true, [164] = true, [333] = true, [202] = true, [182] = true, [165] = true, [186] = true,
                  [393] = true, [197] = true }

-- The watch-list feats (CF-53 notable items), by item ID: key and texts (the site's NOTABLE_TEXT).
local NOTABLE = {
  [12784] = { key = "arcaniteReaper", title = "Arcanite Reaper", detail = "Crafted at last" },
  [12360] = { key = "arcaniteTransmute", title = "Arcanite Bar", detail = "The first Arcanite transmute" },
  [14342] = { key = "mooncloth", title = "Mooncloth", detail = "The first Mooncloth" },
  [15063] = { key = "devilsaur", title = "Devilsaur leather", detail = "Devilsaur gear crafted" },
  [15062] = { key = "devilsaur", title = "Devilsaur leather", detail = "Devilsaur gear crafted" },
  [19807] = { key = "extravaganzaJoined", title = "Fishing Extravaganza", detail = "Joined the Fishing Extravaganza" },
  [19970] = { key = "extravaganzaWon", title = "Extravaganza winner", detail = "Won the Fishing Extravaganza" },
  [19979] = { key = "extravaganzaWon", title = "Extravaganza winner", detail = "Won the Fishing Extravaganza" },
}

local thousands = ns.Text.thousands

-- "First blood", "1,000 honorable kills", "10,000 kills": an honor-kill step's title.
local function killsTitle(step)
  if step == 1 then return "First blood" end
  return step == 10000 and "10,000 kills" or (thousands(step) .. " honorable kills")
end

local function rank(char, line)
  local p = char.professions and char.professions[line]
  return p and p.rank or 0
end

--[[ The feats a character holds now: { { key, kind, title, detail } } in a stable order. char: the stored Char
(level, professions, pvp, riding, faction); entries: its feed entries of the last days (runs, loot, notable). ]]
function Feats.derive(char, entries)
  local list = {}
  local function add(key, kind, title, detail)
    list[#list + 1] = { key = key, kind = kind, title = title, detail = detail }
  end
  local level = char.level or 0
  for _, l in ipairs(Feats.LEVELS) do
    if level >= l then add("level:" .. l, "level", "Level " .. l, "Reached level " .. l) end
  end
  if level >= Feats.MAX_LEVEL then add("maxLevel", "maxLevel", "Level " .. Feats.MAX_LEVEL, "Reached the level cap") end
  local lines = {}
  for line in pairs(char.professions or {}) do lines[#lines + 1] = line end
  table.sort(lines)
  for _, line in ipairs(lines) do
    local p = char.professions[line]
    if CAPS[p.rank or 0] and p.rank == p.max then
      local name = (p.name or "A profession") .. " " .. p.rank
      if p.rank == 300 and CAP_TITLES[line] then
        add("professionCap:" .. line .. ":" .. p.rank, "professionCap", CAP_TITLES[line], name)
      else
        add("professionCap:" .. line .. ":" .. p.rank, "professionCap", name, "At its cap")
      end
    end
  end
  local pvp = char.pvp or {}
  for _, step in ipairs(Feats.HONOR_KILLS) do
    if (pvp.hk or 0) >= step then
      if step == 1 then
        add("honorKills:1", "honorKills", "First blood", "The first honorable kill")
      else
        add("honorKills:" .. step, "honorKills", killsTitle(step), step == 10000 and "Ten thousand. Honorably." or nil)
      end
    end
  end
  if type(pvp.rank) == "number" and pvp.rank > 0 and ns.Pvp.TITLES[pvp.rank] then
    local official = pvp.rankName or (ns.Pvp.RANK_NAMES[char.faction or ""] or {})[pvp.rank] or ("Rank " .. pvp.rank)
    add("pvpRank:" .. pvp.rank, "pvpRank", official,
      "a.k.a. " .. ns.Pvp.TITLES[pvp.rank] .. " \194\183 rank " .. pvp.rank)
  end
  for _, step in ipairs(Feats.DUEL_WINS) do
    if (pvp.duelsWon or 0) >= step then
      add("duelWins:" .. step, "duelWins", step .. " duel wins", step .. " duels won")
    end
  end
  if (pvp.deaths or 0) >= Feats.DEATHS then
    add("deaths100", "deaths100", "A spirit healer's best friend", "100 deaths")
  end
  local riding = char.riding or 0
  if riding >= Feats.RIDING_MOUNT then add("mount", "mount", "Mount", "at level " .. level) end
  if riding >= Feats.RIDING_EPIC then add("epicMount", "epicMount", "Epic mount", "at level " .. level) end
  if rank(char, FISHING) > 1 then add("firstCatch", "firstCatch", "First catch", "Fishing") end
  local primaries = 0
  for line in pairs(char.professions or {}) do
    if PRIMARY[line] and rank(char, line) >= 300 then primaries = primaries + 1 end
  end
  if primaries >= 2 and rank(char, COOKING) >= 300 and rank(char, FIRST_AID) >= 300 and rank(char, FISHING) >= 300 then
    add("jackOfAllTrades", "jackOfAllTrades", "Jack of all trades", "Cooking, First Aid, Fishing at 300")
  end
  -- From the feed: a battleground's first win, the first epic, watch-list items.
  local seen = {}
  for _, e in ipairs(entries or {}) do
    for _, run in ipairs(e.runs or {}) do
      local key = "bgFirstWin:" .. tostring(run.name)
      if run.kind == "pvp" and run.won == true and Feats.BATTLEGROUNDS[run.name] and not seen[key] then
        seen[key] = true
        add(key, "bgFirstWin", "First win", "First win in " .. run.name)
      end
    end
    local epic = e.loot and e.loot.epic and e.loot.epic[1]
    if epic and not seen.firstEpic then
      seen.firstEpic = true
      add("firstEpic", "firstEpic", epic.name or "An epic item",
        "First epic" .. (epic.level and (" \194\183 looted at level " .. epic.level) or ""))
    end
    local ids = {}
    for id in pairs(e.notable or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local n = NOTABLE[id]
      if n and not seen["notableItem:" .. n.key] then
        seen["notableItem:" .. n.key] = true
        add("notableItem:" .. n.key, "notableItem", n.title, n.detail)
      end
    end
  end
  return list
end

--[[ Remembers the feats a character holds (in place): store = { [key] = { at, title, detail } }. The first time a
character is seen everything it holds is "Earlier" (at = 0); later a new key gets `now`. Feats are never removed (a
PvP rank that drops keeps its feat). Returns the keys new this time (not on the first sight). ]]
function Feats.remember(store, list, now)
  local first = next(store) == nil
  local new = {}
  for _, f in ipairs(list) do
    if not store[f.key] then
      store[f.key] = { at = first and 0 or now, title = f.title, detail = f.detail }
      if not first then new[#new + 1] = f.key end
    end
  end
  if first then store["_seen"] = { at = now } end -- marks the first sight even without any feat
  return new
end

--[[ A character's feats for the tab, newest first, "Earlier" ones last by key: { { key, title, detail, at } }. ]]
function Feats.list(store)
  local list = {}
  for key, f in pairs(store or {}) do
    if key ~= "_seen" then list[#list + 1] = { key = key, title = f.title, detail = f.detail, at = f.at or 0 } end
  end
  table.sort(list, function(a, b)
    if a.at ~= b.at then return a.at > b.at end
    return a.key < b.key
  end)
  return list
end

-- The next honorable-kill feat and how far: "1,000 honorable kills", "412 / 1,000"; nil past the last.
function Feats.nextKills(hk)
  for _, step in ipairs(Feats.HONOR_KILLS) do
    if (hk or 0) < step then
      return killsTitle(step), thousands(hk or 0) .. " / " .. thousands(step)
    end
  end
  return nil
end

ns.Feats = Feats
return Feats
