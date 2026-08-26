local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Scope = NS.Core.Scope or {}

local Scope = NS.Core.Scope
local CONST = NS.Constants or {}
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local GetNumClasses = rawget(_G, "GetNumClasses")
local GetClassInfo = rawget(_G, "GetClassInfo")
local GetNumSpecializationsForClassID = rawget(_G, "GetNumSpecializationsForClassID")
local GetSpecializationInfoForClassID = rawget(_G, "GetSpecializationInfoForClassID")

function Scope:GetCurrentClassSpec()
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return classID or 0, specID or 0
end

function Scope:IsActiveScopeLoaded(entryClassID, entrySpecID, currentClassID, currentSpecID)
    entryClassID = tonumber(entryClassID) or 0
    entrySpecID = tonumber(entrySpecID) or 0
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0

    if entryClassID == ALL_CLASSES_ID then
        return true
    end

    return entryClassID == currentClassID and (entrySpecID == currentSpecID or entrySpecID == ALL_SPECS_ID)
end

function Scope:ResolveClassName(classID)
    classID = tonumber(classID) or 0
    if classID == ALL_CLASSES_ID then
        return L("ALL_CLASSES")
    end
    if classID < 0 then
        return "-"
    end

    if type(GetNumClasses) == "function" and type(GetClassInfo) == "function" then
        local classCount = tonumber(GetNumClasses()) or 0
        for classIndex = 1, classCount do
            local ok, className, _, candidateClassID = pcall(GetClassInfo, classIndex)
            if ok and tonumber(candidateClassID) == classID and type(className) == "string" and className ~= "" then
                return className
            end
        end
    end

    return L("FALLBACK_CLASS", tostring(classID))
end

function Scope:ResolveSpecName(classID, specID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        return L("ALL_SPECS")
    end
    if classID < 0 or specID < 0 then
        return "-"
    end
    if specID == ALL_SPECS_ID then
        return L("ALL_SPECS")
    end

    if type(GetNumSpecializationsForClassID) == "function" and type(GetSpecializationInfoForClassID) == "function" then
        local specCount = tonumber(GetNumSpecializationsForClassID(classID)) or 0
        for specIndex = 1, specCount do
            local ok, candidateSpecID, specName = pcall(GetSpecializationInfoForClassID, classID, specIndex)
            if ok and tonumber(candidateSpecID) == specID and type(specName) == "string" and specName ~= "" then
                return specName
            end
        end
    end

    return L("FALLBACK_SPEC", tostring(specID))
end
