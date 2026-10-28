# Sync and relay: technical reference

How CommunitiesForever clients exchange data: the messages and every field in them, when messages are
sent, what the receiver checks, and how much traffic that causes. Written from the code as of CF-28
(`src/core/Protocol.lua`, `Merge.lua`, `Identity.lua`, `Snapshot.lua`, `Feed.lua`, `src/services/Sync.lua`,
`Messenger.lua`). Design rules live in `ARCHITECTURE.md`; this file is the reference for the wire.

## 1. Short answer: how often do clients talk?

- **There is no polling.** No timer asks "do you have something new?" every few minutes. Every message is
  caused by an event: a login, a friend or community member coming online, or your own data changing.
- **What travels often is small.** A `HELLO` says "my record has version V, and these are the versions of
  the records I can pass on". It is one message part.
- **The big message only goes when needed.** A peer that sees a newer version than it has sends `REQ`,
  and only then the full record (`RECORD`) is sent, to that peer only.
- **The version is a timestamp.** `version = max(previous + 1, server time in seconds)`, so newer always
  means bigger, across clients.

```
 You change (level, gear, quest log, ...)            A friend / community member
 ──────────────────────────────────────              ───────────────────────────
 version 1730000000 → 1730000420
 (5 s quiet) ── HELLO {ver 1730000420} ───────────▶  stored 1730000000 < 1730000420
                                                      ◀── REQ {want = nil} ──
 ── RECORD {all your characters} ─────────────────▶  merge per character, store
                                                      (5 s quiet) HELLO to its other peers,
                                                      with known[you] = 1730000420 (relay)
```

## 2. Transports and wire format

| | Battle.net | Community (CF-28) |
|---|---|---|
| Who | Battle.net friends online in Forever | Members of the selected community running the addon, not reached over Battle.net |
| Send | `BNSendGameData(gameAccountID, "CommForever", part)` | `C_ChatInfo.SendAddonMessage("CommForever", part, "WHISPER", characterName)` |
| Receive | `BN_CHAT_MSG_ADDON`; sender → BattleTag via Battle.net presence | `CHAT_MSG_ADDON` channel `WHISPER`; sender name → community member GUID |
| Part size | 3500 bytes | 255 bytes (longer is cut silently, V50) |
| Rejected | senders that are not friends online in Forever | senders that are not members of the selected community |

**Hidden community channel (CF-31):** every client in the community joins a hidden chat channel named
`cf` + a hash of the community name (`Chat.syncChannel`), takes it out of every chat window and hides its
join lines. Only **HELLO** and **BYE** go there, as one `SendAddonMessage(..., "CHANNEL", index)` that every
member on the channel receives (and only when the message fits one 255-byte part: a lost part of a
broadcast could not be asked again). Everything aimed at one peer (REQ, RECORD, MISS, ASK, ANSWER, PING)
stays a whisper. Receiving works like a whisper: the sender name must be a community member; your own
broadcast coming back is dropped.

| Fallback | What happens |
|---|---|
| A member said `ch` = our channel in their HELLO | they get our HELLOs on the channel only |
| A member without `ch` (older client, or their join failed) | they are whispered as before |
| Someone new says HELLO | always answered by whisper (they may have joined after our last HELLO) |
| We could not join, or a HELLO needs more than one part | everyone is whispered as before |

**Encoding of one message:** Lua table → `LibSerialize:Serialize` → `LibDeflate:CompressDeflate` →
`LibDeflate:EncodeForWoWAddonChannel`. Every message carries `pv = 1` (protocol version). A message with
another `pv` is dropped and shown once as "a friend uses a newer version". The examples below are written
as JSON for readability; on the wire they are compressed Lua tables.

**Parts:** the encoded text is split into parts with the header `<msgId>:<part>:<total>:`, for example
`3f2ax1a:2:5:` followed by the slice. `msgId` is per sender and session (a session prefix from the server
time plus a counter). Parts may arrive in any order; duplicates are ignored.

**Missing parts (CF-28 part 2a):**

