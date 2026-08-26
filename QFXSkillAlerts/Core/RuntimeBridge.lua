local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.RuntimeBridge = NS.Core.RuntimeBridge or {}

local Bridge = NS.Core.RuntimeBridge

local function GetRuntime()
    return (NS.Core and NS.Core.Runtime) or NS.Runtime
end

function Bridge:GetRuntime()
    return GetRuntime()
end

function Bridge:WipeCooldowns(hideVisual)
    local runtime = GetRuntime()
    if runtime and type(runtime.WipeCooldowns) == "function" then
        return runtime:WipeCooldowns(hideVisual)
    end
    return false
end

function Bridge:ClearDelayedCastSuccessTimers()
    local runtime = GetRuntime()
    if runtime and type(runtime.ClearDelayedCastSuccessTimers) == "function" then
        return runtime:ClearDelayedCastSuccessTimers()
    end
    return false
end

function Bridge:QueueCastSuccessNotification(triggerSpellID, cfg, fallback)
    local runtime = GetRuntime()
    if runtime and type(runtime.QueueCastSuccessNotification) == "function" then
        return runtime:QueueCastSuccessNotification(triggerSpellID, cfg)
    end
    if type(fallback) == "function" then
        return fallback(cfg, triggerSpellID)
    end
    return false
end

function Bridge:RefreshRuntimeCooldowns(mappedRuntimeCfg)
    local runtime = GetRuntime()
    if runtime and type(runtime.RefreshRuntimeCooldowns) == "function" then
        return runtime:RefreshRuntimeCooldowns(mappedRuntimeCfg)
    end
    return false
end

function Bridge:ApplyEditorVisualState(primaryKey, cfg)
    local runtime = GetRuntime()
    if runtime and type(runtime.ApplyEditorVisualState) == "function" then
        return runtime:ApplyEditorVisualState(primaryKey, cfg)
    end
    return false
end

function Bridge:StartCooldown(spellId, mappedSpellToPrimary, mappedRuntimeCfg)
    local runtime = GetRuntime()
    if runtime and type(runtime.StartCooldown) == "function" then
        return runtime:StartCooldown(spellId, mappedSpellToPrimary, mappedRuntimeCfg)
    end
    return nil
end
