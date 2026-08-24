local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.NotifierBridge = NS.Core.NotifierBridge or {}

local Bridge = NS.Core.NotifierBridge

local function GetNotifier()
    return (NS.Core and NS.Core.Notifier) or NS.Notifier
end

function Bridge:GetNotifier()
    return GetNotifier()
end

function Bridge:NormalizeSoundPath(path)
    local notifier = GetNotifier()
    if notifier and type(notifier.NormalizeSoundPath) == "function" then
        return notifier:NormalizeSoundPath(path)
    end
    local utils = NS.Utils or {}
    if utils.CanonicalPath then
        return utils.CanonicalPath(path)
    end
    return tostring(path or ""):gsub("/", "\\")
end

function Bridge:ResolveEntrySoundPath(entry)
    local notifier = GetNotifier()
    if notifier and type(notifier.ResolveEntrySoundPath) == "function" then
        return notifier:ResolveEntrySoundPath(entry)
    end
    return self:NormalizeSoundPath(type(entry) == "table" and entry.soundPath or entry)
end

function Bridge:PlayReadyNotification(cfg, alertChannel, remaining, primaryKey)
    local notifier = GetNotifier()
    if notifier and type(notifier.PlayReadyNotification) == "function" then
        return notifier:PlayReadyNotification(cfg, alertChannel, remaining, primaryKey)
    end
    return false
end

function Bridge:PlayCastSuccessNotification(cfg, triggerSpellID, castGUID)
    local notifier = GetNotifier()
    if notifier and type(notifier.PlayCastSuccessNotification) == "function" then
        return notifier:PlayCastSuccessNotification(cfg, triggerSpellID, castGUID)
    end
    return false
end

function Bridge:PlayEventNotification(cfg)
    local notifier = GetNotifier()
    if notifier and type(notifier.PlayEventNotification) == "function" then
        return notifier:PlayEventNotification(cfg)
    end
    return false
end

function Bridge:HideVisualAlerts(exceptKind)
    local notifier = GetNotifier()
    if notifier and type(notifier.HideVisualAlerts) == "function" then
        notifier:HideVisualAlerts(exceptKind)
        return true
    end
    return false
end

function Bridge:UpdateCooldownCountdown(cfg, remaining, primaryKey)
    local notifier = GetNotifier()
    if notifier and type(notifier.UpdateCooldownCountdown) == "function" then
        return notifier:UpdateCooldownCountdown(cfg, remaining, primaryKey)
    end
    return false
end

function Bridge:HideCooldownCountdown(primaryKey)
    local notifier = GetNotifier()
    if notifier and type(notifier.HideCooldownCountdown) == "function" then
        return notifier:HideCooldownCountdown(primaryKey)
    end
    return false
end

function Bridge:RefreshActiveVisualForKey(primaryKey, cfg, fallbackText)
    local notifier = GetNotifier()
    if notifier and type(notifier.RefreshActiveVisualForKey) == "function" then
        return notifier:RefreshActiveVisualForKey(primaryKey, cfg, fallbackText)
    end
    return false
end
