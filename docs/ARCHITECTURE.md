# Architecture

## Core rules
1. A character is **visible** only if its GUID is a member of the selected community.
   Exception (CF-17): a **non-member alt** is visible if it arrived in its owner's record AND the owner has at least one visible, linked member character. It is shown under that person, marked "not in community", and never in Unlinked.
2. A visible character is **linked** to a person (BattleTag) only if that BattleTag is a current Battle.net friend AND either:
   - BNet presence showed that friend logged in on that character, or
   - that friend's addon sent a record containing the character directly.
3. Visible but not linked: shown in the **Unlinked** section with community data only.
4. No relay in V1. Records are accepted only from their owner over BNet, and only for the sender's own BattleTag.
5. Only the owner changes their record. Version = `max(prev + 1, GetServerTime())`. Higher version wins.

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
      Friends.lua            BNet presence snapshot, online/switch/offline diff, presence links
    adapters/                WoW API wrappers only
      Events.lua             guarded event registration (C_EventUtils.IsEventValid)
      Timer.lua              C_Timer debounce
      SelfInfo.lua           Unit*, GetProfessions, item level
      Community.lua          C_Club (club list, members, club and member events)
      Presence.lua           C_BattleNet friend accounts, BN events
      Transport.lua          BNSendGameData, prefix, BN_CHAT_MSG_ADDON, combat state (thin)
    services/
      SelfTracker.lua        keeps own snapshot current (events, ilvl debounce)
      CommunitySelection.lua owns settings.clubId, clears it when the club is gone
      MemberTracker.lua      members of the selected community (FocusMembers, 1 s debounce)
      PresenceTracker.lua    friends in Forever, gameAccountID -> BattleTag, writes presence
      ViewModel.lua          gathers tracker + DB state, runs the Linker (UI input)
      Messenger.lua          send: encode, chunk, throttle, combat hold; receive: reassemble, decode, sender BattleTag
      Ping.lua               /cf ping test messages (PING/PONG)
      Sync.lua               HELLO / REQ / RECORD flow, dedupe, shared-set version bumps
      Notify.lua             login notifications
    ui/
      MainFrame.lua          AceGUI Frame + TreeGroup (people/characters left, detail card right)
      Settings.lua           AceConfig options (Blizzard panel + /cf settings)
      Tooltip.lua            unit tooltip line
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

UI choice: AceConfig for settings (also registered in the Blizzard settings panel). Main window: AceGUI `Frame` (move, resize, saved position and size via its status table) with a `TreeGroup`: people expandable to their characters on the left, a detail card on the right (decided in CF-12, draft B, replacing the earlier custom frame + ScrollBox plan: no unverified templates). Profession bars are inline textures. Each UI module that listens to internal messages uses its own AceEvent-embedded object, because AceEvent keeps one handler per object and message.

## Data model
SavedVariables `CommunitiesForeverDB`, AceDB `global` scope (account-wide).
```lua
global = {
  schemaVersion = 1,
  settings  = { clubId = nil, notifications = true, minimap = {}, window = {}, tree = {},  -- window, tree: AceGUI status
                sendInterval = 0.2,                  -- seconds between outgoing chunks
                shareAlts = true },                  -- CF-17: send own alts outside the community
  self      = { battleTag, displayName, version, chars = { [guid] = Char }, sharedSignature },
  people    = { [battleTag] = { displayName, version, receivedAt,
                                chars = { [guid] = Char } } },
  presence  = { [guid] = { battleTag, lastSeen } },  -- links observed via BNet presence
  nicknames = { [battleTag] = "Sjaak" },             -- local only, never synced
  locations = { [guid] = { zone, seenAt } },         -- last zone seen in the community, local only
}

Char = {
  guid, name, classFile, raceID, level, faction, realm,
  ilvl,                                              -- equipped avg, floored; nil if API unavailable
  professions = { [skillLineID] = { name, rank, max } },
  talents, mainTree, role, roleOverride,           -- CF-18 (future): talent split per tree, heal/dps/tank
  quests = { [questID] = title },                    -- CF-19 (future): quest log, names only, no progress
  updatedAt,                                         -- last synced-field change
  lastPlayed,                                        -- own chars: login/logout time (not compared, no bump)
}
```
- Zone and online state are NOT synced. They are live data from presence and C_Club.
- Bump `self.version` only when a synced field actually changes (Snapshot compare).
- Display name priority: local nickname > owner's displayName > BattleTag name part (before `#`).
- Sender includes only own characters that are current community members, plus all other own characters when the setting "Share alts outside the community" is on (CF-17, default on). Receiver filters again, authoritatively (core rule 1).
- Link conflict (two BattleTags claim one GUID): presence wins.
- Professions keyed by `skillLine` ID (locale-independent), from `GetProfessionInfo`.

## Sync protocol
- Prefix `CommForever`. Payload: LibSerialize -> LibDeflate compress -> `EncodeForWoWAddonChannel`.
- Chunking: max 3500 bytes per message including a `msgId/seq/total` header, written as `<msgId>:<seq>:<total>:<slice>` (msgId alphanumeric, unique per sender). The real BNet limit is unverified; 3500 is safely below it. Reassembly is per sender + msgId, any order, duplicates ignored.
- Every message carries `pv` (protocol version, starts at 1).

Messages:
- `HELLO {bt, ver}`: on login/reload, when a friend starts Forever, after own record changes (debounced 5 s). The same version goes to the same peer at most once per 60 s; a newer version always goes out (decided in CF-11, so changes arrive in ~10 s). `/cf sync` forces one.
- `REQ {bt}`: sent when a peer's advertised `ver` is higher than stored.
- `RECORD {bt, displayName, version, chars}`: own record, filtered to community members (plus non-member alts when sharing is on, CF-17).
- The own version also bumps when the set of own characters that are community members changes (`self.sharedSignature`), because that changes what friends receive. A REQ that arrives before community member data has loaded is answered once it has (decided in CF-11).

Accept rule (Merge.lua):
- sender `gameAccountID` resolves to BattleTag B via presence
- `record.bt == B`
- `record.version > stored version`
- `pv` supported
Otherwise drop silently (debug log only).

Other:
- Queue outgoing while `InCombatLockdown()`, flush on `PLAYER_REGEN_ENABLED`.
- Unknown higher `pv`: ignore, show "a friend has a newer CommunitiesForever version" once per session.
- Incomplete chunked messages expire after 30 s.
