-- Golden fixture v1.8.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
return {
  [1] = {
    hex = "634c734ace482cdae4949fa4e05a91985b9093aa5450c6ec9456949f6b041454ca4c093234b43030142a4972f40b0e770d4a4acc2b2e4f2d0aca492c492d02fc",
    message = {
      answer = "later",
      char = "Bob Example",
      from = "Bob",
      id = "11801",
      pv = 1,
      t = "ANSWER",
    },
    name = "bn-ANSWER",
    sender = "B",
  },
  [2] = {
    hex = "63dce654905f5c92e0945e9a99522018909358995aa46ba86b0102048e0606864a99294186861606864225468ec1de4ec91989459b1c5312155c2b12730b72529d8af273528d520a8a9d324b52730b840d2c8d932dcd4d5353928c5274411a750d9dd28af2738d807a940aca988b524af3d253f3f3dc80062ba5e41ae52656983ae525e6a65e0ac9485570494d4cc9cdcc4b2d360292ca4a8925473c0103",
    message = {
      at = 1180,
      char = "Ada Example",
      dungeon = {
        id = "dm",
        max = 26,
        min = 17,
        name = "The Deadmines",
      },
      from = "Ada",
      guid = "Player-1-0000A001",
      id = "11801",
      item = "093c975edb2d-1180-1",
      post = true,
      pv = 1,
      role = "dps",
      t = "ASK",
    },
    name = "bn-ASK",
    sender = "A",
  },
  [3] = {
    hex = "636c534a29660ccacecb2fcfe3122a09f270f5f1f1372a4b2d9a62a79454d2e49892a86c686060a894581664a067a867a05450c6ac5454ca08f8",
    message = {
      av = "0.1.0",
      bt = "Ada#1001",
      ds = 0,
      known = {},
      pv = 1,
      ru = 0,
      t = "HELLO",
      ver = 1001,
    },
    name = "bn-HELLO",
    sender = "A",
  },
  [4] = {
    hex = "630c534a2c39e2a95450c6ec9456949fbbc9312551c1b52231b72027b5a820312525332f7d51051c0895380578fab903fe",
    message = {
      at = 1180,
      from = "Ada Example",
      padding = "xxxxxxxxxx",
      pv = 1,
      t = "PING",
    },
    name = "bn-PING",
    sender = "A",
  },
  [5] = {
    hex = "630c534a2c39e2a95450c6ec9456949fbbc9293f49c1b52231b7202755a8c429c0dfcfdda938b32a5514f0",
    message = {
      at = 1180,
      from = "Bob Example",
      pv = 1,
      size = 10,
      t = "PONG",
    },
    name = "bn-PONG",
    sender = "B",
  },
  [6] = {
    hex = "2d904f6b134118c60d45491b14ffc02241cd1221d2439724c54a2f819d34a90ab5e9823d787b77e7ddcd90d9997566369b1e0d45f02a0103efc54fd08f9083e7c18fe22770129de3cbf33cf37b9edad7c7268e46c3f3e8a41d9b6548e165afdbeda9392acda4580ddac57c27ca24709dc6da2884598d1452f2465421ceb457bb54ba82a240ba67ef35fa1acdfb9b2a887989a7086a5d05094710512974ff771550b80a05fdc0b2a959c601032d91eb4342a5c0bd3698eb010389519b1a712aed3dbb7369eb9b4cbbfb694d831c181f2b86822e6990f26d020d10cc79259685bb40f6b120d35218fbe05f58a4d0d13cad35ba7d6074dd3d3e4c8edfbc461af7294911a957bfa87bc5a309872b5407bd83ae7ba1eb3edeba971af5660103ddecb48d7468a992f9f5e07bc241eb31e348cec2d3111190e3ad5bcd1f2d202f3846c91494f66cf317617cce774856326a9bb18204df9ddcb7cfed8b88e31cf9fe6da164faff8fcecfc6513f8705ddb5adf88c092632a240ccbeac1a47f6d50fdb52432967ee6af7efda96f5550a8971c6e8ad54146f1c92d9d6a00eb02c2818a4a1590de2cfa5db537bf527df3a8a96224329a6916186e39fd01fb3852915fa171b911b0b785e3c1c6eeab1c42768c09fcc277fff",
    message = {
      aid = "093c975edb2d",
      bt = "Ada#1001",
      chars = {
        ["Player-1-0000A001"] = {
          classFile = "MAGE",
          faction = "Horde",
          guid = "Player-1-0000A001",
          ilvl = 1,
          lastPlayed = 1000,
          level = 20,
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
          updatedAt = 1001,
        },
      },
      feed = {
        [20744] = {
          ["Player-1-0000A001"] = {
            at = 1000,
            classFile = "MAGE",
            name = "Ada Example",
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
      pv = 1,
      t = "RECORD",
      version = 1001,
    },
    name = "bn-RECORD",
    sender = "A",
  },
  [7] = {
    hex = "6334534a2a69724c495436343030542a2863162a310a720d04fc",
    message = {
      bt = "Ada#1001",
      pv = 1,
      t = "REQ",
    },
    name = "bn-REQ",
    sender = "A",
  },
  [8] = {
    hex = "6354532a2863162a31728a7405fc",
    message = {
      pv = 1,
      t = "BYE",
    },
    name = "whisper-BYE",
    sender = "C",
  },
  [9] = {
    hex = "639ca69452cce894549298dee4949fa46c64606014949d975f9e275620909899626560699c6c696e9a9a926494c2e2265412e4e1eae3e36f54965ad462a7945402519464616260686a6494666e68a094581664a067a867a05450c6ac5454ca08f8",
    message = {
      av = "0.1.0",
      bt = "aid:b8401522f710",
      btag = "Bob#2002",
      ds = 0,
      known = {
        ["aid:093c975edb2d"] = 1120,
      },
      pv = 1,
      ru = 0,
      t = "HELLO",
      ver = 1000,
    },
    name = "whisper-HELLO",
    sender = "B",
  },
  [10] = {
    hex = "4d90c18a134110860d8b103308d14310099844d85bc6c9a8ab78086c679355411307760fde6aa66b264d7aba9bee9ecceed1902710d1fbe213ecc107c813343e919de8c13efe747df5d5dff84e520bc586c8f4691c45f1439b26d3c93c391ba456b581d137e9eb17d1e8651ce7af46915ea3364c8aed78a0d6474921819b3c355623ac1a4449c983a4465c994ee3529b1a9442da72cd203668dfdfd461ca2b3c47d0bb3acc3882482a61e2df7548e1fa54d08fac58da4d1ad20ab9794ea814d81a80dd8e498ac63688ff653add3b97aeb567bae0f38e8625303ed30c05ddd030e707020d11ecbc161be513282e145956c2baf65f58a2d1db3c6a0451eccfdbfd7f1ec91169a7f9a9d9510f161cae510f47c3c83f1245a3d9617a63d0ec1b308f8f07567ab55ccb723bfe9a713066c63826c9fcfc624a049478eb4bed4dafa0543ece96a04dc7757f11c6d7fc881415a3aeeb9eb85eaa21c37767f7138e6be443d777039d4366fd96e4add4146f3cdb1e7ca8df54290a16e9a997b9555ae6ff7c8e7f0627710957f49eeba71f9860a2201ac4eacbb7e0c40d7fb8be9e48b9f2a97b76d7570102bc54edc95e9a653d82167a8bf5e2cf",
    message = {
      aid = "b8401522f710",
      bt = "aid:b8401522f710",
      btag = "Bob#2002",
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
      pv = 1,
      t = "RECORD",
      version = 1000,
    },
    name = "whisper-RECORD",
    sender = "B",
  },
  [11] = {
    hex = "3592cd6e133114851525ad4223a4d24a4315b2182214a9448dd254048a44a571dba4fcb4b456055b3ce39bc48a631bdb3369d91175c33642625ff1047d049ec062d1e7403c0103ce01025efa1e9f7beefd5cc8d66c8c0ff7dfe2837a6cd52a61f4797b7727d97dfa0468dca13a036d9814a55e5d65453c94849b416cac06322e202525afe029c0d8048577da4c89524057dc72a563c0beba9eb6629e421f88fe316d251c88c0a9309d9fd316259791a0276c38b2b3b84553e06607512960a54eecd51e8ac1d802f22ab3823578b38d42a58d06010234289f950375ef94934bd05bdb5b6d7fa2767bfb560b6949cc21283f5b2ece0c98456e536dd4adf486032d27577b78cc3837c13c32231019e150445c4a1b20502ca976eb8c96b77f610e19f026126402bf239d10c12c841888028d8692d3463c244c01022d60a340d85227a640ecc854bb6bb6d4c309490d6069475efec98fe436662a53af179dab3df7c86de4aac9e59b8c375d6dded76c129ea7663ccffbf67cd04dbf8452cfd56e224ac2c30b32511ce60927c6f41807741cf50f752e3e974d9c2fef6febce548a0ff5ccdc2019ff7f879311d12670ebb788f18c17d13065d4ad777ca46cbe40772485d42f66b9cd7b298af5d1f8be7b58996922c6277e05b8af536173693ec3125a54963c16c2276a757f118b2521024bc2d3ec749e2a4a2cd0c8e7b9f6359b93a2577baee636dd63d7d40392588f061f494de1466939f8c7aaf1bdd2ed4cc805bde36af131134c0cddeee7af95ae8bbeb99ade97729c5f2db907cdf863eabf8809caeb5f1a9aa66208528cb065967b66618f5dd8544378b610c59a24f0f2e0ee9f",
    message = {
      bt = "aid:093c975edb2d",
      chars = {
        ["Player-1-0000A001"] = {
          classFile = "MAGE",
          faction = "Horde",
          guid = "Player-1-0000A001",
          ilvl = 1,
          lastPlayed = 1000,
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
      feed = {
        [20744] = {
          ["Player-1-0000A001"] = {
            at = 1120,
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
      pv = 1,
      t = "RECORD",
      version = 1120,
    },
    name = "whisper-RECORD-relay",
    sender = "B",
  },
  [12] = {
    hex = "6334534a2a291048cc4cb14ab23031303435324a333734502a2863162a310a720d04fc",
    message = {
      bt = "aid:b8401522f710",
      pv = 1,
      t = "REQ",
    },
    name = "whisper-REQ",
    sender = "B",
  },
  [13] = {
    hex = "6374732a4fcc2b291048cc4cb132b0344eb634374d4d49324a514a82099a59585a5a1a259a9b1a582a1594310b951805b90602fe",
    message = {
      bt = "aid:0689992a7509",
      pv = 1,
      t = "REQ",
      want = "aid:093c975edb2d",
    },
    name = "whisper-REQ-want",
    sender = "C",
  },
}
