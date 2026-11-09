# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes, Part A of the Recipes handoff;
   V60 answered at launch).
2. E18, the mission catalogue: CF-70 first, then in parallel lanes (see E18 "Building in parallel"), CF-77 last.

### CF-114 The Hunt's prey: a hint to keep them targeted
CF-110 takes the kill's victim from your target, then mouseover, then an enemy nameplate that died within 5 s of being
seen alive (V73: the honor message doesn't name the victim). A kill on someone you never targeted or hovered counts
without a victim, so the Hunt can't tick. Nico chose (2026-11-09): a prey hint so players target them, and a tip in
the Hunt's text to turn enemy nameplates on. Hints only, nothing is blocked (recommend, not restrict). Touches
`src/core/Doomsday.lua`, `src/core/DoomsdayView.lua`, `src/services/HuntPrey.lua` (new), `src/services/DoomsdayTracker.lua`,
`src/ui/Tooltip.lua`, `src/ui/DoomsdayTab.lua`, their specs, `docs/DOOMSDAY.md`, VERIFY.md.
- While the current character's Hunt (its faction's combination today) is not done, targeting or hovering an enemy
  player of exactly that race and class adds "Your prey: The Hunt" to their unit tooltip, in the PvP track's colour
  (the existing `TooltipDataProcessor` unit post-call, V6).
- The same target or mouseover also prints "Prey in sight: <race> <class>. Keep them targeted for the kill." (no
  names), at most once per player (GUID) per `Doomsday.PREY_CHAT_EVERY` (5 minutes). CF-91 removed chat lines that
  a banner already shows; this one has no other place when you tab-target, and no setting applies.
- Nothing for friendly players, other combinations, a done Hunt, a day without a Hunt, in a battleground or arena
  (kills there score on the bg track, not for the Hunt), or without a community this character is in (Doomsday is
  quiet then, CF-85).
- The rule is pure core with busted tests: `Doomsday.isPrey(hunt, done, unit, instanceType)` and
  `Doomsday.preyChatDue(said, key, now)`. Unit values come from `PvpInfo.enemy` (every value through
  `ns.Safe.call`, a secret one is nil before any comparison, CF-108); the GUID passes `Safe.text`.
- The Hunt's goal tooltip on the Doomsday tab (Today row and Board cell) adds "Target your prey, or turn on enemy
  nameplates, so the kill knows who it was." (`DoomsdayView.HUNT_TIP`), and `docs/DOOMSDAY.md` says it too. The
  site's and bot's Hunt texts live in the web repo: a follow-up there.
- The draw had no Hunt then (`Doomsday.HUNT_SINCE` nil); it joins with pool version 4 (CF-104), so the hint shows from there.
- No change to stored data or messages (rule 8).
- Manual: VERIFY.md CF-114.

### CF-113 Launch probe: the export of 2026-11-09
The export of 2026-11-09 (build 70862). Same rule as CF-105 and CF-109: an answered check leaves the probe and
FriendProbe's checklist gets a `done` marker. Touches `src/core/Probe.lua`, `src/services/LaunchProbe.lua`,
`src/services/LaunchProbeMissions.lua`, `tools/FriendProbe/Checklist.lua`, `tools/FriendProbe/Missions.lua`, the
probe specs, `docs/API-FINDINGS.md`, VERIFY.md.
- V120 passed (2 testers): `C_DeathRecap.GetRecapEvents()` names a player killer (`Player-` GUID, readable name). To
  API-FINDINGS; out of VERIFY.md and `Probe.IDS`, its code removed; FriendProbe's item `done`. It unblocks the
  killer goals of CF-81 (`p.revenge`, `b.revenge3`; `p.avenge`, `b.avenge3` also need a friend's killer, which CF-81
  keeps local): not built here. The addon reads the recap only for a death's cause (`PvpInfo.recapDamage`).
- V101 half answered (1 tester): posting an auction fires `AUCTION_HOUSE_AUCTION_CREATED` (`d.auctionPost` can be
  built). V101 stays open for buying: the probe passes on `AUCTION_HOUSE_PURCHASE_COMPLETED` or `ERR_AUCTION_WON_S`
  (no longer on a post); a pass stored for a post gives way to the first buy's. FriendProbe's item the same.
