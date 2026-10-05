local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMAlertBridge = NS.Core.CDMAlertBridge or {}

local Bridge = NS.Core.CDMAlertBridge

-- The Cooldown Manager voice editor's ready / on-cooldown events are stored as
-- regular cooldown alert entries (cdMode = "ready" / "cooldown") so both
-- editors share one record and the main runtime plays them. Aura, charge and
-- pandemic events keep their own paths.
local EVENT_TO_MODE = { AVAILABLE = "ready", ON_COOLDOWN = "cooldown" }
local MODE_TO_EVENT = { ready = "AVAILABLE", cooldown = "ON_COOLDOWN" }

local function GetEntryMap()
    return NS.Core and NS.Core.EntryMap
end

local function GetCollectionStore()
    return NS.Core and NS.Core.CollectionStore
end

local function NormalizeCdMode(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local mode = tostring(entry.cdMode or ""):lower()
    if mode == "ready" or mode == "cooldown" then
        return mode
    end
    return nil
end

local AURA_TRIGGERS = { applied = true, removed = true, applications = true }

local function NormalizeAuraTrigger(value)
    value = tostring(value or ""):lower()
    if AURA_TRIGGERS[value] then
        return value
    end
    return nil
end

local AURA_UNITS = { player = true, target = true, focus = true }

local function NormalizeAuraUnit(value)
    value = tostring(value or ""):lower()
    if AURA_UNITS[value] then
        return value
    end
    return "player"
end

local function ResolveSpellName(spellID)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return ""
end

function Bridge:GetModeForEventKey(eventKey)
    return EVENT_TO_MODE[tostring(eventKey or ""):upper()]
end

function Bridge:GetEventKeyForMode(cdMode)
    return MODE_TO_EVENT[tostring(cdMode or ""):lower()]
end

local EVENT_TO_AURA_TRIGGER = { AURA_APPLIED = "applied", AURA_REMOVED = "removed" }

function Bridge:GetAuraTriggerForEventKey(eventKey)
    return EVENT_TO_AURA_TRIGGER[tostring(eventKey or ""):upper()]
end

-- All saved alert entries live in the global storage scope ([0][0]); the
-- class / spec applicability is carried by alertClassIDs / alertSpecIDs. The
-- classID / specID arguments are kept for scoping the saved entry itself.
local function GetSpecMap(classID, specID, create)
    local entryMap = GetEntryMap()
    local db = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or nil
    local root = db and db.specConfigs
    if not entryMap or type(root) ~= "table" then
        return nil
    end
    if create then
        return entryMap:EnsureSpecTable(root, 0, 0)
    end
    return entryMap:GetSpecTable(root, 0, 0)
end

function Bridge:FindEntry(classID, specID, spellID, cdMode)
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, false)
    if not entryMap or not map then
        return nil, nil
    end
    spellID = tonumber(spellID)
    if not spellID then
        return nil, nil
    end
    for _, index in ipairs(entryMap:GetOrderedEntryIndices(map)) do
        local entry = entryMap:GetEntry(map, index)
        if entry
            and tostring(entry.entryType or "cooldown") == "cooldown"
            and tonumber(entry.spellId) == spellID
            and NormalizeCdMode(entry) == cdMode then
            return index, entry
        end
    end
    return nil, nil
end

-- Defaults mirror the fields written by the cooldown alert editor so the
-- entry is fully valid for the runtime and the editor.
local function BuildEntry(classID, specID, spellID, spellName, cdMode, voiceItem)
    local entry = {
        entryType = "cooldown",
        objectType = "spell",
        spellId = spellID,
        spellName = tostring(spellName or ""),
        baseCD = 0,
        fixedCD = true,
        cdMode = cdMode,
        gameStateCD = true,
        chargeInput = 1,
        notifyMode = "sound",
        ttsText = "",
        ttsRate = 0,
        delayEnabled = false,
        delaySeconds = 0,
        castDelayMode = "show",
        cooldownAlertTime = 0,
        soundPath = tostring(voiceItem.path or ""),
        soundSource = "sharedmedia",
        builtinSoundPath = "",
        customSoundPath = "",
        sharedMediaSound = tostring(voiceItem.name or ""),
        voiceEnabled = true,
        voiceConditionOp = "<=",
        voiceConditionTime = 0,
        imageEnabled = false,
        imageConditionOp = "<=",
        imageConditionTime = 0,
        imageSource = "auto",
        imageIconID = 0,
        imagePath = "",
        imageSize = 96,
        imageDurationEnabled = false,
        imageDuration = 2,
        imageX = 0,
        imageY = 120,
        textEnabled = false,
        textCooldownCountdown = false,
        textConditionOp = "<=",
        textConditionTime = 0,
        textAlert = "",
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
        checkTalent = false,
        talentId = 0,
        talentName = "",
        talentCD = 0,
        talentLoadFilter = false,
        loadTalentEnabled = false,
        loadTalentId = 0,
        loadTalentName = "",
    }
    -- Scope the entry to the class / spec it was configured for.
    entry.alertClassIDs = classID and { [classID] = true } or nil
    entry.alertSpecIDs = specID and { [specID] = true } or nil
    return entry
