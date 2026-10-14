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
            category = tostring(data.category or ""),
            spellID = tonumber(data.spellID),
            eventKey = tostring(data.eventKey or ""),
            auraUnit = data.auraUnit and tostring(data.auraUnit):lower() or nil,
            voiceName = tostring(data.voiceName or ""),
            voicePath = tostring(data.voicePath or ""),
            enabled = data.enabled ~= false,
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

-- Aura units: tracked bars watch the target, everything else the player.
Equal(Bridge:ResolveRecordAuraUnit({ category = "trackedBar" }), "target",
    "tracked bar records watch the target")
Equal(Bridge:ResolveRecordAuraUnit({ category = "trackedBuff" }), "player",
    "tracked buff records watch the player")
Equal(Bridge:ResolveRecordAuraUnit({ category = "essential" }), "player",
    "cooldown records watch the player")
Equal(Bridge:ResolveRecordAuraUnit({ category = "trackedBar", auraUnit = "focus" }), "focus",
    "an explicit unit wins over the category default")
Equal(Bridge:ResolveRecordAuraUnit({ category = "trackedBuff", auraUnit = "TARGET" }), "target",
    "an explicit unit is normalized")
Equal(Bridge:ResolveRecordAuraUnit(nil), "player", "missing records watch the player")

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
dofile("QFXSkillAlerts/Core/CollectionStore.lua")
local deleteIndex = Bridge:FindEntry(8, 62, 100, "cooldown")
local deleteKey = string.format("0:0:%d", deleteIndex)
QFXSkillAlertsDB.collectionData = { [8] = { [62] = {
    root = {}, groups = { test = { entries = { deleteKey, "0:0:999" } } },
} } }
Assert(Bridge:DeleteRecord(8, 62, 100, "cooldown"), "bridge delete should succeed")
Equal(#QFXSkillAlertsDB.collectionData[8][62].groups.test.entries, 1, "delete clears the real global-storage collection key")
Equal(QFXSkillAlertsDB.collectionData[8][62].groups.test.entries[1], "0:0:999", "delete keeps unrelated collection references")
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

-- A CDM aura saved after migration must register, including the warrior proc
-- from the user report. A regular aura entry overrides the same legacy edge.
QFXSkillAlertsDB.specConfigs = {}
records = { { spellID = 456120, eventKey = "AURA_APPLIED", voiceName = "Proc", voicePath = "proc.ogg" } }
Assert(AuraSounds:Sync(), "post-migration CDM aura should register")
Equal(AuraSounds.registered["aura:player:456120:applied"].path, "proc.ogg", "CDM proc path")

-- CDM aura records without a saved unit register on both the player and the
-- target (Blizzard's CooldownViewer aura tracking scans both units), so enemy
-- debuffs like Garrote and Rupture fire as well. An explicit unit always wins.
records = {
    { spellID = 1943, eventKey = "AURA_APPLIED", category = "trackedBar", voiceName = "Rupture", voicePath = "rupture.ogg" },
    { spellID = 703, eventKey = "AURA_REMOVED", category = "essential", voiceName = "Garrote", voicePath = "garrote.ogg" },
    { spellID = 53, eventKey = "AURA_APPLIED", auraUnit = "focus", voiceName = "Stun", voicePath = "stun.ogg" },
}
Assert(AuraSounds:Sync(), "player and target CDM auras should register")
Equal(AuraSounds.registered["aura:target:1943:applied"].path, "rupture.ogg", "tracked bar debuff registers on the target")
Equal(AuraSounds.registered["aura:player:1943:applied"].path, "rupture.ogg", "tracked bar record also registers on the player")
Equal(AuraSounds.registered["aura:player:703:removed"].path, "garrote.ogg", "player registration for a removed trigger")
Equal(AuraSounds.registered["aura:target:703:removed"].path, "garrote.ogg", "target registration for a removed trigger")
Equal(AuraSounds.registered["aura:focus:53:applied"].path, "stun.ogg", "an explicit unit is kept")
Assert(AuraSounds.registered["aura:player:53:applied"] == nil, "an explicit unit does not double-register")
records = { { spellID = 456120, eventKey = "AURA_APPLIED", voiceName = "Proc", voicePath = "proc.ogg" } }
Assert(AuraSounds:Sync(), "restoring the proc record should re-register it")
Assert(Bridge:SaveAuraRecord(8, 62, 456120, "Proc", "applications", "player", auraVoice))
Assert(AuraSounds:Sync(), "applications should register alongside applied")
Equal(AuraSounds.registered["aura:player:456120:applications"].trigger, 1, "stack increase enum")
local countBeforeZone = #addCalls
Assert(not AuraSounds.eventFrame.events.LOADING_SCREEN_ENABLED, "loading screen must not tear down sounds")
AuraSounds.eventFrame.scripts.OnEvent(nil, "PLAYER_ENTERING_WORLD")
Equal(#addCalls, countBeforeZone, "zone entry should retain accepted registrations")

-- Refused voice edits keep the last working registration and retry on regen.
local old = AuraSounds.registered["aura:player:456120:applications"]
Assert(Bridge:SaveAuraRecord(8, 62, 456120, "Proc", "applications", "player", voiceB))
addResult = false
Assert(not AuraSounds:Sync(), "refused replacement should fail")
Equal(AuraSounds.registered["aura:player:456120:applications"].id, old.id, "working registration retained")
addResult = true
AuraSounds.eventFrame.scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
Equal(AuraSounds.registered["aura:player:456120:applications"].path, "B.ogg", "replacement retried")

-- Combat must not attempt protected registration or forget accepted IDs.
local combatLocked = true
function InCombatLockdown() return combatLocked end
local callsBeforeCombat = #addCalls + #removeCalls
Assert(Bridge:DeleteRecord(8, 62, 100, "ready") == false)
records = {}
Assert(not AuraSounds:Sync(), "combat sync should defer")
Equal(#addCalls + #removeCalls, callsBeforeCombat, "no protected calls during combat")
Assert(AuraSounds.registered["aura:player:456120:applied"], "old IDs retained until safe removal")
combatLocked = false
AuraSounds.eventFrame.scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
Assert(not AuraSounds.registered["aura:player:456120:applied"], "deleted CDM record removed after combat")

-- Global storage must not let another spec overwrite or register this spec's voice.
Assert(Bridge:SaveAuraRecord(8, 63, 456120, "Proc", "applications", "player", voiceA))
Equal(#Bridge:BuildAuraEntries(8, 62), 1, "only the current spec's aura is returned")
Assert(AuraSounds:Sync())
Equal(AuraSounds.registered["aura:player:456120:applications"].path, "B.ogg", "other spec must not overwrite")

-- Pending media or a failed entry write cannot delete the legacy record.
QFXSkillAlertsDB.cdmVoiceSyncState = { alertBridgeMigrationDone = true }
local pendingRecord = { classID = 8, specID = 62, spellID = 900, eventKey = "AVAILABLE", voiceName = "", voicePath = "" }
QFXSkillAlertsDB.cdmVoiceProfiles = { [8] = { [62] = { pending = pendingRecord } } }
Equal(Bridge:MigrateLegacyRecords(), 0, "unresolved record should not migrate")
Assert(QFXSkillAlertsDB.cdmVoiceProfiles[8][62].pending, "unresolved legacy voice retained")
Assert(not QFXSkillAlertsDB.cdmVoiceSyncState.alertBridgeMigrationDone, "unresolved migration should retry")
pendingRecord.voiceName = "Recovered"
pendingRecord.voicePath = "recovered.ogg"
local saveRecord = Bridge.SaveRecord
Bridge.SaveRecord = function() return false, "save_failed" end
Equal(Bridge:MigrateLegacyRecords(), 0, "failed save should not migrate")
Assert(QFXSkillAlertsDB.cdmVoiceProfiles[8][62].pending, "failed save retains old voice")
Bridge.SaveRecord = saveRecord
Equal(Bridge:MigrateLegacyRecords(), 1, "later successful migration should recover")
Assert(not QFXSkillAlertsDB.cdmVoiceProfiles[8][62].pending, "only successful migration removes old voice")

-- A disabled legacy record is also the override that mutes a built-in preset.
-- Migration must leave it disabled and must tolerate malformed old values.
QFXSkillAlertsDB.cdmVoiceSyncState = {}
QFXSkillAlertsDB.cdmVoiceProfiles = { [8] = { [62] = {
    disabled = { spellID = 901, eventKey = "AURA_APPLIED", voiceName = "Muted", voicePath = "muted.ogg", enabled = false },
    malformed = false,
} } }
Equal(Bridge:MigrateLegacyRecords(), 0, "disabled and malformed records do not migrate")
Equal(QFXSkillAlertsDB.cdmVoiceProfiles[8][62].disabled.enabled, false, "disabled preset override retained")
Assert(not Bridge:FindAuraEntry(8, 62, 901, "applied", "player"), "migration must not re-enable a muted aura")

-- Runtime sound lookup works before the load-on-demand settings addon opens.
QFXSkillAlertsNS.AceOptions = nil
dofile("QFXSkillAlerts/Core/MediaCatalog.lua")
QFXSkillAlertsNS.MediaCatalog.FetchSharedMediaSoundPath = function(_, name)
    return name == "Runtime media" and "live.ogg" or ""
end
dofile("QFXSkillAlerts/Core/Notifier.lua")
dofile("QFXSkillAlerts/Core/NotifierBridge.lua")
local entryIndex = Bridge:FindAuraEntry(8, 62, 456120, "applications", "player")
local entry = QFXSkillAlertsDB.specConfigs[0][0][entryIndex]
entry.sharedMediaSound = "Runtime media"
entry.soundPath = "stale.ogg"
Assert(AuraSounds:Sync())
Equal(AuraSounds.registered["aura:player:456120:applications"].path, "live.ogg", "runtime resolves latest SharedMedia path")

-- Reproduce the user's real saved entry: the picker stores the hidden talent
-- ID 444774. The client must receive the triggered buff ID 456120 instead.
local getCurrentClassSpec = QFXSkillAlertsNS.Core.CDMVoiceService.GetCurrentClassSpec
QFXSkillAlertsNS.Core.CDMVoiceService.GetCurrentClassSpec = function() return 1, 71 end
QFXSkillAlertsDB.specConfigs = { [0] = { [0] = { {
    entryType = "aura", spellId = 444774, spellName = "Opportunist", auraTrigger = "applied",
    auraUnit = "player", voiceEnabled = true, notifyMode = "sound", soundSource = "sharedmedia",
    sharedMediaSound = "QFX Alert", soundPath = "proc.ogg",
    alertClassIDs = { true }, alertSpecIDs = { [71] = true }, alertRaceIDs = { [0] = true },
} } } }
records = { { spellID = 444774, eventKey = "AURA_APPLIED", voiceName = "Proc", voicePath = "legacy.ogg" } }
local desired = AuraSounds:BuildDesired()
Assert(desired["aura:player:456120:applied"], "picker talent ID resolves to its actual proc buff")
Assert(not desired["aura:player:444774:applied"], "hidden passive must not be registered")
Equal(desired["aura:player:456120:applied"].sourceSpellID, 444774, "diagnostics retain configured ID")
Equal(desired["aura:player:456120:applied"].path, "proc.ogg", "regular entry overrides legacy alias")
Assert(AuraSounds:Sync())
Equal(AuraSounds.registered["aura:player:456120:applied"].spellID, 456120, "native registration uses buff ID")
local realEntry = QFXSkillAlertsDB.specConfigs[0][0][1]
Equal(realEntry.spellId, 444774, "resolution never rewrites the user's saved ID")
realEntry.auraTrigger = "applications"
Assert(AuraSounds:Sync())
Equal(AuraSounds.registered["aura:player:456120:applications"].trigger, 1, "stack trigger uses buff ID too")

-- Other CDM base/override IDs resolve through static linkedSpellIDs. Explicit
-- linked IDs stay explicit; no live aura reads or Blizzard item hooks occur.
local aliasCategoryReads = 0
C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(category)
        aliasCategoryReads = aliasCategoryReads + 1
        return category == 3 and { 9001 } or {}
    end,
    GetCooldownViewerCooldownInfo = function()
        return { spellID = 9100, overrideSpellID = 9101, linkedSpellIDs = { 9200, 9201, 9200 } }
    end,
}
cdmGeneration = cdmGeneration + 1
local resolved = Native:GetAuraSoundSpellIDs(9100)
Equal(#resolved, 2, "CDM linked aura IDs are deduplicated")
Equal(resolved[1], 9200, "first linked aura")
local readsBeforeCache = aliasCategoryReads
Equal(Native:GetAuraSoundSpellIDs(9101)[2], 9201, "override ID resolves to linked auras")
Equal(aliasCategoryReads, readsBeforeCache, "alias catalog reused across entries")
Equal(#Native:GetAuraSoundSpellIDs(9200), 1, "explicit buff ID keeps its identity")
Equal(Native:GetAuraSoundSpellIDs(9200)[1], 9200, "explicit buff is not expanded")
C_CooldownViewer = nil
cdmGeneration = cdmGeneration + 1
Equal(Native:GetAuraSoundSpellIDs(9100)[1], 9100, "unlisted manual buff ID still works")
Equal(Native:GetAuraSoundSpellIDs(444774)[1], 456120, "known proc resolves without CDM data")
-- Tracked-bar legacy aura records migrate to a target-watching entry so
-- target debuffs (Garrote, Rupture, ...) keep firing after the move.
QFXSkillAlertsDB.cdmVoiceSyncState = {}
QFXSkillAlertsDB.cdmVoiceProfiles = { [8] = { [64] = {
    ["trackedBar:1943:AURA_APPLIED"] = {
        classID = 8,
        specID = 64,
        category = "trackedBar",
        spellID = 1943,
        eventKey = "AURA_APPLIED",
        voiceName = "Rupture",
        voicePath = "rupture.ogg",
    },
} } }
Equal(Bridge:MigrateLegacyRecords(), 1, "tracked bar aura record migrates")
Assert(Bridge:FindAuraEntry(8, 64, 1943, "applied", "target"), "tracked bar aura entry watches the target")
Assert(not Bridge:FindAuraEntry(8, 64, 1943, "applied", "player"), "no player entry for a tracked bar")

QFXSkillAlertsNS.Core.CDMVoiceService.GetCurrentClassSpec = getCurrentClassSpec

print("CDM native events regression tests passed")
