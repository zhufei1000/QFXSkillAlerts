local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.EntryMap = NS.Core.EntryMap or {}

local EntryMap = NS.Core.EntryMap
local CONST = NS.Constants or {}
local ENTRY_MIN = CONST.ENTRY_MIN or 1
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local function ClearTable(tbl)
    if type(wipe) == "function" then
        wipe(tbl)
    elseif type(tbl) == "table" then
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end
end

function EntryMap:EnsureSpecTable(root, classID, specID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    if type(root) ~= "table" or classID < 0 or specID < 0 then
        return nil
    end
    if type(root[classID]) ~= "table" then
        root[classID] = {}
    end
    if type(root[classID][specID]) ~= "table" then
        root[classID][specID] = {}
    end
    return root[classID][specID]
end

function EntryMap:GetSpecTable(root, classID, specID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    if type(root) ~= "table" or classID < 0 or specID < 0 then
        return nil
    end
    local classMap = root[classID]
    if type(classMap) ~= "table" then
        return nil
    end
    local specMap = classMap[specID]
    if type(specMap) ~= "table" then
        return nil
    end
    return specMap
end

function EntryMap:GetEntry(map, index)
    local entry = map and map[index]
    if type(entry) ~= "table" then
        return nil
    end
    local spellId = tonumber(entry.spellId) or 0
    local entryType = tostring(entry.entryType or "cooldown")
    if spellId <= 0 then
        return nil
    end
    return entry
end

function EntryMap:GetOrderedEntryIndices(map)
    local indices = {}
    if type(map) ~= "table" then
        return indices
    end

    for index, entry in pairs(map) do
        index = tonumber(index) or 0
        if index >= ENTRY_MIN and type(entry) == "table" then
            local spellId = tonumber(entry.spellId) or 0
            local entryType = tostring(entry.entryType or "cooldown")
            if spellId > 0 then
                indices[#indices + 1] = index
            end
        end
    end

    table.sort(indices)
    return indices
end

function EntryMap:GetUsedEntryCount(map)
    return #self:GetOrderedEntryIndices(map)
end

function EntryMap:FindFirstFreeIndex(map)
    local nextIndex = ENTRY_MIN
    for _, index in ipairs(self:GetOrderedEntryIndices(map)) do
        if index > nextIndex then
            return nextIndex
        end
        if index == nextIndex then
            nextIndex = nextIndex + 1
        end
    end
    return nextIndex
end

function EntryMap:ClearTable(tbl)
    ClearTable(tbl)
end
