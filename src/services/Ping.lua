-- Ping: /cf ping test messages. PING is answered with PONG automatically, so the transport
-- (chunking, throttle, combat queue, sender lookup) can be tested in game before sync exists.
local _, ns = ...

local Ping = {}

local addonRef

-- Sends PING to every friend online in Forever. size pads the message (bytes) to force chunking.
function Ping.send(size)
  local message = { t = "PING", from = ns.SelfInfo.read().name, at = GetServerTime() }
  if size and size > 0 then
    message.padding = string.rep("x", size)
  end
  local targets = ns.Messenger.broadcast(message)
  if targets == 0 then
    addonRef:Print("Ping: no friends online in Forever.")
  else
    addonRef:Print(string.format("Ping sent to %d game account(s)%s.", targets,
      size and size > 0 and string.format(", %d bytes padding", size) or ""))
  end
end

function Ping.start(addon)
  addonRef = addon
  -- Own AceEvent object: Sync (CF-11) will also listen to Messenger.RECEIVED on the addon.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.Messenger.RECEIVED, function(_, message, battleTag, senderID)
    if message.t == "PING" then
      addonRef:Print(string.format("Ping from %s (%s), %d bytes padding.", tostring(message.from), battleTag,
        message.padding and #message.padding or 0))
      ns.Messenger.send(senderID, { t = "PONG", from = ns.SelfInfo.read().name, at = message.at,
                                    size = message.padding and #message.padding or 0 })
    elseif message.t == "PONG" then
      addonRef:Print(string.format("Pong from %s (%s) for %d bytes.", tostring(message.from), battleTag,
        message.size or 0))
    end
  end)
end

ns.Ping = Ping
return Ping
