# Backlog

Build order: CF-01, 03, 05, 06, 07, 08, 12 (usable solo), 09, 10, 11 (sync), 17, 20, 21, 14, 15, 16, 18, 19, 04, 02. (CF-13 dropped.)
Each story: criteria are testable. "Manual" items go into VERIFY.md.

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
- Untagged pushes produce no release.
- Manual: install via the CurseForge app; publishing a new tag delivers an update.

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
