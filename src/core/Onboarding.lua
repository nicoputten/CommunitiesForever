-- Onboarding: which setup steps to show (CF-26). Pure Lua, no WoW globals.
-- The wizard runs once per account; steps added in a later version are shown once to existing users.
-- Chat windows are saved per character, so other characters get only the Community tab prompt.
local _, ns = ...

local Onboarding = {}

-- Bump when steps are added; give new steps `since = <new version>`.
Onboarding.VERSION = 1

Onboarding.STEPS = {
  { id = "welcome", title = "Welcome", since = 1 },
  { id = "community", title = "Community", since = 1 },
  { id = "name", title = "Your name", since = 1 },
  { id = "chat", title = "Community chat", since = 1 },
  { id = "notifications", title = "Notifications", since = 1 },
  { id = "done", title = "Done", since = 1 },
}

-- What the wizard switches start at (the same as Store.defaults: the wizard only presents settings).
Onboarding.DEFAULTS = {
  chatKeepGeneral = true, chatAlert = true, chatSound = false,
  notifications = true, levelUps = true, levelUpToast = true, minimap = true,
}

local function copy(step)
  return { id = step.id, title = step.title, since = step.since }
end

-- Steps of the full wizard (/cf setup), or only those newer than `afterVersion`. The welcome and
-- done steps frame a list of new steps.
function Onboarding.steps(afterVersion)
  local steps = {}
  for _, step in ipairs(Onboarding.STEPS) do
    if not afterVersion or step.since > afterVersion then steps[#steps + 1] = copy(step) end
  end
  if afterVersion and #steps > 0 then
    if steps[1].id ~= "welcome" then table.insert(steps, 1, copy(Onboarding.STEPS[1])) end
    if steps[#steps].id ~= "done" then steps[#steps + 1] = copy(Onboarding.STEPS[#Onboarding.STEPS]) end
  end
  return steps
end

--[[ What to show at login:
  settings: db.global.settings (onboarded, onboardedVersion, chatTabPrompt = { [guid] = true },
    joinPrompt = { [guid] = true } (CF-61))
  char = { guid, hasTab, inCommunity, joinable }: the current character; hasTab: it has a Community chat tab;
    joinable: not in the selected community, and a friend shared an invite link for it.
Returns { kind = "wizard", steps } for the first run or new steps, { kind = "join" } once for a joinable
character (CF-61: the window opens on how to join), { kind = "chatPrompt" } for a character in the community
without a Community tab that was not asked before, or nil.
]]
function Onboarding.plan(settings, char)
  settings = settings or {}
  if not settings.onboarded then
    return { kind = "wizard", steps = Onboarding.steps() }
  end
  local seen = settings.onboardedVersion or 1
  if seen < Onboarding.VERSION then
    local steps = Onboarding.steps(seen)
    if #steps > 0 then return { kind = "wizard", steps = steps } end
  end
  if char and char.guid and char.joinable and not char.inCommunity
     and not (settings.joinPrompt and settings.joinPrompt[char.guid]) then
    return { kind = "join" }
  end
  if char and char.guid and char.inCommunity and not char.hasTab
     and not (settings.chatTabPrompt and settings.chatTabPrompt[char.guid]) then
    return { kind = "chatPrompt" }
  end
  return nil
end

-- The wizard was finished, skipped or closed (in place). The character it ran on saw the chat step,
-- so it gets no extra prompt.
function Onboarding.finish(settings, guid)
  settings.onboarded = true
  settings.onboardedVersion = Onboarding.VERSION
  if guid then Onboarding.dontAsk(settings, guid) end
end

-- The chat prompt was answered on this character (Create, or closed): not asked again (in place).
function Onboarding.dontAsk(settings, guid)
  settings.chatTabPrompt = settings.chatTabPrompt or {}
  settings.chatTabPrompt[guid] = true
end

-- CF-61: the window opened on how to join for this character: not again by itself (in place).
function Onboarding.joinShown(settings, guid)
  settings.joinPrompt = settings.joinPrompt or {}
  settings.joinPrompt[guid] = true
end

-- "Step 4 of 6".
function Onboarding.progress(index, total)
  return string.format("Step %d of %d", index, total)
end

-- CF-61: the wizard's step line: "Step 2 of 6 · Community → Sharing", the current step and the next one only (all
-- titles ran past the window's edge). The last step: "Step 6 of 6 · Done". titles: the step titles in order.
function Onboarding.progressLine(index, titles, arrow)
  local line = Onboarding.progress(index, #titles) .. " 9483 " .. tostring(titles[index] or "")
  if titles[index + 1] then line = line .. (arrow or " 9483 ") .. titles[index + 1] end
  return line
end

ns.Onboarding = Onboarding
return Onboarding
