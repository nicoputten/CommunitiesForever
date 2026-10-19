# Architecture

## Core rules
1. A character is **visible** only if its GUID is a member of the selected community.
   Exception (CF-17): a **non-member alt** is visible if it arrived in its owner's record AND the owner has at least one visible, linked member character. It is shown under that person, marked "not in community", and never in Unlinked.
2. A visible character is **linked** to a person (BattleTag) only if either:
   - that BattleTag is a current Battle.net friend AND BNet presence showed them logged in on that character, or
   - that BattleTag is a current Battle.net friend AND their addon sent a record containing the character, or
   - (CF-20) a friend relayed that person's record and the character is in it. Trust is the community: the owner does not have to be your own Battle.net friend.
3. Visible but not linked: shown in the **Unlinked** section with community data only.
4. Records come from their owner over BNet, or (CF-20) relayed by a friend running the addon. Records are only accepted from current friends in Forever. A record from its owner always replaces a relayed copy; a relayed copy only replaces an older relayed copy, and never a version more than 5 minutes ahead of server time. Until CF-20 is built: owner only.
5. Only the owner changes their record. Version = `max(prev + 1, GetServerTime())`. Higher version wins (with the owner-first exception above).

Consequences:
- Transport is BNet only (`BNSendGameData`). Addon whispers are not used in V1.
- Membership is per character, not per account (verified). An alt that is not invited is only visible as a non-member alt of a person who has at least one member character (CF-17).
- Nothing depends on `clubId` being identical across clients (unverified). Filtering is by GUID membership.

