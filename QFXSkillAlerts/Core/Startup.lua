local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Startup = NS.Core.Startup or {}

local Startup = NS.Core.Startup

local callbacks = {}
local rebuildTimer
local loginItemRefreshTimer
local rebuildReasons = {}
local scheduledResetCooldowns = false
local profileRefreshCombatPending = false
local profileRefreshCombatReset = false
local tradeSkillWasAlchemy = false
local bagUpdateSerial = 0
local inventoryInteractionSerials = {}
local inventoryCloseTimers = {}

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

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

function Startup:CancelScheduledLoginItemRefresh()
    if loginItemRefreshTimer and type(loginItemRefreshTimer.Cancel) == "function" then
        loginItemRefreshTimer:Cancel()
    end
    loginItemRefreshTimer = nil
end

function Startup:CancelInventoryCloseTimers()
    for key, timer in pairs(inventoryCloseTimers) do
        if timer and type(timer.Cancel) == "function" then
            timer:Cancel()
        end
        inventoryCloseTimers[key] = nil
    end
end

function Startup:ScheduleLoginItemRefresh()
    self:CancelScheduledLoginItemRefresh()
    local function apply()
        loginItemRefreshTimer = nil
        SafeCall("handleItemInventoryChanged", "PLAYER_LOGIN_DELAYED")
    end
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        loginItemRefreshTimer = C_Timer.NewTimer(1.0, apply)
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1.0, apply)
    else
        apply()
    end
    return true
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
    callbacks.hasRelevantBagLoadStateChanged = opts.hasRelevantBagLoadStateChanged
    callbacks.isAlchemyTradeSkill = opts.isAlchemyTradeSkill
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
    self:ScheduleLoginItemRefresh()
end

function Startup:OnPlayerLogout()
    self:CancelScheduledProfileRefresh()
    self:CancelScheduledLoginItemRefresh()
    self:CancelInventoryCloseTimers()
    tradeSkillWasAlchemy = false
    wipe(inventoryInteractionSerials)
    SafeCall("clearDelayedCastSuccessTimers")
end

function Startup:OnProfileRefresh(event)
    if event == "PLAYER_ENTERING_WORLD" then
        InitializeMinimapButton()
    end
    if event ~= "PLAYER_ENTERING_WORLD" and IsCombatLocked() then
        profileRefreshCombatPending = true
        return true
    end
    SafeCall("invalidateTalentCache")
    self:ScheduleProfileRefresh(event, false)
end

function Startup:OnSpecializationChanged(unit)
    if unit == "player" then
        if IsCombatLocked() then
            profileRefreshCombatPending = true
            profileRefreshCombatReset = true
            return
        end
        SafeCall("invalidateTalentCache")
        self:ScheduleProfileRefresh("PLAYER_SPECIALIZATION_CHANGED", true)
    end
end

function Startup:OnItemDataLoadResult(...)
    return SafeCall("resolvePendingItems", ...)
end

function Startup:OnPlayerRegenEnabled()
    local deferredProfileRefresh = profileRefreshCombatPending
    if deferredProfileRefresh then
        local reset = profileRefreshCombatReset
        profileRefreshCombatPending = false
        profileRefreshCombatReset = false
        SafeCall("invalidateTalentCache")
        self:ScheduleProfileRefresh("COMBAT_DEFERRED_PROFILE_REFRESH", reset)
    end

    if deferredProfileRefresh then
        SafeCall("handleItemInventoryChanged", "PLAYER_REGEN_ENABLED_COVERED")
    else
        local itemsChanged = SafeCall("resolvePendingItems") == true
        SafeCall(
            "handleItemInventoryChanged",
            itemsChanged and "PLAYER_REGEN_ENABLED_COVERED" or "PLAYER_REGEN_ENABLED"
        )
    end
    -- 只清除施法成功“延时播放”队列；固定CD计时器 cooldowns 必须继续保留。
    SafeCall("clearDelayedCastSuccessTimers")
