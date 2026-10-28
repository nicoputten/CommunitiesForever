# Completed stories

Done (merged) stories, moved here from `docs/STORIES.md`, which holds only open stories. Kept for their decisions and acceptance criteria. Open in-game checks for these stories stay in `VERIFY.md`.

Build order was: CF-01, 03, 05, 06, 07, 08, 12 (usable solo), 09, 10, 11 (sync), 17, 20, 21, 14, 15, 16, 18, 19, 04, 02 (part 1), 22, 25, 26, 23, 24, 27, 28 (parts 1, 2a, 2b), 02 (part 2), 29, 30, 32, 33, 34, 35, 36, 37, 31, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48. (CF-13 dropped.)

## E0 Foundation

### CF-01 Scaffold and tooling
- Repo layout as in ARCHITECTURE.md. TOC Interface 16001, SavedVariables `CommunitiesForeverDB`, loads all files in order via TOC and `embeds.xml`.
- `.pkgmeta` with externals for all listed libraries; `Libs/` gitignored; `tools/` and `tests/` excluded from the package.
- `busted` runs with `tests/mocks/wowapi.lua`; one sample spec passes.
- `.luacheckrc` with WoW globals used by adapters/UI; `src/core` configured to allow no WoW globals.
- GitHub Action runs busted and luacheck on push and PR.
- MIT LICENSE.
- Manual: addon loads in Forever without errors; `/cf version` prints the version.

