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
QFXSkillAlertsNS = {
    Constants = {},
    Utils = {},
    Core = {},
    API = {
        GetModes = function() return "tts", "sound" end,
        ResolveObjectType = function(_, objectType) return objectType end,
        EnsureEntryMap = function() return savedMap end,
        GetStoredEntryMap = function() return savedMap end,
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
    },
    L = function(key) return key end,
}
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
