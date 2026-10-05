-- The quick skill picker offers cooldowns from every category, including the
-- aura-tracking ones (Tracked Buffs / Tracked Bars) used by aura entries,
-- while essential and utility abilities remain selectable. Every class/spec
-- keeps its own list (no cross-spec spellID dedup) and entries read
-- "Class·Spec · Skill"; saved CDM presets only fill specs that have no cached
-- catalog yet.

local function Fail(message)
    error(message, 2)
end

local function Assert(value, message)
    if not value then
        Fail(message or "assertion failed")
    end
end

local savedCatalog = nil

QFXSkillAlertsNS = {
    Constants = {
        OBJECT_TYPE_SPELL = "spell",
        OBJECT_TYPE_ITEM = "item",
        ITEM_LOAD_NONE = "none",
        ITEM_LOAD_EQUIPPED = "equipped",
        ITEM_LOAD_BAGS = "bags",
    },
    UI = { EditorFields = {} },
    Utils = {},
    API = {
        GetCDMVoiceCategories = function()
            return {
                { key = "essential", name = "Essential" },
                { key = "utility", name = "Utility" },
                { key = "trackedBuff", name = "Tracked Buffs" },
                { key = "trackedBar", name = "Tracked Bars" },
            }
        end,
        GetCDMVoiceCooldownsForCategory = function(key)
            local spellID = key == "essential" and 100 or (key == "utility" and 200 or 300)
            return { { spellID = spellID, spellName = key } }
        end,
        GetCDMVoiceSavedEntries = function()
            return {
                { classID = 1, specID = 71, spellId = 100, spellName = "Duplicate live skill" },
                { classID = 2, specID = 65, spellId = 500, spellName = "Catalog Covers This Spec" },
                { classID = 2, specID = 999, spellId = 501, spellName = "Unknown Spec Skill" },
            }
        end,
        GetCDMVoiceCurrentClassSpec = function()
            return 1, 71
        end,
        GetCDMVoiceSkillCatalog = function()
            return {
                [1] = {
                    [71] = { items = { { spellID = 700, spellName = "Current Spec Cache" } } },
                },
                [2] = {
                    [65] = { items = { { spellID = 600, spellName = "Holy Light" } } },
                    -- Same spellID in a second spec must be listed separately.
                    [66] = { items = { { spellID = 600, spellName = "Holy Light" } } },
                },
            }
        end,
        SaveCDMVoiceSkillCatalog = function(classID, specID, items)
            savedCatalog = { classID = classID, specID = specID, count = #items,
                first = items[1] and items[1].spellID }
        end,
    },
    L = function(key) return key end,
}

QFXSkillAlertsNS.AceOptions = {
    GetClassOptionList = function()
        return {
            { classID = 1, className = "Warrior" },
            { classID = 2, className = "Paladin" },
        }
    end,
    GetSpecOptionList = function(_, classID)
        if classID == 1 then
            return { { specID = 71, specName = "Arms" } }
        end
        if classID == 2 then
            return { { specID = 65, specName = "Holy" }, { specID = 66, specName = "Protection" } }
        end
        return {}
    end,
}

dofile("QFXSkillAlerts_Config/UI/EditorFields.lua")
local Fields = QFXSkillAlertsNS.UI.EditorFields

QFXSkillAlertsNS.UI.ScopeSelector = {
    GetScopeSpecItems = function()
        return {
            { value = 0, text = "All Specs" },
            { value = 65, text = "Paladin · Holy" },
            { value = 66, text = "Paladin · Protection" },
            { value = 71, text = "Warrior · Arms" },
        }
    end,
}

local items, enabled, reason, currentSpec = Fields:GetCdmSkillItems()
Assert(enabled == true, "picker enabled with catalog data")
Assert(reason == nil, "no reason when enabled")
Assert(currentSpec == 71, "picker reports the current spec")

