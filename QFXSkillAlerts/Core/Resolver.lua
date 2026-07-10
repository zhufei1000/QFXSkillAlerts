local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.Resolver = NS.Core.Resolver or {}
NS.Resolver = NS.Core.Resolver

local Resolver = NS.Core.Resolver
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local GetSpellInfo = rawget(_G, "GetSpellInfo")
local GetItemInfo = rawget(_G, "GetItemInfo")
local GetItemIcon = rawget(_G, "GetItemIcon")
local GetItemSpell = rawget(_G, "GetItemSpell")

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function RequestItemData(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

function Resolver:ResolveSpellName(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return ""
    end

    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellId)
        if ok and type(name) == "string" then
            return name
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and type(name) == "string" then
            return name
        end
    end

    return ""
end

function Resolver:ResolveSpellIcon(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return nil
    end

    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and (type(icon) == "number" or type(icon) == "string") then
            return icon
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, _, _, icon = pcall(GetSpellInfo, spellId)
        if ok and (type(icon) == "number" or type(icon) == "string") then
            return icon
        end
    end

    return nil
end

function Resolver:ResolveSpellBaseCooldownSeconds(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return nil
    end

    if type(GetSpellBaseCooldown) == "function" then
        local ok, cooldownMS = pcall(GetSpellBaseCooldown, spellId)
        cooldownMS = ok and tonumber(cooldownMS) or 0
        if cooldownMS and cooldownMS > 0 then
            return tonumber(string.format("%.2f", cooldownMS / 1000))
        end
    end

    return nil
end

function Resolver:ResolveItemName(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return ""
    end

    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if C_Item and C_Item.GetItemInfo then
        local ok, name = pcall(C_Item.GetItemInfo, itemID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if type(GetItemInfo) == "function" then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    RequestItemData(itemID)
    return ""
end

function Resolver:ResolveItemIcon(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return nil
    end

    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and (type(icon) == "number" or type(icon) == "string") then
            return icon
        end
    end

    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and (type(icon) == "number" or type(icon) == "string") then
            return icon
        end
    end

    return nil
end

function Resolver:ResolveItemUseSpellInfo(itemID, allowInCombat)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return nil, nil
    end

    if not allowInCombat and IsCombatLocked() then
        RequestItemData(itemID)
        return nil, nil
    end

    if C_Item and C_Item.GetItemSpell then
        local ok, spellName, spellID = pcall(C_Item.GetItemSpell, itemID)
        spellID = ok and tonumber(spellID) or 0
        if spellID and spellID > 0 then
            return tostring(spellName or ""), math.floor(spellID)
        end
    end

    if type(GetItemSpell) == "function" then
        local ok, spellName, spellID = pcall(GetItemSpell, itemID)
        spellID = ok and tonumber(spellID) or 0
        if spellID and spellID > 0 then
            return tostring(spellName or ""), math.floor(spellID)
        end
    end

    RequestItemData(itemID)
    return nil, nil
end

function Resolver:ResolveItemUseSpellID(itemID, allowInCombat)
    local _, spellID = self:ResolveItemUseSpellInfo(itemID, allowInCombat)
    return spellID
end

function Resolver:ResolveItemTriggerForEntry(entry, quiet, noQueue, queueFunc)
    if type(entry) ~= "table" then
        return true
    end

    if tostring(entry.objectType or ""):lower() ~= OBJECT_TYPE_ITEM then
        return true
    end

    local itemID = tonumber(entry.itemID or entry.spellId) or 0
    if itemID <= 0 then
        return false
    end

    entry.objectType = OBJECT_TYPE_ITEM
    entry.itemID = math.floor(itemID)
    entry.spellId = math.floor(itemID)

    local savedTrigger = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
    if savedTrigger > 0 then
        entry.triggerSpellID = math.floor(savedTrigger)
        entry.triggerSpellId = nil
        return true
    end

    if IsCombatLocked() then
        if not noQueue and type(queueFunc) == "function" then
            queueFunc(itemID, entry)
        end
        return false
    end

    local triggerSpellName, triggerSpellID = self:ResolveItemUseSpellInfo(itemID, true)
    triggerSpellID = tonumber(triggerSpellID) or 0
    if triggerSpellID > 0 then
        entry.triggerSpellID = math.floor(triggerSpellID)
        entry.triggerSpellId = nil
        entry.triggerSpellName = tostring(triggerSpellName or entry.triggerSpellName or "")

        if tostring(entry.spellName or "") == "" then
            local itemName = self:ResolveItemName(itemID)
            if itemName ~= "" then
                entry.spellName = itemName
            end
        end
        return true
    end

    if not noQueue and type(queueFunc) == "function" then
        queueFunc(itemID, entry)
    end
    if not quiet and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. L("MSG_ITEM_TRIGGER_PENDING_RESOLVE", tostring(itemID)))
    end
    return false
end

function Resolver:ResolveObjectType(objectID, objectType)
    objectID = tonumber(objectID) or 0
    objectType = tostring(objectType or ""):lower()
    if objectType == OBJECT_TYPE_ITEM then
        return OBJECT_TYPE_ITEM
    end
    if objectType == OBJECT_TYPE_SPELL then
        return OBJECT_TYPE_SPELL
    end

    -- 自动识别：有“使用物品触发法术”的 ID 优先视为物品；否则按技能处理。
    if self:ResolveItemUseSpellID(objectID) then
        return OBJECT_TYPE_ITEM
    end
    if self:ResolveSpellName(objectID) ~= "" then
        return OBJECT_TYPE_SPELL
    end
    if self:ResolveItemName(objectID) ~= "" then
        return OBJECT_TYPE_ITEM
    end
    return OBJECT_TYPE_SPELL
end

function Resolver:ResolveObjectName(objectID, objectType)
    objectID = tonumber(objectID) or 0
    objectType = self:ResolveObjectType(objectID, objectType)
    if objectType == OBJECT_TYPE_ITEM then
        local itemName = self:ResolveItemName(objectID)
        if itemName ~= "" then
            return itemName
        end
    end

    local spellName = self:ResolveSpellName(objectID)
    if spellName ~= "" then
        return spellName
    end

    if objectType ~= OBJECT_TYPE_ITEM then
        return self:ResolveItemName(objectID)
    end
    return ""
end

function Resolver:ResolveObjectIcon(objectID, objectType)
    objectID = tonumber(objectID) or 0
    objectType = self:ResolveObjectType(objectID, objectType)
    if objectType == OBJECT_TYPE_ITEM then
        return self:ResolveItemIcon(objectID) or self:ResolveSpellIcon(objectID)
    end
    return self:ResolveSpellIcon(objectID) or self:ResolveItemIcon(objectID)
end

function Resolver:ResolveObjectBaseCooldownSeconds(objectID, objectType)
    objectType = self:ResolveObjectType(objectID, objectType)
    if objectType == OBJECT_TYPE_ITEM then
        -- 物品冷却继续使用用户填写的固定CD，不主动读取物品冷却，避免引入 Secret Value 逻辑。
        return nil
    end
    return self:ResolveSpellBaseCooldownSeconds(objectID)
end

function Resolver:GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    objectID = tonumber(objectID) or 0
    objectType = self:ResolveObjectType(objectID, objectType)
    triggerSpellID = tonumber(triggerSpellID) or 0
    if triggerSpellID > 0 then
        return math.floor(triggerSpellID)
    end
    if objectID <= 0 then
        return 0
    end
    if objectType == OBJECT_TYPE_ITEM then
        -- 物品不能用物品ID直接匹配 UNIT_SPELLCAST_SUCCEEDED。
        -- 只返回已保存/非战斗解析到的 triggerSpellID；战斗中不会实时拆解。
        return self:ResolveItemUseSpellID(objectID) or 0
    end
    return math.floor(objectID)
end

function Resolver:MakeObjectKey(objectType, objectID)
    objectType = self:ResolveObjectType(objectID, objectType)
    return tostring(objectType) .. ":" .. tostring(math.floor(tonumber(objectID) or 0))
end

function Resolver:ResolveTalentName(talentId)
    talentId = tonumber(talentId) or 0
    if talentId <= 0 then
        return ""
    end

    -- 用户可直接填写“天赋对应的法术ID”。这是最常见、最直观的写法。
    local spellName = self:ResolveSpellName(talentId)
    if spellName ~= "" then
        return spellName
    end

    -- 也兼容填写 TraitDefinitionID：从定义里取 overrideName 或 spellID。
    if C_Traits and C_Traits.GetDefinitionInfo then
        local ok, info = pcall(C_Traits.GetDefinitionInfo, talentId)
        if ok and type(info) == "table" then
            if type(info.overrideName) == "string" and info.overrideName ~= "" then
                return info.overrideName
            end
            if tonumber(info.spellID) and tonumber(info.spellID) > 0 then
                local name = self:ResolveSpellName(info.spellID)
                if name ~= "" then
                    return name
                end
            end
            if tonumber(info.overriddenSpellID) and tonumber(info.overriddenSpellID) > 0 then
                local name = self:ResolveSpellName(info.overriddenSpellID)
                if name ~= "" then
                    return name
                end
            end
        end
    end

    if type(GetPvpTalentInfoByID) == "function" then
        local ok, name = pcall(GetPvpTalentInfoByID, talentId)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return ""
end

function Resolver:GetActiveTalentConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and tonumber(configID) and tonumber(configID) > 0 then
            return tonumber(configID)
        end
    end
    return nil
end

function Resolver:TalentDefinitionMatches(definitionID, talentId)
    talentId = tonumber(talentId) or 0
    definitionID = tonumber(definitionID) or 0
    if talentId <= 0 or definitionID <= 0 then
        return false
    end
    if definitionID == talentId then
        return true
    end
    if C_Traits and C_Traits.GetDefinitionInfo then
        local ok, info = pcall(C_Traits.GetDefinitionInfo, definitionID)
        if ok and type(info) == "table" then
            if tonumber(info.spellID) == talentId then
                return true
            end
            if tonumber(info.overriddenSpellID) == talentId then
                return true
            end
        end
    end
    return false
end

function Resolver:IsTalentSelected(talentId)
    talentId = tonumber(talentId) or 0
    if talentId <= 0 then
        return true
    end

    local configID = self:GetActiveTalentConfigID()
    if not configID or not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo) then
        -- 无法读取天赋树时不要误拦截冷却提示。
        return true
    end

    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfig or type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" then
        return true
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if okNodes and type(nodeIDs) == "table" then
            for _, nodeID in ipairs(nodeIDs) do
                local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okNode and type(nodeInfo) == "table" then
                    local rank = math.max(tonumber(nodeInfo.activeRank) or 0, tonumber(nodeInfo.currentRank) or 0)
                    if rank > 0 then
                        local entryIDs = {}
                        local activeEntry = nodeInfo.activeEntry or nodeInfo.currentEntry
                        if type(activeEntry) == "table" and tonumber(activeEntry.entryID) then
                            entryIDs[#entryIDs + 1] = tonumber(activeEntry.entryID)
                        elseif type(nodeInfo.entryIDs) == "table" then
                            for _, entryID in ipairs(nodeInfo.entryIDs) do
                                entryIDs[#entryIDs + 1] = tonumber(entryID)
                            end
                        end

                        for _, entryID in ipairs(entryIDs) do
                            if entryID and entryID > 0 then
                                local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                                if okEntry and type(entryInfo) == "table" and self:TalentDefinitionMatches(entryInfo.definitionID, talentId) then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end