- V60b: CF-109's fix works, the own link reads `opened Blizzard's view (IsTradeSkillLinked true, N recipes)` (2
  testers). A friend's link while they were online still gave no window for 1 tester, likely another internal server
  (bug 7, CF-107). V60 stays open for an offline friend and a friend on the same server; the answered own-link step
  of VERIFY.md CF-109 is closed.
- Re-confirmed, no change: V73 fails (`You x x x 1 Honor.`, the award without the victim), V70, V87. Still open: V74
  (skull), V100 (inbox take), V108 (emote).
- `Probe.IDS`: 11 checks (V82, V35b, V73, Hunt, V80, V96, V101, V108, V122, V123, V60b).
- Compatibility (rule 8): nothing stored or sent changes shape; the probe stops writing V120 (its stored result stays
  and is uploaded as before) and V101's detail now names a buy.

### CF-110 The PvP kill's victim from your target at the kill
On Forever the kill's honor message is the plain award (`COMBATLOG_HONORAWARD`, V73) and never names the victim, so
the Hunt, `p.punchUp5` / `p.punchDown5`, `p.skull`, `b.skulls3` and the other victim goals (CF-54, CF-55, CF-101)
can't complete. Nico decided (2026-11-08): take the victim from the target or mouseover at the moment of the kill.
Touches `src/core/Pvp.lua`, `src/adapters/PvpInfo.lua`, `src/services/PvpTracker.lua`, `src/core/Probe.lua`,
`src/services/LaunchProbe.lua`, `tools/FriendProbe/Checklist.lua` (V141), their specs, VERIFY.md, `docs/API-FINDINGS.md`, `docs/DOOMSDAY-PVP-CATALOGUE.md`.
- When the lifetime counter rises (`PLAYER_PVP_KILLS_CHANGED`, or an honor message, then `GetPVPLifetimeStats`), the
  victim is picked from the enemy players at that moment: your target first, then your mouseover, then an enemy
  nameplate (`nameplate1` to `nameplate40`). It must be an enemy player, dead now (`UnitIsDead`, unverified: V141)
  and seen alive at most `Pvp.KILL_WINDOW` (5 s) before. The order within a source: the one seen alive last. Players
  are keyed by GUID; the name is stored as the game gives it, never parsed.
- "Seen alive" comes from the target, mouseover and nameplate events and a look once a second
  (`C_Timer.NewTicker`), so a long fight still has a fresh sighting.
- Level, class, race and rank come from the unit at the kill, else from when it was seen alive; a missing one stays
  nil. Several kills in one counter rise take distinct players, best first; no fitting player: the kill counts
  without a victim, as before (no guessing).
- An honor message that names the victim (`COMBATLOG_HONORGAIN` and variants, CF-101) still wins: its kill gets the
  name and the rank from the message, and a picked victim of the same name is not added again.
- Pure rule in core (`Pvp.seeAlive`, `Pvp.pickVictims`) with busted tests: several candidates, none, stale, a
  friendly player, unknown death, a secret value (nil from the adapter) ignored. The adapter (`PvpInfo.look`,
  `PvpInfo.looks`) reads every value through `ns.Safe.call`, so a secret is nil before any comparison (CF-108).
- The launch probe's Hunt also ticks from the victim picked at a counted kill ("Grim Tusk: Orc WARRIOR via target at
  the kill"), with a note whether `UnitIsDead` exists; V73 keeps logging the message's shape.
- Compatibility (rule 8): the `pvpKills` entry keeps its shape (`t, zone, name, lvl, myLvl, class, race, rank, solo,
  bg`); only more entries carry victim fields. An older version sends entries without them for these kills and
  reads ours as before; the site and bot read the same fields. Nothing stored or sent changes, no migration.
- Manual (VERIFY.md CF-110, V141): target an enemy player, kill them; the kill has the victim in the saved data,
  `/cf fp` shows the Hunt and the Doomsday tab's Today box counts the kill by level.

### CF-111 The own character's last location at a zone change and at logout
Bug: logged off in Hillsbrad Foothills, the site still showed an older Westfall. `db.global.locations` was only
written from the community member list (`MemberTracker.refresh`), which runs on member events only; the own zone
change and the logout fire none. Touches `src/core/Members.lua`, `src/services/MemberTracker.lua`,
`tests/spec/Members_spec.lua`, `tests/spec/MemberTracker_spec.lua`, VERIFY.md, CHANGELOG.md.
- `Members.recordOwn(locations, guid, zone, now)` (pure core) writes `locations[guid] = { zone, seenAt = now }`, the
  shape `recordLocations` writes. It keeps the old entry when the GUID or the zone is not a non-empty string, and
  never moves `seenAt` back.
- The zone is `SelfInfo.zone()` (`GetRealZoneText`, verified V35; nil when secret or empty): the zone name, inside an
  instance the instance's name ("Ruins of Lordaeron"), as the member list shows it.
- Recorded 1 s after `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA` (the zone text can be nil right after a
  loading screen), and right away at `PLAYER_LEAVING_WORLD` and `PLAYER_LOGOUT` (handlers run before SavedVariables
  are written, V22). Works without a selected community.
- At `PLAYER_LEAVING_WORLD` and `PLAYER_LOGOUT` the member list's zones are recorded first (locations only: no roster
  update, no message), then the own zone, so the own one wins over a member list that hasn't caught up.
- Everything guarded (`ns.Safe.call`); secret values are nil before any comparison (CF-108).
- Same stored shape, no migration (rule 8): older versions keep writing it from the member list; the site merges
  by the newest `seenAt`.
- Manual (VERIFY.md): change zone, log out, check `global.locations[<GUID>]` and the site after an upload.

### CF-112 No "No player named '...' is currently playing." from our whispers
Bug (Nico, v1.6.1): the line shows twice in chat. It is the game's answer to an addon whisper to a character that is
offline. Whispers go out from Sync (HELLO, REQ, RECORD, RUNS, SCHED, RUNANSWER, KILL, BYE and the MISS of reliable
delivery, all through Messenger) and from CF-84's guild invites (GINVREQ, GINVACK, GINVFAIL). Sync whispered every
member the community list showed online, and that list lags after a logout (V52); peers who left without a BYE
stayed online for KILL, RUNANSWER and BYE; the alt whispers stored guild members it can't see. The CHAT_MSG_SYSTEM
filter meant to hide the line compared it with `ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)` exactly, for 10 s: a
"-Realm" in the line, another case or other quotes, and it never matched, so nothing was hidden and nothing was
marked offline. Touches `src/core/Reach.lua` (new), `src/core/Outbox.lua`, `src/services/ReachTracker.lua` (new),
`src/services/Messenger.lua`, `src/services/Sync.lua`, `src/services/GuildInvites.lua`, `src/adapters/Transport.lua`,
`src/Core.lua`, their specs, VERIFY.md, CHANGELOG.md.
- Pure rule in core (`Reach`): a character is online by the freshest source: Battle.net when it knows (the friend
  is on this character: online; on another character: offline; friends who appear offline count as online), else the
  later of the community presence and the last message heard from it (heard within `Reach.HEARD_FRESH`, 120 s).
- A failed whisper blocks the name until it shows online again: something heard from it, or its community presence
  going offline and then online. A presence that stayed online is what made it fail, so it does not lift the block.
- Messenger whispers a community member only while it is online by that rule: `send` refuses, and parts already
  queued are dropped at send time and when a whisper to that name fails (`Outbox:drop`). `/cf ping stats` counts
  them ("not whispered (offline)").
- `Sync.online()` leaves out a peer the rule shows offline (left without a BYE), so KILL, RUNANSWER and the logout BYE
  don't go to them.
- The guild alt (CF-84) asks members online first, then those no source knows; members known offline (Battle.net,
  an earlier failure this session) are skipped. The member side's whispers back (GINVACK, GINVFAIL) pass the same
  check.
- The filter: the name is read from the line (`Reach.notFoundName`, the game's format string, else the English text
  with either quote or none) and compared without case and "-Realm" with the names we whispered in the last
  `Reach.FAILED_WINDOW` (30 s); the line is hidden in every chat window and reported once (WHISPER_FAILED, with the
  name as we whispered it). A secret line can't be compared: shown, counted. Registered with
  `ChatFrameUtil.AddMessageEventFilter`, else `ChatFrame_AddMessageEventFilter` (both guarded), again at
  `PLAYER_ENTERING_WORLD` when neither existed at login. `/cf sync debug` prints which one, the counts, the last
  name a line had that matched none of ours, and the names blocked.
- Compatibility (rule 8): nothing stored or sent changes; only fewer whispers go out. Older versions keep whispering
  as before; ours treats their messages as before.
- Manual (VERIFY.md CF-112, V53, V129): a member logs out, `/cf sync` within the minute: no line; `/cf sync debug`
  shows the filter and the block.

### CF-109 Launch probe: the export of 2026-11-08, and the V60b window check
The export of 2026-11-08 (6 testers; builds 70790 and 70862). Same rule as CF-105: an answered check leaves the
probe and FriendProbe's checklist gets a `done` marker. Touches `src/core/Probe.lua`,
`src/services/LaunchProbeMissions.lua`, `src/services/LaunchProbeRecipes.lua`, `tools/FriendProbe/Checklist.lua`, the
probe specs, `docs/API-FINDINGS.md`, VERIFY.md.
- V114 passed (1 tester, build 70862): `CONFIRM_SUMMON` with `C_SummonInfo.GetSummonConfirmSummoner()` gives the
  summoner. To API-FINDINGS; out of VERIFY.md and `Probe.IDS`, its code removed; FriendProbe's item `done`.
- V73 answered as a finding: on 70862 (2 testers, with CF-101's variants) the kill's message is the plain award
  (`You x x x 3 Honor.`, only `COMBATLOG_HONORAWARD` matches): no victim in the honor message. Kills still count via
  `PLAYER_PVP_KILLS_CHANGED` and `GetPVPLifetimeStats` (`GetPVPThisWeekStats` missing). The Hunt and
  `p.punchUp5` / `p.punchDown5` would need the victim from the target or mouseover at the kill: not built here (Nico
  decides). VERIFY.md V73 and the CF-101 step closed, FriendProbe's item `done`; the probe keeps logging the shape
  and the Hunt.
- V70: 3 testers now, all `lockdown false, in progress false` in a boss fight (API-FINDINGS count updated).
- V60b fixed: on 70862 it said "no linked window within 5 s" for a friend online and for the own link, though the own
  link from the Friends tab opens Blizzard's window. The check now looks right after the click (the window may open
  inside `SetItemRef`, before the post-hook), on `TRADE_SKILL_SHOW`, `TRADE_SKILL_DATA_SOURCE_CHANGED` and
  `TRADE_SKILL_LIST_UPDATE`, and once a second until the 5 s run out; for the own link an event or Blizzard's frame
  shown (`ProfessionsFrame` or `TradeSkillFrame`, unverified, looked up by name each time) counts as opened. A click
  that opened nothing logs `seen: events …; IsTradeSkillLinked …; frame …`; a link of another server (CF-107) says
  so and is never a `fail`. VERIFY.md V60 stays open (offline friend, old link, the frame's name).
- Unchanged, still open: V74 (skull `-1`), V100 (inbox sender), V108 (emote), V120 (death to a player); V87 fails as
  before (closed in CF-96).
- `Probe.IDS`: 12 checks (V82, V35b, V73, Hunt, V80, V96, V101, V108, V120, V122, V123, V60b).
- Compatibility (rule 8): nothing stored or sent changes shape; the probe stops writing V114 (its stored result stays
  and is uploaded as before) and V60b writes one more log line.
- Manual (VERIFY.md CF-109): the own link, the frame name, a friend online, offline and on another server.

### CF-108 No Lua error from secret event arguments in combat
Bug (Nico, v1.6.0, boss fight): "attempt to compare ... (a secret string value, while execution tainted by
'CommunitiesForever')" via `WorldEvents.lua` onSkill (CHAT_MSG_SKILL). Midnight hands some event arguments to
addons as secret values in combat; `str(v)` in `src/adapters/missions/WorldEvents.lua` compared `v ~= ""` before
its `Safe.secret` check. Touches: `src/adapters/Safe.lua`, the event handlers in `src/adapters`,
`tests/spec/SecretValues_spec.lua`, VERIFY.md, CHANGELOG.md.
- `Safe.text(v)`: true for a readable, non-empty string, the secret check first; `Safe.values(...)`: the arguments
  with secret ones as nil. WorldEvents' `str` is `Safe.text`.
- Audit: every adapter that forwards raw event arguments as an internal message (Instance, SelfInfo, PvpInfo,
  ChatFrames, Community, LootInfo, Guild, GoalEvents) passes secret ones as nil; every handler that compares a
  raw argument (unit tokens of UNIT_SPELLCAST_*, UNIT_AURA; addon message prefixes; system lines; quest IDs) reads
  it through `Safe.value`/`Safe.text` first. Consumers already handle nil arguments. Pure core files unchanged.
- A spec fires every registered event with secret string and secret number stand-ins (throwing on compare,
  concatenation, indexing, arithmetic) and asserts no handler throws and no internal message carries a secret.
- No change to stored data or messages (rule 8).
- Manual: VERIFY.md CF-108.

### CF-107 Bug batch: profession links on another server
Bug 7 (Nico, v1.6.0, in game): a friend's profession link doesn't open. The stored link is byte for byte the game's
own; the game opens a `trade:` link only when the character's GUID server id (the number after `Player-`) is the
viewer's (6940 vs 6856, one mega-realm). Touches: `src/core/Recipes.lua`, `src/core/Card.lua`,
`src/services/ViewModel.lua`, `src/ui/FriendsTab.lua`, `tests/spec/Recipes_spec.lua`, `tests/spec/Format_spec.lua`,
`docs/API-FINDINGS.md`, VERIFY.md, CHANGELOG.md.
- `Recipes.serverId(guid)` reads the server id of a `Player-<id>-<hex>` GUID, nil for anything else;
  `Recipes.otherServer(viewerGuid, guid)` is true only when both are known and differ (unit tested, nil-safe: an
  unknown or odd GUID behaves as today).
- The Friends tab's profession link cell (the only place profession links show) of a character on another server
  than the one you are on: grey instead of the link colour, first tooltip line "Opens only for players on your
  server". Click and Shift-click to chat unchanged (recommend, not restrict).
- No website link in the tooltip: the addon has no helper for a character's page on the site, so it is left out.
- The second item handed in with this batch (the run view clipped at the 700 px minimum, noted in CF-94) was
  already fixed by CF-95 (released in v1.6.0; manual steps VERIFY.md CF-95), so nothing changes for it here.
- No change to stored data or messages (rule 8): the view gets the current character's GUID, nothing is saved.
- Manual: VERIFY.md CF-107.

### CF-106 Runs tab and Dungeons tab with bosses and loot (boards DL01 to DL03; pairs with WEB-96, WEB-97)
Boards in `docs/design/dungeons-2026-11/` (DL01 Runs tab, DL02 Dungeons tab, DL03 states A to F) and the shared
contract (Nico and the designer, 2026-11-07). Ships in one release with the site; not before Nico's go.
- **Runs tab** (its own tab between Activity and Dungeons): runs grouped Today / Tomorrow / Later (headers only with
  runs; a 14:00 run today is Today); each row name, time, role pips, "3 in · 2 open" (once started "5 in · 3/6
  bosses") and your status: you're in, maybe, can't, gold "answer", grey "no fit" (none of your characters fits; you
  can still answer), grey "no boss yet". Ask now… on the list; "Runs from 09:51 ⓘ"; without runs "No runs planned"
  and "Find a dungeon ›". The detail: name, range, **Dungeon ›** (opens it in the Dungeons tab), the time line
  ("started 20:04" once a boss died), the group rows and Your answer as CF-63 built them, and **Bosses** once the run
  has started: a check per boss killed by the run's group, "3 of 6" (optional bosses don't count), "optional", and
  "– skipped" on a cleared run; hover: "Killed 20:31 (from Grom's log)".
- **Badge** on Runs: runs that haven't started, you haven't answered (nor organise), and one of your characters fits.
- **Progress rule** (`RunProgress.progress`, golden `tests/fixtures/run-progress-cases.json`): kills of the dungeon's
  bosses by characters that answered I'm in or Maybe (or organise), from 1 h before the start until the first daily
  reset after it (the Doomsday day boundary); cleared = the final boss died; a run without a kill leaves the list 3 h
  after its start, a run with kills at the reset.
- **Dungeons tab**: every dungeon grouped Fits you / Higher / Lower (Lower only with dungeons) for the character you
  are on; wings indented; a run tag (Today, Tomorrow, a weekday) that opens the run in Runs. No picker, no Show all.
  Nothing fits: "Nothing fits yet · first at 13". The detail: name, "level · zone · fits", "Last cleared by … · Tue"
  (the final boss's last death in a kill log), the next run's button, Ask now, Plan a run… (the website's link: no
  planning in the game, CF-64), **Bosses & loot** (up to 6 drops per boss, "N more" opens the rest until /reload,
  "Classic data ⓘ", the "Usable by <character>" switch remembered per character, the game's tooltip on hover, Shift-
  click links the item, Quest and "Nobody knows it" tags with their tooltips), then **Quests** (AG05).
- **Fit rule** (one rule with the site): fits when `level >= min - 2 and level <= max` (`Dungeons.fits`), everywhere:
  the tab, the suggestions (`Dungeons.overview`), `PlannedRuns.levelFit` ("fits" from 2 below), open slots, Ask
  now's default dungeon. Golden `tests/fixtures/dungeon-fit-cases.json`.
- **Usable by** (golden `tests/fixtures/loot-usable-cases.json`, cited): the class can ever use it: AllowableClass,
  the armor types reached by 60, shields and relics, weapon types it can learn in Classic. No level, no skills.
- **Data**: `Data\Loot.lua` (`ns.LootData`, contract 2) loads before the UI; generated by WEB-96 (build 70862: 207 bosses, 1,940
  drops), the specs use `tests/fixtures/loot-sample.lua` (GPL-3.0 data, ARCHITECTURE "Loot data file"). Kills from `KillLog` over CF-103's data
  (contract 1: `bossKills` of feed runs, `liveKills` from the KILL message, runs in progress).
- Compatibility (rule 8): nothing sent changes. Stored: two new optional settings (`runsTab.selected`,
  `usableOnly = { [guid] = true }`), nil in older data, so no migration; `dungeonTree.selected` keeps its meaning (a
  stored "run:<id>" no longer matches a dungeon and falls back to the first that fits). Older clients ignore them.
- **Wings** (Nico, 2026-11-07): Dire Maul and Stratholme are split like Scarlet Monastery: `dmeast`, `dmwest`,
  `dmnorth` and `stratlive`, `stratud`, titles "Dire Maul: East" etc. Activities and ranges from the client's
  GroupFinderActivity table (build 70862): 813 East 54–60, 814 West 56–60, 815 North 56–60, 816 Main Gate (Live)
  58–60, 1603 Service Gate (Undead) 58–60; the same numbers as the site. The old ids
  `strat` and `dme` stay readable (rule 8, `Dungeons.LEGACY`): `Dungeons.get` finds them, no list shows them, and a
  run for one lists every wing's bosses under the wing's name and is cleared when any wing's final boss dies
  (`DungeonLoot.bossesFor`; golden cases in both fixtures). New plans use the wing ids.
- **Recipe skill** (Nico, 2026-11-07): recipe drops may carry `skill` and `line`; "Can learn" lists only characters
  with that profession at that rank, the tooltip says "Requires Cooking (75)"; without `skill` the profession is
  enough.
- Not in it: raids.
- Done when: specs for the core rules on the golden files, the tabs (RunsTab_spec, DungeonsTab_spec); busted and
  luacheck pass. Manual: VERIFY.md CF-106, V138 to V140.

### CF-105 Launch probe: the export of 2026-11-07
The export of 2026-11-07 (6 testers; builds 70790, 70840 from 01:39 UTC and 70862 from 09:24 UTC) answers the recipe
details. Nico's rule: a check that failed in every export with the same reason is a finding ("fails on Forever"):
it leaves the probe, FriendProbe's checklist gets a `done` marker, and the goals that waited on it are retired or
re-planned. Info results that are still to see (V82, V108, V120, V123) are not failures. Touches `src/core/Probe.lua`,
`src/services/LaunchProbeRecipes.lua`, `src/services/LaunchProbe.lua`, `tools/FriendProbe/Checklist.lua`, the probe
specs, `docs/API-FINDINGS.md`, VERIFY.md.
- V60c passed (build 70840): `GetTradeSkillLineForRecipe` answers per learned recipe (Cooking: line 2939, parent 185);
  skill-up colour, skill-ups and reagents readable; `numAvailable`, `GetRecipeCooldown` and `GetRecipeSourceText`
  missing; the list link is the short form (4 fields). To API-FINDINGS; VERIFY.md V137 closed (CF-38's `recipeLines`
  works); out of `Probe.IDS` and its code removed.
- V60 answered: with Cooking open `GetAllRecipeIDs` gave 132 IDs (Tailoring 471): the list is the open profession's,
  as CF-102 assumes. Out of `Probe.IDS`; only V60b (a friend's link while they are offline) stays. VERIFY.md V60 keeps
  only V60b and the old-link question; the answered CF-98, CF-100 and CF-101 steps go.
- V98 passes for 2 testers (both reads on one client): noted in API-FINDINGS.
- Failed in every export: V87 (closed as failed in CF-96, CF-97 built the guild route) and V70 (its `fail` means "no
  lockdown during a boss fight", the answer recorded in CF-101) are not in the probe any more. V73 fails only from
  clients before CF-101 (old wording, no shape logged), so it stays open and in the probe. No goal waits on a check
  that always failed, so CF-104 (pool 4) is unchanged.
- `Probe.IDS`: 13 checks (V82, V35b, V73, Hunt, V80, V96, V101, V108, V114, V120, V122, V123, V60b). Stored results of
  removed checks stay in the saved data and the upload, as in CF-96.
- Compatibility (rule 8): nothing stored or sent changes shape; the probe only stops writing two keys.
- Manual (VERIFY.md CF-105): `/cf fp` counts 13.

### CF-103 Send which bosses a run killed and when, and share kills live (pairs with the site's WEB-97)
Dungeon feature (boards DL01–DL05, shared "Data contract 1: kills"): kill times are the base for all boss progress
(addon Runs tab CF-106, site run and dungeon pages WEB-97). Built 2026-11-07.
- Runs: the run in progress keeps each kill's server time, `bosses = { [encounterID] = at }` (was `true`, from
  `ENCOUNTER_END` success 1, V35). Store schema 3: the migration gives old `true` kills the run's `lastAt`.
- RECORD: each run in `feed.*.*.runs` gets the optional `bossKills = { [encounterID] = at }` next to the unchanged
  `bosses` count (contract; replaces the earlier `bossIds` idea). Cleaned on receipt (whole IDs, at most 40, times more
  than 5 minutes ahead dropped, also from the owner). Feed merge: the kills of both copies of an entry are joined, the
  union with the earliest time per boss, so a copy relayed by an older client (which drops the field) loses nothing.
- Live: a new message type `KILL { guid, instance, name, encounter, at }` (pv 1) to everyone online right after a
  kill; held while `Instance.messagingRestricted()` and tried again 30 s later, like RUNS. The receiver keeps it in
  `global.liveKills[guid][encounterID] = at` (earliest wins, 2 days, only the sender's own characters) and fires
  `ActivityTracker.KILLS_CHANGED`. Live kills are kept apart from the records because a run reaches the record only
  once it is over (CF-23), and an accepted owner record replaces the feed whole.
- API for CF-106 (pure core): `BossKills.collect(records, live, guids, encounterIDs, from, to)` returns
  `{ [encounterID] = { at = earliest, by = { [guid] = at } } }`; the service `ActivityTracker.kills(guids,
  encounterIDs, from, to)` calls it with every stored record (own and friends'), `global.liveKills` and the own runs
  in progress.
- Compatibility (rule 8): an older client sends runs without `bossKills` (count only) and ignores ours: its clean
  drops the field, and its relayed copies come without it (our merge keeps the times we hold). It ignores `KILL`.
  An older version opening schema-3 data (downgrade) leaves it alone and reads `bosses[id]` (a time) as true.
  Golden fixtures unchanged.
- Manual (VERIFY.md "CF-103").

### CF-104 Pool version 4
Nico (2026-11-07): retire "Defend home" and add what is ready. Nico (2026-11-09): build and release it now, with the
joins below. Pairs with the site's WEB-101, same release. Touches: `src/core/Doomsday.lua`,
`src/core/missions/Battle.lua`, `src/core/missions/World.lua`, `src/adapters/missions/BattleEvents.lua`,
`src/adapters/missions/WorldEvents.lua`, `src/core/Pvp.lua` and `src/services/PvpTracker.lua` (the victim's GUID),
`tests/fixtures/doomsday-cases.json`, `tests/fixtures/missions/battle.json`, `tests/fixtures/missions/world.json`,
`docs/DOOMSDAY.md`, VERIFY.md, CHANGELOG.md. Built 2026-11-09.
- `Doomsday.POOL_VERSION = 4`.
- **Retired:** `p.homeGuard` gets `retired = 4` (V123: own zones outside the capitals have no PvP type, so it only
  counts inside a capital). Pool 1 to 3 draws are unchanged.
- **Joins (`since = 4`), each with a registered progress and cases:**
  - The flag missions from V121 (`UnitIsPVP("player")` read on `PLAYER_FLAGS_CHANGED`, at login and each minute):
    `p.flagUp` (10 minutes flagged on a character), `p.flagHour` (30 minutes flagged in one run, no death or unflag),
    `b.flagged3h` (3 hours flagged, all characters of the week).
  - `d.reward`, `d.fishFriend`, `d.feedFriend`: their in-game check passed (Nico, 2026-11-09).
  - `d.summoned`: a friend's summon (`CONFIRM_SUMMON`, `C_SummonInfo.GetSummonConfirmSummoner()`, V114) accepted (a
    post-hook on `C_SummonInfo.ConfirmSummon`, unverified).
  - `d.auctionPost`: an auction posted (`AUCTION_HOUSE_AUCTION_CREATED` or `ERR_AUCTION_STARTED`, V101); buying
    (`d.auctionBuy`) stays out.
  - `p.revenge` ("Avenge a death"): a kill, outside a battleground, of the player who last killed that character that
    day, by GUID: the killer from the death recap's last damage source (V120), the victim from CF-110's pick
    (`Pvp.pickVictims` now returns the look's `guid`; `Pvp.killEntry` never keeps it).
  - "Send mail" is `d.mailFriend`, already in pool 3; `d.mailbox` (the inbox) stays out.
  - **The Hunt** (Nico, 2026-11-09, "add it to the pool"): `Doomsday.HUNT_SINCE = 4`; golden `draws.hunts` cases
    with `pool: 4` and `huntSince: 4` in the golden file. The victim from CF-110's pick, the prey hint from CF-114.
- Golden `draws` cases for pool 4's days and weeks from its first day, and three pool-4 swaps; the cases of pools 1
  to 3 unchanged.
- Compatibility (rule 8): an addon on pool 3 keeps drawing and recording pool 3 (`pool = 3` on its days); every
  pool-4 id is already in its catalogue, so it scores a friend's pool-4 day. New local day and week facts only
  (`battle.flagged`, `flagRun`, `flagBest`, `killers`, `revenge`; `world.summons`, `world.auctions`), read nil-safe;
  nothing new is sent. The release notes ask friends to update.
- Manual (VERIFY.md CF-104).

### CF-99 Pool version 3
After the launch probe (CF-96) and the three tracker lanes (CF-74 #222, CF-75 #224 #225, CF-76 #221). Follows CF-77.
Touches: `src/core/Doomsday.lua`, `src/core/missions/Battle.lua`, `src/adapters/missions/BattleEvents.lua`,
`tests/fixtures/doomsday-cases.json`, `tests/fixtures/missions/battle.json`, `docs/DOOMSDAY.md`, VERIFY.md,
CHANGELOG.md. The site ships its copy in the same release (WEB story in CommunitiesForever-Web).
- `Doomsday.POOL_VERSION = 3`; `since = 3` on the 82 missions of CF-74 to CF-76 whose checks passed, each with a
  registered progress (tests); not `d.reward`, `d.fishFriend`, `d.feedFriend` (they wait for an in-game check).
- `p.homeGuard` (CF-81): a counted kill in a zone whose PvP type read "friendly" (V123), `since = 3`; progress cases
  in `tests/fixtures/missions/battle.json`.
- The honor rank goals `p.ranked`, `p.rankUp`, `b.ranked5`, `b.rankUp` get `retired = 3` (Nico, 2026-11-06:
  `UnitPVPRank` is missing on Forever); pool 1 and 2 draws are unchanged. `docs/DOOMSDAY.md` says the rank titles,
  rank 0's included, don't show on Forever.
- `docs/DOOMSDAY.md`: `d.bank`, `d.repair`, `d.trainer` are CF-76's in the Data column.
- Golden `draws` cases for days and weeks of pool version 3 from its first day (`pool: 3`) and two pool-3 swaps;
  pool-1 and pool-2 cases unchanged; `Compat_spec` passes.
- Compatibility (rule 8): no switch date, as CF-77: each day records the pool version it was drawn with. An addon on
  pool version 2 keeps drawing version 2 and scores a friend's version-3 day by its `pool` (every id is already in
  its catalogue). Stored data: only new local day facts (`battle.zones`), optional. No new message fields.
- Manual (VERIFY.md CF-99).

### CF-97 A friend who appears offline is known by their BattleTag over the guild
From the launch probe (V87 failed on build 70790, CF-96): from a Battle.net friend who appears offline,
`C_BattleNet.GetGameAccountInfoByID` gives no `playerGuid` and no BattleTag, so their Battle.net messages are dropped.
In the selected guild or community they still sync, as `aid:<id>`, but CF-90 refused their `btag` because the tag is a
current Battle.net friend's ("Battle.net decides for them"). Battle.net can't decide here. Touches:
`src/core/Identity.lua`, `src/services/Sync.lua`, specs, SYNC.md, VERIFY.md, CHANGELOG.md.
- `Identity.claimBattleTag` takes a current Battle.net friend's BattleTag when Battle.net does not show that friend in
  Forever now (no entry in `PresenceTracker.online()`), with every other CF-90 guard (tests). Without an online list
  (`ctx.online == nil`) every friend counts as shown, and the claim is refused as before (tests).
- Still refused while Battle.net shows the friend in Forever, from any character (tests).
- Before the Battle.net friends are read the claim is taken like any BattleTag (as in CF-90); once Battle.net shows
  the friend, their own record carries the same BattleTag and account ID: nothing changes (tests).
- A friend who is really offline can't send over the guild. Someone else claiming their BattleTag is refused when we
  ever synced them (the first owner keeps it: their record holds another account ID, or lists other characters);
  one we never synced can be claimed, the same risk as CF-90 for non-friends (tests).
- Online: a friend known this way stays offline in the window, as Battle.net shows them (privacy, CF-15): `Sync.online`
  lists no community peer whose key is a current Battle.net friend (tests).
- The inert hidden-friend path (`Friends.resolveHidden`, `addHidden`, `PresenceTracker.isHidden`) stays: Blizzard may
  fix the API.
- Compatibility (rule 8): nothing sent and no stored shape changes. Older clients send `btag` the same way (v1.3.1 on)
  or none; an older receiver keeps refusing a friend's claim and keeps the friend under `aid:`. No migration.
- Decided by Nico (2026-11-06): accept the guild BattleTag claim of a friend Battle.net doesn't show in Forever.
- Manual (VERIFY.md CF-97).

### CF-98 Launch probe: the recipes check (V60)
CF-38 (recipes) was prepared before launch with a FriendProbe-only check `/fp recipes` (PR #63, never merged), so the
launch probe never looked at recipes. Now the addon's own probe does, so friends' normal play answers it. Touches:
`src/services/LaunchProbeRecipes.lua` (new), `src/core/Probe.lua` (`Probe.IDS`), `CommunitiesForever.toc`, a comment
in `src/services/LaunchProbe.lua`, `tools/FriendProbe/Checklist.lua`, `tests/spec/LaunchProbe_spec.lua`, VERIFY.md.
- V60, passive: on `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE` and `TRADE_SKILL_DATA_SOURCE_CHANGED` for the own
  window (not a linked one), at most every 10 s and until it passed: which `C_TradeSkillUI` functions are missing
  (a log line), the base and child profession IDs, the number of recipes and of learned ones, from which call the
  item a recipe makes comes (`GetRecipeOutputItemData`, `GetRecipeItemLink`, `GetRecipeSchematic`), and whether
  `GetTradeSkillListLink` gives a `trade:` link. Two learned recipes are noted with their item IDs. Pass: learned
  recipes with an item from at least one call; fail: no `C_TradeSkillUI` or `GetAllRecipeIDs`, or learned recipes
  without any item; info while the list is still empty (tests).
- V60b, needs a click: a post-hook on `SetItemRef` notes a clicked `trade:` link (never acts on it); a
  `TRADE_SKILL_SHOW` or `TRADE_SKILL_DATA_SOURCE_CHANGED` with `IsTradeSkillLinked` true within 5 s answers it. Whose
  link is kept as one word: "yours", "a friend online" (Battle.net presence or a sync peer), "a friend offline" (a
  character of someone in `global.people`) or "someone else". Pass: a friend's link opened while they are offline;
  info: it opened otherwise; fail: a friend's link opened no linked window within 5 s; open until someone clicks one
  (tests).
- Privacy: counts and IDs only (recipe, item, profession); no recipe, item or player names, no GUIDs (tests). Same
  size cap as the other checks (`Probe.trim`). Every API guarded (rule 3; VERIFY.md V60).
- FriendProbe: `/fp recipes` from #63 is not ported (friends run the addon, not FriendProbe, and the addon's probe
  answers the same); its checklist gets a V60 item pointing at `/cf fp`.
- Compatibility (rule 8): two new keys under `global.probe.results.<client>` (`V60`, `V60b`); no migration, nothing
  sent changes. Older versions keep and upload results they have and never write these. The site's reader
  (CommunitiesForever-Web `src/core/probe.ts`) passes the section through without reading item keys.
- Not user-facing (the probe is invisible), so no CHANGELOG line.
- Manual: VERIFY.md V60 and CF-98.

### CF-100 Launch probe: scan the recipes again once the list has loaded
The export of 2026-11-06 (evening) has V60 `info` with `0 recipes, 0 learned` on `TRADE_SKILL_SHOW`: the recipe list
loads just after that event, and the `TRADE_SKILL_LIST_UPDATE` that follows within seconds fell in the 10 s throttle
(`Recipes.EVERY`). No event came after it, so V60 never saw the loaded list. Touches
`src/services/LaunchProbeRecipes.lua`, `tests/spec/LaunchProbe_spec.lua`, VERIFY.md, API-FINDINGS.md.
- A throttled scan schedules one later scan when the throttle runs out (`C_Timer.NewTimer`, verified), at most one at a
  time; it stops as before once V60 passed or while a linked view is open.
- API-FINDINGS gets the partial V60 answer (the functions exist, profession ID, list link, own link opens Blizzard's
  view with 471 recipe IDs); VERIFY.md V60 keeps what is left.
- Compatibility (rule 8): nothing stored or sent changes; an older client keeps its `info` result until it updates.
- Manual (VERIFY.md CF-100).
- Not user-facing (the probe is invisible), so no CHANGELOG line.

### CF-102 Recipes: a scan adds, never replaces
WEB-90 found that the probe's 471 recipe IDs equal Forever's Tailoring recipes in the client data, so
`GetAllRecipeIDs` likely gives only the open (or last loaded) profession's list, not every profession. CF-38 replaced
the stored set on each scan, so opening Cooking after Tailoring dropped the Tailoring recipes and restarted the list
(a full resend to every friend; on the site, recipes vanishing and coming back as "new"). Touches
`src/core/Recipes.lua`, `tests/spec/Recipes_spec.lua`, ARCHITECTURE.md, SYNC.md.
- `Recipes.apply` adds the scan's learned recipes (and `recipeLines`) to the stored ones; a recipe a scan doesn't
  list stays. Recipes are never unlearned here (Nico: the unlearn case doesn't matter); a new order and base start
  only when a recipe's item changes.
- Compatibility (rule 8): no shape change. A v1.5.0 client may have replaced its set once; the next scans fill it
  again, and friends get the list via the existing base logic.
- Manual: VERIFY.md CF-38 (open Tailoring, then Cooking: `/run` count of `recipes` keeps growing).

### CF-101 Honor message variants; the probe checks a recipe's profession (V60c)
The export of 2026-11-06 21:33: the first honorable kill's message did not match `COMBATLOG_HONORGAIN` (V73 fail), so
kills on Forever had no victim (the Hunt, `p.punchUp5`, `p.punchDown5` can't count); and `GetAllRecipeIDs` gives every
profession's recipes at once, so CF-38 needs each recipe's profession. Touches `src/core/Pvp.lua`, `src/core/Probe.lua`,
`src/adapters/PvpInfo.lua`, `src/services/PvpTracker.lua`, `src/services/LaunchProbe.lua`,
`src/services/LaunchProbeRecipes.lua`, specs, VERIFY.md, API-FINDINGS.md.
- Honor messages: `PvpInfo.formats().honors` lists the readable `COMBATLOG_HONORGAIN`, `_NO_RANK` and
  `_EXHAUSTION1` to `4`; `Pvp.honorArgs` / `Pvp.victim` try them in order (a variant without a rank gives rank nil).
- V73: passes naming the global that matched; a miss keeps the message's shape (`Probe.shape`: words not in the
  formats become `x`, so no names) and logs the game's `COMBATLOG_HONOR...` globals once.
- V60c (new): with the own profession window open, `GetTradeSkillLineForRecipe` for each learned recipe (counts per
  line/parent), and of one learned recipe the skill-up colour, skill-ups, can-make count, category, reagents and
  cooldown; of one unlearned recipe whether `GetRecipeSourceText` gives text (its length only). The scan goes on
  after V60 passed until V60c passed.
- Findings from the export moved to API-FINDINGS (V60, V70, V73, V76, V79, V121, V123). `p.homeGuard` counts only in
  the capitals (own zones outside them give no PvP type); left as is until Nico decides.
- Compatibility (rule 8): nothing sent or stored changes shape; a new probe key `V60c` under
  `global.probe.results.<client>` (free-form, uploaded as is). Kill entries keep their shape; Forever kills now get
  the victim fields they lacked.
- Manual (VERIFY.md CF-101). User-facing: Forever kills get their victim (CHANGELOG).

### CF-96 Launch probe results: answered items closed, the probe trimmed
Nico exported the launch probe's results from the site on 2026-11-06: 6 testers on Forever live, build 70790. Touches:
`VERIFY.md`, `docs/API-FINDINGS.md`, `src/core/Probe.lua`, `src/services/LaunchProbe.lua`,
`src/services/LaunchProbeMissions.lua`, `tools/FriendProbe/Checklist.lua`, comments in the adapters that named the
answered items, their specs.
- `docs/API-FINDINGS.md` "Forever launch probe": what was seen per item, as "N of 6" (no names, BattleTags or
  character details). Answered: V55, V63, V71, V77, V78, V81, V83, V84, V86, V90, V93, V94, V95, V98, V102 to V105,
  V107, V109 to V113, V115 to V117. Failed: V87 (a friend who appears offline sends, but
  `GetGameAccountInfoByID` gives no `playerGuid`, so no BattleTag). `UnitPVPRank` is missing on Forever (V79).
- `VERIFY.md` holds only what is still open, with narrower steps: V74 (a skull), V79 (`GetPVPRankInfo`,
  `GetPVPThisWeekStats`, `PLAYER_PVP_KILLS_CHANGED`), V82 (riding, reopened: no tester had it), V85 (what was given),
  V99 (sale, item link, repair cost), V100 (the inbox), V106 (slot links, fishing source), V108 (the emote), V120
  (a player killer), V123 (hostile, contested, starting zones). V87 is closed as failed.
- The probe (`Probe.IDS`) runs only the open checks: V82, V35b, V70, V73, V76, the Hunt, V80, V96, V101, V108,
  V114, V120 to V123 (tests). Enemy players are still looked at for the Hunt. V108 passes on an emote at an
  enemy-faction player alone; V123 keeps looking after "friendly" and notes each new type; `PLAYER_PVP_KILLS_CHANGED`
  is noted under V73 (tests). `Probe.realmClock` (V78) is gone.
- FriendProbe's checklist marks the answered items `done = "forever 70790"`; V82 is open again (spec).
- Compatibility (rule 8): results stored for the removed checks stay in `global.probe` as they are, are uploaded
  as before and only leave the `/cf fp` report; no migration, no schema change (tests). The site's reader
  (CommunitiesForever-Web `src/core/probe.ts`) passes the section through without reading item keys, so files with
  and without the removed keys both work. Nothing sent changes.
- Not user-facing (the probe is invisible), so no CHANGELOG line.
- Manual (VERIFY.md CF-96).

### CF-95 Run view fits the window's smallest width
Open bug (noted in CF-94): at the window's 700 px minimum the detail shows about 408 px, but a run (and a dungeon, and
the empty states) was laid out at least 520 px wide, so the right side was cut off: the group rows' status, "Ask now
for this run", the answer buttons. Touches: `src/ui/DungeonsTab.lua`, `src/ui/RunAnswer.lua`,
`tests/spec/DungeonsTab_spec.lua`, `tests/mocks/wowapi.lua`, VERIFY.md, CHANGELOG.md.
- Everything in the detail follows the width that shows (at least 300 px), like CF-94's "Online now, fits".
- Texts are one line, cut with "..." where they don't fit (the empty state's explainer still wraps). Buttons stay
  whole: what doesn't fit beside something goes below it ("Ask now for this run" under the Group header, "Whisper
  <friend>" under Invite all, the planned-run button under a dungeon's title, the answer block's dropdown and roles on
  the next line, the empty states' buttons below each other).
- Every state: your run and a friend's, Invite open, an ask, a dungeon with quests, the empty and no-fit states.
- No change to stored data or messages (rule 8). No new strings.
- Specs: each part at the 700 px minimum (text + gap + buttons within the row width).
- Manual: VERIFY.md CF-95.

### CF-94 Run detail: Online now, fits at full width, Edit or cancel below
Live feedback (Nico, v1.3.1, 2026-11-05, screenshot): in a planned run's detail, "Online now, fits" had only the left
column beside "Edit or cancel", and the Whisper buttons covered the "level · friend" text. Touches:
`src/ui/DungeonsTab.lua`, `tests/spec/DungeonsTab_spec.lua`, VERIFY.md, CHANGELOG.md.
- "Online now, fits" takes the full width; "Edit or cancel" (organiser) or "On the website" (others), with its ⓘ and
  the link box, goes below it, also at the full width. Strings unchanged.
- Each online row: name and "level · friend" end 8 px before Whisper (and Invite once inviting opens); the info stays
  whole where it can, the name gets the rest; what doesn't fit is cut with "..." on one line.
- Near the window's 700 px minimum the detail shows less than the 520 px the run view is laid out at: these two parts
  follow the width that shows (at least 300 px), so Whisper stays in view.
- Same in every state: organiser and member, nobody online, many online (the detail scrolls).
- No change to stored data or messages (rule 8).
- Manual: VERIFY.md CF-94.

### CF-93 Ctrl+C in the guild invite window copies the command
Live feedback (v1.3.1, a guild member, 2026-11-05): "I couldn't CTRL-C the guild invite string that popped up. I had
to manually type it in… Ctrl-C just pops open my character page." The copy box (CF-88) had no keyboard focus, so C
went to the character window's key binding. Not known yet: whether the text was highlighted or grey, whether they
clicked the box first, whether their chat is IM style. Touches: `src/core/GuildInvite.lua`, `src/adapters/Guild.lua`,
`src/ui/GuildInvitePopup.lua`, `src/services/GuildInvites.lua`, the GuildInvite specs, VERIFY.md, CHANGELOG.md.
- **Focus rule:** a chat input only blocks the focus while it is shown and has the keyboard (`HasFocus`); one that is
  merely open or active (IM-style chat keeps it on screen) does not. Another edit box blocks only when
  `GetCurrentKeyBoardFocus` returns one that is shown and isn't the copy box. Combat and moving still block. Every
  call is guarded.
- **A click always focuses and selects:** on the box, the window body or the key row; selected again on mouse up.
  Taking the focus moves it off a chat input without the addon touching that input (V135).
- **Unfocused state:** besides the mouse cap, "Click here, then Ctrl+C" inside the box (right, gold) while it isn't
  focused and nothing is copied yet; hidden once focused. The window makes room for it when it arrives unfocused.
- **Focus again:** while the window waits unfocused since its arrival (never clicked, nothing copied), it checks every
  0.3 s and takes the focus after two free checks in a row (standing still, out of combat, nobody typing). A focus
  the player let go of (a key, Enter, a click elsewhere) is never taken back.
- Shift and Alt alone no longer release the focus.
- **Debug:** `/cf sync debug` prints each focus decision and why as a `[guild]` line ("invite window focus on
  arrival: no (moving): combat no, speed 7, chat open yes, chat typing no, other box no"), on a retry, on a click,
  and the key that let go of the focus.
- No change to stored data or messages (rule 8).
- Manual: VERIFY.md CF-93.

### CF-91 Quiet chat: no "CommunitiesForever:" lines a banner already shows
Nico (2026-11-05, live on Forever): "I want to remove all of those CommunitiesForever consoles. We show banners for
login and level up, don't wanna double up like that. No need for the reload also." The addon prints only what has no
other place.
- No chat line when a friend comes online or switches character, or a friend's character levels up (CF-15, CF-16).
  The level-up announcement (CF-44) stays.
- No Doomsday chat lines (goal done, bonus kill, someone else's crown, a swapped goal). The celebration banners and
  the crown toast stay.
- No run chat lines (reminder, starting now, a friend on another character, answers to your run, Discord ping
  queued, "Runs updated ... /reload"). The run banners and the start panel stay.
- No "Showing community ..." line when the addon picks the only community by itself.
- Kept: the guild invite lines (CF-87/88), answers to `/cf` commands and to the player's own clicks, errors and
  refusals, `/reload` hints where the player otherwise waits for nothing (an ask posted on Discord, a failed Reload
  now), and debug output (`/cf sync debug`, `/cf activity debug`, `/cf ping`).
- Decided by Nico (2026-11-05): keep a friend's group ask with [Join] [Later] [No], the answers to your own ask
  (with [Invite]) and the update notices ("A newer version … is available", "A friend uses a newer … version");
  dropping "Showing community …" is fine.
- Switches that only turned a removed line on or off are gone from the settings window, the options and the setup
  (When friends log in, Announce friends' level-ups, Doomsday in chat, the six run chat lines). Their stored values
  stay, unused (rule 8: older versions still read them).
- Manual: VERIFY.md CF-91.

### CF-88 The guild invite window (designer's flow)
Stacked on CF-87 (PR #201). The designer's boards GI01Window (the member's window, all states), GI02Screen (placement
at 1920×1080 and 3440×1440) and GI03Alt (the alt's chat lines), and the designer's brief, with Nico's deviations
(2026-11-05). Touches: `src/ui/GuildInvitePopup.lua`, `src/services/GuildInvites.lua`, `src/core/GuildInvite.lua`,
`src/adapters/Guild.lua`, `src/adapters/Sounds.lua`, `src/ui/kit/Theme.lua`, `.luacheckrc`, the WoW mock, the
GuildInvite specs, `tools/FriendProbe/`, VERIFY.md, CHANGELOG.md.
- **Window:** 400 px wide, growing with the command up to 520; title bar 30 px with the shield, "Guild invite" and
  an X; padding 12, gaps 10. "Invite <Name> (<Owner>'s alt)?" with the name in its class colour (white when
  unknown) and the owner's display name, never a BattleTag; at most two lines. A 32 px copy box with exactly
  `/ginvite <name as reported>`, read-only in effect. Key caps [Ctrl]+[C] › [Enter] › [Ctrl]+[V] › [Enter] (22 px,
  1 px edges, 3 px bottom edge; done gold fill, next gold outline, upcoming grey); tooltip "Copy · open chat · paste
  · send". `TOP` of UIParent, 0, −262; strata DIALOG; not movable; `SOUNDKIT.IG_MAINMENU_OPEN` once on arrival.
- **Focus:** the box takes the focus only out of combat, standing still, with no chat input open and no other box
  focused (CF-93: only a chat input being typed in counts); else it arrives unfocused (grey text, a mouse cap first) and one click focuses and selects. While
  focused, Ctrl, C, Enter and Esc work; any other key releases the focus.
- **Keys light only on events:** Ctrl+C on the box's OnKeyDown; Enter on its OnEnterPressed (it releases the focus,
  the window stays, nothing opens the chat: deviation A); Ctrl+V when a chat input's text becomes the command
  (post-hook, `PASTE_HOOK`, V137: deviation B); Enter on "You have invited <name>".
- **States:** sent (all lit, a check at 150 ms, faded out by 1.2 s; chat "Invited <Name> (<Owner>'s alt) into the
  guild."); refused while the window shows the request (closes at once, chat "<Name> (<Owner>'s alt) will ask
  someone else.", GINVFAIL to the alt; no line for another faction); closed with X or Esc (nothing printed or sent);
  a new request replaces the shown one in place (keys reset, a gold edge for 400 ms; no queue).
- **Alt:** chat lines only, with the shield and in gold: "Asked …", "Click Accept to join …", "No member of …
  answered …". No waiting window (GI03 option B).
- Deviations from the brief: A (no chat input opened: 5 key presses, 4 caps; Nico, 2026-11-05: keep 4 caps), B (the paste hook behind a switch),
  C (no locale table, rule 6), D (no new protocol: the refusal is GINVFAIL), E (unverified APIs guarded, V136),
  G (Esc through the frame's own keyboard handler, not `UISpecialFrames`, which needs a named global, rule 5).
- Decided (Nico, 2026-11-05): keep 4 caps; the window stays open after the first Enter (players close it with X or
  Esc); the whisper buttons (Dungeons tab and menus) that open the chat input stay as they are (tested in game).
- No change to stored data or messages (rule 8).
- Manual (VERIFY.md CF-88, V136, V137).

### CF-87 Guild invites by copy and paste
Bug from Nico's in-game tests with a friend, 2026-11-05: CF-84's guild invite does not work at all. On Forever an
addon cannot send a guild invite in any way (`docs/API-FINDINGS.md` "Guild invites"): `C_GuildInfo.Invite` /
`GuildInvite` are forbidden also inside a click (V126, build 9), a secure macro button with `/ginvite` gives "Macro
script disabled" (V134, build 10), and `/ginvite` put in the chat input by the addon is forbidden on Enter (V135,
build 10). Typing `/ginvite <alt name>` by hand works. Copy and paste is the only way (Nico, 2026-11-05). Blocks the
guild release. Touches: `src/adapters/Guild.lua`, `src/core/GuildInvite.lua`, `src/services/GuildInvites.lua`,
`src/ui/GuildInvitePopup.lua`, `tests/mocks/wowapi.lua`, the GuildInvite specs, `tools/FriendProbe/`, VERIFY.md,
API-FINDINGS.md, CHANGELOG.md.
- Addon code never calls `C_GuildInfo.Invite`, `GuildInvite` or `AcceptGuild`, has no secure button, and never opens
  or fills the chat input in the invite flow (`ChatFrameUtil.OpenChat`, `ChatFrame_OpenChat`, `ChatEdit_*`, or text
  set on a chat edit box).
- Every request that passes `checkRequest` shows the member's popup at once: "Invite <alt> (<friend>'s alt)?", an
  edit box in our own window with `/ginvite <name exactly as the whisper's sender was reported>`, focused and
  highlighted so Ctrl+C copies it at once, and the line "Ctrl+C, Enter. Then Enter, Ctrl+V, Enter." The explanation
  is the box's tooltip. Typing restores the text and selects it again; a click selects it all. Enter, Esc or X
  closes the window.
