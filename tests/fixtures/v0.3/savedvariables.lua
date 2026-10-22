-- Golden fixture v0.3: CommunitiesForeverDB.global as schema 1 writes it (tests/fixtures/capture.lua). Do not edit.
return {
  locations = {
    ["Player-1-0000A001"] = {
      seenAt = 1001,
      zone = "Durotar",
    },
    ["Player-1-0000B001"] = {
      seenAt = 1001,
      zone = "Durotar",
    },
  },
  people = {
    ["Bob#2002"] = {
      aid = "b8401522f710",
      chars = {
        ["Player-1-0000B001"] = {
          classFile = "ROGUE",
          faction = "Horde",
          guid = "Player-1-0000B001",
          ilvl = 1,
          lastPlayed = 1000,
          level = 22,
          name = "Bob Example",
          professions = {
            [185] = {
              max = 75,
              name = "Cooking",
              rank = 2,
            },
            [186] = {
              max = 150,
              name = "Mining",
              rank = 64,
            },
          },
          raceID = 6,
          realm = "Classic Beta PvP",
          updatedAt = 1000,
        },
      },
      receivedAt = 1002,
      version = 1000,
    },
  },
  presence = {
    ["Player-1-0000B001"] = {
      battleTag = "Bob#2002",
      lastSeen = 1001,
    },
  },
  runs = {},
  schemaVersion = 1,
  self = {
    accountId = "093c975edb2d",
    battleTag = "Ada#1001",
    chars = {
      ["Player-1-0000A001"] = {
        classFile = "MAGE",
        faction = "Horde",
        guid = "Player-1-0000A001",
        ilvl = 1,
        lastPlayed = 1240,
        level = 21,
        name = "Ada Example",
        professions = {
          [185] = {
            max = 75,
            name = "Cooking",
            rank = 2,
          },
          [186] = {
            max = 150,
            name = "Mining",
            rank = 64,
          },
        },
        quests = {
          [5001] = {
            dungeon = false,
            title = "A Fixture Quest",
          },
        },
        raceID = 6,
        realm = "Classic Beta PvP",
        updatedAt = 1060,
      },
    },
    feed = {
      [20744] = {
        ["Player-1-0000A001"] = {
          at = 1060,
          classFile = "MAGE",
          levelFrom = 20,
          levelTo = 21,
          name = "Ada Example",
        },
      },
    },
    version = 1060,
  },
  settings = {
    chatAlert = true,
    chatKeepGeneral = true,
    chatSound = false,
    chatTab = {},
    chatTabPrompt = {
      ["Player-1-0000A001"] = true,
    },
    clubId = "40000001",
    clubName = "Test Friends",
    minimap = {},
    notifications = true,
    onboarded = true,
    onboardedVersion = 1,
    sendInterval = 0.2,
    shareActivity = true,
    tree = {},
    window = {},
  },
}