| Rule | Value |
|---|---|
| The sender keeps the parts it sent | 60 s |
| A message incomplete and quiet this long gets a `MISS` | 3 s |
| `MISS` per message, at most | 2 |
| Resends per message, at most (only to whoever it was sent to) | 2 |
| Part numbers in one `MISS`, at most | 40 |
| An incomplete message is dropped this long after its last part | 30 s |

A `MISS` is one raw line, not an encoded message: `!M:<msgId>:3,7`. It can never be mistaken for a part
(a part starts with `<msgId>:<number>:<number>:`); older clients drop it as malformed.

**Pace:** all parts go through one queue, 0.2 s apart across all targets (`settings.sendInterval`),
held while you are in combat and sent after it.

## 3. Messages

Keys are person keys: a BattleTag (`"Ann#1234"`) over Battle.net, or `"aid:<accountId>"` (a random
12-character hex ID per account) over the community. **No BattleTag ever travels over the community**;
people whose account ID is unknown are simply not mentioned there.

### HELLO: "this is my version, and these are the versions I can pass on"

```json
{ "t": "HELLO", "pv": 1,
  "bt": "aid:3f9c0a7e21bd",
  "ver": 1730000420,
  "known": { "aid:8d0e44c1a9f2": 1729990011, "aid:c71b02e6d3aa": 1729871234 } }
```

| Field | Meaning |
|---|---|
| `bt` | Sender's key (BattleTag over Battle.net, `aid:` key over the community) |
| `ver` | Version of the sender's own record |
| `known` | `{ key = version }` of records the sender holds and may relay: people with a character in the sender's selected community |
| `ch` | Optional, community only (CF-31): the hidden channel the sender listens on. Members that sent it get later HELLOs on the channel instead of a whisper each. Older clients send none and ignore it (rule 8) |
| `ru` | Optional (CF-46): updatedAt of the sender's planned runs, 0 when it has none. Older clients send none (and get no runs) and ignore it (rule 8) |
| `av` | Optional (CF-35): the sender's addon version (TOC `Version`, e.g. `v0.3.1`). A newer **release** than yours gives one chat line per session; dev builds are never compared. Older clients send none and ignore it (rule 8) |

The receiver compares: `ver` newer than stored → `REQ` for the sender's own record. A `known` entry newer
than stored → `REQ` for that record (relay). Over the community, a HELLO from an unknown member is also
answered with your own HELLO, so both sides know each other.

Over the community, a HELLO from a character that belongs to a person you know **without** an account ID
(their record reached you through a relay, which carries none) teaches you that account ID
(`Identity.bindAccountId`): the game names the sending character, and that character is theirs. A known
account ID is never overwritten, and one that another person already has is never taken. Anything stored
under that `aid:` key is then merged into the person (`Merge.absorb`), and their newer record is asked for.

### REQ: "send me this record"

```json
{ "t": "REQ", "pv": 1, "bt": "aid:8d0e44c1a9f2", "want": "aid:c71b02e6d3aa" }
```

`want` missing (nil) = the receiver's own record. `want` = a key = a record the receiver holds (relay).

### RECORD: a person's data

