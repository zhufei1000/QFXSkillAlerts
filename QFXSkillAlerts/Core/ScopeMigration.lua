local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.ScopeMigration = NS.Core.ScopeMigration or {}

local Migration = NS.Core.ScopeMigration

local MIGRATION_VERSION = 20260708

local KNOWN_SPEC_SCOPES = {
    [31821] = { classID = 2, specIDs = { 65 } },
    [31850] = { classID = 2, specIDs = { 66 } },
    [86659] = { classID = 2, specIDs = { 66 } },
    [255937] = { classID = 2, specIDs = { 70 } },
    [389539] = { classID = 2, specIDs = { 66 } },

    [33206] = { classID = 5, specIDs = { 256 } },
    [47788] = { classID = 5, specIDs = { 257 } },
    [62618] = { classID = 5, specIDs = { 256 } },
    [64843] = { classID = 5, specIDs = { 257 } },
    [200183] = { classID = 5, specIDs = { 257 } },
    [421453] = { classID = 5, specIDs = { 256 } },

    [51271] = { classID = 6, specIDs = { 251 } },
    [1249658] = { classID = 6, specIDs = { 251 } },

    [98008] = { classID = 7, specIDs = { 264 } },
    [114050] = { classID = 7, specIDs = { 262 } },
    [114051] = { classID = 7, specIDs = { 263 } },
    [114052] = { classID = 7, specIDs = { 264 } },
    [384352] = { classID = 7, specIDs = { 263 } },

    [110960] = { classID = 8, specIDs = { 62 } },

    [115203] = { classID = 10, specIDs = { 268 } },
    [115310] = { classID = 10, specIDs = { 270 } },
    [116680] = { classID = 10, specIDs = { 270 } },
    [116849] = { classID = 10, specIDs = { 270 } },
    [322118] = { classID = 10, specIDs = { 270 } },
    [325197] = { classID = 10, specIDs = { 270 } },
    [443028] = { classID = 10, specIDs = { 269, 270 } },

    [33763] = { classID = 11, specIDs = { 105 } },
    [740] = { classID = 11, specIDs = { 105 } },
    [29166] = { classID = 11, specIDs = { 102, 105 } },
    [33891] = { classID = 11, specIDs = { 105 } },
    [102342] = { classID = 11, specIDs = { 105 } },
    [102543] = { classID = 11, specIDs = { 103 } },
    [102558] = { classID = 11, specIDs = { 104 } },
    [194223] = { classID = 11, specIDs = { 102 } },
    [390414] = { classID = 11, specIDs = { 102 } },

    [179057] = { classID = 12, specIDs = { 577 } },
    [187827] = { classID = 12, specIDs = { 581 } },
    [191427] = { classID = 12, specIDs = { 577 } },
    [196718] = { classID = 12, specIDs = { 577 } },
    [198589] = { classID = 12, specIDs = { 577 } },

    [357170] = { classID = 13, specIDs = { 1468 } },
    [374227] = { classID = 13, specIDs = { 1467, 1468 } },
    [374968] = { classID = 13, specIDs = { 1467, 1468 } },
}

local function IsAllScopeMap(map)
    if type(map) ~= "table" or next(map) == nil then
        return true
    end
    return map[0] == true
end

local function BuildSpecMap(specIDs)
    local map = {}
    for _, specID in ipairs(specIDs or {}) do
        specID = tonumber(specID) or 0
        if specID > 0 then
            map[specID] = true
        end
    end
    return map
end

local function IsItemEntry(entry)
    if type(entry) ~= "table" then
        return false
    end
    return tostring(entry.objectType or "") == "item" or tonumber(entry.itemID) ~= nil
end

function Migration:ApplyKnownSpecScopes(db)
    if type(db) ~= "table" then
        return 0
    end
    if (tonumber(db.knownSpecScopeMigrationVersion) or 0) >= MIGRATION_VERSION then
        return 0
    end

    local changed = 0
    local specConfigs = type(db.specConfigs) == "table" and db.specConfigs or nil
    if specConfigs then
        for _, classMap in pairs(specConfigs) do
            if type(classMap) == "table" then
                for _, entryMap in pairs(classMap) do
                    if type(entryMap) == "table" then
                        for _, entry in pairs(entryMap) do
                            if type(entry) == "table" and not IsItemEntry(entry) and IsAllScopeMap(entry.alertSpecIDs or entry.customSpecIDs) then
                                local scope = KNOWN_SPEC_SCOPES[tonumber(entry.spellId) or 0]
                                if scope and scope.classID and scope.specIDs then
                                    local specMap = BuildSpecMap(scope.specIDs)
                                    if next(specMap) ~= nil then
                                        entry.alertClassIDs = { [scope.classID] = true }
                                        entry.alertSpecIDs = specMap
                                        entry.customClassIDs = nil
                                        entry.customSpecIDs = nil
                                        changed = changed + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    db.knownSpecScopeMigrationVersion = MIGRATION_VERSION
    if changed > 0 then
        db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
    end
    return changed
end

