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

function wipe(values)
    for key in pairs(values or {}) do
        values[key] = nil
    end
    return values
end

local now = 100
local globalMap = {
    [1] = {
        entryType = "event", eventKey = "combat_start", eventThrottle = 2,
        voiceEnabled = true, notifyMode = "sound", soundPath = "combat.ogg",
        alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
    [2] = {
        entryType = "event", eventKey = "encounter_success", eventThrottle = 0,
        voiceEnabled = true, notifyMode = "tts", ttsText = "Victory",
        alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
    [3] = {
        entryType = "event", eventKey = "encounter_wipe", eventThrottle = 0,
        voiceEnabled = true, notifyMode = "tts", ttsText = "Wipe",
        alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
    [4] = {
        entryType = "event", eventKey = "ready_check", eventThrottle = 0,
        voiceEnabled = true, notifyMode = "sound", soundPath = "ready.ogg",
        alertClassIDs = { [2] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
}

QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
        ENTRY_MIN = 1, MODE_SOUND = "sound",
    },
    L = function(key) return key end,
}

function UnitRace() return "Human", "Human", 1 end

local createdFrames = 0
local frame
local function CreateTestFrame()
    createdFrames = createdFrames + 1
    frame = { registered = {} }
    function frame:SetScript(name, callback) self[name] = callback end
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:UnregisterAllEvents() wipe(self.registered) end
    return frame
end

dofile("QFXSkillAlerts/Core/EntryMap.lua")
dofile("QFXSkillAlerts/Core/EventVoice.lua")

local EntryMap = QFXSkillAlertsNS.Core.EntryMap
local EventVoice = QFXSkillAlertsNS.Core.EventVoice
local played = {}
EventVoice:Configure({
    getCurrentClassSpec = function() return 1, 101 end,
    getStoredEntryMap = function(classID, specID)
        if classID == 0 and specID == 0 then return globalMap end
        return {}
    end,
    getOrderedEntryIndices = function(map) return EntryMap:GetOrderedEntryIndices(map) end,
    getEntry = function(map, index) return EntryMap:GetEntry(map, index) end,
    resolveEntrySoundPath = function(entry) return entry.soundPath end,
    playNotification = function(cfg)
        played[#played + 1] = cfg.eventKey
        return true
    end,
    getTime = function() return now end,
    createFrame = CreateTestFrame,
})

local ok, count = EventVoice:Rebuild()
Assert(ok, "event runtime rebuild should succeed")
Equal(count, 3, "scope filtering should keep only active event voices")
Equal(createdFrames, 1, "an event frame should be created only when active entries exist")
Assert(frame.registered.PLAYER_REGEN_DISABLED, "combat-start event should be registered")
Assert(frame.registered.ENCOUNTER_END, "shared encounter-end event should be registered once")
Assert(not frame.registered.READY_CHECK, "out-of-scope event should not be registered")
Assert(frame.OnEvent ~= nil, "event frame needs an OnEvent handler")

Assert(EventVoice:Dispatch("PLAYER_REGEN_DISABLED"), "first combat event should play")
Assert(not EventVoice:Dispatch("PLAYER_REGEN_DISABLED"), "duplicate combat event should be throttled")
now = 102
Assert(EventVoice:Dispatch("PLAYER_REGEN_DISABLED"), "combat event should play after its throttle window")
Equal(played[1], "combat_start", "combat start should route to the correct entry")
Equal(played[2], "combat_start", "combat start should route again after throttle")

Assert(EventVoice:Dispatch("ENCOUNTER_END", 10, "Boss", 8, 5, 1), "successful encounter should play")
Equal(played[#played], "encounter_success", "success result should not trigger wipe voice")
Assert(EventVoice:Dispatch("ENCOUNTER_END", 10, "Boss", 8, 5, 0), "failed encounter should play")
Equal(played[#played], "encounter_wipe", "wipe result should not trigger success voice")

globalMap = {}
local _, emptyCount = EventVoice:Rebuild()
Equal(emptyCount, 0, "empty rebuild should clear active event voices")
Assert(next(frame.registered) == nil, "empty rebuild should unregister every event")

local eventEntry = { entryType = "event", eventKey = "combat_start", spellId = 0 }
Assert(EntryMap:GetEntry({ [1] = eventEntry }, 1) == eventEntry, "event entries must remain valid without a spell ID")
Equal(EntryMap:FindFirstFreeIndex({ [1] = eventEntry }), 2, "event entries must occupy saved-list indices")

QFXSkillAlertsNS.API = {
    NormalizeEventVoiceKey = function(value) return EventVoice:NormalizeEventKey(value) end,
    GetModes = function() return "tts", "sound" end,
    ResolveObjectType = function() return "spell" end,
}
QFXSkillAlertsNS.Utils = {
    TrimText = function(value) return tostring(value or ""):match("^%s*(.-)%s*$") end,
}
dofile("QFXSkillAlerts/Core/ImportExportUtil.lua")
local sanitized = QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({
    entryType = "event",
    eventKey = "mythic_plus_start",
    eventThrottle = 999,
    voiceEnabled = true,
    notifyMode = "sound",
    soundSource = "custom",
    soundPath = "Interface/AddOns/Test/start.ogg",
    imageEnabled = true,
    textEnabled = true,
    alertClassIDs = { [1] = true },
    alertSpecIDs = { [101] = true },
})
Assert(type(sanitized) == "table", "valid event entry should pass import sanitization")
Equal(sanitized.entryType, "event", "event type must survive import sanitization")
Equal(sanitized.eventKey, "mythic_plus_start", "event key must survive import sanitization")
Equal(sanitized.eventThrottle, 300, "event duplicate guard must clamp to its supported range")
Equal(sanitized.spellId, 0, "event entry must not acquire a fake spell ID")
Assert(not sanitized.imageEnabled and not sanitized.textEnabled, "event import must remain voice-only")
Assert(QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({ entryType = "event", eventKey = "invalid" }) == nil,
    "unknown events must be rejected during import")

local importMap = {
    [1] = {
        entryType = "event", eventKey = "combat_start", spellId = 0,
        voiceEnabled = true, notifyMode = "tts", soundSource = "tts", ttsText = "Warrior combat",
        alertClassIDs = { [1] = true }, alertSpecIDs = { [71] = true }, alertRaceIDs = { [0] = true },
    },
}
QFXSkillAlertsNS.API.EnsureEntryMap = function() return importMap end
QFXSkillAlertsNS.API.GetStoredEntryMap = function() return importMap end
QFXSkillAlertsNS.API.GetEntry = function(map, index) return EntryMap:GetEntry(map, index) end
QFXSkillAlertsNS.API.GetOrderedEntryIndices = function(map) return EntryMap:GetOrderedEntryIndices(map) end
QFXSkillAlertsNS.API.FindFirstFreeIndex = function(map) return EntryMap:FindFirstFreeIndex(map) end
QFXSkillAlertsNS.API.ClearEntryDeletedMarker = function() end
dofile("QFXSkillAlerts_Config/Core/ImportEntryProcessor.lua")
local ImportEntryProcessor = QFXSkillAlertsNS.ImportEntryProcessor
local secondScopeRecord = {
    classID = 0, specID = 0, index = 1,
    entry = {
        entryType = "event", eventKey = "combat_start", spellId = 0,
        voiceEnabled = true, notifyMode = "tts", soundSource = "tts", ttsText = "Paladin combat",
        alertClassIDs = { [2] = true }, alertSpecIDs = { [65] = true }, alertRaceIDs = { [0] = true },
    },
}
local secondKey, secondIndex = ImportEntryProcessor:ImportEntryRecord(secondScopeRecord, true)
Equal(secondIndex, 2, "same event with a different scope must use a separate saved index")
Equal(secondKey, "0:0:2", "different event scope should remap to its new key")
Equal(importMap[1].ttsText, "Warrior combat", "different event scope must not overwrite the existing entry")
Equal(importMap[2].ttsText, "Paladin combat", "different event scope should be imported intact")

secondScopeRecord.entry.ttsText = "Updated paladin combat"
local replacedKey, replacedIndex = ImportEntryProcessor:ImportEntryRecord(secondScopeRecord, false)
Equal(replacedIndex, 2, "same event and same scope should replace its existing entry")
Equal(replacedKey, "0:0:2", "same event scope should keep a stable saved key")
Equal(importMap[1].ttsText, "Warrior combat", "same-scope replacement must not affect another scope")
Equal(importMap[2].ttsText, "Updated paladin combat", "same-scope replacement should update the matching entry")

local collectionScope = { root = {}, groups = {} }
QFXSkillAlertsDB = { collectionData = { [0] = { [0] = collectionScope } }, collectionSerial = 0 }
QFXSkillAlertsNS.CollectionStore = {
    BuildEntryKey = function(classID, specID, index)
        return tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(index)
    end,
    BuildGroupKey = function(classID, specID, groupID)
        return "group:" .. tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(groupID)
    end,
    EntryRefToKey = function(classID, specID, ref)
        local refClassID, refSpecID, refIndex = tostring(ref or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
        refClassID, refSpecID, refIndex = tonumber(refClassID), tonumber(refSpecID), tonumber(refIndex)
        if not refClassID then return nil end
        return tostring(refClassID) .. ":" .. tostring(refSpecID) .. ":" .. tostring(refIndex), refClassID, refSpecID, refIndex
    end,
    GroupRefToKey = function() return nil end,
    EnsureRootDB = function() return QFXSkillAlertsDB end,
    EnsureCollectionScope = function() return collectionScope end,
    NormalizeCollectionScope = function() return false end,
    IsCDMEntryKey = function() return false end,
}
dofile("QFXSkillAlerts_Config/Core/ImportCollectionProcessor.lua")
local collectionOK, collectionCount = QFXSkillAlertsNS.ImportCollectionProcessor:Import({
    type = "collection", classID = 0, specID = 0,
    entries = {
        {
            classID = 0, specID = 0, index = 3, originalKey = "0:0:3",
            entry = {
                entryType = "event", eventKey = "combat_start", spellId = 0,
                voiceEnabled = true, notifyMode = "tts", soundSource = "tts", ttsText = "Mage combat",
                alertClassIDs = { [8] = true }, alertSpecIDs = { [62] = true }, alertRaceIDs = { [0] = true },
            },
        },
        {
            classID = 0, specID = 0, index = 4, originalKey = "0:0:4",
            entry = {
                entryType = "event", eventKey = "combat_start", spellId = 0,
                voiceEnabled = true, notifyMode = "tts", soundSource = "tts", ttsText = "Priest combat",
                alertClassIDs = { [5] = true }, alertSpecIDs = { [256] = true }, alertRaceIDs = { [0] = true },
            },
        },
    },
    group = { name = "Scoped events", entries = { "0:0:3", "0:0:4" } },
})
Assert(collectionOK, "collection import with scoped event voices should succeed")
Equal(collectionCount, 2, "collection import should keep both scoped event entries")
Equal(importMap[1].ttsText, "Warrior combat", "collection import must preserve pre-existing scoped events")
Equal(importMap[2].ttsText, "Updated paladin combat", "collection import must preserve another pre-existing scope")
Equal(importMap[3].ttsText, "Mage combat", "collection import should preserve the first imported scope")
Equal(importMap[4].ttsText, "Priest combat", "collection import should preserve the second imported scope")
local importedGroup = collectionScope.groups.g1
Assert(type(importedGroup) == "table", "collection import should create its group")
Equal(#importedGroup.entries, 2, "collection should retain two distinct event references")
Equal(importedGroup.entries[1], "0:0:3", "first scoped event reference should remain distinct")
Equal(importedGroup.entries[2], "0:0:4", "second scoped event reference should remain distinct")

dofile("QFXSkillAlerts/Ace3/LibStub/LibStub.lua")
dofile("QFXSkillAlerts_Config/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua")
dofile("QFXSkillAlerts_Config/Libs/LibDeflate/LibDeflate.lua")
dofile("QFXSkillAlerts_Config/Core/ImportCodec.lua")
local encoded = QFXSkillAlertsNS.ImportCodec:Encode({
    type = "entry", version = 1,
    entry = { classID = 0, specID = 0, index = 1, entry = sanitized },
})
local decoded, decodeError = QFXSkillAlertsNS.ImportCodec:Decode(encoded)
Assert(type(decoded) == "table", "event export should decode: " .. tostring(decodeError))
Equal(decoded.entry.entry.entryType, "event", "codec must preserve event type")
Equal(decoded.entry.entry.eventKey, "mythic_plus_start", "codec must preserve event key")
Equal(decoded.entry.entry.eventThrottle, 300, "codec must preserve event duplicate guard")

local source = assert(io.open("QFXSkillAlerts/Core/EventVoice.lua", "rb")):read("*a")
Assert(not source:find("C_Timer", 1, true), "event runtime must not create timers")
Assert(not source:find("OnUpdate", 1, true), "event runtime must not install an OnUpdate loop")
Assert(not source:find("NewTicker", 1, true), "event runtime must not create tickers")

print("event voice runtime/import/export tests passed")
