-- Checklist: the launch checklist's items (CF-60), pure data. One entry per open API question of VERIFY.md
-- (tests/spec/ProbeChecklist_spec.lua fails when they drift apart) and the story steps worth a tick.
-- id: the VERIFY.md number or a story; session: the play session (1 to 6); title: what to check;
-- auto: the probe ticks it itself; friend: needs a second person; how: what to do for a manual item;
-- retail: Retail (the same Mainline API and Midnight restrictions) can answer it too, for a dry run before launch;
-- note: what is known already (shown under the item while it is open);
-- done: answered elsewhere, no recheck needed (CF-61, Nico 2026-10-29: what he checked on Retail 12.1.5 counts). Shown
-- ticked in a Done list at the bottom, out of the sessions.
-- Results are kept per client, so a Retail answer never closes a Forever item by itself.
local _, ns = ...

ns.sessions = {
  "First login alone",
  "With a friend",
  "Questing",
  "A dungeon",
  "World PvP",
  "Later in the week",
}

ns.items = {
  -- 1. First login alone
  { id = "V78", done = "retail 12.1.5", retail = true, session = 1, auto = true,
    title = "Realm clock and its offset from UTC (GetGameTime)" },
  { id = "V77", done = "retail 12.1.5", retail = true, session = 1, auto = true, title = "Region (GetCurrentRegion)" },
  { id = "V63", done = "retail 12.1.5", retail = true, session = 1, auto = true,
    title = "date() gives your clock time" },
  { id = "V71", done = "retail 12.1.5", retail = true, session = 1, auto = true,
    title = "time() turns a date into server seconds" },
  { id = "V55", done = "retail 12.1.5", retail = true, session = 1, auto = true,
    title = "Minimap tooltip: names left, characters right" },
  { id = "V68", done = "retail 12.1.5", retail = true, session = 1, auto = true,
    title = "A button click may reload the UI",
    how = "Press Test: reload and click a button; the probe ticks it after the reload." },
  { id = "V61", done = "retail 12.1.5", retail = true, session = 1, title = "The CommunitiesForever window draws right",
    how = "/cf: the new look (fonts, gold glow, round class icons), no green squares." },
  { id = "V62", retail = true, session = 1, title = "Friends tab: search, mouse-wheel scrolling, fold arrow",
    how = "Type in the search box, scroll the list and the card, fold a person." },
  { id = "V64", retail = true, session = 1, title = "Ambient effects: the title shimmer and the LEVEL UP shine",
    how = "A light streak moves across the window title every few seconds." },
  { id = "V65", retail = true, session = 1, title = "The colour picker for the community chat colour",
    how = "/cf settings, click the colour square, pick a colour, Cancel puts the old one back." },
  { id = "V66", retail = true, session = 1, title = "Esc > Options > AddOns has the CommunitiesForever page",
    how = "The page shows a line and an Open settings button that opens the settings." },
  { id = "V54", done = "retail 12.1.5", retail = true, session = 1,
    title = "Esc closes the window; the key binding shows",
    how = "Open /cf, press Esc: the window closes, the game menu doesn't. The binding is in Keybindings." },
  { id = "V67", retail = true, session = 1, title = "A changed addon file is re-read on /reload",
    how = "Manual: VERIFY.md V67 (you add ReloadProbeLate.lua and its TOC line), then Test: file reload." },
  { id = "Doomsday tab", session = 1, title = "The Doomsday tab: Today and Week look right",
    how = "/cf, Doomsday: compare with VERIFY.md CF-57a." },

  -- 2. With a friend
  { id = "V50b", done = "retail 12.1.5", session = 2, auto = true,
    title = "A burst of 30 addon whispers arrives (to yourself)" },
  { id = "V47", retail = true, session = 2, auto = true, title = "A click on an addon chat link reaches the addon",
    how = "Press Test: links and invites, click the test link in chat." },
  { id = "V80", done = "retail 12.1.5", session = 2, auto = true, friend = true,
    title = "Duel lines parse (DUEL_WINNER_*)",
    how = "Duel a friend: win one, lose one." },
  { id = "V85", retail = true, session = 2, auto = true, friend = true, title = "A completed trade and its partner",
    how = "Trade any item to a friend." },
  { id = "V59", session = 2, friend = true, title = "The hidden sync channel works",
    how = "A community member who isn't your Battle.net friend sees your level-up within seconds." },
  { id = "V52", session = 2, friend = true, title = "Community presence after a logout",
    how = "A member logs out; after a few minutes, are they still shown online?" },
  { id = "V53", session = 2, friend = true, title = "No 'No player named...' line after a friend logs out",
    how = "Right after a friend logs out, /cf sync: no such line in chat." },
  { id = "V48", retail = true, session = 2, friend = true, title = "Getting a friend into your party from a click",
    how = "Test: links and invites, click each invite link once (leave the group between tries)." },
  { id = "V69", retail = true, session = 2, friend = true, title = "One click invites several friends",
    how = "Two friends online, you not grouped: Test: invite all." },
  { id = "V72", retail = true, session = 2, friend = true, title = "Whisper on the start panel fills the chat input",
    how = "Start panel of a run, Whisper on a friend on another character." },
  { id = "V8", session = 2, friend = true, title = "The community's clubId is the same on two clients",
    how = "Both send the saved file: the probe logs the IDs (V8 COMMUNITIES)." },
  { id = "Board", session = 2, friend = true, title = "Doomsday Board and Ladder show the friend",
    how = "/cf, Doomsday, Board and Ladder: compare with VERIFY.md CF-57b." },

  -- 3. Questing
  { id = "V83", done = "retail 12.1.5", retail = true, session = 3, auto = true,
    title = "Loot, quest rewards and crafted items parse" },
  { id = "V86", done = "retail 12.1.5", retail = true, session = 3, auto = true,
    title = "Discovering a place parses (ERR_ZONE_EXPLORED)" },
  { id = "Dailies", session = 3, title = "A daily ticks off as you play",
    how = "Finish a daily (e.g. 10 quests): it shows done with the time (VERIFY.md CF-56)." },
  { id = "Feats", session = 3, title = "Feats list your characters",
    how = "/cf, Doomsday, Feats: a level-up adds a feat with today's date." },

  -- 4. A dungeon
  { id = "V70", retail = true, session = 4, auto = true, title = "Messaging lockdown during a boss fight" },
  { id = "Run log", session = 4, title = "The run shows in Activity",
    how = "Finish a dungeon with a boss: Activity shows 'ran <dungeon>'." },
  { id = "Boss counts", session = 4, title = "Boss counts of the dungeons with wings",
    how = "/cf activity in a full run: note the bosses for SM, BRS, DM, Strat, Scholo, BFD, ST." },

  -- 5. World PvP
  { id = "V73", session = 5, auto = true, title = "Honor message: victim and rank" },
  { id = "V74", session = 5, auto = true, title = "Enemy players: level, class, race readable" },
  { id = "V75", session = 5, auto = true, title = "The combat log can be registered",
    how = "Press Test the combat log (Blizzard may show a warning: then answer No).",
    note = "Retail 12.1.5: blocked for addons (Blizzard's popup). Forever is still open." },
  { id = "V76", session = 5, auto = true, title = "Group and instance at a kill" },
  { id = "V79", session = 5, auto = true, title = "PvP counters, rank and deaths" },
  { id = "V81", done = "retail 12.1.5", retail = true, session = 5, auto = true,
    title = "Where a death's cause comes from" },

  -- 6. Later in the week
  { id = "V84", retail = true, session = 6, auto = true, title = "Fishing loot (IsFishingLoot)" },
  { id = "V82", done = "retail 12.1.5", session = 6, auto = true, title = "The riding skill is readable" },
  { id = "V35b", session = 6, auto = true, title = "How a battleground ended (PVP_MATCH_COMPLETE)" },
  { id = "V51", session = 6, auto = true, friend = true, title = "Addon whispers reach the other faction",
    how = "Both run the probe: /fp whisper <their character>; their probe ticks it." },
}

return ns.items
