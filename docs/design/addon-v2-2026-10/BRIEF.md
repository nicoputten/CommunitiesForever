# CommunitiesForever addon v2: Dungeons tab redesign and polish on the other tabs

Nico's brief (2026-10-29), with the boards in this folder (`AG01Audit`, `AG02Dungeons`, `AG03Tabs`, `AG04Kit`). Story: CF-62 in `docs/STORIES.md`, which records Nico's answers on the explanatory lines and the "known from the website" friends.

This brief redesigns the in-game window of the CommunitiesForever addon ("Doombringers" window).

**Environment:**
- WoW: Forever: Vanilla content, Mainline/Midnight 12.x API.
- The addon cannot read combat-log details.
- The addon cannot make web requests.
- The addon cannot post to Discord.

**The designs:**
- They are on the canvas **"Doombringers v2"**, section "Addon in game v2":
  - `AG01Audit`: live screenshots with numbered issues
  - `AG02Dungeons`: the main work
  - `AG03Tabs`: Doomsday, Friends and Activity
  - `AG04Kit`: the rules for what a frame may draw
- Every design uses only things an addon frame can draw. Build exactly what you see. If something can't be built 1:1, tell Nico first.
- The canvas uses made-up names. Use real data in the code.

## Ground rules

- **Look and feel:**
  - Keep the current window: 1080 × 720 at UI scale 1.
  - Keep the title bar, the four tabs, the footer and the corner diamonds.
  - Keep the fonts you already ship: Marcellus SC for titles and tabs, Inter for the rest.
