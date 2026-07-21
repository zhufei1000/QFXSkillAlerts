local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CastSuccess = NS.Core.CastSuccess or {}

local CastSuccess = NS.Core.CastSuccess
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local MODE_SOUND = CONST.MODE_SOUND or "sound"

local castSuccessCfg = {}
local callbacks = {}

local function SafeCall(name, ...)
    local fn = callbacks[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetOrderedEntryIndices(map)
    local value = SafeCall("getOrderedEntryIndices", map)
    if type(value) == "table" then
        return value
    end

    local indices = {}
    if type(map) ~= "table" then
        return indices
    end
    for index, entry in pairs(map) do
        index = tonumber(index) or 0
        if index >= 1 and type(entry) == "table" and (tonumber(entry.spellId) or 0) > 0 then
            indices[#indices + 1] = index
        end
    end
    table.sort(indices)
    return indices
end

local function GetEntry(map, index)
    local entry = SafeCall("getEntry", map, index)
    if type(entry) == "table" then
        return entry
    end
    entry = map and map[index]
    if type(entry) ~= "table" then
        return nil
    end
    local spellId = tonumber(entry.spellId) or 0
    if spellId <= 0 then
        return nil
    end
    return entry
end

local function ResolveObjectType(objectID, objectType)
    local value = SafeCall("resolveObjectType", objectID, objectType)
    if type(value) == "string" and value ~= "" then
        return value
    end
    objectType = tostring(objectType or OBJECT_TYPE_SPELL):lower()
    if objectType ~= OBJECT_TYPE_ITEM then
        objectType = OBJECT_TYPE_SPELL
    end
    return objectType
end


local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function ScopeMapMatches(source, allID, fallbackID, currentID)
    local hasSelection = false
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                hasSelection = true
                if numberKey == allID or numberKey == currentID then
                    return true
                end
            end
        end
    end
    if not hasSelection then
        fallbackID = tonumber(fallbackID) or allID
        return fallbackID == allID or fallbackID == currentID
    end
    return false
end

local function GetCurrentRaceID()
    if type(UnitRace) ~= "function" then
        return 0
    end
    local _, _, raceID = UnitRace("player")
    return tonumber(raceID) or 0
end

local function IsScopeMatched(entry, scopeClassID, scopeSpecID, currentClassID, currentSpecID, currentRaceID)
    if type(entry) ~= "table" then
        return false
    end
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0
    currentRaceID = tonumber(currentRaceID) or 0
    if not ScopeMapMatches(entry.alertRaceIDs, ALL_RACES_ID, ALL_RACES_ID, currentRaceID) then
        return false
    end
    if not ScopeMapMatches(entry.alertClassIDs or entry.customClassIDs, ALL_CLASSES_ID, scopeClassID, currentClassID) then
        return false
    end
    if not ScopeMapMatches(entry.alertSpecIDs or entry.customSpecIDs, ALL_SPECS_ID, scopeSpecID, currentSpecID) then
        return false
    end
    return true
end

local function ResolveEntrySoundPath(entry)
    local value = SafeCall("resolveEntrySoundPath", entry)
    if type(value) == "string" then
        return value
    end
    return tostring(type(entry) == "table" and entry.soundPath or "")
end

local function ResolveImageTexture(entry)
    local value = SafeCall("resolveImageTexture", entry)
    return value ~= nil and value or false
end

local function GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    local value = SafeCall("getObjectTriggerSpellID", objectID, objectType, triggerSpellID)
    value = tonumber(value) or 0
    if value > 0 then
        return value
    end
    return tonumber(triggerSpellID) or tonumber(objectID) or 0
end

local function ResolveItemTriggerForEntry(entry, quiet)
    local value = SafeCall("resolveItemTriggerForEntry", entry, quiet)
    if value ~= nil then
        return value
    end
    return true
end

local function IsItemLoadRequirementMet(entry)
    local ok = SafeCall("isItemLoadRequirementMet", entry)
    if ok ~= nil then
        return ok ~= false
    end
    return true
end

local function GetCurrentClassSpec()
    local classID, specID = SafeCall("getCurrentClassSpec")
    return tonumber(classID) or 0, tonumber(specID) or 0
end

local function GetStoredEntryMap(classID, specID)
    local map = SafeCall("getStoredEntryMap", classID, specID)
    return type(map) == "table" and map or {}
end

local function GetCastSuccessMap(classID, specID)
    local map = SafeCall("getCastSuccessMap", classID, specID)
    return type(map) == "table" and map or {}
end

function CastSuccess:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.getCurrentClassSpec = opts.getCurrentClassSpec
    callbacks.getOrderedEntryIndices = opts.getOrderedEntryIndices
    callbacks.getEntry = opts.getEntry
    callbacks.getStoredEntryMap = opts.getStoredEntryMap
    callbacks.getCastSuccessMap = opts.getCastSuccessMap
    callbacks.resolveObjectType = opts.resolveObjectType
    callbacks.resolveItemTriggerForEntry = opts.resolveItemTriggerForEntry
    callbacks.isItemLoadRequirementMet = opts.isItemLoadRequirementMet
    callbacks.getObjectTriggerSpellID = opts.getObjectTriggerSpellID
    callbacks.resolveEntrySoundPath = opts.resolveEntrySoundPath
    callbacks.resolveImageTexture = opts.resolveImageTexture
    callbacks.queueNotification = opts.queueNotification
    return true
end

function CastSuccess:GetConfigTable()
    return castSuccessCfg
end

function CastSuccess:GetConfig(triggerSpellID)
    triggerSpellID = tonumber(triggerSpellID) or 0
    if triggerSpellID <= 0 then
        return nil
    end
    return castSuccessCfg[triggerSpellID]
end

function CastSuccess:Clear()
    wipe(castSuccessCfg)
    return true
end

function CastSuccess:Rebuild()
    wipe(castSuccessCfg)

    local classID, specID = GetCurrentClassSpec()
    local raceID = GetCurrentRaceID()

    local function addCastEntry(entry, index, scopeClassID, scopeSpecID)
        if type(entry) ~= "table" then
            return
        end
        if not IsScopeMatched(entry, scopeClassID, scopeSpecID, classID, specID, raceID) then
            return
        end
        local objectID = tonumber(entry.spellId) or 0
        local objectType = ResolveObjectType(objectID, entry.objectType)
        if objectType == OBJECT_TYPE_ITEM then
            if not IsItemLoadRequirementMet(entry) then
                return
            end
            ResolveItemTriggerForEntry(entry, true)
        end
        local triggerSpellID = GetObjectTriggerSpellID(objectID, objectType, entry.triggerSpellID or entry.triggerSpellId)
        if objectID > 0 and triggerSpellID > 0 then
            -- 当前专精配置会覆盖全职业/全专精配置。
            local builtCfg = {
                spellId = objectID,
                objectID = objectID,
                objectType = objectType,
                triggerSpellID = triggerSpellID,
                primaryKey = "cast:" .. tostring(scopeClassID or 0) .. ":" .. tostring(scopeSpecID or 0) .. ":" .. tostring(index or triggerSpellID),
                spellName = tostring(entry.spellName or ""),
                notifyMode = tostring(entry.notifyMode or MODE_SOUND),
                ttsText = tostring(entry.ttsText or ""),
                ttsRate = math.max(-10, math.min(10, tonumber(entry.ttsRate) or 0)),
                resolvedSoundPath = ResolveEntrySoundPath(entry),
                voiceEnabled = entry.voiceEnabled ~= false,
                voiceConditionOp = NormalizeConditionOp(entry.voiceConditionOp),
                voiceConditionTime = math.max(0, tonumber(entry.voiceConditionTime or entry.cooldownAlertTime or entry.alertLeadTime) or 0),
                imageEnabled = entry.imageEnabled == true,
                imageConditionOp = NormalizeConditionOp(entry.imageConditionOp),
                imageConditionTime = math.max(0, tonumber(entry.imageConditionTime or entry.cooldownAlertTime or entry.alertLeadTime) or 0),
                imageSource = tostring(entry.imageSource or "auto"),
                imageIconID = math.max(0, tonumber(entry.imageIconID) or 0),
                imagePath = tostring(entry.imagePath or ""),
                resolvedImageTexture = ResolveImageTexture(entry),
                imageSize = math.max(16, tonumber(entry.imageSize) or 96),
                imageDurationEnabled = entry.imageDurationEnabled == true,
                imageDuration = math.max(0.1, tonumber(entry.imageDuration) or 2),
                imageX = tonumber(entry.imageX) or 0,
                imageY = tonumber(entry.imageY) or 120,
                textEnabled = entry.textEnabled == true,
                textConditionOp = NormalizeConditionOp(entry.textConditionOp),
                textConditionTime = math.max(0, tonumber(entry.textConditionTime or entry.cooldownAlertTime or entry.alertLeadTime) or 0),
                textAlert = tostring(entry.textAlert or ""),
                textSize = math.max(8, tonumber(entry.textSize) or 24),
                textDurationEnabled = entry.textDurationEnabled == true,
                textDuration = math.max(0.1, tonumber(entry.textDuration) or 2),
                textX = tonumber(entry.textX) or 0,
                textY = tonumber(entry.textY) or 120,
                textAttachMode = tostring(entry.textAttachMode or "outside"),
                textVAlign = tostring(entry.textVAlign or "bottom"),
                textHAlign = tostring(entry.textHAlign or "center"),
                textOffsetX = tonumber(entry.textOffsetX) or 0,
                textOffsetY = tonumber(entry.textOffsetY) or 0,
                delayEnabled = entry.delayEnabled == true,
                delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0),
                index = index,
                scopeClassID = tonumber(scopeClassID) or 0,
                scopeSpecID = tonumber(scopeSpecID) or 0,
            }
            if Utils.SyncLinkedVisualDurations then
                Utils.SyncLinkedVisualDurations(builtCfg)
            end
            castSuccessCfg[triggerSpellID] = builtCfg
        end
    end

    local function addLegacyCastMap(castMap, scopeClassID, scopeSpecID)
        for _, index in ipairs(GetOrderedEntryIndices(castMap)) do
            addCastEntry(GetEntry(castMap, index), index, scopeClassID, scopeSpecID)
        end
    end

    local function addUnifiedCastMap(entryMap, scopeClassID, scopeSpecID)
        for _, index in ipairs(GetOrderedEntryIndices(entryMap)) do
            local entry = GetEntry(entryMap, index)
            if entry and tostring(entry.entryType or "cooldown") == "cast" then
                addCastEntry(entry, index, scopeClassID, scopeSpecID)
            end
        end
    end

    -- 优先级：全职业 < 当前职业全专精 < 当前职业当前专精。
    addLegacyCastMap(GetCastSuccessMap(ALL_CLASSES_ID, ALL_SPECS_ID), ALL_CLASSES_ID, ALL_SPECS_ID)
    addUnifiedCastMap(GetStoredEntryMap(ALL_CLASSES_ID, ALL_SPECS_ID), ALL_CLASSES_ID, ALL_SPECS_ID)

    addLegacyCastMap(GetCastSuccessMap(classID, ALL_SPECS_ID), classID, ALL_SPECS_ID)
    addUnifiedCastMap(GetStoredEntryMap(classID, ALL_SPECS_ID), classID, ALL_SPECS_ID)

    if specID ~= ALL_SPECS_ID then
        addLegacyCastMap(GetCastSuccessMap(classID, specID), classID, specID)
        addUnifiedCastMap(GetStoredEntryMap(classID, specID), classID, specID)
    end

    return true
end

function CastSuccess:Queue(triggerSpellID, cfg)
    cfg = cfg or self:GetConfig(triggerSpellID)
    if type(cfg) ~= "table" then
        return false
    end

    local result = SafeCall("queueNotification", triggerSpellID, cfg)
    return result == true
end

function CastSuccess:HandleSpellcastSucceeded(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return false
    end

    local cfg = self:GetConfig(spellId)
    if not cfg then
        return false
    end

    return self:Queue(spellId, cfg)
end