```json
{ "t": "RECORD", "pv": 1,
  "bt": "aid:3f9c0a7e21bd",
  "aid": "3f9c0a7e21bd",
  "displayName": "Ann",
  "version": 1730000420,
  "invite": { "clubId": "23125681", "code": "ab12cd34", "setAt": 1729000000 },
  "chars": {
    "Player-4619-0A1B2C3D": {
      "guid": "Player-4619-0A1B2C3D", "name": "Ann Example", "classFile": "MAGE", "raceID": 2,
      "level": 24, "faction": "Horde", "realm": "Classic Beta PvP", "ilvl": 21,
      "professions": { "186": { "name": "Mining", "rank": 120, "max": 150 },
                       "185": { "name": "Cooking", "rank": 75, "max": 150 } },
      "talents": [ { "name": "Arcane", "points": 0 }, { "name": "Fire", "points": 15 },
                   { "name": "Frost", "points": 0 } ],
      "mainTree": 2, "autoRole": "dps", "roleOverride": null, "role": "dps",
      "quests": { "1654": { "title": "The Test of Righteousness", "area": "Shadowfang Keep", "dungeon": true } },
      "pvp": { "hk": 140, "rank": 3, "rankName": "Sergeant", "weekKills": 12, "weekHonor": 310,
               "deaths": 57, "duelsWon": 4, "duelsLost": 2 },
      "updatedAt": 1730000420, "lastPlayed": 1730000100
    }
  },
  "removed": { "Player-4619-0F0F0F0F": 1729500000 },
  "feed": {
    "20744": {
      "Player-4619-0A1B2C3D": {
        "name": "Ann Example", "classFile": "MAGE", "at": 1730000400,
        "levelFrom": 22, "levelTo": 24,
        "quests": { "Silverpine Forest": 6 },
        "ranks": { "Mining": "Journeyman" }, "learned": { "Cooking": true },
        "runs": [ { "name": "Shadowfang Keep", "kind": "party", "bosses": 3, "won": null,
                    "with": [ "Player-4619-0B0B0B0B" ] } ],
        "kills": { "Hillsbrad Foothills": 3 },
        "deaths": [ { "t": 1730000300, "zone": "Hillsbrad Foothills", "cause": "player" } ],
        "duels": [ { "t": 1730000200, "won": true, "vs": "Bob Example" } ],
        "loot": { "rare": 2, "epic": [ { "id": 12784, "name": "Arcanite Reaper", "slot": "INVTYPE_2HWEAPON",
                                         "level": 60 } ] },
        "notable": { "14342": 2 },
        "gold": { "gained": 15230, "spent": 4100 },
        "sessions": [ { "from": 1729990000, "to": 1730000400 } ],
        "groups": { "Player-4619-0B0B0B0B": true },
        "pvpKills": [ { "t": 1730000250, "zone": "Hillsbrad Foothills", "name": "Grim Tusk", "lvl": 26, "myLvl": 24,
                        "class": "WARRIOR", "race": "Orc", "rank": 2, "solo": true } ]
      }
    }
  } }
```