end

function Startup:OnUnitSpellcastSucceeded(unit, spellId)
    if unit == "player" or unit == "pet" then
        SafeCall("startCooldown", spellId)
        SafeCall("handleCastSuccessSpellcast", spellId)
    end
end

function Startup:OnUnitAura(unit, updateInfo)
    return SafeCall("handleBloodlustAura", unit, updateInfo)
end

function Startup:OnItemInventoryChanged(event)
    return SafeCall("handleItemInventoryChanged", event)
end

function Startup:OnBagUpdateDelayed()
    if SafeCall("hasRelevantBagLoadStateChanged") == true then
        bagUpdateSerial = bagUpdateSerial + 1
        return true
    end
    return false
end

function Startup:OnInventoryInteractionOpened(kind)
    kind = tostring(kind or "")
    if kind == "" then
        return false
    end
    local timer = inventoryCloseTimers[kind]
    if timer and type(timer.Cancel) == "function" then
        timer:Cancel()
    end
    inventoryCloseTimers[kind] = nil
    inventoryInteractionSerials[kind] = bagUpdateSerial
    return true
end

function Startup:OnInventoryInteractionClosed(kind, refreshEvent)
    kind = tostring(kind or "")
    local openedAt = inventoryInteractionSerials[kind]
    inventoryInteractionSerials[kind] = nil
    if openedAt == nil then
        return false
    end

    local function applyIfChanged()
        inventoryCloseTimers[kind] = nil
        if bagUpdateSerial > openedAt then
            SafeCall("handleItemInventoryChanged", refreshEvent)
            return true
        end
        return false
    end

    if bagUpdateSerial > openedAt then
        return applyIfChanged()
    end

    -- Some inventory updates arrive just after the interaction closes. Keep a
    -- short correlation window so those still count, without letting unrelated
    -- BAG_UPDATE_DELAYED events refresh the addon on their own.
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        inventoryCloseTimers[kind] = C_Timer.NewTimer(0.2, applyIfChanged)
        return true
    elseif C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.2, applyIfChanged)
        return true
    end
    return applyIfChanged()
end

function Startup:OnTradeSkillShow()
    tradeSkillWasAlchemy = SafeCall("isAlchemyTradeSkill") == true
    -- Start the correlation window even if Blizzard has not populated the
    -- profession info yet. CLOSE rechecks the profession before refreshing.
    self:OnInventoryInteractionOpened("ALCHEMY")
    return tradeSkillWasAlchemy
end

function Startup:OnTradeSkillClose()
    -- The profession is normally captured on SHOW because Blizzard may clear
    -- the data source before CLOSE. Recheck here as a fallback for a late load
    -- or a SHOW event that arrived before profession data was ready.
    local shouldRefresh = tradeSkillWasAlchemy or SafeCall("isAlchemyTradeSkill") == true
    tradeSkillWasAlchemy = false
    if shouldRefresh then
        return self:OnInventoryInteractionClosed("ALCHEMY", "ALCHEMY_TRADE_SKILL_CLOSED")
    end
    inventoryInteractionSerials.ALCHEMY = nil
    return false
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
        OnUnitAura = function(unit, updateInfo)
            return self:OnUnitAura(unit, updateInfo)
        end,
        OnItemInventoryChanged = function(event)
            return self:OnItemInventoryChanged(event)
        end,
        OnBagUpdateDelayed = function()
            return self:OnBagUpdateDelayed()
        end,
        OnInventoryInteractionOpened = function(kind)
            return self:OnInventoryInteractionOpened(kind)
        end,
        OnInventoryInteractionClosed = function(kind, refreshEvent)
            return self:OnInventoryInteractionClosed(kind, refreshEvent)
        end,
        OnTradeSkillShow = function()
            return self:OnTradeSkillShow()
        end,
        OnTradeSkillClose = function()
            return self:OnTradeSkillClose()
        end,
    }
end
