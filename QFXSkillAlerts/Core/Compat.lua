local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Compat = NS.Core.Compat or {}

local Compat = NS.Core.Compat

local cachedInterface

local function ReadInterface()
    if cachedInterface ~= nil then
        return cachedInterface
    end
    if type(GetBuildInfo) ~= "function" then
        cachedInterface = 0
        return cachedInterface
    end
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    cachedInterface = ok and tonumber(interface) or 0
    return cachedInterface
end

-- WoW Forever uses its own interface range even though it shares most of the
-- modern client API. The range check is the primary source because early
-- Forever builds could still report WOW_PROJECT_ID as Mainline.
function Compat:IsForever()
    local interface = ReadInterface()
    if interface >= 16000 and interface < 17000 then
        return true
    end
    local camelot = rawget(_G, "WOW_PROJECT_CAMELOT")
    return camelot ~= nil and rawget(_G, "WOW_PROJECT_ID") == camelot
end

function Compat:IsRetail()
    local interface = ReadInterface()
    return not self:IsForever() and interface >= 120000 and interface < 200000
end

function Compat:GetInterface()
    return ReadInterface()
end

-- Camelot has no Retail specialization picker or Mythic+ season, but its
-- class talent trees still use the shared Trait APIs.
function Compat:SupportsMythicPlus()
    return not self:IsForever()
end

function Compat:SupportsModernSpecialization()
    return not self:IsForever()
end

function Compat:SupportsTalentLoadConditions()
    return true
end

-- Retail uses positive specialization IDs; 0 is the addon-wide all-specs
-- sentinel. Forever also accepts legacy records saved under scope 0.
-- Keep the positive-only rule on Retail to avoid writing CDM
-- records into the wrong spec after a transient API failure.
function Compat:IsValidSpecScope(specID)
    specID = tonumber(specID)
    if not specID or specID ~= math.floor(specID) then
        return false
    end
    if specID > 0 then
        return true
    end
    return specID == 0 and self:IsForever()
end

local function SpecAPI(name, legacy)
    local api = rawget(_G, "C_SpecializationInfo")
    return type(api) == "table" and type(api[name]) == "function" and api[name] or rawget(_G, legacy)
end

function Compat:GetCurrentSpecInfo()
    local getIndex = SpecAPI("GetSpecialization", "GetSpecialization")
    local getInfo = SpecAPI("GetSpecializationInfo", "GetSpecializationInfo")
    if type(getIndex) ~= "function" or type(getInfo) ~= "function" then return 0 end
    local okIndex, index = pcall(getIndex)
    if not okIndex or not index or index <= 0 then return 0 end
    local ok, id, name = pcall(getInfo, index)
    if not ok then return 0 end
    return tonumber(id) or 0, name
end

function Compat:GetCurrentSpecID()
    local id = self:GetCurrentSpecInfo()
    return id
end

function Compat:GetActiveTalentConfigID()
    local api = rawget(_G, "C_ClassTalents")
    if type(api) == "table" and type(api.GetActiveConfigID) == "function" then
        local ok, id = pcall(api.GetActiveConfigID)
        if ok and tonumber(id) and id > 0 then return id end
    end
    if self:IsForever() then
        local spec = rawget(_G, "C_SpecializationInfo")
        if type(spec) == "table" and type(spec.GetActiveSpecGroup) == "function"
            and type(spec.GetCombatConfigIDForSpecGroup) == "function" then
            local okGroup, group = pcall(spec.GetActiveSpecGroup)
            if okGroup and group then
                local ok, id = pcall(spec.GetCombatConfigIDForSpecGroup, group)
                if ok and tonumber(id) and id > 0 then return id end
            end
        end
    end
end

function Compat:GetSpecOptions(classID)
    local count = SpecAPI("GetNumSpecializationsForClassID", "GetNumSpecializationsForClassID")
    local info = rawget(_G, "GetSpecializationInfoForClassID")
    local result = {}
    if type(count) ~= "function" or type(info) ~= "function" then return result end
    local ok, total = pcall(count, classID)
    if not ok then return result end
    for index = 1, tonumber(total) or 0 do
        local valid, id, name, _, icon = pcall(info, classID, index)
        if valid and tonumber(id) and id > 0 then
            result[#result + 1] = {specID = id, specName = name, specIcon = icon}
        end
    end
    return result
end
