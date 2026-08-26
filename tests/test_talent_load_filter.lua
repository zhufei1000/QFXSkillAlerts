-- Regression test for independent load-filter and CD-change talents, including
-- compatibility with entries saved before the fields were split.

local function Fail(message)
    error(message, 2)
end

local function Assert(condition, message)
    if not condition then
        Fail(message or "assertion failed")
    end
end

-- ---- RuntimeConfigBuilder talent section (extracted verbatim) ----
local function BuildEffectiveCD(entry, isTalentSelected)
    local talentId = tonumber(entry.talentId) or 0
    local checkTalent = entry.checkTalent == true and talentId > 0
    local talentOK = checkTalent and isTalentSelected(talentId)
    local fixedCD = tonumber(entry.baseCD) or 0
    local talentCD = tonumber(entry.talentCD) or 0
    local effectiveCD = (talentOK and talentCD > 0) and talentCD or fixedCD
    local hasIndependent = entry.loadTalentEnabled ~= nil or entry.loadTalentId ~= nil or entry.loadTalentName ~= nil
    local loadTalentId = tonumber(entry.loadTalentId) or 0
    local loadEnabled = entry.loadTalentEnabled == true and loadTalentId > 0
    if not hasIndependent and entry.talentLoadFilter == true then
        loadTalentId = talentId
        loadEnabled = checkTalent
    end
    if loadEnabled and not isTalentSelected(loadTalentId) then
        effectiveCD = 0
    end
    return effectiveCD
end

local function Loaded(effectiveCD)
    return effectiveCD > 0
end

local selectedTalents = {}
local function IsSelected(talentId)
    return selectedTalents[tonumber(talentId)] == true
end

local function Entry(overrides)
    local entry = {
        checkTalent = false,
        talentId = 0,
        talentName = "",
        talentCD = 0,
        talentLoadFilter = false,
        loadTalentEnabled = false,
        loadTalentId = 0,
        loadTalentName = "",
        baseCD = 12,
    }
    for key, value in pairs(overrides or {}) do
        entry[key] = value
    end
    return entry
end

-- CD-change and load-filter talents may be completely different.
Assert(Loaded(BuildEffectiveCD(Entry({}), IsSelected)), "case1: no talent check loads")
Assert(BuildEffectiveCD(Entry({}), IsSelected) == 12, "case1: fixed CD used")
selectedTalents[100] = true
local splitEntry = Entry({ checkTalent = true, talentId = 100, talentCD = 6, loadTalentEnabled = true, loadTalentId = 200 })
Assert(not Loaded(BuildEffectiveCD(splitEntry, IsSelected)), "case2: missing independent load talent blocks loading")
selectedTalents[200] = true
Assert(BuildEffectiveCD(splitEntry, IsSelected) == 6, "case3: both independent talents selected changes CD")
selectedTalents[100] = nil
Assert(BuildEffectiveCD(splitEntry, IsSelected) == 12, "case4: load talent alone loads with fixed CD")
selectedTalents[200] = nil

-- Legacy combined entries still keep their old behavior.
local legacy = { baseCD = 12, checkTalent = true, talentId = 100, talentCD = 6, talentLoadFilter = true }
Assert(not Loaded(BuildEffectiveCD(legacy, IsSelected)), "case5: legacy combined talent still filters")
selectedTalents[100] = true
Assert(BuildEffectiveCD(legacy, IsSelected) == 6, "case6: legacy combined talent still changes CD")
selectedTalents[100] = nil

-- ---- CastSuccess addCastEntry gate (extracted verbatim) ----
-- Cast alerts have no "CD Changes To" value: checking Talent is itself the
-- load filter, so the talentLoadFilter toggle is not consulted here.
local function CastEntryAllowed(entry, isTalentSelected)
    if type(entry) ~= "table" then
        return false
    end
    local hasIndependent = entry.loadTalentEnabled ~= nil or entry.loadTalentId ~= nil or entry.loadTalentName ~= nil
    local talentId = tonumber(entry.loadTalentId) or 0
    local enabled = entry.loadTalentEnabled == true and talentId > 0
    if not hasIndependent then
        talentId = tonumber(entry.talentId) or 0
        enabled = entry.checkTalent == true and talentId > 0
    end
    if enabled and not isTalentSelected(talentId) then
        return false
    end
    return true
end

Assert(CastEntryAllowed(Entry({ loadTalentEnabled = true, loadTalentId = 200 }), IsSelected) == false,
    "case7: cast alert uses independent load talent")
selectedTalents[200] = true
Assert(CastEntryAllowed(Entry({ loadTalentEnabled = true, loadTalentId = 200 }), IsSelected) == true,
    "case8: selected independent cast load talent loads")
selectedTalents[200] = nil
Assert(CastEntryAllowed(Entry({}), IsSelected) == true,
    "case9: cast alert without talent check always loads")

