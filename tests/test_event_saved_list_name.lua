local function Assert(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

local eventEntry = {
    entryType = "event",
    eventKey = "combat_start",
    eventThrottle = 1,
    spellId = 0,
    objectType = "spell",
    voiceEnabled = true,
    notifyMode = "tts",
    soundSource = "tts",
    ttsText = "进入战斗",
    alertClassIDs = { [0] = true },
    alertSpecIDs = { [0] = true },
    alertRaceIDs = { [0] = true },
}

QFXSkillAlertsDB = {
    specConfigs = { [0] = { [0] = { [2] = eventEntry } } },
    collectionData = {
        [0] = { [0] = { root = { { type = "entry", index = 2 } }, groups = {} } },
    },
}

local function BuildEntryKey(classID, specID, index)
    return tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(index)
end

QFXSkillAlertsNS = {
    Constants = {
        ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
        OBJECT_TYPE_SPELL = "spell", OBJECT_TYPE_ITEM = "item",
        ITEM_LOAD_NONE = "none", ITEM_LOAD_EQUIPPED = "equipped", ITEM_LOAD_BAGS = "bags",
    },
    Utils = {
        TrimText = function(value) return tostring(value or ""):match("^%s*(.-)%s*$") end,
    },
    L = function(key, ...)
        local values = { SAVED_VOICE_TTS = "TTS: %s", LOADED_TAG = " loaded", UNLOADED_TAG = " unloaded" }
        local text = values[key] or key
        return select("#", ...) > 0 and string.format(text, ...) or text
    end,
    CollectionStore = {
        BuildEntryKey = BuildEntryKey,
        BuildGroupKey = function(classID, specID, groupID)
            return "group:" .. tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(groupID)
        end,
        EntryRefToKey = function(classID, specID, ref)
            local index = tonumber(ref)
            if not index then return nil end
            return BuildEntryKey(classID, specID, index), classID, specID, index
        end,
        EnsureCollectionScope = function(classID, specID)
            return QFXSkillAlertsDB.collectionData[classID][specID]
        end,
        NormalizeCollectionScope = function() return false end,
        IsSameScopeGroupRef = function() return nil end,
        IsCDMEntryKey = function() return false end,
    },
    AceOptions = {
        ResolveSoundSourceFields = function(_, entry) return entry end,
    },
    API = {
        GetStoredEntryMap = function() return QFXSkillAlertsDB.specConfigs[0][0] end,
        GetEntry = function(map, index) return map[index] end,
        GetOrderedEntryIndices = function() return { 2 } end,
        GetModes = function() return "tts", "sound" end,
        GetCurrentClassSpec = function() return 1, 71 end,
        IsActiveScopeLoaded = function() return true end,
        ResolveClassName = function() return "All classes" end,
        ResolveSpecName = function() return "All specs" end,
        ResolveObjectType = function() return "spell" end,
        ResolveObjectIcon = function() return nil end,
        ResolveSpellIcon = function() return nil end,
        NormalizeEventVoiceKey = function(value) return value == "combat_start" and value or nil end,
        ResolveEventVoiceName = function(value) return value == "combat_start" and "进入战斗" or "" end,
        ResolveEventVoiceIcon = function(value) return value == "combat_start" and 132337 or nil end,
    },
}

function UnitRace() return "Human", "Human", 1 end

dofile("QFXSkillAlerts_Config/Core/SavedListLayout.lua")
local rows = QFXSkillAlertsNS.SavedListLayout:GetSavedListLayoutForScope({}, 0, 0, false)
Equal(#rows, 1, "event saved entry should produce one root row")
Equal(rows[1].entryType, "event", "saved row should preserve event type")
Equal(rows[1].eventKey, "combat_start", "saved row should preserve event key")
Equal(rows[1].spellName, "进入战斗", "saved row should show the localized event name instead of spell ID zero")
Equal(rows[1].icon, 132337, "saved row should use the event icon")
Assert(rows[1].spellName ~= "0", "event saved row must never fall back to spell ID zero")

print("event saved-list name regression tests passed")