local byValue = {}
local valueCounts = {}
for _, item in ipairs(items) do
    byValue[item.value] = item
    valueCounts[item.value] = (valueCounts[item.value] or 0) + 1
end

Assert(byValue[100] and byValue[100].text == "Essential · essential", "essential keeps category label")
Assert(byValue[200] and byValue[200].text == "Utility · utility", "utility keeps category label")
Assert(byValue[300] and byValue[300].text == "Tracked Buffs · trackedBuff",
    "aura-tracking categories are offered for aura entries")

-- Catalog-backed specs keep their full list; the current spec's live layout
-- wins and only its missing catalog entries are appended.
local holyLabel = false
for _, item in ipairs(items) do
    if item.value == 600 and item.text == "Paladin·Holy · Holy Light" then
        holyLabel = true
    end
end
Assert(holyLabel, "cached catalog entry uses its class/spec label")
Assert(byValue[700] and byValue[700].text == "Warrior·Arms · Current Spec Cache",
    "current spec catalog gaps are appended after the live layout")
Assert(savedCatalog and savedCatalog.classID == 1 and savedCatalog.specID == 71
    and savedCatalog.count == 3 and savedCatalog.first == 100,
    "live catalog is cached for the current spec")

-- No cross-spec dedup: the same spellID appears once per spec.
Assert(valueCounts[600] == 2, "same spellID in two specs is listed for each spec")
local labels600 = {}
for _, item in ipairs(items) do
    if item.value == 600 then
        labels600[item.text] = true
    end
end
Assert(labels600["Paladin·Holy · Holy Light"] and labels600["Paladin·Protection · Holy Light"],
    "duplicate spell entries keep their own spec labels")

-- Saved presets are skipped once a spec has a cached catalog, but still fill
-- specs without one; the current spec's saved duplicates are not added.
Assert(not byValue[500], "saved preset is skipped when the spec has a catalog")
Assert(byValue[501] and byValue[501].text == "Paladin · Unknown Spec Skill",
    "unknown spec without catalog keeps its saved preset")
Assert(valueCounts[100] == 1, "live catalog entry is not duplicated by the saved record")

-- Class/spec filter: single selection, no "All" entry, concrete specs keep
-- only their own entries.
local filterItems = Fields:GetSkillFilterItems()
Assert(#filterItems == 3, "filter items exclude the all-specs sentinel")
local hasAllSentinel = false
for _, item in ipairs(filterItems) do
    if (tonumber(item.value) or 0) == 0 then
        hasAllSentinel = true
    end
end
Assert(not hasAllSentinel, "filter list has no all-specs option")

Assert(Fields:FilterSkillItems(items, 0) == items, "no selection keeps everything")

local holyItems = Fields:FilterSkillItems(items, 65)
local holyIDs = {}
for _, item in ipairs(holyItems) do holyIDs[item.value] = true end
Assert(holyIDs[600], "selected spec cached entry stays")
Assert(not holyIDs[501], "other spec saved entry is filtered out")
Assert(not holyIDs[100] and not holyIDs[200], "live current-spec entries are filtered out for another spec")

local armsItems = Fields:FilterSkillItems(items, 71)
local armsIDs = {}
for _, item in ipairs(armsItems) do armsIDs[item.value] = true end
Assert(armsIDs[100] and armsIDs[200], "current spec live entries stay for their own spec")
Assert(armsIDs[700], "current spec catalog gap stays for its own spec")
Assert(not armsIDs[600] and not armsIDs[501], "other specs are filtered out")

-- Missing catalog helpers keep the picker disabled.
QFXSkillAlertsNS.API.GetCDMVoiceCategories = nil
local emptyItems, emptyEnabled, emptyReason = Fields:GetCdmSkillItems()
Assert(emptyEnabled == false, "picker disabled without categories API")
Assert(emptyReason == "not_available", "reason reports unavailable API")
Assert(#emptyItems == 0, "no items without categories API")

print("test_cdm_picker_categories: OK")
