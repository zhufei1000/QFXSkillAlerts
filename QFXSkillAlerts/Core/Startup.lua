local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Startup = NS.Core.Startup or {}

local Startup = NS.Core.Startup

local callbacks = {}

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

function Startup:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.initializeDatabase = opts.initializeDatabase
    callbacks.ensureDB = opts.ensureDB
    callbacks.purgeDeletedEntries = opts.purgeDeletedEntries
    callbacks.resolveAllStoredItemTriggers = opts.resolveAllStoredItemTriggers
    callbacks.rebuildRuntimeConfig = opts.rebuildRuntimeConfig
    callbacks.rebuildCastSuccessConfig = opts.rebuildCastSuccessConfig
    callbacks.rebuildCustomConfig = opts.rebuildCustomConfig
    callbacks.rebuildBloodlustConfig = opts.rebuildBloodlustConfig
    callbacks.refreshRuntimeCooldowns = opts.refreshRuntimeCooldowns
    callbacks.initializeAceOptions = opts.initializeAceOptions
    callbacks.initializeConfigPanel = opts.initializeConfigPanel
    callbacks.initializeCommands = opts.initializeCommands
    callbacks.initializeMinimapButton = opts.initializeMinimapButton
    callbacks.showMinimapButton = opts.showMinimapButton
    callbacks.printLoadedMessage = opts.printLoadedMessage
    callbacks.onProfileChanged = opts.onProfileChanged
    callbacks.markBagItemCacheDirty = opts.markBagItemCacheDirty
    callbacks.resolvePendingItems = opts.resolvePendingItems
    callbacks.clearDelayedCastSuccessTimers = opts.clearDelayedCastSuccessTimers
    callbacks.startCooldown = opts.startCooldown
    callbacks.handleCastSuccessSpellcast = opts.handleCastSuccessSpellcast
    callbacks.handleBloodlustAura = opts.handleBloodlustAura
    callbacks.handleItemInventoryChanged = opts.handleItemInventoryChanged
    callbacks.handleCustomEvent = opts.handleCustomEvent
    return true
end

function Startup:OnPlayerLogin()
    SafeCall("initializeDatabase")
    SafeCall("ensureDB")
    SafeCall("purgeDeletedEntries")
    SafeCall("resolveAllStoredItemTriggers", true)
    SafeCall("rebuildRuntimeConfig")
    SafeCall("rebuildCastSuccessConfig")
    SafeCall("rebuildCustomConfig")
    SafeCall("rebuildBloodlustConfig")
    SafeCall("refreshRuntimeCooldowns")
    SafeCall("initializeAceOptions")
    SafeCall("initializeConfigPanel")
    SafeCall("initializeCommands")
    InitializeMinimapButton()
    SafeCall("printLoadedMessage")
end

function Startup:OnProfileRefresh(event)
    if event == "PLAYER_ENTERING_WORLD" then
        InitializeMinimapButton()
    end
    SafeCall("purgeDeletedEntries")
    SafeCall("resolveAllStoredItemTriggers", true)
    SafeCall("markBagItemCacheDirty")
    SafeCall("onProfileChanged", false)
end

function Startup:OnSpecializationChanged(unit)
    if unit == "player" then
        SafeCall("purgeDeletedEntries")
        SafeCall("resolveAllStoredItemTriggers", true)
        SafeCall("onProfileChanged", true)
    end
end

function Startup:OnItemDataLoadResult(...)
    return SafeCall("resolvePendingItems", ...)
end

function Startup:OnPlayerRegenEnabled()
    SafeCall("resolvePendingItems")
    SafeCall("clearDelayedCastSuccessTimers")
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
