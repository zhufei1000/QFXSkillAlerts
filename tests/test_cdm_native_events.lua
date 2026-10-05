local function Fail(message)
    error(message, 2)
end

local function Assert(value, message)
    if not value then
        Fail(message or "assertion failed")
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        Fail(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
    end
end

local addCalls, removeCalls = {}, {}
local nextSoundID = 1
local addResult = true
C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        addCalls[#addCalls + 1] = { trigger = trigger, info = info }
        if not addResult then
            return nil
        end
        local id = nextSoundID
        nextSoundID = nextSoundID + 1
        return id
    end,
    RemoveAuraSound = function(id)
        removeCalls[#removeCalls + 1] = id
    end,
}

C_Spell = {
    GetSpellName = function(spellID) return "Spell " .. tostring(spellID) end,
}

Enum = {
    UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 },
}

function CreateFrame()
    local frame = {
        scripts = {},
        events = {},
    }
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:RegisterEvent(name) self.events[name] = true end
    function frame:UnregisterEvent(name) self.events[name] = nil end
    return frame
end

function issecretvalue()
    return false
end

QFXSkillAlertsDB = {
    specConfigs = {},
    cdmVoiceProfiles = {},
    cdmVoiceSyncState = {},
}

QFXSkillAlertsNS = {
    Core = {},
    L = function(key, ...)
        local count = select("#", ...)
        if count > 0 then
            return tostring(key) .. ":" .. tostring((...))
        end
        return tostring(key)
    end,
}

local records = {}
QFXSkillAlertsNS.Core.CDMVoiceService = {
    GetCurrentClassSpec = function()
        return 8, 62
    end,
}
QFXSkillAlertsNS.Core.CDMVoicePresetStore = {
    GetEffectiveRecords = function()
        return records
    end,
    ResolveVoice = function(_, record)
        if type(record) ~= "table" then
            return nil
        end
        local name = record.voiceName
        local path = record.voicePath
        if type(name) ~= "string" or name == "" then
            return nil
        end
        return { name = name, path = path or "", identity = "lsm:" .. name, payload = -1000 - #name }
    end,
    SanitizeRecord = function(_, data)
        if type(data) ~= "table" or not tonumber(data.spellID) then
            return nil
        end
        return {
            classID = tonumber(data.classID),
            specID = tonumber(data.specID),
            spellID = tonumber(data.spellID),
            eventKey = tostring(data.eventKey or ""),
            voiceName = tostring(data.voiceName or ""),
            voicePath = tostring(data.voicePath or ""),
        }
    end,
}

dofile("QFXSkillAlerts/Core/EntryMap.lua")
dofile("QFXSkillAlerts/Core/CDMNativeEvents.lua")
dofile("QFXSkillAlerts/Core/CDMAlertBridge.lua")
dofile("QFXSkillAlerts/Core/CDMNativeAuraSounds.lua")

local Native = QFXSkillAlertsNS.Core.CDMNativeEvents
local Bridge = QFXSkillAlertsNS.Core.CDMAlertBridge
local AuraSounds = QFXSkillAlertsNS.Core.CDMNativeAuraSounds
local EntryMap = QFXSkillAlertsNS.Core.EntryMap

-- Event classification.
Assert(Native:IsNativeEventKey("AVAILABLE"), "AVAILABLE should be native")
Assert(Native:IsNativeEventKey("ON_COOLDOWN"), "ON_COOLDOWN should be native")
Assert(Native:IsNativeEventKey("AURA_APPLIED"), "AURA_APPLIED should be native")
Assert(Native:IsNativeEventKey("AURA_REMOVED"), "AURA_REMOVED should be native")
Assert(not Native:IsNativeEventKey("CHARGE_GAINED"), "CHARGE_GAINED should stay on the CDM path")
Assert(not Native:IsNativeEventKey("PANDEMIC_TIME"), "PANDEMIC_TIME should stay on the CDM path")

-- Bridge event mapping.
Equal(Bridge:GetModeForEventKey("AVAILABLE"), "ready", "AVAILABLE maps to ready")
Equal(Bridge:GetModeForEventKey("ON_COOLDOWN"), "cooldown", "ON_COOLDOWN maps to cooldown")
Equal(Bridge:GetEventKeyForMode("ready"), "AVAILABLE", "ready maps back to AVAILABLE")
Equal(Bridge:GetEventKeyForMode("cooldown"), "ON_COOLDOWN", "cooldown maps back to ON_COOLDOWN")

-- Bridge save / update / lookup.
local voiceA = { name = "Voice A", path = "A.ogg" }
local voiceB = { name = "Voice B", path = "B.ogg" }
local ok, index = Bridge:SaveRecord(8, 62, 100, "Spell 100", "ready", voiceA)
Assert(ok, "bridge save should succeed")
Assert(index and index > 0, "bridge save should return an entry index")

local foundIndex, foundEntry = Bridge:FindEntry(8, 62, 100, "ready")
Equal(foundIndex, index, "saved entry should be found")
Equal(foundEntry.cdMode, "ready", "entry should keep the ready mode")
Equal(foundEntry.gameStateCD, true, "entry should use game-state cooldowns")
Equal(foundEntry.sharedMediaSound, "Voice A", "entry should keep the shared media name")
Equal(foundEntry.soundPath, "A.ogg", "entry should keep the sound path")

-- Same spell, different mode -> a second entry (allowed after the duplicate
-- check change in the cooldown alert editor).
Assert(Bridge:SaveRecord(8, 62, 100, "Spell 100", "cooldown", voiceB), "cooldown save should succeed")
local readyIndex = Bridge:FindEntry(8, 62, 100, "ready")
local cooldownIndex = Bridge:FindEntry(8, 62, 100, "cooldown")
Assert(readyIndex ~= cooldownIndex, "ready and cooldown should be separate entries")

-- Saving the same spell and mode updates the entry instead of adding one.
Assert(Bridge:SaveRecord(8, 62, 100, "Spell 100", "ready", voiceB), "repeat save should succeed")
Equal(Bridge:FindEntry(8, 62, 100, "ready"), readyIndex, "repeat save should reuse the entry")
Equal(EntryMap:GetUsedEntryCount(QFXSkillAlertsDB.specConfigs[0][0]), 2, "bridge should not add duplicate entries")

-- Virtual records for the editor list.
local virtual = Bridge:BuildVirtualRecords(8, 62)
Equal(#virtual, 2, "two virtual records expected")
local byEvent = {}
for _, item in ipairs(virtual) do
    byEvent[item.eventKey] = item
end
Assert(byEvent.AVAILABLE, "ready virtual record expected")
Assert(byEvent.ON_COOLDOWN, "cooldown virtual record expected")
Equal(byEvent.AVAILABLE.voiceName, "Voice B", "virtual record should carry the current voice")

-- Delete removes the bridged entry.
Assert(Bridge:DeleteRecord(8, 62, 100, "cooldown"), "bridge delete should succeed")
Assert(Bridge:FindEntry(8, 62, 100, "cooldown") == nil, "deleted entry should be gone")
Equal(#Bridge:BuildVirtualRecords(8, 62), 1, "only the ready record should remain")

-- Migration moves legacy ready/cooldown/aura records out of cdmVoiceProfiles.
QFXSkillAlertsDB.cdmVoiceProfiles = {
    [8] = {
        [62] = {
            ["essential:200:AVAILABLE"] = {
                classID = 8,
                specID = 62,
                spellID = 200,
                eventKey = "AVAILABLE",
                voiceName = "Voice A",
                voicePath = "A.ogg",
            },
            ["essential:400:AURA_APPLIED"] = {
                classID = 8,
                specID = 62,
                spellID = 400,
                eventKey = "AURA_APPLIED",
                voiceName = "Voice B",
                voicePath = "B.ogg",
            },
            ["essential:300:CHARGE_GAINED"] = {
                classID = 8,
                specID = 62,
                spellID = 300,
                eventKey = "CHARGE_GAINED",
                voiceName = "Voice B",
                voicePath = "B.ogg",
            },
        },
    },
}
local migrated = Bridge:MigrateLegacyRecords()
Equal(migrated, 2, "ready and aura records should migrate")
Assert(Bridge:FindEntry(8, 62, 200, "ready"), "migrated ready entry should exist")
Assert(Bridge:FindAuraEntry(8, 62, 400, "applied", "player"), "migrated aura entry should exist")
Assert(QFXSkillAlertsDB.cdmVoiceProfiles[8][62]["essential:200:AVAILABLE"] == nil,
    "legacy ready record should be removed")
Assert(QFXSkillAlertsDB.cdmVoiceProfiles[8][62]["essential:400:AURA_APPLIED"] == nil,
    "legacy aura record should be removed")
Assert(QFXSkillAlertsDB.cdmVoiceProfiles[8][62]["essential:300:CHARGE_GAINED"] ~= nil,
    "charge records must stay on the CDM path")
Equal(Bridge:MigrateLegacyRecords(), 0, "migration should only run once")

-- Aura registrations come from the aura entries saved by the alert editor.
-- The migration above already created an aura entry for spell 400, so these
-- checks use spells 500 / 501.
local function FindAddCall(spellID)
    for _, call in ipairs(addCalls) do
        if call.info.spellID == spellID then
            return call
        end
    end
    return nil
end

local auraVoice = { name = "Aura Voice", path = "E.ogg" }
Assert(Bridge:SaveAuraRecord(8, 62, 500, "Spell 500", "applied", "player", auraVoice), "aura save should succeed")
AuraSounds:Sync()
local appliedCall = FindAddCall(500)
Assert(appliedCall, "aura entry should register")
Equal(appliedCall.trigger, 0, "applied should use the Added trigger")
Equal(appliedCall.info.soundFileName, "E.ogg", "registration should use the entry path")
Equal(appliedCall.info.unitToken, "player", "registration should use the player unit")

local addCountAfterFirstSync = #addCalls
AuraSounds:Sync()
Equal(#addCalls, addCountAfterFirstSync, "a second sync should not re-register")

-- A removed trigger uses the Removed enum value.
Assert(Bridge:SaveAuraRecord(8, 62, 501, "Spell 501", "removed", "player", auraVoice), "removed aura save should succeed")
AuraSounds:Sync()
local removedCall = FindAddCall(501)
Assert(removedCall, "removed aura entry should register")
Equal(removedCall.trigger, 2, "removed should use the Removed trigger")

-- Removing the entry unregisters the sound.
local removeCountBefore = #removeCalls
local removedIndex = Bridge:FindAuraEntry(8, 62, 500, "applied", "player")
Assert(removedIndex, "aura entry should exist before removal")
QFXSkillAlertsDB.specConfigs[0][0][removedIndex] = nil
AuraSounds:Sync()
Equal(#removeCalls, removeCountBefore + 1, "removing the entry should unregister the sound")
Assert(AuraSounds.registered["aura:player:500:applied"] == nil, "removed entry should not stay active")

-- A failed registration is retried and not cached.
Assert(Bridge:SaveAuraRecord(8, 62, 500, "Spell 500", "applied", "player", auraVoice), "aura re-save should succeed")
addResult = false
local syncOK, reason = AuraSounds:Sync()
Assert(not syncOK, "restricted registration should report failure")
Equal(reason, "restricted", "failure reason should be restricted")
Assert(AuraSounds.registered["aura:player:500:applied"] == nil, "failed registration must not be cached")

addResult = true
Assert(AuraSounds:Sync(), "retry after the restriction should succeed")
Assert(AuraSounds.registered["aura:player:500:applied"] ~= nil, "successful retry should be cached")

-- Availability filtering: ready records whose spell is missing from the
-- current CDM data are not loaded.
local cdmGeneration = 1
QFXSkillAlertsNS.Core.CDMVoiceService.GetCooldownCacheGeneration = function()
    return cdmGeneration
end
Enum.CooldownViewerCategory = { Essential = 1, Utility = 2, TrackedBuff = 3, TrackedBar = 4 }
C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(category)
        if category == 1 then
            return { 1001 }
        end
        return {}
    end,
    GetCooldownViewerCooldownInfo = function(cooldownID)
        if cooldownID == 1001 then
            return { spellID = 100 }
        end
        return nil
    end,
}
cdmGeneration = cdmGeneration + 1
Assert(Native:IsRecordAvailable({ spellID = 100 }), "available spell should pass the check")
Assert(not Native:IsRecordAvailable({ spellID = 400 }), "missing spell should fail the check")

-- When the CDM data cannot be read at all the check fails open.
C_CooldownViewer = nil
cdmGeneration = cdmGeneration + 1
Assert(Native:IsRecordAvailable({ spellID = 400 }), "unreadable CDM data should fail open")

print("CDM native events regression tests passed")
