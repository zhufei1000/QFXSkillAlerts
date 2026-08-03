local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Runtime = NS.Core.Runtime or {}
NS.Runtime = NS.Core.Runtime

local Runtime = NS.Core.Runtime
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local MODE_SOUND = CONST.MODE_SOUND or "sound"
local UPDATE_INTERVAL_COMBAT = CONST.UPDATE_INTERVAL_COMBAT or 0.10
local UPDATE_INTERVAL_IDLE = CONST.UPDATE_INTERVAL_IDLE or 0.16

local frame = CreateFrame("Frame")
local cooldowns = {}
local delayedCastSuccess = {}
local delayedCastToken = 0
local updateElapsed = 0
local activeUpdateInterval = UPDATE_INTERVAL_IDLE
local updating = false
local callbacks = {}
local ApplyAlertFields

local function SafeCall(name, ...)
    local fn = callbacks[name]
    if type(fn) == "function" then
        return fn(...)
    end
    return nil
end

local function GetRuntimeUpdateInterval()
    local value = SafeCall("getUpdateInterval")
    value = tonumber(value) or 0
    if value > 0 then
        return value
    end
    if type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then
        return UPDATE_INTERVAL_COMBAT
    end
    return UPDATE_INTERVAL_IDLE
end

local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function NormalizeConditionTime(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = tonumber(fallback) or 0
    end
    return math.max(0, numeric or 0)
end

local function EvaluateCooldownCondition(op, threshold, remaining, previousRemaining)
    -- Hot path (runs every OnUpdate tick for every active alert channel):
    -- op/threshold are always pre-normalized once by ApplyAlertFields when the
    -- config is applied, so re-normalizing them here on every tick is wasted
    -- work. Only fall back to full normalization if something unexpected
    -- (non-numeric threshold / unrecognized op) slips through.
    if type(threshold) ~= "number" then
        threshold = NormalizeConditionTime(threshold, 0)
    end
    if type(op) ~= "string" then
        op = NormalizeConditionOp(op)
    end
    remaining = remaining or 0
    if op == "<" then
        return remaining < threshold
    elseif op == ">" then
        return remaining > threshold
    elseif op == ">=" then
        return remaining >= threshold
    elseif op == "==" then
        if threshold <= 0 then
            return remaining <= 0
        end
        if math.abs(remaining - threshold) <= 0.12 then
            return true
        end
        previousRemaining = tonumber(previousRemaining)
        return previousRemaining ~= nil and previousRemaining > threshold and remaining <= threshold
    end
    return remaining <= threshold
end

local function CheckAndNotifyChannel(cd, channel, remaining)
    if channel == "voice" then
        if cd.voiceEnabled == false or cd.voiceNotified then
            return false
        end
        if EvaluateCooldownCondition(cd.voiceConditionOp, cd.voiceConditionTime, remaining, cd.previousRemaining) then
            SafeCall("playReady", cd, "voice", remaining, cd.primaryKey)
            cd.voiceNotified = true
            return true
        end
    end
    return false
end

local function VisualChannelHasFiniteDuration(cd, channel)
    if channel == "image" then
        return cd.imageDurationEnabled == true
    elseif channel == "text" then
        return cd.textDurationEnabled == true
    elseif channel == "visual" then
        return cd.imageDurationEnabled == true or cd.textDurationEnabled == true
    end
    return true
end

local function SetVisualNotified(cd, channel)
    if channel == "image" then
        cd.imageNotified = true
    elseif channel == "text" then
        cd.textNotified = true
    elseif channel == "visual" then
        cd.imageNotified = true
        cd.textNotified = true
    end
end

local function IsVisualAlreadyNotified(cd, channel)
    if channel == "image" then
        return cd.imageNotified == true
    elseif channel == "text" then
        return cd.textNotified == true
    elseif channel == "visual" then
        return cd.imageNotified == true and cd.textNotified == true
    end
    return true
end

-- A finite-duration channel (image/text with "limit display time" enabled)
-- can only ever fire once per cooldown cycle: once cd.xNotified is true it
-- will never fire again until the next StartCooldown() resets the flags.
-- Untimed (state-based) channels must keep being re-evaluated every tick so
-- they can hide again once the condition goes false, so those are never
-- considered "done" here.
local function IsChannelWorkDone(enabled, durationEnabled, notified)
    if enabled ~= true then
        return true
    end
    if durationEnabled ~= true then
        return false
    end
    return notified == true
end

local function ClearDisabledActiveVisual(cd)
    if cd.visualActive ~= true then
        return false
    end

    local channel = cd.visualChannel
    local stillEnabled = (channel == "image" and cd.imageEnabled == true)
        or (channel == "text" and cd.textEnabled == true)
        or (channel == "visual" and cd.imageEnabled == true and cd.textEnabled == true)
    if stillEnabled then
        return false
    end

    SafeCall("hideVisual", cd.primaryKey)
    cd.visualActive = false
    cd.visualChannel = nil
    return true
end

local function CheckAndUpdateVisualChannels(cd, remaining)
    -- Live config refreshes can disable a channel while its untimed visual is
    -- still active. Clear that stale visual before any hot-path early return.
    ClearDisabledActiveVisual(cd)

    -- Hot-path guard: once every configured finite-duration visual channel
    -- has already fired, there is nothing left this record can do until its
    -- cooldown resets, so skip the (relatively costly) condition evaluation
    -- entirely instead of recomputing the same "already notified" result on
    -- every OnUpdate tick for the rest of the cooldown.
    if IsChannelWorkDone(cd.imageEnabled, cd.imageDurationEnabled, cd.imageNotified)
        and IsChannelWorkDone(cd.textEnabled, cd.textDurationEnabled, cd.textNotified) then
        return false
    end

    local imageReady = cd.imageEnabled == true and
    EvaluateCooldownCondition(cd.imageConditionOp, cd.imageConditionTime, remaining, cd.previousRemaining)
    local textReady = cd.textEnabled == true and
    EvaluateCooldownCondition(cd.textConditionOp, cd.textConditionTime, remaining, cd.previousRemaining)
    local channel = nil
    if imageReady and textReady then
        channel = "visual"
    elseif imageReady then
        channel = "image"
    elseif textReady then
        channel = "text"
    end

    if not channel then
        if cd.visualActive == true then
            SafeCall("hideVisual", cd.primaryKey)
            cd.visualActive = false
            cd.visualChannel = nil
        end
        return false
    end

    local finiteDuration = VisualChannelHasFiniteDuration(cd, channel)
    if finiteDuration then
        if IsVisualAlreadyNotified(cd, channel) then
            return false
        end
        SafeCall("playReady", cd, channel, remaining, cd.primaryKey)
        SetVisualNotified(cd, channel)
        cd.visualActive = false
        cd.visualChannel = nil
        return true
    end

    -- Untimed visual alerts are state-based: show while the cooldown condition is
    -- true, keep ready-state alerts visible after the timer reaches 0, and hide
    -- them when the spell/item is used again or when the condition becomes false.
    if cd.visualActive == true and cd.visualChannel == channel then
        return false
    end
    SafeCall("playReady", cd, channel, remaining, cd.primaryKey)
    cd.visualActive = true
    cd.visualChannel = channel
    return true
end

local function ResolveObjectName(objectID, objectType)
    local value = SafeCall("resolveObjectName", objectID, objectType)
    if type(value) == "string" then
        return value
    end
    return ""
end

function Runtime:Configure(opts)
    opts = type(opts) == "table" and opts or {}
    callbacks.getUpdateInterval = opts.getUpdateInterval
    callbacks.playReady = opts.playReady
    callbacks.playCastSuccess = opts.playCastSuccess
    callbacks.hideVisual = opts.hideVisual
    callbacks.resolveObjectName = opts.resolveObjectName
    return true
end

function Runtime:GetCooldownTable()
    return cooldowns
end

function Runtime:GetDelayedCastSuccessTable()
    return delayedCastSuccess
end

local function StopUpdate()
    if updating then
        updating = false
        updateElapsed = 0
        frame:SetScript("OnUpdate", nil)
    end
end

function Runtime:WipeCooldowns(hideVisual)
    wipe(cooldowns)

    -- Profile/spec rebuilds can remove the cooldown state while a state-based
    -- visual alert is still on screen.  Hide it together with the runtime wipe
    -- so old image/text alerts cannot remain after the active config changes.
    if hideVisual ~= false then
        SafeCall("hideVisual")
    end

    if next(cooldowns) == nil then
        StopUpdate()
    end
    return true
end

function Runtime:ClearDelayedCastSuccessTimers()
    for _, record in pairs(delayedCastSuccess) do
        local timer = record and record.timer
        if timer and type(timer.Cancel) == "function" then
            timer:Cancel()
        end
    end
    wipe(delayedCastSuccess)
    return true
end

function Runtime:SyncCooldownState(spellId, now)
    local cd = cooldowns[spellId]
    if not cd then
        return nil
    end

    now = tonumber(now) or GetTime()
    local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
    local singleCD = tonumber(cd.singleCD) or 0
    if singleCD <= 0 then
        cooldowns[spellId] = nil
        return nil
    end

    if not cd.nextChargeAt then
        cd.nextChargeAt = now + singleCD
    end

    -- Fast path for single-charge cooldowns (the vast majority):
    -- skip the while-loop overhead.
    if maxCharge == 1 then
        if cd.currentCharge < 1 and cd.nextChargeAt and now >= cd.nextChargeAt then
            cd.currentCharge = 1
            cd.nextChargeAt = nil
        end
    else
        while cd.currentCharge < maxCharge and cd.nextChargeAt and now >= cd.nextChargeAt do
            cd.currentCharge = cd.currentCharge + 1
            if cd.currentCharge < maxCharge then
                cd.nextChargeAt = cd.nextChargeAt + singleCD
            else
                cd.nextChargeAt = nil
            end
        end
    end

    return cd
end

function Runtime:EstimateCharges(cd)
    if not cd then
        return 0
    end
    local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
    local currentCharge = math.floor(tonumber(cd.currentCharge) or 0)
    if currentCharge < 0 then
        currentCharge = 0
    end
    if currentCharge > maxCharge then
        currentCharge = maxCharge
    end
    return currentCharge
end

function Runtime:ProcessCooldownRecord(primaryKey, cd, now, processVoice)
    if not cd then
        return false
    end
    cd.primaryKey = primaryKey
    cd = self:SyncCooldownState(primaryKey, now)
    if not cd then
        return false
    end

    local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
    local isFull = self:EstimateCharges(cd) >= maxCharge
    local remaining = 0
    if not isFull then
        local nextChargeAt = tonumber(cd.nextChargeAt) or 0
        remaining = nextChargeAt > 0 and math.max(0, nextChargeAt - now) or 0
    end

    if processVoice ~= false and cd.voiceEnabled ~= false then
        CheckAndNotifyChannel(cd, "voice", remaining)
    end
    if cd.imageEnabled == true or cd.textEnabled == true or cd.visualActive == true then
        CheckAndUpdateVisualChannels(cd, remaining)
    end
    cd.previousRemaining = remaining

    if isFull then
        cooldowns[primaryKey] = nil
        return false
    end
    return true
end

function Runtime:ApplyEditorVisualState(primaryKey, cfg)
    primaryKey = tostring(primaryKey or "")
    if primaryKey == "" or type(cfg) ~= "table" then
        return false
    end

    local cd = cooldowns[primaryKey]
    if not cd then
        return false
    end

    if cfg.imageEnabled ~= true or cfg.textEnabled ~= true then
        -- When switching from a linked Image+Text group to a single visual part,
        -- clear the old group first, then CheckAndUpdateVisualChannels will
        -- show the still-enabled part immediately if its condition is active.
        SafeCall("hideVisual", primaryKey)
        cd.visualActive = false
        cd.visualChannel = nil
    end
    cd.primaryKey = primaryKey

    if ApplyAlertFields then
        ApplyAlertFields(cd, cfg)
    end

    local now = GetTime()
    cd = self:SyncCooldownState(primaryKey, now)
    if not cd then
        return false
    end

    local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
    local isFull = self:EstimateCharges(cd) >= maxCharge
    local remaining = 0
    if not isFull then
        local nextChargeAt = tonumber(cd.nextChargeAt) or 0
        remaining = nextChargeAt > 0 and math.max(0, nextChargeAt - now) or 0
    end

    CheckAndUpdateVisualChannels(cd, remaining)
    if isFull then
        cooldowns[primaryKey] = nil
    end
    return true
end

function Runtime:RefreshRuntimeCooldowns(mappedRuntimeCfg)
    local now = GetTime()
    local active = false
    local cfgMap = type(mappedRuntimeCfg) == "table" and mappedRuntimeCfg or nil

    for primaryKey, cd in pairs(cooldowns) do
        local cfg = cfgMap and cfgMap[primaryKey] or nil
        if cd then cd.primaryKey = primaryKey end
        if cfg and ApplyAlertFields then
            ApplyAlertFields(cd, cfg)
        elseif cfgMap then
            if cd and cd.visualActive == true then
                SafeCall("hideVisual", primaryKey)
            end
            cooldowns[primaryKey] = nil
            cd = nil
        end

        if cd and self:ProcessCooldownRecord(primaryKey, cd, now, false) then
            active = true
        end
    end

    if active then
        self:StartUpdate()
    else
        StopUpdate()
    end
    return true
end

local function RuntimeOnUpdate(_, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < activeUpdateInterval then
        return
    end
    local interval = activeUpdateInterval
    updateElapsed = math.min(math.max(0, updateElapsed - interval), interval)

    local now = GetTime()
    local active = false
    for primaryKey, cd in pairs(cooldowns) do
        if Runtime:ProcessCooldownRecord(primaryKey, cd, now, true) then
            active = true
        end
    end
    activeUpdateInterval = GetRuntimeUpdateInterval()
    if not active then
        StopUpdate()
    end
end

function Runtime:StartUpdate()
    if updating or next(cooldowns) == nil then
        return
    end
    updating = true
    updateElapsed = 0
    activeUpdateInterval = GetRuntimeUpdateInterval()
    frame:SetScript("OnUpdate", RuntimeOnUpdate)
end

function Runtime:QueueCastSuccessNotification(triggerSpellID, cfg)
    if type(cfg) ~= "table" then
        return false
    end

    triggerSpellID = tonumber(triggerSpellID) or tonumber(cfg.triggerSpellID) or tonumber(cfg.spellId) or 0
    local delaySeconds = math.max(0, tonumber(cfg.delaySeconds) or 0)
    local oldRecord = delayedCastSuccess[triggerSpellID]
    if oldRecord then
        if oldRecord.timer and type(oldRecord.timer.Cancel) == "function" then
            oldRecord.timer:Cancel()
        end
        delayedCastSuccess[triggerSpellID] = nil
    end

    if not (cfg.delayEnabled == true and delaySeconds > 0 and triggerSpellID > 0) then
        return SafeCall("playCastSuccess", cfg, triggerSpellID) == true
    end

    if not (C_Timer and type(C_Timer.NewTimer) == "function") then
        return SafeCall("playCastSuccess", cfg, triggerSpellID) == true
    end

    delayedCastToken = delayedCastToken + 1
    local token = delayedCastToken
    local record = { cfg = cfg, token = token }
    delayedCastSuccess[triggerSpellID] = record
    local timer
    timer = C_Timer.NewTimer(delaySeconds, function()
        local current = delayedCastSuccess[triggerSpellID]
        if current ~= record or record.token ~= token or record.timer ~= timer then
            return
        end
        delayedCastSuccess[triggerSpellID] = nil
        record.timer = nil
        SafeCall("playCastSuccess", cfg, triggerSpellID)
    end)
    record.timer = timer
    return true
end

ApplyAlertFields = function(target, cfg)
    target.notifyMode = tostring(cfg.notifyMode or MODE_SOUND)
    target.ttsText = tostring(cfg.ttsText or "")
    target.ttsRate = math.max(-10, math.min(10, tonumber(cfg.ttsRate) or 0))
    target.resolvedSoundPath = tostring(cfg.resolvedSoundPath ~= nil and cfg.resolvedSoundPath or cfg.soundPath or "")
    target.cooldownAlertTime = math.max(0, tonumber(cfg.cooldownAlertTime or cfg.alertLeadTime) or 0)
    target.voiceEnabled = cfg.voiceEnabled ~= false
    target.voiceConditionOp = NormalizeConditionOp(cfg.voiceConditionOp)
    target.voiceConditionTime = NormalizeConditionTime(cfg.voiceConditionTime, target.cooldownAlertTime)
    target.imageEnabled = cfg.imageEnabled == true
    target.imageConditionOp = NormalizeConditionOp(cfg.imageConditionOp)
    target.imageConditionTime = NormalizeConditionTime(cfg.imageConditionTime, target.cooldownAlertTime)
    target.imageSource = tostring(cfg.imageSource or "auto")
    target.imageIconID = math.max(0, tonumber(cfg.imageIconID) or 0)
    target.imagePath = tostring(cfg.imagePath or "")
    target.resolvedImageTexture = cfg.resolvedImageTexture
    target.imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
    target.imageDurationEnabled = cfg.imageDurationEnabled == true
    target.imageDuration = math.max(0.1, tonumber(cfg.imageDuration) or 2)
    target.imageX = tonumber(cfg.imageX) or 0
    target.imageY = tonumber(cfg.imageY) or 120
    target.textEnabled = cfg.textEnabled == true
    target.textConditionOp = NormalizeConditionOp(cfg.textConditionOp)
    target.textConditionTime = NormalizeConditionTime(cfg.textConditionTime, target.cooldownAlertTime)
    target.textAlert = tostring(cfg.textAlert or "")
    target.textSize = math.max(8, tonumber(cfg.textSize) or 24)
    target.textDurationEnabled = cfg.textDurationEnabled == true
    target.textDuration = math.max(0.1, tonumber(cfg.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(target)
    end
    target.textX = tonumber(cfg.textX) or 0
    target.textY = tonumber(cfg.textY) or 120
    target.textAttachMode = tostring(cfg.textAttachMode or "outside")
    target.textVAlign = tostring(cfg.textVAlign or "bottom")
    target.textHAlign = tostring(cfg.textHAlign or "center")
    target.textOffsetX = tonumber(cfg.textOffsetX) or 0
    target.textOffsetY = tonumber(cfg.textOffsetY) or 0
    target.index = tonumber(cfg.index) or 0
    target.scopeClassID = tonumber(cfg.scopeClassID) or 0
    target.scopeSpecID = tonumber(cfg.scopeSpecID) or 0
    target.visualEntryKey = cfg.visualEntryKey
    target.visualUID = cfg.visualUID
end

function Runtime:StartCooldown(spellId, mappedSpellToPrimary, mappedRuntimeCfg)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 or type(mappedSpellToPrimary) ~= "table" or type(mappedRuntimeCfg) ~= "table" or not mappedSpellToPrimary[spellId] then
        return
    end

    local primaryKey = mappedSpellToPrimary[spellId]
    local cfg = mappedRuntimeCfg[primaryKey]
    if not cfg or (tonumber(cfg.baseCD) or 0) <= 0 then
        return
    end

    if cfg.imageEnabled == true or cfg.textEnabled == true then
        SafeCall("hideVisual", primaryKey)
    end

    -- 12.0.5：急速API在受污染插件逻辑中可能返回 Secret Number。
    -- 为避免 “attempt to compare/use a secret number value” 报错，冷却只按用户填写的固定CD计算。
    local singleCD = tonumber(cfg.baseCD) or 0
    singleCD = math.floor((singleCD * 100) + 0.5) / 100
    if singleCD <= 0 then
        return
    end

    local maxCharge = math.max(1, math.floor(tonumber(cfg.chargeInput) or 1))
    local now = GetTime()
    local cd = self:SyncCooldownState(primaryKey, now)
    local displayName = cfg.spellName
    if tostring(displayName or "") == "" then
        displayName = ResolveObjectName(cfg.objectID or cfg.spellId, cfg.objectType)
    end

    if cd then
        cd.primaryKey = primaryKey
        cd.singleCD = singleCD
        cd.charge = maxCharge
        cd.spellName = displayName
        cd.objectType = cfg.objectType
        cd.objectID = cfg.objectID or cfg.spellId
        ApplyAlertFields(cd, cfg)
        if cd.currentCharge > 0 then
            cd.currentCharge = cd.currentCharge - 1
        else
            cd.currentCharge = 0
            cd.nextChargeAt = now + singleCD
        end
        if cd.currentCharge <= 0 then
            cd.voiceNotified = false
            cd.imageNotified = false
            cd.textNotified = false
            cd.visualActive = false
            cd.visualChannel = nil
            cd.previousRemaining = nil
            if not cd.nextChargeAt then
                cd.nextChargeAt = now + singleCD
            end
        end
    else
        local currentCharge = maxCharge - 1
        if currentCharge < 0 then
            currentCharge = 0
        end
        if currentCharge < maxCharge then
            local newCd = {
                primaryKey = primaryKey,
                singleCD = singleCD,
                charge = maxCharge,
                currentCharge = currentCharge,
                nextChargeAt = now + singleCD,
                spellName = displayName,
                objectType = cfg.objectType,
                objectID = cfg.objectID or cfg.spellId,
                voiceNotified = (currentCharge > 0),
                imageNotified = (currentCharge > 0),
                textNotified = (currentCharge > 0),
                visualActive = false,
                visualChannel = nil,
                previousRemaining = nil,
                spellId = cfg.objectID or cfg.spellId,
            }
            ApplyAlertFields(newCd, cfg)
            cooldowns[primaryKey] = newCd
        end
    end

    local activeCd = cooldowns[primaryKey]
    if activeCd and self:ProcessCooldownRecord(primaryKey, activeCd, now, true) then
        self:StartUpdate()
    elseif next(cooldowns) == nil then
        StopUpdate()
    end
end
