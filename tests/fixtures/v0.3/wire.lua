-- Golden fixture v0.3: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
return {
  [1] = {
    hex = "634c734ace482cdae4949fa4e05a91985b9093aa5450c6ec9456949f6b041454ca4c093234343230142a4972f40b0e770d4a4acc2b2e4f2d0aca492c492d02fc",
    message = {
      answer = "later",
      char = "Bob Example",
      from = "Bob",
      id = "11201",
      pv = 1,
      t = "ANSWER",
    },
    name = "bn-ANSWER",
    sender = "B",
  },
  [2] = {
    hex = "632c2b4a29cd4b4fcdcf7353ca4c514ac935ca4dac3075ca4bcc4dbd149291aae0929a98929b99975a6c042495950aca989dd28af2738d1c531281ea830c0d8d0c0c854a8c1c83bd95124b58dc9c9233128b36010325155c2b12730b72520103",
    message = {
      at = 1120,
      char = "Ada Example",
      dungeon = {
        id = "dm",
        max = 26,
        min = 17,
        name = "The Deadmines",
      },
      from = "Ada",
      id = "11201",
      pv = 1,
      t = "ASK",
    },
    name = "bn-ASK",
    sender = "A",
  },
  [3] = {
    hex = "630c332a4b2d9a62a79454d2e49892a86c68606018949d975f9ec7255412e4e1eae3e3af5450c60cf8",
    message = {
      bt = "Ada#1001",
      known = {},
      pv = 1,
      t = "HELLO",
      ver = 1001,
    },
    name = "bn-HELLO",
    sender = "A",
  },
  [4] = {
    hex = "630c534a2c6171532a2863764a2bcacfdde49892a8e05a91985b90935a54909892929997bea8020e844a9c023cfddc0103",
    message = {
      at = 1120,
      from = "Ada Example",
      padding = "xxxxxxxxxx",
      pv = 1,
      t = "PING",
    },
    name = "bn-PING",
    sender = "A",
  },
  [5] = {
    hex = "630c534a2c6171532a2863764a2bcacfdde4949fa4e05a91985b90932a54e214e0efe7ee549c59952a0af8",
    message = {
      at = 1120,
      from = "Bob Example",
      pv = 1,
      size = 10,
      t = "PONG",
    },
    name = "bn-PONG",
    sender = "B",
  },
  [6] = {
    hex = "1d8ecd4ac340144691222ac5e20fd66da8507051482256ba092469ab2e8a75dee02673db0e9d4ce29d49a84bc58ddb12702f3e411fc185eb3c8b4f60eab73c9c0fceceac93158d4e645e7d0e178e6d3b54206991aad27341f06f7b70150f6eae91472e3f31111b850f6cc8e205906e67c75309cf483da767d7f3ebf7cfa7046dfe317ff302210bd908e6b9e0d5de3acf3818e4be293d460832c98ec2dad622b60234604d8b69a020c14d9d628d56906412d7f1d6180b89c1c4bf1dd10c6253c7b1bb94386e324a67a8b7b5bafbd5ecbb09acf841d58a264209350f08d4f2a56cf6abb38faa45619a2e6b5a9def328905cacbe829476d747bfff4bd4b3c57734cd582196124fefad658ac4c4e683d6ea58820c6fbe1e1df",
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
    hex = "630c332a4b2d6ab1534a2a291048cc4cb14ab23031303435324a33373408cacecb2fcf13834818581a275b9a9ba6a62419a5b83809950479b8faf8f82b15943103fe",
    message = {
      bt = "aid:b8401522f710",
      known = {
        ["aid:093c975edb2d"] = 1060,
      },
      pv = 1,
      t = "HELLO",
      ver = 1000,
    },
    name = "whisper-HELLO",
    sender = "B",
  },
  [10] = {
    hex = "4d8e4d4ac3401886912222c55205751bba7017488256711170d2fab3908601030ff04de64b1d3ac90c33d35097424e5004f7e209bae801033c418ee4d495eff27d9ec5b3578e74d31b31a78720f82dbbb98ce2ab2429afe3c83468ac50759b261efdfc47278ed16936a3135abc82b167fa3897f086268cc3c88f4451bc254236b247e64bc1bb832f09d6fd39bc4dd74bcdc121bf736d4a0d82acf430f382154540d041903739a9a1c20d512c98aea0d212d7c5ceb81712299d3dbc4c4d0985f375f451198e1b6d548976976b2fbefbe3a482153fec06ec59d4a29e1303f5e2fda33fee4e3fbb81c9945af8b73bdfa7121b94213350e0d3e4e8f7",
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
      pv = 1,
      t = "RECORD",
      version = 1000,
    },
    name = "whisper-RECORD",
    sender = "B",
  },
  [11] = {
    hex = "1d8fc14af3401485f991d2fc16a12a0497a18b8294425ab1521742a669d545b11dc4fd2473d30e9d64e29d49a84bc18ddb22b8179fa00fe17a9ec52730ed599ef3c1fdeebfa41599bcc904bff68717f1f0ea1278d4e758026aa1b290b4f2f2e0c444743c7aa021490102b8ebcc1d373f9e49f602d8ed75fd2a81eff79e36124a901354e9798b9990908ca5b00d38f3c66b96e612700f3caace26964ceb899040a6c1ed98c64b86dab5b51f2264290fc8a210dcd628029369de1ced60117b040cf366e5ccd6adb32972ce0cf0a0baf355ed66afc3df6eeca16d60c26253d9d33b851cb639aa04f4ee1dddfe6e0cfa295bf3ffb61e4d4526b2054196ad5e3f1a03eb7eda3a8e945a55ad3dabd1bd6d277a2e401bed3aa7ef6de445b60102952da91146c26fe04dc4da1408de7c0745c862b80f8ffefe",
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
          quests = {
            [5001] = {
              dungeon = false,
              title = "A Fixture Quest",
            },
          },
          raceID = 6,
          realm = "Classic Beta PvP",
          updatedAt = 1060,
        },
      },
      feed = {
        [20744] = {
          ["Player-1-0000A001"] = {
            at = 1060,
            classFile = "MAGE",
            levelFrom = 20,
            levelTo = 21,
            name = "Ada Example",
          },
        },
      },
      pv = 1,
      t = "RECORD",
      version = 1060,
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