- **Frame:**
  - Square corners and 1 px borders (BackdropTemplate).
  - Flat fills or two-colour `SetGradient`.
  - No rounded corners, blur, drop shadows or letter-spacing (FontStrings can't do letter-spacing).
- **Icons:**
  - Class: atlas `classicon-<class>`.
  - Role: `UI-LFG-RoleIcon-Tank|Healer|DPS`, or `roleicon-tiny-*` at 16 px.
  - Check mark: `common-icon-checkmark`, or ReadyCheck-Ready.
  - Check every atlas once with `C_Texture.GetAtlasInfo`. If one is missing, fall back to a 16 px coloured square: tank `#5B8DD6`, healer `#7FD99A`, damage `#E0625A`.
- **Interaction:**
  - Everything clickable gets a highlight texture on hover and a GameTooltip where the design shows extra info.
  - Never send chat text yourself. Whisper opens the chat box with `ChatFrame_SendTell(name)`.
  - Invites use `C_PartyInfo.InviteUnit(name)`, only on a button click and only out of combat. In combat, disable the button and show the tooltip "Not in combat".
- **Privacy:** don't show BattleTags in the window, not even your own. Show friends by display name and characters by name; the realm is a dim suffix (e.g. `Chromaggus`, not `-Chromaggus`).

## 1. Dungeons tab (`AG02Dungeons`, the main work)

**Left list (290 px):**
- Header: "Runs" (Marcellus SC 17) with an **"Ask now…"** button on the right. It opens the existing Ask now dialog.
- Groups: Tonight, Tomorrow, This week, Later, by local start time.
- Run row (about 50 px):
  - Line 1: the dungeon's short name ("SM: Graveyard", "Razorfen Kraul"), with the start time on the right ("20:30", or "Fri 20:00" outside today).
  - Line 2: five **role pips** (14 × 6 px textures in the order T H D D D; filled in role colour when taken, dark with a 1 px edge when open), then "2 in · 1 maybe", then the organiser's display name on the right. Your own runs say "you organise" in gold.
  - Selected row: 3 px gold bar on the left and a gold tint, as now.
- The line "Runs from the website, Wed 22:30. Type /reload after an upload for newer." moves to the bottom of the list as one muted line (11 px). It is no longer a run row.

**Detail (right side):**
- **Title:**
  - The dungeon's full name ("Scarlet Monastery: Graveyard", Marcellus 26), then "level 26–36" in 13 px grey.
  - The text the organiser typed ("smgy…") is never the title. It shows on the subtitle line as `note: "…"`.
  - Subtitle: "Tonight 20:30 · in 3 h 10 m · planned on the website · note: …". At start time this line begins with "Starting now · 20:30" in `#F0A774`.
- **Group:**
  - Five full-width **rows** of 38 px replace the tiles.
  - Each row: role icon (20), class icon (20), the full character name in class colour, then "level · friend" in grey, and the status right-aligned.
  - Status texts:

    | Status | Colour |
    |---|---|
    | organiser | green |
    | answered on Discord | blue `#9DB4FF` |
    | maybe | orange |
    | online · `<zone>` | green (only at start time) |
    | maybe · offline | orange |

  - Open slot: dashed 1 px border, dimmed role icon, "Damage · open". On the right, "N online fit" in blue, with a tooltip listing them.
  - Under the rows: "Reserve: `<name>` (`<role>`, `<friend>`)".
  - Names must never be cut off at the window's normal width. Truncate only if the window is resized below 900 px.
- **Online now, fits `<range>`** (right column, 250 px):
  - Members of the CommunitiesForever club, from `C_Club.GetClubMembersInfo`.
  - Show only members who are online and whose current character's level is within the run's range, excluding people already in the group.
  - Row of 34 px: class icon, name in class colour, level, "friend · zone", then a button: **Whisper** before the start, **Invite** from 15 minutes before the start.
  - Small muted line under the list: "From the community roster: online members whose current character fits the level range."
  - Empty state: "Nobody online fits right now."
  - Refresh on `CLUB_MEMBER_PRESENCE_UPDATED` and `CLUB_MEMBER_UPDATED`, at most once a second.
- **Action area** (below a divider):
  - Before the start (organiser): "At 20:30", a disabled **"Invite all · opens 20:15"** button (the dark gold off state), and "Reminder at 20:00. Invite all invites everyone who is in and online."
  - From 15 minutes before the start: **"Invite all · N online"** as the main gold button (32 px), plus a Whisper button for whoever is in but not in your party. Note: "`<name>` (maybe) is offline; Discord already pinged everyone who answered."
  - Someone else's run: "Your answer" with three toggle buttons **I'm in / Maybe / Can't**, then "As `<character>` · `<role>` · change". "change" opens a small menu of your characters that fit, plus the role choices.
    - Store the answer in SavedVariables. Send it to online friends with the addon via the existing addon-message channel. The website gets it with the next upload.
    - Line under it: "Shared with online friends now; the website gets it with your next upload."
- **Edit or cancel** (right column): the existing link EditBox, 228 px wide.
  - Select the text when it gets focus (`HighlightText()`).
  - Hint under it: "Click, then Ctrl+C to copy. Opens on the website."
  - Non-organisers see the title "On the website" instead.
- **Empty state** (no runs): the left list says "No runs planned" plus one line. The right side is centred:
  - "Nothing planned yet"
  - "Plan a run on the website and it shows up here after your next upload, or use Ask now to see who is up for a dungeon right now."
  - Buttons: **Ask now…** (gold) and **Copy website link** (selects the site URL in an EditBox).

## 1b. Dungeons in range (`AG05InRange`). Keep everything the current tab has.

The v2 Dungeons tab keeps the "dungeons in range" part of today's tab. Nothing is dropped. It moves into the same layout:

- **Left list, two parts, under the header "Dungeons" + "Ask now…":**
  - **Planned:** the compact run rows from section 1.
  - **In range for `<your character>` (`<level>`):**
    - every dungeon whose range fits the character you're logged in on, using the existing range table
    - each row (about 44 px): the name, the range on the right, then "N fit · X/Y quests"
    - a gold "1 run" tag when a run is planned for that dungeon
    - the line "Ranges are typical levels; the list follows the character you're on." becomes the ⓘ tooltip on this heading
- **Picking a dungeon** shows (right side):
  - **Title:** the dungeon, then "level 22–30 · `<zone>`". If a run exists, a button on the right, "1 run planned · Fri 20:00 ›", selects that run.
  - **Suggested group** (the existing suggestion logic, drawn as the same 38 px rows as the run group):
    - one character per friend, the best fit per role
    - a role nobody can fill: dashed row "Healer · nobody in range", with "close: `<name>` `<level>`" on the right
    - an open slot: "N online fit"
    - under the rows: "Your other characters in range: …"
  - **Online now, fits `<range>`:** the same list as in section 1, filtered by this dungeon's range.
  - **Quests** (QuestieDB, your faction), heading "Quests · 2 of 3 in your log · 1 done":
    - a green check: the quest is in your log, with "`<friend>` has it too" from sync data
    - a gold "!": not picked up yet, with "pick up: `<NPC>` · `<zone>`"
    - struck through and grey: done (`C_QuestLog.IsQuestFlaggedCompleted`), with "done on `<character>`" for your alts
    - no QuestieDB loaded: the heading says "Quests · needs Questie", and the list is hidden
  - **Go:** two buttons:
    - **"Ask now for `<dungeon>`"** opens the existing Ask now dialog with the dungeon filled in
    - **"Plan a run…"** opens the existing in-game plan dialog with the dungeon filled in
    - one muted line under them: "A planned run reaches the website and Discord with your next upload."
- **What opens first:** the next run where you're in. With no run, the first dungeon in range. The empty state (board D) only shows when there are no runs **and** no dungeons in range, e.g. at level 1–12.

## 2. Doomsday tab (`AG03Tabs`, left top)

- **Header:** "Today · Wed evening · 1 of 5 done". The count matches the goals shown. On the right: "New goals Thu 19:00 · in 4 h 28 m" in orange.
- **Goal rows (40 px):**
  - An 18 px **check box** first (filled green with a check when done).
  - Kind label in its track colour: green for Daily, red for Skirmish, Hunt and Duel.
  - Then the title (struck through and grey when done) and a blue **"⇄ swapped"** marker when the goal was swapped. Its tooltip names the original goal and why it was swapped.
  - Progress on the right:
    - Goals that are only done or not done (Gain a level, Raise a profession): no bar, just "done" or "not yet".
    - Count goals: a **140 px** StatusBar next to "1/10", not stretched across the row.
  - Points at the far right: "+5" in the track colour.
- Below the goals: a muted line "⇄ swapped: your character can't do the original goal (hover for it). Goals are suggestions; skip any."
- Then three stat boxes with 1 px borders: **Today** (PvE green · PvP red), **This week** (the same), **Streak** ("N days" in orange, "best N" in grey). This replaces the single gold "PvE 0 · PvP 0" line.
- **Right column (270 px): "Friends today" mini board.**
  - One row per friend with Doomsday data, including you as "You" in gold.
  - Five 12 px boxes: green for PvE done, red for PvP done, outline when open. "PvP Virgin" replaces the PvP boxes when it applies.
  - Points as "PvE · PvP".
  - When all dailies are done, the name is struck through. A crown after the first friend to finish.
  - Muted line under it: "Live for friends online with the addon; others after their upload."

## 3. Friends tab (`AG03Tabs`, right top)

- **Left tree:**
  - Groups "Online · N" and "Not synced yet · N".
  - The second group lists friends known from the website data in SavedVariables who haven't synced this session, each with "from the website".
  - Your own entry reads "You", not "Vestras (you)".
- **Right side:**
  - Title "You" (or the friend's display name).
  - Under it, in green: "Online on `<character>` · `<zone>`". Remove the BattleTag line.
  - **Character cards** (1 px border, 10 × 12 px padding):
    - class icon (32)
    - name in class colour, realm as a dim suffix
    - "· Level 57 · Healer"
    - on the right: "online" in green, or "played 1 h ago"
    - second line: a 120 px level bar in class colour (level / 60), the zone, and on the right the professions, or "no professions yet"
  - Empty explanation (dashed box): "Friends appear here when they are online with the addon at the same time as you, or after the website sync. N friends are known from the website and fill in after your next /reload following an upload."

## 4. Activity tab (`AG03Tabs`, left bottom)

- Filters stay. On the right of the filter row, a one-line summary: "Today: 1 friend active · 1 quest · 0 levels".
- **Rows:**
  - Class icon (28), then the **character first** in class colour, then "· friend" in grey ("you" for yourself).
  - Second line: what happened, with the zone chip.
  - Time on the right.
- After the last row of Today: "That's all for today. Friends' activity arrives when they are online with the addon, or after the website sync."
- Then the **Yesterday** group (and older days within the 7 days kept).

## 5. Everywhere

- **Footer:** replace "Not synced yet" with what it means:
  - "Synced with N friends · HH:MM" (the last addon-message sync this session)
  - or "Synced with 0 friends · waiting for someone online"
  - Friends tab: "Synced with N friends this session · M of your characters". Count your own characters, never "0 characters from 0 friends".
  - Activity keeps "Keeps 7 days".
- **Title bar:** fix the white gradient strip behind the shield icon on the left. It looks like a texture drawn with the wrong texture coordinates, or an extra highlight texture. Only the shield should show.
- **Sizes:**
  - left list 290 px
  - rows 34–40 px
  - buttons 28 px high, 32 for the main action

## Decisions after review (these override the sections above)

1. **Explanatory lines.** Show only status and hints on screen; everything else goes into an ⓘ GameTooltip on a small icon button next to the nearest heading.
   - **Keep visible:**
     - "Runs from the website, Wed 22:30. Type /reload after an upload for newer."
     - "Click, then Ctrl+C to copy."
     - the empty states: "Nothing planned yet…", "Nobody online fits right now.", the Friends empty box
     - the short status "Reminder at 20:00"
   - **Move into a tooltip:**
     - "From the community roster: …" goes on the "Online now, fits" heading.
     - "Shared with online friends now; the website gets it with your next upload." goes on "Your answer".
     - "⇄ swapped: … Goals are suggestions; skip any." goes on the goals heading. The ⇄ marker keeps its own tooltip naming the original goal.
     - "Live for friends online with the addon; others after their upload." goes on "Friends today".
     - "That's all for today. Friends' activity arrives when…" goes on the "Today" heading in Activity.
     - "Invite all invites everyone who is in and online." becomes the tooltip of the Invite all button. It shows when the button is disabled too.
2. **Friends known from the website: option (a).**
   - The site adds a short friends list to the data the uploader writes into the game, next to the runs. The uploader passes it through unchanged.
   - Contents: display name, plus per character the name, realm, class, level, and last-seen date. No BattleTags, no Discord IDs.
   - The addon reads it on load and fills "Not synced yet · N" with "from the website" and the data date. Friends who sync live replace their entry.
   - Site work: one small change to the export. Addon work: read and merge it.
3. **The title-bar shimmer** (bug #1) and the "white strip behind the shield" are the same issue. Fix it once.

## Done when

- At 1080 × 720 and UI scale 1, all four tabs match the `AG02Dungeons` and `AG03Tabs` mockups. No name in the Dungeons group is cut off.
- **Online now, fits:**
  - Changes within a second when a community member logs in or out.
  - Never lists someone already in the group.
  - Invite works out of combat and is disabled in combat.
- Invite all is enabled exactly from 15 minutes before the start and invites only people who answered "I'm in" and are online.
- An answer given in game shows up for an online friend's addon within a few seconds and survives /reload.
- No BattleTag appears anywhere in the window.
- No Lua errors with BugSack/BugGrabber while switching tabs, during combat, or with zero runs, zero friends and zero goals.
