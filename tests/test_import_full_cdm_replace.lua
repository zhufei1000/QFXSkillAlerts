local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(item, seen)
    end
    return copy
end

local cdmShouldSucceed = false
local capturedCDMPayload
QFXSkillAlertsDB = {
    specConfigs = { sentinel = true },
    savedListOrder = { loaded = {}, unloaded = {} },
}
QFXSkillAlertsNS = {
    Constants = {},
    CollectionStore = {},
    ImportEntryProcessor = {},
    ImportExportUtil = {
        DeepCopyTable = function(_, value) return DeepCopy(value) end,
        SanitizeEntryForImport = function(_, entry) return DeepCopy(entry) end,
    },
    API = {
        ImportCDMVoicePresetPayload = function(payload)
            capturedCDMPayload = payload
            return cdmShouldSucceed
        end,
        ClearEntryDeletedMarker = function() end,
        GetStoredEntryMap = function() return {} end,
    },
}

dofile("QFXSkillAlerts_Config/Core/ImportFullProcessor.lua")
local Processor = QFXSkillAlertsNS.ImportFullProcessor

local ok = Processor:Import({
    type = "full",
    specConfigs = {},
    cdmVoiceProfiles = { invalid = true },
})
Assert(ok == false, "full import must propagate a failed CDM restore")
Assert(QFXSkillAlertsDB.specConfigs.sentinel == true,
    "failed CDM preflight must not replace ordinary configuration")
Assert(capturedCDMPayload and capturedCDMPayload.replace == true,
    "full import must request CDM replacement semantics")

cdmShouldSucceed = true
capturedCDMPayload = nil
ok = Processor:Import({
    type = "full",
    specConfigs = {
        [0] = {
            [0] = {
                [1] = { entryType = "cast", objectType = "spell", spellId = 12345 },
            },
        },
    },
    cdmVoiceProfiles = {},
})
Assert(ok == true, "valid full import should succeed")
Assert(capturedCDMPayload and capturedCDMPayload.replace == true,
    "valid full import must keep CDM replacement semantics")
Assert(type(QFXSkillAlertsDB.specConfigs[0]) == "table"
    and type(QFXSkillAlertsDB.specConfigs[0][0]) == "table"
    and QFXSkillAlertsDB.specConfigs[0][0][1].spellId == 12345,
    "valid full import should restore ordinary configuration")

print("full import CDM replacement regression tests passed")