- "Invited %s into the guild." confirms the member's own pasted invite through `ERR_GUILD_INVITE_S`, matched by name
  to the pending request. A refusal text within `REFUSAL_WINDOW` (60 s) of the popup showing or closing is reported
  to the alt (GINVFAIL). The alt waits `INVITE_WAIT` 120 s (was 60) after an ack before asking the next member.
- The alt never accepts by itself: after its request, an invite into the remembered guild prints "Click Accept to
  join %s." and the alt clicks Blizzard's Accept.
- Minimal look with the Kit; the designer's board for this window and the alt's side follows as its own change.
- FriendProbe: the V126 invite buttons are gone (V126, V134, V135 answered).
- No change to stored data or message fields (rule 8).
- Manual (VERIFY.md CF-87).

### CF-92 A website friend listed twice
Nico (2026-11-05): a Battle.net friend without the addon showed twice in the Friends list: live (Battle.net and
the guild) and under "From the website", because the site names them by their site display name and the addon only
matched display names. Now a website friend with a character (by name, any case) already in the list (people or
Unlinked) is not listed again (`Format.tree`). No change to stored data or messages (rule 8).
- [x] A website friend with another name but a known character is not listed under "From the website"
- [x] Unit test in `Format_spec`

### CF-90 Guild members known by their BattleTag
From Nico at launch (2026-11-05): a member reached only over the guild or community (not a Battle.net friend) is
stored under `aid:<accountId>`, because no BattleTag travels over the community (CF-28). The site can't group them
under a Battle.net account or give them access ("Played by Unknown player"). The site's side is WEB-86.
Touches: `src/core/Identity.lua`, `src/core/Linker.lua`, `src/services/Sync.lua`, specs, SYNC.md, ARCHITECTURE.md,
VERIFY.md, CHANGELOG.md.
- Each addon sends its **own** BattleTag over the guild or community: an optional `btag` in its HELLO and in its own
  RECORD there, only when known. Relayed records never carry one (tests).
