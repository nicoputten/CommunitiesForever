-- CF-47: global.pending as the addon saves it (made-up people). The website's upload parser (web WEB-43)
-- reads this list from the saved file; keep this sample and its spec (tests/spec/Pending_spec.lua) in step
-- with core/Pending.lua and share it with the web repo when it changes. Times are UTC seconds.
return {
  { id = "k3f9c0a7e21b-1793120000-1", kind = "plan", at = 1793120000, dungeon = "smarm", startsAt = 1793190600,
    guid = "Player-1-0000AAAA", name = "Ada Lovewell", role = "tank", note = "Bring water" },
  { id = "k3f9c0a7e21b-1793120060-2", kind = "answer", at = 1793120060, run = "r-102", answer = "in",
    guid = "Player-1-0000AAAB", name = "Ada Stormbrew", role = "heal" },
  { id = "k3f9c0a7e21b-1793120120-3", kind = "answer", at = 1793120120, run = "r-103", answer = "cant" },
  { id = "k3f9c0a7e21b-1793120180-4", kind = "ask", at = 1793120180, dungeon = "dm",
    guid = "Player-1-0000AAAA", name = "Ada Lovewell", role = "tank", note = "Quick run for the Defias quests" },
  { id = "k3f9c0a7e21b-1793120190-5", kind = "ping", at = 1793120190, run = "r-102", battleTag = "Bo#2002",
    guid = "Player-1-0000BBBB", name = "Bo Example" }, -- CF-48
}
