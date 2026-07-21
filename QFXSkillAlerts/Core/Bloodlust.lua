local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Bloodlust = NS.Core.Bloodlust or {}

local Bloodlust = NS.Core.Bloodlust
local CONST = NS.Constants or {}

local EXHAUSTION_IDS = CONST.EXHAUSTION_IDS or { 57723, 57724, 80354, 95809, 160455, 207400, 264689, 390435 }
local EXHAUSTION_DURATION = CONST.EXHAUSTION_DURATION or 600
local FRESH_WINDOW = CONST.FRESH_WINDOW or 5
local EXHAUSTION_ID_SET = {}
for _, spellID in ipairs(EXHAUSTION_IDS) do
    EXHAUSTION_ID_SET[tonumber(spellID)] = true
end

local customSoundPaths = {}
local runtimeConfig = {
    customSoundPaths = customSoundPaths,
    voiceEnabled = true,
    voiceConditionOp = "<=",
    voiceConditionTime = 0,
    soundSource = "custom",
    notifyMode = CONST.MODE_SOUND or "sound",
}
local lastExpiration = 0

local function SafeNormalize(normalizeSoundPath, path)
    if type(normalizeSoundPath) == "function" then
        return normalizeSoundPath(path)
    end
    return tostring(path or ""):gsub("/", "\\")
end

local function Trim(value)
    local utils = NS.Utils or {}
    if utils.TrimText then
        return utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function CopyConfigFromDB(cfg, normalizeSoundPath)
    runtimeConfig.customSoundPaths = customSoundPaths
    runtimeConfig.voiceEnabled = cfg.voiceEnabled ~= false
    runtimeConfig.voiceConditionOp = tostring(cfg.voiceConditionOp or "<=")
    runtimeConfig.voiceConditionTime = math.max(0, tonumber(cfg.voiceConditionTime) or 0)
    runtimeConfig.notifyMode = tostring(cfg.notifyMode or CONST.MODE_SOUND or "sound")
    runtimeConfig.soundSource = tostring(cfg.soundSource or "custom")
    runtimeConfig.soundPath = SafeNormalize(normalizeSoundPath, cfg.soundPath or "")
    runtimeConfig.builtinSoundPath = SafeNormalize(normalizeSoundPath, cfg.builtinSoundPath or "")
    runtimeConfig.customSoundPath = SafeNormalize(normalizeSoundPath, cfg.customSoundPath or "")
    runtimeConfig.sharedMediaSound = Trim(cfg.sharedMediaSound or cfg.sharedMediaName or "")
    runtimeConfig.ttsText = tostring(cfg.ttsText or "")
    runtimeConfig.ttsRate = math.max(-10, math.min(10, tonumber(cfg.ttsRate) or 0))
    runtimeConfig.imageEnabled = cfg.imageEnabled == true
    runtimeConfig.imageConditionOp = tostring(cfg.imageConditionOp or "<=")
    runtimeConfig.imageConditionTime = math.max(0, tonumber(cfg.imageConditionTime) or 0)
    runtimeConfig.imageSource = tostring(cfg.imageSource or "auto")
    runtimeConfig.imageIconID = math.max(0, tonumber(cfg.imageIconID) or 0)
    runtimeConfig.imagePath = Trim(cfg.imagePath or "")
    runtimeConfig.imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
    runtimeConfig.imageDurationEnabled = cfg.imageDurationEnabled == true
    runtimeConfig.imageDuration = math.max(0.1, tonumber(cfg.imageDuration) or 2)
    runtimeConfig.imageX = tonumber(cfg.imageX) or 0
    runtimeConfig.imageY = tonumber(cfg.imageY) or 120
    runtimeConfig.textEnabled = cfg.textEnabled == true
    runtimeConfig.textConditionOp = tostring(cfg.textConditionOp or "<=")
    runtimeConfig.textConditionTime = math.max(0, tonumber(cfg.textConditionTime) or 0)
    runtimeConfig.textAlert = tostring(cfg.textAlert or "")
    runtimeConfig.textSize = math.max(8, tonumber(cfg.textSize) or 24)
    runtimeConfig.textDurationEnabled = cfg.textDurationEnabled == true
    runtimeConfig.textDuration = math.max(0.1, tonumber(cfg.textDuration) or 2)
    local utils = NS.Utils or {}
    if utils.SyncLinkedVisualDurations then
        utils.SyncLinkedVisualDurations(runtimeConfig)
    end
    runtimeConfig.textX = tonumber(cfg.textX) or 0
    runtimeConfig.textY = tonumber(cfg.textY) or 120
    runtimeConfig.textAttachMode = tostring(cfg.textAttachMode or "outside")
    runtimeConfig.textVAlign = tostring(cfg.textVAlign or "bottom")
    runtimeConfig.textHAlign = tostring(cfg.textHAlign or "center")
    runtimeConfig.textOffsetX = tonumber(cfg.textOffsetX) or 0
    runtimeConfig.textOffsetY = tonumber(cfg.textOffsetY) or 0
    runtimeConfig.spellName = tostring(cfg.spellName or "Bloodlust")
