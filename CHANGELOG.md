# Changelog

Hand-written (the packager's automatic changelog from commit messages is off). Each release gets its own
`## <tag>` section listing only what changed since the previous release; CurseForge and Wago show just that
section (`tools/release-notes.lua`). Collect changes under `## Unreleased` and rename it to the tag before
tagging; the release stops if the tag has no section.

## Unreleased
- **New:** a friend's crafting professions show as a link in the Friends tab, e.g. `[Tailoring]`: click it to see their
  recipes in the game's own profession window, Shift-click to put it in chat. Opening one of your profession windows
  saves your recipes and that link for the website.
- **Fixed:** honorable kills on Forever should now remember who you killed (level, class and race of a player you saw
  first), so the Hunt and the kill missions that need the victim can count.

## v1.4.1 (2026-11-06)
- **Fixed:** the addon's hidden launch check for professions now waits until the recipe list has loaded, so opening
  a profession window gives us the answer we need for sharing recipes between friends.

## v1.4.0 (2026-11-06)
- **Doomsday:** 83 new missions join the draw (pool version 3): cooking, First Aid, crafting and gathering, fishing,
  kills, elites and rares, flights and travel, the bank, trainer and merchants, loot, sessions and playing without
  dying, and "Defend home" (a kill in your own faction's land) as a Skirmish. **Please update:** friends on the
  previous version see different missions until they do.
- **Doomsday:** the honor rank missions are gone for good: Forever doesn't show a PvP rank to addons. They were never
  drawn, so nothing you've done changes.
- **Fixed:** a Battle.net friend who appears offline and is in your guild or community now shows under their
  Battle.net name instead of as a separate unknown player. They still show as offline in the window.
- **Doomsday:** the addon now keeps track of cooking, First Aid, crafting, gathering, recipes, coins, new gear,
  potions, scrolls, Well Fed, buffing friends and tidy bags, for the new missions.
- **Doomsday:** the addon now tracks 25 more missions: kills, elites and rares, flights, swimming and riding, the
  hearthstone, places within zones, the bank, trainer and merchant, weapon skills, and whispers, mail and group
  screenshots with friends, for the new missions.
- **Fixed:** in a planned run's detail (Dungeons tab), the Whisper buttons no longer cover the level and owner in
  "Online now, fits". The list now uses the full width, with "Edit or cancel" (or "On the website") below it; long
  names are cut with "..." before the buttons, also in a narrow window.
- **Fixed:** at the addon window's smallest width the rest of a run's detail no longer runs off the right edge:
  the group's status column, "Ask now for this run" and your answer buttons stay in view. Long texts are cut with
  "...", and buttons that don't fit beside something move below it. Also for a dungeon's detail and the empty states.

## v1.3.2 (2026-11-05)
- **Fixed:** Ctrl+C in the guild invite window now copies the command instead of opening your character window.
  The box takes the keyboard also when your chat input stays on screen (IM-style chat), takes it once you stand
  still, and says "Click here, then Ctrl+C" until it has it. A click anywhere on the window selects the command.
- **Quieter chat:** the addon no longer prints "CommunitiesForever:" lines for what a banner or window already
  shows: friends logging in or switching character, friends' level-ups (the LEVEL UP announcement stays), Doomsday
  goals, kills and crowns (the celebration banners and the crown toast stay), planned-run reminders, answers and
  updates (the run banners and the start panel stay), and the community picked for you. Their switches are gone from
  the settings. Guild invite lines, answers to your own commands and clicks, and errors stay in chat.
- **Fixed:** a friend no longer shows twice in the list, once live and once under "From the website", when the
  website knows them by another name: a website friend with a character already in your list is not listed again.

## v1.3.1 (2026-11-05)
- **Guild members by their Battle.net name:** guild and community members who run the addon now know each other by
  BattleTag, also when they aren't Battle.net friends. Each addon shares only your own BattleTag, and only with the
  members of the guild or community you picked. The window names them by their BattleTag, and the site can show
  them under their Battle.net account. Members on an older version still sync as before.

## v1.3.0 (2026-11-05)
- **Only your group syncs:** the addon now syncs only with friends who have a character in the community or guild
  you picked, also while they play an alt outside it. Other Battle.net friends who run the addon are left alone:
  nothing is sent to them or stored about them, and what earlier versions stored about them is removed once your
  community's members have loaded. Without a community picked, nothing syncs.
- **Your guild can be the community:** `/cf settings` lists your guild next to your character communities. Pick it
  to see your guild's members grouped per friend; switch back to a community at any time, nothing is lost. With the
  guild picked, guild chat counts for the community chat goals, and the invite link options are hidden.
- **A chat tab for your guild:** with the guild picked, the setup's chat step and "Create a community chat tab" in
  `/cf settings` make a chat tab named after your guild that shows only guild chat, and your other characters in the
  guild are offered it once. Guild chat keeps its own color and stays in General too.
- **Your alts get into the guild with one copy and paste:** set a guild code in `/cf settings` (shown with your guild
  picked). Members' addons share it in the guild. When you log in on an alt outside the guild, it asks an online
  member for an invite: the member gets a small window "Invite <alt> (<your name>'s alt)?" with the `/ginvite` line
  ready to copy into chat and keys that light up as they go (Ctrl+C, Enter, Ctrl+V, Enter), and you click Accept
  on the game's invite. The game doesn't let addons send or accept
  guild invites. The code is saved in the new `CommunitiesForever_Vault` folder that comes with the addon, never in
  the file you upload. Someone who left or was kicked from the guild gets no invite window; a member can still invite
  them by hand.
- **Fixed:** without a community, Doomsday keeps counting your goals quietly: no celebration banner or "First to
  finish today!" popup until you pick a community or your guild. Today's progress counts as soon as you do.
- **Fixed:** the Dungeons tab without a community shows just the explanation, without buttons drawn over it or
  leftovers of the list behind it.
- **Fixed:** the window's background is solid: names and frames of the game no longer show faintly through it.

## v1.2.1 (2026-11-04)
- The addon collects some data about which game features work on Forever and sends it with your uploads, so we can
  add more features. Nothing shows in the game, and it reads only what the game tells the addon, no chat text. This
  collection will be removed in a later version.
- **Fixed:** a level-up that finishes a Doomsday goal no longer syncs your record twice.

## v1.2.0 (2026-11-03)
- **Fixed:** the Doomsday Board's column labels sit centred over their boxes.
- **Doomsday:** only a real fight ends PvP Virgin: an honorable kill, a duel or a finished battleground. A finished
  battleground now counts too.
- **Doomsday:** a new mission pool: 29 new dailies and 13 new weeklies (quests, levels, dungeons, play, friends and
  places) join the draw, and each goal scores by its size (1, 3 or 5 for a daily, 5, 10 or 15 for a weekly). The 3
  weeklies are now of different kinds, as the dailies. Days and weeks drawn before you update keep their goals and
  points. **Everyone should update on release day:** friends on the older version draw the old goals.
- **Doomsday:** the addon now records levels (in a dungeon, with a friend, on a low character), speed runs, dungeons
  new to a character, Cooking, Fishing and First Aid points, and characters played after a break, for the new
  missions.
- **Fixed:** the celebration banner's round medallion no longer grows over the text when the banner comes in; it rises and fades with the banner.
- **Doomsday:** the site's owner can set future days' and weeks' missions on the site; they arrive with the uploader
  and reach friends without it through the addon. Days nobody changed keep the usual goals, and a day that has
  started never changes.
- **Doomsday:** quest hand-ins and new quests are now tracked in detail (quests above your level, group, class and
  dungeon quests, quick hand-ins, quests with a friend) for the new quest missions.
- **Doomsday:** the addon now records zones visited (new to a character, far below or above its level, across the
  sea), friends online at once and in your zone, grouping with a lower friend and your community chat messages, for
  the new friends and places missions.

## v1.1.0 (2026-11-02)
- **Fixed:** no "is online" chat lines right after you log in for friends who were already online.
- **Fixed:** `/cf activity debug` is off again after a `/reload` or logout, so a debug left on from the beta no
  longer prints instance events in chat.
- **Celebrations:** a banner with a game sound when you finish a Doomsday goal, complete the day (with the crown when
  you were first), finish a weekly or the Bounty, or earn a feat; big feats get a bigger banner. Several at once
  become one banner; nothing shows during combat, boss fights or battlegrounds until afterwards. A quiet line bottom
  left when a friend completes the day, a weekly or a special feat. Hover pauses, a click opens Doomsday, right-click
  closes. Settings › Celebrations: banners, sounds, friends' celebrations and a Preview.
- **Minimap button:** the addon's own gold shield instead of a generic icon, also in the addon compartment and the
  AddOns list.
- **Fixed:** the Doomsday tab counts down to the reset while it's open, and the new day's goals show up (and reach
  your friends) within a minute of the reset, even when you're just standing around.

## v1.0.0 (2026-10-29)
- **Fixed:** the Ask dialog, the reload prompt, the start panel, settings and setup open in front of the window
  again (they could open behind it).
- **Ask now:** "Also post on Discord" is back and ticked by default; untick it to ask only friends in game.
- **Fixed, Ask now:** clicks were sometimes lost (the tab redrew its buttons while you clicked) and the button could
  stay greyed; every Ask now (a dungeon, a run, an open slot, /cf ask) now opens the same dialog, which says when you
  can ask again. The "Ask now…" above the run list is gone.
- **Friends:** friends the website knows who haven't synced in game are listed under "From the website" (was
  "Not synced yet"), with what that means on hover.
- **Dungeons, no planning in the game:** "Ask now" is the way in game; plan runs for later on the website or with the
  bot's /plan. Runs planned there still show here, and you answer them as before.
- **Fixed, Ask now:** it always works now: friends with the addon who are online get it, and with "Also post on
  Discord" ticked it is posted on Discord (after a /reload). It no longer refuses when nobody in range is online.
- **Fixed, Dungeons:** class icons show for friends' characters too (no more empty circles); one "Ask now for this
  run" per run instead of one on every open slot; the "In range for" dropdown has a proper arrow.
- **Post on Discord?:** shorter, with the details on hover, and it opens on the window.
- **Sync debug lines:** `/cf sync debug` lasts until the next /reload or login and is no longer saved; anyone who
  had it on sees no more "[sync]" lines after updating.

## v0.10.0-beta1 (2026-10-29)
- **Fixed, Dungeons:** a website run shows the dungeon's name ("Scarlet Monastery: Graveyard") and level range instead
  of its id, and "In range" and "Online now, fits" work on Retail too.
- **Dungeons, a run:** the dungeon's full name, its level range and zone, and a countdown that updates every minute
  ("Starting now" at the start). The group rows use the full width and show who is online; below your answer, "Online
  now, fits" sits next to the website link. A run waiting for your next upload shows a small clock (hover for when it
  reaches the website).
