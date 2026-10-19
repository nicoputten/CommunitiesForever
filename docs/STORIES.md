# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-27 (after V47 and V48), CF-28 (after V49 to V52), CF-02 (part 2: tag workflow, needs the `CF_API_TOKEN` secret).

## E0 Foundation

### CF-02 Release pipeline
- Pushing a git tag `v*` runs the BigWigs packager and uploads to CurseForge (Forever flavor) using the `CF_API_TOKEN` secret. CurseForge project ID in the TOC (`## X-Curse-Project-ID`).
- Still open (part 2, once the `CF_API_TOKEN` secret exists): the tag workflow itself.
- Untagged pushes produce no release.
- Done in part 1 (PR #21, merged without the token): project ID 1752013 in the TOC, zip with forward-slash paths, campfire logo in `docs/logo/`, and the released files contain no personal info. Author `Vestras` (TOC and LICENSE), generic examples in `src` comments, hand-written `CHANGELOG.md` (`manual-changelog` in `.pkgmeta`) instead of a changelog built from commit messages. `tests/spec/Release_spec.lua` fails on banned names in the released files. The repo stays private; its history is unchanged.
- Manual: install via the CurseForge app; publishing a new tag delivers an update.
- The package contains only the addon: `.pkgmeta` ignores tests, tools, docs, `VERIFY.md`, `CLAUDE.md` and the CI config. Check: unzip the built package and list its files.

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

## E10 Community transport

### CF-28 Sync with the community, no Battle.net friendship needed
- Goal: everything that works between Battle.net friends (records with professions, talents, quests and activity; login notices; level-ups; group asks) also works between community members who run the addon but are not each other's Battle.net friends.
- Decided: **both transports**. Battle.net stays for friends (bigger messages, cross-faction, reliable online status); the community transport reaches every member running the addon. A record arriving both ways is merged as today (newest version wins).
- Decided: **random account ID** instead of the BattleTag for people who are not your friends. Each account creates a random ID once (`self.accountId`, saved) and sends it with its record; the BattleTag is only sent to Battle.net friends. Characters group under the account ID; for friends the BattleTag stays the link to Battle.net presence. Data model: `people` keyed by account ID (records from before CF-28 are re-keyed when their owner's next record arrives).
- Transport (decided after V49/V50): addon messages (`C_ChatInfo.SendAddonMessage`, prefix registered as today): a broadcast in the community channel if addons may send there (V49), else a whisper to each online member running the addon (whispers verified). Messages are at most 255 bytes (V50: exact limit and throttle), so records go in small chunks through a rate-limited queue (larger records take longer, a small community stays fine).
- Discovery: on login and on joining the community, a HELLO goes out on the community transport; members running the addon answer, so each client knows who to send to. A BYE on logout (best effort).
- Trust (as relay, CF-20): only records sent by a character that is a member of the selected community are accepted, and the record must contain the sending character; a record never replaces one with a newer version (owner wins).
- Online status: Battle.net decides for friends (CF-15 fix); for others the community presence, corrected by HELLO/BYE (V52: how stale the community presence gets after a logout).
- Cross-faction: whispers most likely do not cross factions (V51); members of the other faction are then reached through Battle.net (friends) or relay only.
- Unit tests (pure core): account ID creation and re-keying; chunking at the community message size; accept rules (sender in community and in the record); online status from presence plus HELLO/BYE.
- Manual (2 accounts that are **not** Battle.net friends, same community): both see each other's characters grouped with professions and talents; a level-up line arrives; a group ask (CF-27) reaches the other one.
