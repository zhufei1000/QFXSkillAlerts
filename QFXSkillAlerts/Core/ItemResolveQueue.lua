local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS
NS.Core = NS.Core or {}

local ItemResolveQueue = NS.Core.ItemResolveQueue or {}
NS.Core.ItemResolveQueue = ItemResolveQueue
NS.ItemResolveQueue = ItemResolveQueue

local pending = ItemResolveQueue.pending or {}
ItemResolveQueue.pending = pending

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

function ItemResolveQueue:Configure(callbacks)
    self.callbacks = callbacks or {}
end

function ItemResolveQueue:RequestItemData(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return false
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
        return true
    end
    return false
end

function ItemResolveQueue:Queue(itemID, entry)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 or type(entry) ~= "table" then
        return false
    end

    local bucket = pending[itemID]
    if type(bucket) ~= "table" then
        bucket = {}
        pending[itemID] = bucket
    end

    for _, existing in ipairs(bucket) do
        if existing == entry then
            self:RequestItemData(itemID)
            return false
        end
    end

    bucket[#bucket + 1] = entry
    self:RequestItemData(itemID)
    return true
end

local function WalkItemEntries(root, callback)
    if type(root) ~= "table" or type(callback) ~= "function" then
        return false
    end

    local changed = false
    for _, classMap in pairs(root) do
        if type(classMap) == "table" then
            for _, specMap in pairs(classMap) do
                if type(specMap) == "table" then
                    for _, entry in pairs(specMap) do
                        if type(entry) == "table" and tostring(entry.objectType or ""):lower() == "item" then
                            if callback(entry) then
                                changed = true
                            end
                        end
                    end
                end
            end
        end
    end
    return changed
end

function ItemResolveQueue:ResolveAllStored(quiet)
    local callbacks = self.callbacks or {}
    local ensureDB = callbacks.ensureDB
    local resolveItemTriggerForEntry = callbacks.resolveItemTriggerForEntry
    if type(ensureDB) ~= "function" or type(resolveItemTriggerForEntry) ~= "function" then
        return false
    end

    local db = ensureDB()
    local changed = false

    local function resolveEntry(entry)
        local before = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
        resolveItemTriggerForEntry(entry, quiet)
        local after = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
        return before <= 0 and after > 0
    end

    changed = WalkItemEntries(db.specConfigs, resolveEntry) or changed
    changed = WalkItemEntries(db.castSuccessConfigs, resolveEntry) or changed
    return changed
end

function ItemResolveQueue:ResolvePending(suppressRefresh)
    if IsCombatLocked() then
        return false
    end

    local callbacks = self.callbacks or {}
    local resolveItemTriggerForEntry = callbacks.resolveItemTriggerForEntry
    if type(resolveItemTriggerForEntry) ~= "function" then
        return false
    end

    local changed = false

    for itemID, entries in pairs(pending) do
        local keep = {}
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if type(entry) == "table" then
                    local before = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
                    local ok = resolveItemTriggerForEntry(entry, true, true)
                    local after = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
                    if ok and before <= 0 and after > 0 then
                        changed = true
                    elseif not ok then
                        keep[#keep + 1] = entry
                    end
                end
            end
        end

        if #keep > 0 then
            pending[itemID] = keep
        else
            pending[itemID] = nil
        end
    end

    if changed and suppressRefresh ~= true then
        if type(callbacks.rebuildRuntimeConfig) == "function" then
            callbacks.rebuildRuntimeConfig()
        end
        if type(callbacks.rebuildCastSuccessConfig) == "function" then
            callbacks.rebuildCastSuccessConfig()
        end
        if type(callbacks.refreshRuntimeCooldowns) == "function" then
            callbacks.refreshRuntimeCooldowns()
        end
        if type(callbacks.refreshPanel) == "function" then
            callbacks.refreshPanel()
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(tostring(callbacks.chatPrefix or "") .. " " .. L("MSG_ITEM_TRIGGER_AUTO_FILLED"))
        end
    end

    return changed
end

local function RunQueueStep(callback)
    if type(callback) ~= "function" then
        return
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

function ItemResolveQueue:CollectStoredItemEntries()
    local callbacks = self.callbacks or {}
    local ensureDB = callbacks.ensureDB
    if type(ensureDB) ~= "function" then
        return {}
    end

    local db = ensureDB()
    local entries = {}
    local function collect(entry)
        entries[#entries + 1] = entry
        return false
    end

    WalkItemEntries(db.specConfigs, collect)
    WalkItemEntries(db.castSuccessConfigs, collect)
    return entries
end

function ItemResolveQueue:ResolveAllStoredBatched(quiet, onDone, batchSize)
    local callbacks = self.callbacks or {}
    local resolveItemTriggerForEntry = callbacks.resolveItemTriggerForEntry
    if type(resolveItemTriggerForEntry) ~= "function" then
        if type(onDone) == "function" then
            onDone(false)
        end
        return false
    end

    local entries = self:CollectStoredItemEntries()
    local total = #entries
    local index = 1
    local changed = false
    batchSize = math.max(1, math.floor(tonumber(batchSize) or 24))

    local function step()
        local processed = 0
        while index <= total and processed < batchSize do
            local entry = entries[index]
            index = index + 1
            processed = processed + 1
            if type(entry) == "table" then
                local before = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
                resolveItemTriggerForEntry(entry, quiet)
                local after = tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0
                if before <= 0 and after > 0 then
                    changed = true
                end
            end
        end

        if index <= total then
            RunQueueStep(step)
        else
            if type(onDone) == "function" then
                onDone(changed)
            end
        end
    end

    RunQueueStep(step)
    return true
end