## Layering
```
CommunitiesForever/
  CommunitiesForever.toc     ## Interface: 16001
  .pkgmeta  embeds.xml  .luacheckrc  .busted  LICENSE (MIT)
  Libs/                      packager externals, gitignored
  src/
    Core.lua                 AceAddon init, wiring, internal event bus
    core/                    PURE Lua, unit tested
      Store.lua              schema, defaults, migrations
      Merge.lua              record accept rules, version rules
      Linker.lua             visibility + linking -> view model (people, unlinked)
      Protocol.lua           encode/decode (LibSerialize + LibDeflate injected), chunk/reassemble
      Outbox.lua             outgoing chunk queue with send-rate limit
      Snapshot.lua           build and compare character snapshots
      Describe.lua           stable text output for debug commands (/cf self)
      Format.lua             view model -> tree nodes, detail cards, last seen, empty states
      Clubs.lua              selectable communities, stored-selection status
      Members.lua            member map by GUID, change compare
      Invite.lua             invite link parsing, newest invite, role check (CF-21)
      Talents.lua            talent split per Vanilla tree (columns of the C_Traits tree), auto role (CF-18)
      Onboarding.lua         which setup steps to show: first run, new steps, Community tab prompt (CF-26)
      GroupAsk.lua           "who's up for it?": recipients, throttle, expiry, cleaning, answer summary (CF-27)
      Dungeons.lua           dungeon planner: level ranges, candidates, group suggestion, calendar matching (CF-24)
      Feed.lua               activity feed: events from snapshot changes, per-day aggregation, clean, lines (CF-22),
                             runs and shared lines for runs done together (CF-23)
      Runs.lua               dungeon/raid/battleground run of the current character: start, bosses, companions,
                             match end, the 10-minute and boss rule (CF-23)
      Chat.lua               community chat: color, which messages alert, which tabs flash, tab name (CF-25)
      Friends.lua            BNet presence snapshot, online/switch/offline diff, presence links
    adapters/                WoW API wrappers only
      Events.lua             guarded event registration (C_EventUtils.IsEventValid)
      Timer.lua              C_Timer debounce
      SelfInfo.lua           Unit*, GetProfessions, item level
      Community.lua          C_Club (club list, members, club and member events)
      ChatFrames.lua         chat windows: community channel, color, flash, sound, new tab, add/remove channel (CF-25)
      Presence.lua           C_BattleNet friend accounts, BN events
      ChatLinks.lua          clickable addon chat links (|Haddon:CommunitiesForever:...|h), click dispatch (CF-27)
      Party.lua              invite request / invite by name / via Battle.net from a click (CF-27, guarded)
      GroupFinder.lua        the Group Finder's dungeon activities with level ranges (C_LFGList, CF-24)
      QuestieData.lua        dungeon quests from the optional QuestieDB addon, completed quests (CF-24, guarded)
      Calendar.lua           C_Calendar event list (this month and next), ToggleCalendar (CF-24, guarded)
      Instance.lua           GetInstanceInfo, group GUIDs, battleground winner/team, instance events (CF-23, guarded)
      Transport.lua          BNSendGameData, prefix, BN_CHAT_MSG_ADDON, combat state (thin)
    services/
      FeedTracker.lua        records own activity into self.feed, debounced version bump, share setting (CF-22)
      GroupAsks.lua          send asks, chat line + sound + [Join] [Later] [No], answers, invite links (CF-27)
      Planner.lua            calendar events for the Dungeons tab, sign-ups of planned runs (OpenEvent queue) (CF-24)
      ActivityTracker.lua    run in progress (db.global.runs), finished runs into the feed, /cf activity debug (CF-23)
      SelfTracker.lua        keeps own snapshot current (events, ilvl debounce)
      CommunitySelection.lua owns settings.clubId (account-wide); active() only if this character is a member
      CommunityChat.lua      community chat color (always), tab flash and sound, Community chat tab (CF-25)
      MemberTracker.lua      members of the selected community (FocusMembers, 1 s debounce)
      Invites.lua            shared invite link: set (owner/leaders/moderators), newest, post as chat link (CF-21)
      PresenceTracker.lua    friends in Forever, gameAccountID -> BattleTag, writes presence
      ViewModel.lua          gathers tracker + DB state, runs the Linker (UI input)
      Messenger.lua          send: encode, chunk, throttle, combat hold; receive: reassemble, decode, sender BattleTag
      Ping.lua               /cf ping test messages (PING/PONG)
      Sync.lua               HELLO / REQ / RECORD flow, dedupe, shared-set version bumps
      Notify.lua             login notifications in chat (30 s per person, settings.notifications)
    ui/
      MainFrame.lua          AceGUI Frame + TreeGroup (people/characters left, detail card right); tabs
                             Friends, Activity (CF-22) and Dungeons (CF-24)
      DungeonsTab.lua        Dungeons tab: dungeon list, suggested group, calendar events, copy fields (CF-24)
      Setup.lua              onboarding wizard and Community tab prompt (CF-26)
      Settings.lua           AceConfig options (Blizzard panel + /cf settings)
      Tooltip.lua            unit tooltip line "Name · N characters" (TooltipDataProcessor, cached lines)
      Minimap.lua            LibDataBroker launcher + LibDBIcon button
  tests/
    helpers.lua              loads addon files in TOC order with (addonName, ns) varargs
    mocks/wowapi.lua
    spec/*_spec.lua
  tools/FriendProbe/         diagnostic addon (not packaged)
  tools/*.ps1                setup-lua, fetch-libs, build (dev only)
  .github/workflows/         test.yml, release.yml
```

Module sharing: every file reads the WoW private addon table via `local ADDON_NAME, ns = ...` and registers on it (`ns.Store = Store`). `Core.lua` turns `ns` into the AceAddon object and exposes it as the `CommunitiesForever` global. Specs load files with `loadfile(path)("CommunitiesForever", ns)` (`tests/helpers.lua`), so core modules need no globals.

Internal event bus: AceEvent messages on the addon object (`SendMessage` / `RegisterMessage`), named `CF_*` and defined as constants in the emitting module (e.g. `SelfInfo.CHANGED`, `SelfTracker.UPDATED`).

Data flow: adapters emit internal events -> services and core compute -> Linker builds a view model -> UI renders the view model. UI never calls adapters for data.

## Libraries
Embedded via `.pkgmeta` externals: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, AceEvent-3.0, AceConsole-3.0, AceConfig-3.0, AceConfigDialog-3.0, AceGUI-3.0 (required by AceConfigDialog), LibSerialize, LibDeflate, LibDataBroker-1.1, LibDBIcon-1.0. Verify the external URLs when writing `.pkgmeta`. LibSerialize and LibDeflate are pure Lua and can be loaded directly in busted tests.