- **Dungeons, answering:** answer a run right under its group, also for runs planned on the website or Discord:
  I’m in, Maybe or Can’t, the character you go as (any of yours, with how its level fits), your role (with whether
  that slot is open or full) and a note to the organiser. Every click saves at once. The answer dialog is gone.
- **Dungeons, the group:** hover a member for their level fit, role, where and when they answered and where they
  are online; right-click for Whisper, Invite (from 15 minutes before the start) and Show in Friends. An open slot
  has "Ask now for this run", and its menu whispers the first friend who fits with a ready-made line.
- **Doomsday, goal boxes:** the Board and Today draw a real box per goal: a gold check when done, a small blue corner
  for a swapped goal, the details on hover (progress or when it was done, the original goal, when goals reset).
- **Run reminders:** a banner at the top of the screen, like LEVEL UP, 30 minutes before a run you're in, when
  invites open 15 minutes before (the organiser gets Invite all) and at the start; a click opens the run. It waits
  while you're in combat or a battleground. It replaces the note under the minimap.
- **Dungeons, the list:** chips to show All runs, My runs, Open slots or the ones In range; "In range for" lets you
  pick any of your characters; "Show all dungeons" lists the others too, with how your characters fit one out of
  range.
- **Dungeons, planning:** "Plan a run…" opens right in the dungeon: tonight, tomorrow or the day after at 20:00 your
  time (or another time), your best character for it (an alt when you're out of range), its role and a note.

## v0.9.0-beta1 (2026-10-29)
- **Fixed:** a friend set to "Appear offline" on Battle.net still syncs and their characters are linked to them
  (not "Unlinked"), while the window keeps showing them as offline. Friends who come online just before you log
  in are picked up too.
- **Dungeons in range:** under the planned runs, every dungeon that fits your character; picking one shows a
  suggested group, who's online and fits, the dungeon's quests (with Questie) and "Ask now" or "Plan a run…" for it.
- **Dungeons, the runs:** runs grouped by day with role pips; a run shows the dungeon, a row per group member with
  their status, who in the community is online and fits (Whisper, or Invite near the start), Invite all from 15
  minutes before the start, and your answer with one click.
- **Friends:** "You" for yourself and no BattleTag anywhere; "Online on <character> · <zone>"; each character as a
  small card with its realm, level bar, zone and professions; friends the website knows but who haven't synced yet
  under "Not synced yet".
- **Footer:** says how many friends synced this session and when ("Synced with 2 friends · 22:41"), or that it's
  waiting for someone online; on Friends, how many of your characters there are.
- **Activity:** the character comes first, then the friend; a one-line summary of today next to the filters.
- **Doomsday Today, redone:** a check box per goal, a short bar only for goals you count up, the points per goal in
  PvE green or PvP red, "⇄ swapped" with the original on hover, boxes for today, this week and your streak, and
  "Friends today" next to it.
- **Fixed:** the light streak across the window title no longer waits as a white strip behind the shield between
  passes; the LEVEL UP shine likewise.
- **Tidier setup:** the last explanatory notes are gone from the setup, the settings and the chat-tab chat line.
- **Fixed:** no more Blizzard warning that the addon uses something "only available to the Blizzard UI": the addon
  no longer reads the combat log. What killed you now comes from the death recap.
- **Fixed:** the Dungeons tab on a character outside the community says it isn't in the community yet, instead of
  that its level fits no dungeon.
- **Doomsday rules:** a duel ends "PvP Virgin" too; without a PvP rank you read "No rank yet · N kills"; the Duel
  slot counts in "N of M done"; the day is named by its start ("Wed evening"), and times after midnight show their
  weekday. All times in your own clock.
- **Feats:** the list shows what your characters earned while the addon was watching; what they already had is one
  "Already had" line (hover for the details). A mount only counts from level 40, an epic mount from 60.
- **A cleaner Doomsday Board:** short column titles, a check mark or an empty box per goal (hover for the
  progress, the time and a swap), the finish time next to a crossed-out name, and one points column.
- **Tidier windows:** the notes explaining how the addon works are gone from the tabs and footers. What a button
  does shows when you hover it (Ask now). Doomsday shows "New goals in …" on Today and Board and "Week resets …"
  on Week and Ladder.
- **Fixed:** the light streak across the window title no longer drags a dark block over the title, and LEVEL UP
  chips stay put while their shine plays (Ambient effects).
- **Fixed:** the setup's step line fits the window (it shows the current and the next step), the settings'
  descriptions wrap inside their column, and the settings footer shows the version with one "v".
- **An alt outside the community:** the window opens once by itself on how to join (when a friend shared the invite
  link), and right after joining you're offered the Community chat tab, in a tidier dialog with Create tab and
  Not now.
- **Fixed:** blue and purple loot is counted on clients whose item links carry the quality instead of a colour,
  also for items the game has not cached yet.

## v0.8.0-beta1 (2026-10-29)
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
