local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Database = NS.Core.Database or {}

local Database = NS.Core.Database
local LibStubGlobal = rawget(_G, "LibStub")

local defaults = {
    profile = {
        specConfigs = {},
        castSuccessConfigs = {},
        bloodlustConfig = {
            customSoundPaths = { "", "", "", "", "" },
            voiceEnabled = true,
            voiceConditionOp = "<=",
            voiceConditionTime = 0,
            soundSource = "custom",
            imageEnabled = false,
            imageConditionOp = "<=",
            imageConditionTime = 0,
            imageSource = "auto",
            imageIconID = 0,
            imageSize = 96,
            imageDurationEnabled = false,
            imageDuration = 2,
            imageX = 0,
            imageY = 120,
            textEnabled = false,
            textConditionOp = "<=",
            textConditionTime = 0,
            textSize = 24,
            textDurationEnabled = false,
            textDuration = 2,
            textX = 0,
            textY = 120,
            textAttachMode = "outside",
            textVAlign = "bottom",
            textHAlign = "center",
            textOffsetX = 0,
            textOffsetY = 0,
        },
        minimap = {
            angle = 225,
            radius = 80,
            hide = false,
        },
        collectionData = {},
        collectionSerial = 0,
        deletedEntries = {},
        cdmVoiceRegistry = {
            byIdentity = {},
            byPayload = {},
            collisionMap = {},
        },
        cdmVoiceUI = {
            lastCategory = nil,
        },
        cdmVoiceProfiles = {},
        cdmVoiceDisabledPresets = {},
        cdmVoiceSyncState = {
            importedVersion = 0,
            pendingRuntimeReload = false,
        },
        languageMode = "auto",
        uiSkinMode = "auto",
    },
}

