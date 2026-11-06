# Recipes: addon scan, item database, site pages and DoomBot (design handoff, 2026-11-06)

Design: Claude Design canvas "Doombringers v2", section "Recipes · site, addon & DoomBot", boards RC01–RC08 (in the
folders next to this file). Each board lists its visible strings beside it; use those exactly. Recipe names, numbers
and sources on the boards are example data.

| Board | What |
|---|---|
| RC01 | Character page: the Professions box gets a recipe line |
| RC02 | The EXISTING Professions page: live search + a recipe line per crafting card |
| RC03 | New profession page `/professions/<slug>` with its recipe drawer |
| RC04 | Item tooltip and drawer at real size |
| RC05 | Phone |
| RC06 | States: Nobody has, one character, no results, not scanned, loading |
| RC07 | Addon: profession links |
| RC08 | DoomBot: rare-find posts and `/craft` |

Order: Part A (addon), Part B (data import), Part C (site), Part D (DoomBot). Each part ships on its own.

## Decisions (fixed)
- Every character counts, alts included.
- Addon: profession links only (no recipe list, no search in the addon). Site: recipe line on the character page,
  live search on the existing Professions page, a new page per profession. DoomBot: rare-find posts and `/craft`.
- The Professions page keeps its design (summary, By profession cards with crafter bars and badges, By character
  table). Only the search and one line per crafting card change.
- Crafting professions, Cooking and First Aid get recipes. Mining, Herbalism, Skinning, Fishing: skill bar only
  (Smelting counts as Mining recipes if it shows up as recipes in the scan).
- Item data comes from our own item database, built by an import script run once per game patch. Never scrape Wowhead.
- Freshness: show "as of <date>" only when a profession's last scan is older than 7 days.
- "Nobody has" = no character in the group knows the recipe. The import leaves out removed/unobtainable recipes.
- "Rare find" (feed) = a recipe learned from a world drop, boss drop or reputation vendor. Trainer, vendor and quest
  recipes never post.
- Gold: never show a gold amount anywhere (no sell prices).
- Copy: only short player copy in the UI; longer text in a tooltip or nowhere. No BattleTags.

## Amendments by Nico and the orchestrator (2026-11-06, these win over the text below)
1. `C_TradeSkillUI.GetAllRecipeIDs()` returns the recipes of EVERY profession at once (verified on Forever: a
   Tailoring recipe came back while Cooking was open; 471 IDs either way). So the addon cannot tell per recipe which
   profession it belongs to unless `C_TradeSkillUI.GetTradeSkillLineForRecipe` works (being checked by the launch
   probe as V60c, CF-101; unverified, guard it). The addon therefore stores the learned recipe set PER CHARACTER
   (complete on each scan, since every profession comes back), and per profession only skill, max, specialisation,
   link, link type and scannedAt. The site maps each recipe to its profession from the item database; where
   GetTradeSkillLineForRecipe works the addon may add the skill line per recipe.
2. Nico decided: the addon also uploads each learned recipe's crafted item ID (`GetRecipeOutputItemData(id).itemID`,
   verified; 0 for none), two numbers per recipe. Forever adds recipes and items with new IDs (e.g. recipe 1229504
   makes item 279972; spells above 1,000,000) that Classic Era data does not have. The site uses these pairs to fill
   gaps and must show Forever-only items gracefully (no name/tooltip until a data source has them).
3. Data source for Part B: check first whether wago.tools offers a Forever build (product name unknown; the client is
   WOW_PROJECT_ID 18, build 70790, Interface 16001). Prefer it over Classic Era when it exists; say which you used.
4. Icon CDN: prefer Blizzard's own render CDN for icons by name if it serves 56 px icons (e.g.
   `render.worldofwarcraft.com/<region>/icons/56/<icon>.jpg`, verify), not a Wowhead host.
5. Never commit real BattleTags, names of real people, or private data. "Ves Doombringer" and "Doombringers" already
   appear in committed designs and may stay.

## Verified on Forever (launch probe, docs/API-FINDINGS.md "Forever launch probe" in the addon repo)
- Unlearned recipes are in the list (471 returned, 6 learned).
- A clicked profession link opens Blizzard's own window with that person's recipes while the owner is ONLINE.
  Offline is untested.
- Link type (short live pointer vs long link with recipes inside) is recorded by V60c; either way, save the link
  again on every scan.

---

## Part A · Addon (CommunitiesForever)

### A1. Scanning
- Scan on `TRADE_SKILL_SHOW`, list updates, `NEW_RECIPE_LEARNED`, `SKILL_LINES_CHANGED`. Debounce to at most one
  scan per second.
