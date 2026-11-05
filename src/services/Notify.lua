-- Notify: friends' characters levelling up (CF-16, from accepted records), as the announcement at the top of the
-- screen (CF-44, settings.levelUpToast). Only for people linked in the selected community, never for yourself.
-- CF-91: no chat lines any more (the "came online", "switched character" and level-up lines are gone: Battle.net's
-- own toast and the announcement show them already).
local _, ns = ...

local Notify = {}

local addonRef

local function linkedPerson(battleTag)
  for _, person in ipairs(ns.ViewModel.build(addonRef).people) do
    if person.battleTag == battleTag and not person.isSelf then return person end
  end
end

-- Level-ups older than this are not announced: relayed records (CF-20) can arrive hours later.
local LEVEL_UP_MAX_AGE = 15 * 60

local function announceLevelUp(battleTag, up)
  if addonRef.db.global.settings.levelUpToast == false then return end
  if not up.updatedAt or GetServerTime() - up.updatedAt > LEVEL_UP_MAX_AGE then return end
  local person = linkedPerson(battleTag)
  if not person then return end
  for _, row in ipairs(person.chars) do
    if row.guid == up.guid then
      local classFile = ns.Classes.info(row.classFile, row.classID)
      ns.LevelUpToast.announce({ displayName = person.displayName, name = row.name or up.name,
                                 classFile = classFile, level = up.level })
      return
    end
  end
end

function Notify.start(addon)
  addonRef = addon
  ns.LevelUpToast.reset()
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.Sync.LEVEL_UP, function(_, battleTag, up) announceLevelUp(battleTag, up) end)
end

ns.Notify = Notify
return Notify
