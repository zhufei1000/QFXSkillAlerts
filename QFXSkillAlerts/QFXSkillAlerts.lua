QFXSkillAlertsDB = (type(QFXSkillAlertsDB) == "table") and QFXSkillAlertsDB or {}

local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

local CONST = NS.Constants or {}
local ENTRY_MIN = CONST.ENTRY_MIN or 1
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local MODE_TTS = CONST.MODE_TTS or "tts"
local MODE_SOUND = CONST.MODE_SOUND or "sound"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
NS.ADDON_DISPLAY_NAME = NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME")
NS.ADDON_SHORT_NAME = NS.ADDON_SHORT_NAME or L("ADDON_SHORT_NAME")
NS.ADDON_CHAT_PREFIX = "|cffff7f50[QFX-SA]|r"
NS.ADDON_ICON = "Interface\\AddOns\\QFXSkillAlerts\\AppIcon.png"

local frame = CreateFrame("Frame")
local CONFIG_ADDON_NAME = "QFXSkillAlerts_Config"

function NS.LoadConfigAddon(silent)
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function" then
        return true
    end

    local loaded = false
    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        local ok, reason = C_AddOns.LoadAddOn(CONFIG_ADDON_NAME)
        loaded = ok == true
        if not loaded and not silent and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. tostring(reason or CONFIG_ADDON_NAME))
        end
    elseif type(LoadAddOn) == "function" then
        local ok, reason = LoadAddOn(CONFIG_ADDON_NAME)
        loaded = ok == true or ok == 1
        if not loaded and not silent and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage((NS.ADDON_CHAT_PREFIX or "") .. " " .. tostring(reason or CONFIG_ADDON_NAME))
        end
    end

    if loaded and NS.AceOptions and type(NS.AceOptions.Initialize) == "function" then
        NS.AceOptions:Initialize()
    end
    return loaded and NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function"
end

-- 物品支持说明：
-- 真实物品ID用于显示名称/图标；物品使用后触发的法术ID(triggerSpellID)用于 UNIT_SPELLCAST_SUCCEEDED 监听。
-- GetItemSpell / C_Item.GetItemSpell 只在非战斗或资料加载回调里解析；战斗中只使用已保存的 triggerSpellID。
local function GetItemResolveQueue()
    return (NS.Core and NS.Core.ItemResolveQueue) or NS.ItemResolveQueue
end

local function QueueItemResolve(itemID, entry)
    local queue = GetItemResolveQueue()
    if queue and type(queue.Queue) == "function" then
        return queue:Queue(itemID, entry)
    end
    return false
end

local MAPPED_SPELL_TO_PRIMARY = {}
local MAPPED_RUNTIME_CFG = {}

local UPDATE_INTERVAL_COMBAT = CONST.UPDATE_INTERVAL_COMBAT or 0.03
local UPDATE_INTERVAL_IDLE = CONST.UPDATE_INTERVAL_IDLE or 0.08

local function GetScope()
    return (NS.Core and NS.Core.Scope) or NS.Scope
end

local function GetCurrentClassSpec()
    local scope = GetScope()
    if scope and type(scope.GetCurrentClassSpec) == "function" then
        return scope:GetCurrentClassSpec()
    end
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return classID or 0, specID or 0
end

local function GetEntryMapStore()
    return NS.Core and NS.Core.EntryMap
end

local function EnsureSpecTable(root, classID, specID)
    local store = GetEntryMapStore()
    if store and type(store.EnsureSpecTable) == "function" then
        return store:EnsureSpecTable(root, classID, specID)
    end
    return nil
end

