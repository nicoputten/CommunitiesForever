# Changelog

Hand-written (the packager's automatic changelog from commit messages is off). Each release gets its own
`## <tag>` section listing only what changed since the previous release; CurseForge and Wago show just that
section (`tools/release-notes.lua`). Collect changes under `## Unreleased` and rename it to the tag before
tagging; the release stops if the tag has no section.

## Unreleased
- **New look, part 1:** the window has a new frame: dark panel with a gold border, the community name and
  who is online in the title, new tabs and a footer. The tabs inside get their new look in the next updates.
- **New look, part 2: the Friends tab.** Class portraits, foldable people, the number of quests you share
  with each character, and a new character card: level, item level and role at a glance, profession and
  talent bars, quests you share grouped by zone, and Whisper and Invite buttons. The footer shows when you
  last synced. Long lists scroll.
- **Less sync traffic in the community:** the "I changed" message goes out once on a hidden channel to
  everyone running the addon, instead of a whisper to each member. Older versions keep getting whispers.
- Fix: a community chat window with other channels before the community channel is recognized again.

## v0.4.0-beta1 (2026-10-23)
- **Right-click menu:** right-click a person or character in the Friends tab to whisper them or invite them
  to your group (no more typing first and last names).
- **Search:** a search box in the Friends tab: names, classes, roles, professions and zones, with
  `tailoring 150` for a minimum rank and `20-30` for a level range.
- **Update notice:** one chat line per session when a friend runs a newer release of CommunitiesForever.
- **Who runs the addon:** a small icon after people who run CommunitiesForever; the card of someone who
  does not explains why their professions, talents and quests are missing.
- **Keybinding:** "Open or close the window" in Blizzard's keybinding menu (unbound by default).
- **Esc** closes the window and the setup.
- **Minimap button:** its tooltip lists who is online, on which character and level.
- **Sync fix:** someone you only knew through a friend's relay now syncs with you directly once you are
  both online in the community, so you no longer keep their older copy.

## v0.3.0-beta1 (2026-10-21)
- Also on **Wago Addons**, so WowUp can install and update it.
- **No community, no noise:** without a community on your account the addon stays quiet (no setup, no
  minimap button, no chat lines, no syncing). `/cf` explains how to join one; once you do, the setup starts
  right away.
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
