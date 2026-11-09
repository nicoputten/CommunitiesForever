-- Golden fixture v1.7.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "2d904f6b134118c60d45491a14ffc02241cd1221d2439724c54a2f819d34a90ab5e9823d787b77e7ddcd90d9997566369b1e0d45f02a0103efc54fd08fd083e7c18fe22770129de3cbf33cf37b9edad7c7268ec6a3b3e8b8139b5548e165bfd7ebab052acda4580f3bc56227ca24709dc6da2884798d1452f2465421ceb557bb50ba82a240ba6bef35061acdfbeb2a8879892708eab60a128e20a252e8c1ef2aa070190afa816533b38a035a22d707844a81bb1d30574312a33635e254da7b76e7c2d63799b6f1e9960639303e510c055dd120e5db041a2098b34aac0a7781ec634166a530f6c1bfb048a1a3795a6bf606c0e86defe820397af31a693ca02445a45efdbcee158fa61c2e51edf7f77bee85aefb64eb5e69d49b0574abdb31d2a1a54ae657c3ef0907ad278c23390d4fc644408e376e357fbc84bce018253350dab3ad5f84f105df2159c9a86dc50a127c777cdf3eb72f228e0be47b378592e9ff3fba3f9b87831c96b461dbf129134c644481987f59370fedab1fb6ad4652ceddd5eeddb56debab1412e38cd15ba9285e3b24b3ad411d605950304843b31ec69f4bb7a7f6ea4fbe75152d458652cc22c30cc73fa13f614b532af4cf37223716f0bc7838dad463894fd0803f5d4cfffe",
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
            pool = 4,
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
        pool = 4,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 4,
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
    hex = "4d90cd8a134114850d83901f84e82288044c22cc2e6da7d5515c04a632c9a8a0890d330b77b7bb6e778a54571555d5e999a5214f20a2fbc12798850f902728e689ac4417d6f250f7bbdf3db51f24b1906f884c9e4561183db2493c9dcce3b34162551b187d9bbc79198e5e4551f67a14ea356ac3a4d88e076a7d14e712b8c9126335c2aa469494bc1157882bd3a95d6a538152489baede880cda0f375590f012cf11f4ae0a528e20e25298e8ae0a285c9f0afa89e54bbb49025a22372f0895029b03b0db3149d0d81af1bf4ca77befd235f74cd7fab2a34101038ccf3443413734c8f8814003043bafc446f904f20b4596a5b0aefd17166bf4368f6bad30f2e7edfe3f8f6488b453ff5cefa8870b0ed7a887a361e81f09c3d1ec30bd3168f60d9827c7032bbd5aa665b11d7f4b391833631ce3787e7e3125020abcf5a5f6a65750281fa74bd0a6e3babf09e36b7e44f29251d7754f5d2fd190e2fbb30731c735f2a1ebbb81ce20b57e4bfc4e6a8a379e6d0f3ed46f2a15058bf4d4cbdc2a2db37f3ec7bf5a2751010357b4e1fac9472698c88906b1fafabd75e2863f5d5f4fa45cf9d43dbfef2b01025ea8f6642fcdd21e410bbdc57af1e7",
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
            pool = 4,
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
        pool = 4,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 4,
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
    hex = "3592c16e133d14851525add24648a595862a6431442852891aa5a90814894ae3b649e1a7a5b52ad8e219df24561cdbd89e49cb8ea81bb61112fb8a27e823f004168b3ec72f9e01026701022f7d8fcf3df77e2e64eb36c647076ff1613db66a8d30faa2bdb79bec3d7b0a34ee509d81364c8a52afaeb2221e4ac2cd203656031917909292afe029c0d8048577da4c89524057ddf24ac7807d7d336dc53c853e10fd63da4a38108153613a3fa72d4aae22414fd9706467718ba6c0cd2ea252c06a9dd8eb7d1483b105e45566156bf0669b854a1b0d010268503e2f07eafe192757a0b777b6dbfe44edf6ce9d16d2929843507ebe5c9c19308bdca6daa85be90d075a4eaef7f198716e827964462032c2a188b8943640a05852edd6192deffc8f3964c09b489009fc8a744204b31062200a341a4a4e1bf190300103b4808d02614b9d9802b12353edaedb520f27243580a51d79f9273f92db9ca94cfdb7e85cedb9c76e33574daede64bce96af3be6693f02235e379deb7e7836ef925947aae761b51121e5d9289e2304f3831a6c738a093a87fa473f1856ce27c797f5a77a6527ca867e616c9f8df3b9c8c883681dbb8438c67bc888629a36ea3e32365f305ba6329a47e39cb6dde4b51ac8fc60fdca3ca4c13313ef52bc07d9d0a9b4bf31996d0a2b2e4b1103e516b078b582c091158129e6567f354516281463ecf8dafd99c14bdde7735b7e59eb8a61e90c47a34f8586a0ab74acbc15f568def956e67422ee98aabc5274c3031747b9fbf56ba2efae66afa40ca717eb5e41e36e38fa9ff2226286f7c69689a8a214831c29659ee99853d7669530de1f942146b92c0abc37bbfff",
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
        pool = 4,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 4,
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
