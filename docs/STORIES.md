# Backlog

Build order: CF-01, 03, 05, 06, 07, 08, 12 (usable solo), 09, 10, 11 (sync), 17, 13, 14, 15, 16, 18, 04, 02.
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

## E2 Community

### CF-05 Community selection
- AceConfig dropdown lists subscribed **character** communities by name (decided in CF-05: guild and Battle.net communities excluded, since membership must be per character with GUIDs). Also in the Blizzard settings panel; `/cf settings` opens it.
- Selection stored in `settings.clubId`, survives reload.
- Auto-select (added in CF-12 feedback): with nothing selected, the only character community is selected, or the one you just joined; a chat line says which.
- If the stored club no longer exists: selection cleared, one chat notice "Your community is no longer available. Select one with /cf settings." The main window empty state follows in CF-12.

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
- Input: members, current friends (BattleTag set), people, presence, self, nicknames. Output view model `{ people = [ {bt, displayName, online, currentChar, chars=[...]} ], unlinked = [...] }`.
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

### CF-11 Sync flow
- HELLO / REQ / RECORD as in ARCHITECTURE.md, with per-peer dedupe (60 s) and debounce (5 s).
- Merge accept rules unit tested: wrong sender BattleTag rejected, older or equal version rejected, spoofed `bt` rejected, unknown `pv` rejected.
- Outgoing RECORD contains only own characters that are current community members (unit test).
- Manual (2 clients): friend levels up, your window shows the new level within ~10 s. Friend logs in on a community alt, it appears under them.

## E5 UI

### CF-12 Main window
- `/cf` and the minimap button toggle a movable, resizable window; position and size saved.
- People section: header per person (display name, BattleTag, online dot plus current character). Expandable to character rows: class-colored name, level, ilvl, professions (rank/max), realm, "Online" or last seen.
- Unlinked section: community data only (name, class, level, zone if online).
- Renders from the Linker view model only. Refreshes on change events, no polling.
- Empty states: no community selected; no linked people yet.
- Decided in CF-12: AceGUI window, draft B layout: tree left (people with online dot, expandable to class-colored characters, Unlinked group), detail right (person card: name, BattleTag, status, character list; character card: class, owner, status, Level / Item level / Last seen boxes, professions with bars). New people start expanded; expansion, selection and tree width are saved (`settings.tree`). No realm shown (one ruleset). Minimap: left-click window, right-click settings, hide toggle. `/cf` toggles the window, `/cf help` lists commands. Round 3: green dot on the character a person is playing; stats as plain text; Professions and Talents (placeholder until CF-18) side by side; offline status shows the last zone seen in the community (`locations`, local only), the character and the time.

### CF-13 Nicknames
- Right-click person header: "Set nickname" (input popup) and "Clear nickname". Local only, stored in `nicknames`.
- Display uses the priority rule everywhere (window, tooltip, notifications).

## E6 Tooltip and notifications

### CF-14 Unit tooltip
- Hovering a player unit whose GUID is linked adds: `<display name> (<BattleTag>) · N characters`.
- Unlinked community member: `CommunitiesForever member`.
- Implemented via TooltipDataProcessor behind an existence check (V6).

### CF-15 Login notifications
- When a linked person comes online in Forever or switches character: chat message `Sjaak is online on Garraka Doombringer (Mage 11)`.
- Only for people linked in the selected community. Not for yourself. No repeat for the same person within 30 s.
- Toggle in settings (default on).

### CF-16 Level-up announcements
- When a linked person's character in the selected community levels up, show a chat line: `Sjaak's Garraka Doombringer reached level 12`.
- Detected on the receiving side: an accepted RECORD whose character `level` is higher than the stored one. No new message type and no protocol change.
- Only for characters visible and linked per the core rules. Not for yourself. No message for characters seen for the first time.
- Toggle in settings "Announce friends' level-ups" (default on), separate from login notifications.
- Unit tests: level increase announces; same or lower level, new character, own record, unlinked character do not.
- Manual (2 clients): friend levels up; within ~10 s the line appears in your chat.
- Scope (accepted): only reaches people who are your Battle.net friends and run the addon (V1 has no relay).

### CF-17 Alts outside the community
- Setting "Share alts outside the community" (default on), stored in `settings`. On: the outgoing RECORD contains all own characters. Off: only current community members (CF-11 behavior). Changing it bumps the version and triggers a debounced HELLO.
- Receiver (Linker): a character from a record that is not a member of the selected community is shown only as a non-member alt, under its owner, if the owner is a current friend with at least one visible, linked member character. Otherwise it is ignored. It never appears in Unlinked.
- Membership is always decided by the receiver's own community data, never by the sender.
- UI: non-member alts are listed after the person's community characters, dimmed and tagged "not in community".
- Unit tests (Linker): non-member alt shown under a person with a member character; hidden when the person has no member character; hidden for a non-friend; a character that joins the community becomes a normal member row. Sender filter respects the setting both ways.
- Manual (2 clients): the friend has an alt that is not invited; with the setting on it shows dimmed under them; after they turn the setting off it disappears.
- Privacy note: default on means alts are shared with Battle.net friends who run the addon and are in the community, unless the owner turns it off.

### CF-18 Talents and role (future)
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
