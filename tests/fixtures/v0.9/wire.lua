-- Golden fixture v0.9: messages as pv 1 writes them (tests/fixtures/capture.lua). Do not edit.
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
    hex = "632c532a2a65544a2a69724c495436343030544a2c0b32d033d43308cacecb2fcfe3122a09f270f5f1f1572a2863362a4b2d9a6207f8",
    message = {
      av = "0.1.0",
      bt = "Ada#1001",
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
    hex = "2d91d16a134114860d4148130463619156748d1010ecb24968a537814c9a558bc574dfe0ccce493264b233cecc26a9778620785b02de973e411fc10baf071fc5277092766ee6f031f3ff3fff29fd7866693ae87f49cf1ad4ae7a0cdeb4e2b8a5e7a80d97f9a6db50f3723a9620cc881aab11a625a2a414e5748138354129d16601034a21ab122673ac36c0aebb6d83f67cb588be79628e557d11b1221fa3cc13cd3167a69d2ea20cd48a7a8ec2740845634b84c195095e3c4a5ca579c3a2af8587a615fb1184fd8c73149a45627b5fb3c84c4023ebb8bd7b47573df7904a63d0745cddedff5551915b596413a002538d3ed2f3522d6e0367bfe3d34e76fafe18196d3332426441e5b212a8fa50c015eaa3d651ec4fcf1791ecc4575e745b87396836ac5c77c948cbd9ba7b9d093026e102c945efc380e430c33b5f613858c24c7953efad4de00eff102ee6a24cc60567eef0c6ffb23b27e6350ac5c022ebd94dd7870431534ffb5b599e85042d84c3f9d085eeb57be95ee91164d6c7483f4acdf04e69397ac8d5bcad9db467b0647b2ea4173ce7f99868c8a7df37b513f7ee970b755fcaa9a72e7a9cee1a7c4befeb0d2afb3f9bfa613b93d4722bf05f2f4cf8d2161ac3cbed23aa21c34f674ffeff",
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
            set = {
              [1] = "d.bosses3",
              [2] = "d.quests10",
              [3] = "d.level",
              [4] = "p.untouchable",
            },
            swapped = {
              ["d.level"] = "d.shared3",
              ["d.quests10"] = "d.altLevel",
            },
          },
        },
        pool = 1,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            set = {
              [1] = "w.zones5",
              [2] = "w.dungeonFriends2",
              [3] = "w.cap",
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
    hex = "632c532a2a65544a2a291048cc4cb14ab23031303435324a333734504a2c0b32d033d43308cacecb2fcf1383a830b0344eb634374d4d49324a1171132a09f270f5f1f1572a2863362a4b2d6ab103fc",
    message = {
      av = "0.1.0",
      bt = "aid:b8401522f710",
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
    hex = "4d90d16a134114860d41481384462188155d73912bb36c36b68a170103274dd4a2342ef801026776cea64b6677c639b39bd63b4bf001038ae07df1097ae103f804834fe4247ae1dcccf0c17cff7f4ee3eb5dcb93d9f43439ee73abf721172ff98b67d1e8308eb3e7a3c8d4682857e566d2d77533592a909471b20661d5605a29d94cd6882bea35e686d6a0358a3613aac4761fec661213da93cb75f8d9133ad4dd7528aa7289aa9c9b1c4b4171b20e53d097dc739434661cc93698800bea3dbc3577adc1b5083f551ed228f24f90f61dd6288d08e5f6be12219d814131767b7f135dfbc443ae8890c6aeebeefdd661555a55a567c02526067da5fb8d4e14fb597ffd3f2bcb1045aff5a1d5d3dd85840b34c3d130f28745d168be935f7ae9761df460d0b76a33619951c56672954a209ae75e9f9cbefe3863251478c3140f66e750688f7db8a19e3bf8c97259cb265b56b97007d7fe9bdd45092fa9b401028be295cff12d41167a7fbaf5e669c0d042b0a8172e704fdc23f7d864905adf2379a38cc01b6d54f6afd8e047e7282ee05cecb980bfcfcbbc5c3203e5eacbb7ce917bfadd0566aad4ca5317de4e762b1c720329be3dbef3e7",
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
            set = {
              [1] = "d.bosses3",
              [2] = "d.quests10",
              [3] = "d.level",
              [4] = "p.untouchable",
            },
            swapped = {
              ["d.level"] = "d.shared3",
              ["d.quests10"] = "d.altLevel",
            },
          },
        },
        pool = 1,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            set = {
              [1] = "w.zones5",
              [2] = "w.dungeonFriends2",
              [3] = "w.cap",
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
    hex = "3592cd6e133110c715a545a111523fd052851c42842295a8559aaa812211296ebb2d1f85d6aac415ef7a9258f1dac6f66e5a6e44b9708d90b8239ea04fe2539f03f1047897e2e3cc7f3cff99df94b2751be1e3c30ff8a81959b54a187dd939d88b0f9eef038dba5467a00d93e261d85459198f24e1661819ab814c4a4849c9cb780a30314129d4664a9402ba82a814b0d22476deef1ab06f66d39d2f3e62f6d5da7487a6620452849a81a0a68ba73b3151b3c8c7819b3d1481b12544c9b559c11a7cf566a9da414301021a542e2a815a3be7e41af4f6ee76c7bf41a7b37bab85b424e210545edc2bcf0c98dcb0a9b59a56cefb68a86532efe309e3dc048b811983c8088732e252da0102816271add764b4b2fb1b73c880b7912009fc19e8980866a1818128d06824396d4523c204d012360a845dea4614881d9b5a6fdd2e853826a901032cedd8cbf381dde64c65ea6ddeb916baa76eb35025d7ef32de76f5c5896649e332359345d137f446b7fcd2964257bf1950d238be2289e2b088393126641cd0d9e0e45817e24bd9c6c5c6feb5ee4ea5f8d4cccc0d92d1ff3a1c8f893681dbb8458c67bc8c4629a36ea3eb2d658b9cd9a91452bf9a15df7c94a2dc1c4f1eb927d5992662f2deaf01029fe854d8425accb08cf2ccb2c74278a2560f735b2c6e20b0a4719e9d2f524589053af07e7efa9c2d48d179dfd5dd967be6da7a4862ebd1e053a929dc282d8777ac5abfaabd6e42aee87d578fce986062e40ebe7eaff6dce087abeb4329274568d93d6e479f537f2226a86c7c6be9bb631a63cb2cf7cc1a21bbb2a986c6452e8a3489e1f5d183bf",
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
        pool = 1,
        reset = 68400,
        streak = 0,
        weeks = {
          [0] = {
            at = 1000,
            done = {},
            set = {
              [1] = "w.zones5",
              [2] = "w.dungeonFriends2",
              [3] = "w.cap",
              [4] = "b.duels3",
            },
            swapped = {},
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