- Store per character and per profession (skill line): skill line id, current skill, max skill, specialisation if the
  API exposes it, the profession link from `C_TradeSkillUI.GetTradeSkillListLink()` plus the link type, `scannedAt`.
  Learned recipe ids: see amendment 1 and 2.
- Only the open profession's skill/link counts. Never wipe another profession's data because a scan didn't include it.
- Gathering professions and Fishing: skill only, as today.
- Upload: into the SavedVariables the uploader already sends. Small: recipe ids as numbers, no names, no reagents.

### A2. Friends tab: profession rows (RC07)
- Each crafting profession row: name, skill bar, skill, then the link text `[Tailoring]` in Blizzard's link colour.
- Click: `SetItemRef` with the stored link → Blizzard's own profession window with that friend's recipes.
- Shift-click: `ChatEdit_InsertLink` → the link in the open chat box; the player sends it.
- Hover tooltip, online: "Mira's Tailoring" / "Click: open in game" / "Shift-click: link in chat".
- Offline, only if the offline test shows links fail: show the link dimmed, tooltip "Opens while Mira is online".
  If offline links work, both states look like the online one.
- No scan yet: "not scanned", tooltip "Opens once Mira opens Cooking in game".
- Gathering professions and Fishing: no link.

### A3. Done when
- [ ] Opening a profession window stores its learned recipe ids, skill, link and scannedAt for that character, without
      touching other professions.
- [ ] Learning a recipe updates the stored data without a /reload.
- [ ] A friend's link opens Blizzard's window when clicked; Shift-click puts it in the chat box.
- [ ] The offline link test is run; the dimmed offline state is built only if needed.

## Part B · Item database and import (site backend)
A script (`scripts/import-items` or similar), run by hand once per patch; idempotent; writes to our database.

### B1. Sources
1. wago.tools DB2 CSV exports (see amendment 3) — Blizzard's own client data. Check exact table/column names:
   - `ItemSparse`: name, quality, item level, required level, bind type, stats, armor, durability, Equip/Use spell text
   - `Item`: class, subclass, inventory type, icon file id
   - `SkillLineAbility`: recipe spell → skill line, plus the four thresholds: orange = `MinSkillLineRank`,
     yellow = `TrivialSkillLineRankLow`, grey = `TrivialSkillLineRankHigh`, green = (yellow + grey) / 2
   - `SpellReagents` (or the Classic equivalent): reagents and counts
   - `SpellEffect`: the item a recipe creates
2. cmangos classic-db or VMaNGOS (GPL-3.0) for where each recipe is learned; one or more sources per recipe:
   Trainer (`npc_trainer`); Vendor (`npc_vendor`, limited stock → "Vendor · Limited"); Drop (recipe item in a
   creature loot table: store creature and map, name the dungeon for instances); Rep (faction + rank, e.g.
   "Rep · Thorium Brotherhood · Honored"); Quest (rewards or teaches it).
3. Icon names: map icon file ids to names with the community listfile.

### B2. Tables (adjust to our schema)
- `items`: id, name, quality, the tooltip fields from B1, `icon_name`
- `recipes`: spell id, skill line id, created item id (or null), the four thresholds, category (item type, for grouping)
- `recipe_reagents`: recipe, item, count
- `recipe_sources`: recipe, kind (`trainer`/`vendor`/`vendor_limited`/`drop`/`rep`/`quest`), place, faction, rank,
  `is_rare` (true for drop and rep)
- `character_professions`: character, skill line, skill, max, specialisation, link, link type, `scanned_at`
- `character_recipes`: character, recipe, `first_seen_at`

### B3. Icon cache
- On first request for an icon name, fetch it once from a CDN (amendment 4), store it on our server, serve it
  ourselves from then on. CDN URL in config. One size, 56 px; CSS scales it to 30–48 px. Missing: a neutral
  question-mark icon.

### B4. Upload processing
- Per character, compare the uploaded learned ids with the stored ones: insert new ones with `first_seen_at`, remove
  vanished ones (rare, e.g. after a respec), update skill, link and `scanned_at` per profession.
- The first scan of a profession is the baseline and never counts as "newly learned" (else the first upload would post
  everything).
- Collect new rare finds per character per upload for the feed (Part D).