end

-- Creates or updates the cooldown alert entry for a Cooldown Manager editor
-- record. Returns true plus the entry index, or false plus a reason.
function Bridge:SaveRecord(classID, specID, spellID, spellName, cdMode, voiceItem)
    classID = tonumber(classID)
    specID = tonumber(specID)
    spellID = tonumber(spellID)
    if not classID or not specID or not spellID or not cdMode then
        return false, "invalid_record"
    end
    if type(voiceItem) ~= "table" or tostring(voiceItem.name or "") == "" then
        return false, "invalid_payload"
    end
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, true)
    if not entryMap or not map then
        return false, "data_not_ready"
    end
    local index = self:FindEntry(classID, specID, spellID, cdMode)
    if not index then
        index = entryMap:FindFirstFreeIndex(map)
    end
    if not index or index <= 0 then
        return false, "save_failed"
    end
    map[index] = BuildEntry(classID, specID, spellID, spellName, cdMode, voiceItem)
    return true, index
end

function Bridge:DeleteRecord(classID, specID, spellID, cdMode)
    classID = tonumber(classID)
    specID = tonumber(specID)
    spellID = tonumber(spellID)
    if not classID or not specID or not spellID or not cdMode then
        return false, "invalid_record"
    end
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, false)
    if not entryMap or not map then
        return false, "not_found"
    end
    local index = self:FindEntry(classID, specID, spellID, cdMode)
    if not index then
        return false, "not_found"
    end
    map[index] = nil
    local collectionStore = GetCollectionStore()
    if collectionStore
        and type(collectionStore.BuildEntryKey) == "function"
        and type(collectionStore.RemoveEntryKeyFromAllCollectionScopes) == "function" then
        local entryKey = collectionStore.BuildEntryKey(classID, specID, index)
        pcall(collectionStore.RemoveEntryKeyFromAllCollectionScopes, entryKey)
    end
    return true
end

function Bridge:FindAuraEntry(classID, specID, spellID, trigger, unit)
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, false)
    if not entryMap or not map then
        return nil, nil
    end
    spellID = tonumber(spellID)
    if not spellID then
        return nil, nil
    end
    unit = NormalizeAuraUnit(unit)
    for _, index in ipairs(entryMap:GetOrderedEntryIndices(map)) do
        local entry = entryMap:GetEntry(map, index)
        if entry
            and tostring(entry.entryType or "cooldown") == "aura"
            and tonumber(entry.spellId) == spellID
            and NormalizeAuraTrigger(entry.auraTrigger) == trigger
            and NormalizeAuraUnit(entry.auraUnit) == unit then
            return index, entry
        end
    end
    return nil, nil
end

-- Creates or updates an aura alert entry. Aura entries are voice-only: the
-- client plays them through AddAuraSound.
function Bridge:SaveAuraRecord(classID, specID, spellID, spellName, trigger, unit, voiceItem)
    classID = tonumber(classID)
    specID = tonumber(specID)
    spellID = tonumber(spellID)
    trigger = NormalizeAuraTrigger(trigger)
    unit = NormalizeAuraUnit(unit)
    if not classID or not specID or not spellID or not trigger then
        return false, "invalid_record"
    end
    if type(voiceItem) ~= "table" or tostring(voiceItem.name or "") == "" then
        return false, "invalid_payload"
    end
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, true)
    if not entryMap or not map then
        return false, "data_not_ready"
    end
    local index = self:FindAuraEntry(classID, specID, spellID, trigger, unit)
    if not index then
        index = entryMap:FindFirstFreeIndex(map)
    end
    if not index or index <= 0 then
        return false, "save_failed"
    end
    local entry = BuildEntry(classID, specID, spellID, spellName, "ready", voiceItem)
    entry.entryType = "aura"
    entry.auraTrigger = trigger
    entry.auraUnit = unit
    entry.cdMode = "fixed"
    entry.gameStateCD = false
    map[index] = entry
    return true, index
end

-- Aura alert entries for the current spec: registered with the client through
-- AddAuraSound by CDMNativeAuraSounds.
function Bridge:BuildAuraEntries(classID, specID)
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, false)
    local result = {}
    if not entryMap or not map then
        return result
    end
    for _, index in ipairs(entryMap:GetOrderedEntryIndices(map)) do
        local entry = entryMap:GetEntry(map, index)
        if entry and tostring(entry.entryType or "cooldown") == "aura" then
            local spellID = tonumber(entry.spellId)
            local trigger = NormalizeAuraTrigger(entry.auraTrigger)
            local unit = NormalizeAuraUnit(entry.auraUnit)
            if spellID and trigger then
                result[#result + 1] = {
                    classID = tonumber(classID),
                    specID = tonumber(specID),
                    spellID = spellID,
                    trigger = trigger,
                    auraUnit = unit,
                    entryIndex = index,
                    recordKey = string.format("aura:%s:%d:%s", unit, spellID, trigger),
                    voiceName = tostring(entry.sharedMediaSound or ""),
                    voicePath = tostring(entry.soundPath or entry.customSoundPath or ""),
                }
            end
        end
    end
    return result
