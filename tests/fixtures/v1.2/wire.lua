-- Golden fixture v1.2: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "636c534a29660ccacecb2fcf132b1048cc4cb132b0344eb634374d4d49324a1171132a09f270f5f1f1372a4b2d6ab1534a2a81284ab23031303435324a333734504a2c0b32d033d433502a2863562a2a6504fc",
    message = {
      av = "0.1.0",
      bt = "aid:b8401522f710",
      ds = 0,
      known = {
        ["aid:093c975edb2d"] = 1121,
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
    hex = "3552d16a134d1426a4296983506b596d3010160c686c48138cb66021d376db5fadb643d15b67774e92219399716676d37a67e88db741f0fec727e893cc551fc027109fc0c956e772ce77beef3be73b856cddc6f870ff1d3e0863abd608a3bbed9d6eb2f3fc19d0b8437506da302936a25065453c94849b416cac06322e2025252fe129c0d80485f7da4c895240033d6d517269bab3692b19116dba6eb9d431605ffd9cb6044c0f523104294cc7adf88fa196a93a4bc158df10b7680adc74119502564362aff650ec4b05b4205cc51a3ccd8342a58d06e085ca67e540dd3de5e412f4d6f656dbbf7ebbbd7da385b424e610945f2c176706cc6204536d84567ac2819693ab3d3c669c9b60de37231019e150445c4a1b20502ca9f64246cbdbbf30870c7813093281df7d9d10c12cd43110051a0d25a78d78489801025ac04681b04b9d9802b12353edaddba50827243580a51d79f8673f92db9ca94cbd5e285723f7c86de6a8c9e59b8c375d6d7ea4d9a47e9e9af13cd78dbcd1c77e094b91ab5df729a91f5e9089e2304f383126621cd049ffe850e7e073d9c4f9f26ea53b53293e8699b94632fed787f33402b7718318cf78110d5346dd46c75bcae68b148fa590fae52ca7f92045311c8defbbb032d3448cdffa15e0239d0a9b43f3194a685129f958089fa8b5fd852d96d41158523fcd4ee7a9a2c402ed7b3ffffb9acd93a2577baee69eb8a67baa0724b13e1a7c2c35856ba5e5e06f568d1f955e67422ee88aabc5274c303174bb5fbe557a0e7d7735bd2fe538ff2ab987cdf8537e3d41f9ded786a6b7c735c29659ee33ab47ecc2a61aeaf989c59a24f0dfc19d3f",
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
      version = 1121,
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
