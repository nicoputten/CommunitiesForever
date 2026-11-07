-- Golden fixture v1.6.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "2d904f6b134118c65d8a366d50fc038b951a4384a0872e498a955e023b69d25aa8a67ba8e77777de4d864c66d699d96c7a3414c16b09780f7e827c841e3c0f7e947e02676be734bcbccff33ecfcffbf1dcc451bff7253a6ac466115278db6eb5da6a864a332996dd4636db884612b84e636d14c2c42399947c332a1027daf72e942e20cb906edb479b1d8de674550431cff11841dd1441c21144940bddf95b04142e43413fb3d1d82ce280e6c8f53ea152e07603cc5597c4a88d47dc96f6771f5cd84ae969b74ed73410580c78a9bba64e274f72616ecb9f18a11403c550d055167067f555f2d43ef96f182974895e7ad5560718bd691dee27871f3f208d3b94a488d4af9c57fcecd990c325aabdf65ecbbdd0f51fdca9171a754941bf6a368c74f15225a757ddeb8483d603c6919c85c77d22608a6b47aede9fc334e318256350dab73b7f08e333be414639a376275690e0a7a3c776d7be8e38ce90bf5f674aa6f7379abfab079d29cce996adc5674c3031220ac4e4fbb27a609bbf6c4df5a49cb8a97df7d0d6ec1b9542629c303a918ae2ca45327735a80b9867140cd2d02cbbf1b7dc31d57ee5c5cfa6bac7358e0c331c6fc3fa80cd4daeb07e5e2e3958c0a7d9d35e598f25758206eac3d9f0df",
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
            pool = 3,
            set = {
              [1] = "d.newFlight",
              [2] = "d.duoHunt",
              [3] = "d.dungeonFriend",
              [4] = "p.loneWolf",
            },
            swapped = {},
          },
        },
        pool = 3,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 3,
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
    hex = "4d90416e13311486892ad4900829b08810453004a92b329a0c50108b48759ab45482164b94f5f3f8cd7414c7b66c4fa65d12e50415827dc409b2e001023d81c5513801034e618157d6d3fbfff7fd7fe31b610e8a0551ec599a24e97dc7e87874420f7acce90e94fc2d7bf33219bc4ad3fcf520317334b6547239ece9f9162d14089b33eb0cc2b441b452629bd68853db6d9c195b83d6c85bbeb99d5a74c7ab3a66a2c24304735dc7994090b49236fd55c71c2ef725ff5016e76ec1625ea1b02f0857125b3d70cb2161685d83842ddb7d74ebccb7369ebe7dbce6b1c47a2236ba2b1e74eaa892eef7e6270b5472624a947ca56311ac3e2b91fbce5f436a30103d68b4933444bcfe3f22c91179b7f9b1d9d5f74e055ca2e90ffa4978244906931bf5c2a2ddb4601feef69c0a78b951b3e5f02a1360eda41448e9c9e1a7319130c37528361a5fc04c8771760ec676fdce4f528ab9d822455572bfe31ffb27cc4086ef0eee528173147d1ff9a72687cc852bf448198eabe0ed6e7878b854690e0ef97e80596ba3f27f3cbb3fda7be90c2ef81d1fb1f7a52c65410cc8e997afed3dfffcbb8fcc48a96998faf876a80102c44c77461be8328b083a884ee7a77ffe",
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
            pool = 3,
            set = {
              [1] = "d.newFlight",
              [2] = "d.duoHunt",
              [3] = "d.dungeonFriend",
              [4] = "p.loneWolf",
            },
            swapped = {},
          },
        },
        pool = 3,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 3,
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
    hex = "3592cd6e1331148515256d4323a4d24a4315b208118a54a246692a0245a2d2b834e1afa5b52ad8e219df24d638b6b13d93961d51376c2324f6154fd047e0092c167d0ec413e00ce0a5eff1b9e7decf856cdd46f8f0e02d7ede88ac5a238c3eedecedc67b8f1f01038dba5467a00d93a2d46fa8ac88479270338c8cd54092025252f2153c05484c5078a7cd94280574d52daf740dd85757d376c453180102d13fa6ed9803113815a6fb73daa6e42214f4988dc67616b5690adcec222a05ac3688bddc4711185b405e6556b1066fb659a874d0108006e5d372a0ee9c707201037a7b67bbe34fd8e9ecdc68212d893804e527cbc5990103b3c86daacd8695de70a8e5e4721f278c7313cc43330691110e45c4a5b4010302c5e26aafc16879e717e69001036f214126f03bd43111cc421d0351a0d14872da8c468409a0056c14085bea4614881d9b6a6fdd96fa3826a901032cedd8cb3ff991dce64c65eaf5a273b5ef1eb8cd5c35b97893f196abcd079a4dea67a949e679dfbe0fbae59750eabbda754849fdf09c4c148779cc89317dc601031d8583439d8bcf640be7cbfbdbba3b95e2432333d74846ffdfe1784cb409dcc60d623ce345344a19751b5d1f299b2fd0bd9042ea67b3dce6bd14c5c638b9ebee57669a88e4d8af01020f742a6c2ecd6758428bca92c742f844ad1d2c62b1b88ec092fa4976324f15251668e8f35cf99acd49d1cb7d57735beea16be92189ad47835f484de15a6939fcc7aaf9bdd2eb4ec839bde56ad111134c8cdcdee7af959e0bbfb99a3e9032c9af96dcbd56f431f55fc404e58d2f4d4d53310229c6d832cb3db37a9f9ddb5443fd74218a3489e1e5f3db7ffe",
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
        pool = 3,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 3,
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
