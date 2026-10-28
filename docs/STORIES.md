# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.

## E14 Planned runs (continued)

## CF-58 Drop "Share my activity"
Decided with Nico (2026-10-28): there is no sharing toggle. A friend who doesn't want to share uninstalls the addon. This makes the feed, Doomsday's `goals` (CF-56) and their relaying simpler.
- The setting **Share my activity** goes: from Settings (the Sharing group keeps "Receive group asks"), from onboarding step 5, from `Store` defaults and from `FeedTracker`. A stored `settings.shareActivity` is ignored (and may be cleared); no migration needed.
- `Merge.outgoingRecord` always sends `feed` (and, after CF-56, `goals`). The addon never sends `false` for either.
- **Receiving** (rule 8): released clients may still send or relay `feed = false`. It now means "nothing sent": the stored feed of that friend stays, as for a record without `feed`. The same holds for `goals = false`.
- The Activity tab's footer loses "Activity is shared only by friends who turned on Share my activity".
- If CF-56 is not built yet, it is built without `goals = false`.
- `docs/SYNC.md` (RECORD fields, merge rule), `docs/ARCHITECTURE.md` (settings, RECORD) and `docs/DOOMSDAY.md` (if it mentions sharing) updated.
- Tests (busted): `outgoingRecord` without the setting; a received `feed = false` keeps the stored feed; `Compat_spec` passes on earlier fixtures.
- The site does the same on its side (web WEB-55): `false` from released clients means nothing sent.
