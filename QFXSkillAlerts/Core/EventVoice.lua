local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.EventVoice = NS.Core.EventVoice or {}

local EventVoice = NS.Core.EventVoice
local CONST = NS.Constants or {}
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local MODE_SOUND = CONST.MODE_SOUND or "sound"

local L = NS.L or function(key)
    return tostring(key)
end

local DEFINITIONS = {
    { key = "combat_start", wowEvent = "PLAYER_REGEN_DISABLED", labelKey = "EVENT_VOICE_COMBAT_START", icon = 132337 },
    { key = "combat_end", wowEvent = "PLAYER_REGEN_ENABLED", labelKey = "EVENT_VOICE_COMBAT_END", icon = 132338 },
    { key = "mythic_plus_start", wowEvent = "CHALLENGE_MODE_START", labelKey = "EVENT_VOICE_MYTHIC_PLUS_START", icon = 525134 },
    { key = "mythic_plus_complete", wowEvent = "CHALLENGE_MODE_COMPLETED", labelKey = "EVENT_VOICE_MYTHIC_PLUS_COMPLETE", icon = 236372 },
    { key = "encounter_start", wowEvent = "ENCOUNTER_START", labelKey = "EVENT_VOICE_ENCOUNTER_START", icon = 136116 },
    { key = "encounter_success", wowEvent = "ENCOUNTER_END", labelKey = "EVENT_VOICE_ENCOUNTER_SUCCESS", icon = 236621, encounterResult = 1 },
    { key = "encounter_wipe", wowEvent = "ENCOUNTER_END", labelKey = "EVENT_VOICE_ENCOUNTER_WIPE", icon = 132281, encounterResult = 0 },
    { key = "ready_check", wowEvent = "READY_CHECK", labelKey = "EVENT_VOICE_READY_CHECK", icon = 132272 },
    { key = "player_dead", wowEvent = "PLAYER_DEAD", labelKey = "EVENT_VOICE_PLAYER_DEAD", icon = 132331 },
}

local definitionByKey = {}
for _, definition in ipairs(DEFINITIONS) do
    definitionByKey[definition.key] = definition
end

local callbacks = {}
local activeByWowEvent = {}
local lastFiredAt = {}

local function ClearTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    if type(wipe) == "function" then
        wipe(tbl)
    else
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

local function SafeCall(name, ...)
    local callback = callbacks[name]
    if type(callback) == "function" then
        return callback(...)
    end
    return nil
end

local function ScopeMapMatches(source, allID, fallbackID, currentID)
    local hasSelection = false
    if type(source) == "table" then
        for key, selected in pairs(source) do
            local numericKey = tonumber(key)
            if selected == true and numericKey and numericKey >= 0 then
                hasSelection = true
                if numericKey == allID or numericKey == currentID then
                    return true
                end
            end
        end
    end
    if not hasSelection then
        fallbackID = tonumber(fallbackID) or allID
        return fallbackID == allID or fallbackID == currentID
    end
    return false
end

local function GetCurrentRaceID()
    if type(UnitRace) ~= "function" then
        return 0
    end
    local _, _, raceID = UnitRace("player")
    return tonumber(raceID) or 0
end

local function IsScopeMatched(entry, scopeClassID, scopeSpecID, currentClassID, currentSpecID, currentRaceID)
    return ScopeMapMatches(entry.alertRaceIDs, ALL_RACES_ID, ALL_RACES_ID, currentRaceID)
        and ScopeMapMatches(entry.alertClassIDs or entry.customClassIDs, ALL_CLASSES_ID, scopeClassID, currentClassID)
        and ScopeMapMatches(entry.alertSpecIDs or entry.customSpecIDs, ALL_SPECS_ID, scopeSpecID, currentSpecID)
end

local function GetNow()
    local value = SafeCall("getTime")
    if value ~= nil then
        return tonumber(value) or 0
    end
    if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
    end
    return 0
end

local function MatchesDefinition(definition, ...)
    if definition.encounterResult ~= nil then
        local success = tonumber(select(5, ...))
        return success == definition.encounterResult
    end
    return true
end

function EventVoice:NormalizeEventKey(value)
    value = tostring(value or "")
    if definitionByKey[value] then
        return value
    end
    return nil
end

function EventVoice:GetDefinition(value)
    local key = self:NormalizeEventKey(value)
    return key and definitionByKey[key] or nil
end

function EventVoice:GetDisplayName(value)
    local definition = self:GetDefinition(value)
    return definition and L(definition.labelKey) or ""
end

function EventVoice:GetIcon(value)
    local definition = self:GetDefinition(value)
    return definition and definition.icon or 134400
end

function EventVoice:GetOptions()
    local options = {}
    for _, definition in ipairs(DEFINITIONS) do
        options[#options + 1] = {
            value = definition.key,
            text = L(definition.labelKey),
            icon = definition.icon,
        }
    end
    return options
end

