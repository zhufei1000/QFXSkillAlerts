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
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"
local MODE_SOUND = CONST.MODE_SOUND or "sound"

local callbacks = {}
local itemLoadEventNeeds = { equipped = false, bags = false }

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
    local path = SafeCall("resolveEntrySoundPath", entry)
    return type(path) == "string" and path or ""
end

local function ResolveImageTexture(entry)
    local texture = SafeCall("resolveImageTexture", entry)
    return texture ~= nil and texture or false
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
    callbacks.resolveImageTexture = opts.resolveImageTexture
    return true
end

function Builder:GetItemLoadEventNeeds()
    return itemLoadEventNeeds.equipped == true, itemLoadEventNeeds.bags == true
end

function Builder:Rebuild(spellToPrimary, runtimeCfg)
    if type(spellToPrimary) ~= "table" or type(runtimeCfg) ~= "table" then
        return false
    end

    ClearTable(spellToPrimary)
    ClearTable(runtimeCfg)
    itemLoadEventNeeds.equipped = false
    itemLoadEventNeeds.bags = false

    local classID, specID = GetCurrentClassSpec()
    local raceID = GetCurrentRaceID()

    local function addEntriesFromMap(entryMap, scopeClassID, scopeSpecID)
        for _, index in ipairs(GetOrderedEntryIndices(entryMap)) do
            local entry = GetEntry(entryMap, index)
            if entry and tostring(entry.entryType or "cooldown") == "cooldown" and IsScopeMatched(entry, scopeClassID, scopeSpecID, classID, specID, raceID) then
                local objectID = tonumber(entry.spellId) or 0
                local objectType = ResolveObjectType(objectID, entry.objectType)
                if objectType == OBJECT_TYPE_ITEM then
                    local loadMode = tostring(entry.itemLoadMode or ""):lower()
                    if loadMode == ITEM_LOAD_EQUIPPED then
                        itemLoadEventNeeds.equipped = true
                    elseif loadMode == ITEM_LOAD_BAGS then
                        itemLoadEventNeeds.bags = true
                    end
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
                local hasIndependentLoadTalent = entry.loadTalentEnabled ~= nil
                    or entry.loadTalentId ~= nil or entry.loadTalentName ~= nil
                local loadTalentId = tonumber(entry.loadTalentId) or 0
                local loadTalentEnabled = entry.loadTalentEnabled == true and loadTalentId > 0
                if not hasIndependentLoadTalent and entry.talentLoadFilter == true then
                    loadTalentId = talentId
                    loadTalentEnabled = checkTalent
                end
                if loadTalentEnabled and not IsTalentSelected(loadTalentId) then
                    effectiveCD = 0
                end
                if objectID > 0 and triggerSpellID > 0 and effectiveCD > 0 then
                    local objectKey = MakeObjectKey(objectType, objectID)
                    -- 触发事件里拿到的是技能ID；物品会映射到该物品“使用时触发的技能ID”。
                    spellToPrimary[triggerSpellID] = objectKey
                    local builtCfg = {
                        spellId = objectID,
                        objectID = objectID,
                        objectType = objectType,
                        triggerSpellID = triggerSpellID,
                        spellName = tostring(entry.spellName or ""),
                        baseCD = effectiveCD,
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
                        resolvedSoundPath = ResolveEntrySoundPath(entry),
                        voiceEnabled = entry.voiceEnabled ~= false,
                        imageEnabled = entry.imageEnabled == true,
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
                        textCooldownCountdown = entry.textCooldownCountdown == true,
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
                        index = index,
                        scopeClassID = tonumber(scopeClassID) or 0,
                        scopeSpecID = tonumber(scopeSpecID) or 0,
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