end

function Bloodlust:GetRuntimeConfig()
    return runtimeConfig
end

function Bloodlust:Rebuild(db, normalizeSoundPath)
    wipe(customSoundPaths)

    local cfg = type(db) == "table" and type(db.bloodlustConfig) == "table" and db.bloodlustConfig or nil
    if type(cfg) ~= "table" then
        CopyConfigFromDB({}, normalizeSoundPath)
        return false
    end

    local source = type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths or {}
    for i = 1, 5 do
        customSoundPaths[i] = SafeNormalize(normalizeSoundPath, source[i] or "")
    end
    if Trim(cfg.customSoundPath or "") ~= "" and Trim(customSoundPaths[1] or "") == "" then
        customSoundPaths[1] = SafeNormalize(normalizeSoundPath, cfg.customSoundPath)
    end

    CopyConfigFromDB(cfg, normalizeSoundPath)
    return true
end

function Bloodlust:PlayNotification(cfg, notifier)
    if notifier and type(notifier.PlayBloodlustNotification) == "function" then
        return notifier:PlayBloodlustNotification(cfg or self:GetRuntimeConfig(), customSoundPaths)
    end
    return false
end

function Bloodlust:CheckExhaustionFresh()
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
        return false, nil
    end

    local now = GetTime()
    for _, spellId in ipairs(EXHAUSTION_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if aura and aura.expirationTime then
            local remaining = (tonumber(aura.expirationTime) or 0) - now
            if remaining >= (EXHAUSTION_DURATION - FRESH_WINDOW) then
                return true, tonumber(aura.expirationTime) or 0
            end
        end
    end

    return false, nil
end

local function GetReadableAuraSpellID(aura)
    if type(aura) ~= "table" then
        return nil, true
    end
    local ok, spellID = pcall(function()
        return tonumber(aura.spellId or aura.spellID)
    end)
    return ok and spellID or nil, ok
end

function Bloodlust:UpdateMayContainExhaustion(updateInfo)
    if type(updateInfo) ~= "table" or updateInfo.isFullUpdate == true then
        return true
    end

    for _, aura in ipairs(type(updateInfo.addedAuras) == "table" and updateInfo.addedAuras or {}) do
        local spellID, readable = GetReadableAuraSpellID(aura)
        if not readable or EXHAUSTION_ID_SET[spellID] then
            return true
        end
    end

    local updated = type(updateInfo.updatedAuraInstanceIDs) == "table"
        and updateInfo.updatedAuraInstanceIDs or {}
    if #updated > 0 then
        if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByAuraInstanceID) ~= "function" then
            return true
        end
        for _, auraInstanceID in ipairs(updated) do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", auraInstanceID)
            if not ok then
                return true
            end
            local spellID, readable = GetReadableAuraSpellID(aura)
            if not readable or EXHAUSTION_ID_SET[spellID] then
                return true
            end
        end
    end

    -- Removed auras cannot represent a newly applied exhaustion effect.
    return false
end

function Bloodlust:HandleUnitAura(unit, notifier, updateInfo)
    if unit ~= "player" then
        return false
    end
    local filterOK, mayContainExhaustion = pcall(self.UpdateMayContainExhaustion, self, updateInfo)
    if filterOK and not mayContainExhaustion then
        return false
    end

    local isFresh, expirationTime = self:CheckExhaustionFresh()
    if isFresh and expirationTime and expirationTime > 0 and expirationTime ~= lastExpiration then
        lastExpiration = expirationTime
        return self:PlayNotification(nil, notifier)
    end

    return false
end