## Part C · Website (Next.js)
Libraries: Radix UI (HoverCard, Dialog, Tabs, Popover) styled with our own Night over Azeroth styles (not shadcn's);
Floating UI for tooltip placement; TanStack Table + TanStack Virtual for long lists; MiniSearch for typo-tolerant
search; nuqs for filters in the URL.

### C1. Item tooltip (RC04)
- Shared `<ItemTooltip itemId>` on every icon and item name; hover with 150 ms delay; flips at screen edges.
- Order: name in quality colour, bind, slot + type on one line, armor, stats, durability, required level, green
  "Equip:" and "Use:" lines. No sell price.
- Game look: dark blue-black background, 1 px grey-blue border, 13 px text, 300 px wide (240 px for reagents).
- Phone: tapping an icon opens the tooltip in a small sheet with an "Open recipe" button (RC05).

### C2. Character page (RC01)
- Keep the Professions box. Under each crafting profession: "86 recipes ›" → `/professions/<slug>?char=<character>`.
- Stale: "as of 21 Oct" only when that profession's scan is older than 7 days.
- Never scanned: "Recipes not scanned" with an ⓘ tooltip "Open Enchanting in game once.", no link.

### C3. Professions page (RC02), existing design kept
- Replace the dashed "future" search box and its line "Recipe search arrives when…" with the live search, same place:
  results from 2 letters, item and recipe names, typo-tolerant; two groups: "Can craft" (max 6) and "Nobody yet"
  (max 3), best quality first; each result: item icon, name in quality colour, crafters in class colour each with a
  difficulty dot, or where it is learned when nobody knows it; ↑ ↓ move, Enter opens, Esc closes; a click goes to
  `/professions/<slug>?recipe=<id>` with the drawer open; below: "All Tailoring recipes ›".
- Each crafting card (Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid)
  gets one line at the bottom: "**112** of 185 recipes ›" → its profession page.
- Everything else stays exactly as it is.

### C4. Profession page `/professions/<slug>` (RC03)
- Header: "← Professions", name with its card badge (Covered / Thin / Gap), "112 of 185 recipes known", the same
  crafter bars as the card (name, ★ for the best, skill / max).
- Tabs: All / Known / Nobody has, each with its count.
- Filters: search within the profession, character (Everyone ▾), type, skill range; all in the URL:
  `?char=&type=&skill=&tab=&recipe=`.
- Table: grouped by item type, highest skill first; columns: icon, recipe (name in quality colour), skill (four
  threshold numbers in orange/yellow/green/grey), known by (characters in class colour with a dot in the recipe's
  current colour for them), learn from (e.g. "Drop · Blackrock Spire"); virtualised (300 rows smooth).
- Drawer: a row click opens it on the right, non-modal, adds `?recipe=`; Esc or ✕ closes. Order: icon, name,
  "Tailoring · Chest"; the full item tooltip; skill; reagents (icon, name, ×count, each with its tooltip); "Can make
  it" (crafters with difficulty dot, "Tailoring 300 · online"); "Learn from"; "Copy link" (tooltip "Link copied").
- From the character page: the Known tab is preselected and means "this character knows it".

### C5. Phone (RC05)
- Rows on two lines: name; skill numbers + crafters (or the source).
- Row tap: drawer as a sheet; swipe down or ✕ closes; URL as on desktop. Icon tap: tooltip sheet. Filters scroll
  sideways.

### C6. States (RC06)
- Nobody has tab. One character: "as of" only when that character's scan is stale. No results: "No recipe matches
  "…"" + "Clear filters", filters stay visible. Not scanned yet (someone has the profession, never opened it): "No
  recipes scanned yet" with ⓘ, "186 recipes to learn", "See all recipes". Loading: skeleton rows.

### C7. Done when
- [ ] The Professions page looks exactly as before apart from the live search and recipe lines.
- [ ] Every state on RC01–RC06 is built, desktop and phone.
- [ ] Tooltips use our own item data, no sell price; icons from our icon cache.
- [ ] Any filtered view or open drawer can be shared as a link.

## Part D · DoomBot (RC08)
### D1. Rare-find feed
- Trigger: an upload adds recipes whose source `is_rare` (drop or rep).
- One post per upload per character. One find: author line "Mira learned a rare recipe", item name as title, fields
  for the profession with its skill and for "Learned from", item icon as thumbnail. Two or more: "Mira learned 2 rare
  recipes", one line per recipe: name, then "· Drop · …" or "· Rep · …".
- Embed colour bar: the best item's quality colour; text stays white.
- Channel: the one set for feats on the Discord page. Never post on a profession's first scan.
### D2. `/craft <item>`
- Autocomplete on craftable item names.
- Answer: item card with name and "Tailoring 300"; "Can make it": up to 5 crafters each with 🟠🟡🟢⚪, then "+N more";
  "Reagents": e.g. "12 × Bolt of Runecloth · 4 × …"; "Open the recipe ›" → the drawer URL.
- Nobody knows it: "Nobody can make it yet." + "Learn from: …". Unknown item: "No recipe makes that."
- Answers in the channel where it was typed.
### D3. Done when
- [ ] A test upload with a new drop recipe posts once; a trainer recipe doesn't, nor does a first scan.
- [ ] `/craft` covers crafters, nobody, unknown item.

## Out of scope
Cooldown tracking, "craftable now" counts, crafting requests, search inside the addon, gathering-profession recipes.
