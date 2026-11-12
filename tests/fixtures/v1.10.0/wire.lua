-- Golden fixture v1.10.0: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "2d904d6b134118c70d45491b22bec02256748d1054e892a458e925b0932655b19aeea19e9fdd79928c999d196766f372b494825709780f7e827c841c3c0f7e143f8193e81c87e7f93fbfffaf747dcfa649b7f33139a9a5f632a6f0acd96834f504b561522cda3535d9498612b819a4c66a8471892829793599228e4d50bad0660a4a21dd73b7aa2d83f6dd721aa5bcc05304bd9e4619471049214cebf734a2308f05fdc086237b9946b4406e0e099502f76a60afda2445634bc44f99e0d18d0b57de64baddcf6b1ae5c0784f331474452383991414f45cd388e304f94a4528309fbf0741c9a81076a9a254dad1279fe46eff0b4f347aba07a54aa3058cae1bc787d9f1eb5748d3162503441a94cfcb81badbe730477dd03c68f8177b17bdedf6a541b331621ed66b567ad48196f955fb7bc6c1981ee348cee2d32e1190e3ca5b0cbb33c815c7241b813681dbff45189ff01d322c1875fba9860cdf9e54dd63f724d93678b1525a0efedfa8ffac1cb57298d15d17a6674c3031241ac4f8eba272e49eff70a1ee4839f6bfeee54d17baa77a010299f58bc91ba9292e3d92ddd6a01eb050142cd2d82edae997c2fb3541f9feb7baa68518a214a3c432cbf14f1cf6d8cc161ac3f3cd9097053c57773a9b7a2c0b095a08fb93fedf",
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
            pool = 6,
            set = {
              [1] = "d.mailFriend",
              [2] = "d.secondary",
              [3] = "d.level",
              [4] = "p.enemyLand",
              [5] = "hunt",
              [6] = "p.bothWays",
            },
            swapped = {},
          },
        },
        pool = 6,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 6,
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
    hex = "4d90c18a134110861d16212604a28720e2429c85bd65988cba8a87c07636591575e380ebb97aba2619d3d3dd74f7249ba3214f20a2f7b04f90830f9027687c223bd1837d2cbabefafe3ff841a885c98a487a92c471f2c0d27438b84a2f426a550b0af68abe7c16f79e2749fea217eb396a5348b1ee876a7e944e247093536335c22c204a4ade4c178833d30eaeb5598052c8eaaed64c0cdab79b4544798597087ab788328e20d24a98e4f72262b03c17ec433199da158d5885dc3c254c0aac8760d77d42d1d880f85fa6fdf8ceb5abef99aef165c7a2120a3ed2050ab66591c14c0a067aa959c4718e7cab2214582edf8160645a09bb51119576fad9935ceb2f3cd5e8ed1e068d38f17177ffc72539226bd73ed6daeafe98c31275b7d78dfd2371dc1b1db65706cdbe11f3e834b4d2abe65a96ebfeb78c8331a382639a5e5d7e1a120103256e7dc99de10d94ca8fb32968d376c7bf48c1e7fc884caa82b963d7714fa8860cdf5c34d34384ae0bdd89ce21b3fe4afa5a6a861bcfb6071fe62f558a814576ee65b64acbfc9fcfe96de32c29e186dd73217d5f88424c880631fbfabd71e6a29f2ed40329677eeae2bbbe02e0a56a0df6d245d62168a1339e8ffffc",
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
            pool = 6,
            set = {
              [1] = "d.mailFriend",
              [2] = "d.secondary",
              [3] = "d.level",
              [4] = "p.enemyLand",
              [5] = "hunt",
              [6] = "p.bothWays",
            },
            swapped = {},
          },
        },
        pool = 6,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 6,
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
    hex = "3592c16e133d14851525ad42a34aa595862a6431442852891aa5a90814894ae3b649e1a7a5b52ad8e219df24561cdbd89e49cb8ea81bb61112fb8a27e823f004168b3ec72f9e01026701022f7d8fcf3df77e2e64eb36c647076ff1613db66a8d30faa2bdb79bec3d7b0a34ee509d81364c8a52afaeb2221e4ac2cd203656031917909292afe229c0d8048577da4c89524057dcf26ac7807d7d336dc53c853e10fd63da4a38108153613a3fa72d4aae22414fd9706467718ba6c0cd2ea252c04a9dd8eb7d1483b105e45566056bf0669b854a1b0d010268503e2f07eafe192757a0b777b6dbfe44edf6ce9d16d2929843507ebe5c9c19308bdca6daa85be90d075a4eaef7f198716e827964462032c2a188b8943640a05852edd6192deffc8f3964c09b489009fc8a744204b31062200a341a4a4e1bf190300103b4808d02614b9d9802b12353edaedb520f27243580a51d79f9273f92db9ca94cfdb7e85cedb9c76e33574daede64bce96af3be6693f02235e379deb7e7836ef925947aae761b51121e5d9289e2304f3831a6c738a093a87fa473f1856ce27c797f5a77a6527ca867e616c9f8df3b9c8c883681dbb8438c67bc888629a36ea3e32365f305ba6329a47e39cb6dde4b51ac8fc60fdca3ca4c13313ef52bc07d9d0a9b4bf31996d0a2b2e4b1103e516b078b582c091158129e6567f354516281463ecf8dafd99c14bdde7735b7e59eb8a61e90c47a34f8586a0ab74acbc15f568def956e67422ee93d578b4f986062e8f63e7fad745df4cdd5f48194e3fc6ac93d6cc61f53ff454c50def8d2d03415439062842db3dc330b7becd2a61ac2f38528d624815787abbfff",
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
        pool = 6,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            pool = 6,
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
