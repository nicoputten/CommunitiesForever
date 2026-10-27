-- Classes: a character's class file and name from its class ID. C_CreatureInfo.GetClassInfo is verified (V21).
local _, ns = ...

local Classes = {}

-- classFile (kept when known, else from the ID) and the localized class name, or classFile, nil.
function Classes.info(classFile, classID)
  if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    local info = C_CreatureInfo.GetClassInfo(classID)
    if info then return classFile or info.classFile, info.className end
  end
  return classFile, nil
end

ns.Classes = Classes
return Classes
