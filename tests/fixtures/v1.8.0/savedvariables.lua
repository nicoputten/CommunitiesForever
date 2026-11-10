-- Golden fixture v1.8.0: CommunitiesForeverDB.global as schema 3 writes it (tests/fixtures/capture.lua). Do not edit.
return {
  liveKills = {},
  locations = {
    ["Player-1-0000A001"] = {
      seenAt = 1300,
      zone = "Ashenvale",
    },
    ["Player-1-0000B001"] = {
      seenAt = 1300,
      zone = "Durotar",
    },
  },
  members = {
    ["Player-1-0000A001"] = {
      name = "Ada Example",
      seenAt = 1001,
    },
    ["Player-1-0000B001"] = {
      name = "Bob Example",
      seenAt = 1001,
    },
    ["Player-1-0000C001"] = {
      name = "Cy Example",
      seenAt = 1001,
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
        pool = 5,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 5,
            set = {
              [1] = "w.blueGear",
              [2] = "w.cleanRuns2",
              [3] = "w.dayAndNight",
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
  probe = {
    results = {
      forever = {
        Hunt = {
          at = 1121,
          build = "?",
          detail = "kill counted, no victim: no enemy player as target, mouseover or nameplate dead or at low health, 0 candidates",
          log = {
            [1] = "UnitIsDead missing, target dead missing, target health missing",
          },
          status = "info",
        },
        V123 = {
          at = 1000,
          build = "?",
          detail = "GetZonePVPInfo missing",
          status = "fail",
        },
        V82 = {
          at = 1000,
          build = "?",
          detail = "no riding skill seen (GetProfessionInfoBySkillLineID missing)",
          status = "info",
        },
      },
    },
  },
  runs = {},
  schemaVersion = 3,
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
      celebrated = {
        friends = {
          ["Bob#2002"] = {
            chars = {
              ["Player-1-0000B001"] = true,
            },
            keys = {
              ["Player-1-0000B001:level:10"] = true,
              ["Player-1-0000B001:level:20"] = true,
            },
          },
        },
        own = {
          ["Player-1-0000A001:feat:firstEpic"] = true,
          ["Player-1-0000A001:feat:honorKills:1"] = true,
          ["Player-1-0000A001:feat:notableItem:mooncloth"] = true,
          ["Player-1-0000A001:feat:pvpRank:2"] = true,
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
          battle = {
            flagBest = {},
            flagRun = {},
            flagged = {},
            killers = {},
            zones = {},
          },
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
          extended = {
            aliveMax = 0,
            cleanRuns = {},
            crafted = 1,
            fed = 0,
            fishFriend = 0,
            fishNight = 0,
            fishZones = {},
            green = 1,
            groupDays = {},
            night = false,
            profit = false,
            reward = 0,
            sessionMax = 0,
            tradeFriends = {},
          },
          fish = 0,
          friends = {},
          huntDays = {},
          hunts = {
            Alliance = {
              class = "ROGUE",
              race = "Orc",
            },
            Horde = {
              class = "HUNTER",
              race = "Human",
            },
          },
          ilvlBase = {
            ["Player-1-0000A001"] = 1,
          },
          ilvlGain = 0,
          items = {
            bandageFriend = false,
            bandageKinds = {},
            bandages = 0,
            bandagesUsed = 0,
            blueGear = false,
            buffFriend = false,
            coins = 0,
            cookKinds = {},
            cookRecipe = false,
            cooked = 0,
            eatOwn = false,
            equipNew = false,
            fine = 0,
            gathered = 0,
            hadJunk = {},
            looted = {
              ["Player-1-0000A001|12784"] = true,
            },
            potions = 0,
            recipes = {},
            scrolls = 0,
            tidy = false,
            wellFed = false,
          },
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
          places = {
            carry = 0,
            carryDays = {},
            chat = 0,
            chatDays = {},
            crossSea = false,
            daredevil = false,
            newZones = {},
            nostalgia = false,
            onlineMax = 1,
            sameZone = false,
            zones = {},
          },
          quests = {},
          rare = 1,
          records = {
            dingDungeon = 0,
            dingFriend = 0,
            dustOff = false,
            levelDays = {
              [-1] = true,
            },
            lowbie = 0,
            newDungeons = {},
            skillBase = {
              ["Player-1-0000A001"] = {
                [185] = 2,
              },
            },
            skillGain = {},
            speedRun = false,
            switchUp = false,
          },
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
          world = {
            bank = 0,
            bestStreak = 0,
            bigFoes = 0,
            buys = 0,
            duo = 0,
            elites = 0,
            flights = 0,
            groupPic = 0,
            hearth = 0,
            kills = 0,
            mailFriend = 0,
            newFlights = 0,
            places = {},
            rares = 0,
            repairs = 0,
            ride = {},
            sales = 0,
            streak = {
              ["Player-1-0000A001"] = 0,
            },
            swim = {},
            trainer = 0,
            weaponUps = 0,
            whispers = 0,
          },
          zone = "Ashenvale",
        },
      },
      dungeonsSeen = {},
      lastLogin = {
        ["Player-1-0000A001"] = 1300,
      },
      weeks = {
        [0] = {
          altByChar = {},
          altLevels = 0,
          battle = {
            flagBest = {},
            flagRun = {},
            flagged = {},
            killers = {},
            zones = {},
          },
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
          extended = {
            aliveMax = 0,
            cleanRuns = {},
            crafted = 1,
            fed = 0,
            fishFriend = 0,
            fishNight = 0,
            fishZones = {},
            green = 1,
            groupDays = {},
            night = false,
            profit = false,
            reward = 0,
            sessionMax = 0,
            tradeFriends = {},
          },
          fish = 0,
          friends = {},
          huntDays = {},
          ilvlBase = {
            ["Player-1-0000A001"] = 1,
          },
          ilvlGain = 0,
          items = {
            bandageFriend = false,
            bandageKinds = {},
            bandages = 0,
            bandagesUsed = 0,
            blueGear = false,
            buffFriend = false,
            coins = 0,
            cookKinds = {},
            cookRecipe = false,
            cooked = 0,
            eatOwn = false,
            equipNew = false,
            fine = 0,
            gathered = 0,
            hadJunk = {},
            looted = {
              ["Player-1-0000A001|12784"] = true,
            },
            potions = 0,
            recipes = {},
            scrolls = 0,
            tidy = false,
            wellFed = false,
          },
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
          places = {
            carry = 0,
            carryDays = {},
            chat = 0,
            chatDays = {},
            crossSea = false,
            daredevil = false,
            newZones = {},
            nostalgia = false,
            onlineMax = 1,
            sameZone = false,
            zones = {},
          },
          quests = {},
          rare = 1,
          records = {
            dingDungeon = 0,
            dingFriend = 0,
            dustOff = false,
            levelDays = {
              [-1] = true,
            },
            lowbie = 0,
            newDungeons = {},
            skillBase = {
              ["Player-1-0000A001"] = {
                [185] = 2,
              },
            },
            skillGain = {},
            speedRun = false,
            switchUp = false,
          },
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
          world = {
            bank = 0,
            bestStreak = 0,
            bigFoes = 0,
            buys = 0,
            duo = 0,
            elites = 0,
            flights = 0,
            groupPic = 0,
            hearth = 0,
            kills = 0,
            mailFriend = 0,
            newFlights = 0,
            places = {},
            rares = 0,
            repairs = 0,
            ride = {},
            sales = 0,
            streak = {
              ["Player-1-0000A001"] = 0,
            },
            swim = {},
            trainer = 0,
            weaponUps = 0,
            whispers = 0,
          },
          zone = "Stonetalon Mountains",
        },
      },
      worn = {
        ["Player-1-0000A001"] = {},
      },
      zonesSeen = {},
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
      best = 0,
      days = {
        [-1] = {
          at = 1000,
          done = {},
          pool = 5,
          set = {
            [1] = "d.mailFriend",
            [2] = "d.flight",
            [3] = "d.eatOwn",
            [4] = "p.flagUp",
            [5] = "hunt",
          },
          swapped = {},
        },
      },
      streak = {
        last = -1,
        n = 0,
      },
      weeks = {
        [0] = {
          at = 1000,
          done = {},
          pool = 5,
          set = {
            [1] = "w.blueGear",
            [2] = "w.cleanRuns2",
            [3] = "w.dayAndNight",
            [4] = "b.duels3",
          },
          swapped = {},
        },
      },
    },
    version = 1120,
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
    clubType = 1,
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
