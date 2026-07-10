local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.RuntimeConfigBuilder = NS.Core.RuntimeConfigBuilder or {}

local Builder = NS.Core.RuntimeConfigBuilder
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local MODE_SOUND = CONST.MODE_SOUND or "sound"

local callbacks = {}

local function SafeCall(name, ...)
    local fn = callbacks[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function ClearTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    if type(wipe) == "function" then
        wipe(tbl)
    else
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local function GetCurrentClassSpec()
    local classID, specID = SafeCall("getCurrentClassSpec")
    return tonumber(classID) or 0, tonumber(specID) or 0
end

local function GetStoredEntryMap(classID, specID)
    local map = SafeCall("getStoredEntryMap", classID, specID)
    return type(map) == "table" and map or {}
end

local function GetOrderedEntryIndices(map)
    local indices = SafeCall("getOrderedEntryIndices", map)
    return type(indices) == "table" and indices or {}
end

local function GetEntry(map, index)
    local entry = SafeCall("getEntry", map, index)
    return type(entry) == "table" and entry or nil
end

local function ResolveObjectType(objectID, objectType)
    local resolved = SafeCall("resolveObjectType", objectID, objectType)
    if type(resolved) == "string" and resolved ~= "" then
        return resolved
    end
    objectType = tostring(objectType or OBJECT_TYPE_SPELL):lower()
    if objectType ~= OBJECT_TYPE_ITEM then
        objectType = OBJECT_TYPE_SPELL
    end
    return objectType
end

local function ResolveItemTriggerForEntry(entry, quiet)
    local ok = SafeCall("resolveItemTriggerForEntry", entry, quiet)
    if ok ~= nil then
        return ok
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

local function GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    local resolved = SafeCall("getObjectTriggerSpellID", objectID, objectType, triggerSpellID)
    resolved = tonumber(resolved) or 0
    if resolved > 0 then
        return resolved
    end
    return tonumber(triggerSpellID) or tonumber(objectID) or 0
end

local function MakeObjectKey(objectType, objectID)
    local key = SafeCall("makeObjectKey", objectType, objectID)
    if type(key) == "string" and key ~= "" then
        return key
    end
    return tostring(objectType or OBJECT_TYPE_SPELL) .. ":" .. tostring(math.floor(tonumber(objectID) or 0))
end

local function IsTalentSelected(talentId)
    local selected = SafeCall("isTalentSelected", talentId)
    return selected ~= false
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

local function NormalizeConditionTime(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = tonumber(fallback) or 0
    end
    return math.max(0, numeric or 0)
end


local function CopyNumberBoolMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                copy[numberKey] = true
            end
        end
    end
    return copy
end

local function NormalizeScopeClassMap(source, fallbackClassID)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        local classID = tonumber(fallbackClassID) or 0
        copy[classID > 0 and classID or ALL_CLASSES_ID] = true
    end
    if copy[ALL_CLASSES_ID] == true then
        return { [ALL_CLASSES_ID] = true }
    end
    return copy
end

local function NormalizeScopeSpecMap(source, fallbackSpecID)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        local specID = tonumber(fallbackSpecID) or 0
        copy[specID > 0 and specID or ALL_SPECS_ID] = true
    end
    if copy[ALL_SPECS_ID] == true then
        return { [ALL_SPECS_ID] = true }
    end
    return copy
end

local function NormalizeScopeRaceMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil or copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
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
    local raceIDs = NormalizeScopeRaceMap(entry.alertRaceIDs)
    if raceIDs[ALL_RACES_ID] ~= true and raceIDs[currentRaceID] ~= true then
        return false
    end
    local classIDs = NormalizeScopeClassMap(entry.alertClassIDs or entry.customClassIDs, scopeClassID)
    if classIDs[ALL_CLASSES_ID] ~= true and classIDs[currentClassID] ~= true then
        return false
    end
    local specIDs = NormalizeScopeSpecMap(entry.alertSpecIDs or entry.customSpecIDs, scopeSpecID)
    if specIDs[ALL_SPECS_ID] ~= true and specIDs[currentSpecID] ~= true then
        return false
    end
    return true
end

local function ResolveEntrySoundPath(entry)
    local path = SafeCall("resolveEntrySoundPath", entry)
    return type(path) == "string" and path or ""
end

function Builder:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.getCurrentClassSpec = opts.getCurrentClassSpec
    callbacks.getStoredEntryMap = opts.getStoredEntryMap
    callbacks.getOrderedEntryIndices = opts.getOrderedEntryIndices
    callbacks.getEntry = opts.getEntry
    callbacks.resolveObjectType = opts.resolveObjectType
    callbacks.resolveItemTriggerForEntry = opts.resolveItemTriggerForEntry
    callbacks.isItemLoadRequirementMet = opts.isItemLoadRequirementMet
    callbacks.getObjectTriggerSpellID = opts.getObjectTriggerSpellID
    callbacks.makeObjectKey = opts.makeObjectKey
    callbacks.isTalentSelected = opts.isTalentSelected
    callbacks.resolveEntrySoundPath = opts.resolveEntrySoundPath
    return true
end

function Builder:Rebuild(spellToPrimary, runtimeCfg)
    if type(spellToPrimary) ~= "table" or type(runtimeCfg) ~= "table" then
        return false
    end

    ClearTable(spellToPrimary)
    ClearTable(runtimeCfg)

    local classID, specID = GetCurrentClassSpec()
    local raceID = GetCurrentRaceID()

    local function addEntriesFromMap(entryMap, scopeClassID, scopeSpecID)
        for _, index in ipairs(GetOrderedEntryIndices(entryMap)) do
            local entry = GetEntry(entryMap, index)
            if entry and tostring(entry.entryType or "cooldown") == "cooldown" and IsScopeMatched(entry, scopeClassID, scopeSpecID, classID, specID, raceID) then
                local objectID = tonumber(entry.spellId) or 0
                local objectType = ResolveObjectType(objectID, entry.objectType)
                if objectType == OBJECT_TYPE_ITEM then
                    if not IsItemLoadRequirementMet(entry) then
                        objectID = 0
                    else
                        ResolveItemTriggerForEntry(entry, true)
                    end
                end
                local triggerSpellID = GetObjectTriggerSpellID(objectID, objectType, entry.triggerSpellID or entry.triggerSpellId)
                local talentId = tonumber(entry.talentId) or 0
                local checkTalent = entry.checkTalent == true and talentId > 0
                local talentOK = checkTalent and IsTalentSelected(talentId)
                local fixedCD = tonumber(entry.baseCD) or 0
                local talentCD = tonumber(entry.talentCD) or 0
                local effectiveCD = (talentOK and talentCD > 0) and talentCD or fixedCD
                if objectID > 0 and triggerSpellID > 0 and effectiveCD > 0 then
                    local objectKey = MakeObjectKey(objectType, objectID)
                    -- 触发事件里拿到的是技能ID；物品会映射到该物品“使用时触发的技能ID”。
                    spellToPrimary[triggerSpellID] = objectKey
                    local builtCfg = {
                        spellId = objectID,
                        objectID = objectID,
                        objectType = objectType,
                        itemLoadMode = tostring(entry.itemLoadMode or ""),
                        triggerSpellID = triggerSpellID,
                        spellName = tostring(entry.spellName or ""),
                        baseCD = effectiveCD,
                        fixedCD = true,
                        chargeInput = math.max(1, math.floor(tonumber(entry.chargeInput or entry.charge) or 1)),
                        cooldownAlertTime = math.max(0, tonumber(entry.cooldownAlertTime or entry.alertLeadTime) or 0),
                        voiceConditionOp = NormalizeConditionOp(entry.voiceConditionOp),
                        voiceConditionTime = NormalizeConditionTime(entry.voiceConditionTime, entry.cooldownAlertTime or entry.alertLeadTime),
                        imageConditionOp = NormalizeConditionOp(entry.imageConditionOp),
                        imageConditionTime = NormalizeConditionTime(entry.imageConditionTime, entry.cooldownAlertTime or entry.alertLeadTime),
                        textConditionOp = NormalizeConditionOp(entry.textConditionOp),
                        textConditionTime = NormalizeConditionTime(entry.textConditionTime, entry.cooldownAlertTime or entry.alertLeadTime),
                        notifyMode = tostring(entry.notifyMode or MODE_SOUND),
                        ttsText = tostring(entry.ttsText or ""),
                        ttsRate = math.max(-10, math.min(10, tonumber(entry.ttsRate) or 0)),
                        soundPath = ResolveEntrySoundPath(entry),
                        soundSource = tostring(entry.soundSource or ""),
                        builtinSoundPath = tostring(entry.builtinSoundPath or ""),
                        customSoundPath = tostring(entry.customSoundPath or ""),
                        customSoundPaths = type(entry.customSoundPaths) == "table" and entry.customSoundPaths or nil,
                        sharedMediaSound = tostring(entry.sharedMediaSound or entry.sharedMediaName or ""),
                        voiceEnabled = entry.voiceEnabled ~= false,
                        imageEnabled = entry.imageEnabled == true,
                        imageSource = tostring(entry.imageSource or "auto"),
                        imageIconID = math.max(0, tonumber(entry.imageIconID) or 0),
                        imagePath = tostring(entry.imagePath or ""),
                        imageSize = math.max(16, tonumber(entry.imageSize) or 96),
                        imageDurationEnabled = entry.imageDurationEnabled == true,
                        imageDuration = math.max(0.1, tonumber(entry.imageDuration) or 2),
                        imageX = tonumber(entry.imageX) or 0,
                        imageY = tonumber(entry.imageY) or 120,
                        textEnabled = entry.textEnabled == true,
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
                        checkTalent = checkTalent,
                        talentMatched = talentOK == true,
                        talentId = talentId,
                        talentName = tostring(entry.talentName or ""),
                        talentCD = talentCD,
                        fixedBaseCD = fixedCD,
                        index = index,
                        scopeClassID = tonumber(scopeClassID) or 0,
                        scopeSpecID = tonumber(scopeSpecID) or 0,
                        alertRaceIDs = NormalizeScopeRaceMap(entry.alertRaceIDs),
                        alertClassIDs = NormalizeScopeClassMap(entry.alertClassIDs or entry.customClassIDs, scopeClassID),
                        alertSpecIDs = NormalizeScopeSpecMap(entry.alertSpecIDs or entry.customSpecIDs, scopeSpecID),
                    }
                    if Utils.SyncLinkedVisualDurations then
                        Utils.SyncLinkedVisualDurations(builtCfg)
                    end
                    runtimeCfg[objectKey] = builtCfg
                end
            end
        end
    end

    -- 优先级：全职业 < 当前职业全专精 < 当前职业当前专精；后加入的覆盖前面的通用配置。
    addEntriesFromMap(GetStoredEntryMap(ALL_CLASSES_ID, ALL_SPECS_ID), ALL_CLASSES_ID, ALL_SPECS_ID)
    addEntriesFromMap(GetStoredEntryMap(classID, ALL_SPECS_ID), classID, ALL_SPECS_ID)
    if specID ~= ALL_SPECS_ID then
        addEntriesFromMap(GetStoredEntryMap(classID, specID), classID, specID)
    end

    return true
end
