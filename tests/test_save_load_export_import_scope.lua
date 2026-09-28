-- Save / load / export / import chain for the fields touched by the editor
-- rework: CD type (fixed / ready, legacy gameStateCD) and race / class / spec
-- scope maps. The export+import sanitizer is the real addon module; the
-- save/load normalizers and the runtime scope matcher are extracted verbatim
-- from EntryStore.lua / RuntimeConfigBuilder.lua so the chain is covered
-- without the WoW frame environment.

local function Fail(message)
    error(message, 2)
end

local function Assert(value, message)
    if not value then
        Fail(message or "assertion failed")
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        Fail(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
    end
end

QFXSkillAlertsNS = {
    Constants = {
        ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
        OBJECT_TYPE_SPELL = "spell", OBJECT_TYPE_ITEM = "item",
        ITEM_LOAD_NONE = "none", ITEM_LOAD_EQUIPPED = "equipped", ITEM_LOAD_BAGS = "bags",
    },
    Utils = {},
    ImportExportUtil = {},
}

dofile("QFXSkillAlerts/Core/ImportExportUtil.lua")
local Util = QFXSkillAlertsNS.ImportExportUtil

local function Entry(overrides)
    local entry = {
        entryType = "cooldown",
        objectType = "spell",
        spellId = 446035,
        spellName = "Bladestorm",
        baseCD = 0,
        cdMode = "ready",
        gameStateCD = true,
        voiceEnabled = true,
        notifyMode = "sound",
        soundPath = "test.ogg",
        imageEnabled = false,
        textEnabled = false,
        alertRaceIDs = { [0] = true },
        alertClassIDs = { [0] = true },
        alertSpecIDs = { [71] = true },
    }
    for key, value in pairs(overrides or {}) do
        entry[key] = value
    end
    return entry
end

-- ---- CD type round trip through export / import sanitation ----

do
    local ready = Util:SanitizeEntryForImport(Entry({ cdMode = "ready", gameStateCD = true }))
    Assert(ready, "ready entry must sanitize")
    Equal(ready.cdMode, "ready", "ready mode survives export/import")
    Equal(ready.gameStateCD, true, "ready sets legacy flag for old runtimes")
end

do
    local fixed = Util:SanitizeEntryForImport(Entry({ cdMode = "fixed", gameStateCD = false }))
    Equal(fixed.cdMode, "fixed", "fixed mode survives export/import")
    Equal(fixed.gameStateCD, false, "fixed clears legacy flag")
end

do
    local cooldown = Util:SanitizeEntryForImport(Entry({ cdMode = "cooldown", gameStateCD = true }))
    Equal(cooldown.cdMode, "cooldown", "cooldown-start mode survives export/import")
    Equal(cooldown.gameStateCD, true, "cooldown-start sets legacy flag")
end

do
    local cooldownTalent = Util:SanitizeEntryForImport(Entry({
        cdMode = "cooldown", checkTalent = true, talentId = 123, talentName = "Talent", talentCD = 5,
    }))
    Equal(cooldownTalent.checkTalent, false, "cooldown-start drops the CD-change talent")
    Equal(cooldownTalent.talentId, 0, "cooldown-start clears talent id")
end

do
    local raw = Entry()
    raw.cdMode = nil
    raw.gameStateCD = true
    local legacyReady = Util:SanitizeEntryForImport(raw)
    Equal(legacyReady.cdMode, "ready", "legacy gameStateCD=true imports as ready")
end

do
    local raw = Entry()
    raw.cdMode = nil
    raw.gameStateCD = nil
    local legacyFixed = Util:SanitizeEntryForImport(raw)
    Equal(legacyFixed.cdMode, "fixed", "entries without mode info import as fixed")
end

do
    local charge = Util:SanitizeEntryForImport(Entry({ cdMode = "charge" }))
    Equal(charge.cdMode, "ready", "removed charge mode imports as ready")
end

-- ---- CD-change talent only survives for fixed CD ----

do
    local ready = Util:SanitizeEntryForImport(Entry({
        cdMode = "ready", checkTalent = true, talentId = 123, talentName = "Talent", talentCD = 5,
    }))
    Equal(ready.checkTalent, false, "ready drops the CD-change talent")
    Equal(ready.talentId, 0, "ready clears talent id")
    Equal(ready.talentCD, 0, "ready clears talent CD")
end

do
    local fixed = Util:SanitizeEntryForImport(Entry({
        cdMode = "fixed", checkTalent = true, talentId = 123, talentName = "Talent", talentCD = 5,
    }))
    Equal(fixed.checkTalent, true, "fixed keeps the CD-change talent")
    Equal(fixed.talentId, 123, "fixed keeps talent id")
    Equal(fixed.talentCD, 5, "fixed keeps talent CD")
end

do
    local readyLoad = Util:SanitizeEntryForImport(Entry({
        cdMode = "ready", loadTalentEnabled = true, loadTalentId = 456, loadTalentName = "Load",
        checkTalent = true, talentId = 123, talentName = "Talent", talentCD = 5,
    }))
    Equal(readyLoad.loadTalentEnabled, true, "ready keeps the load-talent filter")
    Equal(readyLoad.loadTalentId, 456, "ready keeps load-talent id")
    Equal(readyLoad.checkTalent, false, "ready drops only the CD-change talent")
end

-- ---- Scope map round trip ----

do
    local allClassesArms = Util:SanitizeEntryForImport(Entry({
        alertClassIDs = { [0] = true },
        alertSpecIDs = { [71] = true },
        alertRaceIDs = { [1] = true, [2] = true },
    }))
    Equal(allClassesArms.alertClassIDs[0], true, "all-classes marker preserved")
    Equal(allClassesArms.alertSpecIDs[71], true, "concrete spec preserved alongside all classes")
    Assert(allClassesArms.alertSpecIDs[0] ~= true, "all-classes must not force all specs")
    Equal(allClassesArms.alertRaceIDs[1], true, "concrete race preserved")
    Equal(allClassesArms.alertRaceIDs[2], true, "second concrete race preserved")
end

do
    local allSpecs = Util:SanitizeEntryForImport(Entry({ alertSpecIDs = { [0] = true } }))
    Equal(allSpecs.alertSpecIDs[0], true, "all-specs marker preserved")
end

do
    local conflicting = Util:SanitizeEntryForImport(Entry({
        alertClassIDs = { [0] = true, [1] = true },
    }))
    Equal(conflicting.alertClassIDs[0], true, "all-classes wins over concrete entries")
    Assert(conflicting.alertClassIDs[1] ~= true, "concrete class cleared by all-classes")
end

do
    local raw = Entry()
    raw.alertRaceIDs = nil
    raw.alertClassIDs = nil
    raw.alertSpecIDs = nil
    local noScope = Util:SanitizeEntryForImport(raw)
    Assert(noScope.alertRaceIDs == nil, "absent race scope stays absent")
    Assert(noScope.alertClassIDs == nil, "absent class scope stays absent")
    Assert(noScope.alertSpecIDs == nil, "absent spec scope stays absent")
end

-- ---- Runtime scope matching (extracted verbatim from RuntimeConfigBuilder) ----

local function ScopeMapMatches(source, allID, fallbackID, currentID)
    local hasSelection = false
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                hasSelection = true
                if numberKey == allID or numberKey == currentID then
                    return true
                end
            end
        end
    end
    if not hasSelection then
        fallbackID = tonumber(fallbackID) or allID
        return fallbackID == allID or fallbackID == currentID
    end
    return false
end

do
    local classes = { [0] = true }
    local specs = { [71] = true }
    Assert(ScopeMapMatches(classes, 0, 0, 1), "all-classes matches warrior")
    Assert(ScopeMapMatches(classes, 0, 0, 2), "all-classes matches paladin")
    Assert(ScopeMapMatches(specs, 0, 0, 71), "concrete spec matches its own spec")
    Assert(not ScopeMapMatches(specs, 0, 0, 72), "concrete spec does not match other specs")
    Assert(ScopeMapMatches(nil, 0, 0, 5), "absent scope falls back to the stored scope")
    Assert(not ScopeMapMatches(nil, 0, 2, 5), "absent scope falls back to a concrete stored scope")
end

print("test_save_load_export_import_scope: OK")
