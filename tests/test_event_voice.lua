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
local currentInstanceName, currentInstanceType = "Open World", "none"
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
function GetInstanceInfo() return currentInstanceName, currentInstanceType, 0, 0, 0, 0, false, 0 end

local summonPending = true
local resurrectionByUnit = { player = true }
Enum = { SummonStatus = { Pending = 1, Accepted = 2, Declined = 3 } }
C_IncomingSummon = {
    HasIncomingSummon = function(unit) return unit == "player" end,
    IncomingSummonStatus = function(unit) return unit == "player" and (summonPending and 1 or 2) or 0 end,
}
function UnitHasIncomingResurrection(unit)
    return resurrectionByUnit[unit] == true
end

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
dofile("QFXSkillAlerts/Core/EventContext.lua")
dofile("QFXSkillAlerts/Core/GroupDeathMonitor.lua")
dofile("QFXSkillAlerts/Core/EventVoice.lua")

local EntryMap = QFXSkillAlertsNS.Core.EntryMap
local EventVoice = QFXSkillAlertsNS.Core.EventVoice
local GroupDeathMonitor = QFXSkillAlertsNS.Core.GroupDeathMonitor
local groupDeathMonitorEnabled = false
local originalSetGroupDeathEnabled = GroupDeathMonitor.SetEnabled
GroupDeathMonitor.SetEnabled = function(self, value)
    groupDeathMonitorEnabled = value == true
    return originalSetGroupDeathEnabled(self, value)
end
Assert(EventVoice:NormalizeEventKey("group_member_dead") == "group_member_dead",
    "group-member death should be available without replacing player death")
Assert(EventVoice:NormalizeEventKey("player_dead") == "player_dead",
    "player death should remain available")
