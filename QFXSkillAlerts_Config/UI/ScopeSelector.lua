local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.ScopeSelector = NS.UI.ScopeSelector or {}

local ScopeSelector = NS.UI.ScopeSelector
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local CONST = NS.Constants or {}

local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local RACE_IDS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 36, 37, 52, 70, 84, 85,
}

local RACE_FALLBACK_NAMES = {
    [1] = "Human", [2] = "Orc", [3] = "Dwarf", [4] = "Night Elf", [5] = "Undead",
    [6] = "Tauren", [7] = "Gnome", [8] = "Troll", [9] = "Goblin", [10] = "Blood Elf",
    [11] = "Draenei", [22] = "Worgen", [24] = "Pandaren", [25] = "Pandaren (Alliance)",
    [26] = "Pandaren (Horde)", [27] = "Nightborne", [28] = "Highmountain Tauren",
    [29] = "Void Elf", [30] = "Lightforged Draenei", [31] = "Zandalari Troll",
    [32] = "Kul Tiran", [34] = "Dark Iron Dwarf", [35] = "Vulpera", [36] = "Mag'har Orc",
    [37] = "Mechagnome", [52] = "Dracthyr", [70] = "Dracthyr", [84] = "Earthen", [85] = "Earthen",
}

local function GetRaceName(raceID)
    raceID = tonumber(raceID) or 0
    if C_CreatureInfo and type(C_CreatureInfo.GetRaceInfo) == "function" then
        local ok, info = pcall(C_CreatureInfo.GetRaceInfo, raceID)
        if ok and type(info) == "table" and type(info.raceName) == "string" and info.raceName ~= "" then
            return info.raceName
        end
    end
    return RACE_FALLBACK_NAMES[raceID] or tostring(raceID)
end

local function BuildRaceItems()
    local items = {}
    for _, raceID in ipairs(RACE_IDS) do
        items[#items + 1] = { value = raceID, text = GetRaceName(raceID) }
    end
    table.sort(items, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return items
end

local function FormatColorText(text, r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return tostring(text or "")
    end
    local function Channel(value)
        value = math.max(0, math.min(1, value))
        return math.floor(value * 255 + 0.5)
    end
    return string.format("|cff%02x%02x%02x%s|r", Channel(r), Channel(g), Channel(b), tostring(text or ""))
end

local function GetClassColorRGB(classFile)
    local color
    if type(classFile) == "string" and classFile ~= "" then
        if rawget(_G, "C_ClassColor") and type(C_ClassColor.GetClassColor) == "function" then
            local ok, result = pcall(C_ClassColor.GetClassColor, classFile)
            if ok and type(result) == "table" then
                color = result
            end
        end
        if not color and type(rawget(_G, "RAID_CLASS_COLORS")) == "table" then
            color = RAID_CLASS_COLORS[classFile]
        end
    end
    if color and type(color.GetRGB) == "function" then
        local r, g, b = color:GetRGB()
        return tonumber(r), tonumber(g), tonumber(b)
    end
    return nil
end

-- Inline scope dropdown data used by the always-visible race / class / spec
-- multi-select dropdowns in the editor. Class and spec entries carry their
-- class color as a text escape so both the closed control and the popup list
-- are colored.
function ScopeSelector:GetScopeRaceItems()
    local items = { { value = ALL_RACES_ID, text = L("SCOPE_ALL_RACES"), searchText = L("SCOPE_ALL_RACES") } }
    for _, item in ipairs(BuildRaceItems()) do
        items[#items + 1] = { value = item.value, text = item.text, searchText = item.text }
    end
    return items
end

function ScopeSelector:GetScopeClassItems()
    local items = { { value = ALL_CLASSES_ID, text = L("SCOPE_ALL_CLASSES"), searchText = L("SCOPE_ALL_CLASSES") } }
    local classOptions = NS.AceOptions and NS.AceOptions.GetClassOptionList and NS.AceOptions:GetClassOptionList() or {}
    for _, classInfo in ipairs(classOptions or {}) do
        local classID = tonumber(classInfo and classInfo.classID) or 0
        if classID > 0 then
            local name = tostring(classInfo.className or classID)
            local r, g, b = GetClassColorRGB(classInfo.classFile)
            items[#items + 1] = {
                value = classID,
                text = FormatColorText(name, r, g, b),
                searchText = name,
            }
        end
    end
    return items
end

-- Lists "All Specs" plus the specs of every class in classMap (all classes when
-- classMap resolves to "all"). Spec order follows the client's class/spec
-- order so multi-class lists read the same way as the in-game talent pane.
function ScopeSelector:GetScopeSpecItems(classMap)
    local items = { { value = ALL_SPECS_ID, text = L("SCOPE_ALL_SPECS"), searchText = L("SCOPE_ALL_SPECS") } }
    local concrete = {}
    for classID, enabled in pairs(type(classMap) == "table" and classMap or {}) do
        classID = tonumber(classID) or 0
        if enabled == true and classID > 0 then
            concrete[classID] = true
        end
    end
    local includeAll = next(concrete) == nil
    local classOptions = NS.AceOptions and NS.AceOptions.GetClassOptionList and NS.AceOptions:GetClassOptionList() or {}
    for _, classInfo in ipairs(classOptions or {}) do
        local classID = tonumber(classInfo and classInfo.classID) or 0
        if classID > 0 and (includeAll or concrete[classID] == true) then
            local className = tostring(classInfo.className or classID)
            local r, g, b = GetClassColorRGB(classInfo.classFile)
            local specList = NS.AceOptions and NS.AceOptions.GetSpecOptionList and NS.AceOptions:GetSpecOptionList(classID) or {}
            for _, specInfo in ipairs(specList or {}) do
                local specID = tonumber(specInfo and specInfo.specID) or 0
                if specID > 0 then
                    local specName = tostring(specInfo.specName or specID)
                    items[#items + 1] = {
                        value = specID,
                        text = FormatColorText(className .. " · " .. specName, r, g, b),
                        searchText = className .. " " .. specName,
                    }
                end
            end
        end
    end
    return items
end
