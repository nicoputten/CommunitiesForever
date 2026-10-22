-- Version: release versions of the addon and their order (CF-35). Pure Lua.
-- A release version is a tag: "v1.2.3", "v1.2.3-beta2", "v1.2.3-alpha1". Anything else (dev builds
-- "0.1.155" from build.ps1, "@project-version@", untagged packager builds "v1.2.3-beta1-6-gabc1234") is
-- not a release: it never triggers the notice and never gets it.
local _, ns = ...

local Version = {}

local STAGE = { alpha = 1, beta = 2 } -- a full release is 3

-- { major, minor, patch, stage, n } or nil.
function Version.parse(text)
  if type(text) ~= "string" then return nil end
  local major, minor, patch = text:match("^v(%d+)%.(%d+)%.(%d+)$")
  if major then
    return { major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch), stage = 3, n = 0 }
  end
  local stageName, n
  major, minor, patch, stageName, n = text:match("^v(%d+)%.(%d+)%.(%d+)%-(%a+)(%d+)$")
  if major and STAGE[stageName] then
    return { major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch), stage = STAGE[stageName],
             n = tonumber(n) }
  end
  return nil
end

-- -1, 0 or 1 for two parsed versions.
function Version.compare(a, b)
  for _, field in ipairs({ "major", "minor", "patch", "stage", "n" }) do
    if a[field] ~= b[field] then return a[field] < b[field] and -1 or 1 end
  end
  return 0
end

-- True when `other` is a newer release than `own` (both release versions). A version more than one major
-- ahead is ignored: nobody is that far ahead, so it is broken or made up.
function Version.isNewer(own, other)
  local a, b = Version.parse(own), Version.parse(other)
  if not a or not b then return false end
  if b.major > a.major + 1 then return false end
  return Version.compare(a, b) < 0
end

ns.Version = Version
return Version