local function GetSpecTable(root, classID, specID)
    local store = GetEntryMapStore()
    if store and type(store.GetSpecTable) == "function" then
        return store:GetSpecTable(root, classID, specID)
    end
    return nil
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function IsItemEquippedForLoad(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return false end
    if C_Item and type(C_Item.IsEquippedItem) == "function" then
        local ok, equipped = pcall(C_Item.IsEquippedItem, itemID)
        if ok and equipped ~= nil then return equipped == true end
    end
    if type(IsEquippedItem) == "function" then
        local ok, equipped = pcall(IsEquippedItem, itemID)
        if ok and equipped ~= nil then return equipped == true end
    end
    if type(GetInventoryItemID) == "function" then
        for slot = 1, 19 do
            local equippedID = GetInventoryItemID("player", slot)
            if tonumber(equippedID) == itemID then
                return true
            end
        end
    end
    return false
end

local bagItemIDCache = {}
local bagItemNameCache = {}
local bagItemNameByIDCache = {}
local bagCacheValid = false
local bagCacheDirty = true

local function TrimItemLoadName(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function ResolveBagCacheItemName(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return "" end
    local cached = bagItemNameByIDCache[itemID]
    if cached ~= nil then
        return cached
    end
    local name = ""
    if C_Item and type(C_Item.GetItemNameByID) == "function" then
        local ok, value = pcall(C_Item.GetItemNameByID, itemID)
        if ok then
            name = TrimItemLoadName(value)
        end
    end
    if name == "" and type(GetItemInfo) == "function" then
        local ok, value = pcall(GetItemInfo, itemID)
        if ok then
            name = TrimItemLoadName(value)
        end
    end
    bagItemNameByIDCache[itemID] = name
    return name
end

local function ClearBagItemCache()
    wipe(bagItemIDCache)
    wipe(bagItemNameCache)
end

local function MarkBagItemCacheDirty()
    bagCacheDirty = true
end

local function RebuildBagItemCache()
    ClearBagItemCache()
    local bagIDs = { 0, 1, 2, 3, 4 }
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        bagIDs[#bagIDs + 1] = Enum.BagIndex.ReagentBag
    end
    for _, bagID in ipairs(bagIDs) do
        local slots = 0
        if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
            slots = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
        elseif type(GetContainerNumSlots) == "function" then
            slots = tonumber(GetContainerNumSlots(bagID)) or 0
        end
        for slot = 1, slots do
            local currentID = nil
            if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                if type(info) == "table" then
                    currentID = info.itemID
                end
            end
            if not currentID then
                if C_Container and type(C_Container.GetContainerItemID) == "function" then
                    currentID = C_Container.GetContainerItemID(bagID, slot)
                elseif type(GetContainerItemID) == "function" then
                    currentID = GetContainerItemID(bagID, slot)
                end
            end
            currentID = tonumber(currentID) or 0
            if currentID > 0 then
                currentID = math.floor(currentID)
                bagItemIDCache[currentID] = true
                local itemName = ResolveBagCacheItemName(currentID)
                if itemName ~= "" then
                    bagItemNameCache[itemName] = true
                end
            end
        end
    end
    bagCacheValid = true
    bagCacheDirty = false
    return true
end

local function EnsureBagItemCache()
    if bagCacheValid and (not bagCacheDirty or IsCombatLocked()) then
        return true
    end
    if IsCombatLocked() then
        return bagCacheValid
    end
    return RebuildBagItemCache()
end

local function IsItemInBagsForLoad(itemID, matchSameName)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return false end
    itemID = math.floor(itemID)
    if not EnsureBagItemCache() then
        return false
    end
    if bagItemIDCache[itemID] == true then
        return true
    end
    if matchSameName == true then
        local itemName = ResolveBagCacheItemName(itemID)
        if itemName ~= "" and bagItemNameCache[itemName] == true then
            return true
        end
    end
    return false
end

local function IsItemLoadRequirementMet(entry)
    if type(entry) ~= "table" then return false end
    if tostring(entry.objectType or ""):lower() ~= OBJECT_TYPE_ITEM then
        return true
    end
    local mode = NormalizeItemLoadMode(entry.itemLoadMode)
    if mode == ITEM_LOAD_NONE then
        return true
    end
    local itemID = tonumber(entry.itemID or entry.spellId) or 0
    if itemID <= 0 then
        return false
    end
    if mode == ITEM_LOAD_EQUIPPED then
        return IsItemEquippedForLoad(itemID)
    elseif mode == ITEM_LOAD_BAGS then
        return IsItemInBagsForLoad(itemID, entry.itemLoadSameName == true)
    end
    return true
end

local function IsActiveScopeLoaded(entryClassID, entrySpecID, currentClassID, currentSpecID)
    local scope = GetScope()
    if scope and type(scope.IsActiveScopeLoaded) == "function" then
        return scope:IsActiveScopeLoaded(entryClassID, entrySpecID, currentClassID, currentSpecID)
    end

    entryClassID = tonumber(entryClassID) or 0
    entrySpecID = tonumber(entrySpecID) or 0
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0

    if entryClassID == ALL_CLASSES_ID then
        return true
    end

    return entryClassID == currentClassID and (entrySpecID == currentSpecID or entrySpecID == ALL_SPECS_ID)
end

local function EnsureDB()
    local db = QFXSkillAlertsDB
    if type(db) ~= "table" then
        db = {}
        QFXSkillAlertsDB = db
    end
    if type(db.specConfigs) ~= "table" then
        db.specConfigs = {}
    end
    if type(db.castSuccessConfigs) ~= "table" then
        db.castSuccessConfigs = {}
    end
    if type(db.bloodlustConfig) ~= "table" then
        db.bloodlustConfig = {}
    end
    if type(db.bloodlustConfig.customSoundPaths) ~= "table" then
        db.bloodlustConfig.customSoundPaths = { "", "", "", "", "" }
    else
        for i = 1, 5 do
            db.bloodlustConfig.customSoundPaths[i] = db.bloodlustConfig.customSoundPaths[i] or ""
        end
    end
    if db.bloodlustConfig.voiceEnabled == nil then
        db.bloodlustConfig.voiceEnabled = true
    end
    if type(db.bloodlustConfig.soundSource) ~= "string" then
        db.bloodlustConfig.soundSource = "custom"
    end
    db.bloodlustConfig.imageEnabled = db.bloodlustConfig.imageEnabled == true
    db.bloodlustConfig.textEnabled = db.bloodlustConfig.textEnabled == true
    if type(db.deletedEntries) ~= "table" then
        db.deletedEntries = {}
    end
    if type(db.cdmVoiceRegistry) ~= "table" then
        db.cdmVoiceRegistry = {}
    end
    if type(db.cdmVoiceRegistry.byIdentity) ~= "table" then
        db.cdmVoiceRegistry.byIdentity = {}
    end
    if type(db.cdmVoiceRegistry.byPayload) ~= "table" then
        db.cdmVoiceRegistry.byPayload = {}
    end
    if type(db.cdmVoiceRegistry.collisionMap) ~= "table" then
        db.cdmVoiceRegistry.collisionMap = {}
    end
    if type(db.cdmVoiceUI) ~= "table" then
        db.cdmVoiceUI = { lastCategory = nil }
    end
    if type(db.cdmVoiceProfiles) ~= "table" then
        db.cdmVoiceProfiles = {}
    end
    if type(db.cdmVoiceDisabledPresets) ~= "table" then
        db.cdmVoiceDisabledPresets = {}
    end
    if type(db.cdmVoicePendingRemovals) ~= "table" then
        db.cdmVoicePendingRemovals = {}
    end
    if type(db.cdmVoiceApplyState) ~= "table" then
        db.cdmVoiceApplyState = { applyInProgress = false }
    elseif db.cdmVoiceApplyState.applyInProgress == nil then
        db.cdmVoiceApplyState.applyInProgress = false
    end
    if type(db.cdmVoiceSyncState) ~= "table" then
        db.cdmVoiceSyncState = {}
    end
    if type(db.cdmVoiceSyncState.importedVersion) ~= "number" then
        db.cdmVoiceSyncState.importedVersion = 0
    end
    if db.cdmVoiceSyncState.pendingRuntimeReload == nil then
        db.cdmVoiceSyncState.pendingRuntimeReload = false
    end
    if type(db.languageMode) ~= "string" then
        db.languageMode = "auto"
    end
    return db
end


local function GetDeletedEntryStore()
    return (NS.Core and NS.Core.DeletedEntryStore) or NS.DeletedEntryStore
end

local function MarkEntryDeleted(classID, specID, entry, index)
    local store = GetDeletedEntryStore()
    if store and type(store.Mark) == "function" then
        return store:Mark(EnsureDB(), classID, specID, entry, index)
    end
    return false
end

local function ClearEntryDeletedMarker(classID, specID, entry, index)
    local store = GetDeletedEntryStore()
    if store and type(store.Clear) == "function" then
        return store:Clear(EnsureDB(), classID, specID, entry, index)
    end
    return false
end

local function IsEntryMarkedDeleted(classID, specID, entry, index)
    local store = GetDeletedEntryStore()
    if store and type(store.IsMarked) == "function" then
        return store:IsMarked(EnsureDB(), classID, specID, entry, index)
    end
    return false
end

local function PurgeDeletedEntries()
    local store = GetDeletedEntryStore()
    if store and type(store.Purge) == "function" then
        return store:Purge(EnsureDB())
    end
    return false
end

local function EnsureCastSuccessMap(classID, specID)
    local specMap = EnsureSpecTable(EnsureDB().castSuccessConfigs, classID, specID)
    if type(specMap) ~= "table" then
        return nil
    end
    return specMap
end

local function GetCastSuccessMap(classID, specID)
    local map = GetSpecTable(EnsureDB().castSuccessConfigs, classID, specID)
    if type(map) ~= "table" then
        return {}
    end
    return map
end

local function EnsureEntryMap(classID, specID)
    local specMap = EnsureSpecTable(EnsureDB().specConfigs, classID, specID)
    if type(specMap) ~= "table" then
        return nil
    end
    return specMap
end

local function GetStoredEntryMap(classID, specID)
    local map = GetSpecTable(EnsureDB().specConfigs, classID, specID)
    if type(map) ~= "table" then
        return {}
    end
    return map
end

local function GetEntry(map, index)
    local store = GetEntryMapStore()
    if store and type(store.GetEntry) == "function" then
        return store:GetEntry(map, index)
    end
    return nil
end

local function GetOrderedEntryIndices(map)
    local store = GetEntryMapStore()
    if store and type(store.GetOrderedEntryIndices) == "function" then
        return store:GetOrderedEntryIndices(map)
    end
    return {}
end

local function ResolveSpellName(spellId)
    return NS.Core.ResolverBridge:ResolveSpellName(spellId)
end

local function ResolveSpellIcon(spellId)
    return NS.Core.ResolverBridge:ResolveSpellIcon(spellId)
end

local function ResolveSpellBaseCooldownSeconds(spellId)
    return NS.Core.ResolverBridge:ResolveSpellBaseCooldownSeconds(spellId)
end

local function ResolveItemName(itemID)
    return NS.Core.ResolverBridge:ResolveItemName(itemID)
end

local function ResolveItemIcon(itemID)
    return NS.Core.ResolverBridge:ResolveItemIcon(itemID)
end

local function ResolveItemUseSpellID(itemID, allowInCombat)
    return NS.Core.ResolverBridge:ResolveItemUseSpellID(itemID, allowInCombat)
end

local function ResolveItemTriggerForEntry(entry, quiet, noQueue)
    return NS.Core.ResolverBridge:ResolveItemTriggerForEntry(entry, quiet, noQueue, QueueItemResolve)
end

local function ResolveObjectType(objectID, objectType)
    return NS.Core.ResolverBridge:ResolveObjectType(objectID, objectType)
end

local function ResolveObjectName(objectID, objectType)
    return NS.Core.ResolverBridge:ResolveObjectName(objectID, objectType)
end

local function ResolveObjectIcon(objectID, objectType)
    return NS.Core.ResolverBridge:ResolveObjectIcon(objectID, objectType)
end

local function ResolveObjectBaseCooldownSeconds(objectID, objectType)
    return NS.Core.ResolverBridge:ResolveObjectBaseCooldownSeconds(objectID, objectType)
end

local function GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
    return NS.Core.ResolverBridge:GetObjectTriggerSpellID(objectID, objectType, triggerSpellID)
end

local function MakeObjectKey(objectType, objectID)
    return NS.Core.ResolverBridge:MakeObjectKey(objectType, objectID)
end

local function ResolveTalentName(talentId)
    return NS.Core.ResolverBridge:ResolveTalentName(talentId)
end

local function IsTalentSelected(talentId)
    return NS.Core.ResolverBridge:IsTalentSelected(talentId)
end

local function GetRuntimeUpdateInterval()
    return UnitAffectingCombat("player") and UPDATE_INTERVAL_COMBAT or UPDATE_INTERVAL_IDLE
end

local function GetNotifier()
    return NS.Core.NotifierBridge:GetNotifier()
end

local function GetRuntime()
    return NS.Core.RuntimeBridge:GetRuntime()
end

local function GetRuntimeConfigBuilder()
    return NS.Core and NS.Core.RuntimeConfigBuilder
end

local function GetBloodlust()
    return (NS.Core and NS.Core.Bloodlust) or NS.Bloodlust
end

local function GetCastSuccess()
    return (NS.Core and NS.Core.CastSuccess) or NS.CastSuccess
end

local function GetCustomRuntime()
    return nil
end

local function BuildLoadedPreviewEntryKey(cfg)
    if type(cfg) ~= "table" then
        return ""
    end
    local classID = tonumber(cfg.scopeClassID) or 0
    local specID = tonumber(cfg.scopeSpecID) or 0
    local index = tonumber(cfg.index) or 0
    if index <= 0 then
        return ""
    end
    local store = GetEntryMapStore()
    if store and type(store.BuildEntryKey) == "function" then
        return store.BuildEntryKey(classID, specID, index)
    end
    return string.format("%d:%d:%d", classID, specID, index)
end

function NS:GetLoadedVisualPreviewConfigs()
    local results = {}
    local function addConfig(cfg, key, source)
        if type(cfg) ~= "table" then
            return
        end
        if cfg.imageEnabled ~= true and cfg.textEnabled ~= true then
            return
        end
        local copy = {}
        for k, v in pairs(cfg) do
            if type(v) ~= "table" then
                copy[k] = v
            end
        end
        copy.previewKey = tostring(key or cfg.primaryKey or source or (#results + 1))
        copy.previewSource = tostring(source or "loaded")
        copy.entryKey = BuildLoadedPreviewEntryKey(cfg)
        results[#results + 1] = copy
    end

    for key, cfg in pairs(MAPPED_RUNTIME_CFG) do
        addConfig(cfg, key, "cooldown")
    end

    local castSuccess = GetCastSuccess()
    local castTable = castSuccess and type(castSuccess.GetConfigTable) == "function" and castSuccess:GetConfigTable() or nil
    if type(castTable) == "table" then
        for key, cfg in pairs(castTable) do
            addConfig(cfg, "cast:" .. tostring(key), "cast")
        end
    end

    local bloodlust = GetBloodlust()
    local bloodlustCfg = bloodlust and type(bloodlust.GetRuntimeConfig) == "function" and bloodlust:GetRuntimeConfig() or nil
    if type(bloodlustCfg) == "table" then
        addConfig(bloodlustCfg, "bloodlust", "bloodlust")
    end

    table.sort(results, function(a, b)
        local ak = tostring(a.entryKey or a.previewKey or "")
        local bk = tostring(b.entryKey or b.previewKey or "")
        return ak < bk
    end)
    return results
end

local function GetProfileController()
    return NS.Core and NS.Core.ProfileController
end

local function GetStartup()
    return NS.Core and NS.Core.Startup
end

local function GetNotifierBridge()
    return NS.Core and NS.Core.NotifierBridge
end

local function NormalizeSoundPath(path)
    local bridge = GetNotifierBridge()
    if bridge and type(bridge.NormalizeSoundPath) == "function" then
        return bridge:NormalizeSoundPath(path)
    end
    local utils = NS.Utils or {}
    if utils.CanonicalPath then
        return utils.CanonicalPath(path)
    end
    return tostring(path or ""):gsub("/", "\\")
end

local function ResolveEntrySoundPath(entry)
    local bridge = GetNotifierBridge()
    if bridge and type(bridge.ResolveEntrySoundPath) == "function" then
        return bridge:ResolveEntrySoundPath(entry)
    end
    return NormalizeSoundPath(type(entry) == "table" and entry.soundPath or entry)
end

local function ResolveRuntimeImageTexture(entry)
    local notifier = GetNotifier()
    if notifier and type(notifier.ResolveImageTexture) == "function" then
        return notifier:ResolveImageTexture(entry)
    end
    return nil
end

local function PlayReadyNotification(cfg, alertChannel, remaining, primaryKey)
    local bridge = GetNotifierBridge()
    if bridge and type(bridge.PlayReadyNotification) == "function" then
        return bridge:PlayReadyNotification(cfg, alertChannel, remaining, primaryKey)
    end
    return false
end

local function PlayCastSuccessNotification(cfg, triggerSpellID, castGUID)
    local bridge = GetNotifierBridge()
    if bridge and type(bridge.PlayCastSuccessNotification) == "function" then
        return bridge:PlayCastSuccessNotification(cfg, triggerSpellID, castGUID)
    end
    return false
end

local function HideVisualAlerts(primaryKeyOrMode)
    local bridge = NS.Core and NS.Core.NotifierBridge
    if bridge and type(bridge.HideVisualAlerts) == "function" then
        return bridge:HideVisualAlerts(primaryKeyOrMode)
    end
    local notifier = (NS.Core and NS.Core.Notifier) or NS.Notifier
    if notifier and type(notifier.HideVisualAlerts) == "function" then
        return notifier:HideVisualAlerts(primaryKeyOrMode)
    end
    return false
end

local function PlayBloodlustNotification(cfg)
    local bloodlust = GetBloodlust()
    if bloodlust and type(bloodlust.PlayNotification) == "function" then
        return bloodlust:PlayNotification(cfg, GetNotifier())
    end
    return false
end

local function ConfigureRuntime()
    local runtime = GetRuntime()
    if runtime and type(runtime.Configure) == "function" then
        runtime:Configure({
            getUpdateInterval = GetRuntimeUpdateInterval,
            playReady = PlayReadyNotification,
            playCastSuccess = PlayCastSuccessNotification,
            hideVisual = HideVisualAlerts,
            resolveObjectName = ResolveObjectName,
        })
    end
end

local function WipeRuntimeCooldowns(hideVisual)
    return NS.Core.RuntimeBridge:WipeCooldowns(hideVisual)
end

local function ClearDelayedCastSuccessTimers()
    return NS.Core.RuntimeBridge:ClearDelayedCastSuccessTimers()
end

local function QueueCastSuccessNotification(triggerSpellID, cfg)
    return NS.Core.RuntimeBridge:QueueCastSuccessNotification(triggerSpellID, cfg, PlayCastSuccessNotification)
end

local function ConfigureCastSuccess()
    local castSuccess = GetCastSuccess()
    if castSuccess and type(castSuccess.Configure) == "function" then
        castSuccess:Configure({
            getCurrentClassSpec = GetCurrentClassSpec,
            getOrderedEntryIndices = GetOrderedEntryIndices,
            getEntry = GetEntry,
            getStoredEntryMap = GetStoredEntryMap,
            getCastSuccessMap = GetCastSuccessMap,
            resolveObjectType = ResolveObjectType,
            resolveItemTriggerForEntry = ResolveItemTriggerForEntry,
            isItemLoadRequirementMet = IsItemLoadRequirementMet,
            getObjectTriggerSpellID = GetObjectTriggerSpellID,
            resolveEntrySoundPath = ResolveEntrySoundPath,
            resolveImageTexture = ResolveRuntimeImageTexture,
            queueNotification = QueueCastSuccessNotification,
        })
    end
end

local function ConfigureCustomRuntime()
    local custom = GetCustomRuntime()
    if custom and type(custom.Configure) == "function" then
        custom:Configure({
            getCurrentClassSpec = GetCurrentClassSpec,
            getStoredEntryMap = GetStoredEntryMap,
            getOrderedEntryIndices = GetOrderedEntryIndices,
            getEntry = GetEntry,
            resolveEntrySoundPath = ResolveEntrySoundPath,
            normalizeSoundPath = NormalizeSoundPath,
            playReady = PlayReadyNotification,
            hideVisual = HideVisualAlerts,
        })
    end
end

local function ConfigureRuntimeConfigBuilder()
    local builder = GetRuntimeConfigBuilder()
    if builder and type(builder.Configure) == "function" then
        builder:Configure({
            getCurrentClassSpec = GetCurrentClassSpec,
            getStoredEntryMap = GetStoredEntryMap,
            getOrderedEntryIndices = GetOrderedEntryIndices,
            getEntry = GetEntry,
            resolveObjectType = ResolveObjectType,
            resolveItemTriggerForEntry = ResolveItemTriggerForEntry,
            isItemLoadRequirementMet = IsItemLoadRequirementMet,
            getObjectTriggerSpellID = GetObjectTriggerSpellID,
            makeObjectKey = MakeObjectKey,
            isTalentSelected = IsTalentSelected,
            resolveEntrySoundPath = ResolveEntrySoundPath,
            resolveImageTexture = ResolveRuntimeImageTexture,
        })
    end
end

ConfigureRuntime()
ConfigureCastSuccess()
ConfigureCustomRuntime()
ConfigureRuntimeConfigBuilder()

local function RebuildBloodlustConfig()
    local bloodlust = GetBloodlust()
    if bloodlust and type(bloodlust.Rebuild) == "function" then
        return bloodlust:Rebuild(EnsureDB(), NormalizeSoundPath)
    end
    return false
end

local function HandleBloodlustAura(unit, updateInfo)
    local bloodlust = GetBloodlust()
    if bloodlust and type(bloodlust.HandleUnitAura) == "function" then
        return bloodlust:HandleUnitAura(unit, GetNotifier(), updateInfo)
    end
    return false
end

local function RebuildRuntimeConfig()
    local startup = GetStartup()
    if startup and type(startup.CancelScheduledProfileRefresh) == "function" then
        startup:CancelScheduledProfileRefresh()
    end
    NS.Core.RuntimeBridge:ClearDelayedCastSuccessTimers()
    local builder = GetRuntimeConfigBuilder()
    if builder and type(builder.Rebuild) == "function" then
        local resolverBridge = NS.Core and NS.Core.ResolverBridge
        if resolverBridge and type(resolverBridge.BuildSelectedTalentCache) == "function" then
            resolverBridge:BuildSelectedTalentCache()
        end
        return builder:Rebuild(MAPPED_SPELL_TO_PRIMARY, MAPPED_RUNTIME_CFG)
    end
    return false
end

local function RebuildCastSuccessConfig()
    local castSuccess = GetCastSuccess()
    if castSuccess and type(castSuccess.Rebuild) == "function" then
        return castSuccess:Rebuild()
    end
    return false
end

local function RebuildCustomConfig()
    local custom = GetCustomRuntime()
    if custom and type(custom.Rebuild) == "function" then
        return custom:Rebuild()
    end
    return false
end

local function HandleCustomEvent(event, ...)
    local custom = GetCustomRuntime()
    if custom and type(custom.HandleEvent) == "function" then
        return custom:HandleEvent(event, ...)
    end
    return false
end

local function HandleCastSuccessSpellcast(spellId)
    local castSuccess = GetCastSuccess()
    if castSuccess and type(castSuccess.HandleSpellcastSucceeded) == "function" then
        return castSuccess:HandleSpellcastSucceeded(spellId)
    end
    return false
end

local function RefreshRuntimeCooldowns()
    return NS.Core.RuntimeBridge:RefreshRuntimeCooldowns(MAPPED_RUNTIME_CFG)
end

local itemLoadRefreshPending = false
local itemLoadRefreshCombatPending = false
local function RefreshItemLoadState(event)
    if event == "BAG_UPDATE_DELAYED" then
        MarkBagItemCacheDirty()
    end
    if event == "PLAYER_REGEN_ENABLED" and not itemLoadRefreshCombatPending then
        return false
    end
    if IsCombatLocked() then
        itemLoadRefreshCombatPending = true
        return false
    end
    if itemLoadRefreshPending then
        return false
    end
    itemLoadRefreshCombatPending = false
    itemLoadRefreshPending = true
    local function apply()
        itemLoadRefreshPending = false
        RebuildRuntimeConfig()
        RebuildCastSuccessConfig()
        RefreshRuntimeCooldowns()
        if NS.AceOptions and type(NS.AceOptions.RefreshUI) == "function" then
            NS.AceOptions:RefreshUI()
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.2, apply)
    else
        apply()
    end
    return true
end

local function StartCooldown(spellId)
    return NS.Core.RuntimeBridge:StartCooldown(spellId, MAPPED_SPELL_TO_PRIMARY, MAPPED_RUNTIME_CFG)
end

local function GetUsedEntryCount(map)
    local store = GetEntryMapStore()
    if store and type(store.GetUsedEntryCount) == "function" then
        return store:GetUsedEntryCount(map)
    end
    return #GetOrderedEntryIndices(map)
end

local function FindFirstFreeIndex(map)
    local store = GetEntryMapStore()
    if store and type(store.FindFirstFreeIndex) == "function" then
        return store:FindFirstFreeIndex(map)
    end
    local indices = GetOrderedEntryIndices(map)
    local nextIndex = ENTRY_MIN
    for _, index in ipairs(indices) do
        if index > nextIndex then
            return nextIndex
        end
        if index == nextIndex then
            nextIndex = nextIndex + 1
        end
    end
    return nextIndex
end

local function ConfigureProfileController()
    local controller = GetProfileController()
    if controller and type(controller.Configure) == "function" then
        controller:Configure({
            getAceState = function()
                if NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
                    return NS.AceOptions:GetState()
                end
                return nil
            end,
            getCurrentClassSpec = GetCurrentClassSpec,
            getStoredEntryMap = GetStoredEntryMap,
            getUsedEntryCount = GetUsedEntryCount,
            wipeRuntimeCooldowns = WipeRuntimeCooldowns,
            rebuildRuntimeConfig = RebuildRuntimeConfig,
            rebuildCastSuccessConfig = RebuildCastSuccessConfig,
            rebuildCustomConfig = RebuildCustomConfig,
            rebuildBloodlustConfig = RebuildBloodlustConfig,
            refreshRuntimeCooldowns = RefreshRuntimeCooldowns,
            refreshPanel = function()
                if NS.AceOptions and type(NS.AceOptions.RefreshUI) == "function" then
                    return NS.AceOptions:RefreshUI()
                end
                return false
            end,
        })
    end
end

ConfigureProfileController()

local function ResolveClassName(classID)
    local scope = GetScope()
    if scope and type(scope.ResolveClassName) == "function" then
        return scope:ResolveClassName(classID)
    end
    return L("FALLBACK_CLASS", tostring(classID or 0))
end

local function ResolveSpecName(classID, specID)
    local scope = GetScope()
    if scope and type(scope.ResolveSpecName) == "function" then
        return scope:ResolveSpecName(classID, specID)
    end
    return L("FALLBACK_SPEC", tostring(specID or 0))
end

local function GetTargetClassSpec()
    local controller = GetProfileController()
    if controller and type(controller.GetTargetClassSpec) == "function" then
        return controller:GetTargetClassSpec()
    end
    return GetCurrentClassSpec()
end

local function BuildSummaryText()
    local controller = GetProfileController()
    if controller and type(controller.BuildSummaryText) == "function" then
        return controller:BuildSummaryText()
    end
    return L("MSG_SCOPE_COUNT", 0)
end

local function GetEntryRange()
    local controller = GetProfileController()
    if controller and type(controller.GetEntryRange) == "function" then
        return controller:GetEntryRange()
    end
    return ENTRY_MIN, ENTRY_MIN
end

function RefreshPanel()
    local controller = GetProfileController()
    if controller and type(controller.RefreshPanel) == "function" then
        return controller:RefreshPanel()
    end
    if NS.AceOptions and type(NS.AceOptions.RefreshUI) == "function" then
        return NS.AceOptions:RefreshUI()
    end
    return false
end

local function OnProfileChanged(resetCooldowns)
    local startup = GetStartup()
    if startup and type(startup.CancelScheduledProfileRefresh) == "function" then
        startup:CancelScheduledProfileRefresh()
    end
    local controller = GetProfileController()
    if controller and type(controller.OnProfileChanged) == "function" then
        return controller:OnProfileChanged(resetCooldowns)
    end
    if resetCooldowns then
        WipeRuntimeCooldowns()
        ClearDelayedCastSuccessTimers()
    end
    MarkBagItemCacheDirty()
    RebuildRuntimeConfig()
    RebuildCastSuccessConfig()
    RebuildCustomConfig()
    RebuildBloodlustConfig()
    RefreshRuntimeCooldowns()
    RefreshPanel()
end

NS.API = NS.API or {}
NS.API.RefreshPanel = RefreshPanel
local function ConfigureItemResolveQueue()
    local queue = GetItemResolveQueue()
    if queue and type(queue.Configure) == "function" then
        queue:Configure({
            ensureDB = EnsureDB,
            resolveItemTriggerForEntry = ResolveItemTriggerForEntry,
            rebuildRuntimeConfig = RebuildRuntimeConfig,
            rebuildCastSuccessConfig = RebuildCastSuccessConfig,
            rebuildCustomConfig = RebuildCustomConfig,
            refreshRuntimeCooldowns = RefreshRuntimeCooldowns,
            refreshPanel = RefreshPanel,
            chatPrefix = NS.ADDON_CHAT_PREFIX,
        })
    end
end

local function ResolveAllStoredItemTriggers(quiet)
    local queue = GetItemResolveQueue()
    if queue and type(queue.ResolveAllStored) == "function" then
        return queue:ResolveAllStored(quiet)
    end
    return false
end

local function ResolvePendingItems()
    local queue = GetItemResolveQueue()
    if queue and type(queue.ResolvePending) == "function" then
        return queue:ResolvePending()
    end
    return false
end

ConfigureItemResolveQueue()

local PublicAPI = NS.Core and NS.Core.PublicAPI
local InstalledAPI = PublicAPI:Install({
        GetCurrentClassSpec = GetCurrentClassSpec,
        IsActiveScopeLoaded = IsActiveScopeLoaded,
        GetTargetClassSpec = GetTargetClassSpec,
        GetStoredEntryMap = GetStoredEntryMap,
        GetCastSuccessMap = GetCastSuccessMap,
        EnsureCastSuccessMap = EnsureCastSuccessMap,
        GetEntry = GetEntry,
        PlayReadyNotification = PlayReadyNotification,
        PlayCastSuccessNotification = PlayCastSuccessNotification,
        QueueCastSuccessNotification = QueueCastSuccessNotification,
        ClearDelayedCastSuccessTimers = ClearDelayedCastSuccessTimers,
        PlayBloodlustNotification = PlayBloodlustNotification,
        RebuildCastSuccessConfig = RebuildCastSuccessConfig,
        RebuildCustomConfig = RebuildCustomConfig,
        RebuildBloodlustConfig = RebuildBloodlustConfig,
        GetModes = function()
            return MODE_TTS, MODE_SOUND
        end,
        GetEntryRange = function()
            return GetEntryRange()
        end,
        GetSummaryText = BuildSummaryText,
        ResolveClassName = ResolveClassName,
        ResolveSpecName = ResolveSpecName,
        ResolveSpellName = ResolveSpellName,
        ResolveSpellIcon = ResolveSpellIcon,
        ResolveSpellBaseCooldownSeconds = ResolveSpellBaseCooldownSeconds,
        ResolveItemName = ResolveItemName,
        ResolveItemIcon = ResolveItemIcon,
        ResolveItemUseSpellID = ResolveItemUseSpellID,
        ResolveItemTriggerForEntry = ResolveItemTriggerForEntry,
        IsItemLoadRequirementMet = IsItemLoadRequirementMet,
        ResolveAllStoredItemTriggers = ResolveAllStoredItemTriggers,
        ResolvePendingItems = ResolvePendingItems,
        MarkEntryDeleted = MarkEntryDeleted,
        ClearEntryDeletedMarker = ClearEntryDeletedMarker,
        IsEntryMarkedDeleted = IsEntryMarkedDeleted,
        PurgeDeletedEntries = PurgeDeletedEntries,
        ResolveObjectType = ResolveObjectType,
        ResolveObjectName = ResolveObjectName,
        ResolveObjectIcon = ResolveObjectIcon,
        ResolveObjectBaseCooldownSeconds = ResolveObjectBaseCooldownSeconds,
        GetObjectTriggerSpellID = GetObjectTriggerSpellID,
        ResolveTalentName = ResolveTalentName,
        IsTalentSelected = IsTalentSelected,
        EnsureEntryMap = EnsureEntryMap,
        FindFirstFreeIndex = FindFirstFreeIndex,
        GetOrderedEntryIndices = GetOrderedEntryIndices,
        RebuildRuntimeConfig = RebuildRuntimeConfig,
        RefreshRuntimeCooldowns = RefreshRuntimeCooldowns,
        GetCDMVoiceCurrentClassSpec = function()
            return NS.Core.CDMVoiceService:GetCurrentClassSpec()
        end,
        IsCDMVoiceAvailable = function()
            return NS.Core.CDMVoiceService:IsAvailable()
        end,
        GetCDMVoiceCategories = function()
            return NS.Core.CDMVoiceService:GetCategories()
        end,
        GetCDMVoiceCooldownsForCategory = function(category)
            return NS.Core.CDMVoiceService:GetCooldownsForCategory(category)
        end,
        GetCDMVoiceValidEvents = function(cooldownID)
            return NS.Core.CDMVoiceService:GetValidEvents(cooldownID)
        end,
        GetCDMVoiceRegistryItems = function()
            return NS.Core.CDMVoiceRegistry:GetItems()
        end,
        GetCDMVoiceConfiguredAlert = function(cooldownID, eventType)
            return NS.Core.CDMVoiceService:GetSoundAlert(cooldownID, eventType)
        end,
        CanConfigureCDMVoice = function(cooldownID, eventType, payload)
            return NS.Core.CDMVoiceService:CanConfigureSound(cooldownID, eventType, payload)
        end,
        ApplyCDMVoiceAlert = function(cooldownID, eventType, payload, classID, specID, category)
            return NS.Core.CDMVoiceService:ApplySoundAlert(cooldownID, eventType, payload, classID, specID, category)
        end,
        ApplyCurrentCDMVoiceDraftAndReload = function(draft)
            return NS.Core.CDMVoicePresetSync:ApplyCurrentDraftAndReload(draft)
        end,
        SaveCDMVoicePresetOnly = function(cooldownID, eventType, payload, classID, specID, category)
            if type(cooldownID) == "table" then
                return NS.Core.CDMVoiceService:SaveVoicePresetOnly(cooldownID)
            end
            return NS.Core.CDMVoiceService:SaveVoicePresetOnly(
                cooldownID, eventType, payload, classID, specID, category
            )
        end,
        SaveAndSyncCDMVoicePreset = function(cooldownID, eventType, payload, classID, specID, category)
            return NS.Core.CDMVoiceService:SaveAndSyncVoicePreset(
                cooldownID, eventType, payload, classID, specID, category
            )
        end,
        DeleteCDMVoiceAlertByKey = function(key)
            return NS.Core.CDMVoiceService:DeleteSoundAlertByKey(key)
        end,
        GetCDMVoiceSavedEntries = function()
            return NS.Core.CDMVoiceService:GetCurrentSpecSavedEntries()
        end,
        GetCurrentSpecCDMVoiceEntries = function()
            return NS.Core.CDMVoiceService:GetCurrentSpecSavedEntries()
        end,
        DeleteCDMVoiceEntryByKey = function(key)
            return NS.Core.CDMVoiceService:DeleteSoundAlertByKey(key)
        end,
        DeleteCDMVoiceEntryLocalOnly = function(key)
            return NS.Core.CDMVoiceService:DeleteSoundAlertByKeyLocalOnly(key)
        end,
        ParseCDMVoiceSavedKey = function(key)
            return NS.Core.CDMVoiceService:ParseSavedEntryKey(key)
        end,
        GetCDMVoicePresetRecord = function(classID, specID, recordKey)
            return NS.Core.CDMVoicePresetStore:GetEffectiveRecord(classID, specID, recordKey)
        end,
        RefreshCDMVoiceRegistry = function()
            return NS.Core.CDMVoiceRegistry:Refresh(false)
        end,
        GetCDMVoiceLastCategory = function()
            return NS.Core.CDMVoiceService:GetLastCategory()
        end,
        SetCDMVoiceLastCategory = function(category)
            return NS.Core.CDMVoiceService:SetLastCategory(category)
        end,
        SetCDMVoiceUIRefreshCallback = function(callback)
            return NS.Core.CDMVoiceService:SetUIRefreshCallback(callback)
        end,
        GetCDMVoicePresetRecords = function(classID, specID)
            local store = NS.Core.CDMVoicePresetStore
            if classID and specID then
                return store:GetEffectiveRecords(classID, specID)
            end
            return store:GetAllProfilesForExport()
        end,
        CaptureCurrentCDMVoicePresets = function()
            return NS.Core.CDMVoicePresetStore:CaptureCurrentSpecFromLayout()
        end,
        ExportCDMVoicePresetString = function()
            local builder = NS.ExportBuilder
            return builder and type(builder.ExportCDMVoicePresetString) == "function"
                and builder:ExportCDMVoicePresetString() or ""
        end,
        ExportCDMVoiceEntryString = function(savedEntryKey)
            local builder = NS.ExportBuilder
            return builder and type(builder.ExportCDMVoiceEntryString) == "function"
                and builder:ExportCDMVoiceEntryString(savedEntryKey) or ""
        end,
        ImportCDMVoicePresetPayload = function(payload)
            payload = type(payload) == "table" and payload or {}
            if tonumber(payload.version) ~= 1 or type(payload.profiles) ~= "table" then
                return false, 0, nil, "invalid_version"
            end
            local store = NS.Core.CDMVoicePresetStore
            local currentClassID, currentSpecID = NS.Core.CDMVoiceService:GetCurrentClassSpec()
            local expectedCurrent, expectedOther, expectedInvalid = 0, 0, 0
            for classID, classMap in pairs(payload.profiles) do
                for specID, specMap in pairs(type(classMap) == "table" and classMap or {}) do
                    for _, data in pairs(type(specMap) == "table" and specMap or {}) do
                        local candidate = {}
                        for key, value in pairs(type(data) == "table" and data or {}) do
                            candidate[key] = value
                        end
                        candidate.classID = tonumber(candidate.classID) or tonumber(classID)
                        candidate.specID = tonumber(candidate.specID) or tonumber(specID)
                        local sanitized = store:SanitizeRecord(candidate, "import")
                        if not sanitized then
                            expectedInvalid = expectedInvalid + 1
                        elseif sanitized.classID == tonumber(currentClassID)
                            and sanitized.specID == tonumber(currentSpecID) then
                            expectedCurrent = expectedCurrent + 1
                        else
                            expectedOther = expectedOther + 1
                        end
                    end
                end
            end
            local imported, invalid = store:ImportProfiles(payload.profiles)
            local state = store:GetSyncState()
            state.importedVersion = math.max(tonumber(state.importedVersion) or 0, 1)
            local sync = NS.Core.CDMVoicePresetSync
            local evaluated, summary, reason = sync:EvaluateCurrentSpec("preset_import", {
                prompt = expectedCurrent > 0,
                promptKind = "import",
            })
            summary = type(summary) == "table" and summary or {}
            local details = {
                total = tonumber(imported) or 0,
                currentSpec = expectedCurrent,
                otherScopes = expectedOther,
                invalid = math.max(tonumber(invalid) or 0, expectedInvalid),
                pending = tonumber(summary.pendingCount) or 0,
                pendingRemoval = tonumber(summary.pendingRemoval) or 0,
                added = tonumber(summary.pending) or 0,
                replaced = 0,
                deduplicated = 0,
                missingVoice = tonumber(summary.missingVoice) or 0,
            }
            if not evaluated and type(NS.Core.CDMVoiceService.RefreshRuntimeData) == "function" then
                NS.Core.CDMVoiceService:RefreshRuntimeData("preset_import_local")
            end
            return imported > 0, imported, details, evaluated and "pending" or (reason or "deferred")
        end,
        SyncCurrentSpecCDMVoices = function(reason, options)
            return NS.Core.CDMVoicePresetSync:EvaluateCurrentSpec(
                reason or "manual",
                type(options) == "table" and options or {}
            )
        end,
        EvaluateCurrentSpecCDMVoices = function(reason, options)
            return NS.Core.CDMVoicePresetSync:EvaluateCurrentSpec(reason or "manual", options)
        end,
        GetCurrentSpecCDMPendingSummary = function()
            return NS.Core.CDMVoicePresetSync:GetCurrentSpecPendingSummary()
        end,
        ApplyCurrentCDMVoiceRecordAndReload = function(recordKey)
            return NS.Core.CDMVoicePresetSync:ApplyCurrentRecordAndReload(recordKey)
        end,
        ApplyAllPendingCurrentSpecCDMVoicesAndReload = function(reason, drafts)
            return NS.Core.CDMVoicePresetSync:ApplyAllPendingCurrentSpecAndReload(reason, drafts)
        end,
        ClearCDMVoiceRuntimeReloadPending = function()
            return NS.Core.CDMVoiceService:ClearPendingRuntimeReload()
        end,
        ApplyCDMVoiceAlertsBatch = function(operations, options)
            return NS.Core.CDMVoiceService:ApplySoundAlertsBatch(operations, options)
        end,
        GetCDMVoiceSyncSummary = function()
            return NS.Core.CDMVoicePresetSync:GetLastSummary()
        end,
        GetCDMVoiceRecordForAlert = function(classID, specID, category, spellID, eventType)
            return NS.Core.CDMVoicePresetStore:GetRecordForAlert(classID, specID, category, spellID, eventType)
        end,
        RemoveCDMVoicePresetRecord = function(classID, specID, recordKey)
            return NS.Core.CDMVoicePresetStore:RemoveRecord(classID, specID, recordKey)
        end,
        DisableBuiltInCDMVoicePreset = function(classID, specID, recordKey)
            return NS.Core.CDMVoicePresetStore:DisableBuiltInRecord(classID, specID, recordKey)
        end,
        RefreshActiveCDMRuntime = function()
            return false
        end,
    })
_G.QFXSkillAlerts = InstalledAPI

local function ConfigureStartup()
    local startup = GetStartup()
    if startup and type(startup.Configure) == "function" then
        startup:Configure({
            initializeDatabase = function()
                if NS.Core and NS.Core.Database and type(NS.Core.Database.Initialize) == "function" then
                    return NS.Core.Database:Initialize()
                end
                return false
            end,
            ensureDB = EnsureDB,
            initializeAceOptions = function()
                if NS.AceOptions and type(NS.AceOptions.Initialize) == "function" then
                    return NS.AceOptions:Initialize()
                end
                return false
            end,
            initializeConfigPanel = function()
                if NS.Core and NS.Core.ConfigPanel and type(NS.Core.ConfigPanel.Initialize) == "function" then
                    return NS.Core.ConfigPanel:Initialize()
                end
                return false
            end,
            initializeCommands = function()
                if NS.Core and NS.Core.Commands and type(NS.Core.Commands.Initialize) == "function" then
                    return NS.Core.Commands:Initialize()
                end
                return false
            end,
            initializeMinimapButton = function()
                if NS.Core and NS.Core.MinimapButton and type(NS.Core.MinimapButton.Initialize) == "function" then
                    return NS.Core.MinimapButton:Initialize()
                end
                return false
            end,
            showMinimapButton = function()
                if NS.Core and NS.Core.MinimapButton and type(NS.Core.MinimapButton.Show) == "function" then
                    return NS.Core.MinimapButton:Show()
                end
                return false
            end,
            printLoadedMessage = function()
                print("[QFX-SA] " .. L("MSG_LOADED"))
            end,
            onProfileChanged = OnProfileChanged,
            resolvePendingItems = ResolvePendingItems,
            clearDelayedCastSuccessTimers = ClearDelayedCastSuccessTimers,
            startCooldown = StartCooldown,
            handleCastSuccessSpellcast = HandleCastSuccessSpellcast,
            handleBloodlustAura = HandleBloodlustAura,
            handleItemInventoryChanged = RefreshItemLoadState,
            handleCustomEvent = HandleCustomEvent,
            invalidateTalentCache = function()
                local bridge = NS.Core and NS.Core.ResolverBridge
                if bridge and type(bridge.InvalidateTalentCache) == "function" then
                    return bridge:InvalidateTalentCache()
                end
                return false
            end,
            prepareProfileRefresh = function()
                PurgeDeletedEntries()
                ResolveAllStoredItemTriggers(true)
                MarkBagItemCacheDirty()
            end,
        })
    end
end

ConfigureStartup()

local EventHub = NS.Core and NS.Core.EventHub
local Startup = GetStartup()
local eventHandlers = Startup and type(Startup.GetEventHandlers) == "function" and Startup:GetEventHandlers() or {}
EventHub:Initialize(frame, eventHandlers)