local function CopyMissingTables(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end
    if target == source then
        return
    end

    local visited = {}
    local stack = {
        {
            target = target,
            source = source,
        },
    }

    while #stack > 0 do
        local item = table.remove(stack)
        local itemTarget = item.target
        local itemSource = item.source

        if type(itemTarget) == "table" and type(itemSource) == "table" and itemTarget ~= itemSource and not visited[itemSource] then
            visited[itemSource] = true
            for key, value in pairs(itemSource) do
                if type(value) == "table" then
                    if type(itemTarget[key]) ~= "table" then
                        itemTarget[key] = {}
                    end
                    stack[#stack + 1] = {
                        target = itemTarget[key],
                        source = value,
                    }
                elseif itemTarget[key] == nil then
                    itemTarget[key] = value
                end
            end
        end
    end
end

local function MigrateLegacyCastSuccessConfigs(db)
    local util = NS.ImportExportUtil
    if util and type(util.MergeLegacyCastSuccessConfigsIntoSpecConfigs) == "function" then
        return util:MergeLegacyCastSuccessConfigsIntoSpecConfigs(db, false)
    end
    return 0
end

local function ApplyKnownSpecScopeMigration(db)
    local migration = NS.Core and NS.Core.ScopeMigration
    if migration and type(migration.ApplyKnownSpecScopes) == "function" then
        return migration:ApplyKnownSpecScopes(db)
    end
    return 0
end

local function ClearLegacyCDMPendingApply(db)
    local cleared = 0
    for _, classMap in pairs(type(db) == "table" and type(db.cdmVoiceProfiles) == "table"
        and db.cdmVoiceProfiles or {}) do
        for _, specMap in pairs(type(classMap) == "table" and classMap or {}) do
            for _, record in pairs(type(specMap) == "table" and specMap or {}) do
                if type(record) == "table" and record.pendingApply ~= nil then
                    record.pendingApply = nil
                    cleared = cleared + 1
                end
            end
        end
    end
    return cleared
end

local function PurgeRemovedCustomEntries(db)
    if type(db) ~= "table" then
        return 0
    end
    local removed = 0
    local store = NS.CollectionStore or {}
    local removeFromCollections = type(store.RemoveEntryKeyFromAllCollectionScopes) == "function" and store.RemoveEntryKeyFromAllCollectionScopes or nil
    local buildEntryKey = type(store.BuildEntryKey) == "function" and store.BuildEntryKey or function(classID, specID, index)
        return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
    end

    local specConfigs = type(db.specConfigs) == "table" and db.specConfigs or nil
    if specConfigs then
        for classIDKey, classMap in pairs(specConfigs) do
            local classID = tonumber(classIDKey) or 0
            if type(classMap) == "table" then
                for specIDKey, specMap in pairs(classMap) do
                    local specID = tonumber(specIDKey) or 0
                    if type(specMap) == "table" then
                        for indexKey, entry in pairs(specMap) do
                            if type(entry) == "table" and tostring(entry.entryType or "") == "custom" then
                                local index = tonumber(indexKey) or 0
                                specMap[indexKey] = nil
                                removed = removed + 1
                                if removeFromCollections and index > 0 then
                                    removeFromCollections(buildEntryKey(classID, specID, index))
                                end
                            elseif type(entry) == "table" then
                                entry.customName = nil
                                entry.customCode = nil
                                entry.customUseEvents = nil
                                entry.customEvents = nil
                                entry.customEventText = nil
                                entry.customUseTicker = nil
                                entry.customInterval = nil
                                entry.customResultVar = nil
                                entry.customConditionOp = nil
                                entry.customConditionValue = nil
                                entry.customConditionLogic = nil
                                entry.customResultVars = nil
                                entry.customNotifications = nil
                                entry.customNotifyCount = nil
                                entry.customClassIDs = nil
                                entry.customSpecIDs = nil
                            end
                        end
                    end
                end
            end
        end
    end

    db.customConfigs = nil
    db.customRuntimeConfigs = nil
    if type(db.deletedEntries) == "table" and type(db.deletedEntries.signatures) == "table" then
        for key in pairs(db.deletedEntries.signatures) do
            if tostring(key):find(":custom:", 1, true) then
                db.deletedEntries.signatures[key] = nil
            end
        end
    end
    if removed > 0 then
        db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
    end
    return removed
end

local function CopyKnownSavedFields(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    local sourceProfile = type(source.profile) == "table" and source.profile or source
    for _, key in ipairs({
        "specConfigs", "castSuccessConfigs", "bloodlustConfig", "minimap", "collectionData", "deletedEntries",
        "cdmVoiceRegistry", "cdmVoiceUI", "cdmVoiceProfiles", "cdmVoiceDisabledPresets", "cdmVoiceSyncState",
    }) do
        if type(sourceProfile[key]) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyMissingTables(target[key], sourceProfile[key])
        elseif sourceProfile[key] ~= nil and target[key] == nil then
            target[key] = sourceProfile[key]
        end
    end
    if type(sourceProfile.collectionSerial) == "number" and type(target.collectionSerial) ~= "number" then
        target.collectionSerial = sourceProfile.collectionSerial
    end
    if type(sourceProfile.languageMode) == "string" and type(target.languageMode) ~= "string" then
        target.languageMode = sourceProfile.languageMode
    end
    if type(sourceProfile.uiSkinMode) == "string" and type(target.uiSkinMode) ~= "string" then
        target.uiSkinMode = sourceProfile.uiSkinMode
    end
end

function Database:Initialize()
    if self.initialized then
        return self.db
    end
    self.initialized = true

    local legacy = (type(QFXSkillAlertsDB) == "table") and QFXSkillAlertsDB or {}
    local aceDB = nil

    if type(LibStubGlobal) == "table" then
        local AceDB = LibStubGlobal:GetLibrary("AceDB-3.0", true)
        if AceDB then
            aceDB = AceDB:New("QFXSkillAlertsDB", defaults, true)
        end
    end

    if aceDB and type(aceDB.profile) == "table" then
        CopyKnownSavedFields(aceDB.profile, legacy)
        QFXSkillAlertsDB = aceDB.profile
        MigrateLegacyCastSuccessConfigs(aceDB.profile)
        ApplyKnownSpecScopeMigration(aceDB.profile)
        PurgeRemovedCustomEntries(aceDB.profile)
        ClearLegacyCDMPendingApply(aceDB.profile)
        if type(NS.SetLanguageMode) == "function" then
            NS.SetLanguageMode(aceDB.profile.languageMode or "auto")
        end
        self.db = aceDB
        return aceDB
    end

    CopyMissingTables(legacy, {
        specConfigs = {},
        castSuccessConfigs = {},
        bloodlustConfig = {
            customSoundPaths = { "", "", "", "", "" },
            voiceEnabled = true,
            voiceConditionOp = "<=",
            voiceConditionTime = 0,
            soundSource = "custom",
            imageEnabled = false,
            imageConditionOp = "<=",
            imageConditionTime = 0,
            imageSource = "auto",
            imageIconID = 0,
            imageSize = 96,
            imageDurationEnabled = false,
            imageDuration = 2,
            imageX = 0,
            imageY = 120,
            textEnabled = false,
            textConditionOp = "<=",
            textConditionTime = 0,
            textSize = 24,
            textDurationEnabled = false,
            textDuration = 2,
            textX = 0,
            textY = 120,
            textAttachMode = "outside",
            textVAlign = "bottom",
            textHAlign = "center",
            textOffsetX = 0,
            textOffsetY = 0,
        },
        minimap = {
            angle = 225,
            radius = 80,
            hide = false,
        },
        collectionData = {},
        collectionSerial = 0,
        deletedEntries = {},
        cdmVoiceRegistry = {
            byIdentity = {},
            byPayload = {},
            collisionMap = {},
        },
        cdmVoiceUI = {
            lastCategory = nil,
        },
        cdmVoiceProfiles = {},
        cdmVoiceDisabledPresets = {},
        cdmVoiceSyncState = {
            importedVersion = 0,
            pendingRuntimeReload = false,
        },
        languageMode = "auto",
        uiSkinMode = "auto",
    })
    QFXSkillAlertsDB = legacy
    MigrateLegacyCastSuccessConfigs(legacy)
    ApplyKnownSpecScopeMigration(legacy)
    PurgeRemovedCustomEntries(legacy)
    ClearLegacyCDMPendingApply(legacy)
    if type(NS.SetLanguageMode) == "function" then
        NS.SetLanguageMode(legacy.languageMode or "auto")
    end
    self.db = nil
    return nil
end