- A HELLO or own record over the community with a valid `btag` re-keys that person from `aid:<id>` to the BattleTag,
  keeps `aid = <id>`, and merges anything stored under the `aid:` key (`Merge.absorb`). Later messages under the
  `aid:` key land on the BattleTag; over the community the person is still sent as `aid:` (tests).
- Spoofing guards (`Identity.claimBattleTag`): only from the account's own character (the sending character is in
  that account's record, or the account is new, and in no one else's record); never your own BattleTag, never a
  current Battle.net friend's (Battle.net decides for them), never against a presence link of the sending character
  to another BattleTag, never a BattleTag another account ID already has, never an account ID already known under
  another BattleTag. The first account that claims a BattleTag keeps it (tests).
- CF-89 stays: only people with a character in the selected community are stored or synced (tests).
- Compatibility (rule 8): `btag` is optional within `pv` 1. Older clients send none and ignore ours; they keep
  `aid:` keys. No stored shape change, no migration: `people` holds BattleTag and `aid:` keys as before.
- Manual (VERIFY.md CF-90).
- Decided by Nico (2026-11-05): each addon shares its own BattleTag over the guild or community; guild members may
  see each other's BattleTags.
- Decided by Nico (2026-11-05): guild members known by BattleTag take part in the Doomsday Board, Ladder and
  celebration banners like friends (those skip only `aid:` keys).

