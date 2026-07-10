local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Runtime = NS.Core.Runtime or {}
NS.Runtime = NS.Core.Runtime

local Runtime = NS.Core.Runtime
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local MODE_SOUND = CONST.MODE_SOUND or "sound"
local UPDATE_INTERVAL_COMBAT = CONST.UPDATE_INTERVAL_COMBAT or 0.03
local UPDATE_INTERVAL_IDLE = CONST.UPDATE_INTERVAL_IDLE or 0.08

local frame = CreateFrame("Frame")
local cooldowns = {}
local delayedCastSuccess = {}
local updateElapsed = 0
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

local function NormalizeSoundPath(path)
    local value = SafeCall("normalizeSoundPath", path)
    if type(value) == "string" then
        return value
    end
    return tostring(path or ""):gsub("/", "\\")
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

local function NormalizeCastDelayMode(value)
    return "show"
end

local function EvaluateCooldownCondition(op, threshold, remaining)
    remaining = math.max(0, tonumber(remaining) or 0)
    threshold = math.max(0, tonumber(threshold) or 0)
    op = NormalizeConditionOp(op)
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
        return math.abs(remaining - threshold) <= 0.12
    end
    return remaining <= threshold
end

local function CopyChannelConfig(cfg, channel, remaining)
    local copy = {}
    for key, value in pairs(cfg or {}) do
        copy[key] = value
    end
    copy.alertChannel = channel
    copy.cooldownRemaining = math.max(0, tonumber(remaining) or 0)
    return copy
end

local function CheckAndNotifyChannel(cd, channel, remaining)
    if channel == "voice" then
        if cd.voiceEnabled == false or cd.voiceNotified then
            return false
        end
        if EvaluateCooldownCondition(cd.voiceConditionOp, cd.voiceConditionTime, remaining) then
            SafeCall("playReady", CopyChannelConfig(cd, "voice", remaining))
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

local function CheckAndUpdateVisualChannels(cd, remaining)
    local imageReady = cd.imageEnabled == true and EvaluateCooldownCondition(cd.imageConditionOp, cd.imageConditionTime, remaining)
    local textReady = cd.textEnabled == true and EvaluateCooldownCondition(cd.textConditionOp, cd.textConditionTime, remaining)
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
        SafeCall("playReady", CopyChannelConfig(cd, channel, remaining))
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
    SafeCall("playReady", CopyChannelConfig(cd, channel, remaining))
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
    callbacks.normalizeSoundPath = opts.normalizeSoundPath
    callbacks.resolveObjectName = opts.resolveObjectName
    return true
end

function Runtime:GetCooldownTable()
    return cooldowns
end

function Runtime:GetDelayedCastSuccessTable()
    return delayedCastSuccess
end

function Runtime:WipeCooldowns(hideVisual)
    wipe(cooldowns)

    -- Profile/spec rebuilds can remove the cooldown state while a state-based
    -- visual alert is still on screen.  Hide it together with the runtime wipe
    -- so old image/text alerts cannot remain after the active config changes.
    if hideVisual ~= false then
        SafeCall("hideVisual")
    end

    if next(delayedCastSuccess) == nil and updating then
        updating = false
        updateElapsed = 0
        frame:SetScript("OnUpdate", nil)
    end
    return true
end

function Runtime:ClearDelayedCastSuccessTimers()
    wipe(delayedCastSuccess)
    if next(cooldowns) == nil and updating then
        updating = false
        updateElapsed = 0
        frame:SetScript("OnUpdate", nil)
    end
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

    while cd.currentCharge < maxCharge and cd.nextChargeAt and now >= cd.nextChargeAt do
        cd.currentCharge = cd.currentCharge + 1
        if cd.currentCharge < maxCharge then
            cd.nextChargeAt = cd.nextChargeAt + singleCD
        else
            cd.nextChargeAt = nil
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

        if cd then
            cd = self:SyncCooldownState(primaryKey, now)
            if cd then
                local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
                local isFull = self:EstimateCharges(cd) >= maxCharge
                local remaining = 0
                if not isFull then
                    local nextChargeAt = tonumber(cd.nextChargeAt) or 0
                    remaining = nextChargeAt > 0 and math.max(0, nextChargeAt - now) or 0
                end

                -- Re-apply visual state immediately after editing an entry.  This
                -- makes removing Image/Text hide current visuals right away and
                -- makes adding them take effect during an active cooldown without
                -- waiting for the next spell use.
                CheckAndUpdateVisualChannels(cd, remaining)

                if isFull then
                    cooldowns[primaryKey] = nil
                else
                    active = true
                end
            end
        end
    end

    if active or next(delayedCastSuccess) ~= nil then
        self:StartUpdate()
    elseif updating then
        updating = false
        updateElapsed = 0
        frame:SetScript("OnUpdate", nil)
    end
    return true
