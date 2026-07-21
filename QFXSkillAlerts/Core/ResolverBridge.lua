local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.ResolverBridge = NS.Core.ResolverBridge or {}

local Bridge = NS.Core.ResolverBridge
local CONST = NS.Constants or {}

local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"

local function GetResolver()
    return (NS.Core and NS.Core.Resolver) or NS.Resolver
end

function Bridge:ResolveSpellName(spellId)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveSpellName) == "function" then
        return resolver:ResolveSpellName(spellId)
    end
    return ""
end

function Bridge:ResolveSpellIcon(spellId)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveSpellIcon) == "function" then
        return resolver:ResolveSpellIcon(spellId)
    end
    return nil
end

function Bridge:ResolveSpellBaseCooldownSeconds(spellId)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveSpellBaseCooldownSeconds) == "function" then
        return resolver:ResolveSpellBaseCooldownSeconds(spellId)
    end
    return nil
end

function Bridge:ResolveItemName(itemID)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveItemName) == "function" then
        return resolver:ResolveItemName(itemID)
    end
    return ""
end

function Bridge:ResolveItemIcon(itemID)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveItemIcon) == "function" then
        return resolver:ResolveItemIcon(itemID)
    end
    return nil
end

function Bridge:ResolveItemUseSpellID(itemID, allowInCombat)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveItemUseSpellID) == "function" then
        return resolver:ResolveItemUseSpellID(itemID, allowInCombat)
    end
    return nil
end

function Bridge:ResolveItemTriggerForEntry(entry, quiet, noQueue, queueFunc)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveItemTriggerForEntry) == "function" then
        return resolver:ResolveItemTriggerForEntry(entry, quiet, noQueue, queueFunc)
    end
    return true
end

function Bridge:ResolveObjectType(objectID, objectType)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveObjectType) == "function" then
        return resolver:ResolveObjectType(objectID, objectType)
    end
    return tostring(objectType or OBJECT_TYPE_SPELL)
end

function Bridge:ResolveObjectName(objectID, objectType)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveObjectName) == "function" then
        return resolver:ResolveObjectName(objectID, objectType)
    end
    return ""
end

function Bridge:ResolveObjectIcon(objectID, objectType)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveObjectIcon) == "function" then
        return resolver:ResolveObjectIcon(objectID, objectType)
    end
    return nil
end

function Bridge:ResolveObjectBaseCooldownSeconds(objectID, objectType)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveObjectBaseCooldownSeconds) == "function" then
        return resolver:ResolveObjectBaseCooldownSeconds(objectID, objectType)
    end
    return nil
end

function Bridge:GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    local resolver = GetResolver()
    if resolver and type(resolver.GetObjectTriggerSpellID) == "function" then
        return resolver:GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    end
    return tonumber(triggerSpellID) or tonumber(objectID) or 0
end

function Bridge:MakeObjectKey(objectType, objectID)
    local resolver = GetResolver()
    if resolver and type(resolver.MakeObjectKey) == "function" then
        return resolver:MakeObjectKey(objectType, objectID)
    end
    return tostring(objectType or OBJECT_TYPE_SPELL) .. ":" .. tostring(math.floor(tonumber(objectID) or 0))
end

function Bridge:ResolveTalentName(talentId)
    local resolver = GetResolver()
    if resolver and type(resolver.ResolveTalentName) == "function" then
        return resolver:ResolveTalentName(talentId)
    end
    return ""
end

function Bridge:IsTalentSelected(talentId)
    local resolver = GetResolver()
    if resolver and type(resolver.IsTalentSelectedCached) == "function" then
        return resolver:IsTalentSelectedCached(talentId)
    elseif resolver and type(resolver.IsTalentSelected) == "function" then
        return resolver:IsTalentSelected(talentId)
    end
    return true
end

function Bridge:InvalidateTalentCache()
    local resolver = GetResolver()
    if resolver and type(resolver.InvalidateTalentCache) == "function" then
        resolver:InvalidateTalentCache()
        return true
    end
    return false
end

function Bridge:BuildSelectedTalentCache()
    local resolver = GetResolver()
    if resolver and type(resolver.BuildSelectedTalentCache) == "function" then
        return resolver:BuildSelectedTalentCache()
    end
    return false
end