### CF-89 Only the group takes part
Bug from Nico at launch (2026-11-05): `PresenceTracker` / `Friends.recordPresence` wrote `presence` for every
Battle.net friend seen in Forever, and `Sync` HELLOed every Forever game account of every friend, so records were
exchanged with friends outside the group and stored in `people`. The upload carried them all, and the site made
every BattleTag in `people` and `presence` a site member ("has no addon data yet"). The site's side is WEB-85.
Touches: `src/core/Belongs.lua` (new), `src/core/Friends.lua`, `src/services/MemberTracker.lua`,
`src/services/PresenceTracker.lua`, `src/services/Messenger.lua`, `src/services/Sync.lua`, specs,
`tests/fixtures/capture.lua`, ARCHITECTURE.md ("Who belongs"), SYNC.md, VERIFY.md, CHANGELOG.md.
- A person belongs when at least one of their characters is a member of the selected community or guild, also while
  they play an alt outside it; their characters come from presence links, the character they are on now and their
  own record. You always belong. Without a selected community nobody belongs: no sync at all (tests).
- Over Battle.net nothing is sent to a friend who does not belong (HELLO, REQ, RECORD, relays, RUNS, SCHED, asks,
  pings) and nothing from them is accepted or stored (tests).
- `presence` keeps only links of member characters and of people who belong; `people` only people who belong. What
  earlier versions stored is removed at run time once the members are known (tests).
- `CommunitiesForeverDB.global.members = { [guid] = { name, seenAt } }`: the selected community's members as last seen
  by this client, replaced whole on every member update, `{}` without a community (the site's proof of who is in
  the group); in the golden fixtures from the next release on (tests).
- Login timing: the roster is only replaced from a member list that lists your own character; until a roster is
  known (first login with this version, or after choosing another community) nobody is dropped and nothing is
  sent over Battle.net; a HELLO received meanwhile is answered once it is known, if the friend belongs (tests).
- Compatibility (rule 8): no message changes; `members` is a new optional key (no migration, no schema bump: the
  cleanup needs the members, which a migration cannot know).
- Manual (VERIFY.md CF-89).
- Decided by Nico (2026-11-05): stop exchanging, not just hide; prune `presence` and `people`; the `members` key as
  the contract with the site.

### CF-86 A chat tab for the guild
Bug from Nico's in-game test of build 8 (develop 4d648b0): with the guild picked, the setup's chat step asks for the
community chat tab, but none is made. Cause: CF-83 made `CommunityChat.createTab` stop for a guild ("Your community is
a guild: guild chat already has its place in your chat windows."); the channel lookup is never reached (it would be
nil anyway: guild chat is the `GUILD` message group, not a `Community:<clubId>:<streamId>` channel). Builds on CF-83.
Touches: `src/adapters/ChatFrames.lua`, `src/services/CommunityChat.lua`, `src/ui/Setup.lua`, `src/ui/Settings.lua`,
`src/ui/SettingsWindow.lua`, `tests/mocks/wowapi.lua`, `tests/spec/Guild_spec.lua`, `.luacheckrc`, VERIFY.md,
ARCHITECTURE.md, CHANGELOG.md.
- With the guild picked, the setup's "Create chat tab", `/cf settings` "Create a community chat tab" and the
  once-per-character prompt make a chat tab named after the guild: `FCF_OpenNewWindow(name)`,
  `ChatFrame_RemoveAllMessageGroups(frame)`, then the `GUILD` message group (`ChatFrame_AddMessageGroup`, or
  `frame:AddMessageGroup`; unverified, V133). Without either no tab is opened ("Could not create the chat tab.")
  (tests).
- "Already has a tab" works for the guild tab (found by name, as for a community): the setup's chat step then says
  "This character has a <guild> chat tab." and offers no Create button; a second Create says it is there (tests).