function EventVoice:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.getCurrentClassSpec = opts.getCurrentClassSpec
    callbacks.getStoredEntryMap = opts.getStoredEntryMap
    callbacks.getOrderedEntryIndices = opts.getOrderedEntryIndices
    callbacks.getEntry = opts.getEntry
    callbacks.resolveEntrySoundPath = opts.resolveEntrySoundPath
    callbacks.playNotification = opts.playNotification
    callbacks.getTime = opts.getTime
    callbacks.createFrame = opts.createFrame
    return true
end

function EventVoice:EnsureFrame()
    if self.frame then
        return self.frame
    end
    local frame = SafeCall("createFrame")
    if not frame and type(CreateFrame) == "function" then
        frame = CreateFrame("Frame")
    end
    if not frame then
        return nil
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        self:Dispatch(event, ...)
    end)
    self.frame = frame
    return frame
end

function EventVoice:UpdateRegistrations()
    local frame = self.frame
    if frame and type(frame.UnregisterAllEvents) == "function" then
        frame:UnregisterAllEvents()
    end
    if not next(activeByWowEvent) then
        return true
    end
    frame = self:EnsureFrame()
    if not frame or type(frame.RegisterEvent) ~= "function" then
        return false
    end
    for wowEvent in pairs(activeByWowEvent) do
        frame:RegisterEvent(wowEvent)
    end
    return true
end

function EventVoice:Rebuild()
    ClearTable(activeByWowEvent)

    local currentClassID, currentSpecID = SafeCall("getCurrentClassSpec")
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0
    local currentRaceID = GetCurrentRaceID()
    local effectiveByKey = {}

    local function addEntriesFromMap(entryMap, scopeClassID, scopeSpecID)
        local indices = SafeCall("getOrderedEntryIndices", entryMap)
        for _, index in ipairs(type(indices) == "table" and indices or {}) do
            local entry = SafeCall("getEntry", entryMap, index)
            local eventKey = entry and self:NormalizeEventKey(entry.eventKey)
            if entry and tostring(entry.entryType or "") == "event" and eventKey
                and entry.voiceEnabled ~= false
                and IsScopeMatched(entry, scopeClassID, scopeSpecID, currentClassID, currentSpecID, currentRaceID) then
                effectiveByKey[eventKey] = {
                    eventKey = eventKey,
                    eventName = self:GetDisplayName(eventKey),
                    notifyMode = tostring(entry.notifyMode or MODE_SOUND),
                    ttsText = tostring(entry.ttsText or ""),
                    ttsRate = math.max(-10, math.min(10, tonumber(entry.ttsRate) or 0)),
                    soundPath = tostring(entry.soundPath or ""),
                    soundSource = tostring(entry.soundSource or ""),
                    builtinSoundPath = tostring(entry.builtinSoundPath or ""),
                    customSoundPath = tostring(entry.customSoundPath or ""),
                    sharedMediaSound = tostring(entry.sharedMediaSound or ""),
                    resolvedSoundPath = tostring(SafeCall("resolveEntrySoundPath", entry) or ""),
                    voiceEnabled = true,
                    eventThrottle = math.max(0, math.min(300, tonumber(entry.eventThrottle) or 1)),
                }
            end
        end
    end

    addEntriesFromMap(SafeCall("getStoredEntryMap", ALL_CLASSES_ID, ALL_SPECS_ID), ALL_CLASSES_ID, ALL_SPECS_ID)
    addEntriesFromMap(SafeCall("getStoredEntryMap", currentClassID, ALL_SPECS_ID), currentClassID, ALL_SPECS_ID)
    if currentSpecID ~= ALL_SPECS_ID then
        addEntriesFromMap(SafeCall("getStoredEntryMap", currentClassID, currentSpecID), currentClassID, currentSpecID)
    end

    local count = 0
    for _, definition in ipairs(DEFINITIONS) do
        local cfg = effectiveByKey[definition.key]
        if cfg then
            local list = activeByWowEvent[definition.wowEvent]
            if not list then
                list = {}
                activeByWowEvent[definition.wowEvent] = list
            end
            list[#list + 1] = { definition = definition, cfg = cfg }
            count = count + 1
        end
    end

    self:UpdateRegistrations()
    return true, count
end

function EventVoice:Dispatch(wowEvent, ...)
    local list = activeByWowEvent[tostring(wowEvent or "")]
    if type(list) ~= "table" then
        return false
    end

    local now = GetNow()
    local fired = false
    for _, active in ipairs(list) do
        local definition = active.definition
        local cfg = active.cfg
        if definition and cfg and MatchesDefinition(definition, ...) then
            local throttle = math.max(0, tonumber(cfg.eventThrottle) or 0)
            local previous = lastFiredAt[definition.key]
            if previous == nil or throttle <= 0 or (now - previous) >= throttle then
                lastFiredAt[definition.key] = now
                fired = SafeCall("playNotification", cfg) == true or fired
            end
        end
    end
    return fired
end