Optional, not embedded (CF-24): the **QuestieDB** addon (comes with Questie; `## OptionalDeps: QuestieDB`). When it is installed with contract 3 or later, the Dungeons tab reads every dungeon's quests from its public API (`LibQuestieDB`, `QuestDB`) at runtime; nothing of its data ships with this addon (it has no license). Without it, dungeon quests come from the community's quest logs.

UI choice: AceConfig for settings (also registered in the Blizzard settings panel). Main window: AceGUI `Frame` (move, resize, saved position and size via its status table) with a `TreeGroup`: people expandable to their characters on the left, a detail card on the right (decided in CF-12, draft B, replacing the earlier custom frame + ScrollBox plan: no unverified templates). Profession bars are inline textures. Each UI module that listens to internal messages uses its own AceEvent-embedded object, because AceEvent keeps one handler per object and message.

## Data model
SavedVariables `CommunitiesForeverDB`, AceDB `global` scope (account-wide).
```lua
global = {
  schemaVersion = 1,
  settings  = { clubId = nil, clubName = nil,        -- account-wide selection; name remembered for non-members
                notifications = true, minimap = {}, window = {}, tree = {},  -- window, tree: AceGUI status
                sendInterval = 0.2,                  -- seconds between outgoing chunks
                shareActivity = true,                -- CF-22: send the activity feed to friends
                chatColor = { r, g, b },             -- CF-25: community chat color (nil: default purple)
                chatAlert = true, chatSound = false, chatKeepGeneral = true,
                chatTab = { [guid] = true },         -- CF-25: characters with a Community chat tab
                activityDebug = nil,                 -- CF-23: /cf activity debug prints instance events
                onboarded, onboardedVersion,         -- CF-26: setup wizard done (Skip and close count)
                chatTabPrompt = { [guid] = true },   -- CF-26: no Community tab prompt on these characters
                groupAsks = true,                    -- CF-27: receive "who's up for it?" asks
                dungeonTree = {} },                  -- CF-24: Dungeons tab selection and list width
  self      = { battleTag, displayName, version, chars = { [guid] = Char },
                invite = { clubId, code, setAt },    -- CF-21: shared invite link (owner/leaders/moderators)
                feed = Feed },                       -- CF-22: activity feed, last 7 realm days
  people    = { [battleTag] = { displayName, version, receivedAt,
                                chars = { [guid] = Char }, via, invite, feed,      -- via: relayed by (CF-20); invite (CF-21); feed (CF-22)
                                removed = { [guid] = time }, feedOff } },          -- CF-28: dropped characters; feed not shared
  presence  = { [guid] = { battleTag, lastSeen } },  -- links observed via BNet presence
  locations = { [guid] = { zone, seenAt } },         -- last zone seen in the community, local only
  runs      = { [guid] = Run },                      -- CF-23: run in progress per own character, local only
}

-- CF-23: kind = GetInstanceInfo type; with = community members in the group (GUIDs); won: battleground.
Run = { name, kind = "party"|"raid"|"pvp", instanceID, day, startedAt, lastAt,
        bosses = { [encounterID] = true }, bossCount, with = { [guid] = true }, ended, won }

-- CF-22: [day] = realm day number (days since 1970-01-01), aggregated per character.
Feed = { [day] = { [guid] = { name, classFile, at, levelFrom, levelTo,
                              quests = { [zone] = count }, ranks = { [profession] = rank },
                              learned = { [profession] = true },
                              runs = { { name, kind, bosses, won, with = { guid, ... } } } } } }  -- CF-23

Char = {
  guid, name, classFile, raceID, level, faction, realm,
  ilvl,                                              -- equipped avg, floored; nil if API unavailable
  professions = { [skillLineID] = { name, rank, max } },
  talents = { { name, points } x3 }, mainTree,       -- CF-18: points per Vanilla tree, tree with most points
  autoRole, roleOverride, role,                      -- CF-18: guessed, player override, effective (tank/heal/dps)
  quests = { [questID] = { title, area, dungeon } },  -- CF-19: quest log, names only, no progress; area = log header
  updatedAt,                                         -- last synced-field change
  lastPlayed,                                        -- own chars: login/logout time (not compared, no bump)
}
```
- Zone and online state are NOT synced. They are live data from presence and C_Club.
- Bump `self.version` only when a synced field actually changes (Snapshot compare).
- Display name priority: owner's displayName > BattleTag name part (before `#`). (Local nicknames, CF-13, were dropped.)
- Text from other players is untrusted: `Merge.store` removes WoW escape sequences (`|`) from the display name and every string in received characters; display names are capped at 24 characters (CF-04).
- Sender always includes all own characters (decided in CF-17 testing; no setting). The receiver decides what to show (core rule 1), so the record does not depend on the sender's community member list and can be sent from any character.
- Link conflict (two BattleTags claim one GUID): presence wins.
- Professions keyed by `skillLine` ID (locale-independent), from `GetProfessionInfo`.

