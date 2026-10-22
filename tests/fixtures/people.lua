-- The invented players of the golden fixtures (capture.lua writes with them, Compat_spec reads with them).
-- Ada and Bob are Battle.net friends; Cy is only in the community. Never change these: the fixtures of
-- earlier versions were captured with exactly these names, GUIDs and BattleTags.
return {
  A = { key = "A", name = "Ada Example", guid = "Player-1-0000A001", battleTag = "Ada#1001",
        classFile = "MAGE", classID = 8, level = 20, gameAccountID = 101, friends = { "B" } },
  B = { key = "B", name = "Bob Example", guid = "Player-1-0000B001", battleTag = "Bob#2002",
        classFile = "ROGUE", classID = 4, level = 22, gameAccountID = 102, friends = { "A" } },
  C = { key = "C", name = "Cy Example", guid = "Player-1-0000C001", battleTag = "Cy#3003",
        classFile = "PRIEST", classID = 5, level = 18, gameAccountID = 103, friends = {} },
}
