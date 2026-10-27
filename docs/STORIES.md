# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-43, CF-44 (any order).

## E13 Revamp (new look)

Design: `docs/design/revamp-2026-10/` (README: decisions and where the mockups differ). Each screen story replaces one tab whole: old and new never mix inside one tab. Nothing stored or sent changes unless a story says so (rule 8). Visual checks happen in game after launch (VERIFY.md).

### CF-43 Settings and setup in the new look
- Goal: the settings window and the first-run setup as in `settings-setup.html`.
- Settings (own window, 640 × ~500): Display name, Community (dropdown, character communities only), Sharing (Share my activity; Receive group asks: "a chat line when a friend looks for a group"), Notifications (When friends log in, Announce friends' level-ups, Play a sound), Community chat (colour swatch and Reset, Flash the chat tab, Create a community chat tab), Interface (Minimap button, **Open on login**, **Ambient effects**: title shimmer and level-up glow). No "paste an invite link to join" (blocked, V26). Footer "Also under Options › AddOns · v<version>"; registered there with `Settings.RegisterCanvasLayoutCategory` (unverified, VERIFY.md), replacing the AceConfig dialog.
- New settings `openOnLogin` (off) and `ambientEffects` (on): new keys with defaults, no migration (rule 8).
- Setup (600 × 460): progress bars and "Step n of 6", Welcome (three tiles: Friends, Activity, Dungeons), Community, Name, Community chat (optional, as CF-30: Create chat tab in the Next spot, Not now), Sharing and notifications, Done. Skip setup / Next.
- Unit tests: every setting writes the same value as before (one source of truth, CF-26); the new settings' defaults; the steps.
- Manual: compare with `settings-setup.html`; every setting works; the setup on a fresh account.

### CF-44 Level-up announcement
- Goal: a short announcement at the top of the screen when a friend's character levels up (`activity.html`, above the window).
- A pill at the top centre: 28 px portrait, "<person>'s <character> reached level N", the LEVEL UP chip (shine unless Ambient effects is off); fades out after 6 s; several in a row stack or queue. The chat line (CF-16) stays.
- Setting "Level-up announcement" (Notifications); its default is decided when building.
- Unit tests: when it shows (same rules as the CF-16 line: linked people, not older than 15 minutes), the text, the queue.
- Manual: a friend levels up: the pill shows and fades; off in settings: nothing.
