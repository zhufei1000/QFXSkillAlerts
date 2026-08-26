local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.ProfileController = NS.Core.ProfileController or {}

local Controller = NS.Core.ProfileController
local CONST = NS.Constants or {}

local ENTRY_MIN = CONST.ENTRY_MIN or 1
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local callbacks = {}

local function SafeCall(name, ...)
    local fn = callbacks[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetAceState()
    local state = SafeCall("getAceState")
    return type(state) == "table" and state or nil
end

function Controller:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.getAceState = opts.getAceState
    callbacks.getCurrentClassSpec = opts.getCurrentClassSpec
    callbacks.getStoredEntryMap = opts.getStoredEntryMap
    callbacks.getUsedEntryCount = opts.getUsedEntryCount
    callbacks.wipeRuntimeCooldowns = opts.wipeRuntimeCooldowns
    callbacks.rebuildRuntimeConfig = opts.rebuildRuntimeConfig
    callbacks.rebuildCastSuccessConfig = opts.rebuildCastSuccessConfig
    callbacks.rebuildCustomConfig = opts.rebuildCustomConfig
    callbacks.rebuildEventVoiceConfig = opts.rebuildEventVoiceConfig
    callbacks.rebuildBloodlustConfig = opts.rebuildBloodlustConfig
    callbacks.refreshRuntimeCooldowns = opts.refreshRuntimeCooldowns
    callbacks.refreshPanel = opts.refreshPanel
    return true
end

function Controller:GetTargetClassSpec()
    local state = GetAceState()
    if state then
        local classID = tonumber(state.classID) or 0
        local specID = tonumber(state.specID) or 0
        if classID >= 0 and specID >= 0 then
            if classID == ALL_CLASSES_ID then
                return ALL_CLASSES_ID, ALL_SPECS_ID
            end
            return classID, specID
        end
    end

    local classID, specID = SafeCall("getCurrentClassSpec")
    return tonumber(classID) or 0, tonumber(specID) or 0
end

function Controller:GetEntryRange()
    local classID, specID = self:GetTargetClassSpec()
    local map = SafeCall("getStoredEntryMap", classID, specID)
    if type(map) ~= "table" then
        map = {}
    end

    local maxIndex = ENTRY_MIN
    for index in pairs(map) do
        local candidate = tonumber(index) or 0
        if candidate >= ENTRY_MIN and candidate > maxIndex then
            maxIndex = candidate
        end
    end
    return ENTRY_MIN, maxIndex
end

function Controller:BuildSummaryText()
    local classID, specID = self:GetTargetClassSpec()
    local map = SafeCall("getStoredEntryMap", classID, specID)
    if type(map) ~= "table" then
        map = {}
    end
    local count = SafeCall("getUsedEntryCount", map)
    count = tonumber(count) or 0
    return L("MSG_SCOPE_COUNT", count)
end

function Controller:RefreshPanel()
    return SafeCall("refreshPanel")
end

function Controller:OnProfileChanged(resetCooldowns)
    -- Only wipe active timers when the playable profile really changes.
    -- World entry, spellbook refreshes, and talent refreshes can happen while a
    -- fixed cooldown is already running; wiping here makes the ready alert vanish.
    if resetCooldowns then
        SafeCall("wipeRuntimeCooldowns", true)
    end
    SafeCall("rebuildRuntimeConfig")
    SafeCall("rebuildCastSuccessConfig")
    SafeCall("rebuildCustomConfig")
    SafeCall("rebuildEventVoiceConfig")
    SafeCall("rebuildBloodlustConfig")
    SafeCall("refreshRuntimeCooldowns")
    SafeCall("refreshPanel")
end
