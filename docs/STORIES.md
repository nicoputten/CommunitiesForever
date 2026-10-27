# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-44.

## E13 Revamp (new look)

Design: `docs/design/revamp-2026-10/` (README: decisions and where the mockups differ). Each screen story replaces one tab whole: old and new never mix inside one tab. Nothing stored or sent changes unless a story says so (rule 8). Visual checks happen in game after launch (VERIFY.md).

### CF-44 Level-up announcement
- Goal: a short announcement at the top of the screen when a friend's character levels up (`activity.html`, above the window).
- A pill at the top centre: 28 px portrait, "<person>'s <character> reached level N", the LEVEL UP chip (shine unless Ambient effects is off); fades out after 6 s; several in a row stack or queue. The chat line (CF-16) stays.
- Setting "Level-up announcement" (Notifications); its default is decided when building.
- Unit tests: when it shows (same rules as the CF-16 line: linked people, not older than 15 minutes), the text, the queue.
- Manual: a friend levels up: the pill shows and fades; off in settings: nothing.
