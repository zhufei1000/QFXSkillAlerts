local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceRegistry = NS.Core.CDMVoiceRegistry or {}

local Registry = NS.Core.CDMVoiceRegistry
local Catalog = NS.MediaCatalog or {}

local PAYLOAD_HIGH = -1000000000
local PAYLOAD_LOW = -2140000000
local PAYLOAD_RANGE = PAYLOAD_HIGH - PAYLOAD_LOW + 1

Registry.items = Registry.items or {}
Registry.itemByIdentity = Registry.itemByIdentity or {}
Registry.itemByPayload = Registry.itemByPayload or {}

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function NormalizePath(value)
    return Trim(value):gsub("/", "\\"):gsub("\\+", "\\"):lower()
end

local function NormalizeName(value)
    return Trim(value):lower()
end

local function IsValidPayload(value)
    value = tonumber(value)
    return value ~= nil
        and value == math.floor(value)
        and value >= PAYLOAD_LOW
        and value <= PAYLOAD_HIGH
end

local function EnsureDatabase()
    if type(QFXSkillAlertsDB) ~= "table" then
        QFXSkillAlertsDB = {}
    end
    local db = QFXSkillAlertsDB
    if type(db.cdmVoiceRegistry) ~= "table" then
        db.cdmVoiceRegistry = {}
    end
    local store = db.cdmVoiceRegistry
    if type(store.byIdentity) ~= "table" then
        store.byIdentity = {}
    end
    if type(store.byPayload) ~= "table" then
        store.byPayload = {}
    end
    if type(store.collisionMap) ~= "table" then
        store.collisionMap = {}
    end
    return store
end

local function HashString(value)
    local hash = 5381
    value = tostring(value or "")
    for index = 1, #value do
        hash = ((hash * 33) + value:byte(index)) % PAYLOAD_RANGE
    end
    return hash
end

function Registry:BuildIdentity(name, path)
    local normalizedName = NormalizeName(name)
    local normalizedPath = NormalizePath(path)
    if normalizedName == "" or normalizedPath == "" then
        return nil
    end
    return "lsm:" .. normalizedName .. ":" .. normalizedPath
end

function Registry:BuildCandidate(identity, salt)
    identity = tostring(identity or "")
    salt = math.max(0, math.floor(tonumber(salt) or 0))
    local hashInput = salt == 0 and identity or (identity .. "#" .. tostring(salt))
    return PAYLOAD_HIGH - HashString(hashInput)
end

function Registry:GetOrCreatePayload(identity)
    identity = tostring(identity or "")
    if identity == "" then
        return nil
    end

    local store = EnsureDatabase()
    local stored = tonumber(store.byIdentity[identity])
    if IsValidPayload(stored) then
        local reverse = store.byPayload[tostring(stored)]
        if reverse == nil or reverse == identity then
            store.byPayload[tostring(stored)] = identity
            return stored
        end
    end

    local salt = math.max(0, math.floor(tonumber(store.collisionMap[identity]) or 0))
    local attempts = 0
    while attempts < PAYLOAD_RANGE do
        local payload = self:BuildCandidate(identity, salt)
        local occupant = store.byPayload[tostring(payload)]
        if occupant == nil or occupant == identity then
            store.byIdentity[identity] = payload
            store.byPayload[tostring(payload)] = identity
            if salt > 0 then
                store.collisionMap[identity] = salt
            else
                store.collisionMap[identity] = nil
            end
            return payload
        end
        salt = salt + 1
        attempts = attempts + 1
    end
    return nil
end

function Registry:GetItems()
    return self.items
end

function Registry:RepairStoredMappings()
    local store = EnsureDatabase()
    for identity, payload in pairs(store.byIdentity) do
        payload = tonumber(payload)
        if type(identity) == "string" and identity ~= "" and IsValidPayload(payload) then
            local key = tostring(payload)
            if store.byPayload[key] == nil then
                store.byPayload[key] = identity
            elseif store.byPayload[key] ~= identity then
                -- Keep the established reverse owner and reallocate this identity
                -- deterministically the next time its sound is available.
                store.byIdentity[identity] = nil
            end
        else
            store.byIdentity[identity] = nil
        end
    end
    for payloadKey, identity in pairs(store.byPayload) do
        local payload = tonumber(payloadKey)
        if type(identity) ~= "string" or identity == "" or not IsValidPayload(payload) then
            store.byPayload[payloadKey] = nil
        elseif store.byIdentity[identity] == nil then
            store.byIdentity[identity] = payload
        end
    end
