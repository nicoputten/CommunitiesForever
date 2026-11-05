-- Golden fixture v1.3.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "3d51dd6a134114762991d4206a8545ace81a2120d8253f58e94d20931f6ba198ee45ef67764ed221b333e3ccec6e7a692882b725e0bdf80479042fbc1e7c041fa14fe0642dcee577e6fb39df09beec59928c871f935193d8d580e2579d76bba30bd08649b1ee3755b193cc25e666468cd5801701035252f25a52022c4c189c6b5362a58086ba8c29be34bd5519a717589b9ebb5beb1ab0277fca584039cac51ca4305db7eb81b996b93acbc1584f2031cd819b1ea252c0bd26b6577d44fc28405bc1f0d99d73570fafa9ff5549ac68cc6549187803d738b9f93f986806826ee8d6df1e03e7d2edfd56712eaccc3d4438b807ffe4130d3ed993a0d1ee62467fb68f7ae9d1bbb7404997a219f865ea67f5503d9a727c09faa073d0f66fe08b9954ec950103b3adc73c6d35adf461675a6657fdeb946363268c033a1dbc1f238133d8f84aa3f112678a4352d512bafd5f88f182efa079cea8dbffee59b672a25e2357145ba003bbde86c43c530f875b599646082c8ea6c5d445eea57bee5ee8194ead8f911c4b4d61a3b49cdde66afd681c7633bca4bb2e22a74c3031471a8bc5e775e3d0bdf9e6223d9472e15117d7120e05f0d7e453758cb0fef86b4bdff67991586639dc0ca2095bda5c43545d8c689cc287d1fdbf",
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
      pv = 1,
      t = "RECORD",
      version = 1001,
    },
    name = "bn-RECORD",
    sender = "A",
  },
  [7] = {
    hex = "6334132a310a720d542a2863564a2a69724c49543634303004fc",
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
    hex = "636c534a29660ccacecb2fcf132b1048cc4cb132b0344eb634374d4d49324a6171132a09f270f5f1f1372a4b2d6ab1534a2a81284ab23031303435324a333734504a2c0b32d033d433502a2863562a2a6504fc",
    message = {
      av = "0.1.0",
      bt = "aid:b8401522f710",
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
    hex = "4d504d6e133118655405a54488d2c508510443165d91d1640205b18884f343a9849a8e44f7f6f89bc18a635bb667a65d12451ca042628f3841163d010227b0380247e00438294278f99edfdf177cdeb7249b8c4eb3719758b587197d4d5e3d4ffa2fd2b478d94f740dda302956c3aeaa77b252626e0a62ac063c0f909292b7b206606ec2e05c9b062b0534d44d4cf1a5192c9b38ff88b519b8dbadd4803df9d5c4029a71254a90c2a46ed703a596953aabc0582f2031ad809b0103a252c09d2eb6ab21229e0ad0c6307c74ebdcb5c32bea7f6d2d9634e6b2210c7c80eb9cfcfe474c350341d774936f8f8173e9f67faab81256561e221cdcbd1bfb4c836ff620e824a9dffee3ffeda801023fa67dd60ed5fd19c797a07bfd5ee21f4a92fe74ab5e1a309bf39887875d2b7dd942cbc56a7895736ccc9471c8b2d3b71f2648e005ac9124d1e4022f9487b77709ddc13562bce63ba8ac187507dfbccc6ea3a837a914c516e89b9b96982fd4de68e3cbf20881c5d1ac9eb9c83d758fdd135de0dcfa1ed9b1d414d64acbe26fb1c3ef9da374812fe8ae8bc87b26982891c662fee94be7c83dfbea223d9272ee5117b7320e35f01ed1388777e3bb7ffe",
    message = {
      aid = "b8401522f710",
      bt = "aid:b8401522f710",
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
      pv = 1,
      t = "RECORD",
      version = 1000,
    },
    name = "whisper-RECORD",
    sender = "B",
  },
  [11] = {
    hex = "3552c16e133b145594a44a1b219552cda31191a29188f4088dd244045a894a71dbb40f28b456055b3ce39bc48ac736b667d2b223ea866df4a4b77fe20bfa255ef503f802c417e04cc14bdf73cf39f79e5bc8366c848f0edee1c330b26a9d30bad7d9edc5bbcf9f01038dba5467a00d93a2340c5556c46349b81945c66a20d3025252f2329e01034c4d5078afcd8c280534d0b3362557a6379fb5e309d1a6e756ca5d03f6d5f7595bc0ec30156390c274ddaaff186b99aaf3148cf50d519ba6c04d0f5129602d24f67a1f45be54404bc235acc1d33c2c543b68045ea8725e09d4fd334eae406fef6c77fc1b743a3bb75a484b220e41e5c54a716ec02c4730b56668a5271c69995cefe329e3dc048b819980c8088722e252da0102816271ad1f325ad9f9813964c05b4890047e0e744c04b3d0c040146834969c36a33161026801031b05c296ba11056227a6d6dfb0a5218e496a01024b3bf1f0cf7e24b73557997abd54ae0ddd63b795a392ab37196fb9fae258b3a471919ae922d71d7aa37ffb259486ae7e33a0a471744912c561117362cc907140a783e3239d832f640be7cbbb93eecea4f81866e606c9e84f1fced308dce62d623ce345344e19759b5d6f295b2c533c9142ea97f39ce68314c57032fdcb85d5b92662fad6af01021feb54d81c9acf5046cb4ad9c74278a2d60f96b658dc406049e32c3b5ba48a120b74e0fdfcef6b364f8a5eefbbba7be25aeea91e91d8fa68f089d4146e9496a3df5935bf55fbdd845cd255578f4e996062ecf6befc5bed3bf49fabeb0329a7f957d93d6a459ff2eb092a0fbe3635bd3bae09b6cc729f5963c82e6daaa1919f58a4490cff1cdefbf5",
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
      pv = 1,
      t = "RECORD",
      version = 1120,
    },
    name = "whisper-RECORD-relay",
    sender = "B",
  },
  [12] = {
    hex = "6334132a310a720d542a2863564a2a291048cc4cb14ab23031303435324a3337340102fc",
    message = {
      bt = "aid:b8401522f710",
      pv = 1,
      t = "REQ",
    },
    name = "whisper-REQ",
    sender = "B",
  },
  [13] = {
    hex = "6374732a4fcc2b291048cc4cb132b0344eb634374d4d49324a112a310a720d542a2863564a82499b59585a5a1a259a9b1a5802fe",
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
