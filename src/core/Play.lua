-- Play: play sessions per character in the feed (CF-53). Pure Lua, no WoW globals.
-- feed[day][guid].sessions = { { from, to } } in server time, under the feed day the session started.
-- `to` moves on with a heartbeat while playing and at logout; a login within CONTINUE seconds of the
-- last `to` continues that session, so a /reload or a short disconnect does not split it.
local _, ns = ...

local Play = {}

Play.CONTINUE = 300   -- seconds: a login this soon after the last `to` continues the session
Play.HEARTBEAT = 300  -- seconds between `to` updates while playing
Play.MAX_SESSIONS = 20 -- per character and day

-- The character's latest session in the feed: session, entry (its feed entry), or nil.
function Play.last(feed, guid)
  local best, bestEntry
  for _, chars in pairs(feed or {}) do
    local entry = type(chars) == "table" and chars[guid]
    for _, s in ipairs(entry and entry.sessions or {}) do
      if type(s.to) == "number" and (not best or s.to > best.to) then best, bestEntry = s, entry end
    end
  end
  return best, bestEntry
end

-- At login: continues the last session when it ended at most CONTINUE seconds ago (in place, returns it
-- and its entry), else nil: the caller starts a new one with Feed.add { kind = "session", from = now }.
function Play.resume(feed, guid, now)
  local session, entry = Play.last(feed, guid)
  if session and now - session.to <= Play.CONTINUE and now >= session.from then
    session.to = now
    entry.at = math.max(entry.at or 0, now)
    return session, entry
  end
  return nil
end

-- Moves a session's end to now (heartbeat, logout). Not a change worth a sync of its own: the next
-- version bump carries it.
function Play.touch(session, entry, now)
  if type(session) ~= "table" or now < (session.to or 0) then return end
  session.to = now
  if entry then entry.at = math.max(entry.at or 0, now) end
end

ns.Play = Play
return Play