end

function Registry:GetPayloadForSound(name, path)
    local identity = self:BuildIdentity(name, path)
    return identity and self:GetOrCreatePayload(identity) or nil
end

function Registry:GetIdentityForPayload(payload)
    if not IsValidPayload(payload) then
        return nil
    end
    return EnsureDatabase().byPayload[tostring(tonumber(payload))]
end

function Registry:IsOwnedPayload(payload)
    return self:GetIdentityForPayload(payload) ~= nil
end

function Registry:GetItemForPayload(payload)
    return self.itemByPayload[tostring(tonumber(payload))]
end

function Registry:GetPathForPayload(payload)
    local item = self:GetItemForPayload(payload)
    return item and item.path or nil
end

function Registry:GetNameForPayload(payload)
    local item = self:GetItemForPayload(payload)
    return item and item.name or nil
end

function Registry:IsPayloadAvailable(payload)
    local item = self:GetItemForPayload(payload)
    return item ~= nil and type(item.path) == "string" and item.path ~= ""
end

function Registry:NotifyChanged()
    local api = NS.API
    if type(api) == "table" and type(api.OnCDMVoiceRegistryChanged) == "function" then
        pcall(api.OnCDMVoiceRegistryChanged)
    end
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if sync and type(sync.ScheduleSync) == "function" then
        sync:ScheduleSync("registry")
    end
end

function Registry:Refresh(silent)
    local values = type(Catalog.GetSharedMediaSoundList) == "function" and Catalog:GetSharedMediaSoundList() or {}
    local items = {}
    local byIdentity = {}
    local byPayload = {}

    for name in pairs(type(values) == "table" and values or {}) do
        local path = type(Catalog.FetchSharedMediaSoundPath) == "function" and Catalog:FetchSharedMediaSoundPath(name) or ""
        local identity = self:BuildIdentity(name, path)
        if identity then
            local payload = self:GetOrCreatePayload(identity)
            if payload then
                local item = {
                    identity = identity,
                    name = tostring(name),
                    path = tostring(path),
                    payload = payload,
                }
                items[#items + 1] = item
                byIdentity[identity] = item
                byPayload[tostring(payload)] = item
            end
        end
    end

    table.sort(items, function(left, right)
        local leftName = tostring(left.name or ""):lower()
        local rightName = tostring(right.name or ""):lower()
        if leftName == rightName then
            return tostring(left.path or ""):lower() < tostring(right.path or ""):lower()
        end
        return leftName < rightName
    end)

    self.items = items
    self.itemByIdentity = byIdentity
    self.itemByPayload = byPayload
    if not silent then
        self:NotifyChanged()
    end
    return items
end

function Registry:SelfCheck()
    local identityA = self:BuildIdentity(" Test Sound ", "Interface/AddOns/Test/Sound.ogg")
    local identityB = self:BuildIdentity("test sound", "Interface\\AddOns\\Test\\Sound.ogg")
    local payloadA = identityA and self:BuildCandidate(identityA, 0) or nil
    local payloadB = identityB and self:BuildCandidate(identityB, 0) or nil
    return identityA == identityB
        and IsValidPayload(payloadA)
        and payloadA == payloadB
end

function Registry:RegisterSharedMediaCallback()
    if self.callbackRegistered then
        return true
    end
    local LSM = type(Catalog.GetSharedMediaLibrary) == "function" and Catalog:GetSharedMediaLibrary() or nil
    if not LSM or type(LSM.RegisterCallback) ~= "function" then
        return false
    end
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
        if mediaType == "sound" then
            Registry:Refresh(false)
        end
    end)
    self.callbackRegistered = true
    return true
end

function Registry:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self.selfCheckPassed = self:SelfCheck()
    self:RepairStoredMappings()
    local registered = self:RegisterSharedMediaCallback()
    self:Refresh(true)
    if not registered and type(CreateFrame) == "function" then
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function()
            if Registry:RegisterSharedMediaCallback() then
                Registry:Refresh(false)
                watcher:UnregisterEvent("ADDON_LOADED")
            end
        end)
        self.sharedMediaWatcher = watcher
    end
end

Registry:Initialize()