end

function Runtime:StartUpdate()
    if updating then
        return
    end

    updating = true
    updateElapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        updateElapsed = updateElapsed + elapsed
        if updateElapsed < GetRuntimeUpdateInterval() then
            return
        end
        updateElapsed = 0

        local now = GetTime()
        local active = false

        for spellId, cd in pairs(cooldowns) do
            if cd then cd.primaryKey = spellId end
            cd = self:SyncCooldownState(spellId, now)
            if cd then
                local maxCharge = math.max(1, math.floor(tonumber(cd.charge) or 1))
                local isFull = self:EstimateCharges(cd) >= maxCharge
                local remaining = 0
                if not isFull then
                    local nextChargeAt = tonumber(cd.nextChargeAt) or 0
                    remaining = nextChargeAt > 0 and math.max(0, nextChargeAt - now) or 0
                end

                -- Cooldown-end visual semantics:
                -- 1) While the cooldown exists, use the live Remaining value.
                -- 2) When the timer reaches the ready state, do one final pass with Remaining = 0.
                -- 3) Delete the cooldown timer immediately after that final pass.
                -- This keeps <=2 / <=0 / =0 visual alerts visible when their condition is
                -- still true at 0, without keeping long-lived OnUpdate cooldown records.
                CheckAndNotifyChannel(cd, "voice", remaining)
                CheckAndUpdateVisualChannels(cd, remaining)

                if isFull then
                    cooldowns[spellId] = nil
                else
                    active = true
                end
            end
        end

        for triggerSpellID, timer in pairs(delayedCastSuccess) do
            local fireAt = tonumber(timer and timer.fireAt) or 0
            if fireAt > 0 and now >= fireAt then
                if tostring(timer and timer.mode or "show") == "hide" then
                    local key = tostring((timer and timer.primaryKey) or "")
                    if key ~= "" then
                        SafeCall("hideVisual", key)
                    end
                else
                    SafeCall("playCastSuccess", timer.cfg)
                end
                delayedCastSuccess[triggerSpellID] = nil
            else
                active = true
            end
        end

        if not active then
            updating = false
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function Runtime:QueueCastSuccessNotification(triggerSpellID, cfg)
    if type(cfg) ~= "table" then
        return false
    end

    triggerSpellID = tonumber(triggerSpellID) or tonumber(cfg.triggerSpellID) or tonumber(cfg.spellId) or 0
    local delaySeconds = math.max(0, tonumber(cfg.delaySeconds) or 0)
    local delayMode = NormalizeCastDelayMode(cfg.castDelayMode)

    local function CopyCastConfig(source)
        source = type(source) == "table" and source or {}
        local copy = {
            primaryKey = tostring(source.primaryKey or (triggerSpellID > 0 and ("cast:" .. tostring(triggerSpellID)) or "")),
            spellId = tonumber(source.spellId) or 0,
            objectID = tonumber(source.objectID or source.spellId) or 0,
            objectType = tostring(source.objectType or OBJECT_TYPE_SPELL),
            triggerSpellID = triggerSpellID,
            spellName = tostring(source.spellName or ""),
            notifyMode = tostring(source.notifyMode or MODE_SOUND),
            ttsText = tostring(source.ttsText or ""),
            ttsRate = math.max(-10, math.min(10, tonumber(source.ttsRate) or 0)),
            soundPath = NormalizeSoundPath(source.soundPath or ""),
            soundSource = tostring(source.soundSource or ""),
            sharedMediaSound = tostring(source.sharedMediaSound or source.sharedMediaName or ""),
            voiceEnabled = source.voiceEnabled ~= false,
            voiceConditionOp = NormalizeConditionOp(source.voiceConditionOp),
            voiceConditionTime = NormalizeConditionTime(source.voiceConditionTime, source.cooldownAlertTime or source.alertLeadTime),
            imageEnabled = source.imageEnabled == true,
            imageConditionOp = NormalizeConditionOp(source.imageConditionOp),
            imageConditionTime = NormalizeConditionTime(source.imageConditionTime, source.cooldownAlertTime or source.alertLeadTime),
            imageSource = tostring(source.imageSource or "auto"),
            imageIconID = math.max(0, tonumber(source.imageIconID) or 0),
            imagePath = tostring(source.imagePath or ""),
            imageSize = math.max(16, tonumber(source.imageSize) or 96),
            imageDurationEnabled = source.imageDurationEnabled == true,
            imageDuration = math.max(0.1, tonumber(source.imageDuration) or 2),
            imageX = tonumber(source.imageX) or 0,
            imageY = tonumber(source.imageY) or 120,
            textEnabled = source.textEnabled == true,
            textConditionOp = NormalizeConditionOp(source.textConditionOp),
            textConditionTime = NormalizeConditionTime(source.textConditionTime, source.cooldownAlertTime or source.alertLeadTime),
            textAlert = tostring(source.textAlert or ""),
            textSize = math.max(8, tonumber(source.textSize) or 24),
            textDurationEnabled = source.textDurationEnabled == true,
            textDuration = math.max(0.1, tonumber(source.textDuration) or 2),
            textX = tonumber(source.textX) or 0,
            textY = tonumber(source.textY) or 120,
            textAttachMode = tostring(source.textAttachMode or "outside"),
            textVAlign = tostring(source.textVAlign or "bottom"),
            textHAlign = tostring(source.textHAlign or "center"),
            textOffsetX = tonumber(source.textOffsetX) or 0,
            textOffsetY = tonumber(source.textOffsetY) or 0,
            delayEnabled = source.delayEnabled == true,
            delaySeconds = delaySeconds,
            castDelayMode = delayMode,
        }
        if Utils.SyncLinkedVisualDurations then
            Utils.SyncLinkedVisualDurations(copy)
        end
        return copy
    end

    if not (cfg.delayEnabled == true and delaySeconds > 0 and triggerSpellID > 0) then
        return SafeCall("playCastSuccess", CopyCastConfig(cfg)) == true
    end

    local castCfg = CopyCastConfig(cfg)

    -- 同一个成功施法触发器再次命中时，覆盖旧倒计时并从当前时刻重新计时。
    -- 1.0.158: cast-success has only two execution modes: immediate or delayed.
    -- Image/Text lifetime is controlled by their own duration checkboxes, so the
    -- old "delay then hide" mode is no longer scheduled here.
    delayedCastSuccess[triggerSpellID] = {
        mode = "show",
        fireAt = GetTime() + delaySeconds,
        cfg = castCfg,
    }
    self:StartUpdate()
    return true