-- Exercise the real editor save path. A regression here previously cleared
-- checkTalent/talentId for every non-cooldown entry before it reached storage.
local savedMap = {}
QFXSkillAlertsDB = {
    specConfigs = { [0] = { [0] = savedMap } },
    collectionData = {
        [1] = {
            [71] = {
                root = { { type = "group", id = "g1" } },
                groups = { g1 = { name = "Events", entries = {} } },
            },
        },
    },
    collectionSerial = 1,
}
QFXSkillAlertsNS = {
    Constants = {},
    Utils = {},
    Core = {},
    API = {
        GetModes = function() return "tts", "sound" end,
        ResolveObjectType = function(_, objectType) return objectType end,
        EnsureEntryMap = function(classID, specID)
            if classID == 0 and specID == 0 then return savedMap end
            return {}
        end,
        GetStoredEntryMap = function(classID, specID)
            if classID == 0 and specID == 0 then return savedMap end
            return {}
        end,
        GetEntry = function(map, index) return type(map) == "table" and map[index] or nil end,
        GetOrderedEntryIndices = function() return {} end,
        FindFirstFreeIndex = function() return 1 end,
        ResolveTalentName = function() return "Saved Talent" end,
        RebuildRuntimeConfig = function() end,
        RebuildCastSuccessConfig = function() end,
        RebuildCustomConfig = function() end,
        RefreshRuntimeCooldowns = function() end,
        RefreshPanel = function() end,
        ClearEntryDeletedMarker = function() end,
        NormalizeEventVoiceKey = function(value) return value == "combat_start" and value or nil end,
        NormalizeEventLoadContexts = function(value)
            return {
                world = type(value) == "table" and value.world == true,
                delve = type(value) == "table" and value.delve == true,
                dungeon = type(value) == "table" and value.dungeon == true,
                raid = type(value) == "table" and value.raid == true,
            }
        end,
        NormalizeEventInstanceMode = function(value)
            return (value == "season" or value == "specific") and value or "any"
        end,
        NormalizeEventInstanceSelections = function(value)
            local result = {}
            for key, selected in pairs(type(value) == "table" and value or {}) do
                if selected == true then result[tostring(key)] = true end
            end
            return result
        end,
        NormalizeEventInstanceSelectionNames = function(value)
            local result = {}
            for key, name in pairs(type(value) == "table" and value or {}) do result[tostring(key)] = tostring(name) end
            return result
        end,
        FilterCurrentSeasonEventSelections = function(_, value) return value end,
        ResolveEventInstanceSelectionNames = function(_, _, value) return value end,
        HasSelectedEventLoadContext = function(value)
            return type(value) == "table" and (value.world or value.delve or value.dungeon or value.raid) == true
        end,
        RebuildEventVoiceConfig = function() end,
    },
    L = function(key) return key end,
}
dofile("QFXSkillAlerts/Core/CollectionStore.lua")
dofile("QFXSkillAlerts/Core/EventContext.lua")
QFXSkillAlertsNS.API.BuildEventLoadConditionSignature = function(entry)
    return QFXSkillAlertsNS.Core.EventContext:BuildLoadConditionSignature(entry)
end
QFXSkillAlertsNS.API.EventLoadConditionsOverlap = function(left, right)
    return QFXSkillAlertsNS.Core.EventContext:LoadConditionsOverlap(left, right)
end
dofile("QFXSkillAlerts_Config/Core/EntryStore.lua")
QFXSkillAlertsNS.EntryStore.LoadSelectedEntry = function() return true end
local saveState = {
    classID = 1,
    specID = 71,
    entryType = "cast",
    objectType = "spell",
    spellId = 12345,
    spellName = "Talent Cast",
    checkTalent = false,
    loadTalentEnabled = true,
    loadTalentId = 67890,
    loadTalentName = "Saved Talent",
    talentCD = 9,
    talentLoadFilter = false,
    notifyMode = "sound",
    soundSource = "custom",
    soundPath = "Interface\\AddOns\\Test\\cast.ogg",
    customSoundPath = "Interface\\AddOns\\Test\\cast.ogg",
    voiceEnabled = true,
    imageEnabled = false,
    textEnabled = false,
}
local owner = {
    GetState = function() return saveState end,
    ResolveSoundSourceFields = function(_, entry)
        return {
            notifyMode = "sound",
            soundSource = "custom",
            soundPath = entry.soundPath,
            customSoundPath = entry.customSoundPath,
        }
    end,
    NormalizeSoundPath = function(_, path) return tostring(path or "") end,
}
Assert(QFXSkillAlertsNS.EntryStore:SaveEntry(owner) == true,
    "real cast save path should succeed")
Assert(savedMap[1] and savedMap[1].checkTalent == false,
    "cast save must not use the CD-change talent")
Assert(savedMap[1].loadTalentId == 67890 and savedMap[1].loadTalentEnabled == true,
    "real cast save must preserve independent load talent")
Assert(savedMap[1].loadTalentName == "Saved Talent",
    "real cast save must preserve independent load talent name")
Assert(savedMap[1].talentCD == 0,
    "cast save must discard the cooldown-only talentCD")
Assert(savedMap[1].talentLoadFilter == false,
    "new cast save must not rely on the legacy combined flag")

