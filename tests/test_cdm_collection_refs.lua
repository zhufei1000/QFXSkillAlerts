local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

local VALID_CDM = "cdmpreset:1:2:essential:12345:AVAILABLE"
local INVALID_CDM = "cdmpreset:1:2:essential:99999:AVAILABLE"

local function ParseCDMKey(key)
    local classID, specID, category, spellID, eventKey = tostring(key or ""):match(
        "^cdmpreset:(%d+):(%d+):([^:]+):(%d+):([^:]+)$"
    )
    if not classID then
        return nil
    end
    return {
        keyType = "preset",
        classID = tonumber(classID),
        specID = tonumber(specID),
        recordKey = table.concat({ category, spellID, eventKey }, ":"),
    }
end

-- Collection normalization keeps live CDM references and removes stale ones.
QFXSkillAlertsDB = {
    specConfigs = { [1] = { [2] = {} } },
    collectionData = {
        [1] = {
            [2] = {
                root = { { type = "group", id = "g1" } },
                groups = {
                    g1 = { name = "CDM", entries = { VALID_CDM, INVALID_CDM } },
                },
            },
        },
    },
}
QFXSkillAlertsNS = { Constants = {}, Utils = {} }
dofile("QFXSkillAlerts/Core/CollectionStore.lua")
local Store = QFXSkillAlertsNS.CollectionStore
local api = {
    GetOrderedEntryIndices = function() return {} end,
    GetStoredEntryMap = function() return {} end,
    GetEntry = function() return nil end,
    ParseCDMVoiceSavedKey = ParseCDMKey,
    GetCDMVoicePresetRecord = function(_, _, recordKey)
        if recordKey == "essential:12345:AVAILABLE" then
            return { recordKey = recordKey }
        end
        return nil
    end,
}
local scope = Store.EnsureCollectionScope(1, 2)
Store.NormalizeCollectionScope(scope, {}, 1, 2, api)
Equal(#scope.groups.g1.entries, 1, "stale CDM collection references must be removed")
Equal(scope.groups.g1.entries[1], VALID_CDM, "live CDM collection reference must be preserved")

api.GetModes = function() return "tts", "sound" end
api.GetCurrentClassSpec = function() return 1, 2 end
local snapshotRevision = 1
local savedEntryBuilds = 0
api.GetCDMVoiceRefreshSerial = function() return snapshotRevision end
api.GetCDMVoiceSavedEntries = function()
    savedEntryBuilds = savedEntryBuilds + 1
    return {
        {
            key = VALID_CDM,
            entryType = "cdmVoice",
            itemType = "entry",
            classID = 1,
            specID = 2,
            spellName = "Test CDM",
            isLoaded = true,
            isVirtual = true,
        },
    }
end
QFXSkillAlertsNS.API = api
local snapshotA = Store.GetCDMEntrySnapshot(api)
local snapshotB = Store.GetCDMEntrySnapshot(api)
Equal(snapshotA, snapshotB, "unchanged CDM revision should reuse one saved-list snapshot")
Equal(savedEntryBuilds, 1, "reused CDM snapshot must not rebuild saved entries")
snapshotRevision = snapshotRevision + 1
Store.GetCDMEntrySnapshot(api)
Equal(savedEntryBuilds, 2, "a changed CDM revision must invalidate the snapshot")
dofile("QFXSkillAlerts_Config/Core/SavedListLayout.lua")
local layoutRows = QFXSkillAlertsNS.SavedListLayout:GetSavedListLayoutForScope({}, 1, 2, true)
Equal(#layoutRows, 2, "expanded collection should render its CDM child")
Equal(layoutRows[1].count, 1, "CDM child must contribute to the collection count")
Equal(layoutRows[2].key, VALID_CDM, "collection should render the referenced CDM row")
Assert(layoutRows[2].canDrag == true and layoutRows[2].isVirtual == false,
    "rendered CDM collection row must be draggable")

-- A CDM projection can be dragged into and back out of a collection.
QFXSkillAlertsNS.API = {
    GetCurrentClassSpec = function() return 1, 2 end,
    GetStoredEntryMap = function() return {} end,
    GetOrderedEntryIndices = function() return {} end,
    GetEntry = function() return nil end,
    ParseCDMVoiceSavedKey = ParseCDMKey,
    GetCDMVoicePresetRecord = api.GetCDMVoicePresetRecord,
}
dofile("QFXSkillAlerts_Config/Core/SavedListOrder.lua")
dofile("QFXSkillAlerts_Config/Core/SavedListDropKey.lua")
dofile("QFXSkillAlerts_Config/Core/SavedListMoveContext.lua")
dofile("QFXSkillAlerts_Config/Core/SavedListMoveController.lua")
local owner = { GetState = function() return {} end }
scope.groups.g1.entries = {}
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, VALID_CDM, "group:1:2:g1:inside", "loaded", true
), "CDM entry should move into a collection")
Equal(scope.groups.g1.entries[1], VALID_CDM, "collection should store the stable CDM key")
Assert(QFXSkillAlertsNS.SavedListMoveController:MoveSavedListItem(
    owner, VALID_CDM, "root:1:2:after", "loaded", true
), "CDM entry should move out of a collection")
Equal(#scope.groups.g1.entries, 0, "moving to root should remove the CDM collection reference")

-- Deleting a collection batch-deletes its CDM presets and removes the group.
scope.groups.g1.entries = { VALID_CDM }
local deletedKeys
QFXSkillAlertsNS.API.EnsureEntryMap = function() return {} end
QFXSkillAlertsNS.API.DeleteCDMVoicePresetsLocalByKeys = function(keys)
    deletedKeys = keys
    return true, #keys
end
QFXSkillAlertsNS.API.RebuildRuntimeConfig = function() end
QFXSkillAlertsNS.API.RebuildCastSuccessConfig = function() end
QFXSkillAlertsNS.API.RefreshRuntimeCooldowns = function() end
QFXSkillAlertsNS.AceOptions = owner
dofile("QFXSkillAlerts_Config/Core/CollectionController.lua")
Assert(QFXSkillAlertsNS.CollectionController:DeleteCollection(owner, "group:1:2:g1", true),
    "collection deletion should succeed")
Equal(deletedKeys and deletedKeys[1], VALID_CDM, "collection deletion must delete its CDM preset")
Assert(scope.groups.g1 == nil, "deleted collection must be removed")

-- Root CDM projections participate in saved-list ordering after normal rows.
QFXSkillAlertsDB = {
    specConfigs = { [1] = { [2] = { [1] = {} } } },
    collectionData = {},
    savedListOrder = { loaded = { VALID_CDM, "1:2:1" }, unloaded = {} },
}
QFXSkillAlertsNS.UI = {}
QFXSkillAlertsNS.API.GetCurrentClassSpec = function() return 1, 2 end
QFXSkillAlertsNS.API.GetCDMVoiceSavedEntries = api.GetCDMVoiceSavedEntries
QFXSkillAlertsNS.AceOptions = {
    GetSavedListLayoutForScope = function(_, classID, specID)
        if classID == 1 and specID == 2 then
            return {
                { key = "1:2:1", itemType = "entry", isLoaded = true },
            }
        end
        return {}
    end,
}
dofile("QFXSkillAlerts_Config/UI/SavedListBuilder.lua")
local loaded = QFXSkillAlertsNS.UI.SavedListBuilder.BuildLayout({}, {})
Equal(loaded[1].key, VALID_CDM, "saved order should position a root CDM entry")
Assert(loaded[1].canDrag == true and loaded[1].isVirtual == false,
    "root CDM projection must be draggable")

-- Empty CDM metadata from the first collection-enabled build is a no-op, while
-- real CDM payloads contribute to the reported import count and preserve refs.
local function ImportCollectionPayload(payload, importResult, importCount)
    QFXSkillAlertsDB = { specConfigs = {}, collectionData = {}, collectionSerial = 0 }
    QFXSkillAlertsNS = {
        Constants = {},
        Utils = {},
        ImportEntryProcessor = { ImportEntryRecord = function() return nil end },
    }
    dofile("QFXSkillAlerts/Core/CollectionStore.lua")
    local importCalls = 0
    QFXSkillAlertsNS.API = {
        GetStoredEntryMap = function() return {} end,
        GetOrderedEntryIndices = function() return {} end,
        GetEntry = function() return nil end,
        ImportCDMVoicePresetPayload = function()
            importCalls = importCalls + 1
            return importResult, importCount
        end,
        ParseCDMVoiceSavedKey = ParseCDMKey,
        HasCDMVoicePresetRecord = function(_, _, recordKey)
            return recordKey == "essential:12345:AVAILABLE"
        end,
    }
    dofile("QFXSkillAlerts_Config/Core/ImportCollectionProcessor.lua")
    local ok, count = QFXSkillAlertsNS.ImportCollectionProcessor:Import(payload)
    return ok, count, importCalls
end

local emptyOK, emptyCount, emptyCalls = ImportCollectionPayload({
    type = "collection",
    classID = 1,
    specID = 2,
    group = { name = "ordinary", entries = {} },
    cdmVoiceProfiles = {},
}, false, 0)
Assert(emptyOK, "an ordinary collection with empty CDM metadata must still import")
Equal(emptyCount, 0, "empty CDM metadata must not affect the ordinary import count")
Equal(emptyCalls, 0, "empty CDM metadata must not call the CDM importer")

local cdmOK, cdmCount, cdmCalls = ImportCollectionPayload({
    type = "collection",
    classID = 1,
    specID = 2,
    rootGroupID = "old",
    group = { name = "cdm", entries = { VALID_CDM } },
    groups = { old = { name = "cdm", entries = { VALID_CDM } } },
    cdmVoiceProfiles = { [1] = { [2] = { record = {} } } },
}, true, 1)
Assert(cdmOK, "a CDM collection should import")
Equal(cdmCount, 1, "CDM collection import count must include imported presets")
Equal(cdmCalls, 1, "CDM collection payload should be imported once")

print("CDM collection reference regression tests passed")