local played = {}
local playedPaths = {}
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
        playedPaths[#playedPaths + 1] = cfg.soundPath
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

local encounterUnitStatus = {
    { creatureID = 123, creatureName = "Boss", remainingHealthPercent = 0 },
}
Assert(EventVoice:Dispatch("ENCOUNTER_END", 10, "Boss", 8, 5, 1, encounterUnitStatus), "successful encounter should play")
Equal(played[#played], "encounter_success", "success result should not trigger wipe voice")
Assert(EventVoice:Dispatch("ENCOUNTER_END", 10, "Boss", 8, 5, 0, encounterUnitStatus), "failed encounter should play")
Equal(played[#played], "encounter_wipe", "wipe result should not trigger success voice")
Assert(EventVoice:Dispatch("ENCOUNTER_END", 10, "Boss", 8, 5, 1), "successful encounter without unit status should still play")

globalMap[6] = {
    entryType = "event", eventKey = "role_check_start", eventThrottle = 0,
    voiceEnabled = true, notifyMode = "tts", ttsText = "Choose a role",
    alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
}
globalMap[7] = {
    entryType = "event", eventKey = "incoming_summon", eventThrottle = 0,
    voiceEnabled = true, notifyMode = "tts", ttsText = "Summon",
    alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
}
globalMap[8] = {
    entryType = "event", eventKey = "incoming_resurrection", eventThrottle = 0,
    voiceEnabled = true, notifyMode = "tts", ttsText = "Resurrection",
    alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
}
local _, commonEventCount = EventVoice:Rebuild()
Equal(commonEventCount, 6, "three filtered common events should join the active event set")
Assert(frame.registered.LFG_ROLE_CHECK_SHOW, "role-check start should register its event")
Assert(frame.registered.INCOMING_SUMMON_CHANGED, "incoming summon should register its event")
Assert(frame.registered.INCOMING_RESURRECT_CHANGED, "incoming resurrection should register its event")
Assert(EventVoice:Dispatch("LFG_ROLE_CHECK_SHOW"), "role-check start should play")
Assert(EventVoice:Dispatch("INCOMING_SUMMON_CHANGED"), "a pending player summon should play")
summonPending = false
Assert(not EventVoice:Dispatch("INCOMING_SUMMON_CHANGED"), "accepted summon state must not replay")
Assert(not EventVoice:Dispatch("INCOMING_RESURRECT_CHANGED", "party1"), "another unit's resurrection must not play")
Assert(EventVoice:Dispatch("INCOMING_RESURRECT_CHANGED", "player"), "the player's incoming resurrection should play")
resurrectionByUnit.player = false
Assert(not EventVoice:Dispatch("INCOMING_RESURRECT_CHANGED", "player"), "resurrection stop edge must not replay")

globalMap[6], globalMap[7], globalMap[8] = nil, nil, nil
summonPending = true
resurrectionByUnit.player = true

globalMap[1].eventLoadContexts = { world = true }
globalMap[1].eventThrottle = 0
globalMap[5] = {
    entryType = "event", eventKey = "combat_start", eventThrottle = 0,
    voiceEnabled = true, notifyMode = "sound", soundPath = "dungeon.ogg",
    eventLoadContexts = { dungeon = true },
    alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
}
now = 200
local _, multiConditionCount = EventVoice:Rebuild()
Equal(multiConditionCount, 4, "same event with disjoint load conditions should keep both runtime configs")
Assert(EventVoice:Dispatch("PLAYER_REGEN_DISABLED"), "world event config should play in the world")
Equal(playedPaths[#playedPaths], "combat.ogg", "world should use the world-specific event config")
currentInstanceName, currentInstanceType = "Test Dungeon", "party"
Assert(EventVoice:Dispatch("PLAYER_REGEN_DISABLED"), "dungeon event config should play in a dungeon")
Equal(playedPaths[#playedPaths], "dungeon.ogg", "dungeon should use the dungeon-specific event config")

globalMap = {
    [1] = {
        entryType = "event", eventKey = "group_member_dead", eventThrottle = 1,
        voiceEnabled = true, notifyMode = "tts", ttsText = "Group member died",
        alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
}
local _, groupDeathCount = EventVoice:Rebuild()
Equal(groupDeathCount, 1, "group-member death should build as an event voice")
Assert(groupDeathMonitorEnabled,
    "an active group-member death entry should enable its dedicated monitor")
Assert(not frame.registered.QFXSA_GROUP_MEMBER_DEAD,
    "the internal group-death signal must not be registered as a Blizzard event")

globalMap = {}
local _, emptyCount = EventVoice:Rebuild()
Equal(emptyCount, 0, "empty rebuild should clear active event voices")
Assert(next(frame.registered) == nil, "empty rebuild should unregister every event")
Assert(not groupDeathMonitorEnabled,
    "removing the group-member death entry should disable its monitor")

local eventEntry = { entryType = "event", eventKey = "combat_start", spellId = 0 }
Assert(EntryMap:GetEntry({ [1] = eventEntry }, 1) == eventEntry, "event entries must remain valid without a spell ID")
Equal(EntryMap:FindFirstFreeIndex({ [1] = eventEntry }), 2, "event entries must occupy saved-list indices")

QFXSkillAlertsNS.API = {
    NormalizeEventVoiceKey = function(value) return EventVoice:NormalizeEventKey(value) end,
    GetModes = function() return "tts", "sound" end,
    ResolveObjectType = function() return "spell" end,
    NormalizeEventLoadContexts = function(value)
        if type(value) ~= "table" then return { world = true, delve = true, dungeon = true, raid = true } end
        return { world = value.world == true, delve = value.delve == true, dungeon = value.dungeon == true, raid = value.raid == true }
    end,
    NormalizeEventInstanceMode = function(value)
        return (value == "season" or value == "specific") and value or "any"
    end,
    NormalizeEventInstanceSelections = function(value)
        local result = {}
        for key, selected in pairs(type(value) == "table" and value or {}) do
            if selected == true then result[tostring(key)] = true end
        end
        return result
    end,
    NormalizeEventInstanceSelectionNames = function(value)
        local result = {}
        for key, name in pairs(type(value) == "table" and value or {}) do result[tostring(key)] = tostring(name) end
        return result
    end,
    BuildEventLoadConditionSignature = function(entry)
        return QFXSkillAlertsNS.Core.EventContext:BuildLoadConditionSignature(entry)
    end,
    EventLoadConditionsOverlap = function(left, right)
        return QFXSkillAlertsNS.Core.EventContext:LoadConditionsOverlap(left, right)
    end,
}
QFXSkillAlertsNS.Utils = {
    TrimText = function(value) return tostring(value or ""):match("^%s*(.-)%s*$") end,
}
dofile("QFXSkillAlerts/Core/ImportExportUtil.lua")
local sanitized = QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({
    entryType = "event",
    eventKey = "mythic_plus_start",
    eventThrottle = 999,
    eventLoadContexts = { dungeon = true, raid = true },
    eventDungeonMode = "season",
    eventRaidMode = "any",
    eventDungeonSelectionIDs = { [101] = true, [202] = true },
    eventDungeonSelectionNames = { [101] = "Ruby Life Pools", [202] = "The Stonevault" },
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
Assert(sanitized.eventLoadContexts.dungeon and sanitized.eventLoadContexts.raid and not sanitized.eventLoadContexts.world,
    "event load locations must survive import sanitization")
Equal(sanitized.eventDungeonMode, "season", "event dungeon season mode must survive import sanitization")
Equal(sanitized.eventRaidMode, "any", "event raid any mode must survive import sanitization")
Assert(sanitized.eventDungeonSelectionIDs["101"] and sanitized.eventDungeonSelectionIDs["202"],
    "specific dungeon selections must survive import sanitization")
Equal(sanitized.eventDungeonSelectionNames["101"], "Ruby Life Pools",
    "specific dungeon fallback names must survive import sanitization")
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

local conditionedBase = {
    classID = 0, specID = 0,
    entry = {
        entryType = "event", eventKey = "ready_check", spellId = 0,
        voiceEnabled = true, notifyMode = "tts", soundSource = "tts", ttsText = "Conditioned ready",
        alertClassIDs = { [8] = true }, alertSpecIDs = { [62] = true }, alertRaceIDs = { [0] = true },
        eventLoadContexts = { world = true },
    },
}
local worldConditionKey, worldConditionIndex = ImportEntryProcessor:ImportEntryRecord(conditionedBase, false)
Equal(worldConditionIndex, 5, "first conditioned event should use the next free index")
conditionedBase.entry.eventLoadContexts = { dungeon = true }
conditionedBase.entry.ttsText = "Dungeon ready"
local dungeonConditionKey, dungeonConditionIndex = ImportEntryProcessor:ImportEntryRecord(conditionedBase, false)
Equal(dungeonConditionIndex, 6, "same event and scope with a disjoint location should import separately")
Assert(worldConditionKey ~= dungeonConditionKey, "disjoint event load conditions need distinct saved keys")
conditionedBase.entry.eventLoadContexts = { world = true }
conditionedBase.entry.ttsText = "Updated world ready"
local replacedConditionKey, replacedConditionIndex = ImportEntryProcessor:ImportEntryRecord(conditionedBase, false)
Equal(replacedConditionIndex, 5, "same event, scope, and load condition should replace its exact match")
Equal(replacedConditionKey, worldConditionKey, "exact conditioned import replacement should keep its key")
Equal(importMap[5].ttsText, "Updated world ready", "world-conditioned import should update independently")
Equal(importMap[6].ttsText, "Dungeon ready", "dungeon-conditioned import should remain untouched")
conditionedBase.entry.eventLoadContexts = { world = true, dungeon = true }
conditionedBase.entry.ttsText = "Overlapping ready"
local overlappingConditionKey = ImportEntryProcessor:ImportEntryRecord(conditionedBase, false)
Assert(overlappingConditionKey == nil, "an imported event condition that overlaps saved variants must be rejected")
Equal(importMap[5].ttsText, "Updated world ready", "rejected overlap must not replace the world variant")
Equal(importMap[6].ttsText, "Dungeon ready", "rejected overlap must not replace the dungeon variant")

dofile("QFXSkillAlerts/Core/DeletedEntryStore.lua")
local deletedStore = QFXSkillAlertsNS.Core.DeletedEntryStore
local deletedDB = {}
local deletedWorld = {
    entryType = "event", eventKey = "combat_start", eventLoadContexts = { world = true },
}
local deletedDungeon = {
    entryType = "event", eventKey = "combat_start", eventLoadContexts = { dungeon = true },
}
Assert(deletedStore:Mark(deletedDB, 0, 0, deletedWorld, 50), "event deletion marker should be created")
Assert(deletedStore:IsMarked(deletedDB, 0, 0, deletedWorld, 51),
    "event deletion signature should follow the same load-condition variant")
Assert(not deletedStore:IsMarked(deletedDB, 0, 0, deletedDungeon, 52),
    "deleting one event load-condition variant must not delete another")
Assert(deletedStore:Clear(deletedDB, 0, 0, deletedWorld, 50), "event deletion marker should clear")
deletedDB.deletedEntries.signatures["0:0:event:combat_start"] = true
Assert(deletedStore:IsMarked(deletedDB, 0, 0, deletedDungeon, 52),
    "legacy broad event deletion markers should remain compatible")
Assert(deletedStore:Clear(deletedDB, 0, 0, deletedDungeon, 52),
    "clearing a legacy event deletion marker should migrate it away")
Assert(not deletedStore:IsMarked(deletedDB, 0, 0, deletedWorld, 53),
    "cleared legacy deletion marker must no longer affect event variants")

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
Assert(decoded.entry.entry.eventLoadContexts.dungeon and decoded.entry.entry.eventLoadContexts.raid,
    "codec must preserve event load locations")
Equal(decoded.entry.entry.eventDungeonMode, "season", "codec must preserve dungeon season mode")
Assert(decoded.entry.entry.eventDungeonSelectionIDs["101"] and decoded.entry.entry.eventDungeonSelectionIDs["202"],
    "codec must preserve multiple specific dungeon selections")

local source = assert(io.open("QFXSkillAlerts/Core/EventVoice.lua", "rb")):read("*a")
Assert(not source:find("C_Timer", 1, true), "event runtime must not create timers")
Assert(not source:find("OnUpdate", 1, true), "event runtime must not install an OnUpdate loop")
Assert(not source:find("NewTicker", 1, true), "event runtime must not create tickers")

print("event voice runtime/import/export tests passed")