end

ApplyAlertFields = function(target, cfg)
    target.notifyMode = tostring(cfg.notifyMode or MODE_SOUND)
    target.ttsText = tostring(cfg.ttsText or "")
    target.ttsRate = math.max(-10, math.min(10, tonumber(cfg.ttsRate) or 0))
    target.soundPath = NormalizeSoundPath(cfg.soundPath or "")
    target.soundSource = tostring(cfg.soundSource or "")
    target.sharedMediaSound = tostring(cfg.sharedMediaSound or cfg.sharedMediaName or "")
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
    singleCD = tonumber(string.format("%.2f", singleCD)) or singleCD
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
            cd.notified = false
            cd.voiceNotified = false
            cd.imageNotified = false
            cd.textNotified = false
            cd.visualActive = false
            cd.visualChannel = nil
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
                notified = (currentCharge > 0),
                voiceNotified = (currentCharge > 0),
                imageNotified = (currentCharge > 0),
                textNotified = (currentCharge > 0),
                visualActive = false,
                visualChannel = nil,
                spellId = cfg.objectID or cfg.spellId,
            }
            ApplyAlertFields(newCd, cfg)
            cooldowns[primaryKey] = newCd
        end
    end

    self:RefreshRuntimeCooldowns()
    self:StartUpdate()
end