### CF-02 Release pipeline
- Pushing a git tag `v*` runs the BigWigs packager and uploads to CurseForge (Forever flavor) using the `CF_API_TOKEN` secret. CurseForge project ID in the TOC (`## X-Curse-Project-ID`).
- Part 2 (built 2026-10-19, `.github/workflows/release.yml`): a tag `v*` runs lint and tests, then `BigWigsMods/packager@v2` with the `CF_API_TOKEN` secret (an **author** API token from https://authors.curseforge.com/#/settings/api-tokens, not a key from console.curseforge.com). The packager detects interface 16001 as the Forever game type. Release type from the tag: `v1.0.0` release, `v1.0.0-beta1` beta, `v1.0.0-alpha1` alpha. The workflow fails when the secret is missing, so a release never silently skips the upload. Gitflow: merge `develop` into `main`, then tag on `main`.
- Untagged pushes produce no release.
- Done in part 1 (PR #21, merged without the token): project ID 1752013 in the TOC, zip with forward-slash paths, campfire logo in `docs/logo/`, and the released files contain no personal info. Author `Vestras` (TOC and LICENSE), generic examples in `src` comments, hand-written `CHANGELOG.md` (`manual-changelog` in `.pkgmeta`) instead of a changelog built from commit messages. `tests/spec/Release_spec.lua` fails on banned names in the released files. The repo stays private; its history is unchanged.
- Manual: install via the CurseForge app; publishing a new tag delivers an update.
- The package contains only the addon: `.pkgmeta` ignores tests, tools, docs, `VERIFY.md`, `CLAUDE.md` and the CI config. Check: unzip the built package and list its files.
- Released (2026-10-19 to 10-21): v0.2.0-beta1 was rejected by CurseForge ("General error processing file"): LibDeflate's `1.0.2-release` tag ships `docs/topics/README.md.html` and `readme.md.html`, a case-only path clash; `.pkgmeta` now ignores `Libs/LibDeflate/docs` (PR #40). v0.2.0-beta2 and v0.3.0-beta1 were accepted.
- Decided after part 2: CurseForge (and Wago) show only the tag's `## <tag>` section of `CHANGELOG.md` (`tools/release-notes.lua` writes `RELEASE_NOTES.md`; a tag without a section stops the release, PR #41). The rule is in CLAUDE.md: changes collect under `## Unreleased`, renamed to the tag when preparing a release; a rejected tag's notes move to the next tag.
- Wago Addons as a second target for WowUp (PR #43): `## X-Wago-ID: b6XyqbKp` in the TOC, the `WAGO_API_TOKEN` secret, and a manual workflow run that re-releases an existing tag (optionally to Wago only; used for v0.2.0-beta2). `Release_spec` checks that the workflow's Wago ID matches the TOC.

## E1 Own data

### CF-03 Self snapshot
- On login, current character stored in `self.chars[guid]` with all `Char` fields.
- Updates on level up, profession skill change, and equipment change (ilvl, debounced 2 s).
- `self.version` bumps only on a real change of a synced field (unit test: identical snapshot, no bump).
- If `GetAverageItemLevel` is missing, `ilvl = nil`, no error.
- `self.battleTag` from `BNGetInfo()` (2nd return).
- Manual: level up / train a profession / change gear, then `/dump` the DB shows updates.

### CF-04 Own display name
- Settings field "Display name" stored in `self.displayName`; changing it bumps the version and triggers a debounced HELLO.
- Decided in CF-04: plain text only, up to 24 characters (WoW escape sequences removed); empty falls back to the BattleTag name part. Received display names and all text in received characters (names, professions, talents) are cleaned the same way, so a modified addon cannot inject colors, textures or links.

## E2 Community

### CF-05 Community selection
- AceConfig dropdown lists subscribed **character** communities by name (decided in CF-05: guild and Battle.net communities excluded, since membership must be per character with GUIDs). Also in the Blizzard settings panel; `/cf settings` opens it.
- Selection stored in `settings.clubId`, survives reload.
- Auto-select (added in CF-12 feedback): with nothing selected, the only character community is selected, or the one you just joined; a chat line says which.
- ~~If the stored club no longer exists: selection cleared~~ Changed in CF-17: membership is per character but the selection is account-wide, so the selection is never cleared automatically. On a character that is not a member (or after leaving the community) the window says: "Your account has characters in <community>, but <character> isn't a member, so it can't be shown here." The community name is remembered (`settings.clubName`). Sync keeps working on that character.

### CF-06 Member tracking
- Adapter exposes `members[guid] = { name, classID, level, zone, presence, raceID, faction }` for the selected club.
- Calls `FocusMembers` on selection; refreshes on CLUB_MEMBERS_UPDATED, CLUB_MEMBER_ADDED, CLUB_MEMBER_REMOVED, CLUB_MEMBER_PRESENCE_UPDATED, CLUB_REMOVED (debounced 1 s; event names guarded).
- Manual: invite or kick a character; `/cf members` (and later the main window) updates within a few seconds.

## E3 Presence and linking

### CF-07 BNet presence tracking
- Tracks friends' game accounts where `clientProgram == BNET_CLIENT_WOW` and `wowProjectID == WOW_PROJECT_ID`, including friends with multiple game accounts.
- Maintains `gameAccountID -> battleTag` map (session only) and writes `presence[guid] = { battleTag, lastSeen }` when a friend is seen on a character.
- Refresh on BN_FRIEND_INFO_CHANGED, BN_FRIEND_ACCOUNT_ONLINE, BN_FRIEND_ACCOUNT_OFFLINE, BN_CONNECTED (debounced).
- Emits internal events: friend online in Forever, friend switched character, friend offline. Friends already online at login are the baseline and produce no "online" event (decided in CF-07).
- Manual: `/cf friends` shows friends in Forever and presence links.

### CF-08 Linker (pure)
- Input: members, current friends (BattleTag set), people, presence, self. Output view model `{ people = [ {bt, displayName, online, currentChar, chars=[...]} ], unlinked = [...] }`.
- Unit tests:
  - non-member characters are excluded
  - characters of a non-friend go to Unlinked
  - a presence link alone links a character
  - addon-record characters link only if the sender is a current friend
  - conflict: presence wins
  - own characters link to self
  - a character removed from the community disappears
  - display name priority rule
  - sorting: online first, then display name
- Decided in CF-08: own characters link to self first, then presence (friend only), then a friend's record. Two records claiming one GUID: newest `updatedAt` wins, then BattleTag order. Only people with at least one visible character are listed (self included). Input also takes `online` (PresenceTracker) and `selfGuid` for `online`/`currentChar`. `/cf people` prints the view model.

## E4 Sync

### CF-09 Protocol (pure)
- encode -> chunk -> reassemble -> decode round trip for payloads from 10 B to 50 KB.
- Out-of-order chunks reassemble; duplicate chunks ignored; incomplete messages expire after 30 s (time injected).
- Messages with unsupported `pv` rejected.

### CF-10 Transport
- Sends via `BNSendGameData` with throttle (configurable, default max 1 chunk per 0.2 s); queues during combat, flushes on PLAYER_REGEN_ENABLED.
- Receives BN_CHAT_MSG_ADDON for prefix `CommForever`, resolves sender BattleTag via presence, passes reassembled messages to Sync.
- Decided in CF-10: queue and rate limit in pure `core/Outbox`, wiring in `services/Messenger` (the adapter stays thin); interval in `settings.sendInterval`; `/cf ping [bytes]` and `/cf ping stats` for in-game testing before sync.

### CF-11 Sync flow
- HELLO / REQ / RECORD as in ARCHITECTURE.md, with per-peer dedupe (60 s) and debounce (5 s).
- Merge accept rules unit tested: wrong sender BattleTag rejected, older or equal version rejected, spoofed `bt` rejected, unknown `pv` rejected.
- Outgoing RECORD contains only own characters that are current community members (unit test).
- Decided in CF-11: same-version HELLO deduped per peer for 60 s, newer versions always sent; version bumps when the shared set of own community characters changes; REQ answered after member data has loaded; `/cf sync` forces a HELLO; window refreshes on `CF_PEOPLE_UPDATED`. Superseded in CF-17: the shared-set version bump and the wait for member data were removed, because all own characters are always shared.
- Manual (2 clients): friend levels up, your window shows the new level within ~10 s. Friend logs in on a community alt, it appears under them.

## E5 UI

### CF-12 Main window
- `/cf` and the minimap button toggle a movable, resizable window; position and size saved.
- People section: header per person (display name, BattleTag, online dot plus current character). Expandable to character rows: class-colored name, level, ilvl, professions (rank/max), realm, "Online" or last seen.
- Unlinked section: community data only (name, class, level, zone if online).
- Renders from the Linker view model only. Refreshes on change events, no polling.
- Empty states: no community selected; no linked people yet.
- Decided in CF-12: AceGUI window, draft B layout: tree left (people with online dot, expandable to class-colored characters, Unlinked group), detail right (person card: name, BattleTag, status, character list; character card: class, owner, status, Level / Item level / Last seen boxes, professions with bars). New people start expanded; expansion, selection and tree width are saved (`settings.tree`). No realm shown (one ruleset). Minimap: left-click window, right-click settings, hide toggle. `/cf` toggles the window, `/cf help` lists commands. Round 3: green dot on the character a person is playing; stats as plain text; Professions and Talents (placeholder until CF-18) side by side; offline status shows the last zone seen in the community (`locations`, local only), the character and the time.

### CF-13 Nicknames (dropped)
- Removed on request: no local nicknames. Display names come from the owner's displayName (CF-04) or the BattleTag name part.

## E6 Tooltip and notifications

### CF-14 Unit tooltip
- Hovering a player unit whose GUID is linked adds: `<display name> · N characters` (no BattleTag, decided in CF-14).
- Unlinked community member: `CommunitiesForever member`.
- Implemented via TooltipDataProcessor behind an existence check (V6).
- Decided in CF-14: the line shows the display name without BattleTag (`Sjaak · 3 characters`, the count includes alts outside the community); nothing on your own characters; GUIDs that are secret values (Midnight) are skipped.

### CF-15 Login notifications
- When a linked person comes online in Forever or switches character: chat message `Sjaak is online on Garraka Doombringer (Mage 11)`.
- Only for people linked in the selected community. Not for yourself. No repeat for the same person within 30 s.
- Toggle in settings (default on).
- Decided in CF-15: the same message for coming online and switching character; uses the display name and the localized class name and level from Battle.net presence; friends already online at login give no message (CF-07 baseline).

### CF-16 Level-up announcements
- When a linked person's character in the selected community levels up, show a chat line: `Sjaak's Garraka Doombringer reached level 12`.
- Detected on the receiving side: an accepted RECORD whose character `level` is higher than the stored one. No new message type and no protocol change.
- Only for characters visible and linked per the core rules. Not for yourself. No message for characters seen for the first time.
- Toggle in settings "Announce friends' level-ups" (default on), separate from login notifications.
- Unit tests: level increase announces; same or lower level, new character, own record, unlinked character do not.
- Manual (2 clients): friend levels up; within ~10 s the line appears in your chat.
- Scope (accepted): only reaches people who are your Battle.net friends and run the addon (V1 has no relay).

### CF-17 Alts outside the community
- All own characters are always shared (decided in CF-17 testing: the "Share alts outside the community" setting was removed). The outgoing RECORD contains every own character; the receiver decides what to show.
- Receiver (Linker): a character from a record that is not a member of the selected community is shown only as a non-member alt, under its owner, if the owner is a current friend with at least one visible, linked member character. Otherwise it is ignored. It never appears in Unlinked.
- Membership is always decided by the receiver's own community data, never by the sender.
- UI: non-member alts are listed after the person's community characters, class-colored, with "not in community" on the cards.
- Unit tests (Linker): non-member alt shown under a person with a member character; hidden when the person has no member character; hidden for a non-friend; a character that joins the community becomes a normal member row. Outgoing RECORD contains all own characters.
- Manual (2 clients): the friend has an alt that is not invited; it shows under them with its class color and a "not in community" label on the cards.
- Privacy note: alts are always shared with Battle.net friends who run the addon; they are only shown when the owner has a character in the community.
- Decided in CF-17: your own alts outside the community are shown under you too (your record is `self.chars`); alts outside the community keep their class color (not dimmed), the cards say "Not in community"; a friend online on an outside alt has that row as current character.

### CF-18 Talents and role
- First: find the talent API on Forever (V20). Forever uses the Mainline API with Vanilla content, so it may be the classic-style `GetNumTalentTabs` / `GetTalentTabInfo` or the retail-style `C_ClassTalents` / `C_Traits`. Extend FriendProbe (`/fp talents`) to dump what exists before building.
- Snapshot (CF-03) adds per character:
  - `talents = { { name, points }, ... }` per talent tree, in the game's tree order
  - `mainTree` = index of the tree with the most points; nil with no points spent; ties go to the lower index
  - `role` = `"tank"`, `"heal"` or `"dps"`; nil below talent level / no points
  - `roleOverride` = `"tank"`, `"heal"`, `"dps"` or nil (auto)
  All are synced fields: a change bumps the version. Refresh on the talent-change event (V20).
- Auto role (pure, unit tested): table `classFile + mainTree -> role`, e.g. Warrior Protection = tank, Priest Holy/Discipline = heal, Paladin Holy = heal, Paladin Protection = tank, Druid Restoration = heal, Shaman Restoration = heal; everything else dps. Druid Feral defaults to dps (override to tank).
- Override: the owner sets the role per own character in settings ("Role: Auto / Tank / Healer / DPS" for each own character). Effective role = override, else auto. Friends see the effective role.
- Display (CF-12 character rows): role (icon or short text) plus the talent split, e.g. `Heal · Holy 31 / Protection 5 / Retribution 15` with the main tree highlighted. Unknown: `-`.
- Unit tests: auto role per class/tree; ties; no points -> nil; override wins over auto; clearing override returns to auto; talent change bumps version, identical talents do not.
- Manual: spend a talent point, `/cf self` shows the new split and role; set an override, a friend sees it in their window.
- Decided in CF-18 (V20/V29): Forever has no classic talent tabs and one specialization per class, so the three Vanilla trees are the three columns of the single `C_Traits` tree, split at the two largest x gaps; tree names come from a fixed per-class table (left-to-right order verified for Warrior). Role override per own character in settings ("Roles of your characters"). Talents show on the character card (main tree in gold, bars), the role also in the person card list and `/cf self`. Talent data that cannot be read for a moment is kept, not wiped.

### CF-19 Shared quests
- Goal: on a friend's character card, show the quests it has in common with any of your characters, so you know who to group with. Names only, no objective progress (decided: keeps sync small and changes rare).
- Quest log API (V23, verified): `C_QuestLog.GetNumQuestLogEntries` / `C_QuestLog.GetInfo(i)` (questID, title, isHeader, isHidden); headers are areas (zones, dungeons, "Crafting", the class). Events QUEST_ACCEPTED, QUEST_REMOVED, QUEST_TURNED_IN, QUEST_LOG_UPDATE (debounced 2 s).
- Snapshot (CF-03) adds per own character `quests = { [questID] = { title, area, dungeon } }`, headers skipped (area = header above the quest). Synced field: the version bumps only when the set of quest IDs changes (accept, turn in, abandon), not on progress. Your alts' quests are as of their last login.
- Sync: part of each Char in RECORD (title included, so the receiver needs no quest cache). Rough size: 25 quests x ~40 bytes per character, compressed; fits the existing chunking.
- Pure core `Quests.shared(friendQuests, ownChars)` -> areas `{ { area, dungeon, quests = { { questID, title, ownChars = { { name, classFile } } } } } }`, dungeon areas first, quests by title; matching by questID, never by title.
- Display (decided, layout A): a friend's character card gets `Shared quests (N)`, grouped by area, dungeon areas first with the dungeon entrance icon and `Dungeon`; per quest the title plus which of your characters has it (class-colored). At most 5 quest lines in total, then a `Show all N` link (`Show fewer` folds it back, per card until /reload). None: `No shared quests.` Not shown on your own or Unlinked characters.
- Dungeon quests (decided): quest tag `C_QuestLog.GetQuestTagInfo(questID).tagID` 81 (Dungeon) or 62 (Raid) (V31), or the quest sits under a Vanilla dungeon/raid header (fallback name list).
- Person card (decided, option B): `Shared quests (N)` over all of the friend's characters; per quest the title, then `Them <their characters>   You <yours>`. Same 5-line limit and Show all. Not on your own person card.
- Empty quest log (decided): ignored (the stored quests stay) unless it follows QUEST_TURNED_IN or QUEST_REMOVED, since the log can be empty for a moment right after login.
- Hidden `/cf debugon` / `/cf debugoff`: a fake Debug Friend (two characters with talents, professions and some of your current quests) in the window only, never stored or synced.
- Tree (decided): a friend's character that shares a dungeon quest with you gets the dungeon entrance icon (`worldquest-icon-dungeon` atlas, picked in-game with `/fp icons`, V32; gold `[D]` fallback) after its level. Not a skull.
- Unit tests: overlap with one alt, with several alts, none; headers ignored; quest progress change does not bump the version; accept/abandon does; matching by ID with different titles (locale).
- Manual (2 clients): both accept the same quest on any character; within ~10 s it appears on the friend's character card; abandon it, it disappears.
- Depends on sync (CF-09, CF-10, CF-11).

### CF-20 Relay records through friends
- Goal: records travel through any friend running the addon, so people in different time zones still get each other's data. Example: A and B are online together, B logs off, C logs on while A is online: C gets B's record from A.
- Decided: trust is the community. A relayed record links its community characters to its owner even when the owner is not your own Battle.net friend (changes core rules 2 and 4). Relayed records are marked subtly: the person card says `Updated 3 h ago via Sjaak`; nothing extra for records that came from the owner.
- Protocol (pv stays 1; old clients ignore the new field):
  - `HELLO {bt, ver, known = { [battleTag] = version } }`: every record the sender holds (own included), only people with at least one character in the sender's selected community.
  - The receiver sends `REQ {bt = <wanted BattleTag>}` to that peer for every entry newer than what it stores; the peer answers with that `RECORD` (own or stored).
  - A RECORD whose `bt` differs from the sender's BattleTag is a relayed record; it is stored with `via = <sender BattleTag>`.
- Accept rules (Merge, unit tested):
  - Direct record (from its owner): as CF-11, and it always replaces a relayed copy, even one with a higher version, so a broken or forged copy can never block the owner's real data.
  - Relayed record: sender is a friend in Forever (transport), `record.bt` is not your own BattleTag, version newer than stored, version not more than 5 minutes ahead of server time (versions are close to server time; a far-future version would block real updates), and at least one of its characters is a member of your selected community (your own community data).
  - Relayed records may be relayed again (A -> C -> D); versions only go up, so loops stop by themselves.
- Linker: people from relayed records are linked like direct ones (presence still wins on conflicts); CF-17 rules for alts outside the community apply unchanged.
- Unit tests: relayed record stored with `via`; direct replaces relayed even at a lower version; relayed never replaces direct at an equal or lower version; far-future version rejected; own BattleTag rejected; record without a community member rejected; HELLO `known` lists only community people; REQ for a stored person answered with the stored record; a non-friend owner is linked through a relayed record.
- Manual (3 clients, or 2 plus timing): A and B online, B logs off; C logs on while A is online: within ~10 s C sees B's characters under B with `via <A's name>`; later B and C online together: the label disappears (direct record).
- Depends on CF-11. Build order: right after CF-17.
- Decided in CF-20: REQ carries `want` (nil = the peer's own record), backward compatible; on a character that cannot see the community, HELLO `known` lists every stored record (the receiver still checks the community); accepting a new record triggers a debounced HELLO so other friends learn it; relayed records link even when the owner is not your Battle.net friend.

### CF-21 Join the community with a shared invite code
- Goal: on a character that is not in the selected community, the addon offers a "Join <community>" button, so alts can join without asking someone online to invite them.
- First (blocking): verify on Forever that an addon may look up and redeem invite codes (V25 existence, V26 real call with FriendProbe `/fp ticket` and `/fp redeem`). If `C_Club.RedeemTicket` is missing or blocked for addons, this story stops and we revisit option B (direct invites by someone with invite rights).
- Setting (only for the owner, leaders and moderators of the selected community, role from `C_Club.GetMemberInfoForSelf`, guarded): "Community invite link". Accepts a full invite link or just the code; stored as the code plus `setAt`.
- Sync: the code travels in the setter's record as `invite = { clubId, code, setAt }` (pv stays 1; old clients ignore it). Receivers keep the newest by `setAt` across all records (relayed records included, CF-20).
- Join steps: in the "not a member" message (CF-17) when an invite code for the selected community is known (see "Decided in CF-21" below; the original direct-join plan was blocked by Blizzard).
- Invite links expire or have a use limit, so the setter may need to paste a new one now and then; the setting shows when it was set.
- Unit tests: link and code parsing; newest invite wins; invite only for the selected community; button only on a non-member character with a valid code; expired code shows the message.
- Manual: owner pastes a link; on an alt outside the community (after a sync) the Join button appears; click it: the alt joins and the window shows the community.
- Depends on CF-17 (not-a-member message) and CF-11 (sync); best after CF-20 (relay).
- Decided in CF-21: addons may not join (C_Club.RedeemTicket is protected, V26). The window shows step-by-step instructions and a "Post invite link in chat" button; the posted clubTicket link opens Blizzard's own join window (V27). Who may set the link comes from the verified `role` member field (1-3). Links must end in the code.

## E7 Activity and planning

### CF-22 Activity feed
- Goal: see at a glance what friends did recently, without one active player flooding the feed. One line per person per day, built from events each client records about its own characters and syncs with its record.
- Decided: no play time, no logins without other activity, no gold, no deaths. Only what someone did.
- Events in this story (no new API needed):
  - **Level-up** (`PLAYER_LEVEL_UP`): per character lowest → highest level of the day: `Ves 5 → 8`.
  - **Milestone**: reaching level 10, 20, 40 or 60 replaces the plain range: `Ves reached 40` (for 60: `Ves reached 60!`).
  - **Questing** (`QUEST_TURNED_IN`, at least 1 quest): count per character plus the zones, sorted by most turn-ins. One zone: `questing in Westfall (9)`; two: `questing in Westfall and Redridge (12)`; three or more: `questing in Westfall, Redridge +2 zones (15)`. The zone is the area (log header) of the quest that was turned in.
  - **Profession rank** (`SKILL_LINES_CHANGED`): only when a new rank is trained (the max goes up: 75 Apprentice, 150 Journeyman, 225 Expert, 300 Artisan), and when a profession is learned: `Mining reached Expert`, `learned Alchemy`. Skill point gains are not shown.
- Storage: own record field `feed`, aggregated per realm day (in-game calendar date) per character, so turn-ins do not add one entry each: `feed = { [day] = { [guid] = { levelFrom, levelTo, milestone, quests = { [zone] = count }, ranks = { { name, rank } }, learned = { name } } } }`. Kept 7 days. A feed change bumps the version at most once per 60 s (debounced), so questing does not sync after every turn-in.
- Privacy: setting "Share my activity" (on by default). Off: your own feed still shows in your window, but `outgoingRecord` leaves `feed` out and friends drop what they stored.
- Line per person per day (pure core, unit tested): parts in order of importance: milestone, level, profession, questing (CF-23 adds dungeon, raid, battleground and activities together at the top). At most 3 parts, then `+N`; clicking the line shows all parts. With several characters the most active one is in the sentence, then `+1 character`. Example: `Vestras: Ves 5 → 8, Mining reached Expert, questing in Westfall (9) +1 character`.
- Window: an **Activity** tab next to the current view (the dungeon planner, CF-24, becomes a third tab). Sections `Today`, `Yesterday`, then weekday names, newest first; within a day, the person active most recently first. Your own line is included. Received text is cleaned like all other received text.
- Unit tests: aggregation per day and character; milestone replaces range; zone wording for 1, 2 and 3+ zones; only new ranks; 3-part limit with `+N`; several characters; 7-day trim; debounced version bump; share off leaves `feed` out.
- Manual (2 clients): level up, turn in quests in two zones, train a new profession rank; within ~1 min the friend's Activity tab shows one line for you today. Share off: your line disappears for the friend after the next sync.


### CF-23 Feed: dungeons, raids, battlegrounds and playing together
- Needs V35 (which events tell instance type, boss kills, group members and battleground results).
- **Dungeon run**: inside a dungeon at least 10 minutes and at least 1 boss killed (which boss does not matter, skipping the last one is fine): `ran Deadmines`; twice: `ran Deadmines ×2`.
- **Raid**: the same for raids, with the number of bosses: `raided Molten Core (4 bosses)`.
- **Battleground**: per match that ends: `3 battlegrounds (2 won)`.
- **Playing together** (decided: one combined line): the client stores the group members' GUIDs with each dungeon, raid and battleground. The receiver maps them to people (Linker). When two or more people did the same activity together that day, one shared line replaces it on their own lines: `Vestras and Alice ran Deadmines ×2`, `Vestras, Alice and Bob: 3 battlegrounds (2 won)`. Community members without the addon appear by character name: `Vestras ran Deadmines with Alice Example`.
- These parts come first on a line, before milestone and level.
- Unit tests: 10-minute and boss rule; ×2; shared line from two records; shared line from one record (companion without the addon); companions outside the community left out.
- Manual (2 clients in one group): run a dungeon together, kill one boss, leave after 10 minutes: one shared line for both.
- Decided in CF-23: built before V35 was run, with guarded fallbacks: a boss kill comes from `ENCOUNTER_END` (success 1) or `BOSS_KILL` (counted once per encounter); the battleground winner from `PVP_MATCH_COMPLETE` or `GetBattlefieldWinner`, your team from `GetBattlefieldArenaFaction` or your faction (Horde 0, Alliance 1). A missing API means a missing line, never an error. `/cf activity debug` prints every instance event and what the tracker concluded, so the first real dungeon answers V35.
- Decided in CF-23: the run in progress is saved (`db.global.runs`), so `/reload` or a disconnect inside keeps it; the time inside counts until leaving (or the logout). A run counts on the day it started. Only companions who are members of the selected community are stored. Several runs with the same people on a day make one shared line per group of people (`Ann and Ben together`: `ran Deadmines ×2`); battlegrounds are counted together regardless of map.

### CF-24 Dungeon planner
- Calendar findings: reading events works (V33); creating one is blocked for addons (V34: `AddEvent` fires `ADDON_ACTION_BLOCKED`).
- A **Dungeons** tab: for each Vanilla dungeon (fixed table in core with level ranges, same names as the CF-19 list) that fits one of your characters: your characters in range, friends' characters in range (online first), and who has a quest for it (CF-19). Dungeons with the most candidates first.
- Selecting a dungeon suggests a group automatically: up to 5 characters in level range, preferring one tank and one healer by role (CF-18), then shared quests, then online.
- Calendar: upcoming community events (`calendarType` community, V33) whose title mentions the dungeon are listed with their time and sign-ups. Since addons cannot create events (V34), "Plan in calendar" opens Blizzard's calendar (unverified call, guarded) and puts a ready-made title (`<dungeon> run`) and the suggested characters in a chat line to copy into the event. Still to verify: how a community event shows in `GetDayEvent` (create one by hand, `/fp calendar`).
- Unit tests: level-range filter; suggestion order (roles, quests, online); title matching for calendar events.
- Manual: open the tab, pick a dungeon, create the event in Blizzard's calendar from the suggestion; it shows on the dungeon page; a friend sees it and signs up.
- Decided in CF-24: layout A (dungeon list on the left like the Friends tab, the chosen dungeon on the right). Candidates are all community members: your characters, linked people's characters (also their alts outside the community), and unlinked members (level and class only; each counts as their own person). Only dungeons with one of your characters in range; raids are left out. Scarlet Monastery is split into its four wings with their own ranges; quests count for a dungeon by their quest log area. The suggestion takes at most one character per person: your best one first, then a tank and a healer from two different people, then shared quests, online, closeness to the middle of the range. Chat lines cannot be copied in WoW, so "Plan a run" shows the event title in a field to copy from (Ctrl+C), plus an Open calendar button.
- Decided in CF-24 round 2 (feedback): the event title is just the dungeon name and events match on the dungeon name only ("The" optional, the longest name wins: a Scarlet Monastery wing beats nothing shorter); no short names, no group field (you cannot invite yourself; inviting is done in the calendar). Runs planned within 3 days are listed on top under Planned (also for dungeons none of your characters fits, in grey) with their time and sign-ups, and the tab reads `Dungeons (N)`. Sign-ups count signed up, accepted and confirmed (tentative apart); they need each event opened (`C_Calendar.OpenEvent`, one at a time, V43), done in the background by the Planner service. Section titles in the normal size; your other characters in range on one line under yours; no Calendar section without events.
- Decided in CF-24 round 3 (feedback): list rows show the dungeon icon with `have/total` quests; the detail has a Quests section (in your log, to pick up with who in range has it, from level N, and how many are already done). have = quests in the log of your character in the suggested group; total = have + quests you can pick up now. No API lists quests you have not picked up, so the full list comes from the optional QuestieDB addon at runtime (decided: no data shipped, QuestieDB has no license); without it, from the quest logs of people in range. Quests of the other faction (`requiredRaces`) and class quests are left out; completed ones only for the character you are on (`IsQuestFlaggedCompleted`, V45).
- Decided in CF-24 round 4 (feedback: Forever's new dungeons were missing): the list comes from the game's Group Finder (`C_LFGList` dungeon activities, V46) at runtime. Known dungeons keep their quest data and take the game's level range; unknown ones (Forever's new dungeons: Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran) are added by name and range, with quests only from quest logs (QuestieDB has no Forever-only data yet). Without the Group Finder the static Vanilla table is used. When the Group Finder answers, only the dungeons it offers are listed (no Stockade for Horde); a dungeon without known quests says "No quests known for this dungeon yet."

## E8 Communication

### CF-25 Community chat that stands out
- Goal: messages in the selected community's chat are easy to notice, in Blizzard's own chat (no chat of our own).
- V37 (verified): coloring the channel, opening a chat tab, flashing a tab and playing a sound work from an addon; `ChatFrame_AddChannel` is gone; `frame:AddChannel(name)` puts the channel into the new tab (V39, verified). V38 (verified): the message text is hidden, but the sender name and GUID are readable.
- **Color, always on** (decided): the community channel is purple in all chat windows (`ChangeChatColor` on the channel, default `#C080FF`, readable on the dark chat background). Applied on every login and when the community selection changes. A color picker in settings changes the shade; there is no off switch.
- **Alert on a new message** (setting, on by default): when someone else writes in the selected community, every chat tab that shows the channel and is not the selected tab flashes (`FCF_StartAlertFlash`). Optional sound (`SOUNDKIT.TELL_MESSAGE`, setting, off by default). No alert for your own messages (sender GUID is one of your characters, V38).
- **Community chat tab** (encouraged, CF-26 offers it): a button "Create a Community tab" opens a chat tab named after the community that shows only that channel. Chat windows are saved per character by the game, so the tab is offered once per character (remembered in `settings.chatTab[guid]`); clicking again when the tab exists says so. Option "Keep community messages in General too" (on by default); off removes the channel from the other windows, so only the Community tab flashes.
- Not in scope: a chat view inside our window, changing sender names or message text (likely blocked by secret values under Midnight).
- Unit tests (pure core): which incoming messages alert (selected community, not you, not the selected tab); color setting default and change; tab offered once per character.
- Manual (2 clients): a friend writes in the community while another chat tab is selected: the tab with the community chat flashes and the message is purple. Create the Community tab: it shows only community messages; with "Keep in General" off, General no longer shows them.

### CF-26 Onboarding wizard
- Goal: new users set things up in a minute and are encouraged to create the Community chat tab (CF-25). Builds on CF-25 (tab and color code).
- A small window with Back, Next and Skip, shown once per account on the first login after installing (`settings.onboarded`), reopened with `/cf setup`. Closing it counts as skipped; nothing is required.
- Steps:
  1. **Welcome**: what the addon does in three lines (who is who in your community, synced between friends with the addon, activity and shared quests).
  2. **Community**: pick the community (dropdown, pre-selected when there is only one). Without a character community: how to join one (invite link from a friend, CF-21).
  3. **Your name**: display name friends see (CF-04), prefilled with the BattleTag name part.
  4. **Community chat**: a preview line in the purple community color, the big highlighted button **Create a Community tab** (recommended), "Keep community messages in General too" (on), "Flash the tab on new messages" (on), "Play a sound" (off).
  5. **Notifications and sharing**: login notices (on), level-ups (on), Share my activity (on), minimap button (on), each with one line on what it does.
  6. **Done**: "Open CommunitiesForever with /cf", and that friends need the addon too to see their professions, talents, quests and activity.
- Every step writes the same settings as `/cf settings` (one source of truth); the wizard only presents them.
- Alts: chat windows are per character, so on a character without the Community tab (`settings.chatTab[guid]`) a small prompt offers only step 4 ("Create a Community tab on this character too?" Create / Not now / Don't ask again for this character).
- New steps added later (`settings.onboardedVersion`) are shown once to existing users, only the new ones.
- Unit tests (pure core): which steps to show (first run, new version, alt without tab, don't ask again); defaults per setting.
- Manual: fresh SavedVariables: the wizard opens on login, Skip closes it, `/cf setup` reopens it; finishing step 4 creates the Community tab; on an alt only the chat prompt appears.
- Decided in CF-26: existing users (no `settings.onboarded` yet) see the full wizard once too, prefilled with their settings. Layout A: a compact window with dots and "Step N of 6" on top, Back / Skip / Next at the bottom (Finish on the last step). It opens 5 s after login. The character the wizard ran on gets no chat prompt; the prompt (feedback round 1) has one big "Yes, create a Community tab" button; closing it means no, and either way the character is not asked again (`settings.chatTabPrompt[guid]`). A closed chat tab keeps its name, so closed windows do not count as a Community tab (V41). The display name is saved when leaving its step, and only when it changed.

### CF-29 Passive without a community
- Goal: an addon that has nothing to work with stays out of the way.
- Passive = no community selected for the account (`settings.clubId`) and this character is in no character community (`Clubs.passive`, pure). A character outside the selected community is not passive (it keeps the "how to join" page).
- Decided: while passive no setup wizard or chat prompt, no minimap button (whatever the setting), no login notices, and no sync (`Messenger` sends and accepts nothing). `/cf` shows what the addon is for and how to join with an invite link or code, or create a community.
- Decided: joining a community while playing (`CLUB_ADDED`) selects it, opens the setup right away, shows the minimap button and announces to friends (`CommunitySelection.PASSIVE_CHANGED`).
- Built in PR #44 (released in v0.3.0-beta1). Unit tests: `Clubs_spec` (passive rule), `Passive_spec`. Manual steps in VERIFY.md ("Passive without a community").

### CF-30 Setup: chat tab button in the Next spot
- Goal: clicking on through the setup in the same place also creates the Community chat tab.
- Decided: on the Community chat step, on a character without a Community tab, the Next spot reads **Create chat tab** (creates the tab and goes to the next step) and **Not now** replaces Skip (goes on without a tab). With a tab the step has Skip and Next as before; a closed tab counts as no tab (V41).
- Built in PR #45 (released in v0.3.0-beta1). Unit tests in `Setup_spec`. Manual steps in VERIFY.md ("Setup: chat tab button in the Next spot").

## E9 Playing together

### CF-27 "Who's up for it?" group ask
- Goal: get a group together now for a dungeon, with one click, among friends who run the addon.
- Ask: from a dungeon in the Dungeons tab (button **Ask who's up for it**) or `/cf ask <dungeon>`. Sent over the existing Battle.net addon channel to friends online in Forever who run the addon and have **any** character in the dungeon's level range (decided: also on an alt; the message says which of their characters fit).
- Receiving: a sound and one chat line (decided: no popup): `Vestras asks: The Deadmines now? (17-26)`, `You could come on: <character> <level>`, with clickable `[Join] [Later] [No]` (an addon chat link; V47).
- Answers come back to the asker and show live under the dungeon (`Ben: joining`, `Cid: later`, `Dee: no`), and as a chat line for Join.
- Getting into the party: decided after the probe (V48), one of: the joiner's click requests an invite from the asker (`C_PartyInfo.RequestInviteFromUnit`, Blizzard's accept popup for the asker); or the asker gets an `[Invite Ben]` chat link whose click invites (`C_PartyInfo.InviteUnit` by name, or `BNInviteFriend` by game account). Fully automatic inviting is not expected to be allowed.
- Guard rails: an ask expires after 10 minutes; at most one ask per 3 minutes; a setting "Receive group asks" (on; off: no chat line and no sound).
- Unit tests (pure core): who is eligible (any character in range, online in Forever, runs the addon, not yourself); expiry and throttle; answer states per person.
- Manual (2 clients): ask for a dungeon both have characters for; the friend hears a sound and sees the chat line; Join gets them into your party (per V48); Later and No show for the asker.
- Built before V47/V48 (decided): the Join click asks the asker for an invite (`RequestInviteFromUnit`, when it exists) and the asker also gets an `[Invite]` link (`InviteUnit` by name, else `BNInviteFriend`); the probe decides which stays. Links are hooked through EventRegistry "SetItemRef" and a SetItemRef hook (a click reported by both counts once). The ask button sits under the suggested group in the Dungeons tab (only for dungeons that fit your characters) and shows the answers there for 10 minutes; `/cf ask <dungeon>` asks by name, `/cf ask` shows the state.
- Built (PR #29). In-game checks V47 (link clicks) and V48 (which invite path works) are still open in VERIFY.md; they decide which of the two invite paths stays.

## E10 Community transport

### CF-28 Sync with the community, no Battle.net friendship needed
- Goal: everything that works between Battle.net friends (records with professions, talents, quests and activity; login notices; level-ups; group asks) also works between community members who run the addon but are not each other's Battle.net friends.
- Decided: **both transports**. Battle.net stays for friends (bigger messages, cross-faction, reliable online status); the community transport reaches every member running the addon. A record arriving both ways is merged as today (newest version wins).
- Decided: **random account ID** instead of the BattleTag for people who are not your friends. Each account creates a random ID once (`self.accountId`, saved) and sends it with its record; the BattleTag is only sent to Battle.net friends. Characters group under the account ID; for friends the BattleTag stays the link to Battle.net presence. Data model: `people` keyed by account ID (records from before CF-28 are re-keyed when their owner's next record arrives).
- Transport (decided after V49/V50): addon messages (`C_ChatInfo.SendAddonMessage`, prefix registered as today): a broadcast in the community channel if addons may send there (V49), else a whisper to each online member running the addon (whispers verified). Messages are at most 255 bytes (V50: exact limit and throttle), so records go in small chunks through a rate-limited queue (larger records take longer, a small community stays fine).
- **Part 2**: the community transport below, and reliable delivery for **both** transports (also Battle.net, decided 2026-10-19). Built in two steps: **2a** reliable delivery and `/cf sync debug` (on Battle.net now, transport-neutral), **2b** the community transport on top. 2b decided while building: the account ID is made once without a version bump (friends learn it with the next record change); a community record counts as the owner's own only when the sending character already belongs to that person (or the person is new), else it is relayed; community peers count as online on HELLO and offline after BYE or a "No player named ..." line (V53); login notices and group asks reach community peers too.
- Reliable delivery (decided): every part carries `<msgId>:<part>:<total>:` (as today). When a message stays incomplete for a few seconds after its last part, the receiver sends `MISS <msgId> <parts>`; the sender keeps what it sent for about a minute and resends only those parts (twice at most). No acknowledgement per message and no extra HELLOs (decided against). The transfer shows only in a debug trace: `/cf sync debug` prints `record from <name>: part 7/20`, missing parts and resends (like `/cf activity debug`).
- **Part 1 (PR #30): merge per character** (decided, for both transports and relay): each character is compared on its own `updatedAt` and the newer copy stays, so a relayed or late record never replaces a character with older data. The owner's own record is the truth for its characters (it may lower a level: that corrects a wrong one); a relayed copy never lowers a level. Relayed timestamps (characters, removals, activity entries) more than 5 minutes ahead of server time are ignored, so a broken or modified client cannot make a copy win forever. A character the owner's own record no longer lists is removed and remembered with the time; a relayed copy that is not newer than that cannot bring it back. The activity feed merges per day and character; "Share my activity" off travels as `feed = false`.
- Unit tests for the merge (part 1, done): older character copy ignored inside a newer record; newer copy taken; a relay never lowers a level, the owner may; future timestamps ignored; a dropped character not revived by an older relay copy.
- Discovery: on login and on joining the community, a HELLO goes out on the community transport; members running the addon answer, so each client knows who to send to. A BYE on logout (best effort).
- Trust: on the community transport a message is only accepted from a character that is a member of the selected community (the sender name maps to a member). A record the sender claims as its own must contain the sending character, so nobody can pose as someone else; a record about someone else is a relayed record and follows the relay rules (CF-20: newer version, at most 5 minutes ahead, a character in the community) and the part 1 merge rules. Your own record is never accepted from anyone.
- Online status: Battle.net decides for friends (CF-15 fix); for others the community presence, corrected by HELLO/BYE (V52: how stale the community presence gets after a logout).
- Cross-faction: whispers most likely do not cross factions (V51); members of the other faction are then reached through Battle.net (friends) or relay only.
- Unit tests (pure core): account ID creation and re-keying; chunking at the community message size; accept rules (sender in community and in the record); online status from presence plus HELLO/BYE.
- Manual (2 accounts that are **not** Battle.net friends, same community): both see each other's characters grouped with professions and talents; a level-up line arrives; a group ask (CF-27) reaches the other one.
- Built: part 1 (PR #30), part 2a (PR #32) and 2b (PR #33). The community transport whispers each member running the addon (255-byte parts, MISS and resend); the one-broadcast-per-community variant waits for V49 (see CF-31 in STORIES.md). Wire details: `docs/SYNC.md`.

## E11 Ease of use

### CF-32 Keybinding and Esc closes the window
- Goal: open and close the window without typing `/cf`.
- A keybinding "Toggle CommunitiesForever" under its own header in Blizzard's keybinding menu (`Bindings.xml`), unbound by default.
- Decided: hard rule 5 in CLAUDE.md gets `BINDING_HEADER_*` / `BINDING_NAME_*` next to `SLASH_*` (Bindings.xml needs them as globals).
- Esc closes the window (and the setup wizard) through the frame's own key handler: no named global frame for `UISpecialFrames`. Esc still opens the game menu when no CommunitiesForever window is open, and still works for other frames and the chat input.
- Manual: bind a key, it toggles the window; Esc closes it; Esc with the window closed opens the game menu; typing in the chat input is not affected.
- Built: `Bindings.xml` (`COMMUNITIESFOREVER_TOGGLE`, header plus `category="ADDONS"`, calls `CommunitiesForever:ToggleWindow()`); `src/adapters/Keys.lua` sets the window and the setup to take keyboard input, pass every key on except Esc, and pass keys on again right after closing. In combat nothing changes (set up on the next show). V54 checks the keyboard API and where the binding shows.

### CF-33 Minimap button tooltip: who is online
- Goal: see at a glance who is online without opening the window.
- Hovering the minimap button lists the people online now: display name, then their character with class color and level (e.g. `Bright  Vel Stormcaller 24`), Battle.net friends and community peers alike (`Sync.online()`), sorted by name. Nobody online: "Nobody online right now." At most 15 lines, then "+N more".
- Below: "Left-click: open window", "Right-click: settings" (as today).
- Unit tests (pure core): the lines from the online list (sorting, class/level missing, the cap).
- Manual: with a friend online, the tooltip shows them on the right character; after they log out they disappear.
- Built: `Format.onlineList` (pure: other people online from the view model, sorted, capped at 15 with `more`) and the tooltip in `src/ui/Minimap.lua` (`AddDoubleLine` when present, V55). The old "N friend(s) online in Forever" line is replaced.

### CF-34 "Uses the addon" mark
- Goal: explain why some people show no professions, talents or quests: they don't run the addon.
- In the Friends tab tree, people running the addon (a record received from them, own or relayed) get a small icon after their name; people known only from the community list get none. The icon's tooltip: "Runs CommunitiesForever" / on the person card a line "Does not run CommunitiesForever: only what the community list shows (class, level, zone)."
- Unit tests (pure core): which people count as running the addon (own record, relayed record, none).
- Manual: a friend with the addon has the mark; a community member without it has none and the explaining line.
- Built: `usesAddon` in the Linker (yourself, or a record with a version, own or relayed); the tree shows the minimap button's icon after the name (not on your own row) and the card a line (`Format.USES_ADDON` / `NO_ADDON`). Decided while building: the explanation is on the card, since AceGUI tree rows have no per-row tooltip. Rule 8: nothing stored or sent changes (derived from records that already exist).

### CF-35 Newer version notice
- Goal: during the betas, everyone notices when an update is out.
- Each HELLO carries the sender's addon version (new field; older clients ignore it). When someone runs a newer **release** version than yours, one chat line per session: "A newer version of CommunitiesForever is available (v0.3.1). Update with the CurseForge app or WowUp."
- Decided: only release versions are compared (`v1.2.3`, `v1.2.3-betaN`, `-alphaN`; `v0.3.0-beta1` < `v0.3.0-beta2` < `v0.3.0` < `v0.3.1`). Dev builds (`0.1.N` from `build.ps1`, `@project-version@`) never trigger the line and never get it. A version more than one major ahead or unparsable is ignored.
- `docs/SYNC.md` documents the field.
- Unit tests (pure core): version parsing and order, dev builds ignored, once per session.
- Manual: two clients on different release builds: the older one gets the line once; `/reload` shows it once more at most.
- Built: `src/core/Version.lua` (release tags only, alpha < beta < release, more than one major ahead ignored); HELLO carries `av` (the TOC version, `addon.version`); `Sync` prints the line once per session after the sender passed the HELLO checks. Rule 8: `av` is a new optional field: older clients ignore it, a HELLO without it gives no line. Tests: `Version_spec`, `VersionNotice_spec` (end-to-end harness, also over the community).

### CF-36 Smart filter in the Friends tab
- Goal: find "who has Tailoring 150?" or "which mages are 20-30?" without clicking through everyone (instead of a separate profession overview: same data).
- A search box above the tree with a grey placeholder while empty and unfocused: `e.g. tailoring 150, mage 20-30` (AceGUI has no placeholder: an own grey text on the edit box, hidden while it has text or focus).
- Decided: each word must match something of a character: name, owner's display name, class, role (tank/healer/dps), profession or zone. A number right after a profession is a minimum rank (`tailoring 150`); `20-30` is a level range; a single number is an exact level. Case-insensitive, also on part of a word (`tail`).
- The tree shows only people with at least one matching character, those characters only, expanded; the count shows ("3 of 12"). Empty box: everything as today. The text stays while the window is open, cleared on close.
- Unit tests (pure core): parsing (words, profession + rank, ranges) and matching per field; no match.
- Manual: `tailoring 150`, `mage 20-30`, `healer`, a zone name, a partial name; clearing the box shows everyone.
- Built: `src/core/Filter.lua` (parse and match, pure); the box sits in the window's tab row (the content area holds one widget), shown on the Friends tab only, with the count next to it; filtering expands the matches and puts the groups back when cleared; the card still shows the whole person. Decided while building: role words match from their start, so "mage" does not find damage dealers. Rule 8: nothing stored or sent changes.

### CF-37 Right-click menu on a character or person
- Goal: whisper, invite or copy a character's name without typing a first-and-last name.
- Right-click a character (in the tree and on the person card) opens a Blizzard-style context menu: **Whisper** (opens the chat input with `/w <name> `), **Invite to group** (as CF-27's invite: by name, else Battle.net), **Copy name** (a small box with the name selected, so Ctrl+C copies it; WoW has no clipboard API). Your own characters: only Copy name.
- Decided: Blizzard's menu (`MenuUtil`), probed first (new FriendProbe check, V-question in VERIFY.md): does `MenuUtil.CreateContextMenu` exist and work from an AceGUI tree row, and which call opens a whisper (`ChatFrameUtil.SendTell` / `ChatFrame_SendTell`). If the menu does not work, a small own popup with the same three buttons.
- Manual: each menu item on a friend's character; Invite on an offline character is disabled.
- Decided after V57 run 1: also on a **person** (group) row: Whisper and Invite go to the character they are on now; offline: both disabled with "Offline" in the title, Copy name copies the last character seen. Your own row: Copy name only. The menu is raised above the main window (it draws below AceGUI windows otherwise). The copy box closes after Ctrl+C and when it loses focus.
- Decided after V57 run 3: no Copy name (the copy box was clumsy; addons cannot use the clipboard), so the menu has Whisper and Invite to group only, and your own rows have no menu. The main window is strata `DIALOG`, one below Blizzard's menu. Built: `Format.contextMenu` (pure), `src/adapters/ContextMenu.lua` (menu, `ChatFrameUtil.SendTell`), right-click on tree rows and on the card's character list; Invite uses CF-27's `Party.invite` (by name, else Battle.net). Rule 8: nothing stored or sent changes.

### CF-31 One broadcast on a hidden community channel
- Goal: the community transport (CF-28 part 2b) sends one message to the community channel instead of a whisper to each member running the addon, so traffic no longer grows with the number of members.
- Depends on V49: can addons send addon messages in the community channel, and do they arrive at the other members (run 1: the send is accepted, but no copy comes back to the sender)? If V49 says no, this story is dropped and the whispers stay.
- Keeps everything from CF-28: 255-byte parts, MISS and resend, the accept rules (the sender maps to a community member; a record claimed as own must contain the sending character).
- Manual (2 clients in the community, not Battle.net friends): records, level-ups and group asks arrive; `/cf sync debug` shows one channel send instead of a whisper per member.
- Decided (2026-10-23): not the community channel (V49 unclear: the send was accepted but did not come back), but a hidden custom chat channel named `cf` + a hash of the community name, built with an automatic fallback to whispers instead of probing first. V49 dropped. Only HELLO and BYE go on the channel (single part); REQ, RECORD, MISS, ASK and PING stay whispers. HELLO carries `ch` (rule 8: optional); members without it, or a failed join, keep getting whispers; someone new is always answered by whisper. Built: `Chat.syncChannel`, `src/adapters/Channels.lua`, `src/services/SyncChannel.lua`, `Messenger.sendChannel`. Found while building: `ChatFrames.windows` only looked at the first channel of a window (`{ f and f() }` keeps one value). Tests: `SyncChannel_spec` (harness with channels), `Chat_spec`. VERIFY V59.

## E13 Revamp (new look)

### CF-39 Kit and window shell
- Goal: the new window around the existing tabs, and the building blocks the screen stories use.
- Decided: native frames and our own small kit (`src/ui/kit/`), no AceGUI for the main window. Ace3 stays for the plumbing. Fonts Marcellus SC, Marcellus and Inter bundled (SIL OFL, `media/fonts/`; added to ARCHITECTURE "Libraries", rule 7), the game font as fallback for non-Latin clients.
- Kit (values from `widget-kit.html` and the mockups): Window (96% opaque navy panel, 1 px gold border, corner diamonds, soft shadow), title bar (shield emblem, community name in Marcellus SC, "CommunitiesForever", "● N online", settings and close buttons), Tabs (Marcellus SC, gold underline when active, count badge as in "Dungeons (1)"), footer line, Button (normal, hover, pressed, disabled; primary and ghost), Checkbox (with a second line of help text), ListRow (28 px, hover and selected states), SkillBar (fill, cap shading, tier ticks), ClassPortrait (the real class icon in a round mask with a class-colour ring; 20, 32 and 52 px; online dot), Toast. Colour tokens and sizes in one place (`src/ui/kit/Theme.lua`).
- Window: 880 × 600 at UI scale 1, resizable down to 700 × 480, moved by dragging the title; size and position saved as today; strata `DIALOG` (CF-37); Esc and the keybinding as in CF-32; opens on the last tab.
- Textures to make (`media/`, TGA, power-of-two, tinted in code): border nine-slice, corner diamond, button states, checkbox, shine streak, shadow nine-slice, shield emblem, portrait ring.
- Until each screen story lands, the existing tab content (AceGUI) sits inside the new shell's content area.
- Unverified on Forever (VERIFY.md, checked at launch): `CreateMaskTexture`, `Texture:SetGradient` with `CreateColor`, `FontString:SetFont` with a bundled font, `C_ClassColor.GetClassColor`, the class icon atlas, `ScrollBox` with a `DataProvider`, `SetResizeBounds`.
- Unit tests: theme tokens (every colour defined once); the window's saved size and position; tabs and badge; the mock grows the frame API the kit uses.
- Manual: the window looks like the mockups (border, title, tabs, footer), moves, resizes within its bounds, Esc closes it, the old tabs still work inside it.
- Built: `src/ui/kit/` (Theme: colours, text roles, sizes; Widgets: Button, IconButton, Checkbox, ListRow, SkillBar, Portrait, Toast; Window: window shell and Tabs), fonts in `media/fonts` (Marcellus SC, Marcellus, Inter Regular/Medium/SemiBold, static files from the Inter 4.1 release), textures drawn by `tools/make-textures.py`. Decided while building: windows saved before the revamp are reset once to 880 × 600 (Nico), the gear opens the current settings until CF-43, the shadow is one soft texture instead of a nine-slice. The mock gained a recording native-frame API (`CreateFrame`, textures, font strings). VERIFY V61.

### CF-40 Friends tab in the new look
- Goal: the Friends tab as in `friends.html`.
- List (left, 270 px): the search box (CF-36, placeholder kept), per person a group header (online dot, name, "(you)", character count, collapsible), character rows (20 px portrait with online dot, name in class colour, level right, the shared-quest icon with a count). Selected row: gold left bar. Long lists scroll. Right-click menu as CF-37.
- Detail (right): header (52 px portrait, name in Marcellus 24 in class colour, "Class · played by <person> · <status>": online in <zone> or offline, last seen in <zone> <ago>), **Whisper** and **Invite** buttons (the CF-37 actions; disabled when offline or for your own characters). Tiles: Level (with a bar to 60), Item level, Role ("from talents" or "set by player"). Professions as skill bars (rank / max, cap shading, ticks at the tier steps; secondary professions muted). Talents per tree with "a / b / c". Quests you share, grouped by area, dungeons first with a Dungeon tag, "Show all N →". A person's card (group header selected): as today, in the new style.
- Footer: "Synced with <person> <ago>" (the newest record received), "N characters from M friends", "/cf to open · drag the title to move".
- Unit tests (pure core): the header status line, the tiles, skill bar fractions and tier ticks, the footer texts.
- Manual: compare with `friends.html`; search, collapse, right-click, Whisper and Invite still work.
- Decided (2026-10-27): the arrow folds a person, clicking the name opens the person card; our own simple scrolling (`Kit.scrollArea`: plain ScrollFrame, mouse wheel, a thin gold thumb), not ScrollBox. Selection and folded people stay in `settings.tree` (the AceGUI tree's keys: `selected`, `groups` with false = folded; no migration, rule 8). The character card's Whisper and Invite are the CF-37 menu items. The list row shows the number of shared quests (the dungeon icon of CF-19 is gone from the list; areas on the card carry the DUNGEON tag).

### CF-41 Activity tab in the new look
- Goal: the Activity tab as in `activity.html`.
- Filter chips: All, Level-ups, Dungeons, Together (one active; remembered while the window is open).
- Day headers (Today, Yesterday, then the date) in Marcellus SC. Per entry: a 32 px portrait (two overlapping for a together line), "<person> on <character>" or "<person> and <person> together", then a line with a **LEVEL UP** chip "22 → 24" (gold, with a slow shine unless Ambient effects is off), "questing in" with the top zones as pills and "+N zones", "· N quests done", runs ("ran <dungeon>"), profession ranks. The time on the right is the entry's last change that day (`at`, already stored; no run durations: not recorded).
- Footer: "Activity is shared only by friends who turned on Share my activity" and "Keeps 7 days".
- Unit tests (pure core): filtering per chip, the entry lines, "+N zones", the time.
- Manual: compare with `activity.html`; Show all and the together lines still work.
- Decided (2026-10-27): the Dungeons chip covers every run (dungeons, raids, battlegrounds); a chip keeps whole entries (a person's entry counts when any of their characters that day matches); older days read "Monday 26 Oct"; the LEVEL UP chip is static until CF-43 brings Ambient effects. The chip shows "from → to" (the milestone texts "reached 20" stay in `Feed.parts`); an entry shows all its pieces, "Show all (N)" opens the person's other characters. The time is the local clock of the entry's `at` (`date`, V63).

### CF-42 Dungeons tab in the new look
- Goal: the Dungeons tab as in `dungeons.html`.
- List (left): "Planned" (calendar runs within 3 days: name, day and time, who is going), then "In range for <character> (<level>)": per dungeon the level range ("outdoor" for outdoor ones), friends in range, and "x / y quests" (green when you have all). A note: "Ranges are typical levels; the list follows the character you're on."
- Detail: name in Marcellus 26, "levels a–b · <zone>". Suggested group as five slots (tank, healer, three damage): portrait, "<character> <level>", role and person; a missing role stands out ("nobody in range", orange dashed); your slot outlined in gold; open slots "+ open". "Alternatives for you: <your other characters in range>". **Ask who's up for it** (CF-27) with "Sends a chat line to friends with the addon" (not a popup). Quests "x / y in your log" with a check per quest and who else has it. Plan a run: the title ready to copy and **Open calendar** (as CF-24).
- Footer: "Synced with <person> <ago>" and "Group asks wait until combat ends".
- Unit tests (pure core): the slots (missing role, your slot, open), alternatives, quest counts and colour, the planned list.
- Manual: compare with `dungeons.html`; asking, the calendar button and planned runs still work.
- Decided (2026-10-27): the list follows the character you are on (`Dungeons.overview` and `suggest` with its GUID; your other characters are "Alternatives for you"); zones per dungeon hardcoded in English (`Dungeons.ZONES`; none for the Group Finder's new dungeons); "Also in range" kept, compact. No "outdoor" ranges (no data). The list no longer shows the dungeon atlas icon (V32). Selection stays in `settings.dungeonTree.selected` (rule 8).

### CF-43 Settings and setup in the new look
- Goal: the settings window and the first-run setup as in `settings-setup.html`.
- Settings (own window, 640 × ~500): Display name, Community (dropdown, character communities only), Sharing (Share my activity; Receive group asks: "a chat line when a friend looks for a group"), Notifications (When friends log in, Announce friends' level-ups, Play a sound), Community chat (colour swatch and Reset, Flash the chat tab, Create a community chat tab), Interface (Minimap button, **Open on login**, **Ambient effects**: title shimmer and level-up glow). No "paste an invite link to join" (blocked, V26). Footer "Also under Options › AddOns · v<version>"; registered there with `Settings.RegisterCanvasLayoutCategory` (unverified, VERIFY.md), replacing the AceConfig dialog.
- New settings `openOnLogin` (off) and `ambientEffects` (on): new keys with defaults, no migration (rule 8).
- Setup (600 × 460): progress bars and "Step n of 6", Welcome (three tiles: Friends, Activity, Dungeons), Community, Name, Community chat (optional, as CF-30: Create chat tab in the Next spot, Not now), Sharing and notifications, Done. Skip setup / Next.
- Unit tests: every setting writes the same value as before (one source of truth, CF-26); the new settings' defaults; the steps.
- Manual: compare with `settings-setup.html`; every setting works; the setup on a fresh account.
- Decided (2026-10-27): Options › AddOns gets a launcher page (a line and "Open settings"), not a second copy of the controls; the settings window also keeps roles per character (CF-18), the invite link to share (CF-21) and "Keep community messages in General too"; "Play a sound" is the existing chat sound, under Community chat; the ambient animations are built now (`Kit.shine`, AnimationGroup, V64). Built: `Kit.dialog`, `Kit.input`, `Kit.select` (Blizzard's menu), `Kit.swatch`, `Kit.shine`; `adapters/Panels.lua` (colour picker V65, Options page V66). Option names follow the design ("When friends log in", "Minimap button", "Chat color", "Reset", "Create a community chat tab"). AceGUI and AceConfig are no longer called (their libraries stay embedded for now).

### CF-44 Level-up announcement
- Goal: a short announcement at the top of the screen when a friend's character levels up (`activity.html`, above the window).
- A pill at the top centre: 28 px portrait, "<person>'s <character> reached level N", the LEVEL UP chip (shine unless Ambient effects is off); fades out after 6 s; several in a row stack or queue. The chat line (CF-16) stays.
- Setting "Level-up announcement" (Notifications); its default is decided when building.
- Unit tests: when it shows (same rules as the CF-16 line: linked people, not older than 15 minutes), the text, the queue.
- Manual: a friend levels up: the pill shows and fades; off in settings: nothing.
- Decided (2026-10-27): the setting is on by default (also in the setup's notifications step); several level-ups queue, one pill at a time, at most 5 waiting (the oldest dropped). Same rules as the chat line (linked people, not older than 15 minutes); each switch works without the other. Built: `core/Queue.lua`, `ui/LevelUpToast.lua`, `Kit.toast` with a chip, fade (AnimationGroup Alpha, V64) and `onDone`.

## E14 Planned runs

Decided with Nico, 2026-10-27. Two kinds of group: **Ask now** lives in the game (CF-27) and is answered within minutes; a **planned run** is owned by the website, posted and answered in Discord, and ends in an invite in the game at start time. The game never talks to the internet: it learns about runs at login or `/reload` from `Data\Runs.lua` (written by the uploader, UP-12) or from a friend's addon over sync, and what the player does reaches the site after the game saves (`/reload` or logout) and the uploader uploads (web WEB-43). The in-game calendar is out of the flow. Times are UTC in data and shown in the player's local time. Boards: `docs/design/runs-2026-10/` (`runs-flow.html` shows the whole flow). Web stories: E7 in the web repo; bot: BOT-04.

### CF-45 Runs file and checks
- Ship an empty `Data\Runs.lua` (`CF_RUNS = nil`) listed in the TOC, in a release **before** the uploader writes it: a file that isn't there when the game starts only loads after a restart. Release it soon.
- `src/adapters/RunsFile.lua` reads `CF_RUNS` defensively (missing, empty, wrong types, oversized): treated as untrusted like received sync data (strip `|` escapes, caps on counts and string lengths); `src/core` gets a pure validator, unit tested.
- VERIFY.md entries with FriendProbe steps (extend `tools/FriendProbe/`):
  - V-a: is a Lua file in the addon folder that changed on disk re-read on `/reload` (not only at game start)?
  - V-b: may an addon call `C_UI.Reload()` (or `ReloadUI()`) from a button click?
  - V-c: can one click invite several friends in a row (`C_PartyInfo.InviteUnit` per name), converting to a party?
  - V47 and V48 (CF-27) are still open and decide Request invite.
- Compat (rule 8): no stored data or messages change.
- Built (2026-10-27): the file format (`CF_RUNS = { v, updatedAt, reminderMinutes, runs }`, field names in `docs/ARCHITECTURE.md` "Planned runs file") is defined here, since WEB-44 names no fields; the web (WEB-44) and the uploader (UP-12) follow it. Dungeons are named by the ids of `core/Dungeons.lua`. Built: `Data/Runs.lua` (empty), `core/PlannedRuns.lua`, `adapters/RunsFile.lua` (reads once per load, clears the global); the checks are V67, V68, V69 (`/fp reloadfile`, `/fp reload`, `/fp inviteall`).

### CF-46 Dungeons tab with runs
- Board `dungeons-runs.html`. A **Runs** segment next to the dungeons in range (with the count in the tab title), each run with dungeon, local time, organiser, "3 in · 1 maybe", your answer, and what you could fill ("Grom Ashfeller fits tank"). "Runs updated at 17:34 · /reload for newer" from `CF_RUNS.updatedAt`, never pretending to be live.
- A run's detail: the five slots from the roles the addon knows (CF-18), who answered where ("answered on Discord"), who is close in level, the reminder line, Invite all from start time (CF-48), "Edit or cancel on the website" with the link to copy.
- Dungeons in range show their planned runs ("1 run"). The calendar parts of CF-24 (event matching, Planner's `OpenEvent` queue, Open calendar) are removed.
- Runs are shared over sync to friends' addons (a new message type within `pv`; rule 8: older clients ignore it), the newer `updatedAt` wins, never sent during encounters, keystones or PvP matches.
- Tests: the runs list from a sample `CF_RUNS`, slot filling, newer wins over sync, an old client ignoring the new message.
- Built (2026-10-27): runs come from `Data\Runs.lua`, from friends (`RUNS`/`RUNREQ`, HELLO `ru`) and from `global.plannedRuns` (stored, so a friend without the uploader keeps them after `/reload`; a new optional key, no migration). Slots: "I'm in" answers by role (the site's, else the role the addon knows), then "maybe" dimmed; a tank or healer slot is missing when nobody in range plays it. A run gets an optional `source` (site, discord, game). The organiser sees a disabled "Invite all · from <time>" (CF-48 enables it); Ask now and Plan a run buttons come with CF-47 (the CF-27 ask stays meanwhile). Restricted sending: `Instance.messagingRestricted` (`C_ChatInfo.InChatMessagingLockdown`, `IsEncounterInProgress`, battlegrounds; V70). Removed: `adapters/Calendar.lua`, the calendar parts of `Planner` and `Dungeons`.

### CF-47 Ask now, plan a run, sign up
- Board `run-dialogs.html`. **Ask now** (CF-27's ask in the new dialog): dungeon, you go as, who gets whispered and who not (and why), note, **Also post on Discord** (needs a `/reload`; "posted about 15 s later"). **Plan a run**: dungeon, lead as, day (today and the next 6 days), time on the PC clock ("friends see their own time"), note. **Sign up in game** to a run: I'm in / Maybe / Can't, Pick my character (fits / too high / too low), sent to the organiser's addon over sync at once when both are online.
- What has to reach the site (plans, answers, asks to post, pings from CF-48) goes into a `pending` table in SavedVariables, each item with an id (so a file uploaded twice changes nothing on the site), marked "reaches Discord after /reload" until a later `Runs.lua` or sync shows it arrived. Store migration step for the new table (rule 8).
- **The reload prompt** after Ask now or Plan run: "Reload now to post on Discord" / "Later" (later: at the next reload or logout; an ask older than 10 minutes by then is not posted).
- The labels everywhere: "reaches Discord after /reload", "answered on Discord", "Runs updated at … · /reload for newer".
- Tests: the pending queue (ids, cleared when confirmed), what goes in the saved file (the web's WEB-43 reads it: share a fixture), the expiry of a queued ask.
- Built (2026-10-27): `core/Pending.lua` and `global.pending` (schema 2, `Store.MIGRATIONS[1]`), ids `<accountId>-<time>-<n>`; one pending answer per run (the newest); asks older than 10 minutes and anything older than 14 days are pruned at login and logout; items leave when the runs data lists their id in `received` (new optional `CF_RUNS` field). Shared sample for the web: `tests/fixtures/pending.lua`. `RUNANSWER` goes to the organiser at once; ASK carries an optional `note`. Ask now replaces the direct "Ask who's up for it" button; the dungeon card got Plan a run, a run Answer / Change answer. Reload: `Panels.reload` (`C_UI.Reload`, else `ReloadUI`; V68), with "Type /reload" as the fallback. Local time to UTC: `time()` (V71). Days are chosen as buttons, the dungeon and character as dropdowns.

### CF-48 Reminder, start time and chat lines
- Board `run-start.html`. **Reminder toast** at the site's reminder time (default 30 min, in `CF_RUNS`) for friends who answered I'm in or Maybe and are online with the addon: under the minimap, 20 s, soft chime (off in settings), Open, no answer buttons. **Starting now** toast with Request invite.
- **Start-time panel**, opening by itself at start time (or from the Dungeons tab). Organiser: each friend's state from Battle.net presence and sync (ready, on another character, offline, maybe, can't, answered on Discord, already grouped) with Invite, Whisper (an editable Battle.net whisper), Invite <other character> instead, Ping on Discord (queued, after `/reload`); Invite everyone ready, Ping everyone missing. Everyone else: the organiser's state and Request invite (sends the organiser a request in game; when the organiser is offline, suggests whispering the next person).
- **Chat lines** in the addon's style with clickable links (`|H` links, V47): reminder, someone answered (in game or on Discord), starting now, on another character, ping queued, runs updated. Each type can be turned off in settings.
- Done marking needs nothing new: the run log (CF-23) already records the dungeon, time and community members in the group; the site matches it (WEB-43).
- Tests: the reminder timer from UTC times, the friend states, the invite list (skips grouped friends), chat line settings.
- Built (2026-10-27): `core/RunStart.lua` (due reminders and starts between checks, states ready / other / offline / grouped / cant, invite and ping lists), `services/RunAlerts.lua` (a 15 s check only while runs exist; chat lines with addon links, each kind off in settings: `settings.runLines`), `ui/RunToasts.lua` (under `MinimapCluster`, 20 s, `runToasts`, chime `runSound` with the chat sound), `ui/StartPanel.lua` (opens by itself for the organiser at start; from the run: Invite all from 5 minutes before, Request invite for the others). Whisper opens the chat input with the text filled in (`ChatFrameUtil.OpenChat`, V72); Discord pings are pending `ping` items. The "someone answered" lines come from `RUNANSWER` and from newer runs data (answers that changed on runs you organise).

### CF-49 Runs v2 in game: level fit and roles
Nico tested Runs on the live site (2026-10-27) and the site moved to "Runs v2" (web repo WEB-47..50, boards `runs-v2-*`): any character can join, the role is picked apart from the character, and full roles get a reserve list. The game follows so it says the same as the site and Discord.
- `src/core`: `levelFit(level, min, max)` with the same kinds and labels as the web's WEB-47 (fits, `+N over`, `carry · +N` from 10 over, `N below`; 6+ below can only answer Maybe) and `rolesFor(class)` (Warrior tank and damage; Paladin and Druid tank, healer and damage; Priest and Shaman healer and damage; Mage, Warlock, Hunter, Rogue damage). Unit tested at every boundary and for every class.
- The Dungeons tab's runs (CF-46) and "what you could fill" use `levelFit`; slots show each sign-up's role, carries and reserves from `Runs.lua` when present.
- Sign up in game (CF-47): any character with its fit tag, then a role the class can play (default the addon's role for that character); a tooLow character only Maybe.
- Compat (rule 8): `Runs.lua` gets `role`, `fit` and the reserve state per answer as optional fields (from the web's WEB-44 feed, written by the uploader); without them the addon behaves as now. A pending answer gets an optional `role`; an older site ignores it, and the web's WEB-43 reads it when present. No stored data is reshaped, so no migration step; no sync message changes meaning (a role in run sync is a new optional field).
- Tests: the fit labels and role lists, slots from a `Runs.lua` with and without roles, a pending answer with a role.
- Decided with Nico (2026-10-28): the fit label on each character in Answer, with its note; a character 6+ below picks only Maybe (I'm in greyed); a role row with the class's roles in Answer and Plan a run; a reserve takes no slot and is listed under the slots; the slot status shows the fit when not "fits"; "fits damage" only for suggested characters in a role the class can play, "Close" for low ones and carries; the addon's own fit before the file's; the uploader's UP-12 copies `fit` and `reserve`.
- Done (PR #81): `PlannedRuns.levelFit`, `rolesFor`, `canPlay`, `defaultRole`, `fitOf`, `reserves`; `fit` and `reserve` in `validate`; `slots`, `youFit` and `close` by levelFit and roles; the role row and fit labels in `ui/RunDialogs.lua`; the fit status and reserve line in `ui/DungeonsTab.lua`. Busted and luacheck run locally (no Actions minutes).

### CF-50 Any level may answer I'm in
Nico (2026-10-28, after testing the live site v0.4.0 and bot v0.2.0; the web's rule "recommend, never restrict", web `docs/DESIGN.md` §8, WEB-52): a character 6 or more levels below may answer I'm in, with its "N below" and "This will be tough."; it is still never suggested or "Close".
- Done (PR #84): `PlannedRuns.levelFit` gives `tooLow` (and an unknown level) `canPick = true` and the tough note; `close` lists 1-5 below and carries by kind, so nothing new shows there; `ui/RunDialogs.lua` no longer switches to Maybe or greys out I'm in, and shows the note.
- Compat (rule 8): nothing stored or sent changes shape. An older addon receiving a run with an I'm in from a 6+ below character (through the site's `Runs.lua` or run sync) shows it as any I'm in; an older site refused such an answer (`out_of_range`, kept in the game's `received` list as applied-or-refused like any item), the site from WEB-52 on accepts it. Busted and luacheck run locally (no Actions minutes).

### CF-51 Carry friends' asks
Decided with Nico (2026-10-28): an ask with "Also post on Discord" reached the site only after the asker's own `/reload` within 10 minutes. From now on every friend's file carries it (web WEB-53).
- The ASK sync message gets optional `post = true`, `item` (the asker's Pending item id), `guid` and `role` when "Also post on Discord" was ticked (pv 1, `docs/SYNC.md`), and goes to every online peer with the addon (Nico: everyone carries it); only peers in range get the "asks: … now?" line, the rest keep it silently.
- Each receiver keeps it as a Pending `ask` item with the asker's id, `at`, guid, name, role, note and BattleTag, within `ASK_EXPIRE`, once (by id); no reload prompt: it goes with the next `/reload` or logout. `Pending.confirm` drops it when the site's `received` lists it.
- Your in-game answer to a posted ask is also kept as a Pending `askAnswer` item (`ask`, `answer` in/maybe/cant, guid, name, role), one per ask, pruned with the ask's 10 minutes.
- Rule 8: no stored reshape (a new Pending kind, optional fields on a Pending ask and on ASK); `Compat_spec` stays green. An older site would take a carried ask as the carrier's own, so the site's WEB-53 goes live first. Busted and luacheck run locally (no Actions minutes).
- Done (PR #TBD): `GroupAsk.message` / `cleanAsk` (the post fields), `GroupAsk.peers`, `Pending` (`askAnswer`, once by id), `Planner.carry` and `Planner.askAnswer`, `GroupAsks` (send to every peer when posted, carry, the silent case, keep your answer), the Ask now dialog makes the Discord item first. VERIFY.md "CF-51".
