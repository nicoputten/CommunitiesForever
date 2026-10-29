-- Golden fixture v0.9: CommunitiesForeverDB.global as schema 2 writes it (tests/fixtures/capture.lua). Do not edit.
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
  pending = {
    [1] = {
      at = 1180,
      dungeon = "dm",
      guid = "Player-1-0000A001",
      id = "093c975edb2d-1180-1",
      kind = "ask",
      name = "Ada Example",
      role = "dps",
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
      feed = {
        [20744] = {
          ["Player-1-0000B001"] = {
            at = 1000,
            classFile = "ROGUE",
            name = "Bob Example",
            sessions = {
              [1] = {
                from = 1000,
                to = 1000,
              },
            },
          },
        },
      },
      goals = {
        best = 0,
        days = {},
        pool = 1,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            set = {
              [1] = "w.zones5",
              [2] = "w.dungeonFriends2",
              [3] = "w.cap",
              [4] = "b.duels3",
            },
            swapped = {},
          },
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
  schemaVersion = 2,
  self = {
    accountId = "093c975edb2d",
    battleTag = "Ada#1001",
    chars = {
      ["Player-1-0000A001"] = {
        classFile = "MAGE",
        faction = "Horde",
        guid = "Player-1-0000A001",
        ilvl = 1,
        lastPlayed = 1300,
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
        pvp = {
          deaths = 5,
          duelsWon = 1,
          hk = 11,
          rank = 2,
          rankName = "Grunt",
          weekHonor = 30,
          weekKills = 2,
        },
        quests = {
          [5001] = {
            dungeon = false,
            title = "A Fixture Quest",
          },
        },
        raceID = 6,
        realm = "Classic Beta PvP",
        updatedAt = 1120,
      },
    },
    doomsday = {
      announced = {
        day = -1,
        keys = {
          ["swap:d.level"] = true,
          ["swap:d.quests10"] = true,
        },
      },
      chars = {
        ["Player-1-0000A001"] = {
          death = 1120,
          level = 1060,
        },
      },
      days = {
        [-1] = {
          altByChar = {},
          altLevels = 0,
          capReached = false,
          chars = {
            ["Player-1-0000A001"] = true,
          },
          cleanLevels = 0,
          craftTrade = 0,
          crafted = {
            [14342] = true,
          },
          days = {
            [-1] = true,
          },
          deaths = {
            [1] = {
              char = "Player-1-0000A001",
              t = 1120,
            },
          },
          discoveries = 0,
          duelFriends = {
            ["Bob#2002"] = true,
          },
          earlyBird = false,
          fish = 0,
          friends = {},
          huntDays = {},
          ilvlBase = {
            ["Player-1-0000A001"] = 1,
          },
          ilvlGain = 0,
          kills = {
            [1] = {
              char = "Player-1-0000A001",
              myLvl = 21,
              name = "Grim Tusk",
              t = 1120,
              zone = "Ashenvale",
            },
          },
          learned = 0,
          levels = 1,
          longestSession = 0,
          quests = {},
          rare = 1,
          runs = {},
          secondary = false,
          sharedMax = 0,
          skill = 0,
          skillBase = {
            ["Player-1-0000A001"] = {
              [185] = 2,
              [186] = 64,
            },
          },
          trades = 0,
          zone = "Ashenvale",
        },
      },
      weeks = {
        [0] = {
          altByChar = {},
          altLevels = 0,
          capReached = false,
          chars = {
            ["Player-1-0000A001"] = true,
          },
          cleanLevels = 0,
          craftTrade = 0,
          crafted = {
            [14342] = true,
          },
          days = {
            [-1] = true,
          },
          deaths = {
            [1] = {
              char = "Player-1-0000A001",
              t = 1120,
            },
          },
          discoveries = 0,
          duelFriends = {
            ["Bob#2002"] = true,
          },
          earlyBird = false,
          fish = 0,
          friends = {},
          huntDays = {},
          ilvlBase = {
            ["Player-1-0000A001"] = 1,
          },
          ilvlGain = 0,
          kills = {
            [1] = {
              char = "Player-1-0000A001",
              myLvl = 21,
              name = "Grim Tusk",
              t = 1120,
              zone = "Ashenvale",
            },
          },
          learned = 0,
          levels = 1,
          longestSession = 0,
          quests = {},
          rare = 1,
          runs = {},
          secondary = false,
          sharedMax = 0,
          skill = 0,
          skillBase = {
            ["Player-1-0000A001"] = {
              [185] = 2,
              [186] = 64,
            },
          },
          trades = 0,
          zone = "Stonetalon Mountains",
        },
      },
    },
    feats = {
      ["Player-1-0000A001"] = {
        _seen = {
          at = 1000,
        },
        firstEpic = {
          at = 1120,
          detail = "First epic · looted at level 21",
          title = "Arcanite Reaper",
        },
        ["honorKills:1"] = {
          at = 1120,
          detail = "The first honorable kill",
          title = "First blood",
        },
        ["level:10"] = {
          at = 0,
          detail = "Reached level 10",
          title = "Level 10",
        },
        ["level:20"] = {
          at = 0,
          detail = "Reached level 20",
          title = "Level 20",
        },
        ["notableItem:mooncloth"] = {
          at = 1120,
          detail = "The first Mooncloth",
          title = "Mooncloth",
        },
        ["pvpRank:2"] = {
          at = 1120,
          detail = "a.k.a. Accidental Flagger · rank 2",
          title = "Grunt",
        },
      },
    },
    feed = {
      [20744] = {
        ["Player-1-0000A001"] = {
          at = 1300,
          classFile = "MAGE",
          deaths = {
            [1] = {
              cause = "other",
              t = 1120,
              zone = "Ashenvale",
            },
          },
          duels = {
            [1] = {
              t = 1120,
              vs = "Bob Example",
              won = true,
            },
          },
          gold = {
            gained = 0,
            spent = 800,
          },
          kills = {
            Ashenvale = 1,
          },
          levelFrom = 20,
          levelTo = 21,
          loot = {
            epic = {
              [1] = {
                id = 12784,
                level = 21,
                name = "Arcanite Reaper",
                slot = "INVTYPE_2HWEAPON",
              },
            },
          },
          name = "Ada Example",
          notable = {
            [14342] = 1,
          },
          pvpKills = {
            [1] = {
              myLvl = 21,
              name = "Grim Tusk",
              t = 1120,
              zone = "Ashenvale",
            },
          },
          sessions = {
            [1] = {
              from = 1000,
              to = 1300,
            },
          },
        },
      },
    },
    goals = {
      best = 1,
      days = {
        [-1] = {
          at = 1060,
          done = {
            ["d.level"] = 1060,
          },
          set = {
            [1] = "d.bosses3",
            [2] = "d.quests10",
            [3] = "d.level",
            [4] = "p.untouchable",
          },
          swapped = {
            ["d.level"] = "d.shared3",
            ["d.quests10"] = "d.altLevel",
          },
        },
      },
      streak = {
        last = -1,
        n = 1,
      },
      weeks = {
        [0] = {
          at = 1000,
          done = {},
          set = {
            [1] = "w.zones5",
            [2] = "w.dungeonFriends2",
            [3] = "w.cap",
            [4] = "b.duels3",
          },
          swapped = {},
        },
      },
    },
    version = 1121,
  },
  settings = {
    ambientEffects = true,
    chatAlert = true,
    chatKeepGeneral = true,
    chatSound = false,
    chatTab = {},
    chatTabPrompt = {
      ["Player-1-0000A001"] = true,
    },
    clubId = "40000001",
    clubName = "Test Friends",
    levelUpToast = true,
    minimap = {},
    notifications = true,
    onboarded = true,
    onboardedVersion = 1,
    openOnLogin = false,
    sendInterval = 0.2,
    tree = {},
    window = {},
  },
}
