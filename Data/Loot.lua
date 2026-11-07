--[[ PLACEHOLDER (CF-106): hand-written until CommunitiesForever-Web's `npm run export:addon-loot` (WEB-96) generates
this file. The generated file replaces it before the release; it then carries the GPL-3.0 notice and the cmangos
classic-db attribution, as docs/ARCHITECTURE.md "Loot data file" says.

This placeholder has The Deadmines, Scarlet Monastery: Graveyard and Stratholme: Undead in the contract's shape, for
building and testing the Dungeons tab only. Boss IDs are made up (90001...: no real DungeonEncounter ID), so no in-game kill matches them;
item IDs and chances are typed from the design board and memory, not checked. Do not ship it. ]]
local _, ns = ...
ns.LootData = {
  build = "placeholder",
  placeholder = true,
  dungeons = {
    dm = {
      { id = 90001, name = "Rhahk'Zor", drops = {
        { item = 5187, chance = 77, cls = 2, sub = 5 },
      } },
      { id = 90002, name = "Sneed", drops = {
        { item = 1156, chance = 31, cls = 4, sub = 0 },
        { item = 5195, chance = 30, cls = 2, sub = 15 },
      } },
      { id = 90003, name = "Gilnid", drops = {
        { item = 1875, chance = 100, cls = 12, sub = 0, quest = 167 },
        { item = 5199, chance = 40, cls = 4, sub = 2 },
      } },
      { id = 90004, name = "Mr. Smite", drops = {
        { item = 5192, chance = 33, cls = 2, sub = 7 },
        { item = 7230, chance = 31, cls = 2, sub = 5 },
        { item = 5196, chance = 29, cls = 2, sub = 0 },
      } },
      { id = 90005, name = "Captain Greenskin", drops = {
        { item = 5201, chance = 30, cls = 2, sub = 10 },
      } },
      { id = 90006, name = "Edwin VanCleef", final = true, drops = {
        { item = 10399, chance = 36, cls = 4, sub = 2 },
        { item = 5193, chance = 29, cls = 4, sub = 1 },
        { item = 5191, chance = 26, cls = 2, sub = 7 },
        { item = 5202, chance = 18, cls = 4, sub = 1 },
        { item = 10400, chance = 15, cls = 4, sub = 2 },
        { item = 10401, chance = 12, cls = 4, sub = 2 },
        { item = 10402, chance = 10, cls = 4, sub = 2 },
        { item = 7997, chance = 4, cls = 4, sub = 1 },
      } },
      { id = 90007, name = "Cookie", optional = true, drops = {
        { item = 5197, chance = 41, cls = 2, sub = 4 },
        { item = 728, chance = 12, cls = 9, sub = 5, recipe = 2795 },
      } },
    },
    stratud = {
      { id = 90021, name = "Nerub'enkan", drops = {
        { item = 18740, chance = 15, cls = 4, sub = 3 },
      } },
      { id = 90022, name = "Baron Rivendare", final = true, drops = {
        { item = 13505, chance = 1, cls = 2, sub = 8 },
        { item = 13335, chance = 1, cls = 15, sub = 5 },
      } },
    },
    smgy = {
      { id = 90011, name = "Interrogator Vishas", drops = {
        { item = 7682, chance = 31, cls = 4, sub = 3 },
      } },
      { id = 90012, name = "Bloodmage Thalnos", final = true, drops = {
        { item = 7684, chance = 33, cls = 4, sub = 1 },
        { item = 7685, chance = 30, cls = 4, sub = 0 },
      } },
    },
  },
}