| Field | Meaning |
|---|---|
| `bt` | Whose record (key). Over the community always an `aid:` key |
| `aid` | The owner's account ID, only in the owner's own record (not in relayed copies); links a BattleTag to its community key for friends |
| `displayName` | Name chosen in settings (plain text, max 24 characters) or missing |
| `version` | Record version (see section 5) |
| `invite` | Shared community invite link (CF-21), only from owners, leaders and moderators |
| `chars` | **All** own characters by GUID, also those outside the community |
| `chars.*.updatedAt` | When the owner last saw this character change: the per-character merge key |
| `chars.*.lastPlayed` | Last login on that character (updated without a version change) |
| `chars.*.quests` | Quest log: `{ questID = { title, area, dungeon } }`, IDs only, no progress |
| `chars.*.pvp` | CF-52, optional: `hk` lifetime honorable kills, `rank` PvP rank number (0 none, 1 to 14) and `rankName` the game's name for it, `weekKills`/`weekHonor` this week's, and the addon's own lifetime counters `deaths` (or the game's death statistic when higher), `duelsWon`, `duelsLost` (counted since the addon recorded them). Each field missing = unknown |
| `chars.*.riding` | CF-53, optional: riding skill 0, 75 or 150 (missing = unknown) |
| `removed` | Only in relayed copies: characters the owner dropped, with the time |
| `feed` | Activity of the last 7 realm days by day number and character; always sent (CF-58). Missing = unknown (relayed). `false` comes only from released clients that had "Share my activity" off: it means nothing was sent, and the stored feed stays |
| `feed.*.*.at` | When the entry last changed: the feed merge key |
| `feed.*.*.runs` | Dungeons, raids, battlegrounds (CF-23); `with` = companions' GUIDs (community members only) |
| `feed.*.*.kills` | CF-52: honorable kills by the zone where the kill counter rose (battlegrounds by their name) |
| `feed.*.*.deaths` | CF-52: `{ t, zone, cause }`, at most 50; `cause` one of `fall`, `fire`, `lava`, `drown`, `fatigue`, `player`, `creature`, `other` (unknown received causes become `other`) |
| `feed.*.*.loot` | CF-53: `rare` = blue items looted or received as quest rewards; `epic` = purple (or better) ones, at most 20, `{ id, name, slot, level }` with the `INVTYPE_*` slot (missing for items you can't equip) and the character's level then |
| `feed.*.*.notable` | CF-53: `{ [itemID] = n }` for the watch list (`Loot.WATCH`): created (Arcanite Reaper, Arcanite Bar, Mooncloth, Devilsaur Gauntlets and Leggings) or looted (Speckled Tastyfish, Arcanite Fishing Pole, Hook of the Master Angler). Numeric keys |
| `feed.*.*.gold` | CF-53: `{ gained, spent }` in copper that day. Never shown as an amount |
| `feed.*.*.sessions` | CF-53: `{ from, to }` server times, at most 20, under the day the session started; `to` moves every 5 minutes and at logout, a login within 5 minutes continues the session |
| `feed.*.*.groups` | CF-53: `{ [guid] = true }` characters of the selected community you were in a group with |
| `feed.*.*.pvpKills` | CF-55b: one entry per honorable kill, at most 100 (`kills` keeps counting past it): `t`, `zone`, `name` (the victim's full name from the honor message; missing for a kill only the counter showed), `lvl` (-1 skull), `myLvl`, `class` and `race` tokens, `rank` (number), `solo`, `bg`. Victim fields come from the honor message or from what was seen of that player (target, mouseover, nameplate) in the 10 minutes before; each is missing when unknown. Received: tokens checked (`^%u+$`, `^%a+$`), levels -1 to 100, rank 0 to 14 |
| `feed.*.*.duels` | CF-52: `{ t, won, vs }`, at most 50, every duel of that character; `vs` = the opponent's full name as the game gives it (never split) |

Not in a record: zone, online status and current level of community characters: those come live from the
community (`C_Club`) and Battle.net presence.

### BYE (community, CF-28)

```json
{ "t": "BYE", "pv": 1 }
```

Sent on logout to community peers (best effort: the game may close before it goes out). The receiver shows
the sender's character offline until its next HELLO.

### RUNS and RUNREQ (CF-46, planned runs)

```json
{ "t": "RUNREQ", "pv": 1 }
{ "t": "RUNS", "pv": 1,
  "runs": { "v": 1, "updatedAt": 1793120000, "reminderMinutes": 30,
            "runs": [ { "id": "r-102", "dungeon": "smlib", "startsAt": 1793210400, "state": "open", "source": "site",
                        "organiser": { "battleTag": "Ada#1001", "name": "Ada Lovewell" },
                        "answers": [ { "battleTag": "Ada#1001", "name": "Ada Lovewell", "answer": "in", "role": "tank" } ] } ] } }
```

`runs` has the shape of `CF_RUNS` (ARCHITECTURE "Planned runs file"), since CF-49 with the optional `fit`
and `reserve` per answer (older addons drop them and show a reserve as Maybe). A HELLO whose `ru` is older than ours
gets `RUNS`; newer gets `RUNREQ`, answered with `RUNS`. Each at most once per target and updatedAt per 60 s.
The receiver checks the runs like the file (`PlannedRuns.validate`) and keeps them when their `updatedAt` is
newer than its own and at most 5 minutes ahead of server time; then it sends a HELLO with the new `ru`. Over
the community every `battleTag` is left out. Not sent during an encounter, a keystone or a PvP match
(`Instance.messagingRestricted`, V70): tried again 30 s later.

### RUNANSWER (CF-47, an answer to a run)

```json
{ "t": "RUNANSWER", "pv": 1, "run": "r-102", "answer": "maybe", "guid": "Player-1-0000AAAA", "name": "Ada Lovewell",
  "role": "heal" }
```

Sent once, right after you answer a run in game, to the run's organiser when they are online (a Battle.net
friend by BattleTag, or a community peer on the organiser's character). The organiser keeps it in memory and
shows it until the site's runs have it. Cleaned like the runs file; ignored unless the receiver organises the
run. The answer also waits in `global.pending` and reaches the site after `/reload`.

### ASK and ANSWER (CF-27, "Who's up for it?")

```json
{ "t": "ASK", "pv": 1, "id": "17300004201",
  "dungeon": { "id": "dm", "name": "The Deadmines", "min": 17, "max": 26 },
  "from": "Ann", "char": "Ann Example", "at": 1730000420 }
{ "t": "ANSWER", "pv": 1, "id": "17300004201", "answer": "join", "from": "Ben", "char": "Ben Example" }
```

Sent only to peers with a character in range; `answer` is `join`, `later` or `no`. ASK may carry `note` (CF-47, what the asker typed in Ask now); older clients ignore it.

CF-51 (optional fields within pv 1): when the asker ticked "Also post on Discord", ASK carries `post = true`, `item` (the asker's Pending item id, `[%w-:.]`, at most 64), `guid` and `role` (`tank` / `heal` / `dps`) of the asker's character, and is sent to **every** online peer with the addon, not only those in range:

```json
{ "t": "ASK", "pv": 1, "id": "17300004201", "post": true, "item": "k3f9c0a7e21b-1730000420-1",
  "guid": "Player-1-0000AAAA", "role": "tank", "at": 1730000420,
  "dungeon": { "id": "dm", "name": "The Deadmines", "min": 17, "max": 26 }, "from": "Ann", "char": "Ann Example" }
```

Every receiver keeps it as a Pending `ask` item with the asker's `item` id, `at`, `guid`, `char` (as `name`), `role`, `note` and the sender's BattleTag, within the 10 minutes (`Pending.ASK_EXPIRE`), so the next `/reload` or logout of any friend brings it to the site (web WEB-53), which makes it once. Only receivers with a character in range get the "asks: … now?" line; the rest keep it silently. An answer to such an ask is also kept as a Pending `askAnswer` item (`ask` = the `item` id). Older clients ignore the new fields, but show the line to anyone who gets the ASK, also out of range (Nico, 2026-10-28: everyone runs the latest version).

### PING and PONG (`/cf ping`, testing)

```json
{ "t": "PING", "pv": 1, "from": "Ann Example", "at": 1730000420, "padding": "xxxx…" }
{ "t": "PONG", "pv": 1, "from": "Ben Example", "at": 1730000420, "size": 4000 }
```

## 4. When messages go out

| Event | What is sent | To whom |
|---|---|---|
| Login / `/reload` | HELLO | Every friend online in Forever, every community member online not reached over Battle.net |
| A friend comes online in Forever | HELLO (forced) | That friend |
| The community member list changes (someone comes online) | HELLO, 5 s debounced | Everyone; the 60 s dedupe skips peers that already got the same HELLO |
| Your record changes (see section 5) | HELLO, 5 s after the last change | Everyone online |
| A record from someone else was accepted | HELLO, 5 s debounced | Everyone (now you can relay it) |
| A HELLO shows a newer version | REQ | That peer only |
| A REQ arrives | RECORD | That peer only |
| A HELLO shows older or newer planned runs (`ru`, CF-46) | RUNS or RUNREQ | That peer only |
| Newer planned runs were accepted | HELLO, 5 s debounced | Everyone |
| A message stays incomplete for 3 s | MISS | Its sender only |
| Logout | BYE | Community peers |
| `/cf sync` | HELLO (forced) | Everyone online |

**Dedupe:** the same HELLO (same version and the same `known` list) goes to the same peer at most once per
60 s; the same REQ (same record, same version) at most once per 60 s.

**Example cost:** you are on with 4 people online and level up. After 5 s: 4 HELLOs (one part each). Each
of the 4 sends one REQ (one part). You send 4 RECORDs (a few parts each, see section 7). Each of them then
sends one HELLO to its other peers; those that already have your new version from you send no REQ.

## 5. What changes the version (and so causes traffic)

The version bumps only when a synced field of the character you are on really changes
(`Snapshot.equal`):

| Bumps the version | Does not |
|---|---|
| Level, race, faction, realm, item level (floored, 2 s debounce on gear changes) | Zone, online status, position |
| A profession learned, a skill point, a new rank | Quest progress (only the set of quest IDs counts) |
| Talent points (2 s debounce) or your role override | `lastPlayed` (login and logout) |
| A quest accepted, abandoned or turned in (2 s debounce) | Logging in on the same character with nothing changed |
| Display name, invite link | |
| Activity feed changes: at most one bump per 60 s (questing does not sync per turn-in) | |
| A new PvP rank (CF-52) right away; kills, honor, deaths and duels with the feed's 60 s bump | |
| Loot, gold and groups (CF-53) with the feed's 60 s bump; the riding skill like other snapshot fields | A session's start and end (CF-53: they travel with the next bump) |

## 6. What the receiver checks (accept and merge)

**Sender:**
- Battle.net: the sender is a friend online in Forever, identified by Battle.net (cannot be faked).
- Community: the sender is a member of the selected community; its character name maps to a GUID.

**Accept** (`Merge.accept`), for a record about someone:
1. Never your own record, from anyone.
2. From its owner: newer than what is stored, or what is stored is a relayed copy (the owner's own record
   always replaces a relayed one). Over the community a record counts as the owner's own only when it
   lists the sending character **and** that character already belongs to that person (or the person is
   new); otherwise it is treated as relayed, so a learned account ID cannot be used to pose as someone.
3. Relayed: newer than stored, the version at most 5 minutes ahead of server time, and at least one
   character in your selected community.

**Merge** (`Merge.store`), per character:
- From the owner: the owner's record decides its characters (a wrong level can be corrected that way);
  characters it no longer lists are removed and remembered with the time.
- Relayed: per character the copy with the newer `updatedAt` stays; a relayed copy never lowers a level;
  `updatedAt`, removal times and feed `at` more than 5 minutes in the future are ignored; a removal only
  takes away copies not newer than it.
- Activity feed: per day and character, the entry with the newer `at` stays; on an equal `at` the stored one
  (CF-52: a copy relayed by an older client lacks the newer fields).
- `chars.*.pvp` (CF-52): only the expected fields, whole numbers ≥ 0, rank at most 14.
- All received text is cleaned: color, link and texture codes removed; names, feed sizes and days capped.

**Keys:** a Battle.net record that shows an `aid` merges an earlier `aid:` entry of the same account into
the BattleTag, so a person never shows twice.

## 7. Sizes and limits

| | Value |
|---|---|
| One HELLO | One part (a few hundred bytes with a `known` list of ~10 people) |
| One character in a record | Roughly 200–800 bytes before compression; most of it is the quest log (titles) |
| A record with 5 characters, full quest logs and a week of activity | Roughly 2–5 KB compressed: 1–2 Battle.net parts or ~10–20 community parts |
| Send pace | One part per 0.2 s across all targets: 20 community parts take ~4 s |
| Feed kept | 7 realm days; received feeds are capped (days, characters per day, zones, runs, 50 deaths and 50 duels, 100 raw kills) |
| A week of raw kills at the cap (7 × 100) | Under 8 KB encoded (about 6.3 KB measured, CF-55b): 2 Battle.net parts or ~28 community parts |

The numbers in this table are estimates from the field sizes, not measurements.

## 8. Known limits and possible improvements

- **Full records:** a RECORD always carries all characters, also when one quest changed. Sending only the
  characters newer than the version the peer has ("deltas") would cut most parts. Not built yet.
- **No periodic healing:** a record that is lost even after two resends waits for the next HELLO
  (the next change or login on either side). A quiet HELLO every few minutes would close that gap at the
  cost of one small message per peer.
- **`known` grows with the community:** every HELLO lists every relayable person. Fine for a group of
  friends; for a large community it would need limiting.
- **Community broadcast (CF-31):** HELLO and BYE go out once on the hidden channel; REQ and RECORD are
  still one whisper per peer that asks (a broadcast would not save anything there).
- **BYE is best effort:** if it does not go out, the community presence (which can lag, V52) decides
  until the next HELLO.