saveState.entryType = "event"
saveState.eventKey = "combat_start"
saveState.eventThrottle = 2
saveState.eventLoadContexts = { world = true, dungeon = true }
saveState.eventDungeonMode = "specific"
saveState.eventRaidMode = "any"
saveState.eventDungeonSelectionIDs = { [101] = true, [202] = true }
saveState.eventDungeonSelectionNames = { [101] = "Ruby Life Pools", [202] = "The Stonevault" }
saveState.spellId = 0
saveState.spellName = ""
saveState.loadTalentEnabled = false
saveState.loadTalentId = 0
saveState.loadTalentName = ""
saveState.selectedCollectionKey = "group:1:71:g1"
Assert(QFXSkillAlertsNS.EntryStore:SaveEntry(owner) == true,
    "real event save path should succeed")
Assert(savedMap[1] and savedMap[1].eventLoadContexts.world and savedMap[1].eventLoadContexts.dungeon,
    "event save must preserve selected load locations")
Assert(not savedMap[1].eventLoadContexts.delve and not savedMap[1].eventLoadContexts.raid,
    "event save must not add unselected load locations")
Assert(savedMap[1].eventDungeonMode == "specific" and savedMap[1].eventRaidMode == "any",
    "event save must preserve dungeon and raid selection modes")
Assert(QFXSkillAlertsDB.collectionData[1][71].groups.g1.entries[1] == "0:0:1",
    "an event created from a scoped collection must be inserted into that collection")
Assert(savedMap[1].eventDungeonSelectionIDs["101"] and savedMap[1].eventDungeonSelectionIDs["202"],
    "event save must preserve multiple specific current-season dungeons")

QFXSkillAlertsNS.API.GetOrderedEntryIndices = function(map)
    local indices = {}
    for index, entry in pairs(type(map) == "table" and map or {}) do
        index = tonumber(index) or 0
        if index > 0 and type(entry) == "table" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    return indices
end
QFXSkillAlertsNS.API.FindFirstFreeIndex = function(map)
    for index = 1, 999 do
        if type(map[index]) ~= "table" then return index end
    end
end
saveState.selectedKey = nil
saveState.eventLoadContexts = { delve = true }
saveState.eventDungeonMode = "any"
saveState.eventDungeonSelectionIDs = {}
saveState.eventDungeonSelectionNames = {}
Assert(QFXSkillAlertsNS.EntryStore:SaveEntry(owner) == true,
    "same event with a disjoint load location should save separately")
Assert(savedMap[2] and savedMap[2].eventLoadContexts.delve,
    "disjoint event load condition should use a separate saved entry")

saveState.selectedKey = nil
saveState.eventLoadContexts = { dungeon = true }
saveState.eventDungeonMode = "any"
Assert(QFXSkillAlertsNS.EntryStore:SaveEntry(owner) == nil,
    "same event with an overlapping dungeon condition should be rejected")
Assert(savedMap[3] == nil, "rejected event overlap must not create a saved entry")

-- Import/export sanitization must key off objectType, not entryType. Item
-- alerts cannot use talent conditions even though their entryType is cooldown
-- or cast.
dofile("QFXSkillAlerts/Core/ImportExportUtil.lua")
local itemEntry = QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({
    entryType = "cast",
    objectType = "item",
    spellId = 98765,
    checkTalent = true,
    talentId = 45678,
    talentName = "Invalid Item Talent",
    talentLoadFilter = true,
    soundPath = "Interface\\AddOns\\Test\\item.ogg",
})
Assert(itemEntry and itemEntry.checkTalent == false,
    "item import must clear checkTalent")
Assert(itemEntry.talentId == 0 and itemEntry.talentName == "",
    "item import must clear talent identity")
Assert(itemEntry.talentLoadFilter == false,
    "item import must clear talentLoadFilter")
Assert(itemEntry.loadTalentEnabled == false and itemEntry.loadTalentId == 0,
    "item import must clear independent load talent")

local splitImported = QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({
    entryType = "cooldown", objectType = "spell", spellId = 22222, baseCD = 65,
    checkTalent = true, talentId = 100, talentName = "CD Talent", talentCD = 45,
    loadTalentEnabled = true, loadTalentId = 200, loadTalentName = "Load Talent",
    textEnabled = true, textCooldownCountdown = true,
})
Assert(splitImported and splitImported.checkTalent == true and splitImported.talentId == 100,
    "import must preserve the CD-change talent")
Assert(splitImported.loadTalentEnabled == true and splitImported.loadTalentId == 200
    and splitImported.loadTalentName == "Load Talent",
    "import must preserve the independent load talent")
Assert(splitImported.textCooldownCountdown == true,
    "import must preserve the cooldown countdown option")

local legacyImported = QFXSkillAlertsNS.ImportExportUtil:SanitizeEntryForImport({
    entryType = "cooldown", objectType = "spell", spellId = 33333, baseCD = 12,
    checkTalent = true, talentId = 300, talentName = "Legacy Talent",
    talentCD = 6, talentLoadFilter = true,
})
Assert(legacyImported.loadTalentEnabled == true and legacyImported.loadTalentId == 300,
    "legacy import must migrate the combined load talent")

print("test_talent_load_filter: runtime, save, and import cases passed")
