local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Startup = NS.Core.Startup or {}

local Startup = NS.Core.Startup

local callbacks = {}
local rebuildTimer
local rebuildReasons = {}
local scheduledResetCooldowns = false

local function SafeCall(name, ...)
    local fn = callbacks[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function InitializeMinimapButton()
    SafeCall("initializeMinimapButton")
    SafeCall("showMinimapButton")
end

function Startup:CancelScheduledProfileRefresh()
    if rebuildTimer and type(rebuildTimer.Cancel) == "function" then
        rebuildTimer:Cancel()
    end
    rebuildTimer = nil
    scheduledResetCooldowns = false
    wipe(rebuildReasons)
end

function Startup:ScheduleProfileRefresh(reason, resetCooldowns)
    rebuildReasons[tostring(reason or "unknown")] = true
    if resetCooldowns == true then
        scheduledResetCooldowns = true
    end
    if rebuildTimer then
        return true
    end

    local function apply()
        rebuildTimer = nil
        local reset = scheduledResetCooldowns
        scheduledResetCooldowns = false
        wipe(rebuildReasons)
        SafeCall("prepareProfileRefresh")
        SafeCall("onProfileChanged", reset)
    end
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        rebuildTimer = C_Timer.NewTimer(0.10, apply)
    else
        apply()
    end
    return true
end

function Startup:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.initializeDatabase = opts.initializeDatabase
    callbacks.ensureDB = opts.ensureDB
    callbacks.initializeAceOptions = opts.initializeAceOptions
    callbacks.initializeConfigPanel = opts.initializeConfigPanel
    callbacks.initializeCommands = opts.initializeCommands
    callbacks.initializeMinimapButton = opts.initializeMinimapButton
    callbacks.showMinimapButton = opts.showMinimapButton
    callbacks.printLoadedMessage = opts.printLoadedMessage
    callbacks.onProfileChanged = opts.onProfileChanged
    callbacks.resolvePendingItems = opts.resolvePendingItems
    callbacks.clearDelayedCastSuccessTimers = opts.clearDelayedCastSuccessTimers
    callbacks.startCooldown = opts.startCooldown
    callbacks.handleCastSuccessSpellcast = opts.handleCastSuccessSpellcast
    callbacks.handleBloodlustAura = opts.handleBloodlustAura
    callbacks.handleItemInventoryChanged = opts.handleItemInventoryChanged
    callbacks.handleCustomEvent = opts.handleCustomEvent
    callbacks.invalidateTalentCache = opts.invalidateTalentCache
    callbacks.prepareProfileRefresh = opts.prepareProfileRefresh
    return true
end

function Startup:OnPlayerLogin()
    SafeCall("invalidateTalentCache")
    SafeCall("initializeDatabase")
    SafeCall("ensureDB")
    SafeCall("initializeAceOptions")
    SafeCall("initializeConfigPanel")
    SafeCall("initializeCommands")
    InitializeMinimapButton()
    SafeCall("printLoadedMessage")
    self:ScheduleProfileRefresh("PLAYER_LOGIN", false)
end

function Startup:OnPlayerLogout()
    self:CancelScheduledProfileRefresh()
    SafeCall("clearDelayedCastSuccessTimers")
end

function Startup:OnProfileRefresh(event)
    if event == "PLAYER_ENTERING_WORLD" then
        InitializeMinimapButton()
    end
    SafeCall("invalidateTalentCache")
    self:ScheduleProfileRefresh(event, false)
end

function Startup:OnSpecializationChanged(unit)
    if unit == "player" then
        SafeCall("invalidateTalentCache")
        self:ScheduleProfileRefresh("PLAYER_SPECIALIZATION_CHANGED", true)
    end
end

function Startup:OnItemDataLoadResult(...)
    return SafeCall("resolvePendingItems", ...)
end

function Startup:OnPlayerRegenEnabled()
    SafeCall("resolvePendingItems")
    SafeCall("handleItemInventoryChanged", "PLAYER_REGEN_ENABLED")
    -- 只清除施法成功“延时播放”队列；固定CD计时器 cooldowns 必须继续保留。
    SafeCall("clearDelayedCastSuccessTimers")
end

function Startup:OnUnitSpellcastSucceeded(unit, spellId)
    if unit == "player" or unit == "pet" then
        SafeCall("startCooldown", spellId)
        SafeCall("handleCastSuccessSpellcast", spellId)
    end
end

function Startup:OnUnitAura(unit)
    return SafeCall("handleBloodlustAura", unit)
end

function Startup:OnItemInventoryChanged(event)
    return SafeCall("handleItemInventoryChanged", event)
end

function Startup:OnAnyEvent(event, ...)
    return SafeCall("handleCustomEvent", event, ...)
end

function Startup:GetEventHandlers()
    return {
        OnAnyEvent = function(event, ...)
            return self:OnAnyEvent(event, ...)
        end,
        OnPlayerLogin = function()
            return self:OnPlayerLogin()
        end,
        OnPlayerLogout = function()
            return self:OnPlayerLogout()
        end,
        OnProfileRefresh = function(event)
            return self:OnProfileRefresh(event)
        end,
        OnSpecializationChanged = function(unit)
            return self:OnSpecializationChanged(unit)
        end,
        OnItemDataLoadResult = function(...)
            return self:OnItemDataLoadResult(...)
        end,
        OnPlayerRegenEnabled = function()
            return self:OnPlayerRegenEnabled()
        end,
        OnUnitSpellcastSucceeded = function(unit, spellId)
            return self:OnUnitSpellcastSucceeded(unit, spellId)
        end,
        OnUnitAura = function(unit)
            return self:OnUnitAura(unit)
        end,
        OnItemInventoryChanged = function(event)
            return self:OnItemInventoryChanged(event)
        end,
    }
end
