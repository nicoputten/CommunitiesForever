-- Golden fixture v1.3.0: CommunitiesForeverDB.global as schema 2 writes it (tests/fixtures/capture.lua). Do not edit.
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
        pool = 2,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 2,
            set = {
              [1] = "w.newDungeons2",
              [2] = "w.days3",
              [3] = "w.groupQuests3",
              [4] = "b.duels3",
            },
            swapped = {
              ["w.days3"] = "w.chars3",
            },
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
          at = 1120,
          build = "?",
          detail = "victim Grim Tusk named, but not seen with race and class before the kill",
          status = "info",
        },
        V105 = {
          at = 1120,
          build = "?",
          detail = "created 14342: class missing/missing, quality missing",
          status = "pass",
        },
        V120 = {
          at = 1121,
          build = "?",
          detail = "C_DeathRecap.GetRecapEvents missing",
          status = "fail",
        },
        V121 = {
          at = 1000,
          build = "?",
          detail = "UnitIsPVP missing",
          status = "fail",
        },
        V123 = {
          at = 1000,
          build = "?",
          detail = "GetZonePVPInfo missing",
          status = "fail",
        },
        V55 = {
          at = 1000,
          build = "?",
          detail = "GameTooltip.AddDoubleLine missing",
          status = "fail",
        },
        V63 = {
          at = 1000,
          build = "?",
          detail = "date: 20:02",
          status = "pass",
        },
        V71 = {
          at = 1000,
          build = "?",
          detail = "time() 1793993400",
          status = "fail",
        },
        V73 = {
          at = 1120,
          build = "?",
          detail = "victim and rank from the honor message (rank Scout)",
          status = "pass",
        },
        V76 = {
          at = 1120,
          build = "?",
          detail = "IsInGroup missing, instance none",
          status = "fail",
        },
        V77 = {
          at = 1000,
          build = "?",
          detail = "region missing",
          status = "fail",
        },
        V78 = {
          at = 1000,
          build = "?",
          detail = "GetGameTime nil:nil",
          status = "fail",
        },
        V79 = {
          at = 1000,
          build = "?",
          detail = "lifetime missing, 0, 0, rank (nothing), deaths --",
          log = {
            [1] = "at a kill: lifetime 11, 0, 0, week 2, 30",
            [2] = "at a death: GetStatistic(60) 4",
          },
          status = "fail",
        },
        V80 = {
          at = 1120,
          build = "?",
          detail = "DUEL_WINNER_KNOCKOUT parsed with your name",
          status = "pass",
        },
        V81 = {
          at = 1120,
          build = "?",
          detail = "no cause source",
          status = "fail",
        },
        V82 = {
          at = 1000,
          build = "?",
          detail = "no riding skill seen (GetProfessionInfoBySkillLineID missing)",
          status = "info",
        },
        V83 = {
          at = 1120,
          build = "?",
          detail = "LOOT_ITEM_SELF matched, item 12784",
          status = "pass",
        },
      },
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
          zone = "Stonetalon Mountains",
        },
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
          pool = 2,
          set = {
            [1] = "d.dungeonFriend",
            [2] = "d.chatHello",
            [3] = "d.dungeon",
            [4] = "p.untouchable",
          },
          swapped = {
            ["d.dungeon"] = "d.lowbie",
          },
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
          pool = 2,
          set = {
            [1] = "w.newDungeons2",
            [2] = "w.days3",
            [3] = "w.groupQuests3",
            [4] = "b.duels3",
          },
          swapped = {
            ["w.days3"] = "w.chars3",
          },
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