- A character not in the selected guild gets "Select a community first ..." and no tab (tests).
- Guild chat only: no officer chat or guild achievements. No color, flash or sound for guild chat, and General keeps
  guild chat: with the guild picked, the chat color, Reset, flash, sound and "Keep community messages in General too"
  options are hidden (`/cf settings`, the Options panel, the setup's chat step) (tests).
- Other characters in the guild get the "Create a Community tab on this character too?" prompt once, with the line
  "A tab with only your guild chat." (CF-83 left it out) (tests).
- Communities work as before (the existing CF-25/CF-26 tests).
- Compatibility (rule 8): nothing stored or sent changes; `chatTab[guid]` is set as for a community.
- Manual (VERIFY.md CF-86, V133).
- Decided by Nico (2026-11-05): guild chat only; no color, flash or sound for guild chat (hide those options);
  "Keep community messages in General too" hidden for a guild; alts in the guild get the tab prompt.

### CF-85 No community: quiet Doomsday, a clean Dungeons tab
Two bugs Nico found at launch (v1.2.1) on a character with no community (none could be made, so none was selected).
Builds on CF-83: a character in a guild only is no longer passive. Touches: `src/services/Celebrate.lua`,
`src/services/DoomsdayAlerts.lua`, `src/ui/DungeonsTab.lua`, `src/ui/kit/Theme.lua`, `tests/spec/Celebrate_spec.lua`,
`tests/spec/DungeonsTab_spec.lua`, VERIFY.md, CHANGELOG.md.
- Doomsday is tracked quietly without a community this character is in (`CommunitySelection.active()` nil, the
  same gate as the chat lines): goals, points and feats are recorded, but no celebration banner, banner sound,
  friends' line or crown toast comes up. Each moment is still remembered as told, so picking a community or the
  guild later brings up nothing old; today's progress counts at once (tests). The settings' Preview still shows its
  sample banner (you asked for it).
- Dungeons tab, the window's empty states (no community, none selected, not a member): the list shows only its
  "Dungeons" title, none of its parts drawn from empty data (chips, No runs planned, In range for, Show all dungeons,
  No dungeon fits yet). While passive the right pane shows "Nothing planned yet" and the explainer only, no Ask now
  and no Copy website link. Wherever those buttons show, they sit below the text, measured with `GetStringHeight`
  (tests).
- The window background (`Theme` `panel`, also the toasts') is opaque: at 0.96 the game world's nameplates and
  frames showed faintly through it, best seen in the empty state (Nico's screenshot).
- Compatibility (rule 8): nothing stored or sent changes.
- Manual (VERIFY.md CF-85).
- Decided by Nico (2026-11-05): track quietly without a community; hide Ask now and Copy website link while passive;
  an opaque window background.

### CF-84 Automatic guild invites for alts
Builds on CF-83 (branch `feature/cf-83-guild`). When a member logs in on an alt that is not in the guild, the alt gets
into the guild with as little clicking as possible. Every member has invite rights (Nico's guild setting). Design by
Nico (2026-11-05). Touches: `src/core/GuildInvite.lua`, `src/adapters/Guild.lua`, `src/adapters/Vault.lua`,
`src/services/GuildInvites.lua`, `src/ui/GuildInvitePopup.lua`, `src/ui/Settings.lua`, `src/ui/SettingsWindow.lua`,
`src/Core.lua`, the new `CommunitiesForever_Vault/` folder, `.pkgmeta`, `tools/build.ps1`, `tools/FriendProbe/`,
`tests/spec/GuildInvite_spec.lua`, `tests/spec/GuildInvites_spec.lua`, VERIFY.md, SYNC.md, ARCHITECTURE.md,
CHANGELOG.md.
- **Not over Battle.net, never a custom channel:** the alt sends its request as an addon WHISPER
  (`C_ChatInfo.SendAddonMessage`, verified) to guild members; the guild code spreads on the guild's own addon channel
  (`"GUILD"`, V128). Own prefix `CFGuild`, single-part messages, `pv` 1: GKEY, GKEYHI, GINVREQ, GINVACK, GINVCLAIM
  (`docs/SYNC.md` "Guild invites").
- **The guild code:** never hardcoded or generated. A member types it in `/cf settings` in a masked field (V130) shown
  only while the guild is picked; the field is empty again after Enter and the code is never printed or shown (the
  line under the field gives only when it was set). 6 to 64 characters, no `|` or line breaks. An empty field changes
  nothing. Without a code the feature is off. It does not rotate when someone leaves.
- **Newest code wins:** by a version counter (see edge case 5 below), then the server time it was typed, then the
  code that sorts last, so all clients end on the same code.
- **Spread:** after login a member in the guild sends its code (GKEY) or asks (GKEYHI with `at` 0); a member with a
  newer code answers after a random 1 to 5 s unless another member's answer came first, at most once a minute.
- **Kept out of the upload:** the code and the member list live in `CommunitiesForeverVaultDB`, the SavedVariables of
  a companion folder `CommunitiesForever_Vault` shipped in the same package (`.pkgmeta` `move-folders`). Its file is
  `CommunitiesForever_Vault.lua`; the uploader reads only `CommunitiesForever.lua`, which gets nothing new. Without the
  vault folder the feature is off and the settings line says so.
- **Member list for alts:** a member's client keeps the picked guild's members `{ name, seen }` (last seen online) in
  the vault, at most 500, members who left dropped.
- **Alt:** 15 s after login, when the guild is picked, the character is in no guild and a code is known: whisper
  GINVREQ to the stored members, most recently online first (never your own characters), one at a time, at most 10
  per attempt, 6 s each; "No player named ..." (hidden by Transport's filter, V129) moves to the next at once. A
  GINVACK waits for the invite (60 s); a GINVFAIL moves on at once. No ack: again after 5 minutes, 3 attempts per
  login, then one chat line (at most once a day).
- **Proof, not the code:** the request carries a 64-bit digest of code, guild name, the requesting character's name
  and the request time (not a cryptographic hash). The member computes it with the name the game reports for the
  whisper and invites only that sender (only at the request of the character itself), only when it is not in the
  guild, within 5 minutes of the request time, once a minute per requester.
- **One handler:** the member that accepts a request whispers GINVACK to the alt and posts GINVCLAIM on the guild
  channel; others drop that request id.
- **Member invites:** `C_GuildInfo.Invite(name)` or `GuildInvite(name)` (guarded, V126). Confirmed by "You have
  invited ..." (`ERR_GUILD_INVITE_S`); when the game blocks it (`ADDON_ACTION_BLOCKED`/`_FORBIDDEN`) or no
  confirmation comes in 3 s, a small window "Invite <alt> (<friend>'s alt)?" with one Invite button; the rest of the
  session goes straight to that window.
- **Auto-accept:** `GUILD_INVITE_REQUEST` for the remembered guild within 3 minutes of our request: `AcceptGuild()`
  (guarded, V127); Blizzard's popup is hidden once the guild shows in the club list. Blocked: Blizzard's popup stays,
  with a chat line to click Accept. Any other invite is left alone.
- **Compatibility (rule 8):** nothing new in CommunitiesForeverDB (no migration, schema stays 2); the vault has its
  own `v = 1`. New message types only, on a new prefix that older versions never register, so they never see them.
- **Edge cases (asked by Nico, 2026-11-05):**
  1. **Another guild:** the account-wide pick only changes when none exists (CF-83's auto-pick); a bank alt in another
     guild leaves it alone and shows the community as not available; such an alt never asks (test).
  2. **Names with a space:** the alt whispers each member by the name the guild's member list gives
     (`C_Club.GetMemberInfo`); the member whispers back and invites with the sender's name exactly as `CHAT_MSG_ADDON`
     reported it (with "-Realm" when the game adds it). No name is built from parts. Which forms work: V131.
  3. **Another faction or realm:** members store the guild's faction and realm (`UnitFactionGroup`, `GetRealmName`)
     with the member list; an alt that differs, or whose request a member's game refuses as the other faction, stops
     for good with one chat line, remembered per character in the vault. An alt that can reach nobody (another
     ruleset) says "No member … answered" at most once a day.
  4. **No invite rights:** the member's client reads the game's refusal (`ERR_GUILD_PERMISSIONS` and others, V132) and
     whispers GINVFAIL; the alt asks the next member at once with a new request id. An acknowledged invite that never
     comes (popup ignored) moves on after 60 s.
  5. **Old codes coming back:** newest by a version counter `v` (one more than the highest known), not by time; time
     and code only break a tie of two codes set at the same version.
  6. **Removed characters:** a character that leaves the guild (kicked or left) is remembered in the vault
     (`removed[guid] = { name, at }`, at most 200) by every member that sees it go, and shared as GKICK on the guild
     channel. Members never invite it by themselves. Lifted when it is back in the guild list, or by a manual invite
     from that member ("You have invited <name>" that was not ours). A list that looks half loaded (more than 5 and a
     fifth gone at once) counts nobody as gone.
- FriendProbe: Test: guild invites (V126-V132).
- Manual (VERIFY.md CF-84, V126 to V132).
- Decided by Nico (2026-11-05): the vault folder and its global `CommunitiesForeverVaultDB` are OK; the code can only
  be replaced, never cleared; the code in plain text on the guild channel and the checksum (not the code) in requests
  are fine; the alt accepts any invite to the remembered guild within 3 minutes of its request; a one-time "action
  blocked" error on the member's side before the Invite button takes over is acceptable.

### CF-83 The guild as the community
On Forever no community can be created at launch (`docs/API-FINDINGS.md` "Creating a community"), so Nico's group
uses a guild for now and may move to a community once Blizzard fixes creation. The player can pick the guild as "the
community", next to the character communities. On Retail a guild is a club of type `Enum.ClubType.Guild` (2), so the
club path stays the one path: no guild-roster fallback. Unverified on Forever (V124, V125): the PR waits on that check.
Touches: `src/core/Clubs.lua`, `src/adapters/Community.lua`, `src/adapters/ChatFrames.lua`,
`src/adapters/missions/PlaceEvents.lua`, `src/services/CommunitySelection.lua`, `src/services/CommunityChat.lua`,
`src/services/Invites.lua`, `src/ui/Settings.lua`, `src/ui/Setup.lua`, `src/core/Format.lua`,
`tools/FriendProbe/`, `tests/spec/Guild_spec.lua`, VERIFY.md, API-FINDINGS.md, ARCHITECTURE.md, CHANGELOG.md.
- The picker (settings, setup) lists the guild and the character communities, never Battle.net communities. The
  guild type comes from `Enum.ClubType.Guild`, guarded, with 2 as the fallback (as `characterType()`).
- A character in a guild only is no longer passive; with nothing picked, the guild is picked as the only community.
- Switching guild, community, guild works without a reload and loses nothing: data stays keyed by character GUID and
  friend, only the member list changes (test).
- The wording stays "community". Only the texts that said guilds are not supported change.
- With the guild picked, own guild chat (`CHAT_MSG_GUILD`, guarded) counts for "Say something in the community chat"
  and "Chat in the community on 5 days". Same missions and texts; the Doomsday draw and pool do not change.
- With the guild picked, every invite-link option and text is hidden (no settings field, no How to join, no Post
  invite link), also on alts outside the guild (`settings.clubType` remembers the type).
- With the guild picked, the community chat features (color, tab flash and sound, Community tab and its prompt) leave
  guild chat alone; Create a community chat tab says why.
- Sync is unchanged: the hidden channel is named after the guild's name, members are whispered as before.
- FriendProbe: Test: guild (V124, V125) logs the guild club, its members, streams, the member events and guild chat.
- Compatibility (rule 8): one new optional local setting (`settings.clubType`, nil = unknown), no migration, schema
  stays 2; nothing new is sent. An older version with a guild `clubId` stored shows the community as not available
  on every character and keeps all data; picking a community there works as before.
- Manual (VERIFY.md CF-83, V124, V125).
- Decided by Nico (2026-11-05): with a guild picked, guild chat is left alone (no recolor, flash, sound or tab);
  a character that is only in a guild turns the addon on and auto-picks the guild.

### CF-82 The hidden launch probe (v1.2.1)
Friends answer FriendProbe's automatic checks without installing it: the addon runs them silently and the results
reach Nico in the saved file the uploader already sends to the site (an owner-only download there is a web story).
Touches: `src/core/Probe.lua`, `src/services/LaunchProbe.lua`, `src/services/LaunchProbeMissions.lua`, `src/Core.lua`
(`/cf fp`), `tests/spec/Probe_spec.lua`, `tests/spec/LaunchProbe_spec.lua`, VERIFY.md, CHANGELOG.md, ARCHITECTURE.md.
- Only the checks FriendProbe ticks by itself (`auto` in `tools/FriendProbe/Checklist.lua`): V35b, V55, V63, V70,
  V71, V73, V74, V76, V77, V78, V79, V80, V81, V82, V83, V84, V85, V86, V87, the Hunt, and the automatic mission and
  PvP checks (V90, V93 to V96, V98 to V117, V120 to V123).
- Left out, because they can show something or act: the combat-log registration (V75, Blizzard's popup), the
  self-whisper burst (V50b), whispers, invites and link tests (V47, V48, V51, V69), reloads (V67, V68), the jump hook
  (V118: a "blocked" popup is a possible answer), the Yes/No items and the hints for them.
- Results in `CommunitiesForeverDB.global.probe.results[<client>][<id>]` = `{ status, detail, at, build, later, log }`
  (client: `forever`, `retail` or `project <n>`, as FriendProbe). A pass stays; a later non-pass goes to `later`.
  `detail` at most 120 characters, `log` the last 3 lines of the item, the whole section at most 30 KB (oldest log
  lines go first). No raw chat text, no event log; player names only for the Hunt's victim and the killer (V120).
- Runs from login until 2026-11-18 00:00 UTC, then registers nothing and keeps the results.
- Invisible: nothing in chat, no window, sound or popup; post-hooks only; every handler in `pcall`, secret values
  logged as `secret`, missing APIs as `missing`. Cheap in combat: units throttled per GUID (60 s), auras skipped in
  combat and throttled, a check's scan stops once it passed.
- Hidden `/cf fp` (not in `/cf help`): one summary line and a dialog with the copyable report.
- Compatibility (rule 8): a new optional section, no migration, schema stays 2; older versions and the site ignore it.
  The section stays far below the site's upload limit (25 MiB).
- Manual (VERIFY.md): `/cf fp` after a play session on Forever shows ticks; the saved file has `probe`; nothing shows
  in chat or on screen while playing.

## E12 Crafting

### CF-38 Recipes: profession scan and profession links
Part A of the Recipes handoff (`docs/design/recipes-2026-11/HANDOFF.md`, its "Amendments" win; board RC07
`RC07Addon.dc.html`). The addon only scans and shows profession links: **no recipe list and no search in the addon**
(that is the website, Part C, and DoomBot, Part D). V60/V60b/V104 answered what it needs (API-FINDINGS "Forever launch
probe"); PR #63 (the old recipe-list story) is superseded.
- **Scan** (`core/Recipes.lua`, `adapters/TradeSkill.lua`, `services/RecipeTracker.lua`): on `TRADE_SKILL_SHOW`,
  `TRADE_SKILL_LIST_UPDATE`, `NEW_RECIPE_LEARNED` and `SKILL_LINES_CHANGED`, at most one scan per second (an event
  inside that second gets one later scan). Never a linked view (`IsTradeSkillLinked`), also not after it closed.
  - Per character: `recipes = { [recipeID] = itemID }`, the learned recipes of **all** professions
    (`GetAllRecipeIDs` gives every profession at once), itemID from `GetRecipeOutputItemData(id).itemID`, 0 for none;
    `recipesAt` the time of the scan. A scan replaces the set (it is complete), never on an empty or failed read
    (CF-100). `recipeLines = { [recipeID] = skillLineID }` only where `GetTradeSkillLineForRecipe` answers (V137;
    CF-105: it answers on Forever, the parent line, e.g. 185 for Cooking). Not readable on Forever (V60c): how many a
    character can make now (`numAvailable`), a recipe's cooldown (`GetRecipeCooldown`) and where an unlearned recipe
    is learned (`GetRecipeSourceText`); the addon stores none of them.
  - Per profession (only the open one; window open = `TRADE_SKILL_SHOW` until `TRADE_SKILL_CLOSE`): `link` (the
    `trade:` part of `GetTradeSkillListLink()`), `linkType` (`short` for 4 colon-separated fields, else `long`),
    `spec` (the specialisation's name, `IsSpellKnown` on the Vanilla specialisation spells, V136), `scannedAt`. Never
    another profession's fields. Mining, Herbalism, Skinning and Fishing: skill only, no link.
  - A snapshot refresh (`Snapshot.apply`) keeps these fields (`Recipes.carry`).
- **Sync** (SYNC.md, within `pv` 1): `link`, `linkType`, `scannedAt`, `spec` travel with the character's professions.
  The learned recipes travel too (Nico, 2026-11-06), so friends without the uploader still reach the site: an
  append-only list per character (`recipeOrder`, `recipesBase`); a REQ says how many each character's list the asker
  holds (`rc`), the RECORD (own or relayed) carries only the tail after it (`recipesFrom`, `recipeIds`,
  `recipeItems`, `recipeCount`), and the receiver appends it when its count and base match, else keeps what it has.
  An unlearned recipe starts a new base (the full list again); unlearn and relearn are otherwise not tracked. A new
  recipe, link, link type or spec bumps the version; a new `scannedAt` alone does not. Received fields are cleaned
  (`Recipes.clean`).
- **Friends tab** (RC07): a crafting profession row is name, skill bar, skill, then `[Tailoring]` in Blizzard's link
  colour. Click: `SetItemRef` with the stored link (Blizzard's window with their recipes). Shift-click: the link into
  the chat box (`ChatEdit_InsertLink`, or `ChatFrame_OpenChat` without an open box, V134). Tooltip: "Mira’s
  Tailoring" / "Click: open in game" / "Shift-click: link in chat". Without a link: a dim "not scanned", tooltip
  "Opens once Mira opens Cooking in game". Gathering and Fishing: nothing.
- Not built: the dimmed offline state ("Opens while Mira is online"). Only if the offline test (VERIFY.md CF-38)
  shows a friend's link fails while they are offline.
- Compatibility (rule 8): only new optional fields, no migration, schema stays 2. An older client stores the new
  profession and recipe fields it receives (strings without `|`), ignores them and may relay them as they came; a
  relayed tail only applies where it fits. It sends no `rc`, so it always gets full lists, and no recipes, so its
  characters show "not scanned" and a stored list stays. Stored data of older versions has no link and no recipes:
  "not scanned" until the profession is opened once.
- Unit tests: scan to stored shape, never wiping other professions, empty read, the throttle, link type, cleaning,
  the learn order and tails, the Friends tab cells, click and Shift-click (`Recipes_spec`, `RecipeTracking_spec`), the
  full list then the tail between friends and through a relay (`RecipeSync_spec`).
- Manual: VERIFY.md CF-38 (with the offline and the old-link test) and V134 to V136 (V137 answered, CF-105).

## E15 Doomsday (decided with Nico, 2026-10-28)
Daily and weekly goals, points per track, a streak and a crown, feats and a ladder, in the game, on the site (web E8) and in Discord (bot "Doomsday"). **`docs/DOOMSDAY.md` is the one description of the rules**; read it first. It replaces the three workshop designs (milestones, PvP ladder, dailies and weeklies; their PRs were closed unmerged).

Boards in `docs/design/doomsday-2026-10/`:
- `DD07AddonToday.dc.html`: Today, Week, chat lines, toast
- `DD08AddonBoard.dc.html`: Board, Ladder, Feats
- `AddonKit-doomsday.dc.html`: what WoW supports for Doomsday

The site's and the bot's boards are in their repos. Where a board and `DOOMSDAY.md` disagree, `DOOMSDAY.md` wins: the reset is 19:00 (a setting), goals are computed (not delivered through `Runs.lua`), and the crown gives no points.

None of the new APIs are verified on Forever. Each is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step (V73 to V86), and is checked at launch (from 2026-11-05). A guarded API that is missing leaves its field out (nil). A goal that needs it stays out of the pool, and the site shows no card or feat for it.

Compatibility (rule 8): only new optional fields in `chars.*`, feed entries and RECORD, within `pv` 1. Older clients ignore them, relay what they keep, and a relayed record without them changes nothing (nil = unknown). New stored fields are optional (nil-safe), so no migration unless a field changes meaning. Friends on an older addon show "no Doomsday data yet", never 0 points as if known.

Status (2026-10-29): CF-52, CF-53, CF-55 (a and b), CF-56, CF-57 (a and b) and CF-58 are done (`docs/STORIES-COMPLETED.md`). Open: CF-54, the probe run at launch, which decides the victim fields, the Hunt and the next pool version (`DOOMSDAY.md` "The algorithm, exactly"). The unverified APIs are V73 to V86 in `VERIFY.md`.

### CF-54 FriendProbe: what Forever tells about a kill, and realm time
Probe written (PR #98): `/fp pvp` and the V77/V78 and V79–V83 lines in `/fp start`. The story stays open until the launch run is in `API-FINDINGS.md` (`VERIFY.md` "CF-54").
Answers V73 to V78 in one run at launch. The results go to `docs/API-FINDINGS.md` and decide which fields CF-55 fills and which goals `docs/DOOMSDAY.md` can draw.
- `/fp pvp` switches kill logging on (it stays on after `/reload`; `/fp pvp off` stops it):
  - every `CHAT_MSG_COMBAT_HONOR_GAIN` with all its arguments, and whether the game's format string (`COMBAT_LOG_HONORGAIN` or the one that exists) gives the victim's name and rank
  - `PLAYER_PVP_KILLS_CHANGED` with the counters from `GetPVPSessionStats` and `GetPVPLifetimeStats`
  - for target, mouseover and each nameplate (`NAME_PLATE_UNIT_ADDED`) of an enemy player: `UnitName`, `UnitLevel` (`-1` on a skull), `UnitClass`, `UnitRace`, `UnitPVPRank` or the API that exists, and `UnitGUID`
  - whether `COMBAT_LOG_EVENT_UNFILTERED` can be registered, and if so each `PARTY_KILL` (with `GetPlayerInfoByGUID` on the victim's GUID) and the last damage source before `PLAYER_DEAD` (the killer's name)
  - `IsInGroup()` and `GetInstanceInfo()` type at each kill
- `/fp start` also logs `GetCurrentRegion()` (V77), and `GetGameTime()` next to `GetServerTime()` with the offset it gives (V78).
- Every call is guarded; a missing one logs `missing`, a secret value logs `secret`.
- The finding names which victim fields are readable at the moment of the honor message: from the message itself, or only from a target, mouseover or nameplate seen before. It decides whether the Hunt stays (`DOOMSDAY.md`, "The Hunt").
- If the killer's name is readable, propose stories for a Wanted poster (the enemy who killed us most this week, a bounty on them) and a revenge kill (killing your killer within 10 minutes).

## E18 The Doomsday mission catalogue (approved by Nico, 2026-11-03)
`docs/DOOMSDAY-CATALOGUE.md` is the approved list of dailies: 118 PvE dailies in 15 categories and 4 Skirmish goals,
numbered 1 to 125 (#16, #27 and #94 removed), each with its id, label, points (1, 3 or 5), "done when", data source
and fallback. The weekly catalogue (`docs/DOOMSDAY-WEEKLY-CATALOGUE.md`, #177: 50 weeklies) and the
PvP catalogue (`docs/DOOMSDAY-PVP-CATALOGUE.md`, #178: 57 Skirmish and 43 Bounty goals) were approved by Nico on
2026-11-03; CF-79 puts them in code, and the tracker lanes cover their missions too. Read the catalogue first;
where a story and a catalogue disagree on a mission, the catalogue wins. The site's side is in
`docs/WEB-STORIES-DOOMSDAY-CATALOGUE.md` (for the web repo).

Compatibility (rule 8), for all of E18:
- Stored data: only new optional local facts (`self.doomsday`, as CF-56) and two new per-character sets (zones and
  dungeons seen, CF-72 and CF-73), nil = unknown. No migration: nothing changes meaning.
- Messages: nothing new is sent. Goals travel as today (`goals.days[n].done` ids, `goals.pool`). An older client keeps
  ids it doesn't know (`Goals.clean`), and shows them by id until it updates.
- The draw depends on `POOL_VERSION`: a friend on an older addon draws the older pool. That is the existing rule
  (`goals.pool` is recorded); the release notes ask friends to update on release day.

### Building in parallel
Nico wants several workers on E18 at once. The stories are cut so that, after CF-70, workers on different lanes never
edit the same file. Each story lists the files it touches and what it waits for.

| Lane | Stories, in order | Files only this lane edits |
|---|---|---|
| Start (one worker) | CF-70 | sets up everything the other lanes share (below) |
| Rules | CF-69, then CF-78, then CF-79 (after the reviews) | `src/core/Doomsday.lua`, `src/core/DoomsdayView.lua`, `src/core/Pvp.lua`, `src/ui/DoomsdayTab.lua`, `src/ui/CelebrationBanner.lua`, `docs/DOOMSDAY.md`, `tests/fixtures/doomsday-cases.json` and their specs |
| Quests | CF-71 | `src/core/missions/Quests.lua`, `src/adapters/missions/QuestEvents.lua`, `src/core/Quests.lua`, `src/adapters/SelfInfo.lua` (the quest log fields), `tests/spec/MissionsQuests_spec.lua`, `tests/fixtures/missions/quests.json` |
| Records | CF-72 | `src/core/missions/Records.lua`, `src/adapters/missions/RecordEvents.lua`, `tests/spec/MissionsRecords_spec.lua`, `tests/fixtures/missions/records.json` |
| Friends and places | CF-73 | `src/core/missions/Places.lua`, `src/adapters/missions/PlaceEvents.lua`, `tests/spec/MissionsPlaces_spec.lua`, `tests/fixtures/missions/places.json` |
| Launch checks | CF-74, CF-75, CF-76 (after the launch run, each in its own module files, `missions/Extended`, `missions/Items`, `missions/World`) | as the lanes above, with their own module, adapter, spec and fixture |
| PvP fights | CF-80 (after the launch run) | `src/core/missions/Fights.lua`, `src/adapters/missions/FightEvents.lua`, `tests/spec/MissionsFights_spec.lua`, `tests/fixtures/missions/fights.json` |
| PvP extras | CF-81 (after the launch run) | `src/core/missions/Battle.lua`, `src/adapters/missions/BattleEvents.lua`, `tests/spec/MissionsBattle_spec.lua`, `tests/fixtures/missions/battle.json` |
| End (one worker) | CF-77 | `src/core/Doomsday.lua` (`POOL_VERSION`, `since`, the draw), `tests/fixtures/doomsday-cases.json`, `docs/DOOMSDAY.md` |

Shared by everyone, append only: `VERIFY.md` (each story adds its own section under "Manual test steps per story")
and `CHANGELOG.md` (each story adds its line under "Unreleased"). A merge conflict there is resolved by keeping both.
`CommunitiesForever.toc` is edited only by CF-70 (it lists every module file up front), so the lanes don't touch it.

**Weeklies:** each tracker lane also registers the progress of the weeklies that read its data (the weekly
catalogue's "Data" column: `w.groupQuests3` in CF-71, `w.levels5` in CF-72, `w.roam10` in CF-73, and so on). A
progress function registered before CF-79 lists the weekly is harmless, so the lanes don't wait for CF-79.

Dependencies: CF-70 before everything. CF-69 → CF-78 → CF-79 in the rules lane. CF-71, CF-72, CF-73 need only CF-70
and run side by side, and alongside the rules lane. CF-74 to CF-76 need CF-70 and their launch checks
(`docs/API-FINDINGS.md`); CF-80 and CF-81 the same. CF-77 needs CF-69 and the tracker stories it puts in the pool,
and the site's WEB-80.

### CF-70 The catalogue in code, and the mission modules (first, one worker)
Touches: `src/core/Doomsday.lua`, `src/core/Goals.lua`, `src/services/DoomsdayTracker.lua`, `CommunitiesForever.toc`,
`docs/DOOMSDAY.md` (the goal tables and short labels), `tests/fixtures/doomsday-cases.json` (`pools`), the stub files
below, and their specs. Waits for: nothing.
- `Doomsday.GOALS` gets every daily catalogue mission in catalogue order within its slot, with `id`, `slot`,
  `category` (the 15 categories), `text` (the catalogue's title), `points` (the catalogue's; used by CF-69), `can` and
  `fallback`. New goals have no `since` (they wait for data), so pool version 1's draw doesn't change.
- Moved categories: `d.groupFriend` and `d.trade` to social, `d.rare` to loot, `d.fish20` to fishing (none of them
  in pool version 1).
- `Doomsday.SHORT_LABELS` gets every label (at most 10 characters; a spec checks length and uniqueness per slot).
- The situation (`Goals.situation`) gets the new optional fields: `below20`, `hasCooking`, `hasFirstAid`,
  `hasGathering`, `riding`, `friends`, `canBuff`. A missing field never swaps.
- **Mission modules**, so the tracker lanes never edit a shared file:
  - `Goals.registerKind(kind, fn)`: a module adds its own observation kinds to `Goals.observe` (facts stay in the
    day's and week's facts table under the module's own key, e.g. `facts.quests2`).
  - `Doomsday.registerProgress(id, fn)`: a module adds the progress function of its missions; `Doomsday.progress`
    looks there after its own table.
  - `DoomsdayTracker` forwards every module's internal message (`CF_MISSION_EVENT`, reason = the kind) to
    `Goals.observe`, with today's and this week's facts.
  - Stub files, listed in the TOC now, each a module that registers nothing yet: `src/core/missions/Quests.lua`,
    `Records.lua`, `Places.lua`, `Extended.lua`, `Items.lua`, `World.lua`, `Fights.lua`, `Battle.lua`, and
    `src/adapters/missions/QuestEvents.lua`, `RecordEvents.lua`, `PlaceEvents.lua`, `ExtendedEvents.lua`,
    `ItemEvents.lua`, `WorldEvents.lua`, `FightEvents.lua`, `BattleEvents.lua`; empty fixture
    files `tests/fixtures/missions/*.json` (addon-only progress cases: the site never computes progress).
- `docs/DOOMSDAY.md`: the dailies and Skirmish tables list the new goals with "Data" (the story that tracks them).
- Golden cases: `pools` lists the catalogue; the draws of pool version 1 are unchanged.

### CF-69 Points per mission (rule change; rules lane)
Touches: `src/core/Doomsday.lua` (points, ladder), `src/core/DoomsdayView.lua`, `src/ui/DoomsdayTab.lua`,
`src/ui/CelebrationBanner.lua`, `docs/DOOMSDAY.md` "Points", `tests/fixtures/doomsday-cases.json` (`pointsPerGoal`),
their specs. Waits for: CF-70.
- Nico, 2026-11-03: every goal scores by size: dailies and Skirmish 1, 3 or 5; weeklies and Bounty 5, 10 or 15. A
  day's total varies with the draw.
- `docs/DOOMSDAY.md` "Points": the flat "5 per daily, 15 per weekly" becomes "each goal's points, from the pool"; a
  day keeps the points of the pool version it was drawn in.
- `Doomsday.pointsFor(id, pool)`: pool version 1 keeps 5 (dailies, Skirmish) and 15 (weeklies, Bounty); from pool
  version 2 the goal's `points`. Nil-safe: an unknown id scores the old flat value.
- Points of a day or week come from its `done` ids and the pool version recorded with it (`goals.pool`), on both
  sides. The crown, crossing out and the streak don't change: they count goals, not points.
- The sizes of the pool-1 Skirmish and Bounty goals and of the weeklies come from the weekly and PvP catalogues once
  Nico approved them (#177, #178); until then they keep 5 and 15.
- Golden cases: `pointsPerGoal` (a day of pool 1, a day of pool 2 with 1, 3 and 5 point goals, an unknown id), copied
  unchanged by the site (WEB-80).
- The Week, Board and Ladder show the new totals; the day-complete banner shows the day's points.
- Manual (VERIFY.md): a day with a 1-point goal shows "+1" on its banner and in the week's total.

### CF-78 Only a real fight ends PvP Virgin (rule change; rules lane)
Touches: `src/core/Pvp.lua` (`Pvp.virgin`), `src/core/DoomsdayView.lua` and `src/core/Doomsday.lua` (the ladder's
`killedEver`), `docs/DOOMSDAY.md` "Two tracks", `tests/fixtures/doomsday-cases.json` (`ladder`), their specs. Waits
for: CF-69 (same files).
- Nico, 2026-11-03 (#178): **a PvP Virgin stays one until a real fight: an honorable kill, a duel, or a finished
  battleground.** PvP points from goals that need no fight (emotes, the PvP flag) count on the PvP track but don't end
  PvP Virgin status.
- `DOOMSDAY.md`: "any PvP point or any kill ends it" becomes "an honorable kill, a duel or a finished battleground on
  any character ends it; PvP points from goals without a fight don't".
- `Pvp.virgin` and the ladder's `killedEver` (renamed `foughtEver`, the old name read as a fallback) also count a
  finished battleground run (`runs`, `kind = "pvp"`, CF-23).
- Golden `ladder` cases: a friend with only taunt points stays unranked; a friend with one battleground is ranked.
- Manual: a friend who only flexed shows as Conscientious Objector with the points; after a duel, ranked.

### CF-71 Quest details (verified APIs; quests lane)
Touches: `src/core/missions/Quests.lua`, `src/adapters/missions/QuestEvents.lua`, `src/core/Quests.lua` and
`src/adapters/SelfInfo.lua` (the quest log's new fields), `tests/spec/MissionsQuests_spec.lua`,
`tests/fixtures/missions/quests.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70.
Missions: `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.dungeonQuest`, `d.questBurst`, `d.accept5`,
`d.questTogether` (catalogue #6 to #10, #23, #49).
- The stored quest log keeps `level` and `suggestedGroup` from `C_QuestLog.GetInfo` next to `area` and `dungeon` (V23,
  V31); optional fields, nil on records of older versions.
- At `QUEST_TURNED_IN` (questID, as CF-22) the module looks the quest up in the stored log of that character and
  observes `{ kind = "questDone", level, charLevel, group, area, dungeon, grouped }` with the time.
- `QUEST_ACCEPTED`: distinct quest IDs accepted per Doomsday day.
- `grouped`: a friend's community character in the group at that moment (CF-53's groups).
- Progress functions registered per mission; progress cases in its fixture file; manual steps in VERIFY.md.

### CF-72 Levels, play and dungeons on recorded data (verified APIs; records lane)
Touches: `src/core/missions/Records.lua`, `src/adapters/missions/RecordEvents.lua`,
`tests/spec/MissionsRecords_spec.lua`, `tests/fixtures/missions/records.json`, VERIFY.md, CHANGELOG.md. Waits for:
CF-70.
Missions: `d.levels2`, `d.lowbie`, `d.dingDungeon`, `d.dingFriend`, `d.dungeons2`, `d.speedRun`, `d.newDungeon`,
`d.chars3`, `d.switchUp`, `d.dustOff`, `d.cookSkill5`, `d.fishSkill5`, `d.aidSkill5`.
- Level-ups observe the instance type (`GetInstanceInfo`, V35) and whether a friend's community character is grouped.
- Party runs: duration from `startedAt` and `lastAt`; a per-character set of dungeon names (local, in
  `self.doomsday.dungeonsSeen[guid]`, seeded from the stored feed's runs) for `d.newDungeon`.
- Skill points per skill line (185 Cooking, 356 Fishing, 129 First Aid) from the professions the addon stores.
- `d.switchUp` and `d.dustOff` from the days' facts and `lastPlayed`.
- Progress cases in its fixture file; manual steps in VERIFY.md.

### CF-73 Friends and places (verified APIs; friends and places lane)
Touches: `src/core/missions/Places.lua`, `src/adapters/missions/PlaceEvents.lua`, `tests/spec/MissionsPlaces_spec.lua`,
`tests/fixtures/missions/places.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70.
Missions: `d.sameZone`, `d.online3`, `d.carry`, `d.chatHello`, `d.roam4`, `d.newZone`, `d.crossSea`, `d.nostalgia`,
`d.daredevil`.
- Friends: `C_Club.GetMemberInfo` zone and presence (V17, V18) for "same zone" and "online at once"; party members'
  levels for `d.carry`; own messages in the selected community's channel by sender GUID (V38).
- Places: `ZONE_CHANGED_NEW_AREA` with `GetRealZoneText` and the continent from `GetInstanceInfo` (V35); a
  per-character zone set (local, `self.doomsday.zonesSeen[guid]`, seeded from the feed's quest zones); zone level
  ranges from Group Finder's "Quests & Zones" activities (V46), matched to the zone name. A zone without a match never
  counts.
- Progress cases in its fixture file; manual steps in VERIFY.md.

### CF-74 Existing trackers, extended (after their launch checks)
Touches: `src/core/missions/Extended.lua`, `src/adapters/missions/ExtendedEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. It reads the CF-52, CF-53, CF-55b and CF-56 facts and doesn't edit their trackers. Waits for: CF-70 and
the launch checks below.
Missions: `d.fish50`, `d.fishZones`, `d.fishFriend`, `d.fishNight`, `d.nightOwl`, `d.session1h`, `d.deathless`,
`d.cleanRun`, `d.profit`, `d.green5`, `d.reward`, `d.craft5`, `d.feedFriend`, `d.discover1`, `d.discover3`,
`p.punchUp5`, `p.punchDown5`, and the existing `d.cleanLevel`, `d.groupFriend`, `d.trade`, `d.rare`, `d.earlyBird`.
- Each mission joins the pool only once its check passed at launch: V84 (fishing), V85 (trades), V83 (loot), V86
  (discoveries), V73 and V74 (kills), and the CF-52 and CF-53 story steps (deaths, sessions, gold, groups).

### CF-75 Probe-gated: items, crafting, cooking, First Aid, care
Touches: `src/core/missions/Items.lua`, `src/adapters/missions/ItemEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. Waits for: CF-70 and the V checks named below.
Missions: the cooking, firstaid and care missions and `d.gather10`, `d.newRecipe`, `d.craftGreen`, `d.coins10`,
`d.equipNew` (and the weekly `w.blueGear`), `d.treasure`, `d.jump100` (catalogue "needs probe" rows with V95, V104
to V106, V110, V112, V113, V116 to V119).
- Built per mission once its V passed (`docs/API-FINDINGS.md`); a mission whose V failed is marked retired in the
  catalogue and stays out.
- The campfire missions take their spell ID, buff and item count from V119; their "done when" is rewritten from the
  finding before they are built.

### CF-76 Probe-gated: combat, travel, economy, social
Touches: `src/core/missions/World.lua`, `src/adapters/missions/WorldEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. Waits for: CF-70 and the V checks named below.
Missions: the combat, travel and economy missions and `d.whisper`, `d.wave`, `d.groupPic`, `d.places10`, `d.swim`,
`p.flex`, `p.boo` (catalogue "needs probe" rows with V90, V93, V94, V96, V98 to V103, V107 to V109, V111, V114, V115).
- As CF-75: built per mission once its V passed; failed ones retired.
- Kills from the XP message (V90) match the creature last seen by target, mouseover or nameplate (V93), as the Hunt
  does for players.

### CF-79 The weekly and PvP catalogues in code (rules lane)
Touches: `src/core/Doomsday.lua` (the weekly, Skirmish and Bounty entries and labels), `docs/DOOMSDAY.md`,
`tests/fixtures/doomsday-cases.json` (`pools`). Waits for: CF-78 (same files). Both catalogues are approved (#177,
#178).
- As CF-70 for the weeklies and the PvP goals: every approved mission with category, points, `can` and fallback, no
  `since`. The existing pool-1 Skirmish and Bounty goals get the PvP catalogue's sizes (from pool version 2).
- `needs` per PvP goal (kill, duel, bg, emote, flag), so CF-78's rule can tell fight goals from the rest.
- Weekly #8 is the new `w.blueGear` (a blue or better item new to the character; its tracker is CF-75's V113 gear
  tracker). `w.ilvl3` keeps its id and meaning and is marked retired from pool version 2 (`retired = 2`): it stays in
  pool version 1's draw, golden cases unchanged.
- Their trackers are the lanes' (weeklies) and CF-80 and CF-81 (PvP).

### CF-80 PvP fights: kills, deaths, duels, battlegrounds (PvP fights lane)
Touches: `src/core/missions/Fights.lua`, `src/adapters/missions/FightEvents.lua`, `tests/spec/MissionsFights_spec.lua`,
`tests/fixtures/missions/fights.json`, VERIFY.md, CHANGELOG.md. It reads the CF-55b kills (`pvpKills`), the CF-52
deaths and duels, the CF-23 battleground runs, CF-53's groups and the own rank, and doesn't edit their trackers. Waits
for: CF-70 and the launch checks V73, V74, V76, V79, V35b.
Missions: the PvP catalogue's goals with "existing tracker" data (world kills, targets, streaks, teamwork, duels and
the battleground runs; `b.skirmish5` from the Skirmish `done`).
- Kills are counted as `DOOMSDAY.md` "Kill points" counts them; battleground kills only for the battleground goals.
- First blood compares the own kill's time with the friends' kills known at that moment; a later sync doesn't undo it.
- Each goal joins the pool only once its check passed.

### CF-81 PvP extras: taunts, the flag, battleground scores, zones, the killer (PvP extras lane)
Touches: `src/core/missions/Battle.lua`, `src/adapters/missions/BattleEvents.lua`, `tests/spec/MissionsBattle_spec.lua`,
`tests/fixtures/missions/battle.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70 and the launch checks V108, V120,
V121, V122, V123 (FriendProbe, merged in #179).
Missions: the PvP catalogue's "needs probe" goals (taunts, the flag, battleground objectives and the top killer,
enemy and home territory, revenge and avenge).
- The killer's name (V120) is kept with the own death as a new optional local fact (nil = unknown), never sent.
- Built per goal once its V passed; a goal whose V failed is retired in the catalogue.

### CF-77 Pool version 2 (end, one worker)
Touches: `src/core/Doomsday.lua` (`POOL_VERSION`, `since`, the draw), `tests/fixtures/doomsday-cases.json` (`draws`),
`docs/DOOMSDAY.md` "The algorithm, exactly", VERIFY.md, CHANGELOG.md. Waits for: CF-69, CF-78, the tracker stories
whose missions join, and WEB-80 on the site (same release).
- `Doomsday.POOL_VERSION = 2`; `since = 2` on the missions CF-71 to CF-73 built and on those of CF-74 whose checks
  passed by then; the points of CF-69 count from this version.
- The 15 categories in the draw; golden `draws` cases for days and weeks of pool version 2 from its first day (the
  release day), and the existing pool-1 cases unchanged.
- **The weekly draw takes 3 different categories**, as the dailies do (Nico, 2026-11-03, #177): every weekly gets a
  category, and from pool version 2 slot k takes `candidates[pick(week, 20 + k, #candidates)]` from the pool's
  weeklies whose category isn't taken yet and that weren't in last week's; if none is left, last week's are allowed
  again (categories still differ). Weeks of pool version 1 keep the draw without categories. Golden `draws` cases for
  weeks of both pool versions.
- The site ships its copy of pool version 2 in the same release (WEB-80); the release notes ask friends to update.
- Later bumps (3, 4, ...) add the missions of CF-74 to CF-76, CF-80 and CF-81 (and the weeklies and PvP goals of
  CF-79) as their checks pass, one bump per release,
  with golden cases each.
- Manual (VERIFY.md): on the release day, two friends on the new version see the same 3 dailies; a friend on the old
  version sees pool version 1's.
