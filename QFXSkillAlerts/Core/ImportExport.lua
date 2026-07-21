local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

local ImportExport = NS.ImportExport or {}
NS.ImportExport = ImportExport

NS.AceOptions = NS.AceOptions or {}

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local ImportCodec = NS.ImportCodec or {}
local ImportEntryProcessor = NS.ImportEntryProcessor or {}
local ImportFullProcessor = NS.ImportFullProcessor or {}
local ImportCDMVoicePresetProcessor = NS.ImportCDMVoicePresetProcessor or {}
local ImportCollectionProcessor = NS.ImportCollectionProcessor or {}
local ExportBuilder = NS.ExportBuilder or {}
local ImportRefreshScheduler = NS.ImportRefreshScheduler
local ImportExportUtil = NS.ImportExportUtil or {}

local function GetApi()
    return NS.API
end

local function DecodeExportPayload(text)
    if ImportCodec and type(ImportCodec.Decode) == "function" then
        return ImportCodec:Decode(text)
    end
    return nil, L("ERR_IMPORT_MISSING_LIBS")
end

local function ImportEntryRecord(record, preferImportedIndex)
    if ImportEntryProcessor and type(ImportEntryProcessor.ImportEntryRecord) == "function" then
        return ImportEntryProcessor:ImportEntryRecord(record, preferImportedIndex)
    end
    return nil
end

function ImportExport.ExportEntryString(entryKey)
    if ExportBuilder and type(ExportBuilder.ExportEntryString) == "function" then
        return ExportBuilder:ExportEntryString(entryKey)
    end
    return ""
end

function ImportExport.ExportCollectionString(groupKey)
    if ExportBuilder and type(ExportBuilder.ExportCollectionString) == "function" then
        return ExportBuilder:ExportCollectionString(groupKey)
    end
    return ""
end

function ImportExport.ExportFullString()
    if ExportBuilder and type(ExportBuilder.ExportFullString) == "function" then
        return ExportBuilder:ExportFullString()
    end
    return ""
end

function ImportExport.ExportCDMVoicePresetString()
    if ExportBuilder and type(ExportBuilder.ExportCDMVoicePresetString) == "function" then
        return ExportBuilder:ExportCDMVoicePresetString()
    end
    return ""
end

local function ImportFullPayload(payload)
    if ImportFullProcessor and type(ImportFullProcessor.Import) == "function" then
        return ImportFullProcessor:Import(payload)
    end
    return false, 0
end

local function ImportEntryPayload(payload)
    local imported = 0
    for _, record in ipairs(payload.entries or {}) do
        if ImportEntryRecord(record, true) then
            imported = imported + 1
        end
    end
    return imported > 0, imported
end

local function ImportCollectionPayload(payload)
    if ImportCollectionProcessor and type(ImportCollectionProcessor.Import) == "function" then
        return ImportCollectionProcessor:Import(payload)
    end
    return false, 0
end

function ImportExport.ImportString(text)
    local payload, err = DecodeExportPayload(text)
    if not payload then
        print("[QFX-SA] " .. L("MSG_IMPORT_FAILED", tostring(err or "unknown error")))
        return false
    end

    local ok, count, details = false, 0, nil
    if payload.type == "entry" then
        ok, count = ImportEntryPayload(payload)
    elseif payload.type == "collection" then
        ok, count = ImportCollectionPayload(payload)
    elseif payload.type == "full" then
        ok, count = ImportFullPayload(payload)
    elseif payload.type == "cdmVoicePreset" then
        if ImportCDMVoicePresetProcessor and type(ImportCDMVoicePresetProcessor.Import) == "function" then
            ok, count, details = ImportCDMVoicePresetProcessor:Import(payload)
        end
    else
        print("[QFX-SA] " .. L("MSG_IMPORT_UNKNOWN_TYPE"))
        return false
    end

    if ok then
        if payload.type ~= "cdmVoicePreset" then
            if ImportRefreshScheduler and type(ImportRefreshScheduler.Schedule) == "function" then
                ImportRefreshScheduler:Schedule("import:" .. tostring(payload.type or "unknown"))
            else
                local api = GetApi()
                if api then
                if type(api.ResolveAllStoredItemTriggers) == "function" then
                    api.ResolveAllStoredItemTriggers(true)
                end
                if type(api.RebuildRuntimeConfig) == "function" then
                    api.RebuildRuntimeConfig()
                end
                if type(api.RebuildCastSuccessConfig) == "function" then
                    api.RebuildCastSuccessConfig()
                end
                if type(api.RebuildCustomConfig) == "function" then
                    api.RebuildCustomConfig()
                end
                if type(api.RefreshRuntimeCooldowns) == "function" then
                    api.RefreshRuntimeCooldowns()
                end
                if type(api.RebuildBloodlustConfig) == "function" then
                    api.RebuildBloodlustConfig()
                end
                if type(api.RefreshPanel) == "function" then
                    api.RefreshPanel()
                end
                end
            end
        end
        if payload.type == "cdmVoicePreset" then
            details = type(details) == "table" and details or {}
            print("[QFX-SA] " .. L(
                "CDM_PRESET_IMPORT_LOCAL_DONE",
                tonumber(count) or 0,
                tonumber(details.currentSpec) or 0,
                tonumber(details.otherScopes) or 0,
                tonumber(details.pending) or 0,
                tonumber(details.invalid) or 0
            ))
        else
            print("[QFX-SA] " .. L("MSG_IMPORT_DONE", tostring(payload.type), tonumber(count) or 0))
        end
        return true
    end

    print("[QFX-SA] " .. L("MSG_IMPORT_EMPTY"))
    return false
end


function ImportExport.DeepCopyTable(value, seen)
    if ImportExportUtil and type(ImportExportUtil.DeepCopyTable) == "function" then
        return ImportExportUtil:DeepCopyTable(value, seen)
    end
    return value
end

function ImportExport.SanitizeEntryForImport(entry)
    if ImportExportUtil and type(ImportExportUtil.SanitizeEntryForImport) == "function" then
        return ImportExportUtil:SanitizeEntryForImport(entry)
    end
    return nil
end

function NS.AceOptions:ExportEntryString(entryKey)
    return ImportExport.ExportEntryString(entryKey)
end

function NS.AceOptions:ExportCollectionString(groupKey)
    return ImportExport.ExportCollectionString(groupKey)
end

function NS.AceOptions:ExportFullString()
    return ImportExport.ExportFullString()
end

function NS.AceOptions:ImportString(text)
    return ImportExport.ImportString(text)
end