end

-- Virtual records for the Cooldown Manager editor list: one per bridged
-- ready / cooldown entry of the current spec.
function Bridge:BuildVirtualRecords(classID, specID)
    local entryMap = GetEntryMap()
    local map = GetSpecMap(classID, specID, false)
    local result = {}
    if not entryMap or not map then
        return result
    end
    for _, index in ipairs(entryMap:GetOrderedEntryIndices(map)) do
        local entry = entryMap:GetEntry(map, index)
        if entry and tostring(entry.entryType or "cooldown") == "cooldown" then
            local cdMode = NormalizeCdMode(entry)
            local eventKey = cdMode and self:GetEventKeyForMode(cdMode)
            local spellID = tonumber(entry.spellId)
            if eventKey and spellID then
                result[#result + 1] = {
                    classID = tonumber(classID),
                    specID = tonumber(specID),
                    spellID = spellID,
                    eventKey = eventKey,
                    cdMode = cdMode,
                    entryIndex = index,
                    voiceName = tostring(entry.sharedMediaSound or ""),
                    voicePath = tostring(entry.soundPath or entry.customSoundPath or ""),
                    source = "cdAlert",
                }
            end
        end
    end
    return result
end

-- One-time migration: ready / cooldown records saved by earlier versions in
-- cdmVoiceProfiles are moved into the cooldown alert entries.
function Bridge:MigrateLegacyRecords()
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if not store then
        return 0
    end
    local db = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or {}
    QFXSkillAlertsDB = db
    local state = type(db.cdmVoiceSyncState) == "table" and db.cdmVoiceSyncState or {}
    db.cdmVoiceSyncState = state
    if state.alertBridgeMigrationDone == true then
        return 0
    end

    local migrated = 0
    local profiles = type(db.cdmVoiceProfiles) == "table" and db.cdmVoiceProfiles or {}
    for classIDKey, classMap in pairs(profiles) do
        local classID = tonumber(classIDKey)
        if classID and type(classMap) == "table" then
            for specIDKey, specMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and type(specMap) == "table" then
                    local removeKeys = {}
                    for recordKey, data in pairs(specMap) do
                        local record = store:SanitizeRecord(data, data.source or "user")
                        if record then
                            local cdMode = self:GetModeForEventKey(record.eventKey)
                            local auraTrigger = self:GetAuraTriggerForEventKey(record.eventKey)
                            if cdMode or auraTrigger then
                                local voiceItem = store:ResolveVoice(record)
                                local spellID = tonumber(record.spellID)
                                if voiceItem and spellID then
                                    local ok
                                    if cdMode then
                                        ok = self:SaveRecord(
                                            record.classID or classID,
                                            record.specID or specID,
                                            spellID,
                                            ResolveSpellName(spellID),
                                            cdMode,
                                            voiceItem
                                        )
                                    else
                                        ok = self:SaveAuraRecord(
                                            record.classID or classID,
                                            record.specID or specID,
                                            spellID,
                                            ResolveSpellName(spellID),
                                            auraTrigger,
                                            "player",
                                            voiceItem
                                        )
                                    end
                                    if ok then
                                        migrated = migrated + 1
                                    end
                                end
                                -- Drop the legacy record either way so the CDM
                                -- editor shows the bridged entry instead.
                                removeKeys[#removeKeys + 1] = recordKey
                            end
                        end
                    end
                    for _, recordKey in ipairs(removeKeys) do
                        specMap[recordKey] = nil
                    end
                end
            end
        end
    end

    -- Drop stale native tombstones left behind by earlier versions: their
    -- records no longer exist and they would otherwise surface in the saved
    -- list as ghost entries.
    self:CleanupStaleTombstones()

    state.alertBridgeMigrationDone = true
    return migrated
end

-- Removes native ready / cooldown / aura tombstones whose records are gone.
-- Safe to run repeatedly; called on every scope change so ghost entries left
-- by earlier versions disappear without waiting for a migration.
function Bridge:CleanupStaleTombstones()
    local db = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or nil
    local pending = db and type(db.cdmVoicePendingRemovals) == "table" and db.cdmVoicePendingRemovals or nil
    if not pending then
        return 0
    end
    local removed = 0
    for _, classMap in pairs(pending) do
        if type(classMap) == "table" then
            for _, specMap in pairs(classMap) do
                if type(specMap) == "table" then
                    for recordKey, tombstone in pairs(specMap) do
                        if type(tombstone) == "table" then
                            local eventKey = tostring(tombstone.eventKey or "")
                            if self:GetModeForEventKey(eventKey)
                                or self:GetAuraTriggerForEventKey(eventKey) then
                                specMap[recordKey] = nil
                                removed = removed + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return removed
end
