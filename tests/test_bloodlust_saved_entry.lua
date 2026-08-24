local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
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

local state = { selectedKey = "bloodlust", selectedCollectionKey = "group:1:1:test" }
local loadBloodlustCalls = 0
local encodedPayload
local importPayload
local scheduledReason

QFXSkillAlertsDB = {
    specConfigs = {},
    collectionData = {},
    savedListOrder = {},
    bloodlustConfig = {
        voiceEnabled = true,
        notifyMode = "sound",
        soundSource = "sharedmedia",
        sharedMediaSound = "Raid Horn",
        soundPath = "Interface\\SharedMedia\\RaidHorn.ogg",
        imageEnabled = true,
        textEnabled = false,
    },
}

QFXSkillAlertsNS = {
    Constants = {},
    Utils = {
        TrimText = function(value) return tostring(value or ""):match("^%s*(.-)%s*$") end,
    },
    CollectionStore = {
        EnsureRootDB = function() return QFXSkillAlertsDB end,
    },
    L = function(key, ...)
        local values = {
            SECTION_BLOODLUST_BUILTIN = "Built-in detection",
            TAB_VOICE = "Voice",
            TAB_IMAGE = "Image",
            TAB_TEXT = "Text",
            SAVED_VOICE_SHAREDMEDIA = "SharedMedia: %s",
        }
        local value = values[key] or key
        if select("#", ...) > 0 then
            return string.format(value, ...)
        end
        return value
    end,
    API = {
        GetModes = function() return "tts", "sound" end,
        GetCurrentClassSpec = function() return 1, 1 end,
        ResolveSpellIcon = function(spellID)
            Assert(spellID == 2825, "the Bloodlust row should resolve the Bloodlust icon")
            return 123456
        end,
    },
    AceOptions = {
        GetState = function() return state end,
        ResolveSoundSourceFields = function(_, entry) return entry end,
        NormalizeSoundPath = function(_, value) return tostring(value or "") end,
        IsBuiltinSoundPath = function() return false end,
        LoadBloodlustConfig = function()
            loadBloodlustCalls = loadBloodlustCalls + 1
            state.entryType = "bloodlust"
        end,
        GetSavedListLayoutForScope = function() return {} end,
    },
    ImportExportUtil = {
        DeepCopyTable = function(_, value) return DeepCopy(value) end,
    },
    ImportCodec = {
        Encode = function(_, payload)
            encodedPayload = payload
            return "bloodlust-export"
        end,
        Decode = function(_, text)
            Assert(text == "bloodlust-import", "unexpected import token")
            return DeepCopy(importPayload)
        end,
    },
    ImportRefreshScheduler = {
        Schedule = function(_, reason) scheduledReason = reason end,
    },
}

dofile("QFXSkillAlerts_Config/Core/EntryStore.lua")

local row = QFXSkillAlertsNS.EntryStore:GetBloodlustSavedEntry(QFXSkillAlertsNS.AceOptions)
Assert(type(row) == "table", "the Bloodlust singleton must produce a saved-list row")
Equal(row.key, "bloodlust", "the Bloodlust row must use a stable singleton key")
Equal(row.entryType, "bloodlust", "the saved row must route to the Bloodlust editor")
Equal(row.soundDetail, "SharedMedia: Raid Horn", "the saved row must show the active shared voice")
Equal(row.icon, 123456, "the saved row should use the resolved Bloodlust icon")
Assert(row.canDrag == false and row.canDrop == false, "the global singleton must stay outside class/spec collections")

QFXSkillAlertsNS.EntryStore:LoadSelectedEntry(QFXSkillAlertsNS.AceOptions)
Equal(loadBloodlustCalls, 1, "selecting the saved row must load the Bloodlust editor state")
Equal(state.selectedKey, "bloodlust", "loading must preserve the special selection key")
Equal(state.selectedCollectionKey, nil, "loading the global singleton must clear collection selection")

QFXSkillAlertsNS.AceOptions.GetBloodlustSavedEntry = function(self)
    return QFXSkillAlertsNS.EntryStore:GetBloodlustSavedEntry(self)
end
dofile("QFXSkillAlerts_Config/UI/SavedListBuilder.lua")
local loaded, unloaded = QFXSkillAlertsNS.UI.SavedListBuilder.BuildLayout({}, state)
Equal(#loaded, 1, "the Bloodlust row must appear in the loaded section")
Equal(loaded[1].key, "bloodlust", "the saved-list builder must retain the Bloodlust key")
Equal(#unloaded, 0, "the global Bloodlust row must not appear as an unloaded class/spec entry")

dofile("QFXSkillAlerts_Config/Core/ExportBuilder.lua")
local exportText = QFXSkillAlertsNS.ExportBuilder:ExportEntryString("bloodlust")
Equal(exportText, "bloodlust-export", "single-entry export must accept the Bloodlust row")
Equal(encodedPayload.type, "bloodlust", "Bloodlust single export must use its own payload type")
Equal(encodedPayload.bloodlustConfig.sharedMediaSound, "Raid Horn", "single export must preserve Bloodlust voice fields")

importPayload = {
    type = "bloodlust",
    version = 1,
    bloodlustConfig = {
        voiceEnabled = true,
        soundSource = "builtin",
        builtinSoundPath = "Interface\\AddOns\\QFXSkillAlerts\\Media\\Sounds\\AirHorn.ogg",
    },
}
dofile("QFXSkillAlerts_Config/Core/ImportExport.lua")
Assert(QFXSkillAlertsNS.ImportExport.ImportString("bloodlust-import") == true,
    "single Bloodlust payload should import successfully")
Equal(QFXSkillAlertsDB.bloodlustConfig.soundSource, "builtin", "single import must replace the Bloodlust configuration")
Equal(scheduledReason, "import:bloodlust", "single import must schedule the normal runtime/list refresh")

print("bloodlust saved-entry regression tests passed")
