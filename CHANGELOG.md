# Changelog

Hand-written (the packager's automatic changelog from commit messages is off). Each release gets its own
`## <tag>` section listing only what changed since the previous release; CurseForge and Wago show just that
section (`tools/release-notes.lua`). Collect changes under `## Unreleased` and rename it to the tag before
tagging; the release stops if the tag has no section.

## Unreleased
- Also on **Wago Addons**, so WowUp can install and update it.
- **Setup:** on the community chat step, "Create chat tab" sits where Next is, so clicking on through the
  setup creates the tab; "Not now" goes on without one.

## v0.2.0-beta2 (2026-10-20)
First release (beta: World of Warcraft: Forever is still in beta; please report problems). v0.2.0-beta1 was
rejected by CurseForge for a packaging problem and never reached users.

- **Who is who:** members of a selected community grouped per person, with class, level, item level,
  professions, talents and role, and their alts outside the community. `/cf` or the minimap button.
- **Sync:** character data syncs between players running the addon: Battle.net friends, and also community
  members who are not your Battle.net friends. Data is passed on through others when you are not online at
  the same time, and never goes back to older data.
- **Setup:** a short setup on first use (community, display name, community chat, notifications); `/cf setup`
  runs it again.
- **Notices:** a chat line when someone comes online or levels up; their name on unit tooltips.
- **Shared quests:** quests you share with someone, on their character card, with dungeon quests marked.
- **Activity tab:** what you and the others did each day: levels, quests per zone, profession ranks, dungeons,
  raids and battlegrounds, and one line for runs done together. "Share my activity" turns yours off.
- **Dungeons tab:** every dungeon from the game's Group Finder (also Forever's new ones) that fits your
  characters, with a suggested group, who has quests for it (all quests with Questie installed), and runs
  planned in the community calendar with their sign-ups. "Ask who's up for it" asks the others with a
  character in range; they answer Join, Later or No from chat.
- **Community chat:** purple in every chat window (color adjustable), the chat tab flashes on new messages
  (optional sound), and a button creates a Community chat tab.
- **Invite link:** owners, leaders and moderators can share the community's invite link; characters that
  are not in the community see how to join with it.
