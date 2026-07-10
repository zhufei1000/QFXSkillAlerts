local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS
NS.Core = NS.Core or {}

local DeletedEntryStore = NS.Core.DeletedEntryStore or {}
NS.Core.DeletedEntryStore = DeletedEntryStore
NS.DeletedEntryStore = DeletedEntryStore

local CONST = NS.Constants or {}
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"

local function NormalizeEntryTypeValue(value)
    value = tostring(value or "cooldown")
    if value == "cast" then
        return value
    end
    return "cooldown"
end

local function NormalizeObjectTypeValue(value)
    value = tostring(value or OBJECT_TYPE_SPELL):lower()
    if value ~= OBJECT_TYPE_ITEM then
        value = OBJECT_TYPE_SPELL
    end
    return value
end

local function EnsureStore(db)
    if type(db) ~= "table" then
        return nil
    end
    if type(db.deletedEntries) ~= "table" then
        db.deletedEntries = {}
    end
    if type(db.deletedEntries.keys) ~= "table" then
        db.deletedEntries.keys = {}
    end
    if type(db.deletedEntries.signatures) ~= "table" then
        db.deletedEntries.signatures = {}
    end
    return db.deletedEntries
end

local function BuildExactKey(classID, specID, index)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    index = tonumber(index) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    if classID < 0 or specID < 0 or index <= 0 then
        return nil
    end
    return tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(index)
end

local function BuildSignature(classID, specID, entry)
    if type(entry) ~= "table" then
        return nil
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    local spellId = tonumber(entry.spellId or entry.itemID) or 0
    if classID < 0 or specID < 0 or spellId <= 0 then
        return nil
    end
    local entryType = NormalizeEntryTypeValue(entry.entryType)
    local objectType = NormalizeObjectTypeValue(entry.objectType)
    return tostring(classID) .. ":" .. tostring(specID) .. ":" .. entryType .. ":" .. objectType .. ":" .. tostring(math.floor(spellId))
end

function DeletedEntryStore:Mark(db, classID, specID, entry, index)
    local store = EnsureStore(db)
    if not store then
        return false
    end
    local changed = false
    local exactKey = BuildExactKey(classID, specID, index)
    if exactKey then
        store.keys[exactKey] = true
        changed = true
    end
    local signature = BuildSignature(classID, specID, entry)
    if signature then
        store.signatures[signature] = true
        changed = true
    end
    return changed
end

function DeletedEntryStore:Clear(db, classID, specID, entry, index)
    local store = EnsureStore(db)
    if not store then
        return false
    end
    local changed = false
    local exactKey = BuildExactKey(classID, specID, index)
    if exactKey and store.keys[exactKey] ~= nil then
        store.keys[exactKey] = nil
        changed = true
    end
    local signature = BuildSignature(classID, specID, entry)
    if signature and store.signatures[signature] ~= nil then
        store.signatures[signature] = nil
        changed = true
    end
    return changed
end

function DeletedEntryStore:IsMarked(db, classID, specID, entry, index)
    local store = EnsureStore(db)
    if not store then
        return false
    end
    local exactKey = BuildExactKey(classID, specID, index)
    if exactKey and store.keys[exactKey] then
        return true
    end
    local signature = BuildSignature(classID, specID, entry)
    return signature and store.signatures[signature] == true
end

local function PurgeRoot(self, db, root)
    if type(root) ~= "table" then
        return false
    end
    local changed = false
    for classIDKey, classMap in pairs(root) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            for specIDKey, specMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(specMap) == "table" then
                    if classID == ALL_CLASSES_ID then
                        specID = ALL_SPECS_ID
                    end
                    for index, entry in pairs(specMap) do
                        local entryIndex = tonumber(index) or 0
                        if entryIndex > 0 and type(entry) == "table" and self:IsMarked(db, classID, specID, entry, entryIndex) then
                            specMap[index] = nil
                            changed = true
                        end
                    end
                end
            end
        end
    end
    return changed
end

function DeletedEntryStore:Purge(db)
    if type(db) ~= "table" then
        return false
    end
    local changed = false
    changed = PurgeRoot(self, db, db.specConfigs) or changed
    changed = PurgeRoot(self, db, db.castSuccessConfigs) or changed
    return changed
end
