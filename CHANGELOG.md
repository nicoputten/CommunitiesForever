# Changelog

Hand-written (the packager's automatic changelog from commit messages is off). Each release gets its own
`## <tag>` section listing only what changed since the previous release; CurseForge and Wago show just that
section (`tools/release-notes.lua`). Collect changes under `## Unreleased` and rename it to the tag before
tagging; the release stops if the tag has no section.

## Unreleased
- **Doomsday.** Every day three PvE dailies and a PvP Skirmish, every week three weeklies and a Bounty: the same
  goals for the whole group, resetting at 19:00 realm time, and suggestions, never rules. Progress counts over all
  your characters and is shared with friends and the website as you play.
  - The new **Doomsday** tab: Today and Week with your progress, points (PvE and PvP, never added together), kills,
    the Duel slot, your streak and who took the crown; the Board with every friend's goals today; the Ladder for
    this week; your characters' Feats. All-time totals stay on the website.
  - Chat lines when you finish a goal, a kill is worth bonus points, someone takes the crown or a goal is swapped
    for you (setting "Doomsday in chat"), and "First to finish today!" when you take the crown.
  - A friend's character card shows their PvP rank with our title ("Stone Guard, a.k.a. Mailbox Menace"), or
    "PvP Virgin". The Activity tab shows "a spree of 5" (or 10) for kills in a row without dying.
  - `/cf doomsday` prints today's and this week's goals, your streak and points.
- **More of your play is shared with friends** (for Doomsday and the website's feats): PvP (honorable kills with
  their victims, rank, this week's honor, deaths and what killed you, duels), blue and purple loot, notable crafts
  and catches (Arcanite Reaper, Mooncloth, the Fishing Extravaganza and more), how much gold came in and went out
  (never shown as an amount), play sessions, who from the community you grouped with, and your riding skill.
  `/cf self` shows the PvP line.
- **"Share my activity" is gone.** Everyone with the addon shares their activity with friends; if you'd rather not,
  uninstall the addon.

## v0.7.0-beta1 (2026-10-28)
- An Ask now that is also posted on Discord now reaches the site through any friend with the addon: everyone online carries it along with their next /reload or logout, and answers given in game show on the Discord post too. Only friends with a character in range are asked; the rest just carry it.

## v0.6.0-beta1 (2026-10-28)
- **Planned runs in the Dungeons tab.** Runs planned on the website (brought into the game by the
  CommunitiesForever uploader) or shared by a friend's addon are listed on top: when, who organises, who's in,
  your answer and which of your characters fits. A run shows its five slots, who answered on Discord, who is
  close in level and the link to edit it on the website. The in-game calendar is no longer used.
- **Ask now, Plan a run and answering runs in game.** Ask now shows who gets whispered and who doesn't (and
  why), takes a note and can post the ask on Discord too. Plan a run picks the dungeon, your character, a day
  and a time on your clock. Answer a run with I'm in, Maybe or Can't and the character you bring; the
  organiser's addon gets it at once. What has to reach the website waits for your next /reload ("reaches
  Discord after /reload"), and a prompt offers to reload right away.
- **Run reminders and the start of a run.** A note under the minimap (with a soft chime) before a run you're
  in, and "Starting now" with Request invite at its start. The organiser gets a start panel showing who is
  ready, on another character or offline, with Invite, Whisper, Invite everyone ready and Discord pings for
  whoever is missing. Chat lines for reminders, answers, starts and more; each kind can be turned off in
  the settings.
- **Runs v2: level fit and roles, as on the website.** Answering a run in game: every character of yours
  with how it fits ("fits", "+3 over", "carry · +12", "4 below"), then a role your class can play (Tank,
  Healer, Damage). Any character may answer I'm in, also one 6 or more levels below: it shows how far
  below it is and "This will be tough." Plan a run asks your role too.
  A run's slots show each sign-up's role and fit, reserves are listed under them, and "Close" and "fits
  damage" use the same rule.
- Fix: the card of a community member not linked to a friend said "played by Unlinked"; it now says
  "community member".

## v0.5.0-beta1 (2026-10-27)
- **New look, part 1: the window.** A new frame: dark panel with a gold border, the community name and who
  is online in the title, new tabs and a footer. Every tab, the settings and the setup now share this look.
- **New look, part 2: the Friends tab.** Class portraits, foldable people, the number of quests you share
  with each character, and a new character card: level, item level and role at a glance, profession and
  talent bars, quests you share grouped by zone, and Whisper and Invite buttons. The footer shows when you
  last synced. Long lists scroll.
- **New look, part 3: the Activity tab.** Filter chips (Level-ups, Dungeons, Together), a portrait per entry
  (two for friends who played together), level-ups as a gold chip, the zones you quested in, and the time of
  each entry. Older days show their date.
- **New look, part 4: the Dungeons tab.** The list follows the character you're on, with level ranges, friends
  in range and your quests per dungeon. The suggested group shows as five slots (tank, healer, three damage)
  and says when nobody in range can tank or heal; your other characters show as alternatives, and the card
  says where the dungeon is.
- **New look, part 5: settings and setup.** The settings have their own window (also under Options › AddOns),
  and the first-run setup is redone in the same style. New: **Open on login** opens the window after you
  log in, and **Ambient effects** adds a slow shimmer to the window title and level-up chips (on by default).
- **Level-up announcement:** when a friend's character levels up, a short note shows at the top of the screen
  for a few seconds (next to the chat line). Switch it off under Notifications in the settings.
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
