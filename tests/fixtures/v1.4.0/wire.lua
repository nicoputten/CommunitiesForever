-- Golden fixture v1.4.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "2d904f6b134118c65d8a366d50fc038b951a438480629724c54a2f819db4692d54d33dd4f3bb3bef26432633ebcc6c363d1a8ae0b504bc073f413e420f9e877e947e02676be734bcbccf6f7ef3783f9f9b383aec7d8d0e1ab1998714deb65badb69aa2d24c8a45b7914dd7a2a104aed3581b8530f64826255f8f0ac4b1f6bd73a50bc832a49bf6d17a47a339591641cc733c4250d74590700411e542776e8a80c24528e817361c99791cd01cb9de25540adc6c80b9ec9218b5f188dbd2fef683735b299976e364450381459f97b92bea72f23817e6b6bc89214ad1570c055d66010377a86f92a7f6c97f60a4d019bdf4aaad0e307adddadf4df63f7d441a77284911a95f39abf8d9b30103870b543bed9d963ba1fb7fff2e3dd7a8cb16f4ab66c348a7972a39b9ec5e251cb4ee338ee4343c3a240226b872cdd50f6730c93846c90894f6edd65fc2f894af9161cea8dd5aba94b97b893a469e51304843b32825814fb2a7bd12cb923a4103f5c174606bf68dddb6af550a89711ad1b15414579992e9bd57f34f75af338119ddb0b5f894092686448118ff5854f7ecfbdfb6a67a528eddd47e7818719c227f177fcf5dc7daafbcf8d554f7f58d22c30cc7dbb0de6733932bac9f954bb182043f1f3cfef7",
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
    hex = "4d90416e133114861955a82111526011218a60085257643419a0201691ea3469a9040d2351d6cfe337d3511cdbb23d99764994135408f6514f900507e8092c8ec209705a1678653df9fffcfd2ff841a8856241247d91c471f2d0d274343c490fbad4aa3694ec3d7df73aeebf4992fc6d3fd673d4a6946239e8aaf9565a48e026a7c66a84694094947c3bad11a7a6139c6a538352c89aaeb19d18b4c7ab3aa2bcc243047d5d4719471069254cf2bb8e185cec0bf6a92cceec8246ac426e5e11260536bb60970342d1d880f857a6f3e4cea96b6e98ae75bc6691c07acc37b94be673f2a812f6cfe6260a9462ac4b146ca522ee515f25cf5dfb16986af4468f82569cf88ad7ff57243922eb343e373aeac184c305ea5ebf17fb43e2b83fbe492f0c9acd16cce3ddae955e2fd772b61c5c661c8c19971cd3f4e4f0cb880898e1da2f361c9dc34cf9717606da74dcce2f52f239df22455532b7b3f2317bf315f3904a31b0c8f66f2d81cf547bb8e1965948d04238994f5ce89ebba7ee99ce21b3de233d929ae15a6999ff13dbbd6aed25333867f75c483f96a21405d120a6dfbeb7f6dccb9f2ed44329a77eeaa2bb29c739f21ed590e18783fb7fff",
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
