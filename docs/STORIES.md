# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (after V60, at launch).

## E12 Crafting

### CF-38 Recipes: what everyone can craft
- Goal: see exactly what a person can craft, and find who can make something ("who can make Bolt of Silk Cloth?"), also while they are offline.
- **B, our own recipe list (the story):**
  - Reading: when you open a profession window, the addon reads that profession's learned recipes (`C_TradeSkillUI.GetAllRecipeIDs` + `GetRecipeInfo(id).learned`, V60) and stores them on the character: `char.recipes = { [skillLineID] = { [recipeID] = itemID or 0 } }` (0: no item, e.g. an enchant), with when it was read. Only your own characters; a profession's recipes are known once its owner opened its window once, and updated on every open and on `NEW_RECIPE_LEARNED`.
  - Sharing: part of the character in the record, like professions (rule 8: a new optional character field; older clients ignore it, code handles characters without it). Not shared when the character has none.
  - Showing: on a character's card, each profession gets "Recipes (N)"; clicking it lists the recipes by name, each as the real item link (hover: tooltip, shift-click: into chat), "Read <time> ago". Names come from the item (the client's item cache, loaded on demand) or the recipe name for recipes without an item. Without data: "Recipes not read yet: <name> has to open <profession> once."
  - Finding: the smart filter (CF-36) also matches recipe and item names: `bolt of silk` shows the characters that can make it, the card opens on that recipe.
- **A, Blizzard's own view (extra, only if V60 says it works):** if `C_TradeSkillUI.GetTradeSkillListLink()` gives a link while the window is open and clicking that link opens Blizzard's profession window for someone else, also when they are offline: store the link with the recipes and show a button "Open in Blizzard's window" on the card.
- Decided after V60: which calls give recipe IDs, learned state and the item (`GetRecipeItemLink` / `GetRecipeOutputItemData` / `GetRecipeSchematic`), how big a full profession is on the wire (compressed), and whether A works.
- Unit tests (pure core): reading a recipe list into the stored shape; merge (a newer character copy brings its recipes; an older one never removes them); filter matches recipe names; sizes stay below a limit per profession.
- Manual (2 clients): open Tailoring on one; on the other, the card shows "Recipes (N)" with item links and tooltips; `bolt` in the search finds the crafter; after learning a recipe it shows up; with A: "Open in Blizzard's window" opens their recipes, also when they are offline.
