-- Scope dropdown item builders: ordering, "all" sentinels and class-color text
-- used by the always-visible race / class / spec multi-select dropdowns in the
-- editor (ScopeSelector:GetScopeRaceItems / GetScopeClassItems /
-- GetScopeSpecItems). Spec lists must follow class order and only include the
-- specs of the selected classes; class/spec labels carry the class color.

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
    Constants = { ALL_RACES_ID = 0, ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0 },
    UI = { ScopeSelector = {} },
    AceOptions = {},
}

function QFXSkillAlertsNS.AceOptions:GetClassOptionList()
    return {
        { classID = 0, className = "All Classes" },
        { classID = 1, className = "Warrior", classFile = "WARRIOR" },
        { classID = 2, className = "Paladin", classFile = "PALADIN" },
        { classID = 3, className = "NoColor", classFile = "NOCOLOR" },
    }
end

function QFXSkillAlertsNS.AceOptions:GetSpecOptionList(classID)
    if classID == 1 then
        return {
            { specID = 0, specName = "All Specs" },
            { specID = 71, specName = "Arms" },
            { specID = 72, specName = "Fury" },
            { specID = 73, specName = "Protection" },
        }
    end
    if classID == 2 then
        return {
            { specID = 0, specName = "All Specs" },
            { specID = 65, specName = "Holy" },
            { specID = 66, specName = "Protection" },
            { specID = 70, specName = "Retribution" },
        }
    end
    return { { specID = 0, specName = "All Specs" } }
end

C_ClassColor = {
    GetClassColor = function(classFile)
        if classFile == "WARRIOR" then
            return { GetRGB = function() return 0.78, 0.61, 0.43 end }
        end
        if classFile == "PALADIN" then
            return { GetRGB = function() return 0.96, 0.55, 0.73 end }
        end
        return nil
    end,
}

dofile("QFXSkillAlerts_Config/UI/ScopeSelector.lua")
local Selector = QFXSkillAlertsNS.UI.ScopeSelector

-- Race items: "All Races" first, then concrete races.
do
    local items = Selector:GetScopeRaceItems()
    Assert(#items > 5, "race items expected")
    Equal(items[1].value, 0, "race all sentinel")
    local hasRace = false
    for _, item in ipairs(items) do
        if item.value == 1 then
            hasRace = true
        end
    end
    Assert(hasRace, "human race entry expected")
end

-- Class items: "All Classes" first, then colored class names.
do
    local items = Selector:GetScopeClassItems()
    Equal(items[1].value, 0, "class all sentinel")
    Equal(items[1].text, "SCOPE_ALL_CLASSES", "class all label")
    local warrior, paladin, noColor
    for _, item in ipairs(items) do
        if item.value == 1 then warrior = item end
        if item.value == 2 then paladin = item end
        if item.value == 3 then noColor = item end
    end
    Equal(warrior.text, "|cffc79c6eWarrior|r", "warrior colored text")
    Equal(warrior.searchText, "Warrior", "warrior search text")
    Equal(paladin.text, "|cfff58cbaPaladin|r", "paladin colored text")
    Assert(not noColor.text:find("|cff", 1, true), "class without color stays plain")
end

-- Spec items: only the selected classes' specs, in class order, colored and
-- prefixed with the class name.
do
    local items = Selector:GetScopeSpecItems({ [1] = true })
    Equal(#items, 4, "warrior spec count (all + 3)")
    Equal(items[1].value, 0, "spec all sentinel")
    Equal(items[2].value, 71, "warrior arms first")
    Equal(items[3].value, 72, "warrior fury second")
    Equal(items[4].value, 73, "warrior protection third")
    Equal(items[2].text, "|cffc79c6eWarrior · Arms|r", "spec colored text")

    local both = Selector:GetScopeSpecItems({ [1] = true, [2] = true })
    Equal(#both, 7, "warrior + paladin spec count (all + 3 + 3)")
    Equal(both[5].value, 65, "paladin specs follow warrior specs")
    Equal(both[5].text, "|cfff58cbaPaladin · Holy|r", "paladin spec colored text")

    local all = Selector:GetScopeSpecItems({ [0] = true })
    Equal(#all, 7, "all-class spec count")
end

print("test_scope_dropdown_items: OK")