## Sync protocol
- Prefix `CommForever`. Payload: LibSerialize -> LibDeflate compress -> `EncodeForWoWAddonChannel`.
- Chunking: max 3500 bytes per message including a `msgId/seq/total` header, written as `<msgId>:<seq>:<total>:<slice>` (msgId alphanumeric, unique per sender). The real BNet limit is unverified; 3500 is safely below it. Reassembly is per sender + msgId, any order, duplicates ignored.
- Every message carries `pv` (protocol version, starts at 1).

Messages:
- `HELLO {bt, ver}`: on login/reload, when a friend starts Forever, after own record changes (debounced 5 s). The same version goes to the same peer at most once per 60 s; a newer version always goes out (decided in CF-11, so changes arrive in ~10 s). `/cf sync` forces one. CF-20: also carries `known = { [battleTag] = version }` of the records the sender can relay (people with a character in its community); a HELLO is repeated when the version or `known` changed, and after accepting a new record.
- `REQ {bt, want}`: sent when a peer's advertised `ver` is higher than stored (`want` nil = the peer's own record), or (CF-20) for each `known` entry newer than stored (`want` = that BattleTag). Answered with the own record or the stored record.
- `RECORD {bt, displayName, version, chars, invite, feed, removed}`: own record with all own characters; `feed` only when "Share my activity" is on (CF-22), `false` when it is off (CF-28: so relays pass "stopped sharing" on); `removed` only in relayed copies (dropped characters with the time they were dropped).
- `ASK {id, dungeon = {id, name, min, max}, from, char, at}` (CF-27): "who's up for it now?", sent only to friends online in Forever whose record has a character in the dungeon's range. `char` is the asker's current character (for an invite request).
- `ANSWER {id, answer = "join"|"later"|"no", from, char}` (CF-27): back to the asker; `char` is the answerer's current character (for the invite). Clients without CF-27 ignore both (unknown `t`).

Accept rule (Merge.lua):
- sender `gameAccountID` resolves to BattleTag B via presence (a friend in Forever)
- `pv` supported
- own record (`record.bt == B`): `record.version > stored version`, or the stored copy was relayed (the owner always replaces a relayed copy)
- relayed record (`record.bt ~= B`, CF-20): not our own BattleTag, `record.version > stored version`, at most 5 minutes ahead of server time, at least one character in our selected community; stored with `via = B`
Otherwise drop silently (debug log only).

Store rule (Merge.store, CF-28): an accepted record is **merged per character**, not replaced. Each character keeps the copy with the newer `updatedAt` (quests, professions, talents, item level and role travel inside the character), and a level never goes down. A character the owner's own record no longer lists is removed and remembered in `removed` with the time; a relayed copy not newer than that cannot bring it back, and relayed records pass `removed` on. The activity feed merges per day and character on the entry's `at`; from the owner its feed is the truth, a relayed `false` drops it, a relayed nil keeps it. Display name and invite come from the newest record; the owner's own record sets the version.

Other:
- Queue outgoing while `InCombatLockdown()`, flush on `PLAYER_REGEN_ENABLED`.
- Unknown higher `pv`: ignore, show "a friend has a newer CommunitiesForever version" once per session.
- Incomplete chunked messages expire after 30 s.
